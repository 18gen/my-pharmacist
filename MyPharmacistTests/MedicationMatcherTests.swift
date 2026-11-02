//
//  MedicationMatcherTests.swift
//  MyPharmacistTests
//

import Testing
@testable import MyPharmacist

struct MedicationMatcherTests {
    private let medications = TestMedications.all

    @Test(arguments: ["METFORMIN HCL 500MG", "Metformin 500 mg", "metformin 500.0 mg"])
    func matchesTheRegisteredMedication(_ scanned: String) {
        #expect(MedicationMatcher.match(scannedName: scanned, in: medications) == .match(TestMedications.metformin))
    }

    @Test(arguments: [
        "METFORMIN ER 500 MG",  // different release type
        "METFORMIN 850 MG",     // different strength
        "METFORMIN",            // no strength at all
        "IBUPROFEN 200 MG",     // not registered
    ])
    func rejectsLabelsThatAreNotAnExactFit(_ scanned: String) {
        #expect(MedicationMatcher.match(scannedName: scanned, in: medications) == .none)
    }

    @Test func twoFittingMedicationsAreAmbiguous() {
        let copy = Medication(id: "metformin-500-b", name: "Metformin", strength: "500 mg",
                              doseTimes: [DoseTime(12)])
        #expect(MedicationMatcher.match(scannedName: "METFORMIN 500 MG", in: medications + [copy]) == .ambiguous)
    }

    @Test func tokensSplitNumbersFromUnits() {
        #expect(MedicationMatcher.tokens("Metformin HCl 500mg") == ["metformin", "hcl", "500", "mg"])
    }

    @Test func strengthsNormaliseNumbersAndUnits() {
        #expect(MedicationMatcher.strengths(in: ["500.0", "mg"]) == ["500 mg"])
        #expect(MedicationMatcher.strengths(in: ["0.5", "mg"]) == ["0.5 mg"])
        #expect(MedicationMatcher.strengths(in: ["2", "units"]) == ["2 unit"])
        #expect(MedicationMatcher.strengths(in: ["take", "2"]) == [])
    }
}
