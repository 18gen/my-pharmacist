//
//  InstanceBoxes.swift
//  MyPharmacist
//

import CoreGraphics

/// Finds where each object is in a labelled mask, where every pixel holds the number of
/// the object it belongs to (0 for background).
nonisolated enum InstanceBoxes {
    /// Each label's bounding box, normalized 0–1 with the origin at the top left, and the
    /// share of the image its pixels cover.
    static func boxes(labels: [UInt8], width: Int, height: Int) -> [Int: (box: CGRect, area: Double)] {
        var minX: [Int: Int] = [:], minY: [Int: Int] = [:], maxX: [Int: Int] = [:], maxY: [Int: Int] = [:]
        var count: [Int: Int] = [:]
        for y in 0..<height {
            for x in 0..<width {
                let label = Int(labels[y * width + x])
                guard label != 0 else { continue }
                minX[label] = min(minX[label] ?? x, x)
                maxX[label] = max(maxX[label] ?? x, x)
                minY[label] = min(minY[label] ?? y, y)
                maxY[label] = max(maxY[label] ?? y, y)
                count[label, default: 0] += 1
            }
        }
        let total = Double(width * height)
        var result: [Int: (box: CGRect, area: Double)] = [:]
        for (label, pixels) in count {
            let box = CGRect(
                x: Double(minX[label]!) / Double(width),
                y: Double(minY[label]!) / Double(height),
                width: Double(maxX[label]! - minX[label]! + 1) / Double(width),
                height: Double(maxY[label]! - minY[label]! + 1) / Double(height)
            )
            result[label] = (box, Double(pixels) / total)
        }
        return result
    }

    /// Reading order for boxes: top row first, left to right within a row. Boxes whose
    /// centres are within half a box height of each other count as the same row.
    static func readingOrder(_ boxes: [CGRect]) -> [Int] {
        let indices = boxes.indices.sorted { boxes[$0].midY < boxes[$1].midY }
        var rows: [[Int]] = []
        for index in indices {
            if let last = rows.last?.last, abs(boxes[index].midY - boxes[last].midY) < boxes[last].height / 2 {
                rows[rows.count - 1].append(index)
            } else {
                rows.append([index])
            }
        }
        return rows.flatMap { $0.sorted { boxes[$0].midX < boxes[$1].midX } }
    }
}
