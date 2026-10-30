//
//  ScanResultView.swift
//  MedLens
//

import SwiftUI

/// The medication name and frequency shown above the camera.
struct ScanResultView: View {
    let model: ScannerModel

    var body: some View {
        VStack(spacing: 20) {
            Text(model.medicationName ?? "Scanning...")
                .font(.largeTitle.bold())
                .foregroundStyle(model.medicationName == nil ? .secondary : .primary)
                .minimumScaleFactor(0.5)
                .lineLimit(3)

            Text(model.frequency ?? "Scanning...")
                .font(.title.weight(.semibold))
                .foregroundStyle(model.frequency == nil ? .secondary : .primary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }
}
