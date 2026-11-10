//
//  ResultsSkeletonLayoutTests.swift
//  MyPharmacistTests
//

import SwiftUI
import Testing
@testable import MyPharmacist

/// While the pills are checked, the results page stands ready with everything where it
/// will be: when the answer comes, the summary and the photo don't move.
@MainActor
struct ResultsSkeletonLayoutTests {
    private let size = CGSize(width: 373, height: 760)

    private func render(_ content: PillResultsView.Content) throws -> CGImage {
        let view = PillResultsView(content: content, onDone: {}, onScanAgain: {})
            .frame(width: size.width, height: size.height)
            .background(Color.white)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return try #require(renderer.cgImage)
    }

    /// The first row from `from` down, in a column at `x` (share of the width), that
    /// `matches`.
    private func firstRow(_ image: CGImage, x: Double, from: Int = 0, _ matches: ((red: Int, green: Int, blue: Int)) -> Bool) -> Int? {
        let column = Int(Double(image.width) * x)
        return (from..<image.height).first { matches(pixel(of: image, x: column, y: $0)) }
    }

    @Test func theSummaryAndThePhotoStayWhereTheyAre() throws {
        let sample = DemoScan.samplePills()
        let scanned = sample.pills.enumerated().map { index, pill in
            ScannedPill(id: index + 1, box: pill.box, crop: pill.crop, medication: nil, verdict: .unidentified)
        }
        let checking = try render(.checking(FoundPills(photo: sample.photo, boxes: sample.pills.map(\.box))))
        let ready = try render(.ready(PillScanResult(photo: sample.photo, pills: scanned)))

        // The photo strip: the first thing that isn't white below the summary's line, in
        // a column clear of its words.
        let notWhite: ((red: Int, green: Int, blue: Int)) -> Bool = { $0.red + $0.green + $0.blue < 700 }
        let photoChecking = try #require(firstRow(checking, x: 0.9, from: 60, notWhite))
        let photoReady = try #require(firstRow(ready, x: 0.9, from: 60, notWhite))
        #expect(photoChecking == photoReady, "The photo is at \(photoChecking) while checking and \(photoReady) after")

        // The summary's words: the first dark ink in a column through their start.
        let ink: ((red: Int, green: Int, blue: Int)) -> Bool = { $0.red + $0.green + $0.blue < 300 }
        let wordsChecking = try #require(firstRow(checking, x: 0.12, ink))
        let wordsReady = try #require(firstRow(ready, x: 0.12, ink))
        #expect(abs(wordsChecking - wordsReady) <= 1, "The summary is at \(wordsChecking) while checking and \(wordsReady) after")
    }
}
