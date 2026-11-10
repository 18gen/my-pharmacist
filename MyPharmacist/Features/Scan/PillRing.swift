//
//  PillRing.swift
//  MyPharmacist
//

import SwiftUI

/// The ring around a pill in a photo before anything is known about it: white with a dark
/// edge, so it shows on light and dark pills and on skin alike. Used where the person
/// confirms the pills found and while they are being checked; once checked, each ring
/// takes its level's colour (`ResultPhoto`).
struct PillRing: View {
    var body: some View {
        Capsule()
            .strokeBorder(.white, lineWidth: 3)
            .background(Capsule().strokeBorder(.black.opacity(0.45), lineWidth: 5))
    }
}
