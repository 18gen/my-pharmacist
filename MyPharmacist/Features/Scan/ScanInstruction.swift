//
//  ScanInstruction.swift
//  MyPharmacist
//

/// What the area above the camera view says: a moving picture of what to do and the same
/// in a few plain words, without camera terms or numbers. The picture carries the meaning
/// for anyone who doesn't read the words.
enum ScanInstruction {
    /// One instruction: its words and the picture that shows them.
    struct Line: Equatable {
        let text: String
        let pictogram: ScanPictogram?
    }

    static let aim = Line(text: "Point the camera at your pills", pictogram: .aim)
    static let noPills = Line(text: "No pills found", pictogram: .noPills)
    /// The photo couldn't be searched, so it says nothing about the pills either way.
    static let cantCheck = Line(text: "Couldn't check this photo", pictogram: .noPills)
    /// While the photo is taken and searched for pills.
    static let checking = Line(text: "Checking your pills…", pictogram: .checking)

    /// Once the pills are found and the camera is off.
    static func checking(count: Int) -> Line {
        Line(text: count == 1 ? "Checking 1 pill…" : "Checking \(count) pills…", pictogram: .checking)
    }

    /// Above a photo that has to be taken again: why.
    static func retake(_ reason: RetakeReason) -> Line {
        switch reason {
        case .noPills: noPills
        case .cantCheck: cantCheck
        case .touching: Line(text: "Spread the pills apart", pictogram: .noPills)
        case .cutOff: Line(text: "Move the pills to the middle", pictogram: .aim)
        case .tooFar: Line(text: "Move the phone closer", pictogram: .aim)
        case .hardToSee: Line(text: "Put the pills on a plain surface", pictogram: .noPills)
        }
    }

    /// While aiming: a picture problem, otherwise the plain instruction.
    static func whileAiming(status: QualityGate.Status) -> Line {
        if case .needs(let issue) = status, let fix = issue.fix {
            return Line(text: fix, pictogram: issue.pictogram)
        }
        return aim
    }
}

/// The pictures, each a symbol that moves the way the person should.
enum ScanPictogram: Equatable {
    /// Pills inside a viewfinder that gently closes in on them.
    case aim
    /// The same viewfinder, with the pills fading in and out: none were seen.
    case noPills
    /// A raised hand: stop moving.
    case holdStill
    /// A light bulb glowing: more light.
    case moreLight
    /// A slowly turning sun: out of the bright light.
    case lessLight
    /// A phone tilting forward and back.
    case tilt
    /// A phone getting smaller: further away.
    case moveBack
    /// A magnifying glass looking around.
    case checking
}

extension QualityIssue {
    /// What the person can do about it; nil when the camera sorts it out by itself.
    var fix: String? {
        switch self {
        case .tooDark: "Move to a brighter place"
        case .tooBright: "Move out of bright light"
        case .glare: "Tilt the phone a little"
        case .moving: "Hold still"
        case .focusing: nil
        case .blurry: "Move the phone back a little"
        }
    }

    var pictogram: ScanPictogram? {
        switch self {
        case .tooDark: .moreLight
        case .tooBright: .lessLight
        case .glare: .tilt
        case .moving: .holdStill
        case .focusing: nil
        case .blurry: .moveBack
        }
    }
}
