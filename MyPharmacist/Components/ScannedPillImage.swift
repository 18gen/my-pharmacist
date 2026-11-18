//
//  ScannedPillImage.swift
//  MyPharmacist
//

import SwiftUI

/// A scanned pill's picture: the whole picture the scan cut of the pill, or the
/// medication's own photo when that picture is gone (the app was closed since), on the
/// same beige square as the other pictures on Home, inside a camera's four green corner marks.
struct ScannedPillImage: View {
    let medication: Medication
    let photo: CGImage?
    let size: CGFloat

    var body: some View {
        Group {
            if let photo {
                // The cut is square: all of it shows, rounded a little.
                Image(decorative: photo, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.1, style: .continuous))
                    // As large as fits inside the corner marks.
                    .padding(size * 0.08)
            } else if let saved = medication.photos.first, let image = MedicationPhotoStore.standard.image(saved) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.14)
            } else {
                Image(systemName: "pill.fill")
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(Palette.textMuted)
            }
        }
        .frame(width: size, height: size)
        .background(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous).fill(Palette.cardFill))
        .overlay(CornerMarks().stroke(Palette.ok, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .padding(size * 0.05))
        .accessibilityHidden(true)
    }
}

/// A camera's four corner marks around a square.
nonisolated struct CornerMarks: Shape {
    func path(in rect: CGRect) -> Path {
        let arm = min(rect.width, rect.height) * 0.22
        var path = Path()
        for (corner, dx, dy) in [(CGPoint(x: rect.minX, y: rect.minY), 1.0, 1.0), (CGPoint(x: rect.maxX, y: rect.minY), -1.0, 1.0),
                                 (CGPoint(x: rect.maxX, y: rect.maxY), -1.0, -1.0), (CGPoint(x: rect.minX, y: rect.maxY), 1.0, -1.0)] {
            path.move(to: CGPoint(x: corner.x, y: corner.y + dy * arm))
            path.addLine(to: corner)
            path.addLine(to: CGPoint(x: corner.x + dx * arm, y: corner.y))
        }
        return path
    }
}
