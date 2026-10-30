//
//  SampleMedications.swift
//  MedLens
//

import Foundation

/// Temporary sample data until medications can be registered in the app.
/// These are common real medications so printed or real labels can be scanned,
/// but the schedules are examples only, not advice.
nonisolated enum SampleMedications {
    static let all: [Medication] = [
        Medication(
            id: "metformin-500",
            name: "Metformin",
            strength: "500 mg",
            doseTimes: [DoseTime(8), DoseTime(18)],
            symbol: "pill.fill",
            tint: .blue
        ),
        Medication(
            id: "lisinopril-10",
            name: "Lisinopril",
            strength: "10 mg",
            doseTimes: [DoseTime(8)],
            symbol: "pill.fill",
            tint: .orange
        ),
        Medication(
            id: "atorvastatin-20",
            name: "Atorvastatin",
            strength: "20 mg",
            doseTimes: [DoseTime(21)],
            symbol: "capsule.fill",
            tint: .pink
        ),
    ]
}
