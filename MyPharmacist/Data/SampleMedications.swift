//
//  SampleMedications.swift
//  MyPharmacist
//

import Foundation

/// Mock prescriptions for the prototype's story: a patient on oral capecitabine
/// chemotherapy for breast cancer, with the supportive medications that often come with
/// it. In the real product these arrive from the pharmacy's records when prescribed.
/// The schedules are examples only, not advice.
///
/// Photos: U.S. National Library of Medicine, Computational Photography Project for Pill
/// Identification (C3PI), released for research and development use. Strengths checked
/// against RxNorm by NDC.
nonisolated enum SampleMedications {
    static let all: [Medication] = [
        Medication(
            id: "capecitabine-500",
            name: "Capecitabine",
            strength: "500 mg",
            doseTimes: [DoseTime(8), DoseTime(20)],
            appearance: "Pink oval · XELODA / 500",   // NDC 0004-1101-50 (Xeloda)
            photos: photos("capecitabine-500")
        ),
        Medication(
            id: "ondansetron-8",
            name: "Ondansetron",
            strength: "8 mg",
            doseTimes: [DoseTime(8), DoseTime(20)],
            appearance: "Yellow oval · 131",          // NDC 62756-131-01
            photos: photos("ondansetron-8")
        ),
        Medication(
            id: "dexamethasone-4",
            name: "Dexamethasone",
            strength: "4 mg",
            doseTimes: [DoseTime(8)],
            appearance: "Green round · 54 892",       // NDC 0054-4184-25
            photos: photos("dexamethasone-4")
        ),
        Medication(
            id: "allopurinol-300",
            name: "Allopurinol",
            strength: "300 mg",
            doseTimes: [DoseTime(8)],
            appearance: "Orange round · 5544 / DAN DAN", // NDC 0591-5544-01
            photos: photos("allopurinol-300")
        ),
    ]

    /// The four reference photos in the asset catalog: front, front, back, back
    /// (front, back, front, back for allopurinol).
    private static func photos(_ id: String) -> [String] {
        (1...4).map { "\(id)-\($0)" }
    }
}
