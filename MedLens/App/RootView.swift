//
//  RootView.swift
//  MedLens
//

import SwiftUI

/// The whole app: today's medications above one camera button. Tapping it grows the
/// button's black circle into the live camera view; the same button then closes it.
struct RootView: View {
    @State private var isScanning = false
    @State private var model = ScannerModel()
    @State private var store = MedicationStore()
    @State private var showingMedications = false
    /// What the latest scan did, shown in the camera view.
    @State private var scanOutcome: ScanOutcome?
    /// Medications already handled while the camera is open, so slightly different reads
    /// of the same bottle ("500 MG" / "500MG") don't count it twice.
    @State private var handledMedicationIDs: Set<String> = []

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    Palette.background.ignoresSafeArea()

                    if !isScanning {
                        HomeView(store: store, onShowMedications: { showingMedications = true })
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            // Keep clear of the "Scan Pills" hint and button.
                            .padding(.bottom, ScanLayout.homeReservedHeight)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .transition(CameraButton.hintTransition)
                    }

                    if isScanning {
                        ScanResultView(model: model)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .transition(.opacity)
                    }

                    CameraLens(
                        model: model,
                        isOpen: isScanning,
                        openSize: ScanLayout.openLensSize(in: proxy.size),
                        outcome: scanOutcome,
                        onUndo: undoLastCheck
                    )

                    CameraButton(isScanning: isScanning) {
                        setScanning(!isScanning)
                    }
                }
            }
            .onChange(of: model.medicationName) { _, name in
                guard isScanning, let name else { return }
                handleScan(of: name)
            }
            // After a successful check, close the camera so the ticked row is visible.
            .task(id: scanOutcome) {
                guard isScanning, case .checked = scanOutcome else { return }
                do { try await Task.sleep(for: .seconds(1.6)) } catch { return }
                setScanning(false)
            }
            .sensoryFeedback(trigger: scanOutcome) { scanOutcome?.feedback }
            .task(id: isScanning) {
                if isScanning {
                    model.reset()
                    await model.start()
                } else {
                    model.stop()
                }
            }
            // Home has its own header instead of a navigation bar.
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showingMedications) {
                MedicationsPage(medications: store.medications)
            }
        }
    }

    private func setScanning(_ open: Bool) {
        scanOutcome = nil
        handledMedicationIDs = []
        withAnimation(.spring(duration: 0.5, bounce: 0.15)) {
            isScanning = open
        }
    }

    private func handleScan(of name: String) {
        if case .match(let medication) = MedicationMatcher.match(scannedName: name, in: store.medications) {
            guard !handledMedicationIDs.contains(medication.id) else { return }
            handledMedicationIDs.insert(medication.id)
        }
        let outcome = store.recordScan(scannedName: name)
        scanOutcome = outcome
        AccessibilityNotification.Announcement(outcome.announcement).post()
    }

    private func undoLastCheck() {
        if case .checked(let dose) = scanOutcome {
            store.markNotTaken(dose)
        }
        // Cancels the automatic close too.
        scanOutcome = nil
    }
}

#Preview {
    RootView()
}
