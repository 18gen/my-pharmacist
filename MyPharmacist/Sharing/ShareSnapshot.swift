//
//  ShareSnapshot.swift
//  MyPharmacist
//

import Foundation

/// What the phone sends the pharmacy demo, whole, every time something changes: the
/// medications and the last 7 days of doses and scans. Format 1, as the dashboard checks
/// it (my-pharmacist-dashboard, src/lib/snapshot.ts).
///
/// Sending everything each time means a retry, a dose unticked or a reset needs nothing
/// special: the dashboard always shows what the phone has. Each dose's exact time is
/// worked out here with the phone's calendar, so the dashboard needs no time zones.
nonisolated struct ShareSnapshot: Encodable, Equatable, Sendable {
    /// The format's version.
    let v: Int
    let sentAt: Date
    /// The phone's time zone, like "America/Toronto": the dashboard shows times in it.
    let timeZone: String
    /// When a dose counts as due, and when as missed (`DoseSchedule`).
    let earlyWindowMinutes: Int
    let lateWindowMinutes: Int
    /// "2026-11-19" for each day, oldest first, today last.
    let days: [String]
    let medications: [SharedMedication]
    /// Every scheduled dose on those days, taken or not.
    let doses: [SharedDose]
    /// Medications taken only when needed, on the days they were taken.
    let asNeeded: [SharedAsNeeded]
    /// What each scan said about each pill.
    let scans: [SharedScan]

    struct SharedMedication: Encodable, Equatable, Sendable {
        let id: String
        let name: String
        let strength: String
        /// "08:30", in order; none for a medication taken only when needed.
        let times: [String]
        let asNeeded: Bool
    }

    struct SharedDose: Encodable, Equatable, Sendable {
        let day: String
        let medicationID: String
        let time: String
        let scheduledAt: Date
        /// Left out while it isn't taken.
        let takenAt: Date?
        let scanned: Bool

        enum CodingKeys: String, CodingKey {
            case day, time, scheduledAt, takenAt, scanned
            case medicationID = "medicationId"
        }
    }

    struct SharedAsNeeded: Encodable, Equatable, Sendable {
        let day: String
        let medicationID: String
        let takenAt: Date
        let scanned: Bool

        enum CodingKeys: String, CodingKey {
            case day, takenAt, scanned
            case medicationID = "medicationId"
        }
    }

    struct SharedScan: Encodable, Equatable, Sendable {
        let at: Date
        let pills: [SharedPill]
    }

    struct SharedPill: Encodable, Equatable, Sendable {
        /// Null, not left out, for a pill that wasn't recognized.
        let medicationID: String?
        let outcome: ScanReports.Outcome
        let takenAt: Date?
        let doseTime: String?

        enum CodingKeys: String, CodingKey {
            case outcome, takenAt, doseTime
            case medicationID = "medicationId"
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(medicationID, forKey: .medicationID)
            try container.encode(outcome, forKey: .outcome)
            try container.encodeIfPresent(takenAt, forKey: .takenAt)
            try container.encodeIfPresent(doseTime, forKey: .doseTime)
        }
    }

    /// What the dashboard accepts: more is left out rather than sent and refused.
    enum Limits {
        static let days = 7
        static let medications = CheckLimits.medications
        static let timesPerMedication = 12
        static let scans = 200
        static let pillsPerScan = CheckLimits.pills
    }

    /// As JSON, with times like "2026-11-19T19:41:03Z".
    func json() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
}

extension ShareSnapshot {
    /// What `store` and `reports` hold now, for the last 7 days.
    @MainActor
    static func make(store: MedicationStore, reports: ScanReports, now: Date) -> ShareSnapshot {
        let calendar = store.calendar
        let days = (-(Limits.days - 1)...0).compactMap { calendar.date(byAdding: .day, value: $0, to: now) }
        let dayKey = { (day: Date) in Dose.dayKey(day, calendar: calendar) }

        let medications = Array(store.medications.prefix(Limits.medications))
        let times = Dictionary(uniqueKeysWithValues: medications.map {
            ($0.id, Array($0.doseTimes.sorted().prefix(Limits.timesPerMedication)))
        })

        let doses = days.flatMap { day in
            store.doses(on: day).compactMap { dose -> SharedDose? in
                guard times[dose.medication.id]?.contains(dose.time) == true else { return nil }
                let state = store.state(of: dose)
                return SharedDose(day: dayKey(day), medicationID: dose.medication.id, time: clock(dose.time),
                                  scheduledAt: dose.scheduled, takenAt: state.takenAt, scanned: state.scannedAt != nil)
            }
        }

        let asNeeded = medications.filter { $0.asNeeded != nil }.flatMap { medication in
            days.compactMap { day -> SharedAsNeeded? in
                guard let takenAt = store.asNeededTaken(of: medication, on: day) else { return nil }
                return SharedAsNeeded(day: dayKey(day), medicationID: medication.id, takenAt: takenAt,
                                      scanned: store.asNeededScan(of: medication, on: day) != nil)
            }
        }

        let firstDay = days.first.map(calendar.startOfDay) ?? now
        let scans = reports.reports
            .filter { $0.at >= firstDay && !$0.pills.isEmpty }
            .suffix(Limits.scans)
            .map { report in
                SharedScan(at: report.at, pills: report.pills.prefix(Limits.pillsPerScan).map { pill in
                    SharedPill(medicationID: pill.medicationID, outcome: pill.outcome, takenAt: pill.takenAt,
                               doseTime: pill.doseTime.map(clock))
                })
            }

        return ShareSnapshot(
            v: 1,
            sentAt: now,
            timeZone: calendar.timeZone.identifier,
            earlyWindowMinutes: Int(DoseSchedule.earlyWindow / 60),
            lateWindowMinutes: Int(DoseSchedule.lateWindow / 60),
            days: days.map(dayKey),
            medications: medications.map { medication in
                SharedMedication(id: medication.id, name: medication.name, strength: medication.strength,
                                 times: (times[medication.id] ?? []).map(clock), asNeeded: medication.asNeeded != nil)
            },
            doses: doses,
            asNeeded: asNeeded,
            scans: Array(scans)
        )
    }

    /// "08:30" for 8:30 AM.
    private static func clock(_ time: DoseTime) -> String {
        String(format: "%02d:%02d", time.hour, time.minute)
    }
}
