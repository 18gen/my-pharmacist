//
//  PillPhotoAnalyzerTests.swift
//  MyPharmacistTests
//

import CoreGraphics
import Testing
@testable import MyPharmacist

/// Answers what it is told to, as a recognizer on the device or the server would.
private struct FixedRecognizer: PillRecognizer {
    /// Nil for a recognizer that can't be reached.
    var reading: PillReading?

    func recognize(_ pictures: [CGImage], overview: CGImage?, among medications: [Medication]) async throws(PillRecognitionFailure) -> PillReading {
        guard let reading else { throw .offline }
        return reading
    }
}

struct PillPhotoAnalyzerTests {
    private let width = 540, height = 960

    /// A plain photo and two pills as the finder would return them.
    /// - Parameter rough: Whether the finder doubted each one's outline.
    private func scene(rough: [Bool] = [false, false]) throws -> (photo: CapturedPhoto, found: [FoundPill]) {
        let bytes = [UInt8](repeating: 200, count: width * height * 4)
        let image = try #require(ColourImage(width: width, height: height, bytes: bytes).cgImage())
        let photo = try #require(CapturedPhoto(image: image))
        let found = zip(discs(width: width, height: height, [(150, 400, 30), (350, 400, 30)]).blobs(), rough).map { blob, isRough in
            FoundPill(box: blob.normalizedBounds(pictureWidth: width, pictureHeight: height), crop: testImage(), outline: blob,
                      shape: BlobShape(blob), searchedSize: CGSize(width: width, height: height), sources: .lifted, isRough: isRough)
        }
        return (photo, found)
    }

    private func analyzer(_ reading: PillReading?, medications: [Medication] = TestMedications.all) -> PillPhotoAnalyzer {
        PillPhotoAnalyzer(medications: medications, recognizer: FixedRecognizer(reading: reading))
    }

    @Test func eachPillGetsTheRecognizersAnswerInOrder() async throws {
        let scene = try scene()
        let reading = PillReading(answers: [.medication(TestMedications.metformin.id), .unknown], mayHaveMissedPill: true)
        let identified = try await analyzer(reading).identify(scene.found, in: scene.photo).get()
        #expect(identified.pills.map(\.medicationID) == [TestMedications.metformin.id, nil])
        #expect(identified.pills.map(\.box) == scene.found.map(\.box))
        #expect(identified.mayHaveMissedPill)
    }

    private func failure(_ result: Result<PillIdentification, PillRecognitionFailure>) -> PillRecognitionFailure? {
        if case .failure(let failure) = result { failure } else { nil }
    }

    @Test func aRecognizerThatFailsIsAFailureNeverAnAnswer() async throws {
        let scene = try scene()
        #expect(failure(await analyzer(nil).identify(scene.found, in: scene.photo)) == .offline)
        // An answer for the wrong number of pills can't be matched to them.
        let short = PillReading(answers: [.unknown], mayHaveMissedPill: false)
        #expect(failure(await analyzer(short).identify(scene.found, in: scene.photo)) == .unusable)
        // No recognizer at all: the app isn't set up to check.
        let none = PillPhotoAnalyzer(medications: TestMedications.all, recognizer: nil)
        #expect(failure(await none.identify(scene.found, in: scene.photo)) == .notConfigured)
    }

    @Test func whatBothTheAppAndTheRecognizerDoubtIsLeftOut() async throws {
        // The first has a clean outline, the second a rough one; the recognizer says
        // neither picture shows a pill.
        let scene = try scene(rough: [false, true])
        let reading = PillReading(answers: [.notAPill, .notAPill], mayHaveMissedPill: false)
        let identified = try await analyzer(reading).identify(scene.found, in: scene.photo).get()
        // Only the one both doubt goes; the other stays, unknown.
        #expect(identified.pills.map(\.box) == [scene.found[0].box])
        #expect(identified.pills.map(\.medicationID) == [nil])

        // A rough outline alone is no reason to leave a pill out.
        let recognized = PillReading(answers: [.unknown, .medication(TestMedications.metformin.id)], mayHaveMissedPill: false)
        let both = try await analyzer(recognized).identify(scene.found, in: scene.photo).get()
        #expect(both.pills.map(\.medicationID) == [nil, TestMedications.metformin.id])
    }

    @Test func withNoMedicationsEveryPillIsUnknownWithoutAsking() async throws {
        let scene = try scene()
        let identified = try await analyzer(nil, medications: []).identify(scene.found, in: scene.photo).get()
        #expect(identified.pills.map(\.medicationID) == [nil, nil])
    }
}
