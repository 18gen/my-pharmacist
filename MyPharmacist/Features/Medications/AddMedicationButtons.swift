//
//  AddMedicationButtons.swift
//  MyPharmacist
//

import SwiftUI

/// The two ways to add a medication, side by side, each half the row: "Scan", the
/// dark one, for a keychain card's code, and "Type" for the empty page. What they
/// add is said by the heading above them, so each only says how. At the accessibility
/// text sizes two no longer fit in a row: Scan first, then the other under it.
struct AddMedicationButtons: View {
    /// Opens the camera for a keychain card's code.
    let onScanCard: () -> Void
    /// Opens an empty medication page.
    let onTypeIn: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 12))
        layout {
            WideButton(title: "Scan", systemImage: "qrcode.viewfinder", action: onScanCard)
                .accessibilityLabel("Scan a medication card")
            SecondaryButton(title: "Type", systemImage: "square.and.pencil", fillsWidth: true, action: onTypeIn)
                .accessibilityLabel("Add a medication by typing it in")
        }
    }
}

#if DEBUG
#Preview {
    AddMedicationButtons(onScanCard: {}, onTypeIn: {})
        .padding()
        .background(Palette.background)
}
#endif
