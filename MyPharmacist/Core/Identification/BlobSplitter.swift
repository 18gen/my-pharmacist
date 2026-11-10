//
//  BlobSplitter.swift
//  MyPharmacist
//

import CoreGraphics

/// Takes apart an area that is two or more pills touching. Each pill is thickest in its
/// middle and the area is narrow where two meet, so the area is cut along those narrow
/// places (a watershed of how far each pixel is from the area's edge).
nonisolated enum BlobSplitter {
    struct Split: Sendable, Equatable {
        /// The pieces, in the picture's pixels. One piece when there was nothing to cut.
        let parts: [Blob]
        /// The longest cut between two pieces, in pixels. A cut much shorter than the
        /// pieces are wide is where two pills touch; a long one runs through one pill.
        let longestCut: Int
    }

    /// - Parameter minimumRise: How much thicker, in pixels, a piece's middle must be
    ///   than the narrow place joining it to the next piece for the two to be cut apart.
    ///   Keeps a wavy edge from being read as a second pill.
    static func split(_ blob: Blob, minimumRise: Double) -> Split {
        let mask = blob.mask
        let width = mask.width, height = mask.height
        let depth = distances(mask)

        // Visit pixels from the thickest place outward. A pixel with no visited
        // neighbour starts a piece (it is a middle); any other joins its thickest
        // neighbour's piece. Where two pieces meet, the one with the lower middle is kept
        // apart only if that middle rises enough above the meeting place.
        let order = mask.pixels.indices.filter { mask.pixels[$0] != 0 }.sorted { depth[$0] > depth[$1] }
        var piece = [Int](repeating: -1, count: width * height)
        var parent: [Int] = []
        var peak: [Float] = []
        func root(_ id: Int) -> Int {
            var id = id
            while parent[id] != id {
                parent[id] = parent[parent[id]]
                id = parent[id]
            }
            return id
        }
        for index in order {
            let x = index % width, y = index / width
            var thickest = -1
            var met: [Int] = []
            for ny in max(0, y - 1)...min(height - 1, y + 1) {
                for nx in max(0, x - 1)...min(width - 1, x + 1) {
                    let next = ny * width + nx
                    guard next != index, piece[next] >= 0 else { continue }
                    if thickest < 0 || depth[next] > depth[thickest] { thickest = next }
                    let found = root(piece[next])
                    if !met.contains(found) { met.append(found) }
                }
            }
            guard thickest >= 0 else {
                piece[index] = parent.count
                parent.append(parent.count)
                peak.append(depth[index])
                continue
            }
            var own = root(piece[thickest])
            piece[index] = own
            for other in met where other != own {
                let lower = min(peak[own], peak[other])
                guard Double(lower - depth[index]) < minimumRise else { continue }
                // Not a separate pill: the two become one piece, named for the thicker.
                let keep = peak[own] >= peak[other] ? own : other
                parent[own] = keep
                parent[other] = keep
                own = keep
            }
        }

        var members: [Int: PixelMask] = [:]
        var cuts: [Int: Int] = [:]
        for index in order {
            let own = root(piece[index])
            let x = index % width, y = index / width
            members[own, default: PixelMask(width: width, height: height)][x, y] = true
            // A pixel on a cut is one with a neighbour in another piece; count it once
            // per pair, from the lower-numbered side.
            var others: [Int] = []
            for ny in max(0, y - 1)...min(height - 1, y + 1) {
                for nx in max(0, x - 1)...min(width - 1, x + 1) where piece[ny * width + nx] >= 0 {
                    let other = root(piece[ny * width + nx])
                    if other > own, !others.contains(other) { others.append(other) }
                }
            }
            for other in others {
                cuts[own * parent.count + other, default: 0] += 1
            }
        }
        guard members.count > 1 else { return Split(parts: [blob], longestCut: 0) }
        let parts = members.values
            .compactMap { $0.blobs().max { $0.mask.count < $1.mask.count } }
            .map { Blob(x: blob.x + $0.x, y: blob.y + $0.y, mask: $0.mask) }
            .sorted { ($0.x, $0.y) < ($1.x, $1.y) }
        return Split(parts: parts, longestCut: cuts.values.max() ?? 0)
    }

    /// How far each set pixel is from the nearest clear one (or from the mask's edge),
    /// in pixels; 0 for clear pixels. Two sweeps, counting diagonal steps as √2.
    static func distances(_ mask: PixelMask) -> [Float] {
        let width = mask.width, height = mask.height
        let diagonal: Float = 1.41421356
        var depth = [Float](repeating: 0, count: width * height)
        func at(_ x: Int, _ y: Int) -> Float {
            x < 0 || y < 0 || x >= width || y >= height ? 0 : depth[y * width + x]
        }
        for y in 0..<height {
            for x in 0..<width where mask[x, y] {
                depth[y * width + x] = min(min(at(x - 1, y) + 1, at(x, y - 1) + 1),
                                           min(at(x - 1, y - 1) + diagonal, at(x + 1, y - 1) + diagonal))
            }
        }
        for y in stride(from: height - 1, through: 0, by: -1) {
            for x in stride(from: width - 1, through: 0, by: -1) where mask[x, y] {
                let below = min(min(at(x + 1, y) + 1, at(x, y + 1) + 1),
                                min(at(x + 1, y + 1) + diagonal, at(x - 1, y + 1) + diagonal))
                depth[y * width + x] = min(depth[y * width + x], below)
            }
        }
        return depth
    }
}
