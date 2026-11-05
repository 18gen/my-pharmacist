//
//  QualityGate.swift
//  MyPharmacist
//

/// Turns per-frame quality results into a calm status for the screen: an issue is only
/// shown after several bad frames in a row, and "ready" only after the picture has been
/// good for a while, so the hint doesn't flicker as the hand moves slightly. No issue is
/// shown in the first moments either, while the person is still bringing the pills into view.
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
    /// Frames at the start with no issue shown (about 2 s), so the first thing the person
    /// reads is what to do, not what's wrong. A good picture can still be ready sooner.
    var quietStart = 20

    private(set) var status: Status = .checking
    private var framesSeen = 0
    private var goodStreak = 0
    private var badStreak = 0

    @discardableResult
    mutating func update(_ quality: FrameQuality) -> Status {
        framesSeen += 1
        if let issue = quality.topIssue {
            goodStreak = 0
            badStreak += 1
            if badStreak >= issueAfter, framesSeen > quietStart {
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
