//
//  ShareCard.swift
//  MyPharmacist
//

import SwiftUI

/// On the pharmacy's card: sharing with the pharmacy demo. Off, with the way to start; on,
/// as whom and how the last sending went, with the way to stop; or stopped by the demo.
/// It never says the pharmacy was told anything: it isn't, and the person still calls.
struct ShareCard: View {
    let share: PharmacyShare
    let onShare: () -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let session = share.session {
                heading("Sharing as \(session.name)")
                if let status = deliveryStatus {
                    Text(status.text)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(status.color)
                }
                detail("The pharmacy isn't alerted. If you're unsure about a dose, call them.")
                SecondaryButton(title: "Stop sharing", fillsWidth: true, action: onStop)
                    .padding(.top, 4)
            } else if share.stoppedByDemo {
                heading("Sharing stopped")
                detail("The pharmacy demo was reset, or took you off its screen.")
                WideButton(title: "Share again", systemImage: "arrow.clockwise", action: onShare)
                    .padding(.top, 4)
            } else {
                heading("Share with the pharmacy demo")
                detail("Let Sample Pharmacy's demo dashboard see which doses you took and what your scans said.")
                WideButton(title: "Share my doses", systemImage: "square.and.arrow.up", action: onShare)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }

    private var deliveryStatus: (text: String, color: Color)? {
        switch share.delivery {
        case .idle:
            nil
        case .sending:
            ("Sending…", Palette.textSecondary)
        case .sent(let time):
            ("Sent \(time.formatted(date: .omitted, time: .shortened))", Palette.ok)
        case .failed(.notAllowed):
            ("This version of the app can't share.", Palette.danger)
        case .failed(let failure):
            (failure.mayPassLater ? "Couldn't send. Trying again." : "Couldn't send.", Palette.caution)
        }
    }

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(.title3.weight(.semibold))
            .foregroundStyle(Palette.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private func detail(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(Palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension ShareFailure {
    /// Why sharing couldn't start, and what to do.
    var startMessage: String {
        switch self {
        case .offline: "Couldn't reach the pharmacy demo. Check the internet and try again."
        case .full: "The pharmacy demo is full. Ask whoever runs it to reset it."
        case .busy: "Many people are joining at once. Try again in a minute."
        case .notAllowed: "This version of the app can't share with the pharmacy demo."
        case .gone, .refused, .server: "The pharmacy demo had a problem. Try again."
        }
    }
}
