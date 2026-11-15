//
//  MedicationCardTests.swift
//  MyPharmacistTests
//

import Foundation
import Testing
@testable import MyPharmacist

@MainActor
struct MedicationCardTests {
    /// The four cards on the keychain: the same lines `design/keychain/make_card_qr.py` prints.
    static let keychain = [
        "mypharmacist://add?v=1&id=capecitabine-500&t=1230,2000",
        "mypharmacist://add?v=1&id=dexamethasone-4&t=1230",
        "mypharmacist://add?v=1&id=allopurinol-300&t=2000",
        "mypharmacist://add?v=1&id=ondansetron-8&prn=1",
    ]

    private func emptyStore() -> MedicationStore {
        MedicationStore(storage: InMemoryDoseLogStorage())
    }

    @Test func theSampleListMakesTheKeychainsCards() {
        #expect(SampleMedications.sampleList.map { MedicationCard($0).text } == Self.keychain)
    }

    @Test func aCardIsReadBackAsItWasWritten() throws {
        for text in Self.keychain {
            #expect(try #require(MedicationCard(text)).text == text)
        }
        let card = try #require(MedicationCard(" MyPharmacist://add?id=capecitabine-500&t=2000,0830&v=1\n"))
        #expect(card.medicationID == "capecitabine-500")
        #expect(card.schedule == .times([DoseTime(8, 30), DoseTime(20)]))
    }

    @Test(arguments: [
        "",
        "https://example.com/add?v=1&id=capecitabine-500&t=1230",
        "mypharmacist://remove?v=1&id=capecitabine-500&t=1230",
        "mypharmacist://add?v=2&id=capecitabine-500&t=1230",
        "mypharmacist://add?id=capecitabine-500&t=1230",
        "mypharmacist://add?v=1&t=1230",
        "mypharmacist://add?v=1&id=&t=1230",
        "mypharmacist://add?v=1&id=capecitabine-500",
        "mypharmacist://add?v=1&id=capecitabine-500&t=1230&prn=1",
        "mypharmacist://add?v=1&id=capecitabine-500&prn=0",
        "mypharmacist://add?v=1&id=capecitabine-500&t=",
        "mypharmacist://add?v=1&id=capecitabine-500&t=2400",
        "mypharmacist://add?v=1&id=capecitabine-500&t=1260",
        "mypharmacist://add?v=1&id=capecitabine-500&t=830",
        "mypharmacist://add?v=1&id=capecitabine-500&t=12:30",
        "mypharmacist://add?v=1&id=capecitabine-500&t=1230,1230",
        "mypharmacist://add?v=1&id=capecitabine-500&t=1230,",
        "mypharmacist://add?v=1&id=capecitabine-500&t=0600,0800,1000,1200,1400,1600,1800",
        "mypharmacist://add?v=1&id=capecitabine-500&id=allopurinol-300&t=1230",
    ])
    func anythingElseIsNotACard(text: String) {
        #expect(MedicationCard(text) == nil)
    }

    @Test func aCardAddsItsMedicationWithItsPhotosAndTimes() throws {
        let store = emptyStore()
        let outcome = store.outcome(ofCard: "mypharmacist://add?v=1&id=capecitabine-500&t=0900,2100")
        guard case .add(let entry) = outcome else {
            Issue.record("expected to add, got \(outcome)")
            return
        }
        #expect(entry.name == "Capecitabine")
        #expect(!entry.photos.isEmpty)
        #expect(entry.doseTimes == [DoseTime(9), DoseTime(21)])
        // Nothing yet: the person hasn't agreed.
        #expect(store.entries.isEmpty)

        store.apply(outcome)
        #expect(store.entries == [entry])
    }

    @Test func theKeychainRebuildsTheSampleList() {
        let store = emptyStore()
        for text in Self.keychain {
            store.apply(store.outcome(ofCard: text))
        }
        #expect(store.entries == SampleMedications.sampleList.map(\.tidied))
    }

    @Test func anEmptiedListIsFilledAgainFromTheCards() {
        let store = MedicationStore(entries: SampleMedications.sampleList, storage: InMemoryDoseLogStorage())
        store.removeAll()
        #expect(store.entries.isEmpty)
        #expect(store.medications.isEmpty)

        for text in Self.keychain {
            store.apply(store.outcome(ofCard: text))
        }
        #expect(store.entries == SampleMedications.sampleList.map(\.tidied))
    }

    @Test func aCardForAMedicationOnTheListOnlyChangesWhenItIsTaken() throws {
        let store = emptyStore()
        store.apply(store.outcome(ofCard: Self.keychain[0]))
        var mine = try #require(store.entry("capecitabine-500"))
        mine.purpose = "For my treatment"
        store.update(mine)

        #expect(store.outcome(ofCard: Self.keychain[0]) == .alreadyThere(mine))

        let outcome = store.outcome(ofCard: "mypharmacist://add?v=1&id=capecitabine-500&t=0800")
        guard case .changeSchedule(let changed) = outcome else {
            Issue.record("expected a change of schedule, got \(outcome)")
            return
        }
        #expect(changed.doseTimes == [DoseTime(8)])
        #expect(changed.purpose == "For my treatment")
        store.apply(outcome)
        #expect(store.entry("capecitabine-500") == changed)
        #expect(store.entries.count == 1)
    }

    @Test func aCardCanMakeAMedicationOnlyWhenNeeded() throws {
        let store = emptyStore()
        store.apply(store.outcome(ofCard: "mypharmacist://add?v=1&id=ondansetron-8&t=0800"))
        #expect(try #require(store.entry("ondansetron-8")).isAsNeeded == false)

        store.apply(store.outcome(ofCard: Self.keychain[3]))
        let entry = try #require(store.entry("ondansetron-8"))
        #expect(entry.isAsNeeded)
        #expect(entry.medication.asNeeded == "Only when you feel sick")
    }

    @Test func aCardForAnUnknownMedicationOrNoCardAtAllChangesNothing() {
        let store = emptyStore()
        for text in ["mypharmacist://add?v=1&id=aspirin-81&t=0800", "https://example.com", "hello"] {
            let outcome = store.outcome(ofCard: text)
            #expect(outcome == .notACard)
            store.apply(outcome)
        }
        #expect(store.entries.isEmpty)
    }
}
