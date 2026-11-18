//
//  RootView.swift
//  MyPharmacist
//

import SwiftUI

/// The whole app: today's medications above one camera button. Tapping it grows the
/// button's black circle into the scan view; the same button then closes it.
/// What a scan does is decided by `ScanFlow`; this view only lays out and animates.
struct RootView: View {
    let model: AppModel
    /// The sheet over Home: one at a time.
    @State private var sheet: RootSheet?
    /// The sheet to show once the one open now has closed: a card the camera just read.
    @State private var nextSheet: RootSheet?
    /// Counts the card codes read, for the feel of each.
    @State private var codesRead = 0
    /// The pages pushed over the home screen, in order.
    @State private var path: [AppRoute] = []
    @State private var lastHintAnnouncement = Date.distantPast
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(PillCheckConsent.key) private var allowsChecking = false

    private var store: MedicationStore { model.store }
    private var scan: ScanFlow { model.scan }
    private var pharmacy: PharmacyStore { model.pharmacy }

    /// One of the accessibility text sizes: the instruction gets more room.
    private var largeText: Bool { typeSize.isAccessibilitySize }

    /// The longest VoiceOver waits before saying again what to fix about the picture, so
    /// it doesn't drown out everything else while the hand moves.
    private static let hintAnnouncementGap: TimeInterval = 2.5

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { proxy in
                // Each minute, whether a dose is due now: the scan button turns blue.
                TimelineView(.everyMinute) { context in
                    // Not tied to the camera being open: changing together with it, the
                    // colour's animation would replace the camera's opening spring.
                    screen(in: proxy.size, bottomInset: proxy.safeAreaInsets.bottom, isDue: store.hasDoseDueNow(now: context.date))
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
                sheet = DemoScan.sheet
            }
            #endif
            // Home has its own header instead of a navigation bar.
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $sheet, onDismiss: showNextSheet, content: sheetContent)
            .sensoryFeedback(.success, trigger: codesRead)
            // A keychain card read by the iPhone's Camera, which opened the app on it.
            .onChange(of: model.pendingCardLink, initial: true) { _, link in
                guard let link, sheet == nil else { return }
                model.pendingCardLink = nil
                sheet = .card(ScannedCard(text: link))
            }
            // Every page pushed over the home screen is declared here, once, and opened by
            // adding to `path`. A page shown by a flag (`navigationDestination(isPresented:)`)
            // can't share a stack with pages pushed by value: pushing a medication's page from
            // Pills then showed Pills again, or an empty page.
            .navigationDestination(for: AppRoute.self, destination: page)
        }
    }

    /// The home screen with the scan button, which grows into the scan over it.
    /// - Parameters:
    ///   - size: The screen inside its safe area.
    ///   - bottomInset: The home indicator's strip under that. The scan and its button
    ///     are measured from the screen's physical bottom, so the screen is laid out
    ///     down to there: the same on every iOS version, which letting each of them
    ///     reach into the safe area by itself was not.
    ///   - isDue: A dose is due now: the scan button is blue.
    private func screen(in size: CGSize, bottomInset: CGFloat, isDue: Bool) -> some View {
        ZStack(alignment: .bottom) {
            Palette.background.ignoresSafeArea()

            if !scan.isOpen {
                HomeView(store: store, onShowMedications: showMedications, onShowPharmacy: showPharmacy, onShowAbout: showAbout,
                         onScanCard: { sheet = .cardScanner },
                         // Back from the new page leads to the list it was added to.
                         onTypeIn: { if path.isEmpty { path = [.medications, .newMedication] } })
                    .padding(.top, 8)
                    // Keep clear of the "Scan Pills" hint and button, and of the home
                    // indicator's strip.
                    .padding(.bottom, ScanLayout.homeReservedHeight + bottomInset)
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
                openSize: scan.phase.step.isResultsPage ? ScanLayout.resultsPageSize(in: size, bottomInset: bottomInset)
                                                      : ScanLayout.openLensSize(in: size, largeText: largeText),
                onDone: { setScanning(false) },
                pharmacyCall: pharmacy.pharmacy.callURL,
                closedColor: isDue ? Palette.due : Palette.scanButton
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
        // A geometry reader puts its content at its top, so this reaches down past it.
        .frame(width: size.width, height: size.height + bottomInset)
    }

    /// A page pushed over the home screen.
    @ViewBuilder
    private func page(for route: AppRoute) -> some View {
        switch route {
        case .medications:
            MedicationsPage(store: store, onScanCard: { sheet = .cardScanner },
                            onTypeIn: { if path.last == .medications { path.append(.newMedication) } })
        case .medication(let id):
            if let entry = store.entry(id) {
                MedicationEditor(store: store, entry: entry, onDone: { path.removeAll { $0 == route } })
            }
        case .newMedication:
            MedicationEditor(store: store, onDone: { path.removeAll { $0 == route } })
        case .about:
            AboutPage(store: store, pharmacy: pharmacy)
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: RootSheet) -> some View {
        switch sheet {
        case .consent:
            PillCheckConsentSheet(
                onAllow: {
                    allowsChecking = true
                    self.sheet = nil
                    setScanning(true)
                },
                onNotNow: { self.sheet = nil }
            )
        case .pharmacy:
            PharmacySheet(
                pharmacy: pharmacy.pharmacy,
                startsEditing: startsEditingPharmacy,
                onSave: { pharmacy.pharmacy = $0 },
                onClose: { self.sheet = nil }
            )
        case .cardScanner:
            CardScanner(
                onFound: { code in
                    codesRead += 1
                    nextSheet = .card(ScannedCard(text: code))
                    self.sheet = nil
                },
                onCancel: { self.sheet = nil }
            )
        case .card(let card):
            let outcome = store.outcome(ofCard: card.text)
            MedicationCardSheet(
                outcome: outcome,
                onConfirm: {
                    withAnimation { store.apply(outcome) }
                    self.sheet = nil
                },
                onClose: { self.sheet = nil }
            )
        }
    }

    /// Once a sheet has closed: the card the camera just read, or a card link that
    /// arrived while it was open.
    private func showNextSheet() {
        if let next = nextSheet {
            nextSheet = nil
            sheet = next
        } else if let link = model.pendingCardLink {
            model.pendingCardLink = nil
            sheet = .card(ScannedCard(text: link))
        }
    }

    /// Speaks what to fix about the camera picture for VoiceOver, at most every few
    /// seconds so it doesn't drown out everything else while the hand moves.
    private func announce(_ status: QualityGate.Status) {
        guard scan.phase.step == .aiming, case .needs(let issue) = status, let text = issue.fix,
              Date().timeIntervalSince(lastHintAnnouncement) > Self.hintAnnouncementGap else { return }
        lastHintAnnouncement = Date()
        AccessibilityNotification.Announcement(text).post()
    }

    /// Opens Pills; ignored if a page is already open, so a quick second tap
    /// doesn't push it twice.
    private func showMedications() {
        guard path.isEmpty else { return }
        path.append(.medications)
    }

    /// Opens About & privacy; ignored if a page is already open.
    private func showAbout() {
        guard path.isEmpty else { return }
        path.append(.about)
    }

    /// The pharmacy's card opens on its fields, for a demo of them.
    private var startsEditingPharmacy: Bool {
        #if DEBUG
        DemoScan.editsPharmacy
        #else
        false
        #endif
    }

    /// Shows the pharmacy's card; ignored while a page is open.
    private func showPharmacy() {
        guard path.isEmpty else { return }
        sheet = .pharmacy
    }

    /// Opens or closes the camera. Opening asks first, until the person has allowed pill
    /// pictures to be sent to be checked (guideline: explicit permission before sharing
    /// with a third-party AI).
    private func setScanning(_ open: Bool) {
        if open, !allowsChecking {
            sheet = .consent
            return
        }
        withAnimation(ScanLayout.openingAnimation) {
            scan.setOpen(open)
        }
    }
}

/// The sheets over Home, shown one at a time.
enum RootSheet: Identifiable {
    /// Asking to allow pill checking, before the camera opens for the first time.
    case consent
    /// The pharmacy's card.
    case pharmacy
    /// The camera for a keychain card's code.
    case cardScanner
    /// A keychain card's code, and what it would do, to be agreed to.
    case card(ScannedCard)

    var id: String {
        switch self {
        case .consent: "consent"
        case .pharmacy: "pharmacy"
        case .cardScanner: "cardScanner"
        case .card(let card): card.id.uuidString
        }
    }
}

/// A scanned code, with an identity of its own so that scanning the same card twice
/// shows it twice.
struct ScannedCard: Identifiable {
    let id = UUID()
    let text: String
}

#if DEBUG
#Preview {
    RootView(model: AppModel(store: MedicationStore(entries: SampleMedications.sampleList),
                             pharmacy: PharmacyStore(pharmacy: .sample())))
}
#endif
