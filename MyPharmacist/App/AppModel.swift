//
//  AppModel.swift
//  MyPharmacist
//

import Foundation
import Observation

/// What the app keeps while it runs: the person's medications and the record of their
/// doses, their pharmacy, and the scan. Made once, when the app starts, and handed to
/// the screens.
@Observable
final class AppModel {
    let store: MedicationStore
    let pharmacy: PharmacyStore
    let scan: ScanFlow
    /// A keychain card's link that opened the app, kept until Home can show it: during
    /// the introduction, or while another sheet is open.
    var pendingCardLink: String?

    init(store: MedicationStore, pharmacy: PharmacyStore, scan: ScanFlow? = nil) {
        self.store = store
        self.pharmacy = pharmacy
        self.scan = scan ?? ScanFlow(store: store)
    }

    /// The app as saved on the device: a new install starts with the sample medications
    /// and pharmacy, as "Reset demo" leaves them. Debug demos keep everything in memory,
    /// leaving what is saved alone.
    static func launch() -> AppModel {
        #if DEBUG
        if let demo = DemoScan.model() { return demo }
        #endif
        let store = MedicationStore(entries: SampleMedications.sampleList, listStorage: UserDefaultsMedicationListStorage(),
                                    logStorage: UserDefaultsDoseLogStorage())
        // Photos of a medication whose adding was never finished (the app was closed).
        store.removeUnusedPhotos()
        return AppModel(store: store, pharmacy: PharmacyStore(pharmacy: .sample(), defaults: .standard))
    }
}
