//
//  ScanLog.swift
//  MyPharmacist
//

import os

/// Where a scan writes what it measured (photo size, zoom, what was found and why), for
/// tuning on a real phone. Numbers only: nothing about the person or their medications.
nonisolated enum ScanLog {
    static let logger = Logger(subsystem: "MyPharmacist", category: "scan")
}
