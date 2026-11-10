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
    /// The pills were found but couldn't be checked: no connection, or the checker
    /// didn't answer.
    case checkFailed
}
