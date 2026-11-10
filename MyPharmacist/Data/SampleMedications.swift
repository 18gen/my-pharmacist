//
//  SampleMedications.swift
//  MyPharmacist
//

import Foundation

/// Mock prescriptions for the prototype's story: a patient on oral hormone therapy for
/// breast cancer (exemestane), with the supportive medications that often come with it.
/// In the real product these arrive from the pharmacy's records when prescribed. The
/// schedules are examples only, not advice.
///
/// The sample list is made of pills from the ePillID benchmark (NIH NLM images), so the
/// demo can be run with ePillID pictures and, later, with a model trained on ePillID.
/// Three more from the NLM C3PI image set can be added from the catalog. Strengths,
/// imprints and sizes checked against RxNorm and the FDA labels by NDC.
nonisolated enum SampleMedications {
    /// Every medication that can be put on the list.
    static let all: [Medication] = sampleList + more

    /// What a new list starts with.
    static let startingIDs = sampleList.map(\.id)

    /// What "Restore the sample list" sets, times included, for demos: the C3PI tablets
    /// and the as-needed ondansetron. Two doses at 12 AM, so something is due around
    /// midnight as well as in the morning and evening.
    static let restorePlans: [MedicationPlan] = [
        MedicationPlan(medicationID: "capecitabine-500", doseTimes: [DoseTime(0), DoseTime(20)], isAsNeeded: false),
        MedicationPlan(medicationID: "dexamethasone-4", doseTimes: [DoseTime(0)], isAsNeeded: false),
        MedicationPlan(medicationID: "allopurinol-300", doseTimes: [DoseTime(8)], isAsNeeded: false),
        // Kept with a morning time, used only if it's switched to set times.
        MedicationPlan(medicationID: "ondansetron-8", doseTimes: [DoseTime(8)], isAsNeeded: true),
    ]

    /// From ePillID: two photos each, front and back.
    private static let sampleList: [Medication] = [
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
    private static func photos(_ id: String, count: Int) -> [String] {
        (1...count).map { "\(id)-\($0)" }
    }
}
