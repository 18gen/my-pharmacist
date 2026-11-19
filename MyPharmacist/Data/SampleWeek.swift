//
//  SampleWeek.swift
//  MyPharmacist
//

import Foundation

/// "Reset demo → With a sample week": the sample medications at times that put a dose due
/// at the moment it is pressed, and the six days before filled in. The same story every
/// time, so a demo can count on it, and so the pharmacy demo's dashboard has a week to show:
/// three missed doses, two pills the app said not to take, one not on the list, and the
/// when-needed tablet twice. It mirrors the dashboard's made-up Maria
/// (my-pharmacist-dashboard, scripts/sample-people.ts).
nonisolated enum SampleWeek {
    /// The sample list's two times of day as moved: `first` for the medications taken at
    /// 12:30 PM, `second` for those at 8 PM.
    struct Times: Equatable {
        let first: DoseTime
        let second: DoseTime
        /// `first` is earlier today and already taken; otherwise `first` is the one due now.
        let firstIsEarlierToday: Bool
    }

    /// Hours between the two times of day: a morning and an afternoon dose, say.
    static let gapMinutes = 6 * 60

    /// With N the time rounded down to 5 minutes: from noon, the 12:30 PM medications at
    /// N − 6 h (taken this morning) and the 8 PM ones at N (due now); before noon, the
    /// 12:30 PM ones at N (due now) and the 8 PM ones at N + 6 h. Both stay within the day.
    static func times(at now: Date, calendar: Calendar) -> Times {
        let parts = calendar.dateComponents([.hour, .minute], from: now)
        let minutes = (parts.hour ?? 12) * 60 + (parts.minute ?? 0) / 5 * 5
        if minutes >= 12 * 60 {
            return Times(first: time(minutes - gapMinutes), second: time(minutes), firstIsEarlierToday: true)
        }
        return Times(first: time(minutes), second: time(minutes + gapMinutes), firstIsEarlierToday: false)
    }

    /// The sample list with its 12:30 PM times moved to `first` and its 8 PM times to `second`.
    static func list(_ samples: [MedicationEntry] = SampleMedications.sampleList, times: Times) -> [MedicationEntry] {
        samples.map { sample in
            var entry = sample
            entry.doseTimes = sample.doseTimes.map { $0 < DoseTime(16) ? times.first : times.second }
            return entry
        }
    }

    /// Minutes after its time each dose was taken, in turn, so the week looks lived in.
    private static let delays = [3, 11, 6, 18, 9, 4, 22, 7]

    /// Replaces the list with the moved sample list and fills in the week before `now`: every
    /// dose taken a few minutes after its time, by a scan, except
    /// - 5 days ago, the first time of day ticked by hand; the when-needed tablet taken; an
    ///   allopurinol scanned 2 hours early ("too early");
    /// - 4 days ago, the second time of day missed;
    /// - 3 days ago, a second capecitabine scanned 45 minutes after the first ("already taken");
    /// - 2 days ago, the dexamethasone missed;
    /// - yesterday, the when-needed tablet taken, and a pill not on the list scanned.
    ///
    /// Today, from noon, the first time of day is taken; the one due now is left for the demo.
    @MainActor
    static func fill(_ store: MedicationStore, reports: ScanReports, now: Date) {
        let calendar = store.calendar
        let times = times(at: now, calendar: calendar)
        store.reset(to: list(times: times))
        reports.removeAll()
        func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: now) ?? now }
        func minutes(_ count: Int) -> TimeInterval { TimeInterval(count * 60) }

        var turn = 0
        for offset in -6...0 {
            for dose in store.doses(on: day(offset)) {
                let delay = delays[turn % delays.count]
                turn += 1
                let isFirst = dose.time == times.first
                if offset == 0 {
                    if times.firstIsEarlierToday && isFirst {
                        store.recordScan(of: [dose], at: dose.scheduled.addingTimeInterval(minutes(4)))
                    }
                    continue
                }
                if offset == -4 && !isFirst { continue }
                if offset == -2 && dose.medication.id == "dexamethasone-4" { continue }
                let taken = dose.scheduled.addingTimeInterval(minutes(delay))
                if offset == -5 && isFirst {
                    store.markTaken([dose], at: taken)
                } else {
                    store.recordScan(of: [dose], at: taken)
                }
            }
        }

        if let whenNeeded = store.medications.first(where: { $0.asNeeded != nil }) {
            for (offset, time) in [(-5, DoseTime(14, 30)), (-1, DoseTime(20, 2))] {
                store.recordAsNeededScan(of: whenNeeded, at: time.date(on: day(offset), calendar: calendar), photo: nil)
            }
        }

        func dose(_ offset: Int, _ id: String, _ time: DoseTime) -> Dose? {
            store.doses(on: day(offset)).first { $0.medication.id == id && $0.time == time }
        }
        func scan(at time: Date, _ pill: ScanReports.Pill) {
            reports.record(ScanReports.Report(session: UUID(), at: time, pills: [pill]), now: now)
        }
        if let allopurinol = dose(-5, "allopurinol-300", times.second) {
            scan(at: allopurinol.scheduled.addingTimeInterval(-minutes(120)),
                 ScanReports.Pill(medicationID: "allopurinol-300", outcome: .tooEarly, doseTime: times.second))
        }
        if let capecitabine = dose(-3, "capecitabine-500", times.first), let taken = store.state(of: capecitabine).takenAt {
            scan(at: capecitabine.scheduled.addingTimeInterval(minutes(45)),
                 ScanReports.Pill(medicationID: "capecitabine-500", outcome: .alreadyTaken, takenAt: taken))
        }
        if let evening = dose(-1, "capecitabine-500", times.second) {
            scan(at: evening.scheduled.addingTimeInterval(minutes(60)), ScanReports.Pill(medicationID: nil, outcome: .unknown))
        }
    }

    private static func time(_ minutes: Int) -> DoseTime {
        DoseTime(minutes / 60, minutes % 60)
    }
}
