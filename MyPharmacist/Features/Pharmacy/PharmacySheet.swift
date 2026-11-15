//
//  PharmacySheet.swift
//  MyPharmacist
//

import MapKit
import SwiftUI

/// "My pharmacy", sliding up over Home from the button under the clock: one large button
/// to call, the next refill, the opening hours, and a map that opens Google Maps. Something to look at and act on, so it
/// is a sheet to close rather than a page to come back from.
struct PharmacySheet: View {
    let pharmacy: Pharmacy
    /// Opens the page where the pharmacy is typed in.
    let onEdit: () -> Void
    let onClose: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("My pharmacy")
                    .font(Palette.pageTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                if pharmacy.isEmpty {
                    empty
                } else {
                    contact
                    if let nextRefill = pharmacy.nextRefill { refill(nextRefill) }
                    if !pharmacy.hours.isEmpty { hours }
                    if let urls = pharmacy.googleMapsURLs { location(opening: urls) }
                }

                HStack(spacing: 12) {
                    if !pharmacy.isEmpty {
                        SecondaryButton(title: "Edit", fillsWidth: true, action: onEdit)
                    }
                    SecondaryButton(title: "Close", fillsWidth: true, action: onClose)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .background(Palette.background)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// Before a pharmacy is typed in: what this is for, and the way to add it.
    private var empty: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add your pharmacy's phone number and opening hours, to have them here when you need to call.")
                .font(.body)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            WideButton(title: "Add my pharmacy", systemImage: "plus", action: onEdit)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }

    private var contact: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !pharmacy.name.isEmpty {
                Text(pharmacy.name)
                    .font(.title2.bold())
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let url = pharmacy.callURL {
                // The phone asks before it dials.
                WideButton(title: "Call \(pharmacy.phone)", systemImage: "phone.fill", tint: Palette.due) {
                    openURL(url)
                }
            } else {
                Text("No phone number yet.")
                    .font(.body)
                    .foregroundStyle(Palette.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }

    private func refill(_ date: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("Next refill")
            Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.system(.title2, design: .serif, weight: .medium))
                .foregroundStyle(Palette.textPrimary)
            if let countdown = pharmacy.refillCountdown() {
                Text(countdown.prefix(1).uppercased() + countdown.dropFirst())
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
        .accessibilityElement(children: .combine)
    }

    private var hours: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("Opening hours")
            Text(pharmacy.hours)
                .font(.body)
                .foregroundStyle(Palette.textBody)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }

    /// The address, a map with a pin when the address was found, and the way to Google
    /// Maps. The whole card is the button: the map doesn't move, so a tap anywhere on it
    /// opens Google Maps and the page under it still scrolls.
    private func location(opening urls: (app: URL, web: URL)) -> some View {
        Button {
            // The Google Maps app; without it, Google Maps in the browser.
            openURL(urls.app) { opened in
                if !opened { openURL(urls.web) }
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    sectionTitle("Location")
                    if !pharmacy.address.isEmpty {
                        Text(pharmacy.address)
                            .font(.body)
                            .foregroundStyle(Palette.textBody)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let coordinate = pharmacy.coordinate {
                    PharmacyMap(name: pharmacy.name, coordinate: coordinate)
                }
                Label("Open in Google Maps", systemImage: "arrow.up.right.square")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Palette.due)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardBackground()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Location: \(pharmacy.address)")
        .accessibilityHint("Opens Google Maps")
        .accessibilityAddTraits(.isButton)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.body.weight(.semibold))
            .foregroundStyle(Palette.textSecondary)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A small map with a pin on the pharmacy, to look at rather than move: it takes no
/// touches, so whatever holds it decides what a tap does.
struct PharmacyMap: View {
    let name: String
    let coordinate: CLLocationCoordinate2D

    /// Close enough to see the streets around it.
    private static let span: CLLocationDistance = 600

    var body: some View {
        Map(position: .constant(.region(MKCoordinateRegion(center: coordinate,
                                                           latitudinalMeters: Self.span,
                                                           longitudinalMeters: Self.span))),
            interactionModes: []) {
            Marker(name.isEmpty ? "Pharmacy" : name, coordinate: coordinate)
                .tint(Palette.due)
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("A pharmacy") {
    Color.clear.sheet(isPresented: .constant(true)) {
        PharmacySheet(pharmacy: .sample(), onEdit: {}, onClose: {})
    }
}

#Preview("None yet") {
    Color.clear.sheet(isPresented: .constant(true)) {
        PharmacySheet(pharmacy: Pharmacy(), onEdit: {}, onClose: {})
    }
}
#endif
