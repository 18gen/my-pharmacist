//
//  PharmacyForm.swift
//  MyPharmacist
//

import CoreLocation
import SwiftUI

/// The fields the pharmacy is typed into, shown in its card while it is being edited: its
/// name, phone number, address, opening hours and the next refill date. A map under the
/// address shows where it was found. It changes the copy it is given; the card decides
/// whether that is saved.
struct PharmacyForm: View {
    @Binding var pharmacy: Pharmacy
    /// The address the map was last brought up to date for; nil until the form appears.
    @State private var locatedAddress: String?
    /// Why the address typed has no place on the map; nil when it has one, or none was typed.
    @State private var addressProblem: PharmacyLocator.Outcome?

    /// How long typing has to pause before the address is looked up.
    private static let pause = Duration.seconds(0.8)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                LabeledField("Name") {
                    TextField("Name", text: $pharmacy.name, prompt: Text("For example, Maple Street Pharmacy"))
                        .textInputAutocapitalization(.words)
                }
                LabeledField("Phone number") {
                    TextField("Phone number", text: $pharmacy.phone, prompt: Text("For example, 519-555-0142"))
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                }
                LabeledField("Address") {
                    TextField("Address", text: $pharmacy.address,
                              prompt: Text("For example, 200 University Ave W, Waterloo"), axis: .vertical)
                        .lineLimit(1...3)
                        .textContentType(.fullStreetAddress)
                        .textInputAutocapitalization(.words)
                }
                if let coordinate = pharmacy.coordinate {
                    PharmacyMap(name: pharmacy.name, coordinate: coordinate)
                        // A new map for a new place, rather than a slide across town.
                        .id("\(coordinate.latitude),\(coordinate.longitude)")
                } else if let addressProblem {
                    Text(addressProblem == .unreachable
                         ? "Can't reach the map to find this address now. It is looked up again when you save."
                         : "Couldn't find this address on the map. Check it, or add the city.")
                        .font(.body)
                        .foregroundStyle(Palette.late)
                        .fixedSize(horizontal: false, vertical: true)
                }
                LabeledField("Opening hours") {
                    TextField("Opening hours", text: $pharmacy.hours,
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
                if pharmacy.nextRefill != nil {
                    DatePicker("Next refill date", selection: refillDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(Palette.due)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardBackground()
        }
        .task(id: pharmacy.address) { await locate() }
        // A pin for the address before this one would be in the wrong place: none, until
        // the new address is found.
        .onChange(of: pharmacy.address) { _, address in
            guard let locatedAddress,
                  address.trimmingCharacters(in: .whitespacesAndNewlines) != locatedAddress else { return }
            pharmacy.coordinate = nil
        }
    }

    /// Brings the pin up to date with the address, once typing has paused. An address
    /// that already has its place when the form appears is left alone.
    private func locate() async {
        let address = pharmacy.address.trimmingCharacters(in: .whitespacesAndNewlines)
        if locatedAddress == nil, pharmacy.coordinate != nil || address.isEmpty {
            locatedAddress = address
            return
        }
        guard address != locatedAddress else { return }
        // Cancelled, and started again, by the next letter typed.
        guard (try? await Task.sleep(for: Self.pause)) != nil else { return }
        let outcome = address.isEmpty ? nil : await PharmacyLocator.find(address)
        guard !Task.isCancelled else { return }
        locatedAddress = address
        withAnimation(.easeInOut(duration: 0.2)) {
            if case .found(let latitude, let longitude) = outcome {
                pharmacy.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                addressProblem = nil
            } else {
                pharmacy.coordinate = nil
                addressProblem = outcome
            }
        }
    }

    /// On: a date a week from now to start from. Off: no date.
    private var hasRefill: Binding<Bool> {
        Binding(
            get: { pharmacy.nextRefill != nil },
            set: { on in
                pharmacy.nextRefill = on ? Calendar.current.date(byAdding: .day, value: Pharmacy.sampleRefillDays, to: Date()) : nil
            }
        )
    }

    private var refillDate: Binding<Date> {
        Binding(
            get: { pharmacy.nextRefill ?? Date() },
            set: { pharmacy.nextRefill = $0 }
        )
    }
}

#if DEBUG
#Preview {
    @Previewable @State var pharmacy = Pharmacy.sample()
    ScrollView {
        PharmacyForm(pharmacy: $pharmacy)
            .padding(16)
    }
    .background(Palette.background)
}
#endif
