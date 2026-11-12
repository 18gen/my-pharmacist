//
//  OnboardingTests.swift
//  MyPharmacistTests
//

import Foundation
import Testing
@testable import MyPharmacist

@MainActor
struct OnboardingTests {
    @Test func theIntroductionShowsUntilItIsFinishedAndAgainAfterAReset() {
        let defaults = isolatedDefaults()
        #expect(!Onboarding.isDone(in: defaults))
        Onboarding.markDone(in: defaults)
        #expect(Onboarding.isDone(in: defaults))
        Onboarding.reset(in: defaults)
        #expect(!Onboarding.isDone(in: defaults))
    }

    @Test func resettingLeavesEverythingElseSaved() {
        let defaults = isolatedDefaults()
        let list = UserDefaultsMedicationListStorage(defaults: defaults)
        let scans = UserDefaultsDoseLogStorage(defaults: defaults)
        let entries = [MedicationEntry(name: "Metformin", doseTimes: [DoseTime(8)])]
        let log = ["2026-10-14|metformin-500@8:00": TestClock.at(8)]
        list.save(entries)
        scans.save(log)
        defaults.set(true, forKey: PillCheckConsent.key)
        Onboarding.markDone(in: defaults)

        Onboarding.reset(in: defaults)

        #expect(list.load() == entries)
        #expect(scans.load() == log)
        #expect(defaults.bool(forKey: PillCheckConsent.key))
    }
}
