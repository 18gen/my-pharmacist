//
//  RetakeReason.swift
//  MyPharmacist
//

/// Why a photo can't be checked and has to be taken again.
nonisolated enum RetakeReason: Hashable, Sendable {
    /// The photo was searched and has no pills in it.
    case noPills
    /// The photo couldn't be searched at all, so whether it has pills isn't known.
    case cantCheck
}
