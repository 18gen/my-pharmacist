//
//  ScanReports.swift
//  MyPharmacist
//

import Foundation
import Observation

/// What each scan said about each pill, for the last 7 days, saved on the device: what
/// sharing with the pharmacy demo shows as "told not to take" and "a pill that isn't on
/// the list". The doses a scan marked taken are in `MedicationStore`'s record already.
///
/// One report per scanning session (from opening the camera to closing it): a photo taken
/// again replaces the session's report, so a retake is never counted twice.
@Observable
final class ScanReports {
    nonisolated struct Report: Codable, Equatable, Sendable {
        let session: UUID
        let at: Date
        let pills: [Pill]
    }

    /// What the scan said about one pill.
    nonisolated struct Pill: Codable, Equatable, Sendable {
        /// Nil for a pill that wasn't recognized as one of the person's medications.
        let medicationID: String?
        let outcome: Outcome
        /// For "already taken": when the dose was taken.
        var takenAt: Date?
        /// For "missed" and "too early": the time of the dose it was judged against.
        var doseTime: DoseTime?
    }

    /// `PillVerdict` without what it carries, "unidentified" as "unknown".
    nonisolated enum Outcome: String, Codable, Sendable {
        case take, alreadyTaken, missed, tooEarly, notScheduledToday, extra, unknown, asNeeded
    }

    /// Reports from today and the 6 days before are kept: the week the pharmacy demo sees.
    static let keptDays = 7
    /// At most this many, the latest.
    static let keptCount = 100
    private static let key = "scanReports.v1"

    /// Oldest first.
    private(set) var reports: [Report] {
        didSet {
            defaults?.save(reports, forKey: Self.key)
            onChange?()
        }
    }

    /// Called after a report is added or they are cleared: sharing sends them again.
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private let defaults: UserDefaults?
    @ObservationIgnored private let calendar: Calendar

    /// - Parameters:
    ///   - defaults: Where they are saved; nil keeps them in memory, for tests and demos.
    ///   - now: Reports from before the kept days are dropped as of this time.
    init(defaults: UserDefaults? = nil, calendar: Calendar = .autoupdatingCurrent, now: Date = Date()) {
        self.defaults = defaults
        self.calendar = calendar
        var saved: [Report] = []
        if case .value(let value) = defaults?.saved([Report].self, forKey: Self.key) { saved = value }
        self.reports = Self.kept(saved, now: now, calendar: calendar)
    }

    /// Adds a scan's report, replacing an earlier one from the same session.
    func record(_ report: Report, now: Date = Date()) {
        reports = Self.kept(reports.filter { $0.session != report.session } + [report], now: now, calendar: calendar)
    }

    /// Forgets every report: "Reset demo".
    func removeAll() {
        reports = []
    }

    private static func kept(_ reports: [Report], now: Date, calendar: Calendar) -> [Report] {
        let firstDay = calendar.date(byAdding: .day, value: -(keptDays - 1), to: calendar.startOfDay(for: now)) ?? now
        return Array(reports.filter { $0.at >= firstDay }.sorted { $0.at < $1.at }.suffix(keptCount))
    }
}

extension ScanReports.Pill {
    /// What a verdict says about a pill recognized as `medicationID`.
    nonisolated init(medicationID: String?, verdict: PillVerdict) {
        switch verdict {
        case .take:
            self.init(medicationID: medicationID, outcome: .take)
        case .alreadyTaken(_, let time, _):
            self.init(medicationID: medicationID, outcome: .alreadyTaken, takenAt: time)
        case .missed(let dose, _):
            self.init(medicationID: medicationID, outcome: .missed, doseTime: dose.time)
        case .tooEarly(let next):
            self.init(medicationID: medicationID, outcome: .tooEarly, doseTime: next.time)
        case .notScheduledToday:
            self.init(medicationID: medicationID, outcome: .notScheduledToday)
        case .extra:
            self.init(medicationID: medicationID, outcome: .extra)
        case .unidentified:
            self.init(medicationID: nil, outcome: .unknown)
        case .asNeeded:
            self.init(medicationID: medicationID, outcome: .asNeeded)
        }
    }
}
