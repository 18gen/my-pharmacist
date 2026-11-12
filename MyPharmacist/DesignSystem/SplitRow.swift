//
//  SplitRow.swift
//  MyPharmacist
//

import SwiftUI

/// A row that gives each of its views a fixed share of the width, such as 3 to 7 for a
/// small button beside the main one. An `HStack` can't hold a ratio by itself.
struct SplitRow: Layout {
    /// One number per view, in order; each view gets that part of their total.
    let shares: [CGFloat]
    var spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? subviews.reduce(0) { $0 + $1.sizeThatFits(.unspecified).width }
        let widths = widths(in: width, count: subviews.count)
        let height = zip(subviews, widths)
            .map { $0.sizeThatFits(ProposedViewSize(width: $1, height: proposal.height)).height }
            .max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for (subview, width) in zip(subviews, widths(in: bounds.width, count: subviews.count)) {
            subview.place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading,
                          proposal: ProposedViewSize(width: width, height: bounds.height))
            x += width + spacing
        }
    }

    /// Each view's width: its share of the row, less the gaps between them.
    private func widths(in width: CGFloat, count: Int) -> [CGFloat] {
        let shares = Array(self.shares.prefix(count))
        let total = shares.reduce(0, +)
        guard total > 0 else { return [] }
        let room = max(0, width - spacing * CGFloat(max(0, shares.count - 1)))
        return shares.map { room * $0 / total }
    }
}
