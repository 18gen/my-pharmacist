//
//  MedicationEditor.swift
//  MyPharmacist
//

import SwiftUI

/// One medication's page: what it is, and when it's taken, at set times (each named by
/// its time of day, as on the home screen) or only when needed. Editing a medication on
/// the list changes it straight away and has a button to remove it; adding one from the
/// catalog sets the times first and adds it with one button.
struct MedicationEditor: View {
    enum Mode {
        case edit
        case add
    }

    let store: MedicationStore
    /// The catalog entry: name, strength, photos.
    let entry: Medication
    let mode: Mode
    /// Called after adding, to close the "Add a medication" sheet.
    var onAdded: () -> Void = {}
    /// Called after removing, to close this page. It goes by the navigation path rather
    /// than `dismiss`, which a confirmation dialog that is closing itself can swallow.
    var onRemoved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    /// The times in the order they were set, so a row doesn't jump while its time changes.
    @State private var times: [TimeRow]
    @State private var isAsNeeded: Bool
    @State private var isConfirmingRemove = false

    /// Offered in turn by "Add a time": the usual times of day.
    private static let suggestedTimes = [DoseTime(8), DoseTime(12), DoseTime(18), DoseTime(21)]

    init(store: MedicationStore, entry: Medication, mode: Mode,
         onAdded: @escaping () -> Void = {}, onRemoved: @escaping () -> Void = {}) {
        self.store = store
        self.entry = entry
        self.mode = mode
        self.onAdded = onAdded
        self.onRemoved = onRemoved
        let plan = store.plan(for: entry.id) ?? MedicationPlan(preset: entry)
        _times = State(initialValue: plan.orderedTimes.map(TimeRow.init))
        _isAsNeeded = State(initialValue: plan.isAsNeeded)
    }

    private var draft: MedicationPlan {
        MedicationPlan(medicationID: entry.id, doseTimes: times.map(\.time), isAsNeeded: isAsNeeded)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GlassIconButton(systemName: "chevron.left", accessibilityLabel: "Back") {
                    dismiss()
                }

                header

                Text("When to take")
                    .font(.title2.bold())
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: 4) {
                    Picker("When to take", selection: $isAsNeeded.animation(.easeInOut(duration: 0.2))) {
                        Text("At set times").tag(false)
                        Text("Only when needed").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.large)
                    .padding(.bottom, 8)

                    if isAsNeeded {
                        Label(entry.asNeeded ?? MedicationStore.defaultAsNeeded, systemImage: "exclamationmark.triangle.fill")
                            .font(.title3)
                            .foregroundStyle(Palette.caution)
                            .padding(.vertical, 8)
                    } else {
                        timeList
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardBackground()

                footer
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Palette.background)
        .onChange(of: draft) { _, plan in
            // Changes to a medication on the list apply as they're made: no Save to forget.
            if mode == .edit { store.update(plan) }
        }
        .confirmationDialog("Remove \(entry.name) from your medications?",
                            isPresented: $isConfirmingRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                store.remove(entry.id)
                onRemoved()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It won't be on the home screen, and a scan will show its pill as unknown.")
        }
        .toolbar(.hidden, for: .navigationBar)
        .edgeSwipeBack()
    }

    /// A large picture of the tablet with its name, strength, use and look.
    private var header: some View {
        HStack(spacing: 16) {
            PillImage(medication: entry, size: 88)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(.title.bold())
                    .foregroundStyle(Palette.textPrimary)
                Text([entry.strength, entry.purpose].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)
                if !entry.appearance.isEmpty {
                    Text(entry.appearance)
                        .font(.subheadline)
                        .foregroundStyle(Palette.textTertiary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var timeList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach($times) { $row in
                TimeRowView(row: $row, canRemove: times.count > 1) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        times.removeAll { $0.id == row.id }
                    }
                }
                Divider()
            }
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    times.append(TimeRow(nextSuggestedTime()))
                }
            } label: {
                Label("Add a time", systemImage: "plus.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette.due)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch mode {
        case .add:
            WideButton(title: "Add to my medications", systemImage: "plus") {
                store.add(draft)
                onAdded()
            }
        case .edit:
            Button(role: .destructive) {
                isConfirmingRemove = true
            } label: {
                Label("Remove from my medications", systemImage: "trash")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 34)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(Palette.danger)
        }
    }

    /// The first usual time not set yet, or an hour after the last one.
    private func nextSuggestedTime() -> DoseTime {
        let taken = Set(times.map(\.time))
        if let free = Self.suggestedTimes.first(where: { !taken.contains($0) }) {
            return free
        }
        var candidate = times.map(\.time).max() ?? DoseTime(8)
        repeat {
            candidate = DoseTime((candidate.hour + 1) % 24, candidate.minute)
        } while taken.contains(candidate)
        return candidate
    }
}

/// One time in the editor, with an identity of its own so rows keep their place while
/// their times change.
struct TimeRow: Identifiable {
    let id = UUID()
    var time: DoseTime

    init(_ time: DoseTime) {
        self.time = time
    }
}

/// "Morning   [8:00 AM]   ⊖": the time of day's name and symbol, the time to change, and
/// a button to remove it (not for the last time left).
private struct TimeRowView: View {
    @Binding var row: TimeRow
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        let period = DayPeriod(row.time)
        HStack(spacing: 12) {
            Label {
                Text(period.name)
                    .font(.title3)
                    .foregroundStyle(Palette.textPrimary)
            } icon: {
                Image(systemName: period.symbol)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer(minLength: 8)
            DatePicker("Time", selection: date, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(canRemove ? Palette.danger : Palette.textMuted.opacity(0.4))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canRemove)
            .accessibilityLabel("Remove \(row.time.date(on: Date()).shortTime)")
        }
        .padding(.vertical, 4)
    }

    /// The time as today's date, for the picker.
    private var date: Binding<Date> {
        Binding(
            get: { row.time.date(on: Date()) },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                row.time = DoseTime(parts.hour ?? row.time.hour, parts.minute ?? row.time.minute)
            }
        )
    }
}
