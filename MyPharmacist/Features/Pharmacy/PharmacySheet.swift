//
//  PharmacySheet.swift
//  MyPharmacist
//

import MapKit
import SwiftUI

/// "My pharmacy", sliding up over Home from the button by the clock: one large button
/// to call, the next refill, the opening hours, and a map that opens Apple's Maps, with a
/// button for Google Maps. Something to look at and act on, so it is a sheet to close
/// rather than a page to come back from. "Edit" turns the same card into the fields to
/// type it in, with Save and Cancel; nothing changes until Save.
struct PharmacySheet: View {
    let pharmacy: Pharmacy
    /// Keeps the pharmacy as it was edited.
    let onSave: (Pharmacy) -> Void
    let onClose: () -> Void

    /// The copy being edited; nil while the card only shows the pharmacy.
    @State private var draft: Pharmacy?
    /// Half the screen to look at; all of it to type in.
    @State private var detent: PresentationDetent

    @Environment(\.openURL) private var openURL

    /// - Parameter startsEditing: Opens on the fields; for previews and demos.
    init(pharmacy: Pharmacy, startsEditing: Bool = false,
         onSave: @escaping (Pharmacy) -> Void, onClose: @escaping () -> Void) {
        self.pharmacy = pharmacy
        self.onSave = onSave
        self.onClose = onClose
        _draft = State(initialValue: startsEditing ? pharmacy : nil)
        _detent = State(initialValue: startsEditing ? .large : .medium)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if draft != nil {
                    editing
                } else {
                    showing
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 28)
            .padding(.bottom, 12)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { buttons }
        .background(Palette.background)
        .scrollDismissesKeyboard(.interactively)
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        // What was typed isn't lost to a slip of the finger: Save and Cancel are the ways out.
        .interactiveDismissDisabled(draft != nil)
    }

    @ViewBuilder
    private var showing: some View {
        title("My pharmacy")

        if pharmacy.isEmpty {
            empty
        } else {
            contact
            if let nextRefill = pharmacy.nextRefill { refill(nextRefill) }
            if !pharmacy.hours.isEmpty { hours }
            if let urls = pharmacy.googleMapsURLs { location(opening: urls) }
        }
    }

    @ViewBuilder
    private var editing: some View {
        title(pharmacy.isEmpty ? "Add my pharmacy" : "Edit my pharmacy")

        PharmacyForm(pharmacy: Binding(get: { draft ?? pharmacy }, set: { draft = $0 }))
    }

    /// Edit and Close, or Save and Cancel while editing: the dark one on the left, each
    /// half the row. They stay at the bottom of the card while the rest scrolls, so the
    /// way to save is never below a long form.
    private var buttons: some View {
        HStack(spacing: 12) {
            if draft != nil {
                WideButton(title: "Save", systemImage: "checkmark") {
                    if let draft { onSave(draft) }
                    stopEditing()
                }
                SecondaryButton(title: "Cancel", fillsWidth: true, action: stopEditing)
            } else {
                if !pharmacy.isEmpty {
                    WideButton(title: "Edit", systemImage: "pencil", action: startEditing)
                }
                SecondaryButton(title: "Close", fillsWidth: true, action: onClose)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Palette.background)
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .font(Palette.pageTitle)
            .foregroundStyle(Palette.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    private func startEditing() {
        withAnimation(.easeInOut(duration: 0.2)) {
            draft = pharmacy
            detent = .large
        }
    }

    /// Back to showing the pharmacy: as saved, or as it was if this is Cancel.
    private func stopEditing() {
        withAnimation(.easeInOut(duration: 0.2)) { draft = nil }
    }

    /// Before a pharmacy is typed in: what this is for, and the way to add it.
    private var empty: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add your pharmacy's phone number and opening hours, to have them here when you need to call.")
                .font(.body)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            WideButton(title: "Add my pharmacy", systemImage: "plus", action: startEditing)
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

    /// The next refill: when, and how long until then. A date that has passed says so
    /// instead of passing for the next one.
    private func refill(_ date: Date) -> some View {
        let countdown = pharmacy.refillCountdown()
        return VStack(alignment: .leading, spacing: 4) {
            sectionTitle(countdown == nil ? "Refill was due" : "Next refill")
            Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.system(.title2, design: .serif, weight: .medium))
                .foregroundStyle(Palette.textPrimary)
            Text(countdown.map { $0.prefix(1).uppercased() + $0.dropFirst() } ?? "Set the next date with Edit.")
                .font(.body)
                .foregroundStyle(Palette.textSecondary)
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
    /// Maps. Tapping the map, which is Apple's, opens Apple's Maps; the button under it
    /// opens Google Maps. The map doesn't move, so the page under it still scrolls.
    private func location(opening urls: (app: URL, web: URL)) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                sectionTitle("Location")
                if !pharmacy.address.isEmpty {
                    Text(pharmacy.address)
                        .font(.body)
                        .foregroundStyle(Palette.textBody)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let coordinate = pharmacy.coordinate, let appleMaps = pharmacy.appleMapsURL {
                Button {
                    openURL(appleMaps)
                } label: {
                    PharmacyMap(name: pharmacy.name, coordinate: coordinate)
                        // The map takes no touches itself; this takes the tap for it.
                        .overlay(Color.clear.contentShape(Rectangle()))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(pharmacy.name.isEmpty ? "Map of your pharmacy" : "Map of \(pharmacy.name)")
                .accessibilityHint("Opens Apple Maps")
            }
            Button {
                // The Google Maps app; without it, Google Maps in the browser.
                openURL(urls.app) { opened in
                    if !opened { openURL(urls.web) }
                }
            } label: {
                Label("Open in Google Maps", systemImage: "arrow.up.right.square")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Palette.due)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
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
        PharmacySheet(pharmacy: .sample(), onSave: { _ in }, onClose: {})
    }
}

#Preview("None yet") {
    Color.clear.sheet(isPresented: .constant(true)) {
        PharmacySheet(pharmacy: Pharmacy(), onSave: { _ in }, onClose: {})
    }
}

#Preview("Editing") {
    Color.clear.sheet(isPresented: .constant(true)) {
        PharmacySheet(pharmacy: .sample(), startsEditing: true, onSave: { _ in }, onClose: {})
    }
}
#endif
