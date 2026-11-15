//
//  AddMedicationButtons.swift
//  MyPharmacist
//

import SwiftUI

/// The two ways to add a medication, side by side, each half the row: "Scan card", the
/// dark one, for a keychain card's code, and "Type it in" for the empty page. What they
/// add is said by the heading above them, so each only says how. At the accessibility
/// text sizes two no longer fit in a row: Scan card first, then the other under it.
struct AddMedicationButtons: View {
    /// Opens the camera for a keychain card's code.
    let onScanCard: () -> Void
    /// Opens an empty medication page.
    let onTypeIn: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 12))
        layout {
            WideButton(title: "Scan card", systemImage: "qrcode.viewfinder", action: onScanCard)
                .accessibilityLabel("Scan a medication card")
            SecondaryButton(title: "Type it in", systemImage: "square.and.pencil", fillsWidth: true, action: onTypeIn)
                .accessibilityLabel("Add a medication by typing it in")
        }
    }
}

#Preview {
    AddMedicationButtons(onScanCard: {}, onTypeIn: {})
        .padding()
        .background(Palette.background)
}
