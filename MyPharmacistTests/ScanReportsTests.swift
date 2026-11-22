//
//  ScanReportsTests.swift
//  MyPharmacistTests
//

import CoreGraphics
import Foundation
import Testing
@testable import MyPharmacist

@MainActor
struct ScanReportsTests {
    private let morning = TestClock.at(8)

    private func report(_ session: UUID = UUID(), at time: Date, _ outcome: ScanReports.Outcome = .take) -> ScanReports.Report {
        ScanReports.Report(session: session, at: time, pills: [ScanReports.Pill(medicationID: "metformin-500", outcome: outcome)])
    }

    @Test func aPhotoTakenAgainReplacesItsSessionsReport() {
        let reports = ScanReports(calendar: TestClock.calendar, now: morning)
        let session = UUID()
        reports.record(report(session, at: morning, .extra), now: morning)
        reports.record(report(at: morning.addingTimeInterval(30)), now: morning)
        reports.record(report(session, at: morning.addingTimeInterval(60), .take), now: morning)
        #expect(reports.reports.count == 2)
        #expect(reports.reports.last == report(session, at: morning.addingTimeInterval(60), .take))
    }

    @Test func onlyTheLastSevenDaysAreKept() {
        let reports = ScanReports(calendar: TestClock.calendar, now: morning)
        let calendar = TestClock.calendar
        let sixDaysAgo = TestClock.at(0, 1, on: calendar.date(byAdding: .day, value: -6, to: morning)!)
        let sevenDaysAgo = TestClock.at(23, 59, on: calendar.date(byAdding: .day, value: -7, to: morning)!)
        reports.record(report(at: sevenDaysAgo), now: morning)
        reports.record(report(at: sixDaysAgo), now: morning)
        #expect(reports.reports.map(\.at) == [sixDaysAgo])
    }

    @Test func atMostAHundredAreKeptTheLatest() {
        let reports = ScanReports(calendar: TestClock.calendar, now: morning)
        for minute in 0..<(ScanReports.keptCount + 5) {
            reports.record(report(at: morning.addingTimeInterval(Double(minute) * 60)), now: morning)
        }
        #expect(reports.reports.count == ScanReports.keptCount)
        #expect(reports.reports.first?.at == morning.addingTimeInterval(5 * 60))
    }

    @Test func theyAreSavedAndReadBack() {
        let defaults = isolatedDefaults()
        let saved = ScanReports(defaults: defaults, calendar: TestClock.calendar, now: morning)
        saved.record(report(at: morning, .alreadyTaken), now: morning)
        let read = ScanReports(defaults: defaults, calendar: TestClock.calendar, now: morning)
        #expect(read.reports == saved.reports)
    }

    @Test func clearingThemIsReported() {
        let reports = ScanReports(calendar: TestClock.calendar, now: morning)
        var changes = 0
        reports.onChange = { changes += 1 }
        reports.record(report(at: morning), now: morning)
        reports.removeAll()
        #expect(changes == 2)
        #expect(reports.reports.isEmpty)
    }

    @Test func aScansPicturesAreKeptInMemoryWithItsReportAndGoWithIt() {
        let reports = ScanReports(calendar: TestClock.calendar, now: morning)
        let session = UUID(), first = UUID(), retaken = UUID()
        func pictured(_ id: UUID, at time: Date) -> ScanReports.Report {
            ScanReports.Report(session: session, at: time, pills: [ScanReports.Pill(medicationID: "metformin-500", outcome: .take, photoID: id)])
        }
        reports.record(pictured(first, at: morning), photos: [first: testImage()], now: morning)
        #expect(reports.photos.keys.sorted { $0.uuidString < $1.uuidString } == [first])

        // A photo taken again replaces the report, and its picture.
        reports.record(pictured(retaken, at: morning.addingTimeInterval(30)), photos: [retaken: testImage()], now: morning)
        #expect(Array(reports.photos.keys) == [retaken])

        reports.removeAll()
        #expect(reports.photos.isEmpty)
    }

    @Test func onlyTheLatestPicturesAreKept() {
        let reports = ScanReports(calendar: TestClock.calendar, now: morning)
        var ids: [UUID] = []
        for minute in 0..<(ScanReports.keptPhotos + 3) {
            let id = UUID()
            ids.append(id)
            reports.record(ScanReports.Report(session: UUID(), at: morning.addingTimeInterval(Double(minute) * 60),
                                              pills: [ScanReports.Pill(medicationID: nil, outcome: .unknown, photoID: id)]),
                           photos: [id: testImage()], now: morning)
        }
        #expect(Set(reports.photos.keys) == Set(ids.suffix(ScanReports.keptPhotos)))
    }

    @Test func thePicturesIDsAreSavedButNotThePictures() {
        let defaults = isolatedDefaults()
        let id = UUID()
        let saved = ScanReports(defaults: defaults, calendar: TestClock.calendar, now: morning)
        saved.record(ScanReports.Report(session: UUID(), at: morning, pills: [ScanReports.Pill(medicationID: nil, outcome: .unknown, photoID: id)]),
                     photos: [id: testImage()], now: morning)
        let read = ScanReports(defaults: defaults, calendar: TestClock.calendar, now: morning)
        #expect(read.reports.first?.pills.first?.photoID == id)
        #expect(read.photos.isEmpty)
    }

    @Test func eachVerdictKeepsWhatTheDashboardSays() {
        let dose = Dose(medication: TestMedications.metformin, time: DoseTime(8), day: morning, calendar: TestClock.calendar)
        let evening = Dose(medication: TestMedications.metformin, time: DoseTime(18), day: morning, calendar: TestClock.calendar)
        let id = "metformin-500"
        #expect(ScanReports.Pill(medicationID: id, verdict: .take(dose))
                == ScanReports.Pill(medicationID: id, outcome: .take, doseTime: DoseTime(8)))
        #expect(ScanReports.Pill(medicationID: id, verdict: .alreadyTaken(dose, at: morning, next: evening))
                == ScanReports.Pill(medicationID: id, outcome: .alreadyTaken, takenAt: morning))
        #expect(ScanReports.Pill(medicationID: id, verdict: .missed(dose, next: evening))
                == ScanReports.Pill(medicationID: id, outcome: .missed, doseTime: DoseTime(8)))
        #expect(ScanReports.Pill(medicationID: id, verdict: .tooEarly(next: evening))
                == ScanReports.Pill(medicationID: id, outcome: .tooEarly, doseTime: DoseTime(18)))
        #expect(ScanReports.Pill(medicationID: id, verdict: .extra(TestMedications.metformin)).outcome == .extra)
        #expect(ScanReports.Pill(medicationID: "anything", verdict: .unidentified)
                == ScanReports.Pill(medicationID: nil, outcome: .unknown))
    }
}

/// What a scan keeps in the record of scans.
@MainActor
struct ScanFlowReportTests {
    private let store = MedicationStore(medications: TestMedications.all)
    private let reports = ScanReports()
    private let morning = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!

    private func pill(_ medication: Medication?, x: Double = 0.1) -> AnalyzedPill {
        AnalyzedPill(box: CGRect(x: x, y: 0.4, width: 0.1, height: 0.1), crop: testImage(), medicationID: medication?.id)
    }

    @Test func aScanKeepsWhatItSaidAboutEveryPill() {
        let flow = ScanFlow(store: store, reports: reports)
        flow.setOpen(true)
        flow.showResults([pill(TestMedications.metformin), pill(TestMedications.metformin, x: 0.5), pill(nil, x: 0.7)],
                         photo: testImage(), now: morning)
        #expect(reports.reports.count == 1)
        #expect(reports.reports.first?.pills.map(\.outcome) == [.take, .extra, .unknown])
        // Each pill's cut-out is kept under the picture ID its line was given.
        let ids = reports.reports.first?.pills.compactMap(\.photoID) ?? []
        #expect(ids.count == 3)
        #expect(Set(reports.photos.keys) == Set(ids))
    }

    @Test func aRetakeReplacesTheReportAndTheNextSessionAddsOne() {
        let flow = ScanFlow(store: store, reports: reports)
        flow.setOpen(true)
        flow.showResults([pill(TestMedications.metformin), pill(nil, x: 0.5)], photo: testImage(), now: morning)
        flow.showResults([pill(TestMedications.metformin)], photo: testImage(), now: morning.addingTimeInterval(60))
        #expect(reports.reports.map { $0.pills.map(\.outcome) } == [[.take]])

        flow.setOpen(false)
        flow.setOpen(true)
        flow.showResults([pill(TestMedications.metformin)], photo: testImage(), now: morning.addingTimeInterval(120))
        #expect(reports.reports.map { $0.pills.map(\.outcome) } == [[.take], [.alreadyTaken]])
    }

    @Test func theDemoRecordsNothing() {
        let flow = ScanFlow(store: store, reports: reports)
        flow.setOpen(true)
        flow.showResults([pill(TestMedications.metformin)], photo: testImage(), now: morning, records: false)
        #expect(reports.reports.isEmpty)
    }
}
