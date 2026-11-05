//
//  ScanInstruction.swift
//  MyPharmacist
//

/// The words of the one line above the camera view. Each says what to do now, in a few
/// plain words, without camera terms or numbers.
enum ScanInstruction {
    static let aim = "Point the camera at your pills"
    static let noPills = "No pills found. Try again"
    /// While the photo is taken and searched for pills.
    static let checking = "Checking your pills…"

    /// Once the pills are found and the camera is off.
    static func checking(count: Int) -> String {
        count == 1 ? "Checking 1 pill…" : "Checking \(count) pills…"
    }

    /// While aiming: a picture problem first, then that the last photo had no pills in
    /// it, otherwise the plain instruction.
    static func whileAiming(status: QualityGate.Status, foundNoPills: Bool) -> String {
        if case .needs(let issue) = status, let fix = issue.fix { return fix }
        return foundNoPills ? noPills : aim
    }
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
}
