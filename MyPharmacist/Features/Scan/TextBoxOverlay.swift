//
//  TextBoxOverlay.swift
//  MyPharmacist
//

import SwiftUI

/// Draws a box around only the text the app actually uses: yellow for the line the
/// medication name comes from, cyan for the frequency line(s). Other text is not boxed.
struct TextBoxOverlay: View {
    let lines: [RecognizedLine]
    let frameSize: CGSize

    private var usedLines: [RecognizedLine] {
        lines.filter { $0.role != .other }
    }

    var body: some View {
        GeometryReader { proxy in
            if frameSize.width > 0, frameSize.height > 0 {
                ForEach(Array(usedLines.enumerated()), id: \.offset) { _, line in
                    let rect = Self.viewRect(for: line.box, frameSize: frameSize, viewSize: proxy.size)
                        .insetBy(dx: -4, dy: -3)
                    let color = Self.color(for: line.role)

                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(color.opacity(0.25))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(color, lineWidth: 0.5)
                                // Dark edge keeps yellow and cyan outlines visible on white labels.
                                .shadow(color: .black.opacity(0.6), radius: 1)
                        }
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }
            }
        }
        // Glide boxes between frames instead of jumping.
        .animation(.easeOut(duration: 0.1), value: usedLines)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private static func color(for role: RecognizedLine.Role) -> Color {
        role == .name ? .yellow : .cyan
    }

    /// Maps Vision's normalized box (origin bottom-left) onto the preview, which shows the
    /// camera frame scaled to fill the view and cropped equally on both sides.
    static func viewRect(for box: CGRect, frameSize: CGSize, viewSize: CGSize) -> CGRect {
        let scale = max(viewSize.width / frameSize.width, viewSize.height / frameSize.height)
        let shown = CGSize(width: frameSize.width * scale, height: frameSize.height * scale)
        let offset = CGPoint(x: (viewSize.width - shown.width) / 2, y: (viewSize.height - shown.height) / 2)
        return CGRect(
            x: offset.x + box.minX * shown.width,
            y: offset.y + (1 - box.maxY) * shown.height,
            width: box.width * shown.width,
            height: box.height * shown.height
        )
    }
}
