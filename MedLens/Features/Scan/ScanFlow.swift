//
//  ScanFlow.swift
//  MedLens
//

import Foundation
import Observation

/// One scanning session, from opening the camera to closing it: turns each medication
/// name the scanner confirms into at most one checked dose, and remembers the outcome
/// so the camera view can show it and offer Undo.
@Observable
final class ScanFlow {
    /// How long a "Checked" banner stays before the camera closes by itself, so the
    /// person sees the ticked row on the home screen.
    static let autoCloseDelay: Duration = .seconds(1.6)

    private(set) var isOpen = false
    /// What the latest scan did, shown in the camera view.
    private(set) var outcome: ScanOutcome?
    let scanner: ScannerModel

    @ObservationIgnored private let store: MedicationStore
    /// Medications already handled while the camera is open, so slightly different reads
    /// of the same bottle ("500 MG" / "500MG") don't count it twice.
    @ObservationIgnored private var handledMedicationIDs: Set<String> = []

    init(store: MedicationStore, scanner: ScannerModel = ScannerModel()) {
        self.store = store
        self.scanner = scanner
    }

    /// Opening or closing always starts the next session fresh.
    func setOpen(_ open: Bool) {
        outcome = nil
        handledMedicationIDs = []
        isOpen = open
    }

    /// Handles a name the scanner confirmed. Returns the new outcome, or nil when the scan
    /// was ignored (camera closed, or this medication was already handled this session).
    @discardableResult
    func handleConfirmedName(_ name: String, now: Date = Date()) -> ScanOutcome? {
        guard isOpen else { return nil }
        let match = store.match(scannedName: name)
        if case .match(let medication) = match {
            guard !handledMedicationIDs.contains(medication.id) else { return nil }
            handledMedicationIDs.insert(medication.id)
        }
        let outcome = store.recordScan(match, scannedName: name, now: now)
        self.outcome = outcome
        return outcome
    }

    /// Unchecks the dose the latest scan checked. Clearing the outcome also cancels the
    /// automatic close.
    func undo() {
        if case .checked(let dose) = outcome {
            store.markNotTaken(dose)
        }
        outcome = nil
    }

    /// Whether the camera should close by itself after `autoCloseDelay`.
    var shouldAutoClose: Bool {
        guard isOpen, case .checked = outcome else { return false }
        return true
    }

    /// Starts or stops the camera to match `isOpen`. Each opening starts from "Scanning...".
    func syncCamera() async {
        if isOpen {
            scanner.reset()
            await scanner.start()
        } else {
            scanner.stop()
        }
    }
}
