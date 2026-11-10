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
        let read = Client.answers(from: answers, pillCount: 7, candidateIDs: ["exemestane-25", "ondansetron-8"])
        #expect(read == [.medication("exemestane-25"), .medication("ondansetron-8"), .unknown, .unknown, .unknown, .unknown, .unknown])
    }

    @Test func aPictureOfNoPillIsNotAPillAndLeavesNothingUnchecked() throws {
        let data = Data("""
            {"pills": [
              {"pill": 1, "picture_shows": "one_pill", "shows_one_whole_pill": true, "imprint": "2858", "medication_id": "exemestane-25", "confidence": "high"},
              {"pill": 2, "picture_shows": "no_pill", "shows_one_whole_pill": false, "imprint": "", "medication_id": "none", "confidence": "high"}],
             "unnumbered_pill_like_objects": 0}
            """.utf8)
        let reading = Client.reading(of: try Client.reply(in: data), pillCount: 2, candidateIDs: ["exemestane-25"])
        #expect(reading.answers == [.medication("exemestane-25"), .notAPill])
        #expect(!reading.mayHaveMissedPill)
        // Several pills in one picture, or part of one: unknown, and one may be unchecked.
        for shows in ["several_pills", "part_of_pill", "something new"] {
            let answer = Client.Answer(pill: 1, showsOneWholePill: false, imprint: "", medicationID: "exemestane-25", confidence: "high",
                                       pictureShows: shows)
            let reading = Client.reading(of: Client.Reply(pills: [answer]), pillCount: 1, candidateIDs: ["exemestane-25"])
            #expect(reading.answers == [.unknown])
            #expect(reading.mayHaveMissedPill)
        }
    }

    @Test func aPictureThatIsntOneWholePillMeansAPillMayBeUnchecked() {
        let ids: Set = ["exemestane-25"]
        let whole = Client.Answer(pill: 1, imprint: "2858", medicationID: "exemestane-25", confidence: "high")
        let two = Client.Answer(pill: 2, showsOneWholePill: false, imprint: "", medicationID: "exemestane-25", confidence: "high")
        #expect(!Client.reading(of: Client.Reply(pills: [whole]), pillCount: 1, candidateIDs: ids).mayHaveMissedPill)
        let reading = Client.reading(of: Client.Reply(pills: [whole, two]), pillCount: 2, candidateIDs: ids)
        #expect(reading.answers == [.medication("exemestane-25"), .unknown])
        #expect(reading.mayHaveMissedPill)
        // So does something pill-like that has no number.
        #expect(Client.reading(of: Client.Reply(pills: [whole], unnumberedPillLikeObjects: 1), pillCount: 1, candidateIDs: ids).mayHaveMissedPill)
    }
}
