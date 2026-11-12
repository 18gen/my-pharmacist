//
//  MedicationEditor.swift
//  MyPharmacist
//

import SwiftUI

/// One medication's page, to add a new one or change one on the list: photos of the
/// tablet (front and back), its name, strength and what it's for, and when it's taken,
/// at set times (each named by its time of day, as on the home screen) or only when
/// needed. A medication on the list changes as it's edited; a new one is added with one
/// button once it has a name and a photo.
struct MedicationEditor: View {
    enum Mode {
        case add
        case edit
    }

    let store: MedicationStore
    let mode: Mode
    /// Called after adding (to close the sheet) or removing (to close the page). It goes
    /// by the navigation path rather than `dismiss`, which a confirmation dialog that is
    /// closing itself can swallow.
    var onDone: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var draft: MedicationEntry
    /// The times in the order they were set, so a row doesn't jump while its time changes.
    @State private var times: [TimeRow]
    /// Photos taken while this page was open, so the ones not kept can be deleted.
    @State private var newPhotos: [MedicationPhoto] = []
    @State private var wasAdded = false
    @State private var isConfirmingRemove = false

    /// Offered in turn by "Add a time": the usual times of day.
    private static let suggestedTimes = [DoseTime(8), DoseTime(12), DoseTime(18), DoseTime(21)]

    /// - Parameter entry: The medication to change; nil to add a new one.
    init(store: MedicationStore, entry: MedicationEntry? = nil, onDone: @escaping () -> Void = {}) {
        self.store = store
        self.mode = entry == nil ? .add : .edit
        self.onDone = onDone
        let draft = entry ?? MedicationEntry()
        _draft = State(initialValue: draft)
        _times = State(initialValue: draft.orderedTimes.map(TimeRow.init))
    }

    /// What's still needed before a new medication can be added, in words; nil when ready.
    private var missing: String? {
        let hasName = !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        switch (hasName, !draft.photos.isEmpty) {
        case (false, false): return "Add a photo of the pill and its name."
        case (false, true): return "Add the medication's name."
        case (true, false): return "Add a photo of the pill, so a scan can recognize it."
        case (true, true): return nil
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                topBar
                photos
                details
                schedule
                footer
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Palette.background)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: times.map(\.time)) { _, times in
            draft.doseTimes = times
        }
        .onChange(of: draft) { _, entry in
            // Changes to a medication on the list apply as they're made: no Save to forget.
            if mode == .edit { store.update(entry) }
        }
        .onDisappear(perform: deleteUnkeptPhotos)
        .confirmationDialog("Remove \(draft.name) from your medications?",
                            isPresented: $isConfirmingRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                store.remove(draft.id)
                onDone()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its photos are deleted, it won't be on the home screen, and a scan will show its pill as unknown.")
        }
        .toolbar(.hidden, for: .navigationBar)
        .edgeSwipeBack()
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Back without adding is how a new one is cancelled.
            GlassIconButton(systemName: "chevron.left", accessibilityLabel: mode == .add ? "Cancel" : "Back") {
                dismiss()
            }
            Text(mode == .add ? "New medication" : draft.name)
                .font(Palette.pageTitle)
                .foregroundStyle(Palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
        }
    }

    /// Front and back of the tablet: what a scanned pill is compared with.
    private var photos: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Photos of the pill")
            Text("Put the pill alone on a plain surface. Take the front, then the back.")
                .font(.body)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 12) {
                PillPhotoSlot(title: "Front", photo: photoBinding(0), onSaved: { newPhotos.append($0) })
                PillPhotoSlot(title: "Back", photo: photoBinding(1), onSaved: { newPhotos.append($0) })
            }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 14) {
            field("Name", text: $draft.name, prompt: "For example, Capecitabine")
            field("Strength", text: $draft.strength, prompt: "For example, 500 mg")
            field("What it's for", text: $draft.purpose, prompt: "For example, Cancer treatment")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }

    private var schedule: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("When to take")
            VStack(alignment: .leading, spacing: 4) {
                Picker("When to take", selection: $draft.isAsNeeded.animation(.easeInOut(duration: 0.2))) {
                    Text("At set times").tag(false)
                    Text("Only when needed").tag(true)
                }
                .pickerStyle(.segmented)
                .controlSize(.large)
                .padding(.bottom, 8)

                if draft.isAsNeeded {
                    field("When", text: $draft.asNeededNote, prompt: MedicationEntry.defaultAsNeeded)
                } else {
                    timeList
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardBackground()
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title2.bold())
            .foregroundStyle(Palette.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    private func field(_ label: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
            TextField(label, text: text, prompt: Text(prompt))
                .font(.title3)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .padding(.vertical, 6)
        }
    }

    /// The photo in one of the two places, kept in order: front first.
    private func photoBinding(_ index: Int) -> Binding<MedicationPhoto?> {
        Binding(
            get: { draft.photos.indices.contains(index) ? draft.photos[index] : nil },
            set: { photo in
                var slots: [MedicationPhoto?] = [draft.photos.first, draft.photos.dropFirst().first]
                slots[index] = photo
                draft.photos = slots.compactMap { $0 }
            }
        )
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
            VStack(spacing: 8) {
                WideButton(title: "Add to my medications", systemImage: "plus") {
                    wasAdded = store.add(draft)
                    if wasAdded { onDone() }
                }
                .disabled(missing != nil)
                if let missing {
                    Text(missing)
                        .font(.body)
                        .foregroundStyle(Palette.textTertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
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

    /// Photos taken here that the medication doesn't have in the end: replaced, removed,
    /// or never added because the page was cancelled.
    private func deleteUnkeptPhotos() {
        let kept = (mode == .add && !wasAdded) ? [] : (store.entry(draft.id)?.photos ?? [])
        for photo in newPhotos where !kept.contains(photo) {
            MedicationPhotoStore.standard.delete(photo)
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

#if DEBUG
#Preview("New medication") {
    NavigationStack {
        MedicationEditor(store: MedicationStore(storage: InMemoryDoseLogStorage()))
    }
}

#Preview("A medication on the list") {
    let store = MedicationStore(entries: SampleMedications.demoList, storage: InMemoryDoseLogStorage())
    NavigationStack {
        MedicationEditor(store: store, entry: store.entries[2])
    }
}
#endif
