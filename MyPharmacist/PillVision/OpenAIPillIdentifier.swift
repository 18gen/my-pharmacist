//
//  OpenAIPillIdentifier.swift
//  MyPharmacist
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Temporary, for demos: recognizes pills by asking an OpenAI vision model to match each
/// pill photo against the person's medications, shown with their reference photos. The
/// answer can only be one of those medications or "none" (the response schema allows
/// nothing else), and an unsure answer counts as none. To be replaced by a model trained
/// on ePillID that runs on the device.
///
/// Whether to take a pill is never the model's call: it only says which medication a pill
/// is; the schedule decides the rest.
nonisolated struct OpenAIPillIdentifier: Sendable {
    struct Configuration: Sendable {
        let apiKey: String
        let model: String

        /// "Balance intelligence and cost", per OpenAI's model guide (November 2026).
        static let defaultModel = "gpt-6.1-sol"

        /// From Secrets.plist in the app bundle, which git ignores: OPENAI_API_KEY and,
        /// optionally, OPENAI_MODEL. Nil without a key, and the app recognizes pills on
        /// the device instead.
        static func fromBundle(_ bundle: Bundle = .main) -> Configuration? {
            guard let url = bundle.url(forResource: "Secrets", withExtension: "plist"),
                  let values = NSDictionary(contentsOf: url) as? [String: Any],
                  let key = (values["OPENAI_API_KEY"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  key.hasPrefix("sk-"), !key.contains("paste-your-key") else { return nil }
            let model = (values["OPENAI_MODEL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return Configuration(apiKey: key, model: model?.isEmpty == false ? model! : defaultModel)
        }
    }

    /// A medication to choose from: its ID, a line describing it, and JPEG reference photos.
    struct Candidate: Sendable {
        let id: String
        let description: String
        let photos: [Data]
    }

    /// The model's answer for one pill, before the confidence rule.
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

    /// Everything the model said about one photo.
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

    /// What the app takes from a reply.
    struct Reading: Equatable, Sendable {
        /// One medication ID, or nil, per pill photo, in order.
        let medicationIDs: [String?]
        /// The model saw something pill-like that the app didn't number. This can only
        /// make the result more careful, never less.
        let mayHaveMissedPill: Bool
    }

    enum Failure: Error, CustomStringConvertible {
        case http(Int, String)
        case noAnswer(String)

        var description: String {
            switch self {
            case .http(let status, let body): "OpenAI returned \(status): \(body)"
            case .noAnswer(let reason): "OpenAI gave no usable answer: \(reason)"
            }
        }
    }

    /// Only these count; "low" means unsure, and unsure is "none".
    static let acceptedConfidence: Set<String> = ["high", "medium"]
    static let endpoint = URL(string: "https://api.openai.com/v1/responses")!

    let configuration: Configuration
    var timeout: TimeInterval = 30

    /// - Parameters:
    ///   - pills: A JPEG of each pill, in order.
    ///   - overview: A JPEG of all the pills together, numbered in the same order.
    func identify(_ pills: [Data], overview: Data? = nil, among candidates: [Candidate]) async throws -> Reading {
        var request = URLRequest(url: Self.endpoint, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: Self.requestBody(model: configuration.model, pills: pills, overview: overview, candidates: candidates))

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw Failure.http(status, String(decoding: data.prefix(300), as: UTF8.self))
        }
        let reply = try Self.reply(in: data)
        #if DEBUG
        for answer in reply.pills {
            print("OpenAI pill \(answer.pill): \(answer.medicationID) (\(answer.confidence)), imprint \"\(answer.imprint)\", one whole pill \(answer.showsOneWholePill)")
        }
        print("OpenAI saw \(reply.unnumberedPillLikeObjects) pill-like things without a number; the request was \(Self.inputTokens(in: data).map(String.init) ?? "?") tokens")
        #endif
        return Reading(
            medicationIDs: Self.medicationIDs(from: reply.pills, pillCount: pills.count, candidateIDs: Set(candidates.map(\.id))),
            mayHaveMissedPill: reply.unnumberedPillLikeObjects > 0
        )
    }

    // MARK: Request

    static let instructions = """
        You check pills for a medication safety app used by older people. Each numbered \
        pill photo was cut from a phone photo of pills in a hand or on a surface; it may \
        also be a printed picture of a pill. The pill to judge is in the middle at full \
        brightness; everything around it is dimmed and is not part of it. Long pills have \
        been turned to lie flat, so an imprint may be upside down. Small photos have been \
        enlarged. Compare each pill with the candidate medications' reference photos, which \
        show both sides. Match on shape, colour and the imprint (letters or numbers pressed \
        into or printed on the pill). Give a candidate's ID only when the pill clearly is \
        that medication. If the imprint you can read contradicts it, if no candidate fits, \
        or if you are unsure, answer "none". Report the imprint you can read, or an empty \
        string. Confidence is "high" only when shape, colour and any visible imprint all \
        agree, "medium" when they agree but the imprint can't be read, otherwise "low". \
        Set shows_one_whole_pill to false when the bright middle of a photo shows no pill, \
        only part of a pill, or more than one pill. The last picture shows all the pills \
        together, each in a box with its number beside it. Count in \
        unnumbered_pill_like_objects the things in it that look like a pill or capsule \
        but have no box and number; 0 if there are none or there is no such picture.
        """

    static func requestBody(model: String, pills: [Data], overview: Data? = nil, candidates: [Candidate]) -> [String: Any] {
        var content: [[String: Any]] = [text("Candidate medications, each with its reference photos:")]
        for candidate in candidates {
            content.append(text("Candidate \(candidate.id): \(candidate.description)"))
            content += candidate.photos.map(image)
        }
        content.append(text("Pills to identify (\(pills.count)):"))
        for (index, pill) in pills.enumerated() {
            content.append(text("Pill \(index + 1):"))
            content.append(image(pill))
        }
        if let overview {
            content.append(text("All the pills together, numbered as above:"))
            content.append(image(overview))
        }
        return [
            "model": model,
            // Nothing about the request is to be kept by the service.
            "store": false,
            "instructions": instructions,
            "input": [["role": "user", "content": content]],
            "text": ["format": [
                "type": "json_schema",
                "name": "pill_identification",
                "strict": true,
                "schema": schema(candidateIDs: candidates.map(\.id)),
            ]],
        ]
    }

    /// One answer per pill, with the medication ID limited to the candidates or "none".
    static func schema(candidateIDs: [String]) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "pills": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "pill": ["type": "integer"],
                            "shows_one_whole_pill": ["type": "boolean"],
                            "imprint": ["type": "string"],
                            "medication_id": ["type": "string", "enum": candidateIDs + ["none"]],
                            "confidence": ["type": "string", "enum": ["high", "medium", "low"]],
                        ],
                        "required": ["pill", "shows_one_whole_pill", "imprint", "medication_id", "confidence"],
                        "additionalProperties": false,
                    ],
                ],
                "unnumbered_pill_like_objects": ["type": "integer"],
            ],
            "required": ["pills", "unnumbered_pill_like_objects"],
            "additionalProperties": false,
        ]
    }

    private static func text(_ text: String) -> [String: Any] {
        ["type": "input_text", "text": text]
    }

    /// Detail is said outright: "auto" means different things from one model to the next.
    private static func image(_ jpeg: Data) -> [String: Any] {
        ["type": "input_image", "image_url": "data:image/jpeg;base64,\(jpeg.base64EncodedString())", "detail": "high"]
    }

    // MARK: Response

    /// What a Responses API reply says: the first output message's text, as JSON.
    static func reply(in data: Data) throws -> Reply {
        guard let reply = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = reply["output"] as? [[String: Any]] else {
            throw Failure.noAnswer("unexpected reply")
        }
        let content = output.filter { $0["type"] as? String == "message" }
            .flatMap { $0["content"] as? [[String: Any]] ?? [] }
        if let refusal = content.first(where: { $0["type"] as? String == "refusal" })?["refusal"] as? String {
            throw Failure.noAnswer("refused: \(refusal)")
        }
        guard let text = content.first(where: { $0["type"] as? String == "output_text" })?["text"] as? String else {
            throw Failure.noAnswer("no output text")
        }
        return try JSONDecoder().decode(Reply.self, from: Data(text.utf8))
    }

    /// How many tokens the request came to, as the reply reports it.
    static func inputTokens(in data: Data) -> Int? {
        ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])
            .flatMap { $0["usage"] as? [String: Any] }?["input_tokens"] as? Int
    }

    /// Each pill's medication, or nil when the model said none, was unsure, named
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

    // MARK: Images

    /// A JPEG no bigger than `maxSide`, with any transparency on light grey, as the
    /// reference photos' cut-outs would otherwise turn black.
    static func jpeg(_ image: CGImage, maxSide: Int = 384) -> Data? {
        let scale = min(1, Double(maxSide) / Double(max(image.width, image.height)))
        let width = max(1, Int(Double(image.width) * scale)), height = max(1, Int(Double(image.height) * scale))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        context.setFillColor(gray: 0.85, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let flattened = context.makeImage() else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, flattened, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}
