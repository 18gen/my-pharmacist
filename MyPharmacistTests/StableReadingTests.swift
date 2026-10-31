//
//  StableReadingTests.swift
//  MyPharmacistTests
//

import Testing
@testable import MyPharmacist

@MainActor
struct StableReadingTests {
    @Test func confirmsAfterThreeMatchingReads() {
        var reading = StableReading()
        #expect(reading.confirm("A") == nil)
        #expect(reading.confirm("A") == nil)
        #expect(reading.confirm("A") == "A")
        #expect(reading.confirm("A") == "A")
    }

    @Test func emptyFramesAreIgnored() {
        var reading = StableReading()
        _ = reading.confirm("A")
        _ = reading.confirm(nil)
        _ = reading.confirm("A")
        #expect(reading.confirm("A") == "A")
    }

    @Test func aDifferentReadStartsOver() {
        var reading = StableReading()
        _ = reading.confirm("A")
        _ = reading.confirm("A")
        #expect(reading.confirm("B") == nil)
        #expect(reading.confirm("A") == nil)
    }
}
