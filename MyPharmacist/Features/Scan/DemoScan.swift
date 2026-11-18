//
//  DemoScan.swift
//  MyPharmacist
//

#if DEBUG
import SwiftUI
import UIKit

/// Debug builds only, for the Simulator, which has no camera. Nothing is recorded.
/// - `-demoScan` opens straight into the results page for a made-up photo; with
///   `-demoOpenRow <n>`, pill n's row is open. `-demoScanOK` is the results page for one
///   pill that is OK to take.
/// - `-demoFind` runs a made-up photo of pills on a palm-coloured surface through the
///   real steps instead: finding the pills (by colour alone, as Vision's subject lifting
///   doesn't run in the Simulator), the question whether every pill is circled, and
///   recognizing each. Add `-noCloud` to send nothing to the server (every pill is then unknown).
/// - `-demoRetake` does the same with the palm empty, so the photo has to be taken
///   again: the camera view with its moving picture, and Retake and Cancel.
/// - `-demoOpenClose` opens the camera a second after launch and closes it 2.5 seconds
///   later, to watch (or record) the button growing into the camera picture and back.
/// - `-demoChecking` opens on the results page standing ready while the pills are
///   checked, and stays there.
/// - `-demoMedications` opens Pills, `-demoNewMedication` the page to add one,
///   and `-demoAbout` About & privacy, with the demo medications. `-demoConsent` opens
///   the question asked before the first scan. `-demoHome` stays on Home, `-demoPharmacy`
///   opens the pharmacy's card over it and `-demoPharmacyEditor` the same card on its
///   fields. `-demoCard <code>` shows what a keychain card with that code would do,
///   and `-demoEmpty` is Home with no medications yet. `-demoTaken` is Home with four
///   medications due now: one untouched, one ticked by hand, two scanned (and so ticked);
///   `-demoUntick` the same with the bubble asking whether to untick one. `-demoDone` is
///   Home with Midday and Afternoon all taken and folded, Evening still to come.
/// - `-demoOnboarding` shows the introduction even after it has been finished. The other
///   arguments here skip it.
enum DemoScan {
    static var isRequested: Bool { showsResults || findsPills || retakes || opensAndCloses || checks || pages != nil }

    /// A demo that scans the made-up photo, whose pills are the demo medications'; the
    /// others show the sample list a new install starts with.
    static var scansDemoPhoto: Bool { showsResults || findsPills || retakes || opensAndCloses || checks }

    /// The text after `-demoCard`: a keychain card's code to show as if just scanned.
    static var card: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-demoCard"), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }


    /// Pages to open on launch, if asked for.
    static var pages: [AppRoute]? {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-demoNewMedication") { return [.medications, .newMedication] }
        if arguments.contains("-demoAbout") { return [.about] }
        if arguments.contains("-demoConsent") || arguments.contains("-demoHome") || startsEmpty || showsTaken || showsPharmacy || card != nil { return [] }
        if arguments.contains("-demoMedications") { return [.medications] }
        return nil
    }
    /// Home with ticked doses, from `takenStore()`.
    static var showsTaken: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-demoTaken") || arguments.contains("-demoUntick") || showsDone
    }

    /// With `-demoDone`: Midday and Afternoon all taken and folded, Evening still to come.
    static var showsDone: Bool { ProcessInfo.processInfo.arguments.contains("-demoDone") }

    /// Four medications due this minute, in memory: one untouched, one ticked by hand,
    /// and two scanned four minutes ago, which ticked them. With `-demoDone`, `doneStore`.
    static func takenStore(now: Date = Date(), calendar: Calendar = .current) -> MedicationStore {
        if showsDone { return doneStore(now: now) }
        let parts = calendar.dateComponents([.hour, .minute], from: now)
        let time = DoseTime(parts.hour ?? 8, parts.minute ?? 0)
        let entries = ["capecitabine-500", "dexamethasone-4", "allopurinol-300", "exemestane-25"]
            .compactMap(SampleMedications.builtIn)
            .map { entry -> MedicationEntry in
                var entry = entry
                entry.doseTimes = [time]
                return entry
            }
        let store = MedicationStore(entries: entries, storage: InMemoryDoseLogStorage())
        let doses = Dictionary(uniqueKeysWithValues: store.doses(on: now).map { ($0.medication.id, $0) })
        let earlier = now.addingTimeInterval(-4 * 60)
        store.recordScan(of: [doses["dexamethasone-4"], doses["exemestane-25"]].compactMap { $0 }, at: earlier)
        store.markTaken([doses["dexamethasone-4"], doses["exemestane-25"]].compactMap { $0 }, at: earlier)
        store.markTaken([doses["allopurinol-300"]].compactMap { $0 }, at: now)
        // Exemestane's pill as a scan would cut it; dexamethasone's picture is gone, as
        // after the app is closed, so it shows its own photo.
        if let dose = doses["exemestane-25"], let crop = madeUpCrop("exemestane-25-1") {
            store.keepScanPhoto(crop, of: dose)
        }
        return store
    }

    /// Midday's two medications and Afternoon's one ticked earlier, Evening's still to
    /// come: Home with finished times of day folded to "Midday ✓ Taken …".
    private static func doneStore(now: Date) -> MedicationStore {
        let plan: [(String, DoseTime)] = [("allopurinol-300", DoseTime(12, 30)), ("dexamethasone-4", DoseTime(12, 30)),
                                          ("capecitabine-500", DoseTime(15, 0)), ("exemestane-25", DoseTime(20, 0))]
        let entries = plan.compactMap { id, time -> MedicationEntry? in
            guard var entry = SampleMedications.builtIn(id) else { return nil }
            entry.doseTimes = [time]
            return entry
        }
        let store = MedicationStore(entries: entries, storage: InMemoryDoseLogStorage())
        let doses = Dictionary(uniqueKeysWithValues: store.doses(on: now).map { ($0.medication.id, $0) })
        store.markTaken([doses["allopurinol-300"]].compactMap { $0 }, at: now.addingTimeInterval(-52 * 60))
        store.markTaken([doses["dexamethasone-4"]].compactMap { $0 }, at: now.addingTimeInterval(-50 * 60))
        store.markTaken([doses["capecitabine-500"]].compactMap { $0 }, at: now.addingTimeInterval(-9 * 60))
        return store
    }

    /// A pill photo on a palm-coloured square with everything but the pill dimmed by
    /// half, roughly as `PillCropper` cuts a pill from a scan.
    private static func madeUpCrop(_ asset: String) -> CGImage? {
        guard let pill = UIImage(named: asset) else { return nil }
        let side: CGFloat = 384
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            UIColor(red: 0.42, green: 0.32, blue: 0.26, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            let length = side / 1.45
            let rect = CGRect(x: (side - length) / 2, y: (side - length) / 2, width: length, height: length)
            UIColor(red: 0.84, green: 0.66, blue: 0.54, alpha: 1).setFill()
            UIBezierPath(ovalIn: rect.insetBy(dx: -length * 0.06, dy: -length * 0.06)).fill()
            pill.draw(in: rect)
        }.cgImage
    }

    /// With `-demoUntick`: the medication whose ticked box shows the bubble asking
    /// whether to untick it, on Home as `-demoTaken` shows it.
    static var untickAsked: String? {
        ProcessInfo.processInfo.arguments.contains("-demoUntick") ? "exemestane-25" : nil
    }

    static var startsEmpty: Bool { ProcessInfo.processInfo.arguments.contains("-demoEmpty") }
    /// The pharmacy's card is open over Home.
    static var showsPharmacy: Bool { ProcessInfo.processInfo.arguments.contains("-demoPharmacy") || editsPharmacy }
    /// The card is open on its fields.
    static var editsPharmacy: Bool { ProcessInfo.processInfo.arguments.contains("-demoPharmacyEditor") }
    private static var checks: Bool { ProcessInfo.processInfo.arguments.contains("-demoChecking") }
    private static var opensAndCloses: Bool { ProcessInfo.processInfo.arguments.contains("-demoOpenClose") }
    private static var showsResults: Bool { ProcessInfo.processInfo.arguments.contains("-demoScan") || scansOK }
    static var scansOK: Bool { ProcessInfo.processInfo.arguments.contains("-demoScanOK") }

    /// The number after `-demoOpenRow`: the pill whose row of the results starts open.
    static var openRow: Int? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-demoOpenRow"), arguments.indices.contains(index + 1) else { return nil }
        return Int(arguments[index + 1])
    }
    private static var findsPills: Bool { ProcessInfo.processInfo.arguments.contains("-demoFind") }
    private static var retakes: Bool { ProcessInfo.processInfo.arguments.contains("-demoRetake") }

    static func run(in flow: ScanFlow) {
        if pages != nil {
            return
        } else if checks {
            let sample = samplePills()
            flow.showForPreview(.checking(FoundPills(photo: sample.photo, boxes: sample.pills.map(\.box))))
        } else if opensAndCloses {
            Task {
                try? await Task.sleep(for: .seconds(1))
                withAnimation(ScanLayout.openingAnimation) { flow.setOpen(true) }
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation(ScanLayout.openingAnimation) { flow.setOpen(false) }
            }
        } else if findsPills || retakes {
            Task { await find(in: flow, empty: retakes) }
        } else {
            show(in: flow)
        }
    }

    /// The sample pills at about their real sizes, two of them touching, on a surface
    /// the colour of a palm that is lit from below.
    static func find(in flow: ScanFlow, empty: Bool = false) async {
        let size = CGSize(width: 1134, height: 2016)   // 87.5 mm wide: about 13 pixels a millimetre
        let placed: [(photo: String?, middle: CGPoint, millimeters: CGFloat)] = [
            ("exemestane-25-1", CGPoint(x: 330, y: 800), 6),
            ("dexamethasone-1-5-1", CGPoint(x: 780, y: 760), 6),
            ("metoclopramide-10-1", CGPoint(x: 420, y: 1200), 8),
            ("metoclopramide-10-2", CGPoint(x: 524, y: 1200), 8),
            ("ondansetron-8-1", CGPoint(x: 800, y: 1260), 13),
            (nil, CGPoint(x: 600, y: 1560), 7),
        ].filter { _ in !empty }
        let photo = UIGraphicsImageRenderer(size: size, format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }())
            .image { context in
                let colours = [UIColor(red: 0.66, green: 0.50, blue: 0.42, alpha: 1).cgColor,
                               UIColor(red: 0.84, green: 0.65, blue: 0.55, alpha: 1).cgColor] as CFArray
                if let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colours, locations: [0, 1]) {
                    context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
                }
                for item in placed {
                    let side = item.millimeters * size.width / 87.5
                    pillImage(item.photo, side: side, trimmed: true)
                        .draw(in: CGRect(x: item.middle.x - side / 2, y: item.middle.y - side / 2, width: side, height: side))
                }
            }
        guard let image = photo.cgImage, let captured = CapturedPhoto(image: image) else { return }
        flow.setOpen(true)
        await flow.check(captured)
    }

    /// Results for the made-up photo below.
    static func show(in flow: ScanFlow) {
        let sample = samplePills()
        flow.setOpen(true)
        if scansOK {
            // One capecitabine, due now in `takenStore`, where the photo's first pill is.
            let pill = AnalyzedPill(box: sample.pills[0].box, crop: pillImage("capecitabine-500-1", side: 240).cgImage!,
                                    medicationID: "capecitabine-500")
            flow.showResults([pill], photo: sample.photo, records: false)
            return
        }
        flow.showResults(sample.pills, photo: sample.photo, records: false)
    }

    /// A made-up photo with one of each kind of line: two of the morning pills, a second
    /// metoclopramide, the as-needed ondansetron and a white pill not on the list. In
    /// reading order, because results number pills in the order given. Also used by the
    /// scan views' previews.
    static func samplePills() -> (photo: CGImage, pills: [AnalyzedPill]) {
        let size = CGSize(width: 1080, height: 1440)
        let placed: [(photo: String?, id: String?, rect: CGRect)] = [
            ("metoclopramide-10-1", "metoclopramide-10", CGRect(x: 140, y: 470, width: 240, height: 240)),
            ("exemestane-25-1", "exemestane-25", CGRect(x: 640, y: 480, width: 200, height: 200)),
            ("metoclopramide-10-2", "metoclopramide-10", CGRect(x: 120, y: 790, width: 240, height: 240)),
            ("ondansetron-8-1", "ondansetron-8", CGRect(x: 430, y: 800, width: 250, height: 250)),
            (nil, nil, CGRect(x: 760, y: 840, width: 140, height: 140)),
        ]
        let photo = UIGraphicsImageRenderer(size: size, format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }())
            .image { context in
                UIColor(red: 0.85, green: 0.82, blue: 0.78, alpha: 1).setFill()
                context.fill(CGRect(origin: .zero, size: size))
                for item in placed {
                    pillImage(item.photo, side: item.rect.width).draw(in: item.rect)
                }
            }
        let pills = placed.map { item in
            AnalyzedPill(
                box: CGRect(x: item.rect.minX / size.width, y: item.rect.minY / size.height,
                            width: item.rect.width / size.width, height: item.rect.height / size.height)
                    .insetBy(dx: 0.02, dy: 0.02),
                crop: pillImage(item.photo, side: item.rect.width).cgImage!,
                medicationID: item.id
            )
        }
        return (photo.cgImage!, pills)
    }

    /// The reference picture, or a plain white pill for the one not on the list.
    /// - Parameter trimmed: Without the clear margin around the reference picture's
    ///   pill, so the pill itself is `side` across.
    private static func pillImage(_ name: String?, side: CGFloat, trimmed: Bool = false) -> UIImage {
        if let name, let image = UIImage(named: name) {
            guard trimmed, let cgImage = image.cgImage, let tight = PillFinderTrim.tight(cgImage) else { return image }
            return UIImage(cgImage: tight)
        }
        let inset = trimmed ? 0 : side * 0.1
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in
            UIColor(white: 0.96, alpha: 1).setFill()
            UIBezierPath(ovalIn: CGRect(x: inset, y: inset, width: side - 2 * inset, height: side - 2 * inset)).fill()
        }
    }
}

/// Cuts a picture down to what isn't clear in it.
private enum PillFinderTrim {
    static func tight(_ image: CGImage) -> CGImage? {
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext.bitmap(width: width, height: height, transparent: true, data: buffer.baseAddress) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where bytes[(y * width + x) * 4 + 3] > 40 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        // Square, so a round pill stays round when drawn into a square.
        let side = max(maxX - minX, maxY - minY) + 1
        let rect = CGRect(x: (minX + maxX + 1 - side) / 2, y: (minY + maxY + 1 - side) / 2, width: side, height: side)
        return image.cropping(to: rect.intersection(CGRect(x: 0, y: 0, width: width, height: height)))
    }
}
#endif
