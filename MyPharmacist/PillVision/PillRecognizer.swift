//
//  PillRecognizer.swift
//  MyPharmacist
//

import CoreGraphics

/// What a recognizer says about the pills of one photo.
nonisolated struct PillReading: Equatable, Sendable {
    /// One medication ID, or nil, per pill picture, in order. Nil when the pill isn't
    /// one of the medications, or the recognizer wasn't sure.
    let medicationIDs: [String?]
    /// The recognizer saw something pill-like that the app didn't number, or a pill's
    /// picture that doesn't show one whole pill (two lying together, say, where one
    /// would go unchecked). This can only make the result more careful, never less.
    let mayHaveMissedPill: Bool
}

/// Why the pills couldn't be recognized. Every one of them means "try again"; none is
/// ever shown as a result.
nonisolated enum PillRecognitionFailure: Error, Equatable {
    /// The app has no server address (Secrets.plist).
    case notConfigured
    /// No connection, or the server didn't answer in time.
    case offline
    /// The server answered with an error.
    case server(status: Int)
    /// The answer couldn't be read, or the pictures couldn't be made.
    case unusable
}

/// Says which of the person's medications each pill is. The pill check server
/// (`PillCheckClient`) is one; a model that runs on the device can be another, alone or
/// in front of it.
///
/// Whether to take a pill is never the recognizer's call: it only says which medication
/// a pill is; the schedule decides the rest.
nonisolated protocol PillRecognizer: Sendable {
    /// - Parameters:
    ///   - pictures: One picture per pill, as `PillCropper` makes them: the pill in the
    ///     middle, lying flat, its surroundings dimmed.
    ///   - overview: All the pills together, numbered in the same order, if there is one.
    ///   - medications: The only answers there are. Their photos are the reference.
    func recognize(_ pictures: [CGImage], overview: CGImage?, among medications: [Medication]) async throws(PillRecognitionFailure) -> PillReading
}
