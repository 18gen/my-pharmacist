//
//  HomeView.swift
//  MyPharmacist
//

import SwiftUI

/// Home screen content above the scan button: date and time with the "Pharmacy" button on
/// a card with the onboarding's photo behind them, then one card per time of day
/// ("Morning · 8:00 AM"), earliest first, the medications taken only when needed, and
/// last the "My Medications" button and the way to "About & privacy". Only the time of day due now is open; the rest are
/// folded, so what to take stands out. The header stays put; the cards scroll beneath it.
struct HomeView: View {
    let store: MedicationStore
    /// Opens the "My Medications" page.
    let onShowMedications: () -> Void
    /// Opens the pharmacy's card.
    let onShowPharmacy: () -> Void
    /// Opens "About & privacy".
    let onShowAbout: () -> Void
    /// Opens the camera for a keychain card's code.
    var onScanCard: () -> Void = {}
    /// Opens an empty medication page.
    var onTypeIn: () -> Void = {}

    private static let fadeHeight: CGFloat = 24

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Folded times of day the person has opened, each with the status it was opened in:
    /// when a slot moves on (next → now → scanned) it goes back to how that status shows.
    @State private var openSlots: Set<String> = []
    @State private var showsWhenNeeded = false

    /// Scroll target for the "When needed" card.
    private static let whenNeededID = "whenNeeded"

    var body: some View {
        // Redraw every minute so the clock and each time of day's status stay current.
        TimelineView(.everyMinute) { context in
            let slots = store.todaySlots(now: context.date)
            let asNeeded = store.asNeededMedications

            VStack(alignment: .leading, spacing: 16) {
                HomeHeader(now: context.date, onShowPharmacy: onShowPharmacy)
                    .background { headerPhoto }
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(.horizontal, 16)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            if store.medications.isEmpty {
                                FirstStepsCard(onScanCard: onScanCard, onTypeIn: onTypeIn)
                            } else if slots.isEmpty {
                                Text("No medications scheduled today.")
                                    .font(.body)
                                    .foregroundStyle(Palette.textTertiary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .cardBackground()
                            }
                            ForEach(slots) { slot in
                                DoseSlotCard(slot: slot, isExpanded: isOpen(slot),
                                             onOpened: { scrollIntoView(slot.id, proxy) })
                                    .id(slot.id)
                            }
                            if !asNeeded.isEmpty {
                                WhenNeededCard(items: asNeeded.map { ($0, store.asNeededScan(of: $0, on: context.date)) },
                                               isExpanded: $showsWhenNeeded,
                                               onOpened: { scrollIntoView(Self.whenNeededID, proxy) })
                                    .id(Self.whenNeededID)
                            }
                            // The way to the list and its settings, after everything
                            // about today. With no medications yet, the card above
                            // already has the button.
                            if !store.medications.isEmpty {
                                WideButton(title: "My Medications", systemImage: "pills.fill",
                                           action: onShowMedications)
                                    .padding(.top, 8)
                            }
                            // Last of all, with or without medications: under the
                            // button above, or under the first-steps card.
                            Button(action: onShowAbout) {
                                Label("About & privacy", systemImage: "info.circle")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Palette.textSecondary)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        // Room to scroll the last card clear of the fade.
                        .padding(.bottom, Self.fadeHeight)
                        .animation(.spring(duration: 0.45), value: slots)
                    }
                    // Fade out above the "Scan Pills" button instead of cutting off sharply.
                    .mask {
                        VStack(spacing: 0) {
                            Color.black
                            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                                .frame(height: Self.fadeHeight)
                        }
                    }
                }
            }
        }
    }

    /// Behind the date and clock: the onboarding's photo of pills being scanned, soft and
    /// dimmed so the cream words on it are easy to read. Home opens on the picture the
    /// onboarding ended with.
    private var headerPhoto: some View {
        Image("OnboardingScene")
            .resizable()
            .scaledToFill()
            // Closer on the hand and the phone, which a card this wide would otherwise
            // show only a strip of.
            .scaleEffect(1.5, anchor: UnitPoint(x: 0.5, y: 0.62))
            .blur(radius: 3)
            .overlay(LinearGradient(colors: [.black.opacity(0.25), .black.opacity(0.55)],
                                    startPoint: .top, endPoint: .bottom))
            .accessibilityHidden(true)
    }

    private func isOpen(_ slot: DoseSlot) -> Binding<Bool> {
        let key = "\(slot.scheduled.timeIntervalSince1970) \(slot.status)"
        return Binding(
            get: { openSlots.contains(key) },
            set: { open in
                if open { openSlots.insert(key) } else { openSlots.remove(key) }
            }
        )
    }

    /// Scrolls just enough to show the whole of a card that has just opened; closing a
    /// card leaves the scroll position alone.
    private func scrollIntoView(_ id: some Hashable, _ proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? nil : .spring(duration: 0.4)) {
            proxy.scrollTo(id, anchor: nil)
        }
    }
}

/// What a new person sees before adding any medication: what the app does and the one
/// thing to do first.
private struct FirstStepsCard: View {
    let onScanCard: () -> Void
    let onTypeIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add your medications")
                .font(.title2.bold())
                .foregroundStyle(Palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("Scan the code on each medication's card, or type a medication in with a photo of its pill and when you take it. Then scan the pills in your hand before taking them, to check they're the right ones for now.")
                .font(.body)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            // The same two ways as on My Medications.
            AddMedicationButtons(onScanCard: onScanCard, onTypeIn: onTypeIn)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }
}
