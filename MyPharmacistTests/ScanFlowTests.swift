//
//  ScanFlowTests.swift
//  MyPharmacistTests
//

import CoreGraphics
import Foundation
import Testing
@testable import MyPharmacist

@MainActor
struct ScanFlowTests {
    private let store: MedicationStore
    private let flow: ScanFlow
    private let morning = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!

    init() {
        store = MedicationStore(medications: TestMedications.all, storage: InMemoryDoseLogStorage())
        flow = ScanFlow(store: store)
    }

    private func pill(_ medication: Medication?, x: Double = 0.1) -> AnalyzedPill {
        AnalyzedPill(box: CGRect(x: x, y: 0.4, width: 0.1, height: 0.1), crop: testImage(),
                     match: PillMatch(medicationID: medication?.id, distance: 0.2))
    }

    private var result: PillScanResult? {
        if case .results(let result) = flow.phase { result } else { nil }
    }

    @Test func pillsAreNumberedAndJudged() throws {
        flow.setOpen(true)
        flow.showResults(photo: testImage(), pills: [pill(TestMedications.metformin), pill(nil, x: 0.5)], now: morning)

        let result = try #require(result)
        #expect(result.pills.map(\.id) == [1, 2])
        #expect(result.pills[0].verdict.isTake)
        #expect(result.pills[1].verdict == .unidentified)
        #expect(result.missing.map(\.medication) == [TestMedications.lisinopril])
        #expect(result.summary == "1 to take · 1 not to take · 1 missing")
    }

    @Test func nothingIsTakenUntilConfirmed() {
        flow.setOpen(true)
        flow.showResults(photo: testImage(), pills: [pill(TestMedications.metformin), pill(TestMedications.lisinopril, x: 0.5)], now: morning)
        #expect(!store.todayList(now: morning).contains { $0.state.isTaken })

        #expect(flow.confirmTaken(now: morning) == 2)
        #expect(store.todayList(now: morning).filter { $0.state.isTaken }.count == 2)
    }

    @Test func onlyTakeNowPillsAreConfirmed() {
        flow.setOpen(true)
        flow.showResults(photo: testImage(), pills: [pill(TestMedications.atorvastatin), pill(TestMedications.lisinopril, x: 0.5)], now: morning)
        #expect(flow.confirmTaken(now: morning) == 1)
        #expect(store.todayList(now: morning).filter { $0.state.isTaken }.map(\.dose.medication) == [TestMedications.lisinopril])
    }

    @Test func aPhotoWithNoPills() {
        flow.setOpen(true)
        flow.showResults(photo: testImage(), pills: [], now: morning)
        #expect(flow.phase.step == .noPills)
        #expect(flow.confirmTaken(now: morning) == 0)
    }

    @Test func closingStartsTheNextSessionFresh() {
        flow.setOpen(true)
        flow.showResults(photo: testImage(), pills: [pill(TestMedications.metformin)], now: morning)
        flow.setOpen(false)
        #expect(flow.phase.step == .aiming)
    }
}
