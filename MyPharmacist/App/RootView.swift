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
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(PillCheckConsent.key) private var allowsChecking = false
    /// Asking to allow pill checking, before the camera opens for the first time.
    @State private var isAskingConsent = false

    /// One of the accessibility text sizes: the instruction gets more room.
    private var largeText: Bool { typeSize.isAccessibilitySize }

    /// - Parameters:
    ///   - store: The person's medications and scans; the one saved on the device unless
    ///     given.
    ///   - scan: A scan already in some step, for previews; nil for a new one.
    init(store: MedicationStore = RootView.savedStore(), scan: ScanFlow? = nil) {
        _store = State(initialValue: store)
        _scan = State(initialValue: scan ?? ScanFlow(store: store))
    }

    /// The list and scans saved on the device. Debug demos use the demo medications in
    /// memory instead, leaving the saved list alone.
    static func savedStore() -> MedicationStore {
        #if DEBUG
        if DemoScan.isRequested {
            return MedicationStore(entries: SampleMedications.demoList, storage: InMemoryDoseLogStorage())
        }
        #endif
        return MedicationStore(listStorage: UserDefaultsMedicationListStorage())
    }

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { proxy in
                // Each minute, whether a dose is due now: the scan button turns blue.
                TimelineView(.everyMinute) { context in
                    // Not tied to the camera being open: changing together with it, the
                    // colour's animation would replace the camera's opening spring.
                    screen(in: proxy.size, isDue: store.hasDoseDueNow(now: context.date))
                }
                // Known before the camera is first opened: it zooms for this shape.
                .onChange(of: proxy.size, initial: true) { _, size in
                    scan.visibleAspect = ScanLayout.lensAspect(in: size, largeText: largeText)
                }
                .onChange(of: largeText) { _, largeText in
                    scan.visibleAspect = ScanLayout.lensAspect(in: proxy.size, largeText: largeText)
                }
            }
            .onChange(of: scan.scanner.captureStatus) { _, status in
                announce(status)
                scan.captureStatusChanged(status)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: scan.scanner.captureStatus) { _, status in
                status == .ready
            }
            // What each step of a scan says and feels like.
            .modifier(ScanFeedback(scan: scan))
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active: Task { await scan.appBecameActive() }
                case .background: scan.appWentToBackground()
                default: break
                }
            }
            .task(id: scan.isOpen) {
                #if DEBUG
                // The demo shows results without the camera, and previews never start it.
                if DemoScan.isRequested || ScanPreview.isRunning { return }
                #endif
                await scan.syncCamera()
            }
            #if DEBUG
            .onAppear {
                if DemoScan.isRequested { DemoScan.run(in: scan) }
                if let pages = DemoScan.pages { path = pages }
                if ProcessInfo.processInfo.arguments.contains("-demoConsent") { isAskingConsent = true }
            }
            #endif
            // Home has its own header instead of a navigation bar.
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isAskingConsent) {
                PillCheckConsentSheet(
                    onAllow: {
                        allowsChecking = true
                        isAskingConsent = false
                        setScanning(true)
                    },
                    onNotNow: { isAskingConsent = false }
                )
            }
            // Every page pushed over the home screen is declared here, once, and opened by
            // adding to `path`. A page shown by a flag (`navigationDestination(isPresented:)`)
            // can't share a stack with pages pushed by value: pushing a medication's page from
            // My Medications then showed My Medications again, or an empty page.
            .navigationDestination(for: AppRoute.self, destination: page)
        }
    }

    /// The home screen with the scan button, which grows into the scan over it.
    /// - Parameter isDue: A dose is due now: the scan button is blue.
    private func screen(in size: CGSize, isDue: Bool) -> some View {
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

            // The results page (and, while checking, the page standing ready) says
            // what to do at its own top instead.
            if scan.isOpen && !scan.phase.step.isResultsPage {
                ScanHeader(scan: scan)
                    .frame(height: ScanLayout.headerHeight(in: size, largeText: largeText))
                    .frame(maxHeight: .infinity, alignment: .top)
                    .transition(.opacity)
            }

            CameraLens(
                scan: scan,
                isOpen: scan.isOpen,
                openSize: scan.phase.step.isResultsPage ? ScanLayout.resultsPageSize(in: size)
                                                      : ScanLayout.openLensSize(in: size, largeText: largeText),
                onDone: { setScanning(false) },
                closedColor: isDue ? Palette.due : .black
            )
            .animation(.easeInOut(duration: 0.3), value: isDue)

            CameraButton(isScanning: scan.isOpen,
                         isOnPage: scan.isOpen,
                         // The results page and a photo to retake have buttons of their own.
                         isHidden: scan.isOpen && (scan.phase.step == .results || scan.phase.step == .retake),
                         isDue: isDue) {
                setScanning(!scan.isOpen)
            }
        }
    }

    /// A page pushed over the home screen.
    @ViewBuilder
    private func page(for route: AppRoute) -> some View {
        switch route {
        case .medications:
            MedicationsPage(store: store)
        case .medication(let id):
            if let entry = store.entry(id) {
                MedicationEditor(store: store, entry: entry, onDone: { path.removeAll { $0 == route } })
            }
        case .newMedication:
            MedicationEditor(store: store, onDone: { path.removeAll { $0 == route } })
        case .about:
            AboutPage()
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

    /// Opens or closes the camera. Opening asks first, until the person has allowed pill
    /// pictures to be sent to be checked (guideline: explicit permission before sharing
    /// with a third-party AI).
    private func setScanning(_ open: Bool) {
        if open, !allowsChecking {
            isAskingConsent = true
            return
        }
        withAnimation(ScanLayout.openingAnimation) {
            scan.setOpen(open)
        }
    }
}

#Preview {
    RootView()
}
