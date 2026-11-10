//
//  PillCheckClientTests.swift
//  MyPharmacistTests
//

import Foundation
import Testing
@testable import MyPharmacist

struct PillCheckClientTests {
    private typealias Client = PillCheckClient
    private let candidates = [
        Client.Candidate(id: "exemestane-25", description: "Exemestane 25 mg", photos: [Data([1]), Data([2])]),
        Client.Candidate(id: "ondansetron-8", description: "Ondansetron 8 mg", photos: [Data([3])]),
    ]

    @Test func theServersAddressAndTokenComeFromSecrets() throws {
        let configuration = try #require(Client.Configuration.from([
            "PILL_CHECK_URL": " https://pill-check.example.workers.dev ",
            "PILL_CHECK_TOKEN": "secret",
        ]))
        #expect(configuration.checkURL.absoluteString == "https://pill-check.example.workers.dev/check")
        #expect(configuration.privacyURL.absoluteString == "https://pill-check.example.workers.dev/privacy")
        #expect(configuration.token == "secret")
    }

    @Test func noAddressOrAnExampleOneIsNoConfiguration() {
        #expect(Client.Configuration.from([:]) == nil)
        #expect(Client.Configuration.from(["PILL_CHECK_URL": "http://insecure.example", "PILL_CHECK_TOKEN": "secret"]) == nil)
        #expect(Client.Configuration.from(["PILL_CHECK_URL": "https://ok.example", "PILL_CHECK_TOKEN": "paste-your-token"]) == nil)
    }

    @Test func theRequestCarriesThePicturesAndTheMedications() throws {
        let body = Client.requestBody(pills: [Data([9]), Data([8])], overview: Data([7]), candidates: candidates)
        #expect(body["pills"] as? [String] == [Data([9]).base64EncodedString(), Data([8]).base64EncodedString()])
        #expect(body["overview"] as? String == Data([7]).base64EncodedString())
        let sent = try #require(body["candidates"] as? [[String: Any]])
        #expect(sent.map { $0["id"] as? String } == ["exemestane-25", "ondansetron-8"])
        #expect((sent[0]["photos"] as? [String])?.count == 2)
        // And it is valid JSON.
        _ = try JSONSerialization.data(withJSONObject: body)
        #expect(Client.requestBody(pills: [Data([9])], overview: nil, candidates: [])["overview"] is NSNull)
    }

    @Test func readsTheServersAnswer() throws {
        let data = Data("""
            {"pills": [{"pill": 1, "shows_one_whole_pill": true, "imprint": "2858", "medication_id": "exemestane-25", "confidence": "high"}],
             "unnumbered_pill_like_objects": 1}
            """.utf8)
        let reply = try Client.reply(in: data)
        #expect(reply.pills == [Client.Answer(pill: 1, imprint: "2858", medicationID: "exemestane-25", confidence: "high")])
        #expect(reply.unnumberedPillLikeObjects == 1)
        #expect(throws: (any Error).self) { try Client.reply(in: Data("{\"error\": \"Not allowed\"}".utf8)) }
    }

    @Test func onlySureAnswersAboutCandidatesCount() {
        let answers = [
            Client.Answer(pill: 1, imprint: "2858", medicationID: "exemestane-25", confidence: "high"),
            Client.Answer(pill: 2, imprint: "", medicationID: "ondansetron-8", confidence: "medium"),
            Client.Answer(pill: 3, imprint: "", medicationID: "ondansetron-8", confidence: "low"),
            Client.Answer(pill: 4, imprint: "", medicationID: "none", confidence: "high"),
            Client.Answer(pill: 5, imprint: "", medicationID: "aspirin", confidence: "high"),
            Client.Answer(pill: 6, showsOneWholePill: false, imprint: "2858", medicationID: "exemestane-25", confidence: "high"),
            // Pill 7 got no answer at all.
        ]
        let ids = Client.medicationIDs(from: answers, pillCount: 7, candidateIDs: ["exemestane-25", "ondansetron-8"])
        #expect(ids == ["exemestane-25", "ondansetron-8", nil, nil, nil, nil, nil])
    }
}
