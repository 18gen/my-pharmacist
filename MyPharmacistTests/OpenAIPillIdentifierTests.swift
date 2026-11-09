//
//  OpenAIPillIdentifierTests.swift
//  MyPharmacistTests
//

import Foundation
import Testing
@testable import MyPharmacist

struct OpenAIPillIdentifierTests {
    private typealias Identifier = OpenAIPillIdentifier
    private let candidates = [
        Identifier.Candidate(id: "exemestane-25", description: "Exemestane 25 mg", photos: [Data([1]), Data([2])]),
        Identifier.Candidate(id: "ondansetron-8", description: "Ondansetron 8 mg", photos: [Data([3])]),
    ]

    /// A Responses API reply carrying `text` as its output.
    private func reply(_ text: String) -> Data {
        let body: [String: Any] = [
            "id": "resp_1",
            "status": "completed",
            "output": [
                ["type": "reasoning", "summary": []],
                ["type": "message", "role": "assistant", "content": [["type": "output_text", "text": text]]],
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: body)
    }

    @Test func readsTheAnswersFromAReply() throws {
        let answers = try Identifier.answers(in: reply("""
            {"pills": [{"pill": 1, "imprint": "2858", "medication_id": "exemestane-25", "confidence": "high"}]}
            """))
        #expect(answers == [Identifier.Answer(pill: 1, imprint: "2858", medicationID: "exemestane-25", confidence: "high")])
    }

    @Test func onlySureAnswersAboutCandidatesCount() {
        let answers = [
            Identifier.Answer(pill: 1, imprint: "2858", medicationID: "exemestane-25", confidence: "high"),
            Identifier.Answer(pill: 2, imprint: "", medicationID: "ondansetron-8", confidence: "medium"),
            Identifier.Answer(pill: 3, imprint: "", medicationID: "ondansetron-8", confidence: "low"),
            Identifier.Answer(pill: 4, imprint: "", medicationID: "none", confidence: "high"),
            Identifier.Answer(pill: 5, imprint: "", medicationID: "aspirin", confidence: "high"),
            // Pill 6 got no answer at all.
        ]
        let ids = Identifier.medicationIDs(from: answers, pillCount: 6, candidateIDs: ["exemestane-25", "ondansetron-8"])
        #expect(ids == ["exemestane-25", "ondansetron-8", nil, nil, nil, nil])
    }

    @Test func aRefusalIsNotAnAnswer() {
        let refusal = try! JSONSerialization.data(withJSONObject: [
            "output": [["type": "message", "content": [["type": "refusal", "refusal": "I can't help with that."]]]],
        ])
        #expect(throws: Identifier.Failure.self) { try Identifier.answers(in: refusal) }
    }

    @Test func theRequestOffersOnlyTheCandidatesOrNone() throws {
        let body = Identifier.requestBody(model: "gpt-test", pills: [Data([9]), Data([8])], candidates: candidates)
        #expect(body["model"] as? String == "gpt-test")

        let format = try #require((body["text"] as? [String: Any])?["format"] as? [String: Any])
        #expect(format["strict"] as? Bool == true)
        let pills = try #require(((format["schema"] as? [String: Any])?["properties"] as? [String: Any])?["pills"] as? [String: Any])
        let item = try #require(pills["items"] as? [String: Any])
        let id = try #require((item["properties"] as? [String: Any])?["medication_id"] as? [String: Any])
        #expect(id["enum"] as? [String] == ["exemestane-25", "ondansetron-8", "none"])

        // Three reference photos and two pills.
        let input = try #require((body["input"] as? [[String: Any]])?.first?["content"] as? [[String: Any]])
        #expect(input.filter { $0["type"] as? String == "input_image" }.count == 5)
    }
}
