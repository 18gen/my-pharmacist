//
//  ScanFeedback.swift
//  MyPharmacist
//

import SwiftUI

/// What a scan's steps say to VoiceOver and feel like in the hand: why a photo has to
/// be taken again, the question about the circled pills, and the results. On screen
/// these are only shown, so each is spoken as it appears.
struct ScanFeedback: ViewModifier {
    let scan: ScanFlow

    func body(content: Content) -> some View {
        content
            .onChange(of: scan.phase.step) { _, step in
                if let text = announcement(for: step) {
                    AccessibilityNotification.Announcement(text).post()
                }
            }
            .sensoryFeedback(trigger: scan.phase.step) { _, step in
                feedback(for: step)
            }
    }

    private func announcement(for step: ScanFlow.Step) -> String? {
        switch scan.phase {
        case .retake(_, let reason) where step == .retake:
            ScanInstruction.retake(reason).text
        case .confirming(let found) where step == .confirming:
            ScanInstruction.confirm(count: found.boxes.count).spoken
        case .checking where step == .checking:
            "Checking your pills"
        case .results(let result) where step == .results:
            result.summary
        default:
            nil
        }
    }

    /// A warning when the photo has to be taken again, a tap for the question, and for
    /// the results success only when every pill is OK to take and nothing is missing.
    private func feedback(for step: ScanFlow.Step) -> SensoryFeedback? {
        switch scan.phase {
        case .retake where step == .retake:
            .warning
        case .confirming where step == .confirming:
            .impact(weight: .medium)
        case .results(let result) where step == .results:
            result.isAllClear ? .success : .warning
        default:
            nil
        }
    }
}
