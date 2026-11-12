//
//  SampleMedications.swift
//  MyPharmacist
//

import Foundation

/// Sample medications with built-in photos, for trying the app without one's own pills:
/// an oncology patient's tablets and the supportive medications that often come with
/// them. The schedules are examples only, not advice.
///
/// The photos are from the ePillID benchmark and the NLM C3PI image set (NIH NLM), so
/// the printed demo pill sheet matches them. Strengths, imprints and sizes checked
/// against RxNorm and the FDA labels by NDC.
nonisolated enum SampleMedications {
    /// What "Load sample list" puts on the list, times included, for demos and App
    /// Review: the C3PI tablets and the as-needed ondansetron. Two doses at 12:30 PM and
    /// two at 8 PM, so something is due around midday and again in the evening.
    static let sampleList: [MedicationEntry] = [
        entry(more[0], times: [DoseTime(12,30), DoseTime(20)]),
        entry(more[1], times: [DoseTime(12,30)]),
        entry(more[2], times: [DoseTime(20)]),
        MedicationEntry(ePillID[3]),
    ]

    /// The ePillID medications at their usual times: what the debug demos and previews
    /// scan, as the demo pill sheet prints them.
    static let demoList: [MedicationEntry] = ePillID.map(MedicationEntry.init)

    private static func entry(_ medication: Medication, times: [DoseTime]) -> MedicationEntry {
        var entry = MedicationEntry(medication)
        entry.doseTimes = times
        return entry
    }

    /// From ePillID: two photos each, front and back.
    private static let ePillID: [Medication] = [
        Medication(
            id: "exemestane-25",
            name: "Exemestane",
            strength: "25 mg",
            doseTimes: [DoseTime(8)],
            appearance: "White round · 2858 printed in black",   // NDC 59762-2858-01
            photos: photos("exemestane-25", count: 2),
            purpose: "Breast cancer treatment"
        ),
        Medication(
            id: "dexamethasone-1-5",
            name: "Dexamethasone",
            strength: "1.5 mg",
            doseTimes: [DoseTime(8)],
            appearance: "Pink round · 54 943",                   // NDC 0054-4182-25
            photos: photos("dexamethasone-1-5", count: 2),
            purpose: "Reduces swelling"
        ),
        Medication(
            id: "metoclopramide-10",
            name: "Metoclopramide",
            strength: "10 mg",
            doseTimes: [DoseTime(8), DoseTime(20)],
            appearance: "White round · TEVA / 2203",             // NDC 0093-2203-01
            photos: photos("metoclopramide-10", count: 2),
            purpose: "Prevents nausea"
        ),
        // Taken only when needed, so it is never due and never missing.
        Medication(
            id: "ondansetron-8",
            name: "Ondansetron",
            strength: "8 mg",
            doseTimes: [],
            appearance: "Yellow round · 93 / 7236",              // NDC 0093-7236-56
            photos: photos("ondansetron-8", count: 2),
            purpose: "For nausea",
            asNeeded: "Only when you feel sick"
        ),
    ]

    /// From C3PI: four photos each, both sides.
    private static let more: [Medication] = [
        Medication(
            id: "capecitabine-500",
            name: "Capecitabine",
            strength: "500 mg",
            doseTimes: [DoseTime(8), DoseTime(20)],
            appearance: "Pink oval · XELODA / 500",              // NDC 0004-1101-50 (Xeloda)
            photos: photos("capecitabine-500", count: 4),
            purpose: "Cancer treatment"
        ),
        Medication(
            id: "dexamethasone-4",
            name: "Dexamethasone",
            strength: "4 mg",
            doseTimes: [DoseTime(8)],
            appearance: "Green round · 54 892",                  // NDC 0054-4184-25
            photos: photos("dexamethasone-4", count: 4),
            purpose: "Reduces swelling"
        ),
        Medication(
            id: "allopurinol-300",
            name: "Allopurinol",
            strength: "300 mg",
            doseTimes: [DoseTime(8)],
            appearance: "Orange round · 5544 / DAN DAN",         // NDC 0591-5544-01
            photos: photos("allopurinol-300", count: 4),
            purpose: "Lowers uric acid"
        ),
    ]

    /// Asset names "<id>-1" … "<id>-<count>"; the first is the one shown in lists.
    private static func photos(_ id: String, count: Int) -> [MedicationPhoto] {
        (1...count).map { .asset("\(id)-\($0)") }
    }
}
