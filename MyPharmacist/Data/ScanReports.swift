//
//  ScanReports.swift
//  MyPharmacist
//

import CoreGraphics
import Foundation
import Observation

/// What each scan said about each pill, for the last 7 days, saved on the device: what
/// sharing with the pharmacy demo shows as "told not to take" and "a pill that isn't on
/// the list". The doses a scan marked taken are in `MedicationStore`'s record already.
///
/// One report per scanning session (from opening the camera to closing it): a photo taken
/// again replaces the session's report, so a retake is never counted twice.
///
/// Each pill's cut-out from the scan is kept with it in memory only, never saved, under
/// the ID its report gives it: sharing sends it to the pharmacy demo, which shows the pill
/// as the scan saw it. After the app is closed only the IDs remain.
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
        /// For "missed" and "too early": the time of the dose it was judged against; for
        /// "take", the dose it ticked.
        var doseTime: DoseTime?
        /// The pill's cut-out from the scan, in `photos` while the app is open.
        var photoID: UUID?
    }

    /// `PillVerdict` without what it carries, "unidentified" as "unknown".
    nonisolated enum Outcome: String, Codable, Sendable {
        case take, alreadyTaken, missed, tooEarly, notScheduledToday, extra, unknown, asNeeded
    }

    /// Reports from today and the 6 days before are kept: the week the pharmacy demo sees.
    static let keptDays = 7
    /// At most this many, the latest.
    static let keptCount = 100
    /// At most this many cut-outs are kept in memory, the latest scans'.
    static let keptPhotos = 60
    private static let key = "scanReports.v1"

    /// Oldest first.
    private(set) var reports: [Report] {
        didSet {
            defaults?.save(reports, forKey: Self.key)
            onChange?()
        }
    }

    /// The cut-outs of the pills in the latest reports, by their `photoID`. In memory only.
    @ObservationIgnored private(set) var photos: [UUID: CGImage] = [:]

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

    /// Adds a scan's report, replacing an earlier one from the same session, with the
    /// cut-outs of its pills by their `photoID`. A replaced report's cut-outs are forgotten.
    func record(_ report: Report, photos added: [UUID: CGImage] = [:], now: Date = Date()) {
        let kept = Self.kept(reports.filter { $0.session != report.session } + [report], now: now, calendar: calendar)
        // The latest reports' pictures, up to the most kept: set before the reports, whose
        // change sends them.
        var wanted: [UUID] = []
        for pill in kept.reversed().flatMap({ $0.pills.reversed() }) {
            guard let id = pill.photoID, wanted.count < Self.keptPhotos else { continue }
            wanted.append(id)
        }
        let everything = photos.merging(added) { _, new in new }
        photos = Dictionary(uniqueKeysWithValues: wanted.compactMap { id in everything[id].map { (id, $0) } })
        reports = kept
    }

    /// Forgets every report and picture: "Reset demo".
    func removeAll() {
        photos = [:]
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
        case .take(let dose):
            self.init(medicationID: medicationID, outcome: .take, doseTime: dose.time)
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
