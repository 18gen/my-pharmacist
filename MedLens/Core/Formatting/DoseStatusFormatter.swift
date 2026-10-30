//
//  DoseStatusFormatter.swift
//  MedLens
//

import Foundation

/// The short status under each checkbox ("2 hr", "Now", "1 hr late", "8:02 AM") and its
/// spoken VoiceOver form.
nonisolated enum DoseStatusFormatter {
    /// What the checkbox column shows. A taken dose shows only its time, because the
    /// "Taken" section header says what that time means.
    static func shortStatus(state: DoseState, scheduled: Date, now: Date) -> String {
        switch state {
        case .upcoming: return duration(scheduled.timeIntervalSince(now))
        case .due: return "Now"
        case .late: return "\(duration(now.timeIntervalSince(scheduled))) late"
        case .taken(let time): return time.shortTime
        }
    }

    static func spokenStatus(state: DoseState, scheduled: Date, now: Date) -> String {
        func spoken(_ seconds: TimeInterval) -> String {
            duration(seconds).replacingOccurrences(of: "hr", with: "hours").replacingOccurrences(of: "min", with: "minutes")
        }
        switch state {
        case .upcoming: return "Not taken. Due in \(spoken(scheduled.timeIntervalSince(now)))"
        case .due: return "Not taken. Due now"
        case .late: return "Not taken. \(spoken(now.timeIntervalSince(scheduled))) late"
        case .taken(let time): return "Taken at \(time.shortTime)"
        }
    }

    /// Rounded to whole minutes under an hour, otherwise whole hours.
    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        if minutes < 60 { return "\(max(minutes, 1)) min" }
        return "\(Int((Double(minutes) / 60).rounded())) hr"
    }
}
