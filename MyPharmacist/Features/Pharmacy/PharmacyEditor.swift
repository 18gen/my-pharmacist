//
//  PharmacyEditor.swift
//  MyPharmacist
//

import SwiftUI

/// The page where the pharmacy is typed in: its name, phone number, opening hours and
/// the next refill date. Opened from My Medications. It is saved as it's changed, like a
/// medication on the list.
struct PharmacyEditor: View {
    @Bindable var store: PharmacyStore
    @Environment(\.dismiss) private var dismiss

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
        PharmacyEditor(store: PharmacyStore(pharmacy: .sample))
    }
}
#endif
