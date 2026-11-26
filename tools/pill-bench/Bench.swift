//
//  Bench.swift
//  pill-bench
//
//  The app's own pill finding, run on a folder of photos on a Mac. `build.sh` compiles
//  these files together with the app's (not copies of them), so what this measures is
//  what the app does.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

@main
struct Bench {
    static let usage = """
        pill-bench run <photos> [--out <folder>]
            Looks for the pills in every photo in <photos> (.jpg, .heic, .png) the way the
            app does, and writes results.csv, report.html and a picture per photo of every
            area and what became of it into <folder> (<photos>/bench by default).
            How many pills each photo really has comes from <photo>.json ("pills") or from
            truth.csv in <photos> (file,pills,surface,note).
        pill-bench synth <folder> [--seed <n>] [--pills <asset folder>]
            Makes made-up photos of the demo pills on a palm, a white desk, a dark mat and
            wood, each with a <photo>.json saying where its pills are.
        """

    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        switch arguments.first {
        case "run" where arguments.count >= 2:
            let photos = URL(filePath: arguments[1], directoryHint: .isDirectory)
            let out = value(after: "--out", in: arguments).map { URL(filePath: $0, directoryHint: .isDirectory) }
                ?? photos.appending(path: "bench", directoryHint: .isDirectory)
            exit(run(photos: photos, out: out) ? 0 : 1)
        case "synth" where arguments.count >= 2:
            let out = URL(filePath: arguments[1], directoryHint: .isDirectory)
            let pills = URL(filePath: value(after: "--pills", in: arguments) ?? "MyPharmacist/Resources/Assets.xcassets/Pills",
                            directoryHint: .isDirectory)
            let seed = value(after: "--seed", in: arguments).flatMap { UInt64($0) } ?? 1
            exit(Synthetic.make(into: out, pills: pills, seed: seed) ? 0 : 1)
        default:
            print(usage)
            exit(2)
        }
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    static func run(photos: URL, out: URL) -> Bool {
        let files = (try? FileManager.default.contentsOfDirectory(at: photos, includingPropertiesForKeys: nil)) ?? []
        let images = files
            .filter { ["jpg", "jpeg", "png", "heic"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        guard !images.isEmpty else {
            print("No photos in \(photos.path)")
            return false
        }
        let overlays = out.appending(path: "overlays", directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(at: overlays, withIntermediateDirectories: true)
        } catch {
            print("Can't make \(overlays.path): \(error.localizedDescription)")
            return false
        }
        let truth = Label.truthTable(at: photos.appending(path: "truth.csv"))

        var rows: [Row] = []
        for file in images {
            let name = file.lastPathComponent
            var label = Label.sidecar(of: file)
            if let line = truth[name] { label.merge(line) }
            guard let image = Picture.upright(file),
                  let photo = CapturedPhoto(image: image, widthMillimeters: label.widthMillimeters ?? CapturedPhoto.assumedWidthMillimeters),
                  let diagnosis = Diagnosis(photo) else {
                print("\(name): can't be read")
                continue
            }
            let row = Row(file: name, label: label, diagnosis: diagnosis)
            if let picture = Overlay.draw(diagnosis, row: row, label: label) {
                _ = Picture.writePNG(picture, to: overlays.appending(path: row.overlayName))
            }
            print(row.summaryLine)
            rows.append(row)
        }
        Report.write(rows, to: out)
        print("")
        print(Report.summary(rows))
        print("Written to \(out.path)")
        return true
    }
}

// MARK: - What the app found, step by step

/// One photo searched as the app searches it (`PillFinder.find`), then the same steps
/// again one by one, to see every area and the numbers the rules went by.
struct Diagnosis {
    let search: PillSearch
    /// How long `PillFinder.find` took on this Mac.
    let milliseconds: Double
    let picture: ColourImage
    let rules: PillRules
    let lift: PillFinder.Lift
    let usedTiles: Bool
    let colour: SurfaceOutliers.Result
    let location: PillLocation
    let areas: [ExaminedArea]
    /// The full-size photo's width, as the rules count it.
    let capturedWidth: Int

    init?(_ photo: CapturedPhoto) {
        let clock = ContinuousClock()
        let started = clock.now
        search = PillFinder.find(in: photo)
        let took = clock.now - started
        milliseconds = Double(took.components.seconds) * 1000 + Double(took.components.attoseconds) / 1e15

        // As in `PillFinder.find`.
        let working = photo.working
        let size = PhotoSize.fitting(working, maxSide: PillFinder.searchedSide)
        guard let picture = ColourImage(working, width: size.width, height: size.height), let searched = picture.cgImage() else {
            return nil
        }
        let rules = PillRules(pictureWidth: size.width, widthMillimeters: photo.widthMillimeters, capturedWidth: Int(photo.size.width))
        var lift = PillFinder.lift(from: searched)
        var usedTiles = false
        if lift.ran, lift.objects.isEmpty {
            lift.objects = PillFinder.liftInTiles(from: searched)
            usedTiles = true
        }
        var settings = SurfaceOutliers.Settings()
        settings.blockSize = max(32, Int(PillFinder.surfaceSquareMillimeters * rules.pixelsPerMillimeter))
        let colour = SurfaceOutliers.find(in: picture, within: lift.surface, settings: settings)
        let examined = PillLocator.examine(lifted: lift.objects, colour: colour, rules: rules,
                                           pictureWidth: size.width, pictureHeight: size.height)
        self.picture = picture
        self.rules = rules
        self.lift = lift
        self.usedTiles = usedTiles
        self.colour = colour
        location = examined.location
        areas = examined.areas
        capturedWidth = Int(photo.size.width)
    }

    /// Whether the steps taken one by one came to what `PillFinder.find` did (Vision can
    /// differ between runs now and then).
    var agrees: Bool {
        switch (search, location) {
        case (.found(let pills), .found(let located)): pills.count == located.count
        case (.noPills, .noPills), (.failed, _): true
        case (.unclear(let a), .unclear(let b)): a == b
        case (.unclear(.hardToSee), _): usedTiles && !colour.isReliable
        default: false
        }
    }

    var foundBoxes: [CGRect] {
        if case .found(let pills) = search { pills.map(\.box) } else { [] }
    }

    /// One area as the app's log says it.
    func describe(_ area: ExaminedArea) -> String {
        let perMillimeter = rules.pixelsPerMillimeter
        let dent = area.shape.deepestDent / max(1, area.shape.equivalentRadius)
        let way = area.sources == [.lifted, .colour] ? "both" : area.sources.contains(.lifted) ? "vision" : "colour"
        let outcome: String = switch area.outcome {
        case .pills(let count): count == 1 ? "kept" : "kept as \(count)"
        case .ignored: "IGNORED"
        case .retake(let reason): "retake (\(reason))"
        }
        return String(format: "by %@, %.1f x %.1f mm, %.0f px in the photo, fills %.2f, dent %.2f: %@, %@",
                      way, area.shape.length / perMillimeter, area.shape.width / perMillimeter,
                      area.shape.length * rules.capturedPixelsPerPixel, area.shape.solidity, dent,
                      String(describing: area.verdict), outcome)
    }

    var visionLine: String {
        let shares = lift.shares.prefix(6).map { String(format: "%.1f%%", $0 * 100) }.joined(separator: " ")
        return "vision \(lift.ran ? "ran" : "FAILED"): objects [\(shares)], surface \(lift.surface != nil ? "yes" : "no"), "
            + "\(usedTiles ? "searched again in pieces, " : "")pill-sized objects \(lift.objects.count)"
    }

    var colourLine: String {
        String(format: "colour: %d clear, %d faint, %@, %.1f%% of the surface stands out in %d areas",
               colour.blobs.count, colour.faint.count, colour.isReliable ? "trusted" : "NOT TRUSTED (patterned)",
               colour.shareStandingOut * 100, colour.areas)
    }
}

// MARK: - What is really in a photo

/// How many pills a photo really has and where, when known, and the photo's scale.
struct Label {
    var widthMillimeters: Double?
    var pills: Int?
    var surface: String?
    /// Normalized x, y, width, height of each pill (made-up photos know them).
    var boxes: [CGRect] = []
    /// A retake for this reason is the right answer (pills made to touch, or cut off).
    var expectRetake: String?
    var note: String?
    /// What the app on the phone found in it, for photos the app kept (`ScanPhotoKeeper`).
    var app: String?

    private struct Sidecar: Decodable {
        var widthMillimeters: Double?
        var pills: Int?
        var surface: String?
        var boxes: [[Double]]?
        var expectRetake: String?
        var note: String?
        var app: String?
    }

    /// From `<photo>.json` beside the photo, if there is one.
    static func sidecar(of photo: URL) -> Label {
        let url = photo.deletingPathExtension().appendingPathExtension("json")
        guard let data = try? Data(contentsOf: url), let sidecar = try? JSONDecoder().decode(Sidecar.self, from: data) else {
            return Label()
        }
        let boxes = (sidecar.boxes ?? []).compactMap { $0.count == 4 ? CGRect(x: $0[0], y: $0[1], width: $0[2], height: $0[3]) : nil }
        return Label(widthMillimeters: sidecar.widthMillimeters, pills: sidecar.pills ?? (boxes.isEmpty ? nil : boxes.count),
                     surface: sidecar.surface, boxes: boxes, expectRetake: sidecar.expectRetake, note: sidecar.note, app: sidecar.app)
    }

    /// truth.csv: `file,pills,surface,note`, one photo a line, the first line the heading.
    static func truthTable(at url: URL) -> [String: Label] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        var table: [String: Label] = [:]
        for line in text.split(whereSeparator: \.isNewline).dropFirst() {
            let fields = line.split(separator: ",", maxSplits: 3, omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
            guard let file = fields.first, !file.isEmpty else { continue }
            table[file] = Label(pills: fields.count > 1 ? Int(fields[1]) : nil,
                                surface: fields.count > 2 && !fields[2].isEmpty ? fields[2] : nil,
                                note: fields.count > 3 && !fields[3].isEmpty ? fields[3] : nil)
        }
        return table
    }

    mutating func merge(_ other: Label) {
        pills = other.pills ?? pills
        surface = other.surface ?? surface
        note = other.note ?? note
    }
}

// MARK: - One photo's line in the results

struct Row {
    enum Status: String, CaseIterable {
        /// Every pill circled, nothing else.
        case right = "right"
        /// Asked for a retake where that was the right answer (pills made to touch).
        case rightRetake = "right retake"
        /// Some pills circled, others not, and nothing said: the dangerous one.
        case missed = "MISSED (silent)"
        /// Circled something that isn't a pill.
        case extra = "extra"
        /// Asked for a retake though the pills were fine to find.
        case retake = "retake"
        case noPills = "no pills"
        case failed = "failed"
        /// How many pills the photo has isn't known.
        case unlabelled = "no truth"
    }

    let file: String
    let surface: String
    let truth: Int?
    let found: Int
    /// The real pills circled, when where they are is known; else the count found.
    let circled: Int?
    let outcome: String
    let status: Status
    let milliseconds: Double
    let agrees: Bool
    let details: [String]

    var overlayName: String { (file as NSString).deletingPathExtension + ".png" }

    init(file: String, label: Label, diagnosis: Diagnosis) {
        self.file = file
        surface = label.surface ?? "?"
        truth = label.pills
        milliseconds = diagnosis.milliseconds
        agrees = diagnosis.agrees
        let boxes = diagnosis.foundBoxes
        let count = boxes.count
        found = count
        let matched = label.boxes.isEmpty ? nil : label.boxes.filter { real in boxes.contains { $0.contains(CGPoint(x: real.midX, y: real.midY)) } }.count
        switch diagnosis.search {
        case .found:
            outcome = "found \(count)"
            circled = matched ?? label.pills.map { min($0, count) }
            if let truth = label.pills {
                let real = matched ?? min(count, truth)
                status = real < truth ? .missed : count > truth ? .extra : .right
            } else {
                status = .unlabelled
            }
        case .noPills:
            outcome = "no pills"
            circled = 0
            status = truth == nil ? .unlabelled : truth == 0 ? .right : .noPills
        case .unclear(let reason):
            outcome = "retake: \(reason)"
            circled = 0
            status = truth == nil ? .unlabelled : label.expectRetake == "\(reason)" ? .rightRetake : .retake
        case .failed:
            outcome = "failed"
            circled = 0
            status = .failed
        }

        var details = [diagnosis.visionLine, diagnosis.colourLine]
        let sized = diagnosis.areas.enumerated().filter { $0.element.verdict != .notAPill }
        details += sized.map { "A\($0.offset + 1) " + diagnosis.describe($0.element) }
        let specks = diagnosis.areas.count - sized.count
        if specks > 0 { details.append("\(specks) more areas not pill-sized") }
        if !agrees { details.append("NOTE: the step-by-step run came to something else than the app's run (Vision varied)") }
        if let app = label.app {
            details.append(app == outcome ? "the phone found the same" : "NOTE: the phone found something else: \(app)")
        }
        if let note = label.note { details.append("note: \(note)") }
        self.details = details
    }

    var summaryLine: String {
        func padded(_ text: String, _ width: Int) -> String {
            text.count >= width ? text + " " : text.padding(toLength: width, withPad: " ", startingAt: 0)
        }
        let truthText = truth.map { "of \($0)" } ?? ""
        return padded(file, 30) + padded(surface, 7) + padded(outcome, 20) + padded(truthText, 7)
            + padded(status.rawValue, 17) + String(format: "%5.0f ms", milliseconds)
    }
}

// MARK: - Reading and writing pictures

enum Picture {
    /// The photo upright, at full size, whichever way the camera stored it.
    static func upright(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return nil }
        let width = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties[kCGImagePropertyPixelHeight] as? Int ?? 0
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(width, height),
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    static func writePNG(_ image: CGImage, to url: URL) -> Bool {
        write(image, to: url, type: .png, options: [:])
    }

    static func writeJPEG(_ image: CGImage, to url: URL, quality: Double = 0.92) -> Bool {
        write(image, to: url, type: .jpeg, options: [kCGImageDestinationLossyCompressionQuality: quality])
    }

    private static func write(_ image: CGImage, to url: URL, type: UTType, options: [CFString: Any]) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else { return false }
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        return CGImageDestinationFinalize(destination)
    }
}
