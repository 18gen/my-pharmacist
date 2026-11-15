//
//  PharmacyEditor.swift
//  MyPharmacist
//

import CoreLocation
import SwiftUI

/// The page where the pharmacy is typed in: its name, phone number, address, opening
/// hours and the next refill date. A map under them shows where the address was found. Opened from My Medications. It is saved as it's changed, like a
/// medication on the list.
struct PharmacyEditor: View {
    @Bindable var store: PharmacyStore
    @Environment(\.dismiss) private var dismiss
    /// The address the map was last brought up to date for; nil until the page opens.
    @State private var locatedAddress: String?
    /// The address typed couldn't be found on the map.
    @State private var addressNotFound = false

    /// How long typing has to pause before the address is looked up.
    private static let pause = Duration.seconds(0.8)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GlassIconButton(systemName: "chevron.left", accessibilityLabel: "Back") {
                    dismiss()
                }
                Text("My pharmacy")
                    .font(Palette.pageTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: 14) {
                    field("Name") {
                        TextField("Name", text: $store.pharmacy.name, prompt: Text("For example, Maple Street Pharmacy"))
                            .textInputAutocapitalization(.words)
                    }
                    field("Phone number") {
                        TextField("Phone number", text: $store.pharmacy.phone, prompt: Text("For example, 519-555-0142"))
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                    }
                    field("Address") {
                        TextField("Address", text: $store.pharmacy.address,
                                  prompt: Text("For example, 200 University Ave W, Waterloo"), axis: .vertical)
                            .lineLimit(1...3)
                            .textContentType(.fullStreetAddress)
                            .textInputAutocapitalization(.words)
                    }
                    if let coordinate = store.pharmacy.coordinate {
                        PharmacyMap(name: store.pharmacy.name, coordinate: coordinate)
                            // A new map for a new place, rather than a slide across town.
                            .id("\(coordinate.latitude),\(coordinate.longitude)")
                    } else if addressNotFound {
                        Text("Couldn't find this address on the map. Check it, or add the city.")
                            .font(.body)
                            .foregroundStyle(Palette.late)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    field("Opening hours") {
                        TextField("Opening hours", text: $store.pharmacy.hours,
                                  prompt: Text("For example, Monday to Friday 9 AM – 6 PM"), axis: .vertical)
                            .lineLimit(1...6)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardBackground()

                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: hasRefill.animation(.easeInOut(duration: 0.2))) {
                        Text("Next refill date")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Palette.textPrimary)
                    }
                    .tint(Palette.due)
                    if store.pharmacy.nextRefill != nil {
                        DatePicker("Next refill date", selection: refillDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(Palette.due)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardBackground()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Palette.background)
        .scrollDismissesKeyboard(.interactively)
        .task(id: store.pharmacy.address) { await locate() }
        .toolbar(.hidden, for: .navigationBar)
        .edgeSwipeBack()
    }

    private func field(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
            content()
                .font(.title3)
                .padding(.vertical, 6)
        }
    }

    /// Brings the pin up to date with the address, once typing has paused. An address
    /// that already has its place when the page opens is left alone.
    private func locate() async {
        let address = store.pharmacy.address.trimmingCharacters(in: .whitespacesAndNewlines)
        if locatedAddress == nil, store.pharmacy.coordinate != nil || address.isEmpty {
            locatedAddress = address
            return
        }
        guard address != locatedAddress else { return }
        // Cancelled, and started again, by the next letter typed.
        guard (try? await Task.sleep(for: Self.pause)) != nil else { return }
        let found = address.isEmpty ? nil : await PharmacyLocator.find(address)
        guard !Task.isCancelled else { return }
        locatedAddress = address
        withAnimation(.easeInOut(duration: 0.2)) {
            store.pharmacy.coordinate = found
            addressNotFound = found == nil && !address.isEmpty
        }
    }

    /// On: a date a week from now to start from. Off: no date.
    private var hasRefill: Binding<Bool> {
        Binding(
            get: { store.pharmacy.nextRefill != nil },
            set: { on in
                store.pharmacy.nextRefill = on ? Calendar.current.date(byAdding: .day, value: 7, to: Date()) : nil
            }
        )
    }

    private var refillDate: Binding<Date> {
        Binding(
            get: { store.pharmacy.nextRefill ?? Date() },
            set: { store.pharmacy.nextRefill = $0 }
        )
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        PharmacyEditor(store: PharmacyStore(pharmacy: .sample()))
    }
}
#endif
