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
    /// The pages pushed over the home screen, in order.
    @State private var path: [AppRoute] = []
    @State private var lastHintAnnouncement = Date.distantPast

    init(store: MedicationStore = MedicationStore(startingIDs: SampleMedications.startingIDs,
                                                  listStorage: UserDefaultsMedicationListStorage())) {
        _store = State(initialValue: store)
        _scan = State(initialValue: ScanFlow(store: store))
    }

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { proxy in
                // Each minute, whether a dose is due now: the scan button turns blue.
                TimelineView(.everyMinute) { context in
                    // Not tied to the camera being open: changing together with it, the
                    // colour's animation would replace the camera's opening spring.
                    let isDue = store.hasDoseDueNow(now: context.date)
                    ZStack(alignment: .bottom) {
                        Palette.background.ignoresSafeArea()

                        if !scan.isOpen {
                            HomeView(store: store, onShowMedications: showMedications)
                                .padding(.top, 8)
                                // Keep clear of the "Scan Pills" hint and button.
                                .padding(.bottom, ScanLayout.homeReservedHeight)
                                .frame(maxHeight: .infinity, alignment: .top)
                                .transition(CameraButton.hintTransition)
                        }

                        if scan.isOpen {
                            ScanHeader(scan: scan)
                                .frame(height: ScanLayout.headerHeight(in: proxy.size))
                                .frame(maxHeight: .infinity, alignment: .top)
                                .transition(.opacity)
                        }

                        CameraLens(
                            scan: scan,
                            isOpen: scan.isOpen,
                            openSize: ScanLayout.openLensSize(in: proxy.size),
                            onDone: { setScanning(false) },
                            closedColor: isDue ? Palette.due : .black
                        )
                        .animation(.easeInOut(duration: 0.3), value: isDue)

                        CameraButton(isScanning: scan.isOpen,
                                     isOnPage: scan.isOpen && scan.phase.step.isPage,
                                     isHidden: scan.isOpen && scan.phase.step == .results,
                                     isDue: isDue) {
                            setScanning(!scan.isOpen)
                        }
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
                if foundNone { AccessibilityNotification.Announcement(ScanInstruction.noPills.text).post() }
            }
            .onChange(of: scan.phase.step) { _, step in
                guard step == .results, case .results(let result) = scan.phase else { return }
                AccessibilityNotification.Announcement(result.summary).post()
            }
            // Success when every pill is OK to take and nothing is missing; a warning otherwise.
            .sensoryFeedback(trigger: scan.phase.step) { _, step in
                guard step == .results, case .results(let result) = scan.phase else { return nil }
                return result.isAllClear ? .success : .warning
            }
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
            // Every page pushed over the home screen is declared here, once, and opened by
            // adding to `path`. A page shown by a flag (`navigationDestination(isPresented:)`)
            // can't share a stack with pages pushed by value: pushing a medication's page from
            // My Medications then showed My Medications again, or an empty page.
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .medications:
                    MedicationsPage(store: store)
                case .medication(let id):
                    if let entry = store.catalogEntry(id) {
                        MedicationEditor(store: store, entry: entry, mode: .edit,
                                         onRemoved: { path.removeAll { $0 == route } })
                    }
                }
            }
        }
    }

    /// Speaks what to fix about the camera picture for VoiceOver, at most every few
    /// seconds so it doesn't drown out everything else while the hand moves.
    private func announce(_ status: QualityGate.Status) {
        guard scan.phase.step == .aiming, case .needs(let issue) = status, let text = issue.fix,
              Date().timeIntervalSince(lastHintAnnouncement) > 2.5 else { return }
        lastHintAnnouncement = Date()
        AccessibilityNotification.Announcement(text).post()
    }

    /// Opens My Medications; ignored if a page is already open, so a quick second tap
    /// doesn't push it twice.
    private func showMedications() {
        guard path.isEmpty else { return }
        path.append(.medications)
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
