//
//  ShareSnapshotTests.swift
//  MyPharmacistTests
//

import Foundation
import Testing
@testable import MyPharmacist

/// The snapshot the pharmacy demo gets, as the dashboard's format 1 has it.
@MainActor
struct ShareSnapshotTests {
    private let now = TestClock.at(8, 30)
    private let yesterday = TestClock.calendar.date(byAdding: .day, value: -1, to: TestClock.at(8, 30))!

    /// Metformin scanned at 8:05 today, lisinopril ticked at 8:10, yesterday's atorvastatin
    /// ticked at 9:15 PM, ondansetron scanned yesterday at 8 PM, and one scan that stopped a
    /// second metformin and found an unknown pill.
    private func made() -> (store: MedicationStore, reports: ScanReports) {
        let store = MedicationStore(medications: TestMedications.all + [TestMedications.ondansetron],
                                    calendar: TestClock.calendar, now: now)
        let today = store.doses(on: now)
        store.recordScan(of: today.filter { $0.id == "2026-10-14|metformin-500@8:00" }, at: TestClock.at(8, 5))
        store.markTaken(today.filter { $0.id == "2026-10-14|lisinopril-10@8:00" }, at: TestClock.at(8, 10))
        store.markTaken(store.doses(on: yesterday).filter { $0.medication.id == "atorvastatin-20" },
                        at: TestClock.at(21, 15, on: yesterday))
        store.recordAsNeededScan(of: TestMedications.ondansetron, at: TestClock.at(20, on: yesterday), photo: nil)

        let reports = ScanReports(calendar: TestClock.calendar, now: now)
        reports.record(ScanReports.Report(session: UUID(), at: TestClock.at(8, 20), pills: [
            ScanReports.Pill(medicationID: "metformin-500", outcome: .alreadyTaken, takenAt: TestClock.at(8, 5)),
            ScanReports.Pill(medicationID: nil, outcome: .unknown),
        ]), now: now)
        return (store, reports)
    }

    private func snapshot() -> ShareSnapshot {
        let (store, reports) = made()
        return ShareSnapshot.make(store: store, reports: reports, now: now)
    }

    @Test func coversTheLastSevenDaysTodayLast() {
        #expect(snapshot().days == ["2026-10-08", "2026-10-09", "2026-10-10", "2026-10-11", "2026-10-12", "2026-10-13", "2026-10-14"])
    }

    @Test func listsTheMedicationsWithTheirTimes() {
        let medications = snapshot().medications
        #expect(medications.map(\.id) == ["metformin-500", "lisinopril-10", "atorvastatin-20", "ondansetron-8"])
        #expect(medications[0].times == ["08:00", "18:00"])
        #expect(medications[0].asNeeded == false)
        #expect(medications[3].times == [])
        #expect(medications[3].asNeeded)
    }

    @Test func hasEveryScheduledDoseWithWhetherAndHowItWasTaken() throws {
        let doses = snapshot().doses
        #expect(doses.count == 7 * 4)
        let metformin = try #require(doses.first { $0.day == "2026-10-14" && $0.medicationID == "metformin-500" && $0.time == "08:00" })
        #expect(metformin.scheduledAt == TestClock.at(8))
        #expect(metformin.takenAt == TestClock.at(8, 5))
        #expect(metformin.scanned)
        let lisinopril = try #require(doses.first { $0.day == "2026-10-14" && $0.medicationID == "lisinopril-10" })
        #expect(lisinopril.takenAt == TestClock.at(8, 10))
        #expect(!lisinopril.scanned)
        let atorvastatin = try #require(doses.first { $0.day == "2026-10-13" && $0.medicationID == "atorvastatin-20" })
        #expect(atorvastatin.takenAt == TestClock.at(21, 15, on: yesterday))
        let evening = try #require(doses.first { $0.day == "2026-10-14" && $0.time == "18:00" })
        #expect(evening.takenAt == nil)
    }

    @Test func hasWhenNeededTabletsOnTheDaysTheyWereTaken() {
        #expect(snapshot().asNeeded == [ShareSnapshot.SharedAsNeeded(day: "2026-10-13", medicationID: "ondansetron-8",
                                                                     takenAt: TestClock.at(20, on: yesterday), scanned: true)])
    }

    @Test func hasWhatEachScanSaid() {
        let scans = snapshot().scans
        #expect(scans.count == 1)
        #expect(scans[0].pills.map(\.outcome) == [.alreadyTaken, .unknown])
        #expect(scans[0].pills[0].takenAt == TestClock.at(8, 5))
    }

    @Test func isJSONInTheDashboardsFormat() throws {
        let json = try #require(try JSONSerialization.jsonObject(with: snapshot().json()) as? [String: Any])
        #expect(json["v"] as? Int == 1)
        // Foundation calls UTC "GMT"; both are time zones the dashboard knows.
        #expect(json["timeZone"] as? String == TestClock.calendar.timeZone.identifier)
        #expect(json["sentAt"] as? String == "2026-10-14T08:30:00Z")
        #expect(json["earlyWindowMinutes"] as? Int == 60)
        #expect(json["lateWindowMinutes"] as? Int == 120)

        let doses = try #require(json["doses"] as? [[String: Any]])
        let taken = try #require(doses.first { $0["medicationId"] as? String == "metformin-500" && $0["day"] as? String == "2026-10-14" && $0["time"] as? String == "08:00" })
        #expect(taken["takenAt"] as? String == "2026-10-14T08:05:00Z")
        #expect(taken["scheduledAt"] as? String == "2026-10-14T08:00:00Z")
        // A dose not taken leaves "takenAt" out: the dashboard takes no null there.
        let pending = try #require(doses.first { $0["medicationId"] as? String == "metformin-500" && $0["time"] as? String == "18:00" })
        #expect(pending.keys.contains("takenAt") == false)

        let pills = try #require((json["scans"] as? [[String: Any]])?.first?["pills"] as? [[String: Any]])
        #expect(pills[0]["outcome"] as? String == "alreadyTaken")
        // An unknown pill's medication is null, not left out.
        #expect(pills[1].keys.contains("medicationId"))
        #expect(pills[1]["medicationId"] is NSNull)
        #expect(pills[1]["outcome"] as? String == "unknown")
    }

    @Test func eachDosesTimeIsExactAcrossAChangeOfClocks() throws {
        // Toronto's clocks went back an hour on 1 November 2026: 8 AM was 12:00 UTC on
        // 31 October and 13:00 UTC on 1 November.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 10))!
        let store = MedicationStore(medications: [TestMedications.lisinopril], calendar: calendar, now: now)
        let snapshot = ShareSnapshot.make(store: store, reports: ScanReports(calendar: calendar, now: now), now: now)
        let formatter = ISO8601DateFormatter()
        let times = Dictionary(uniqueKeysWithValues: snapshot.doses.map { ($0.day, formatter.string(from: $0.scheduledAt)) })
        #expect(snapshot.timeZone == "America/Toronto")
        #expect(times["2026-10-31"] == "2026-10-31T12:00:00Z")
        #expect(times["2026-11-01"] == "2026-11-01T13:00:00Z")
    }

    @Test func saysWhereThePhonesRecordsStart() {
        // Yesterday's ondansetron at 8 PM is the first thing recorded.
        #expect(snapshot().recordsSince == "2026-10-13")
        let fresh = MedicationStore(medications: TestMedications.all, calendar: TestClock.calendar, now: now)
        let nothing = ShareSnapshot.make(store: fresh, reports: ScanReports(calendar: TestClock.calendar, now: now), now: now)
        #expect(nothing.recordsSince == "2026-10-14")
    }

    @Test func namesAScanPictureOnlyOnceTheDashboardHasIt() throws {
        let (store, reports) = made()
        let metformin = UUID(), stopped = UUID(), ondansetron = UUID()
        reports.record(ScanReports.Report(session: UUID(), at: TestClock.at(8, 5), pills: [
            ScanReports.Pill(medicationID: "metformin-500", outcome: .take, doseTime: DoseTime(8), photoID: metformin),
        ]), photos: [metformin: testImage()], now: now)
        reports.record(ScanReports.Report(session: UUID(), at: TestClock.at(20, on: yesterday), pills: [
            ScanReports.Pill(medicationID: "ondansetron-8", outcome: .asNeeded, photoID: ondansetron),
        ]), now: now)
        reports.record(ScanReports.Report(session: UUID(), at: TestClock.at(8, 25), pills: [
            ScanReports.Pill(medicationID: "metformin-500", outcome: .alreadyTaken, takenAt: TestClock.at(8, 5), photoID: stopped),
        ]), now: now)

        let unsent = ShareSnapshot.make(store: store, reports: reports, now: now)
        #expect(unsent.doses.allSatisfy { $0.photoID == nil })
        #expect(unsent.scans.flatMap(\.pills).allSatisfy { $0.photoID == nil })

        let sent = ShareSnapshot.make(store: store, reports: reports, now: now, sentPhotos: [metformin, stopped, ondansetron])
        let dose = try #require(sent.doses.first { $0.day == "2026-10-14" && $0.medicationID == "metformin-500" && $0.time == "08:00" })
        #expect(dose.photoID == metformin.uuidString.lowercased())
        let ticked = try #require(sent.doses.first { $0.day == "2026-10-14" && $0.medicationID == "lisinopril-10" })
        #expect(ticked.photoID == nil)
        #expect(sent.asNeeded.first?.photoID == ondansetron.uuidString.lowercased())
        #expect(sent.scans.last?.pills.first?.photoID == stopped.uuidString.lowercased())

        let json = try #require(try JSONSerialization.jsonObject(with: sent.json()) as? [String: Any])
        let doses = try #require(json["doses"] as? [[String: Any]])
        #expect(doses.contains { $0["photoId"] as? String == metformin.uuidString.lowercased() })
        // A dose with no picture leaves "photoId" out.
        #expect(doses.filter { $0["photoId"] != nil }.count == 1)
    }

    @Test func leavesOutWhatTheDashboardWouldRefuse() {
        let many = (0..<14).map { DoseTime($0 + 6) }
        let store = MedicationStore(medications: [Medication(id: "many", name: "Many", strength: "", doseTimes: many)],
                                    calendar: TestClock.calendar, now: now)
        let snapshot = ShareSnapshot.make(store: store, reports: ScanReports(calendar: TestClock.calendar, now: now), now: now)
        #expect(snapshot.medications[0].times.count == ShareSnapshot.Limits.timesPerMedication)
        #expect(snapshot.doses.count == 7 * ShareSnapshot.Limits.timesPerMedication)
    }
}
