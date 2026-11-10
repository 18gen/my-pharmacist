//
//  MedicationStore.swift
//  MyPharmacist
//

import Foundation
import Observation

/// The person's medications and which doses have been scanned, saved on the device.
/// There is no "taken": the app only knows a dose's pill was scanned and judged OK to take.
///
/// The list holds everything about each medication (`MedicationEntry`), including the
/// photos of its tablet that scanned pills are compared with.
@Observable
final class MedicationStore {
    /// The person's list, in their order.
    private(set) var entries: [MedicationEntry] {
        didSet {
            listStorage.save(entries)
            medications = entries.map(\.medication)
        }
    }

    /// The list as the schedule, the home screen and scanning see it.
    private(set) var medications: [Medication]

    /// When each dose was scanned, keyed by `Dose.id`, e.g. "2026-10-14|metformin-500@8:00".
    private var scanLog: [String: Date] {
        didSet { save() }
    }

    @ObservationIgnored private let storage: any DoseLogStorage
    @ObservationIgnored private let listStorage: any MedicationListStorage
    @ObservationIgnored private let photoStore: MedicationPhotoStore
    /// What "Load sample list" puts on the list.
    @ObservationIgnored private let sampleList: [MedicationEntry]
    @ObservationIgnored private let calendar: Calendar
    /// Older records are dropped on launch; only today's matter.
    private static let keepDays = 14

    /// - Parameters:
    ///   - entries: What a list that was never saved starts with: nothing, for a new person.
    ///   - sampleList: What "Load sample list" puts on the list.
    ///   - listStorage: In memory unless given, so tests never touch the app's saved list.
    ///   - now: When the store is created; records older than `keepDays` before it are dropped.
    init(entries: [MedicationEntry] = [],
         sampleList: [MedicationEntry] = SampleMedications.sampleList,
         listStorage: any MedicationListStorage = InMemoryMedicationListStorage(),
         storage: any DoseLogStorage = UserDefaultsDoseLogStorage(),
         photoStore: MedicationPhotoStore = .standard,
         calendar: Calendar = .current,
         now: Date = Date()) {
        let entries = (listStorage.load() ?? entries).map(\.tidied)
        self.entries = entries
        self.medications = entries.map(\.medication)
        self.sampleList = sampleList
        self.listStorage = listStorage
        self.storage = storage
        self.photoStore = photoStore
        self.calendar = calendar
        self.scanLog = Self.recent(storage.load(), now: now, calendar: calendar)
    }

    /// A store whose list starts with these medications, for tests and previews.
    convenience init(medications: [Medication],
                     listStorage: any MedicationListStorage = InMemoryMedicationListStorage(),
                     storage: any DoseLogStorage = UserDefaultsDoseLogStorage(),
                     calendar: Calendar = .current,
                     now: Date = Date()) {
        self.init(entries: medications.map(MedicationEntry.init), listStorage: listStorage, storage: storage,
                  calendar: calendar, now: now)
    }

    // MARK: Reading

    func doses(on day: Date) -> [Dose] {
        DoseSchedule.doses(for: medications, on: day, calendar: calendar)
    }

    /// Today's doses grouped by time of day, earliest first, each group with where it
    /// stands. A time of day from the day before or after that is due now comes too: at
    /// 11:30 PM the 12 AM dose is due, though it's tomorrow's.
    func todaySlots(now: Date) -> [DoseSlot] {
        let today = DoseSchedule.slots(doses(on: now), scannedAt: scanLog, now: now)
        func dueNow(dayOffset: Int) -> [DoseSlot] {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now) else { return [] }
            return DoseSchedule.slots(doses(on: day), scannedAt: scanLog, now: now).filter { $0.status == .now }
        }
        return dueNow(dayOffset: -1) + today + dueNow(dayOffset: 1)
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
        DoseSchedule.ordered(doses(on: now), scannedAt: scanLog, now: now)
    }

    // MARK: The medication list

    func entry(_ id: String) -> MedicationEntry? {
        entries.first { $0.id == id }
    }

    /// Adds a medication at the end of the list. Ignored, returning false, if it isn't
    /// valid (`MedicationEntry.isValid`) or is already on it.
    @discardableResult
    func add(_ entry: MedicationEntry) -> Bool {
        guard entry.isValid, self.entry(entry.id) == nil else { return false }
        entries.append(entry.tidied)
        return true
    }

    /// Replaces a medication on the list. Ignored if it isn't valid, so a medication never
    /// silently stops being due. Photos it no longer has are deleted.
    func update(_ entry: MedicationEntry) {
        guard entry.isValid, let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        let tidied = entry.tidied
        guard entries[index] != tidied else { return }
        deletePhotos(entries[index].photos.filter { !tidied.photos.contains($0) })
        entries[index] = tidied
    }

    /// Takes a medication off the list, with its photos. Its scan records stay, but
    /// nothing reads them.
    func remove(_ id: String) {
        guard let entry = entry(id) else { return }
        deletePhotos(entry.photos)
        entries.removeAll { $0.id == id }
    }

    /// Replaces the list with the sample list, for demos and App Review. The photos of
    /// the medications it replaces are deleted.
    func loadSampleList() {
        deletePhotos(entries.flatMap(\.photos))
        entries = sampleList.map(\.tidied)
    }

    private func deletePhotos(_ photos: [MedicationPhoto]) {
        photos.forEach(photoStore.delete)
    }

    // MARK: Changing

    /// Records that these doses' pills were scanned, OK to take, at `time`.
    func recordScan(of doses: [Dose], at time: Date = Date()) {
        for dose in doses {
            scanLog[dose.id] = time
        }
    }

    func removeScans(of doses: [Dose]) {
        for dose in doses {
            scanLog[dose.id] = nil
        }
    }

    /// Decides which of the pills in a photo to take now, given what each was recognized as.
    func check(_ identities: [Medication?], now: Date = Date()) -> PillSetCheck {
        PillSetVerifier.check(identities, medications: medications,
                              doses: DoseSchedule.doses(for: medications, around: now, calendar: calendar),
                              scannedAt: scanLog, now: now)
    }

    // MARK: Storage

    private func save() {
        storage.save(scanLog)
    }

    private static func recent(_ log: [String: Date], now: Date, calendar: Calendar) -> [String: Date] {
        let cutoff = calendar.date(byAdding: .day, value: -keepDays, to: now) ?? .distantPast
        return log.filter { $0.value >= cutoff }
    }
}
