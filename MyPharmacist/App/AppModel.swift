//
//  AppModel.swift
//  MyPharmacist
//

import Foundation
import Observation

/// What the app keeps while it runs: the person's medications and the record of their
/// doses, what their scans said, their pharmacy, sharing with the pharmacy demo, and the
/// scan. Made once, when the app starts, and handed to the screens.
@Observable
final class AppModel {
    let store: MedicationStore
    let pharmacy: PharmacyStore
    let reports: ScanReports
    let share: PharmacyShare
    let scan: ScanFlow
    /// A keychain card's link that opened the app, kept until Home can show it: during
    /// the introduction, or while another sheet is open.
    var pendingCardLink: String?

    init(store: MedicationStore, pharmacy: PharmacyStore, reports: ScanReports = ScanReports(),
         share: PharmacyShare = PharmacyShare(demo: nil), scan: ScanFlow? = nil) {
        self.store = store
        self.pharmacy = pharmacy
        self.reports = reports
        self.share = share
        self.scan = scan ?? ScanFlow(store: store, reports: reports)
        connectSharing()
    }

    /// Sharing sends what the medications, the record of doses and the scans' reports
    /// hold, shortly after any of them changes. Weak references, as the store and the
    /// reports live as long as this model, which owns the sharing.
    private func connectSharing() {
        share.makeSnapshot = { [weak self] now in
            guard let self else { return nil }
            return ShareSnapshot.make(store: store, reports: reports, now: now)
        }
        store.onChange = { [weak share] in share?.changed() }
        reports.onChange = { [weak share] in share?.changed() }
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
        let demo = PharmacyShareClient.Configuration.current().map { PharmacyShareClient(configuration: $0) }
        let model = AppModel(store: store, pharmacy: PharmacyStore(pharmacy: .sample(), defaults: .standard),
                             reports: ScanReports(defaults: .standard),
                             share: PharmacyShare(demo: demo, defaults: .standard))
        #if DEBUG
        DebugSharing.apply(to: model)
        #endif
        // What changed while the app was closed, and whether the demo was reset meanwhile.
        model.share.appBecameActive()
        return model
    }
}
