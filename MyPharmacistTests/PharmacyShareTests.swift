//
//  PharmacyShareTests.swift
//  MyPharmacistTests
//

import Foundation
import Testing
@testable import MyPharmacist

/// The pharmacy demo's server as a fake: what it was asked, and the failures to answer with.
private actor FakeDemo: PharmacyDemo {
    private(set) var joins: [String] = []
    private(set) var sends: [String] = []
    private(set) var leaves: [String] = []
    private var joinFailure: ShareFailure?
    /// Answered in order, one per sending; success once they run out.
    private var sendFailures: [ShareFailure] = []

    func failJoining(with failure: ShareFailure) { joinFailure = failure }
    func failSending(with failures: ShareFailure...) { sendFailures = failures }

    func join(name: String) async throws(ShareFailure) -> String {
        joins.append(name)
        if let joinFailure { throw joinFailure }
        return "person-\(joins.count)"
    }

    func send(_ snapshot: ShareSnapshot, as id: String) async throws(ShareFailure) {
        sends.append(id)
        if !sendFailures.isEmpty { throw sendFailures.removeFirst() }
    }

    func leave(_ id: String) async throws(ShareFailure) {
        leaves.append(id)
    }
}

@MainActor
struct PharmacyShareTests {
    private let demo = FakeDemo()
    private let sentAt = TestClock.at(8, 30)

    private func makeShare(defaults: UserDefaults? = nil) -> PharmacyShare {
        let share = PharmacyShare(demo: demo, defaults: defaults, debounce: .milliseconds(10),
                                  retryAfter: .milliseconds(30), now: { TestClock.at(8, 30) })
        share.makeSnapshot = { now in
            ShareSnapshot(v: 1, sentAt: now, timeZone: "GMT", earlyWindowMinutes: 60, lateWindowMinutes: 120,
                          days: ["2026-10-14"], medications: [], doses: [], asNeeded: [], scans: [])
        }
        return share
    }

    /// Long enough for the short waits above to pass: for checking that something didn't happen.
    private func settle() async throws {
        try await Task.sleep(for: .milliseconds(150))
    }

    /// Waits until `condition` holds, up to a few seconds: for checking that something did
    /// happen, however busy the machine running the tests is.
    private func eventually(_ condition: () async -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + .seconds(5)
        while ContinuousClock.now < deadline {
            if await condition() { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return await condition()
    }

    @Test func startingJoinsUnderTheNameAsTypedAndSendsAtOnce() async {
        let share = makeShare()
        await share.start(name: "  Maria \n")
        #expect(await demo.joins == ["Maria"])
        #expect(share.session == PharmacyShare.Session(id: "person-1", name: "Maria"))
        #expect(await demo.sends == ["person-1"])
        #expect(share.delivery == .sent(sentAt))
    }

    @Test func aBurstOfChangesSendsOnce() async throws {
        let share = makeShare()
        await share.start(name: "Maria")
        share.changed()
        share.changed()
        share.changed()
        #expect(await eventually { await demo.sends.count == 2 })
        try await settle()
        #expect(await demo.sends.count == 2)
    }

    @Test func nothingIsSentWhileNotSharing() async throws {
        let share = makeShare()
        share.changed()
        share.appBecameActive()
        try await settle()
        #expect(await demo.sends.isEmpty)
    }

    @Test func theDemoEndingItStopsSharingAndSaysSo() async throws {
        let share = makeShare()
        await share.start(name: "Maria")
        await demo.failSending(with: .gone)
        share.appBecameActive()
        #expect(await eventually { share.session == nil })
        #expect(share.stoppedByDemo)
        #expect(share.lastName == "Maria")
    }

    @Test func aSendingThatFailedIsTriedAgain() async throws {
        let share = makeShare()
        await demo.failSending(with: .offline)
        await share.start(name: "Maria")
        #expect(share.delivery == .failed(.offline))
        #expect(await eventually { share.delivery == .sent(sentAt) })
        #expect(await demo.sends.count == 2)
    }

    @Test func aBuildTheDemoRefusesIsNotTriedAgain() async throws {
        let share = makeShare()
        await demo.failSending(with: .notAllowed)
        await share.start(name: "Maria")
        try await settle()
        #expect(await demo.sends.count == 1)
        #expect(share.delivery == .failed(.notAllowed))
    }

    @Test func stoppingLeavesTheDemoAndSendsNothingMore() async throws {
        let share = makeShare()
        await share.start(name: "Maria")
        await share.stop()
        share.changed()
        try await settle()
        #expect(await demo.leaves == ["person-1"])
        #expect(share.session == nil)
        #expect(!share.stoppedByDemo)
        #expect(await demo.sends.count == 1)
    }

    @Test func aStartThatFailedSaysWhyAndCanBeTriedAgain() async {
        let share = makeShare()
        await demo.failJoining(with: .full)
        await share.start(name: "Maria")
        #expect(share.session == nil)
        #expect(share.startFailure == .full)
        #expect(await demo.sends.isEmpty)
    }

    @Test func anEmptyNameStartsNothing() async {
        let share = makeShare()
        await share.start(name: "   ")
        #expect(await demo.joins.isEmpty)
    }

    @Test func whoThisPhoneSharesAsIsKeptAcrossLaunches() async {
        let defaults = isolatedDefaults()
        await makeShare(defaults: defaults).start(name: "Maria")
        let relaunched = makeShare(defaults: defaults)
        #expect(relaunched.session == PharmacyShare.Session(id: "person-1", name: "Maria"))
        #expect(relaunched.lastName == "Maria")
    }

    @Test func withoutTheDemosAddressThereIsNoSharing() async {
        let share = PharmacyShare(demo: nil)
        #expect(!share.isAvailable)
        await share.start(name: "Maria")
        #expect(share.session == nil)
    }

    @Test func aNameIsCutToWhatTheDemoTakes() {
        #expect(PharmacyShare.tidied(String(repeating: "a", count: 50)).count == PharmacyShare.nameLength)
    }
}

struct PharmacyShareConfigurationTests {
    private func configuration(_ address: String, token: String = "a-token") -> PharmacyShareClient.Configuration? {
        PharmacyShareClient.Configuration.from(["PHARMACY_URL": address, "PHARMACY_TOKEN": token])
    }

    @Test func needsAnHTTPSAddressAndAToken() {
        #expect(configuration("https://my-pharmacist-dashboard.vercel.app")?.token == "a-token")
        #expect(configuration("http://example.com") == nil)
        #expect(configuration("https://my-pharmacist-dashboard.vercel.app", token: "paste-your-app-token-here") == nil)
        #expect(configuration("https://my-pharmacist-dashboard.vercel.app", token: " ") == nil)
        #expect(PharmacyShareClient.Configuration.from([:]) == nil)
    }

    @Test func debugBuildsMayUseTheDashboardOnThisMac() {
        #expect(configuration("http://localhost:3000") != nil)
        #expect(configuration("http://192.168.1.20:3000") == nil)
    }

    @Test func eachStatusMeansSomething() {
        #expect(ShareFailure(status: 404) == .gone)
        #expect(ShareFailure(status: 401) == .notAllowed)
        #expect(ShareFailure(status: 409) == .full)
        #expect(ShareFailure(status: 429) == .busy)
        #expect(ShareFailure(status: 413) == .refused)
        #expect(ShareFailure(status: 503) == .server(status: 503))
        #expect(ShareFailure.offline.mayPassLater)
        #expect(!ShareFailure.notAllowed.mayPassLater)
    }
}
