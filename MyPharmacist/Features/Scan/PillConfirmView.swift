//
//  PillConfirmView.swift
//  MyPharmacist
//

import SwiftUI

/// The photo, closed in on the pills, with every pill the app found circled, and the one
/// question only the person can answer: is every pill circled? A pill the app didn't
/// find can't be checked, and nothing after this step would notice it missing. The
/// question itself is in the header above; here are the picture and the two answers.
struct PillConfirmView: View {
    let found: FoundPills
    let size: CGSize
    let onYes: () -> Void
    let onNo: () -> Void

    /// Room for the two buttons, which sit over the bottom of the picture's space.
    private static let buttonsHeight: CGFloat = 150

    var body: some View {
        VStack(spacing: 0) {
            picture
                .frame(width: size.width, height: max(0, size.height - Self.buttonsHeight - ScanLayout.lensButtonBottomPadding))
            VStack(spacing: 4) {
                WideButton(title: "Yes, check them", systemImage: "checkmark", tint: .white, action: onYes)
                    .foregroundStyle(.black)
                    .accessibilityHint("Every pill in the photo is circled")
                Button("No, take it again", action: onNo)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityHint("A pill is not circled. Opens the camera again")
            }
            .padding(.horizontal, 20)
            .frame(height: Self.buttonsHeight)
            Spacer(minLength: 0)
        }
        .frame(width: size.width, height: size.height)
    }

    private var picture: some View {
        GeometryReader { proxy in
            let imageSize = CGSize(width: found.photo.width, height: found.photo.height)
            // Room around the pills: a pill that was missed is most likely right beside
            // the ones that were found.
            let region = PhotoFraming.region(around: found.boxes, imageSize: imageSize,
                                             aspect: proxy.size.width / max(proxy.size.height, 1), margin: 0.3)
            if let cropped = found.photo.cropping(to: region.integral) {
                Image(decorative: cropped, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .overlay {
                        GeometryReader { shown in
                            ForEach(found.boxes.indices, id: \.self) { index in
                                ring(PhotoFraming.shown(found.boxes[index], imageSize: imageSize, region: region, shownWidth: shown.size.width))
                            }
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        // The header says how many; VoiceOver can't describe where they are.
        .accessibilityHidden(true)
    }

    /// A white ring with a dark edge, so it shows on light and dark pills and skin
    /// alike, a little clear of the pill so the pill itself stays in plain view.
    private func ring(_ rect: CGRect) -> some View {
        let rect = rect.insetBy(dx: -10, dy: -10)
        return Capsule()
            .strokeBorder(.white, lineWidth: 3)
            .background(Capsule().strokeBorder(.black.opacity(0.45), lineWidth: 5))
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }
}

#if DEBUG
#Preview("Is every pill circled?") {
    let sample = DemoScan.samplePills()
    GeometryReader { proxy in
        PillConfirmView(found: FoundPills(photo: sample.photo, boxes: sample.pills.map(\.box)),
                        size: proxy.size, onYes: {}, onNo: {})
    }
    .background(.black)
}
#endif
