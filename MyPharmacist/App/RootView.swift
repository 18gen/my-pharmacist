//
//  RootView.swift
//  MyPharmacist
//

import SwiftUI

/// The whole app: today's medications above one camera button. Tapping it grows the
/// button's black circle into the scan view; the same button then closes it.
/// What a scan does is decided by `ScanFlow`; this view only lays out and animates.
struct RootView: View {
    @State private var store: MedicationStore
    @State private var scan: ScanFlow
    @State private var showingMedications = false
    @State private var lastHintAnnouncement = Date.distantPast
    /// Counts confirmations, to play the success vibration.
    @State private var confirmations = 0

    init(store: MedicationStore = MedicationStore()) {
        _store = State(initialValue: store)
        _scan = State(initialValue: ScanFlow(store: store))
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    Palette.background.ignoresSafeArea()

                    if !scan.isOpen {
                        HomeView(store: store, onShowMedications: { showingMedications = true })
                            .padding(.top, 8)
                            // Keep clear of the "Scan Pills" hint and button.
                            .padding(.bottom, ScanLayout.homeReservedHeight)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .transition(CameraButton.hintTransition)
                    }

                    if scan.isOpen {
                        ScanHeader(phase: scan.phase)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .transition(.opacity)
                    }

                    CameraLens(
                        scan: scan,
                        isOpen: scan.isOpen,
                        openSize: ScanLayout.openLensSize(in: proxy.size),
                        onConfirm: confirmTaken
                    )

                    CameraButton(isScanning: scan.isOpen) {
                        setScanning(!scan.isOpen)
                    }
                }
            }
            .onChange(of: scan.scanner.captureStatus) { _, status in
                announce(status)
                scan.captureStatusChanged(status)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: scan.scanner.captureStatus) { _, status in
                status == .ready
            }
            // The retry after a photo without pills is otherwise only shown, not spoken.
            .onChange(of: scan.foundNoPills) { _, foundNone in
                if foundNone { AccessibilityNotification.Announcement(CaptureHintPresentation.noPills.text).post() }
            }
            .onChange(of: scan.phase.step) { _, step in
                guard step == .results, case .results(let result) = scan.phase else { return }
                AccessibilityNotification.Announcement(result.summary).post()
            }
            // Success when every pill is right to take; a warning when any isn't.
            .sensoryFeedback(trigger: scan.phase.step) { _, step in
                guard step == .results, case .results(let result) = scan.phase else { return nil }
                return result.isAllClear ? .success : .warning
            }
            .sensoryFeedback(.success, trigger: confirmations)
            .task(id: scan.isOpen) {
                #if DEBUG
                // The demo shows results without the camera.
                if DemoScan.isRequested { return }
                #endif
                await scan.syncCamera()
            }
            #if DEBUG
            .onAppear {
                if DemoScan.isRequested { DemoScan.show(in: scan) }
            }
            #endif
            // Home has its own header instead of a navigation bar.
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showingMedications) {
                MedicationsPage(medications: store.medications)
            }
        }
    }

    /// Records the "Take now" pills as taken and closes the camera so the ticked rows show.
    private func confirmTaken() {
        let count = scan.confirmTaken()
        confirmations += 1
        AccessibilityNotification.Announcement(count == 1 ? "Marked 1 dose as taken" : "Marked \(count) doses as taken").post()
        setScanning(false)
    }

    /// Speaks camera hints for VoiceOver, at most every few seconds so they don't drown
    /// out everything else while the hand moves.
    private func announce(_ status: QualityGate.Status) {
        guard scan.phase.step == .aiming, let text = status.presentation?.text,
              Date().timeIntervalSince(lastHintAnnouncement) > 2.5 else { return }
        lastHintAnnouncement = Date()
        AccessibilityNotification.Announcement(text).post()
    }

    private func setScanning(_ open: Bool) {
        withAnimation(.spring(duration: 0.5, bounce: 0.15)) {
            scan.setOpen(open)
        }
    }
}

#Preview {
    RootView()
}
