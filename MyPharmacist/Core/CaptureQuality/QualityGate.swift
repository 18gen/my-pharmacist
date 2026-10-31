//
//  QualityGate.swift
//  MyPharmacist
//

/// Turns per-frame quality results into a calm status for the screen: an issue is only
/// shown after several bad frames in a row, and "ready" only after the picture has been
/// good for a while, so the hint doesn't flicker as the hand moves slightly.
nonisolated struct QualityGate {
    enum Status: Hashable, Sendable {
        /// Not enough frames yet to say anything.
        case checking
        case needs(QualityIssue)
        /// Good long enough to take the photo.
        case ready
    }

    /// Good frames in a row before "ready" (about 0.8 s at 10 checks a second).
    var readyAfter = 8
    /// Bad frames in a row before an issue is shown (about 0.3 s).
    var issueAfter = 3

    private(set) var status: Status = .checking
    private var goodStreak = 0
    private var badStreak = 0

    @discardableResult
    mutating func update(_ quality: FrameQuality) -> Status {
        if let issue = quality.topIssue {
            goodStreak = 0
            badStreak += 1
            if badStreak >= issueAfter {
                status = .needs(issue)
            }
        } else {
            badStreak = 0
            goodStreak += 1
            if goodStreak >= readyAfter {
                status = .ready
            }
        }
        return status
    }
}
