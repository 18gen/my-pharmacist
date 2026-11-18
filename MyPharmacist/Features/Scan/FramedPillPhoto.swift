//
//  FramedPillPhoto.swift
//  MyPharmacist
//

import SwiftUI

/// A scan's photo cropped to the shape of the space it is shown in, around the pills
/// found in it, with a mark drawn over each pill: the rings on the "Is every pill
/// circled?" photo and on the results page's.
struct FramedPillPhoto<Mark: View>: View {
    let photo: CGImage
    /// Each pill's box, normalized 0–1 with the origin at the top left of the photo.
    let boxes: [CGRect]
    /// Room around the pills, as a share of their extent.
    var margin: CGFloat = 0.15
    /// The picture's own corners, rounded; nil to leave them square.
    var cornerRadius: CGFloat?
    /// The mark over pill `index`, given where the pill is in the shown picture.
    @ViewBuilder let mark: (_ index: Int, _ shown: CGRect) -> Mark

    var body: some View {
        GeometryReader { proxy in
            let imageSize = CGSize(width: photo.width, height: photo.height)
            let region = PhotoFraming.region(around: boxes, imageSize: imageSize,
                                             aspect: proxy.size.width / max(proxy.size.height, 1), margin: margin)
            if let cropped = photo.cropping(to: region.integral) {
                Image(decorative: cropped, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .overlay {
                        GeometryReader { shown in
                            ForEach(boxes.indices, id: \.self) { index in
                                mark(index, PhotoFraming.shown(boxes[index], imageSize: imageSize, region: region,
                                                               shownWidth: shown.size.width))
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius ?? 0, style: .continuous))
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }
}
