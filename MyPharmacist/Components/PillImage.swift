//
//  PillImage.swift
//  MyPharmacist
//

import SwiftUI

/// A medication's reference photo on a white tile, so the person can see which tablet
/// it is. Falls back to a plain pill symbol if the medication has no photo.
struct PillImage: View {
    let medication: Medication
    var size: CGFloat = 48

    var body: some View {
        Group {
            if let photo = medication.photos.first, let image = MedicationPhotoStore.standard.image(photo) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.08)
            } else {
                Image(systemName: "pill.fill")
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(Palette.textMuted)
            }
        }
        .frame(width: size, height: size)
        .background(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous).fill(Palette.background))
        .accessibilityHidden(true)
    }
}
