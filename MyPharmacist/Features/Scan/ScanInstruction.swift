//
//  ScanInstruction.swift
//  MyPharmacist
//

/// What the area above the camera view says: a moving picture of what to do and the same
/// in a few plain words, without camera terms or numbers. The picture carries the meaning
/// for anyone who doesn't read the words.
enum ScanInstruction {
    /// One instruction: its words and the picture that shows them.
    /// Short and plain, so it can be read in very large letters at a glance: a few
    /// words saying what to do.
    struct Line: Equatable {
        let text: String
        let pictogram: ScanPictogram?
        /// What VoiceOver says, when it should say more than the words on screen.
        var spoken: String? = nil
    }

    static let aim = Line(text: "Point at your pills", pictogram: .aim)
    static let noPills = Line(text: "No pills found", pictogram: .noPills)
    /// The photo couldn't be searched, so it says nothing about the pills either way.
    static let cantCheck = Line(text: "Please try again", pictogram: .again)
    /// While the photo is taken and searched for pills, and while they are checked.
    static let checking = Line(text: "Checking…", pictogram: .checking, spoken: "Checking your pills")

    /// With the photo showing each pill found circled: the question only the person
    /// can answer.
    /// The circles show how many; VoiceOver says it.
    static func confirm(count: Int) -> Line {
        Line(text: "Is every pill circled?", pictogram: nil,
             spoken: count == 1 ? "1 pill found. Is every pill circled?" : "\(count) pills found. Is every pill circled?")
    }

    /// Above a photo that has to be taken again: why.
    static func retake(_ reason: RetakeReason) -> Line {
        switch reason {
        case .noPills: noPills
        case .cantCheck: cantCheck
        case .touching: Line(text: "Spread pills apart", pictogram: .spreadApart)
        case .cutOff: Line(text: "Pills to the middle", pictogram: .toTheMiddle)
        case .tooFar: Line(text: "Move closer", pictogram: .moveCloser)
        case .hardToSee: Line(text: "Use a plain surface", pictogram: .plainSurface)
        case .tooMany: Line(text: "At most \(CheckLimits.pills) pills", pictogram: .spreadApart,
                            spoken: "Too many pills to check at once. Check at most \(CheckLimits.pills) at a time.")
        case .checkFailed(let problem): checkFailed(problem)
        }
    }

    /// Pills that were found but couldn't be checked: what happened, and whether to try
    /// again or ask instead.
    private static func checkFailed(_ problem: CheckProblem) -> Line {
        switch problem {
        case .offline:
            Line(text: "Couldn't check. Try again", pictogram: .offline,
                 spoken: "Couldn't check the pills. Check the internet connection and try again.")
        case .busy:
            Line(text: "Busy. Try again soon", pictogram: .again,
                 spoken: "The pill check is busy. Wait a moment and try again.")
        case .serverError:
            Line(text: "Couldn't check. Try again", pictogram: .again,
                 spoken: "Something went wrong checking the pills. Try again.")
        case .unavailable:
            Line(text: "Can't check pills now", pictogram: .offline,
                 spoken: "Checking pills isn't working in this copy of the app. Ask your pharmacist about these pills.")
        case .tooMuch:
            Line(text: "Fewer pills, please", pictogram: .spreadApart,
                 spoken: "Too much to check at once. Check fewer pills at a time.")
        }
    }

    /// Names the button by its word, which is under it on screen.
    static let turnOnLight = Line(text: "Tap Light below", pictogram: .moreLight)

    /// While aiming: a picture problem, otherwise the plain instruction.
    /// - Parameter canTurnOnLight: The phone has a light that is off: too dark a picture
    ///   asks for it, the quickest fix, instead of a brighter place.
    static func whileAiming(status: QualityGate.Status, canTurnOnLight: Bool = false) -> Line {
        if case .needs(let issue) = status, let fix = issue.fix {
            if issue == .tooDark, canTurnOnLight { return turnOnLight }
            return Line(text: fix, pictogram: issue.pictogram)
        }
        return aim
    }
}

extension ScanFlow {
    /// What to do now, in words and as a moving picture.
    var instruction: ScanInstruction.Line {
        switch phase {
        case .aiming:
            // Without a camera there is nothing to aim, only why.
            if let message = scanner.cameraMessage {
                ScanInstruction.Line(text: message, pictogram: nil)
            } else {
                ScanInstruction.whileAiming(status: scanner.captureStatus,
                                            canTurnOnLight: scanner.hasLight && !scanner.isLightOn)
            }
        case .finding:
            ScanInstruction.checking
        case .retake(_, let reason):
            ScanInstruction.retake(reason)
        case .confirming(let found):
            ScanInstruction.confirm(count: found.boxes.count)
        case .checking:
            ScanInstruction.checking
        case .results:
            // Not shown: the results page has its own heading.
            ScanInstruction.Line(text: "", pictogram: nil)
        }
    }
}

/// The pictures, each a symbol that moves the way the person should.
enum ScanPictogram: Hashable {
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
    /// Two pills moving away from each other.
    case spreadApart
    /// Pills moving from the viewfinder's corner to its middle.
    case toTheMiddle
    /// A phone getting larger: closer.
    case moveCloser
    /// Pills settling onto a plain sheet.
    case plainSurface
    /// An arrow going round: once more.
    case again
    /// A Wi-Fi sign with a warning: no connection to the checker.
    case offline
}

extension QualityIssue {
    /// What the person can do about it; nil when the camera sorts it out by itself.
    var fix: String? {
        switch self {
        case .tooDark: "Find more light"
        case .tooBright: "Avoid bright light"
        case .glare: "Tilt the phone"
        case .moving: "Hold still"
        case .focusing: nil
        case .blurry: "Move back a little"
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
