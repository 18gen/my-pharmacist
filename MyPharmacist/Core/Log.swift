//
//  Log.swift
//  MyPharmacist
//

import os

/// Where the app writes what it measured and what went wrong, for tuning and fixing on a
/// real phone. Numbers and kinds of failure only: nothing about the person, their
/// medications or their pictures.
nonisolated enum Log {
    /// What a scan measured: photo size, zoom, what was found and why.
    static let scan = Logger(subsystem: "MyPharmacist", category: "scan")
    /// Saved data that couldn't be read.
    static let storage = Logger(subsystem: "MyPharmacist", category: "storage")
}
