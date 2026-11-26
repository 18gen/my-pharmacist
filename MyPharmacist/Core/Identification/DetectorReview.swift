//
//  DetectorReview.swift
//  MyPharmacist
//

import CoreGraphics

/// One pill the trained detector sees in the picture that was searched.
nonisolated struct PillDetection: Sendable, Equatable {
    /// In the searched picture's pixels, origin at the top left.
    let box: CGRect
    /// How sure the detector is, 0 to 1.
    let confidence: Float
}

/// The trained detector's second opinion on what Vision and colour found. It sees pills
/// lying against or over each other, which the two ways find poorly, and pills the
/// colour of the hand. Where the two disagree near other pills, the photo is taken again
/// with the pills spread apart: a pill left out without a word is the worst outcome, and
/// spreading the pills is easy to do.
nonisolated enum DetectorReview {
    /// Starting points, to be tuned on real photos (tools/pill-bench).
    struct Settings: Sendable {
        /// Detections less sure than this are left out altogether.
        var leastConfidence: Float = 0.3
        /// A pill only the detector saw, away from other pills, is added (as doubtful)
        /// when the detector is at least this sure.
        var sureConfidence: Float = 0.6
        /// Two detected pills whose boxes share more than this of the smaller box lie
        /// over each other.
        var overlapping = 0.3
        /// A box this close to another, as a share of the smaller pill's width, may be
        /// touching it.
        var nearness = 0.15
    }

    enum Outcome: Equatable {
        /// The detector agrees, or has nothing to add.
        case keep
        /// Pills only the detector saw, each away from others: added as doubtful, for
        /// the checker to confirm.
        case add([CGRect])
        /// Pills lying against or over each other, or a pill missed beside another: the
        /// pills have to be spread apart.
        case touching
    }

    /// - Parameter found: The boxes of the pills Vision and colour found, in the same
    ///   pixels as the detections.
    static func review(found: [CGRect], detections: [PillDetection], settings: Settings = Settings()) -> Outcome {
        let seen = detections.filter { $0.confidence >= settings.leastConfidence }

        // Two pills lying over each other.
        for (index, one) in seen.enumerated() {
            for other in seen[(index + 1)...] where share(of: one.box, and: other.box) > settings.overlapping {
                return .touching
            }
        }
        // Two pills taken for one: a pill found that holds the middles of two detected.
        for pill in found where seen.filter({ pill.contains(middle($0.box)) }).count >= 2 {
            return .touching
        }

        // Pills the detector saw that nothing found matches.
        var added: [CGRect] = []
        for detection in seen where !found.contains(where: { matches($0, detection.box) }) {
            let others = found + seen.filter { $0 != detection }.map(\.box)
            if others.contains(where: { near(detection.box, $0, settings: settings) }) {
                return .touching
            }
            if detection.confidence >= settings.sureConfidence {
                added.append(detection.box)
            }
        }
        return added.isEmpty ? .keep : .add(added)
    }

    /// Whether a found pill and a detected one are the same: either's middle lies in the
    /// other, or they share most of their boxes.
    static func matches(_ found: CGRect, _ detected: CGRect) -> Bool {
        found.contains(middle(detected)) || detected.contains(middle(found)) || share(of: found, and: detected) > 0.5
    }

    /// How much of the smaller box the two share.
    static func share(of a: CGRect, and b: CGRect) -> Double {
        let shared = a.intersection(b)
        guard !shared.isNull, !shared.isEmpty else { return 0 }
        let smaller = min(a.width * a.height, b.width * b.height)
        return smaller > 0 ? Double(shared.width * shared.height / smaller) : 0
    }

    /// Whether two boxes touch or come within `nearness` of the smaller pill's width.
    static func near(_ a: CGRect, _ b: CGRect, settings: Settings) -> Bool {
        let reach = settings.nearness * Double(min(a.width, a.height, b.width, b.height))
        return a.insetBy(dx: -reach, dy: -reach).intersects(b)
    }

    private static func middle(_ box: CGRect) -> CGPoint {
        CGPoint(x: box.midX, y: box.midY)
    }
}
