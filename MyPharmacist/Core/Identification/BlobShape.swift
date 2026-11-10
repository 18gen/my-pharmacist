//
//  BlobShape.swift
//  MyPharmacist
//

import CoreGraphics
import Foundation

/// The measurements of one area of a mask that tell a single pill from two touching
/// ones, a crease or a smear: how big, how long and wide, which way it lies, and how
/// well it fills its own outline.
nonisolated struct BlobShape: Sendable, Equatable {
    /// Pixels in the area.
    let area: Double
    /// The middle of the area in the picture, in pixels.
    let centre: CGPoint
    /// The long and the short side, in pixels: those of the ellipse that spreads the way
    /// the area does. Exact for round and oval pills, a little long for boxy ones.
    let length: Double
    let width: Double
    /// Which way the long side lies: radians from pointing right, turning toward down,
    /// between -π/2 and π/2. Means little when the area is round.
    let angle: Double
    /// The share of its convex outline (a rubber band around it) that the area fills.
    /// A single pill fills nearly all of it; two touching pills leave gaps where they meet.
    let solidity: Double
    /// How far the deepest dent in the outline is from the rubber band, in pixels.
    let deepestDent: Double

    /// The radius of the circle with the same area.
    var equivalentRadius: Double { (area / .pi).squareRoot() }

    init(_ blob: Blob) {
        let mask = blob.mask
        var count = 0.0, sumX = 0.0, sumY = 0.0
        var edge: [(x: Int, y: Int)] = []
        for y in 0..<mask.height {
            for x in 0..<mask.width where mask[x, y] {
                count += 1
                sumX += Double(x)
                sumY += Double(y)
                if !mask.contains(x: x - 1, y: y) || !mask.contains(x: x + 1, y: y)
                    || !mask.contains(x: x, y: y - 1) || !mask.contains(x: x, y: y + 1) {
                    edge.append((x, y))
                }
            }
        }
        guard count > 0 else {
            area = 0; centre = CGPoint(x: blob.x, y: blob.y); length = 0; width = 0; angle = 0; solidity = 0; deepestDent = 0
            return
        }
        let meanX = sumX / count, meanY = sumY / count
        var xx = 0.0, yy = 0.0, xy = 0.0
        for y in 0..<mask.height {
            for x in 0..<mask.width where mask[x, y] {
                let dx = Double(x) - meanX, dy = Double(y) - meanY
                xx += dx * dx
                yy += dy * dy
                xy += dx * dy
            }
        }
        // Each pixel is a unit square, not a point: that adds 1/12 to the spread.
        xx = xx / count + 1.0 / 12
        yy = yy / count + 1.0 / 12
        xy /= count
        let mean = (xx + yy) / 2
        let spread = (((xx - yy) / 2) * ((xx - yy) / 2) + xy * xy).squareRoot()
        area = count
        centre = CGPoint(x: Double(blob.x) + meanX + 0.5, y: Double(blob.y) + meanY + 0.5)
        // An ellipse's spread along an axis is a quarter of that axis' half-length, squared.
        length = 4 * (mean + spread).squareRoot()
        width = 4 * max(0, mean - spread).squareRoot()
        var angle = 0.5 * atan2(2 * xy, xx - yy)
        if angle <= -.pi / 2 { angle += .pi }
        self.angle = angle

        // The outline runs through the middles of the area's outermost pixels, and what
        // it holds is counted in whole pixels, like the area itself. Measuring the
        // outline's exact area instead makes every small round pill look a tenth short
        // of filling it.
        let middles = edge.map { CGPoint(x: Double($0.x) + 0.5, y: Double($0.y) + 0.5) }
        let hull = Self.convexHull(middles)
        let inside = Self.pixelsInside(hull, height: mask.height)
        solidity = inside > 0 ? min(1, count / inside) : 1

        var deepest = 0.0
        for centre in middles where hull.count > 2 {
            var nearest = Double.infinity
            for index in hull.indices {
                nearest = min(nearest, Self.distance(from: centre, toSegment: hull[index], hull[(index + 1) % hull.count]))
            }
            if nearest.isFinite { deepest = max(deepest, nearest) }
        }
        deepestDent = deepest
    }

    // MARK: Geometry

    /// The corners of the smallest convex outline around the points, in order
    /// (Andrew's monotone chain).
    static func convexHull(_ points: [CGPoint]) -> [CGPoint] {
        let sorted = points.sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
        guard sorted.count > 2 else { return sorted }
        func cross(_ o: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }
        var lower: [CGPoint] = []
        for point in sorted {
            while lower.count >= 2, cross(lower[lower.count - 2], lower[lower.count - 1], point) <= 0 { lower.removeLast() }
            lower.append(point)
        }
        var upper: [CGPoint] = []
        for point in sorted.reversed() {
            while upper.count >= 2, cross(upper[upper.count - 2], upper[upper.count - 1], point) <= 0 { upper.removeLast() }
            upper.append(point)
        }
        return Array(lower.dropLast() + upper.dropLast())
    }

    /// How many pixels have their middle inside or on a convex outline, row by row.
    static func pixelsInside(_ outline: [CGPoint], height: Int) -> Double {
        guard outline.count > 2 else { return 0 }
        var total = 0.0
        for row in 0..<height {
            let y = Double(row) + 0.5
            var left = Double.infinity, right = -Double.infinity
            for index in outline.indices {
                let a = outline[index], b = outline[(index + 1) % outline.count]
                let ay = Double(a.y), by = Double(b.y)
                guard min(ay, by) <= y, y <= max(ay, by) else { continue }
                if ay == by {
                    left = min(left, Double(min(a.x, b.x)))
                    right = max(right, Double(max(a.x, b.x)))
                } else {
                    let x = Double(a.x) + (y - ay) / (by - ay) * Double(b.x - a.x)
                    left = min(left, x)
                    right = max(right, x)
                }
            }
            guard left <= right else { continue }
            // Pixel k's middle is at k + 0.5; a hair's allowance for rounding.
            total += max(0, floor(right - 0.5 + 1e-6) - ceil(left - 0.5 - 1e-6) + 1)
        }
        return total
    }

    /// The area inside a closed outline (shoelace formula).
    static func area(of outline: [CGPoint]) -> Double {
        guard outline.count > 2 else { return 0 }
        var twice = 0.0
        for index in outline.indices {
            let a = outline[index], b = outline[(index + 1) % outline.count]
            twice += Double(a.x * b.y - b.x * a.y)
        }
        return abs(twice) / 2
    }

    static func distance(from point: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> Double {
        let dx = Double(b.x - a.x), dy = Double(b.y - a.y)
        let lengthSquared = dx * dx + dy * dy
        var t = 0.0
        if lengthSquared > 0 {
            t = min(1, max(0, (Double(point.x - a.x) * dx + Double(point.y - a.y) * dy) / lengthSquared))
        }
        let px = Double(a.x) + t * dx - Double(point.x), py = Double(a.y) + t * dy - Double(point.y)
        return (px * px + py * py).squareRoot()
    }
}
