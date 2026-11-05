//
//  PillMatchRule.swift
//  MyPharmacist
//

/// Decides which medication a pill is from how far its picture is from each medication's
/// reference photos. A pill only counts as a medication when it is close to it *and*
/// clearly closer to it than to any other, so a pill that isn't on the list is not
/// forced onto the nearest one.
nonisolated struct PillMatchRule {
    /// Starting points from a synthetic test, not tuned values: on a photo made of the
    /// reference pictures, the right medication measured 0.29–0.44 with the runner-up at
    /// 0.75 or more, while look-alike pills not on the list were 0.68 or more from
    /// everything. Real camera photos will measure further; retune on device (each
    /// `PillMatch` keeps its distance for that).
    var maximumDistance: Float = 0.6
    /// The best match's distance must be at most this share of the runner-up's.
    var maximumShareOfRunnerUp: Float = 0.8

    /// - Parameter distances: the smallest distance to each medication's photos, by ID.
    func match(_ distances: [String: Float]) -> PillMatch {
        let sorted = distances.sorted { $0.value < $1.value }
        guard let best = sorted.first else { return PillMatch(medicationID: nil, distance: nil) }
        let isClose = best.value <= maximumDistance
        let isClear = sorted.count < 2 || best.value <= sorted[1].value * maximumShareOfRunnerUp
        return PillMatch(medicationID: isClose && isClear ? best.key : nil, distance: best.value)
    }
}

/// Which medication a pill was recognized as, if any, and how close the nearest one was.
nonisolated struct PillMatch: Hashable, Sendable {
    let medicationID: String?
    /// Distance to the nearest medication's photos, matched or not.
    let distance: Float?
}
