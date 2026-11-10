//
//  PillLocator.swift
//  MyPharmacist
//

import CoreGraphics

/// One pill in the picture that was searched.
nonisolated struct LocatedPill: Sendable, Equatable {
    /// How the pill was found. Found both ways is the surest.
    struct Sources: OptionSet, Sendable, Hashable {
        let rawValue: Int
        /// By Vision's subject lifting.
        static let lifted = Sources(rawValue: 1)
        /// By its colour against the surface.
        static let colour = Sources(rawValue: 2)
    }

    /// The pill's outline and place, in the searched picture's pixels.
    let blob: Blob
    let shape: BlobShape
    let sources: Sources
}

/// What looking for pills came to, before any pill is cut out.
nonisolated enum PillLocation: Sendable, Equatable {
    /// In reading order (top row first, left to right).
    case found([LocatedPill])
    case noPills
    /// Something is there but can't be trusted: ask for another photo, saying why.
    case unclear(RetakeReason)
}

/// What became of one area that was looked at. Only for the log, so that a photo that
/// was wrongly turned away can be explained from the numbers.
nonisolated struct ExaminedArea: Sendable, Equatable {
    enum Outcome: Sendable, Hashable {
        /// Taken for this many pills: one, or several once cut apart.
        case pills(Int)
        case ignored
        case retake(RetakeReason)
    }

    let sources: LocatedPill.Sources
    let shape: BlobShape
    let verdict: PillRules.Verdict
    let outcome: Outcome
}

/// Brings the two ways of finding pills together and applies the rules to every area,
/// so that each one ends up as a pill, as nothing, or as a reason to take the photo
/// again. An area that might be a pill but can't be trusted makes the whole photo
/// unclear; one that is probably a single pill with a rough outline is kept, as the
/// checker is asked of every cut-out whether it shows one whole pill.
nonisolated enum PillLocator {
    /// One area and how it was found.
    private typealias Candidate = (blob: Blob, sources: LocatedPill.Sources)

    /// - Parameters:
    ///   - lifted: The pill-sized objects Vision lifted from the picture.
    ///   - colour: What differs from the surface by colour, if that was looked for.
    static func locate(lifted: [Blob], colour: SurfaceOutliers.Result?, rules: PillRules,
                       pictureWidth: Int, pictureHeight: Int) -> PillLocation {
        examine(lifted: lifted, colour: colour, rules: rules, pictureWidth: pictureWidth, pictureHeight: pictureHeight).location
    }

    /// `locate`, with what became of every area.
    static func examine(lifted: [Blob], colour: SurfaceOutliers.Result?, rules: PillRules,
                        pictureWidth: Int, pictureHeight: Int) -> (location: PillLocation, areas: [ExaminedArea]) {
        func judge(_ blob: Blob) -> PillRules.Verdict {
            rules.judge(blob, pictureWidth: pictureWidth, pictureHeight: pictureHeight)
        }
        // Colour says nothing on a patterned surface.
        let coloured = colour.flatMap { $0.isReliable ? $0.blobs : nil } ?? []
        let faint = colour.flatMap { $0.isReliable ? $0.faint : nil } ?? []

        var pills: [LocatedPill] = []
        var reasons = Set<RetakeReason>()
        var areas: [ExaminedArea] = []
        for candidate in candidates(lifted: lifted, coloured: coloured, judge: judge) {
            let shape = BlobShape(candidate.blob)
            let verdict = judge(candidate.blob)
            let outcome: ExaminedArea.Outcome
            switch settle(candidate, shape: shape, verdict: verdict, rules: rules, judge: judge) {
            case .pills(let parts):
                pills += parts.map { LocatedPill(blob: $0, shape: BlobShape($0), sources: candidate.sources) }
                outcome = .pills(parts.count)
            case .ignored:
                outcome = .ignored
            case .retake(let reason):
                reasons.insert(reason)
                outcome = .retake(reason)
            }
            areas.append(ExaminedArea(sources: candidate.sources, shape: shape, verdict: verdict, outcome: outcome))
        }

        // Something round and pill-sized that barely differs from the surface, where no
        // pill was found: it may be one, and its edge can't be trusted either way.
        for area in faint where judge(area) == .pill && !pills.contains(where: { overlap($0.blob, area) }) {
            let shape = BlobShape(area)
            if rules.isWide(shape), shape.width >= rules.leastFaintWidth * shape.length {
                reasons.insert(.hardToSee)
            }
        }
        if pills.contains(where: { !rules.isReadable($0.shape) }) {
            reasons.insert(.tooFar)
        }
        if pills.count > rules.mostPills {
            reasons.insert(.hardToSee)
        }

        // The one thing to fix first.
        for reason in [RetakeReason.touching, .cutOff, .tooFar, .hardToSee] where reasons.contains(reason) {
            return (.unclear(reason), areas)
        }
        guard !pills.isEmpty else { return (.noPills, areas) }
        let boxes = pills.map { $0.blob.normalizedBounds(pictureWidth: pictureWidth, pictureHeight: pictureHeight) }
        return (.found(InstanceBoxes.readingOrder(boxes).map { pills[$0] }), areas)
    }

    /// Every area to look at. The same pill found both ways is one area. Where Vision
    /// took for one object what colour shows as several pills, the several are kept.
    private static func candidates(lifted: [Blob], coloured: [Blob], judge: (Blob) -> PillRules.Verdict) -> [Candidate] {
        var candidates: [Candidate] = []
        var usedColour = Set<Int>()
        for object in lifted {
            let same = coloured.indices.filter { overlap(object, coloured[$0]) }
            if same.count >= 2, judge(object) != .pill, same.allSatisfy({ judge(coloured[$0]) == .pill }) {
                candidates += same.map { (coloured[$0], [.lifted, .colour]) }
            } else {
                candidates.append((object, same.isEmpty ? .lifted : [.lifted, .colour]))
            }
            usedColour.formUnion(same)
        }
        return candidates + coloured.indices.filter { !usedColour.contains($0) }.map { (coloured[$0], .colour) }
    }

    private enum Settled {
        case pills([Blob])
        case ignored
        case retake(RetakeReason)
    }

    /// What one area is. Skin has creases, shadows and blotches that differ from the
    /// skin around them too, so what colour alone found has more to prove than what
    /// Vision lifted: it must be as wide as a readable pill, and whole.
    private static func settle(_ candidate: Candidate, shape: BlobShape, verdict: PillRules.Verdict, rules: PillRules,
                               judge: (Blob) -> PillRules.Verdict) -> Settled {
        let byColourAlone = candidate.sources == .colour
        func wideEnough(_ parts: [Blob]) -> Bool {
            !byColourAlone || parts.allSatisfy { rules.isWide(BlobShape($0)) }
        }
        switch verdict {
        case .notAPill:
            return .ignored
        case .cutOff:
            // At the photo's edge colour mostly finds what is beside the hand.
            return byColourAlone ? .ignored : .retake(.cutOff)
        case .pill:
            return wideEnough([candidate.blob]) ? .pills([candidate.blob]) : .ignored
        case .touching:
            // Pills that are merely joined (by a shadow between them, or where they
            // touch) come apart cleanly.
            if let parts = withoutBridges(candidate.blob, shape: shape, rules: rules, judge: judge)
                ?? cutApart(candidate.blob, shape: shape, rules: rules, judge: judge, allowingScraps: byColourAlone),
               wideEnough(parts) {
                return .pills(parts)
            }
            let filled = shape.solidity >= (byColourAlone ? rules.leastShadowedSolidity : rules.leastJoinedSolidity)
            guard filled, wideEnough([candidate.blob]) else { return .ignored }
            let middles = BlobSplitter.split(candidate.blob, minimumRise: minimumRise(shape)).parts
            if middles.count > 1 {
                // Two middles that can't be cut apart: pills lying against or over each
                // other, if any piece is a pill at all.
                return middles.contains { judge($0) == .pill } ? .retake(.touching) : .ignored
            }
            // One middle and no larger than a pill: one pill with a rough outline (its
            // shadow, a shine, a score line). Anything longer is part of a hand.
            return shape.length <= rules.longestPill * rules.pixelsPerMillimeter ? .pills([candidate.blob]) : .ignored
        }
    }

    /// How much thicker a piece's middle must be than the narrow place joining it to
    /// the next. A pill's middle is about half its width from its edge; a fifth of that
    /// is more than a wavy edge makes.
    private static func minimumRise(_ shape: BlobShape) -> Double {
        max(2, 0.2 * shape.width / 2)
    }

    /// The pills left when everything thin is taken off an area: the shadow or crease
    /// joining pills that don't touch. Nil unless that leaves two or more pieces, each
    /// a pill by itself; one piece left says nothing about whether it is one pill.
    private static func withoutBridges(_ blob: Blob, shape: BlobShape, rules: PillRules, judge: (Blob) -> PillRules.Verdict) -> [Blob]? {
        let radius = max(1, Int((rules.widestBridge * shape.width / 2).rounded()))
        var parts = blob.mask.opened(by: radius).blobs().map { Blob(x: blob.x + $0.x, y: blob.y + $0.y, mask: $0.mask) }
        let largest = parts.map(\.mask.count).max() ?? 0
        parts.removeAll { judge($0) != .pill && $0.mask.count * 4 < largest }
        guard parts.count > 1, parts.allSatisfy({ judge($0) == .pill }) else { return nil }
        return parts
    }

    /// The single pills an area of touching pills is made of, or nil when it can't be
    /// cut apart cleanly: a piece that isn't a pill by itself, or a cut too long to be
    /// where two pills merely touch.
    /// - Parameter allowingScraps: For an area found by colour, which can include the
    ///   shadow a pill casts beside itself: small pieces that aren't pills are dropped
    ///   instead of spoiling the cut.
    private static func cutApart(_ blob: Blob, shape: BlobShape, rules: PillRules, judge: (Blob) -> PillRules.Verdict,
                                 allowingScraps: Bool) -> [Blob]? {
        let split = BlobSplitter.split(blob, minimumRise: minimumRise(shape))
        guard split.parts.count > 1 else { return nil }
        var parts = split.parts
        if allowingScraps {
            let largest = parts.map(\.mask.count).max() ?? 0
            parts.removeAll { judge($0) != .pill && $0.mask.count * 4 < largest }
        }
        guard !parts.isEmpty, parts.allSatisfy({ judge($0) == .pill }) else { return nil }
        let narrowest = parts.map { BlobShape($0).width }.min() ?? 0
        guard Double(split.longestCut) <= rules.longestCut * narrowest else { return nil }
        return parts
    }

    /// Whether two areas are the same thing: they share more than three tenths of the
    /// smaller one's pixels.
    static func overlap(_ a: Blob, _ b: Blob) -> Bool {
        let shared = a.bounds.intersection(b.bounds)
        guard !shared.isNull, shared.width > 0, shared.height > 0 else { return false }
        var count = 0
        for y in Int(shared.minY)..<Int(shared.maxY) {
            for x in Int(shared.minX)..<Int(shared.maxX) where a.mask[x - a.x, y - a.y] && b.mask[x - b.x, y - b.y] {
                count += 1
            }
        }
        return Double(count) > 0.3 * Double(min(a.mask.count, b.mask.count))
    }
}
