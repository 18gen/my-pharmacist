//
//  ScanFlowTests.swift
//  MyPharmacistTests
//

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

    @Test func scansAreIgnoredWhileTheCameraIsClosed() {
        #expect(flow.handleConfirmedName("METFORMIN 500 MG", now: morning) == nil)
        #expect(!store.todayList(now: morning).contains { $0.state.isTaken })
    }

    @Test func aMatchingScanChecksTheDoseAndAutoCloses() {
        flow.setOpen(true)
        let outcome = flow.handleConfirmedName("METFORMIN 500 MG", now: morning)

        guard case .checked(let dose) = outcome else {
            Issue.record("Expected a checked dose, got \(String(describing: outcome))")
            return
        }
        #expect(flow.outcome == outcome)
        #expect(flow.shouldAutoClose)
        #expect(store.todayList(now: morning).first { $0.id == dose.id }?.state == .taken(at: morning))
    }

    @Test func aSecondReadOfTheSameBottleIsIgnored() {
        flow.setOpen(true)
        let first = flow.handleConfirmedName("METFORMIN 500 MG", now: morning)
        #expect(flow.handleConfirmedName("METFORMIN 500MG", now: morning) == nil)
        // Still the first outcome, not "Already taken".
        #expect(flow.outcome == first)
    }

    @Test func reopeningStartsAFreshSession() {
        flow.setOpen(true)
        flow.handleConfirmedName("METFORMIN 500 MG", now: morning)
        flow.setOpen(false)
        #expect(flow.outcome == nil)

        flow.setOpen(true)
        let outcome = flow.handleConfirmedName("METFORMIN 500 MG", now: morning.addingTimeInterval(60))
        guard case .alreadyTaken = outcome else {
            Issue.record("Expected already taken, got \(String(describing: outcome))")
            return
        }
        #expect(!flow.shouldAutoClose)
    }

    @Test func undoUnchecksTheDose() {
        flow.setOpen(true)
        flow.handleConfirmedName("METFORMIN 500 MG", now: morning)
        flow.undo()

        #expect(flow.outcome == nil)
        #expect(!flow.shouldAutoClose)
        #expect(!store.todayList(now: morning).contains { $0.state.isTaken })
    }

    @Test func unknownLabelsAreReportedEveryTime() {
        flow.setOpen(true)
        #expect(flow.handleConfirmedName("IBUPROFEN 200 MG", now: morning) == .notOnList(scannedName: "IBUPROFEN 200 MG"))
        #expect(flow.handleConfirmedName("IBUPROFEN 200 MG", now: morning) == .notOnList(scannedName: "IBUPROFEN 200 MG"))
    }
}
