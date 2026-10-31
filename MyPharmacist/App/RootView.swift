//
//  RootView.swift
//  MyPharmacist
//

import SwiftUI

/// The whole app: today's medications above one camera button. Tapping it grows the
/// button's black circle into the live camera view; the same button then closes it.
/// What a scan does is decided by `ScanFlow`; this view only lays out and animates.
struct RootView: View {
    @State private var store: MedicationStore
    @State private var scan: ScanFlow
    @State private var showingMedications = false
    @State private var lastHintAnnouncement = Date.distantPast

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
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            // Keep clear of the "Scan Pills" hint and button.
                            .padding(.bottom, ScanLayout.homeReservedHeight)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .transition(CameraButton.hintTransition)
                    }

                    if scan.isOpen {
                        ScanResultView(model: scan.scanner)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .transition(.opacity)
                    }

                    CameraLens(
                        model: scan.scanner,
                        isOpen: scan.isOpen,
                        openSize: ScanLayout.openLensSize(in: proxy.size),
                        outcome: scan.outcome,
                        onUndo: scan.undo
                    )

                    CameraButton(isScanning: scan.isOpen) {
                        setScanning(!scan.isOpen)
                    }
                }
            }
            .onChange(of: scan.scanner.medicationName) { _, name in
                guard let name, let outcome = scan.handleConfirmedName(name) else { return }
                AccessibilityNotification.Announcement(outcome.announcement).post()
            }
            .onChange(of: scan.scanner.captureStatus) { _, status in
                announce(status)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: scan.scanner.captureStatus) { _, status in
                status == .ready
            }
            // After a successful check, close the camera so the ticked row is visible.
            .task(id: scan.outcome) {
                guard scan.shouldAutoClose else { return }
                do { try await Task.sleep(for: ScanFlow.autoCloseDelay) } catch { return }
                setScanning(false)
            }
            .sensoryFeedback(trigger: scan.outcome) { scan.outcome?.feedback }
            .task(id: scan.isOpen) {
                await scan.syncCamera()
            }
            // Home has its own header instead of a navigation bar.
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showingMedications) {
                MedicationsPage(medications: store.medications)
            }
        }
    }

    /// Speaks camera hints for VoiceOver, at most every few seconds so they don't drown
    /// out everything else while the hand moves.
    private func announce(_ status: QualityGate.Status) {
        guard let text = status.presentation?.text,
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
