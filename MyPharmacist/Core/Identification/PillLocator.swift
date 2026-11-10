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

/// Brings the two ways of finding pills together and applies the rules to every area,
/// so that each one ends up as a pill, as nothing, or as a reason to take the photo
/// again. Nothing is quietly left out: an area that might be a pill but can't be
/// trusted makes the whole photo unclear.
nonisolated enum PillLocator {
    /// - Parameters:
    ///   - lifted: The pill-sized objects Vision lifted from the picture.
    ///   - colour: What differs from the surface by colour, if that was looked for.
    static func locate(lifted: [Blob], colour: SurfaceOutliers.Result?, rules: PillRules,
                       pictureWidth: Int, pictureHeight: Int) -> PillLocation {
        func judge(_ blob: Blob) -> PillRules.Verdict {
            rules.judge(blob, pictureWidth: pictureWidth, pictureHeight: pictureHeight)
        }
        // Colour says nothing on a patterned surface.
        let coloured = colour.flatMap { $0.isReliable ? $0.blobs : nil } ?? []
        let faint = colour.flatMap { $0.isReliable ? $0.faint : nil } ?? []

        // The same pill found both ways is one pill. Where Vision took for one object
        // what colour shows as several pills, the several are kept.
        var candidates: [(blob: Blob, sources: LocatedPill.Sources)] = []
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
        candidates += coloured.indices.filter { !usedColour.contains($0) }.map { (coloured[$0], .colour) }

        var pills: [LocatedPill] = []
        var reasons = Set<RetakeReason>()
        for candidate in candidates {
            switch judge(candidate.blob) {
            case .notAPill:
                continue
            case .cutOff:
                reasons.insert(.cutOff)
            case .pill:
                pills.append(LocatedPill(blob: candidate.blob, shape: BlobShape(candidate.blob), sources: candidate.sources))
            case .touching:
                guard let parts = cutApart(candidate.blob, rules: rules, judge: judge) else {
                    reasons.insert(.touching)
                    continue
                }
                pills += parts.map { LocatedPill(blob: $0, shape: BlobShape($0), sources: candidate.sources) }
            }
        }
        // Something pill-shaped that barely differs from the surface, where no pill was
        // found: it may be one, and its edge can't be trusted either way.
        for area in faint where judge(area) == .pill && !pills.contains(where: { overlap($0.blob, area) }) {
            reasons.insert(.hardToSee)
        }
        if pills.contains(where: { !rules.isReadable($0.shape) }) {
            reasons.insert(.tooFar)
        }
        if pills.count > rules.mostPills {
            reasons.insert(.hardToSee)
        }

        // The one thing to fix first.
        for reason in [RetakeReason.touching, .cutOff, .tooFar, .hardToSee] where reasons.contains(reason) {
            return .unclear(reason)
        }
        guard !pills.isEmpty else { return .noPills }
        let boxes = pills.map { pill in
            CGRect(x: pill.blob.bounds.minX / Double(pictureWidth), y: pill.blob.bounds.minY / Double(pictureHeight),
                   width: pill.blob.bounds.width / Double(pictureWidth), height: pill.blob.bounds.height / Double(pictureHeight))
        }
        return .found(InstanceBoxes.readingOrder(boxes).map { pills[$0] })
    }

    /// The single pills an area of touching pills is made of, or nil when it can't be
    /// cut apart cleanly: a piece that isn't a pill by itself, or a cut too long to be
    /// where two pills merely touch.
    private static func cutApart(_ blob: Blob, rules: PillRules, judge: (Blob) -> PillRules.Verdict) -> [Blob]? {
        let shape = BlobShape(blob)
        // A pill's middle is about half its width from its edge; a fifth of that is
        // more than a wavy edge makes.
        let split = BlobSplitter.split(blob, minimumRise: max(2, 0.2 * shape.width / 2))
        guard split.parts.count > 1 else { return nil }
        guard split.parts.allSatisfy({ judge($0) == .pill }) else { return nil }
        let narrowest = split.parts.map { BlobShape($0).width }.min() ?? 0
        guard Double(split.longestCut) <= rules.longestCut * narrowest else { return nil }
        return split.parts
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
