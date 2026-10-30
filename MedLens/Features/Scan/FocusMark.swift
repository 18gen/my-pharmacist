//
//  FocusMark.swift
//  MedLens
//

import SwiftUI

/// Small square marking where the user tapped to focus, like the Camera app.
struct FocusMark: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .stroke(Color.yellow, lineWidth: 1.5)
            .frame(width: 72, height: 72)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
