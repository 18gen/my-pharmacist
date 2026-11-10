//
//  ScanResult+Presentation.swift
//  MyPharmacist
//

import SwiftUI

/// How serious one line of the results is. The results page lists them in this order,
/// most serious first, so a pill not to take is never below one that's fine.
enum ResultLevel: Int, CaseIterable, Comparable, Identifiable {
    /// Not one of the person's medications, or not recognized.
    case unknown
    /// One of theirs, but not to take now.
    case dontTake
    /// For the person to decide: a medication only for when it's needed, or a photo
    /// that may hold a pill that wasn't checked.
    case caution
    case ok

    var id: Int { rawValue }

    static func < (lhs: ResultLevel, rhs: ResultLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// The pill isn't to be taken now, so it goes back.
    var isPutBack: Bool { self < .caution }

    /// The section heading: what to do with these pills.
    var title: String {
        switch self {
        case .unknown: "Unknown – don't take"
        case .dontTake: "Don't take now"
        case .caution: "Caution"
        case .ok: "OK to take"
        }
    }

    /// Icon, colour and words together, so nothing relies on colour alone.
    var icon: String {
        switch self {
        case .unknown: "questionmark.circle.fill"
        case .dontTake: "xmark.circle.fill"
        case .caution: "exclamationmark.triangle.fill"
        case .ok: "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .unknown, .dontTake: Palette.danger
        case .caution: Palette.caution
        case .ok: Palette.ok
        }
    }

    /// The light tint behind a row of this level.
    var fill: Color {
        switch self {
        case .unknown, .dontTake: Palette.dangerFill
        case .caution: Palette.cautionFill
        case .ok: Palette.okFill
        }
    }
}

extension PillVerdict {
    var level: ResultLevel {
        switch self {
        case .take: .ok
        case .asNeeded: .caution
        case .unidentified: .unknown
        case .alreadyScanned, .tooEarly, .notScheduledToday, .extra: .dontTake
        }
    }

    /// One short line on why, under the medication's name.
    var reason: String {
        switch self {
        case .take(let dose): "\(dose.scheduled.shortTime) dose"
        case .alreadyScanned(_, let time, _): "Scanned at \(time.shortTime). You may have taken it."
        case .tooEarly(let next): "Next dose at \(next.scheduled.shortTime)"
        case .notScheduledToday: "Not for today"
        case .extra: "One is enough"
        case .unidentified: "Ask your pharmacist"
        case .asNeeded(let medication): medication.asNeeded ?? "Only when needed"
        }
    }
}

/// One line of the results: a pill from the photo, or a warning that the photo may hold
/// a pill that wasn't checked.
enum ResultLine: Identifiable {
    case pill(ScannedPill)
    case uncheckedPill

    var id: String {
        switch self {
        case .pill(let pill): "pill-\(pill.id)"
        case .uncheckedPill: "unchecked-pill"
        }
    }

    var level: ResultLevel {
        switch self {
        case .pill(let pill): pill.verdict.level
        case .uncheckedPill: .caution
        }
    }

    var title: String {
        switch self {
        case .pill(let pill): pill.medication?.displayName ?? "Unknown pill"
        case .uncheckedPill: "Another pill?"
        }
    }

    var reason: String {
        switch self {
        case .pill(let pill): pill.verdict.reason
        case .uncheckedPill: "The photo may have a pill that wasn't checked. Spread the pills and scan again."
        }
    }
}

/// The lines of one level, under one heading.
struct ResultGroup: Identifiable {
    let level: ResultLevel
    let lines: [ResultLine]

    var id: ResultLevel { level }
}

extension PillScanResult {
    /// Most serious first; empty levels are left out. Within a level, pills in reading
    /// order, then the unchecked-pill warning.
    var groups: [ResultGroup] {
        let lines = pills.map(ResultLine.pill) + (mayHaveMissedPill ? [.uncheckedPill] : [])
        return ResultLevel.allCases.compactMap { level in
            let matching = lines.filter { $0.level == level }
            return matching.isEmpty ? nil : ResultGroup(level: level, lines: matching)
        }
    }

    /// Pills that are unknown or not to take now.
    var putBackCount: Int {
        pills.filter { $0.verdict.level.isPutBack }.count
    }

    /// Something goes back, or a pill may not have been checked, so the next step is
    /// to scan again.
    var needsRescan: Bool { putBackCount > 0 || mayHaveMissedPill }

    /// Every pill is OK to take and no pill went unchecked: the success vibration.
    var isAllClear: Bool {
        !mayHaveMissedPill && pills.allSatisfy { $0.verdict.level == .ok }
    }

    /// What to do, in one line, for the header and VoiceOver.
    var summary: String {
        if putBackCount > 0 {
            return putBackCount == 1 ? "Put back 1 pill" : "Put back \(putBackCount) pills"
        }
        // Not "OK to take" while a pill in the photo may not have been checked.
        if mayHaveMissedPill { return "Scan again: a pill may be unchecked" }
        let okCount = dosesToTake.count
        if okCount == 0 { return "Check before taking" }
        if isAllClear { return okCount == 1 ? "OK to take this pill" : "OK to take all \(okCount)" }
        return okCount == 1 ? "OK to take 1 pill" : "OK to take \(okCount) pills"
    }

    /// The level whose icon goes with the summary.
    var summaryLevel: ResultLevel {
        if putBackCount > 0 { return .dontTake }
        return dosesToTake.isEmpty || mayHaveMissedPill ? .caution : .ok
    }
}
