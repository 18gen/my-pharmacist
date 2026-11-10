//
//  PillCheckClient.swift
//  MyPharmacist
//

import CoreGraphics
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Asks the pill check server (`server/pill-check`) which of the person's medications
/// each pill is. The server holds the OpenAI key and owns the prompt; the app sends the
/// pictures and the medications, and gets back one answer per pill, which can only be
/// one of the medications or "none". An unsure answer counts as none.
///
/// The app's `PillRecognizer` unless another is given.
nonisolated struct PillCheckClient: Sendable {
    struct Configuration: Sendable, Equatable {
        /// The server's address, like "https://my-pharmacist-pill-check.example.workers.dev".
        let baseURL: URL
        /// The token the server checks, so only this app uses it.
        let token: String

        var checkURL: URL { baseURL.appending(path: "check") }
        var privacyURL: URL { baseURL.appending(path: "privacy") }
        var supportURL: URL { baseURL.appending(path: "support") }

        /// From Secrets.plist in the app bundle, which git ignores: PILL_CHECK_URL and
        /// PILL_CHECK_TOKEN. Nil when either is missing or still the example's.
        static func fromBundle(_ bundle: Bundle = .main) -> Configuration? {
            guard let url = bundle.url(forResource: "Secrets", withExtension: "plist"),
                  let values = NSDictionary(contentsOf: url) as? [String: Any] else { return nil }
            return from(values)
        }

        static func from(_ values: [String: Any]) -> Configuration? {
            func value(_ key: String) -> String? {
                (values[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard let address = value("PILL_CHECK_URL"), let baseURL = URL(string: address),
                  baseURL.scheme == "https", baseURL.host() != nil,
                  let token = value("PILL_CHECK_TOKEN"), !token.isEmpty, !token.contains("paste-") else { return nil }
            return Configuration(baseURL: baseURL, token: token)
        }
    }

    /// A medication to choose from: its ID, a line describing it, and JPEG reference photos.
    struct Candidate: Sendable {
        let id: String
        let description: String
        let photos: [Data]
    }

    /// The checker's answer for one pill, before the confidence rule.
    struct Answer: Decodable, Equatable, Sendable {
        let pill: Int
        /// False when the picture shows no pill, part of one, or more than one: the pill
        /// wasn't cut out right, so whatever it was matched to doesn't count.
        var showsOneWholePill = true
        let imprint: String
        let medicationID: String
        let confidence: String

        enum CodingKeys: String, CodingKey {
            case pill, imprint, confidence
            case showsOneWholePill = "shows_one_whole_pill"
            case medicationID = "medication_id"
        }
    }

    /// Everything the checker said about one photo.
    struct Reply: Decodable, Equatable, Sendable {
        let pills: [Answer]
        /// Things in the picture of all the pills that look like a pill but have no
        /// number: pills the app may have missed.
        var unnumberedPillLikeObjects = 0

        enum CodingKeys: String, CodingKey {
            case pills
            case unnumberedPillLikeObjects = "unnumbered_pill_like_objects"
        }
    }

    /// Only these count; "low" means unsure, and unsure is "none".
    static let acceptedConfidence: Set<String> = ["high", "medium"]

    let configuration: Configuration
    /// A little longer than the server waits for OpenAI.
    var timeout: TimeInterval = 35

    /// - Parameters:
    ///   - pills: A JPEG of each pill, in order.
    ///   - overview: A JPEG of all the pills together, numbered in the same order.
    func check(_ pills: [Data], overview: Data?, among candidates: [Candidate]) async throws(PillRecognitionFailure) -> PillReading {
        var request = URLRequest(url: configuration.checkURL, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue(configuration.token, forHTTPHeaderField: "X-App-Token")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        guard let body = try? JSONSerialization.data(withJSONObject: Self.requestBody(pills: pills, overview: overview, candidates: candidates)) else {
            throw .unusable
        }
        request.httpBody = body

        let data: Data, response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw .offline
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw .server(status: status) }
        guard let reply = try? Self.reply(in: data) else { throw .unusable }
        return Self.reading(of: reply, pillCount: pills.count, candidateIDs: Set(candidates.map(\.id)))
    }

    // MARK: Request and reply

    /// What the server takes: the pictures as base64, and the medications.
    static func requestBody(pills: [Data], overview: Data?, candidates: [Candidate]) -> [String: Any] {
        [
            "pills": pills.map { $0.base64EncodedString() },
            "overview": overview.map { $0.base64EncodedString() as Any } ?? NSNull(),
            "candidates": candidates.map { candidate in
                [
                    "id": candidate.id,
                    "description": candidate.description,
                    "photos": candidate.photos.map { $0.base64EncodedString() },
                ] as [String: Any]
            },
        ]
    }

    static func reply(in data: Data) throws -> Reply {
        try JSONDecoder().decode(Reply.self, from: data)
    }

    /// What the app takes from a reply about `pillCount` pill photos.
    static func reading(of reply: Reply, pillCount: Int, candidateIDs: Set<String>) -> PillReading {
        PillReading(
            medicationIDs: medicationIDs(from: reply.pills, pillCount: pillCount, candidateIDs: candidateIDs),
            mayHaveMissedPill: reply.unnumberedPillLikeObjects > 0 || reply.pills.contains { !$0.showsOneWholePill }
        )
    }

    /// Each pill's medication, or nil when the checker said none, was unsure, named
    /// something that isn't a candidate, didn't answer for that pill, or said its photo
    /// doesn't show one whole pill.
    static func medicationIDs(from answers: [Answer], pillCount: Int, candidateIDs: Set<String>) -> [String?] {
        (0..<pillCount).map { index in
            guard let answer = answers.first(where: { $0.pill == index + 1 }),
                  answer.showsOneWholePill,
                  candidateIDs.contains(answer.medicationID),
                  acceptedConfidence.contains(answer.confidence) else { return nil }
            return answer.medicationID
        }
    }

    /// The medications as the checker sees them: a line each and their photos.
    static func candidates(_ medications: [Medication]) -> [Candidate] {
        medications.map { medication in
            let description = [medication.displayName, medication.appearance].filter { !$0.isEmpty }.joined(separator: " · ")
            let photos = medication.photos
                .compactMap { MedicationPhotoStore.standard.image($0)?.cgImage }
                .compactMap { jpeg($0, maxSide: referenceSide) }
            return Candidate(id: medication.id, description: description, photos: photos)
        }
    }

    // MARK: Images

    /// The longer side of a medication's reference photo as it is sent.
    static let referenceSide = 256

    /// A JPEG no bigger than `maxSide`, with any transparency on light grey, as the
    /// reference photos' cut-outs would otherwise turn black.
    static func jpeg(_ image: CGImage, maxSide: Int = 384) -> Data? {
        let scale = min(1, Double(maxSide) / Double(max(image.width, image.height)))
        let width = max(1, Int(Double(image.width) * scale)), height = max(1, Int(Double(image.height) * scale))
        guard let context = CGContext.bitmap(width: width, height: height) else { return nil }
        context.setFillColor(gray: 0.85, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let flattened = context.makeImage() else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, flattened, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}

extension PillCheckClient: PillRecognizer {
    func recognize(_ pictures: [CGImage], overview: CGImage?, among medications: [Medication]) async throws(PillRecognitionFailure) -> PillReading {
        let pills = pictures.compactMap { Self.jpeg($0, maxSide: PillCropper.largestSide) }
        guard pills.count == pictures.count else { throw .unusable }
        return try await check(pills, overview: overview.flatMap { Self.jpeg($0, maxSide: PillCropper.overviewSide) },
                               among: Self.candidates(medications))
    }
}
