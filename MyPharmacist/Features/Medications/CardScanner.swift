//
//  CardScanner.swift
//  MyPharmacist
//

import SwiftUI
import Vision
import VisionKit

/// The camera that reads the square code on a keychain card: "Scan a card". It hands
/// back the first code it sees; what the code means is decided elsewhere.
struct CardScanner: View {
    /// The text of the code that was read.
    let onFound: (String) -> Void
    let onCancel: () -> Void
    /// Whether the camera may be used; nil until the person has been asked (the first
    /// time) or the answer is known.
    @State private var access: CameraPermission.Access?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Scan a card")
                .font(Palette.pageTitle)
                .foregroundStyle(Palette.textPrimary)
                .accessibilityAddTraits(.isHeader)

            if let problem {
                Text(problem)
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardBackground()
                Spacer(minLength: 0)
            } else if access == nil {
                Spacer(minLength: 0)
            } else {
                Text("Hold the square code on a medication card in front of the camera.")
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                CodeCamera(onFound: onFound)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .accessibilityLabel("Camera")
            }

            SecondaryButton(title: "Cancel", fillsWidth: true, action: onCancel)
        }
        .padding(.horizontal, 16)
        .padding(.top, 28)
        .padding(.bottom, 16)
        .background(Palette.background)
        // Asked here the first time: until then the camera's availability says "no".
        .task { access = await CameraPermission.request() }
    }

    /// Why the camera can't read codes here, in words; nil when it can, or while the
    /// person is still being asked.
    private var problem: String? {
        if !DataScannerViewController.isSupported {
            return "This phone can't read card codes inside the app. Point the iPhone's Camera at the card instead."
        }
        switch access {
        case nil: return nil
        case .denied: return "My Pharmacist can't use the camera. Allow it in Settings › My Pharmacist › Camera, then try again."
        case .restricted: return "The camera isn't allowed on this iPhone. Point the iPhone's Camera at the card instead."
        case .allowed:
            return DataScannerViewController.isAvailable
                ? nil : "The camera can't read codes right now. Point the iPhone's Camera at the card instead."
        }
    }
}

/// Apple's code scanner, set to look for one QR code at a time.
private struct CodeCamera: UIViewControllerRepresentable {
    let onFound: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFound: onFound)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])],
                                                qualityLevel: .balanced,
                                                recognizesMultipleItems: false,
                                                isHighFrameRateTrackingEnabled: false,
                                                isPinchToZoomEnabled: true,
                                                isGuidanceEnabled: true,
                                                isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        // If it can't start, the picture stays dark and Cancel is still there.
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onFound: (String) -> Void
        /// Only the first code counts: the scanner keeps seeing it while the card is held.
        private var hasFound = false

        init(onFound: @escaping (String) -> Void) {
            self.onFound = onFound
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            read(addedItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            read([item])
        }

        private func read(_ items: [RecognizedItem]) {
            guard !hasFound else { return }
            for case .barcode(let code) in items {
                guard let text = code.payloadStringValue else { continue }
                hasFound = true
                onFound(text)
                return
            }
        }
    }
}
