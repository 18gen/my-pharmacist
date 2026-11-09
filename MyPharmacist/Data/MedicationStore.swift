//
//  MedicationStore.swift
//  MyPharmacist
//

import Foundation
import Observation

/// The person's medications and which doses have been scanned, saved on the device.
/// There is no "taken": the app only knows a dose's pill was scanned and judged OK to take.
///
/// Medications are chosen from a catalog of the ones the app has reference photos for, so
/// every medication on the list can be recognized in a scan. The list keeps only which
/// ones and when; the rest comes from the catalog.
@Observable
final class MedicationStore {
    /// What a medication taken only when needed says when its catalog entry doesn't.
    static let defaultAsNeeded = "Only when needed"

    /// Every medication that can be on the list, with the times each usually starts with.
    let catalog: [Medication]
    /// The catalog medications a new or restored list starts with.
    @ObservationIgnored private let startingIDs: [String]

    /// The person's list, in their order: which medications, and when.
    private(set) var plans: [MedicationPlan] {
        didSet {
            listStorage.save(plans)
            medications = Self.resolve(plans, catalog: catalog)
        }
    }

    /// The list as full medications, for the schedule, the home screen and scanning.
    private(set) var medications: [Medication]

    /// When each dose was scanned, keyed by "<day>|<Dose.id>", e.g. "2026-10-14|metformin-500@8:00".
    private var scanLog: [String: Date] {
        didSet { save() }
    }

    @ObservationIgnored private let storage: any DoseLogStorage
    @ObservationIgnored private let listStorage: any MedicationListStorage
    @ObservationIgnored private let calendar: Calendar
    /// Older records are dropped on launch; only today's matter.
    private static let keepDays = 14

    /// - Parameters:
    ///   - medications: The catalog.
    ///   - startingIDs: What a list that was never saved starts with; nil for the whole catalog.
    ///   - listStorage: In memory unless given, so tests never touch the app's saved list.
    ///   - now: When the store is created; records older than `keepDays` before it are dropped.
    init(medications: [Medication] = SampleMedications.all,
         startingIDs: [String]? = nil,
         listStorage: any MedicationListStorage = InMemoryMedicationListStorage(),
         storage: any DoseLogStorage = UserDefaultsDoseLogStorage(),
         calendar: Calendar = .current,
         now: Date = Date()) {
        let startingIDs = startingIDs ?? medications.map(\.id)
        let plans = listStorage.load() ?? Self.startingPlans(startingIDs, catalog: medications)
        self.catalog = medications
        self.startingIDs = startingIDs
        self.plans = plans
        self.medications = Self.resolve(plans, catalog: medications)
        self.listStorage = listStorage
        self.storage = storage
        self.calendar = calendar
        self.scanLog = Self.recent(storage.load(), now: now, calendar: calendar)
    }

    // MARK: Reading

    func doses(on day: Date) -> [Dose] {
        DoseSchedule.doses(for: medications, on: day, calendar: calendar)
    }

    /// Today's doses grouped by time of day, earliest first, each group with where it stands.
    func todaySlots(now: Date) -> [DoseSlot] {
        DoseSchedule.slots(doses(on: now), scannedAt: scanTimes(on: now), now: now)
    }

    /// Whether a time of day is due now: the scan button turns blue.
    func hasDoseDueNow(now: Date) -> Bool {
        todaySlots(now: now).contains { $0.status == .now }
    }

    /// Medications taken only when needed, which have no place in the day's slots.
    var asNeededMedications: [Medication] {
        medications.filter { $0.asNeeded != nil }
    }

    /// Today's doses in display order (pending first, earliest on top) with their states.
    func todayList(now: Date) -> [ScheduledDose] {
        let doses = doses(on: now)
        return DoseSchedule.ordered(doses, scannedAt: scanTimes(on: now), now: now)
    }

    // MARK: The medication list

    /// Catalog medications not on the list yet.
    var addable: [Medication] {
        catalog.filter { medication in !plans.contains { $0.medicationID == medication.id } }
    }

    func plan(for medicationID: String) -> MedicationPlan? {
        plans.first { $0.medicationID == medicationID }
    }

    func catalogEntry(_ medicationID: String) -> Medication? {
        catalog.first { $0.id == medicationID }
    }

    /// Adds a catalog medication at the end of the list. Ignored if it's already on it, not
    /// in the catalog, or set to times with none.
    func add(_ plan: MedicationPlan) {
        guard plan.isAsNeeded || !plan.orderedTimes.isEmpty,
              self.plan(for: plan.medicationID) == nil,
              catalogEntry(plan.medicationID) != nil else { return }
        plans.append(Self.tidy(plan))
    }

    /// Replaces a medication's times or switches it to only when needed. A plan with set
    /// times but none at all is ignored, so a medication never silently stops being due.
    func update(_ plan: MedicationPlan) {
        guard plan.isAsNeeded || !plan.orderedTimes.isEmpty,
              let index = plans.firstIndex(where: { $0.medicationID == plan.medicationID }) else { return }
        let tidied = Self.tidy(plan)
        if plans[index] != tidied {
            plans[index] = tidied
        }
    }

    /// Takes a medication off the list. Its scan records stay, but nothing reads them.
    func remove(_ medicationID: String) {
        plans.removeAll { $0.medicationID == medicationID }
    }

    /// Back to the sample list at its usual times, for starting a demo over.
    func restoreSampleList() {
        plans = Self.startingPlans(startingIDs, catalog: catalog)
    }

    private static func startingPlans(_ ids: [String], catalog: [Medication]) -> [MedicationPlan] {
        ids.compactMap { id in catalog.first { $0.id == id } }.map(MedicationPlan.init(preset:))
    }

    // MARK: Changing

    /// Records that these doses' pills were scanned, OK to take, at `time`.
    func recordScan(of doses: [Dose], at time: Date = Date()) {
        for dose in doses {
            scanLog[key(for: dose)] = time
        }
    }

    func removeScans(of doses: [Dose]) {
        for dose in doses {
            scanLog[key(for: dose)] = nil
        }
    }

    /// Decides which of the pills in a photo to take now, given what each was recognized as.
    func check(_ identities: [Medication?], now: Date = Date()) -> PillSetCheck {
        PillSetVerifier.check(identities, medications: medications, dayDoses: doses(on: now),
                              scannedAt: scanTimes(on: now), now: now)
    }

    // MARK: Storage

    private static func tidy(_ plan: MedicationPlan) -> MedicationPlan {
        var plan = plan
        plan.doseTimes = plan.orderedTimes
        return plan
    }

    /// The list as medications: each catalog entry with the plan's times, or none and its
    /// "only when" line when taken only when needed. Plans for medications no longer in the
    /// catalog are left out.
    private static func resolve(_ plans: [MedicationPlan], catalog: [Medication]) -> [Medication] {
        plans.compactMap { plan in
            guard let entry = catalog.first(where: { $0.id == plan.medicationID }) else { return nil }
            return Medication(
                id: entry.id,
                name: entry.name,
                strength: entry.strength,
                doseTimes: plan.isAsNeeded ? [] : plan.orderedTimes,
                appearance: entry.appearance,
                photos: entry.photos,
                purpose: entry.purpose,
                asNeeded: plan.isAsNeeded ? (entry.asNeeded ?? defaultAsNeeded) : nil
            )
        }
    }

    /// The given day's scan times keyed by `Dose.id`.
    private func scanTimes(on day: Date) -> [String: Date] {
        let prefix = Self.dayKey(day, calendar: calendar) + "|"
        var result: [String: Date] = [:]
        for (key, time) in scanLog where key.hasPrefix(prefix) {
            result[String(key.dropFirst(prefix.count))] = time
        }
        return result
    }

    private func key(for dose: Dose) -> String {
        Self.dayKey(dose.scheduled, calendar: calendar) + "|" + dose.id
    }

    private static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private func save() {
        storage.save(scanLog)
    }

    private static func recent(_ log: [String: Date], now: Date, calendar: Calendar) -> [String: Date] {
        let cutoff = calendar.date(byAdding: .day, value: -keepDays, to: now) ?? .distantPast
        return log.filter { $0.value >= cutoff }
    }
}
