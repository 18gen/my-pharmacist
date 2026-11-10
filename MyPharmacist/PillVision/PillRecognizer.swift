//
//  PillRecognizer.swift
//  MyPharmacist
//

import CoreGraphics

/// What a recognizer says about one pill's picture.
nonisolated enum PillAnswer: Equatable, Sendable {
    /// It is this medication, by its ID.
    case medication(String)
    /// A pill, but not one of the medications, or the recognizer wasn't sure.
    case unknown
    /// The picture shows no pill at all: skin, a shadow, something else.
    case notAPill

    var medicationID: String? {
        if case .medication(let id) = self { id } else { nil }
    }
}

/// What a recognizer says about the pills of one photo.
nonisolated struct PillReading: Equatable, Sendable {
    /// One answer per pill picture, in order.
    let answers: [PillAnswer]
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
