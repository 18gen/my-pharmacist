//
//  MedicationStoreTests.swift
//  MedLensTests
//

import Foundation
import Testing
@testable import MedLens

@MainActor
struct MedicationStoreTests {
    /// A private defaults domain per test so nothing touches the app's real data.
    private let defaults: UserDefaults = {
        let name = "MedLensTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }()

    /// The store prunes records older than two weeks against the real clock, so use today.
    private let morning = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!

    @Test func scanningARegisteredLabelMarksTheDoseTaken() {
        let store = MedicationStore(defaults: defaults)
        let outcome = store.recordScan(scannedName: "METFORMIN HCL 500 MG", now: morning)

        guard case .checked(let dose) = outcome else {
            Issue.record("Expected a checked dose, got \(outcome)")
            return
        }
        #expect(dose.id == "metformin-500@8:00")
        let item = store.todayList(now: morning).first { $0.dose.id == dose.id }
        #expect(item?.state == .taken(at: morning))
    }

    @Test func unknownAndAmbiguousLabelsChangeNothing() {
        let store = MedicationStore(defaults: defaults)
        #expect(store.recordScan(scannedName: "IBUPROFEN 200 MG", now: morning) == .notOnList(scannedName: "IBUPROFEN 200 MG"))
        #expect(!store.todayList(now: morning).contains { $0.state.isTaken })
    }

    @Test func takenDosesAreSavedAndCanBeUndone() {
        let store = MedicationStore(defaults: defaults)
        let dose = store.doses(on: morning)[0]
        store.markTaken(dose, at: morning)

        let reloaded = MedicationStore(defaults: defaults)
        #expect(reloaded.todayList(now: morning).first { $0.dose.id == dose.id }?.state == .taken(at: morning))

        reloaded.markNotTaken(dose)
        #expect(!MedicationStore(defaults: defaults).todayList(now: morning).contains { $0.state.isTaken })
    }
}
