//
//  HomeView.swift
//  MedLens
//

import SwiftUI

/// Home screen content above the scan button: date and time, the "My Medications"
/// button, and today's doses.
struct HomeView: View {
    let store: MedicationStore
    /// Opens the "My Medications" page.
    let onShowMedications: () -> Void

    var body: some View {
        // Redraw every minute so the clock and "in 2 hr" labels stay current.
        TimelineView(.everyMinute) { context in
            VStack(alignment: .leading, spacing: 20) {
                HomeHeader(now: context.date, onShowMedications: onShowMedications)
                TodayCard(store: store, now: context.date)
            }
        }
    }
}
