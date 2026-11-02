//
//  PillResultsView.swift
//  MyPharmacist
//

import SwiftUI

/// The checked photo with every pill outlined, a row per pill saying what it is and
/// whether to take it, any missing doses, and the buttons to confirm or scan again.
struct PillResultsView: View {
    let result: PillScanResult
    let onConfirm: () -> Void
    let onScanAgain: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            PillPhotoView(photo: result.photo, pills: result.pills)
                .frame(maxHeight: 220)

            // Problems first, so a pill not to take is never below the fold; the numbers
            // still match the photo.
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(result.pills.filter { !$0.verdict.isTake }) { pill in
                        PillResultRow(pill: pill)
                    }
                    ForEach(result.missing) { dose in
                        MissingDoseRow(dose: dose)
                    }
                    ForEach(result.pills.filter(\.verdict.isTake)) { pill in
                        PillResultRow(pill: pill)
                    }
                }
                // Room for the number badges that stick out of the rows.
                .padding(.top, 6)
                .padding(.horizontal, 6)
            }
            .scrollIndicators(.hidden)

            ScanActionButtons(takeCount: result.dosesToTake.count, onConfirm: onConfirm, onScanAgain: onScanAgain)
        }
    }
}

/// "Scan again", and "Mark N as taken" when any pill is right to take.
struct ScanActionButtons: View {
    let takeCount: Int
    let onConfirm: () -> Void
    let onScanAgain: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onScanAgain) {
                Label("Scan again", systemImage: "arrow.counterclockwise")
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.white)

            if takeCount > 0 {
                Button(action: onConfirm) {
                    Label("Mark \(takeCount) taken", systemImage: "checkmark")
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.taken)
                .accessibilityHint("Only the pills marked Take now are recorded")
            }
        }
        .font(.headline)
        .controlSize(.large)
    }
}
