//
//  MedicationStore.swift
//  MyPharmacist
//

import CoreGraphics
import Foundation
import Observation

/// The person's medications and the record of the doses they took, saved on the device.
///
/// The list holds everything about each medication (`MedicationEntry`), including the
/// photos of its tablet that scanned pills are compared with. The record (`DoseLog`) says
/// which doses were taken and which of those were scanned: a scan of a pill OK to take
/// marks its dose taken.
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

    /// Which doses were taken and scanned.
    private var doseLog: DoseLog {
        didSet { logStorage.save(doseLog.entries) }
    }

    /// The picture of each scanned pill, cut from the scan's photo. Kept in memory only,
    /// never saved: after the app is closed a scanned dose shows its medication's own
    /// photo instead.
    private var scanPhotos: [DoseLog.Key: CGImage] = [:]

    @ObservationIgnored private let logStorage: any DoseLogStorage
    @ObservationIgnored private let listStorage: any MedicationListStorage
    @ObservationIgnored let photoStore: MedicationPhotoStore
    /// What "Reset demo" puts on the list.
    @ObservationIgnored private let sampleList: [MedicationEntry]
    @ObservationIgnored private let calendar: Calendar
    /// Older records are dropped on launch; only the last few days matter.
    private static let keepDays = 14

    /// - Parameters:
    ///   - entries: What a list that was never saved starts with: the app gives a new
    ///     install the sample list.
    ///   - sampleList: What "Reset demo" puts on the list.
    ///   - listStorage: In memory unless given, so tests never touch the app's saved list.
    ///   - logStorage: In memory unless given, for the same reason.
    ///   - calendar: Follows the phone's time zone as it changes, unless one is given.
    ///   - now: When the store is created; records older than `keepDays` before it are dropped.
    init(entries: [MedicationEntry] = [],
         sampleList: [MedicationEntry] = SampleMedications.sampleList,
         listStorage: any MedicationListStorage = InMemoryMedicationListStorage(),
         logStorage: any DoseLogStorage = InMemoryDoseLogStorage(),
         photoStore: MedicationPhotoStore = .standard,
         calendar: Calendar = .autoupdatingCurrent,
         now: Date = Date()) {
        let entries = (listStorage.load() ?? entries).map(\.tidied)
        self.entries = entries
        self.medications = entries.map(\.medication)
        self.sampleList = sampleList
        self.listStorage = listStorage
        self.logStorage = logStorage
        self.photoStore = photoStore
        self.calendar = calendar
        self.doseLog = DoseLog(saved: logStorage.load(), now: now, keepDays: Self.keepDays, calendar: calendar)
    }

    /// A store whose list starts with these medications, for tests and previews.
    convenience init(medications: [Medication],
                     listStorage: any MedicationListStorage = InMemoryMedicationListStorage(),
                     logStorage: any DoseLogStorage = InMemoryDoseLogStorage(),
                     calendar: Calendar = .autoupdatingCurrent,
                     now: Date = Date()) {
        self.init(entries: medications.map(MedicationEntry.init), listStorage: listStorage, logStorage: logStorage,
                  calendar: calendar, now: now)
    }

    // MARK: Today

    func doses(on day: Date) -> [Dose] {
        DoseSchedule.doses(for: medications, on: day, calendar: calendar)
    }

    /// Today's doses grouped by time of day, earliest first, each group with where it
    /// stands. A time of day from the day before or after comes too while it is inside
    /// its window: at 11:30 PM the 12 AM dose is due, though it's tomorrow's, and it stays
    /// once ticked.
    func todaySlots(now: Date) -> [DoseSlot] {
        func slots(dayOffset: Int) -> [DoseSlot] {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now) else { return [] }
            return DoseSchedule.slots(doses(on: day), scannedAt: doseLog.scans, takenAt: doseLog.takenMarks, now: now)
        }
        let inWindow = { (slot: DoseSlot) in DoseSchedule.isInWindow(slot.scheduled, now: now) }
        return slots(dayOffset: -1).filter(inWindow) + slots(dayOffset: 0) + slots(dayOffset: 1).filter(inWindow)
    }

    /// Whether a time of day is due now: the scan button turns blue.
    func hasDoseDueNow(now: Date) -> Bool {
        todaySlots(now: now).contains { $0.status == .now }
    }

    /// Medications taken only when needed, which have no place in the day's slots.
    var asNeededMedications: [Medication] {
        medications.filter { $0.asNeeded != nil }
    }

    // MARK: The medication list

    func entry(_ id: String) -> MedicationEntry? {
        entries.first { $0.id == id }
    }

    /// Adds a medication at the end of the list. Ignored, returning false, if it isn't
    /// valid (`MedicationEntry.isValid`), is already on it, or the list is full.
    @discardableResult
    func add(_ entry: MedicationEntry) -> Bool {
        guard entry.isValid, self.entry(entry.id) == nil, canAddMore else { return false }
        entries.append(entry.tidied)
        return true
    }

    /// Whether another medication fits: a scan compares pills with at most
    /// `CheckLimits.medications` of them.
    var canAddMore: Bool {
        entries.count < CheckLimits.medications
    }

    /// Replaces a medication on the list. Ignored if it isn't valid, so a medication never
    /// silently stops being due. Photos it no longer has are deleted. A dose time changed
    /// after today's dose was taken keeps the tick: it moves to the new time.
    func update(_ entry: MedicationEntry, now: Date = Date()) {
        guard entry.isValid, let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        let tidied = entry.tidied
        let old = entries[index]
        guard old != tidied else { return }
        deletePhotos(old.photos.filter { !tidied.photos.contains($0) })
        moveTodaysRecord(from: old.medication, to: tidied.medication, now: now)
        entries[index] = tidied
    }

    /// Takes a medication off the list, with its photos. What was recorded about its doses
    /// stays until it is too old to keep: if the medication is added back today, today's
    /// doses it was taken for are still taken.
    func remove(_ id: String) {
        guard let entry = entry(id) else { return }
        deletePhotos(entry.photos)
        entries.removeAll { $0.id == id }
    }

    /// Replaces the list with the sample list and forgets every dose taken, for demos and
    /// App Review. The photos of the medications it replaces are deleted.
    func resetToSamples() {
        deletePhotos(entries.flatMap(\.photos))
        entries = sampleList.map(\.tidied)
        doseLog.removeAll()
        scanPhotos = [:]
    }

    /// Deletes photo files that no medication on the list uses: left behind when the app
    /// was closed while a medication was being added, say.
    func removeUnusedPhotos() {
        photoStore.removeAll(except: Set(entries.flatMap(\.photos)))
    }

    private func deletePhotos(_ photos: [MedicationPhoto]) {
        photos.forEach(photoStore.delete)
    }

    /// Today's doses whose times were changed take what was recorded about them to the new
    /// times, removed and added times paired in order: 8:00 moved to 8:30 stays taken.
    private func moveTodaysRecord(from old: Medication, to new: Medication, now: Date) {
        let removed = old.doseTimes.filter { !new.doseTimes.contains($0) }.sorted()
        let added = new.doseTimes.filter { !old.doseTimes.contains($0) }.sorted()
        for (from, to) in zip(removed, added) {
            let source = DoseLog.Key.dose(Dose(medication: old, time: from, day: now, calendar: calendar))
            let destination = DoseLog.Key.dose(Dose(medication: new, time: to, day: now, calendar: calendar))
            doseLog.move(source, to: destination)
            scanPhotos[destination] = scanPhotos.removeValue(forKey: source)
        }
    }

    // MARK: Doses taken

    /// A scan found these doses' pills OK to take at `time`: they are marked taken then.
    /// Each keeps the picture of its pill from the scan, if given.
    func recordScan(of doses: [Dose], at time: Date = Date(), photos: [Dose: CGImage] = [:]) {
        for dose in doses {
            doseLog.markScanned(.dose(dose), at: time)
            scanPhotos[.dose(dose)] = photos[dose]
        }
    }

    /// The person ticked these doses as taken, at `time`, without a scan.
    func markTaken(_ doses: [Dose], at time: Date = Date()) {
        for dose in doses {
            doseLog.markTaken(.dose(dose), at: time)
        }
    }

    /// Not taken after all: the tick, the scan and its picture go, so the next scan of the
    /// pill says to take it.
    func markNotTaken(_ doses: [Dose]) {
        for dose in doses {
            doseLog.markNotTaken(.dose(dose))
            scanPhotos[.dose(dose)] = nil
        }
    }

    /// The picture of a dose's pill from its scan; nil if it wasn't scanned since the app opened.
    func scanPhoto(of dose: Dose) -> CGImage? {
        scanPhotos[.dose(dose)]
    }

    // MARK: Medications taken only when needed

    /// When a medication taken only when needed was marked taken on a day; nil if it wasn't.
    func asNeededTaken(of medication: Medication, on day: Date) -> Date? {
        doseLog.takenAt(asNeededKey(medication, on: day))
    }

    /// When its pill was scanned that day, which marked it taken; nil if it wasn't.
    func asNeededScan(of medication: Medication, on day: Date) -> Date? {
        doseLog.scannedAt(asNeededKey(medication, on: day))
    }

    /// The picture of its pill from that scan, while the app stays open.
    func asNeededScanPhoto(of medication: Medication, on day: Date) -> CGImage? {
        scanPhotos[asNeededKey(medication, on: day)]
    }

    /// A scan found its pill at `time` on `day`, which marks it taken.
    func recordAsNeededScan(of medication: Medication, at time: Date, photo: CGImage?) {
        let key = asNeededKey(medication, on: time)
        doseLog.markScanned(key, at: time)
        scanPhotos[key] = photo
    }

    /// The person ticked it as taken on `day`, at `time`, without a scan.
    func markAsNeededTaken(_ medication: Medication, on day: Date, at time: Date = Date()) {
        doseLog.markTaken(asNeededKey(medication, on: day), at: time)
    }

    /// Not taken after all on `day`: the tick, the scan and its picture go.
    func markAsNeededNotTaken(_ medication: Medication, on day: Date) {
        let key = asNeededKey(medication, on: day)
        doseLog.markNotTaken(key)
        scanPhotos[key] = nil
    }

    private func asNeededKey(_ medication: Medication, on day: Date) -> DoseLog.Key {
        .asNeeded(medication.id, on: day, calendar: calendar)
    }

    // MARK: Checking pills

    /// Decides which of the pills in a photo to take now, given what each was recognized
    /// as: one verdict per pill, in order.
    /// - Parameter ignored: What the same scanning session recorded a moment ago, judged as
    ///   if it hadn't been: a photo taken again shows the same pills, still to take.
    func verdicts(for identities: [Medication?], now: Date = Date(),
                  ignoring ignored: ScanSessionRecord = ScanSessionRecord()) -> [PillVerdict] {
        let log = doseLog.removing(ignored.keys(calendar: calendar))
        return PillSetVerifier.check(identities, doses: DoseSchedule.doses(for: medications, around: now, calendar: calendar),
                                     scannedAt: log.scans, takenAt: log.takenMarks, now: now)
    }
}
