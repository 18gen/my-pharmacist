//
//  MedicationLine.swift
//  MyPharmacist
//

import SwiftUI

/// One medication in a home screen card: a large picture of the tablet to compare with
/// the one in hand, its name and strength, and what it's for (or, for one taken only when
/// needed, when that is). No dose times: the card says when. Once its pill is scanned,
/// the picture is the pill as it was scanned, inside a camera's green corner marks, so
/// the row needs no words to say so. On the right, a box to tick once it is
/// taken; ticked, it turns green with the time under it. Unticking asks first, in a bubble
/// beside the box, so a slip doesn't lose the record. The words of a taken dose step
/// back a little; its picture stays clear.
struct MedicationLine: View {
    let medication: Medication
    /// When this dose's pill was scanned today; nil if it wasn't.
    var scannedAt: Date? = nil
    /// The pill as it was scanned; nil when it wasn't, or the app was closed since.
    var scanPhoto: CGImage? = nil
    /// When the person marked this dose taken; nil if they didn't.
    var takenAt: Date? = nil
    /// Ticks or unticks the box; unticking only once the person has said so in the
    /// bubble. Nil for a dose that can't be ticked yet: no box.
    var onToggleTaken: (() -> Void)? = nil

    /// The bubble asking whether to untick is showing.
    @State private var asksToUntick = false

    @ScaledMetric(relativeTo: .title3) private var pictureSize: CGFloat = 64
    @ScaledMetric(relativeTo: .title2) private var boxSize: CGFloat = 36
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 14) {
                // At accessibility text sizes the picture gives its room to the words.
                if !typeSize.isAccessibilitySize {
                    // Beige tiles: the page's cream would vanish on the white card.
                    if scannedAt != nil {
                        ScannedPillImage(medication: medication, photo: scanPhoto, size: pictureSize)
                    } else {
                        PillImage(medication: medication, size: pictureSize, tileFill: Palette.cardFill)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    name
                    detail
                }
                .opacity(takenAt != nil ? 0.7 : 1)

                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(medication.displayName)
            .accessibilityValue([medication.asNeeded ?? medication.purpose,
                                 scannedAt.map { "Scanned at \($0.shortTime)" } ?? "",
                                 onToggleTaken == nil ? takenAt.map { "Taken at \($0.shortTime)" } ?? "" : ""]
                .filter { !$0.isEmpty }.joined(separator: ", "))

            if let onToggleTaken {
                takenBox(onToggleTaken)
            }
        }
        .padding(.vertical, 8)
        #if DEBUG
        .onAppear { if DemoScan.untickAsked == medication.id, takenAt != nil { asksToUntick = true } }
        #endif
    }

    /// The box to tick, square as on a paper list, with words under it so it isn't only a
    /// shape: "Taken?" while empty, the time it was ticked once it is.
    ///
    /// Ticking changes only the box and its words, never where things are: the column is
    /// always as wide as its widest words, the digits are all one width, and both boxes
    /// sit in the same square.
    private func takenBox(_ toggle: @escaping () -> Void) -> some View {
        Button {
            if takenAt == nil { toggle() } else { asksToUntick = true }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: takenAt == nil ? "square" : "checkmark.square.fill")
                    // One weight for both, so the empty and ticked box are the same size.
                    .font(.system(size: boxSize, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: boxSize * 1.2, height: boxSize * 1.2)
                ZStack {
                    Text("Taken?").hidden()
                    Text(Self.widestTime).hidden()
                    Text(takenAt?.shortTime ?? "Taken?")
                }
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .fixedSize()
            }
            .foregroundStyle(takenAt == nil ? Palette.textSecondary : Palette.ok)
            .frame(minWidth: 56, minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: takenAt != nil) { _, taken in taken }
        .accessibilityLabel("\(medication.displayName) taken")
        .accessibilityValue(takenAt.map { "Yes, at \($0.shortTime)" } ?? "No")
        .accessibilityHint(takenAt == nil ? "Double tap to mark it taken" : "Double tap to mark it not taken")
        // To the left of the box, pointing at it; a bubble on iPhone too, not a sheet.
        .popover(isPresented: $asksToUntick, attachmentAnchor: .rect(.bounds), arrowEdge: .trailing) {
            untickQuestion(toggle)
                .presentationCompactAdaptation(.popover)
        }
    }

    /// The widest a ticked time gets, "10:58 PM" or "22:58" as the phone writes times: it
    /// keeps the box's column from growing when "Taken?" turns into a time.
    private static let widestTime: String = {
        let late = Calendar.current.date(bySettingHour: 22, minute: 58, second: 0, of: Date()) ?? Date()
        return late.shortTime
    }()

    /// "Mark Exemestane as not taken?", with the way to do it and the way out.
    private func untickQuestion(_ toggle: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mark \(medication.name) as not taken?")
                .font(.headline)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            WideButton(title: "Not taken", systemImage: "xmark", tint: Palette.danger) {
                asksToUntick = false
                toggle()
            }
            SecondaryButton(title: "Cancel", fillsWidth: true) { asksToUntick = false }
        }
        .padding(16)
        .frame(width: 250)
        .presentationBackground(Palette.background)
    }

    /// "Capecitabine  500 mg" on one line when it fits, the strength under the name when not.
    private var name: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                nameText
                strengthText
            }
            VStack(alignment: .leading, spacing: 0) {
                nameText
                strengthText
            }
        }
    }

    private var nameText: some View {
        Text(medication.name)
            .font(.title3.weight(.semibold))
            .foregroundStyle(Palette.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var strengthText: some View {
        Text(medication.strength)
            .font(.body)
            .foregroundStyle(Palette.textSecondary)
    }

    @ViewBuilder
    private var detail: some View {
        if let asNeeded = medication.asNeeded {
            // The same caution sign its pill gets in scan results.
            Label(asNeeded, systemImage: "exclamationmark.triangle.fill")
                .font(.body)
                .foregroundStyle(Palette.caution)
        } else if !medication.purpose.isEmpty {
            Text(medication.purpose)
                .font(.body)
                .foregroundStyle(Palette.textSecondary)
        }
    }
}

/// Medications one under another, with dividers between them.
struct MedicationLineList: View {
    struct Item {
        let medication: Medication
        var scannedAt: Date? = nil
        var scanPhoto: CGImage? = nil
        var takenAt: Date? = nil
        var onToggleTaken: (() -> Void)? = nil
    }

    let items: [Item]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Divider()
                }
                MedicationLine(medication: item.medication, scannedAt: item.scannedAt, scanPhoto: item.scanPhoto,
                               takenAt: item.takenAt,
                               onToggleTaken: item.onToggleTaken)
            }
        }
    }
}
