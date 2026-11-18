//
//  RetakeReason.swift
//  MyPharmacist
//

/// Why a photo can't be checked and has to be taken again. Each comes with one thing
/// the person can do about it.
nonisolated enum RetakeReason: Hashable, Sendable {
    /// The photo was searched and has no pills in it.
    case noPills
    /// The photo couldn't be searched at all, so whether it has pills isn't known.
    case cantCheck
    /// Pills touch or lie over each other and can't be told apart for sure.
    case touching
    /// A pill is cut off by the edge of the photo.
    case cutOff
    /// The pills are too small in the photo for their markings to be read.
    case tooFar
    /// Something that may be a pill barely differs from what it lies on.
    case hardToSee
    /// More pills than one check can take (`CheckLimits.pills`).
    case tooMany
    /// The pills were found but couldn't be checked, for this reason.
    case checkFailed(CheckProblem)
}

/// Why pills that were found couldn't be checked.
nonisolated enum CheckProblem: Hashable, Sendable {
    /// No connection, or no answer in time.
    case offline
    /// The checker is busy with too many checks just now.
    case busy
    /// The checker went wrong, or its answer couldn't be read.
    case serverError
    /// This copy of the app can't use the checker at all: trying again won't help.
    case unavailable
    /// More than the checker takes at once.
    case tooMuch

    /// Whether checking the same photo again can work.
    var canTryAgain: Bool {
        switch self {
        case .offline, .busy, .serverError: true
        case .unavailable, .tooMuch: false
        }
    }
}
