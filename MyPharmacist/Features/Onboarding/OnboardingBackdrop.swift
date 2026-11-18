//
//  OnboardingBackdrop.swift
//  MyPharmacist
//

import SwiftUI

/// The photo behind every page, seen as if by a camera that moves from page to page:
/// - welcome: the whole scene, out of focus and dimmed, behind the words;
/// - scan: the same scene sharp, moved up to the top of the screen: pills on a palm, the
///   phone held over them;
/// - circles: closer on the phone's screen, with each pill on it circled as the scan does;
/// - results: into the phone's screen, out of focus behind what the results look like.
/// Between pages everything is in between, so a swipe moves the camera with the finger.
struct OnboardingBackdrop: View, Animatable {
    /// 0 on the welcome to 3 on the results; in between while the pages move.
    var progress: CGFloat

    /// Lets an animation of `progress` pass through every place in between.
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    /// Where things are in the photo, as shares of its width and height.
    private static let phoneScreen = UnitPoint(x: 0.700, y: 0.650)
    private static let whitePill = UnitPoint(x: 0.6875, y: 0.6455)
    private static let yellowPill = UnitPoint(x: 0.7260, y: 0.6585)

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            // The top of the screen, which a step's picture fills.
            let top = CGSize(width: size.width, height: size.height * OnboardingStyle.pictureShare)
            let camera = camera(in: size, top: top)
            // How much each page's own things show: fully on its page, gone a third of
            // the way to the next.
            let circles = max(0, 1 - abs(progress - 2) * 3)
            let results = max(0, 1 - abs(progress - 3) * 3)
            let welcome = max(0, 1 - progress)
            // Where the dark page under a step's picture starts, and how much of the
            // picture above that fades into it.
            let pageTop = size.height * (1 - (1 - OnboardingStyle.pictureShare) * min(max(progress, 0), 1))
            let pageFade = top.height * 0.20

            ZStack(alignment: .topLeading) {
                Palette.espresso

                Image("OnboardingScene")
                    .resizable()
                    .frame(width: PhotoCamera.pixels.width, height: PhotoCamera.pixels.height)
                    .scaleEffect(camera.scale, anchor: .topLeading)
                    .offset(x: camera.origin.x, y: camera.origin.y)
                    .frame(width: size.width, height: size.height, alignment: .topLeading)
                    .blur(radius: camera.blur)
                    .overlay(.black.opacity(camera.dim))

                // The welcome's words are over the whole picture: darker from them down.
                LinearGradient(stops: [.init(color: .clear, location: 0.10),
                                       .init(color: .black.opacity(0.36), location: 0.38),
                                       .init(color: .black.opacity(0.46), location: 1)],
                               startPoint: .top, endPoint: .bottom)
                    .opacity(welcome)
                // A step's words are on the dark page its picture fades into. From the
                // welcome it rises from the bottom of the screen as the photo moves up,
                // always over the photo's bottom edge, so that edge is never seen.
                VStack(spacing: 0) {
                    LinearGradient(colors: [Palette.espresso.opacity(0), Palette.espresso],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: pageFade)
                    Palette.espresso
                }
                .frame(width: size.width, height: size.height, alignment: .top)
                .offset(y: pageTop - pageFade)
                // Behind the clock and Skip, which are white.
                LinearGradient(colors: [.black.opacity(0.40), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: size.height * 0.16)

                // Each pill on the phone's screen circled, as the scan shows them. The
                // rings are a little large as they come in, and close onto the pills.
                Group {
                    PillRing()
                        .frame(width: 80 * camera.scale, height: 46 * camera.scale)
                        .rotationEffect(.degrees(-33))
                        .position(camera.point(Self.whitePill))
                    PillRing()
                        .frame(width: 46 * camera.scale, height: 46 * camera.scale)
                        .position(camera.point(Self.yellowPill))
                }
                .scaleEffect(1 + (1 - circles) * 0.25, anchor: UnitPoint(x: camera.point(Self.phoneScreen).x / max(size.width, 1),
                                                                         y: camera.point(Self.phoneScreen).y / max(size.height, 1)))
                .opacity(circles)

                // Two pills to take and one unknown, in the results page's colours and
                // words, rising into place.
                VStack(spacing: 12) {
                    resultCard("checkmark.circle.fill", "OK to take", colour: Palette.ok, fill: Palette.okFill)
                    resultCard("checkmark.circle.fill", "OK to take", colour: Palette.ok, fill: Palette.okFill)
                    resultCard("questionmark.circle.fill", "Unknown – don't take", colour: Palette.danger, fill: Palette.dangerFill)
                }
                .frame(width: min(size.width - 56, 330))
                .position(x: top.width / 2, y: top.height * 0.50 + (1 - results) * 28)
                .opacity(results)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        .accessibilityHidden(true)
    }

    /// The camera for `progress`: a page's own, or in between two pages'.
    private func camera(in size: CGSize, top: CGSize) -> PhotoCamera {
        let pages = [
            PhotoCamera(in: size, focus: .center, zoom: 1.05, blur: 4, dim: 0.38),
            PhotoCamera(in: top, focus: UnitPoint(x: 0.5, y: 0.625), zoom: 1),
            PhotoCamera(in: top, focus: Self.phoneScreen, at: UnitPoint(x: 0.5, y: 0.46), zoom: 2.3),
            PhotoCamera(in: top, focus: Self.phoneScreen, at: UnitPoint(x: 0.5, y: 0.50), zoom: 3.4, blur: 9, dim: 0.30),
        ]
        let place = min(max(progress, 0), CGFloat(pages.count - 1))
        let from = Int(place.rounded(.down)), to = min(from + 1, pages.count - 1)
        return PhotoCamera.between(pages[from], pages[to], place - CGFloat(from),
                                   around: CGPoint(x: top.width / 2, y: top.height / 2))
    }

    /// One pill on the results page: its picture, what to do with it, and its name's place.
    private func resultCard(_ symbol: String, _ label: String, colour: Color, fill: Color) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(white: 0.15))
                .frame(width: 48, height: 48)
                .overlay(Image(systemName: "pill.fill").font(.system(size: 24)).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 6) {
                Label(label, systemImage: symbol)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(colour)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Capsule()
                    .fill(Palette.textMuted.opacity(0.35))
                    .frame(width: 110, height: 8)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(fill))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(colour, lineWidth: 2))
    }
}

/// How the photo is seen at one moment: how large, where, how sharp and how bright. Also
/// says where anything in the photo then is on screen, for drawing on top of it.
private struct PhotoCamera {
    /// The photo's size in pixels.
    static let pixels = CGSize(width: 852, height: 1846)

    /// Points on screen for each pixel of the photo.
    var scale: CGFloat
    /// The photo's top left corner on screen.
    var origin: CGPoint
    var blur: CGFloat
    /// How much black is over the photo, 0 to 1.
    var dim: Double

    /// - Parameters:
    ///   - size: The space the photo is to cover, from the screen's top left corner.
    ///   - focus: The part of the photo to look at, as shares of its width and height.
    ///   - place: Where in the space that part goes.
    ///   - zoom: 1 just covers the space; more shows less of the photo, larger.
    init(in size: CGSize, focus: UnitPoint, at place: UnitPoint = .center, zoom: CGFloat, blur: CGFloat = 0, dim: Double = 0) {
        scale = max(size.width / Self.pixels.width, size.height / Self.pixels.height) * zoom
        let shown = CGSize(width: Self.pixels.width * scale, height: Self.pixels.height * scale)
        // Never past the photo's edge.
        origin = CGPoint(x: min(0, max(size.width - shown.width, place.x * size.width - focus.x * shown.width)),
                         y: min(0, max(size.height - shown.height, place.y * size.height - focus.y * shown.height)))
        self.blur = blur
        self.dim = dim
    }

    /// Where a part of the photo is on screen.
    func point(_ share: UnitPoint) -> CGPoint {
        CGPoint(x: origin.x + share.x * Self.pixels.width * scale, y: origin.y + share.y * Self.pixels.height * scale)
    }

    /// The part of the photo that is at a place on screen, in pixels.
    private func pixel(at place: CGPoint) -> CGPoint {
        CGPoint(x: (place.x - origin.x) / scale, y: (place.y - origin.y) / scale)
    }

    /// The camera a share of the way from one to another. The zoom grows by equal
    /// factors and what is at `centre` moves in a straight line across the photo, so it
    /// looks like one steady move rather than a slide that speeds up.
    static func between(_ from: PhotoCamera, _ to: PhotoCamera, _ share: CGFloat, around centre: CGPoint) -> PhotoCamera {
        var camera = from
        camera.scale = from.scale * pow(to.scale / from.scale, share)
        let a = from.pixel(at: centre), b = to.pixel(at: centre)
        let looked = CGPoint(x: a.x + (b.x - a.x) * share, y: a.y + (b.y - a.y) * share)
        camera.origin = CGPoint(x: centre.x - looked.x * camera.scale, y: centre.y - looked.y * camera.scale)
        camera.blur = from.blur + (to.blur - from.blur) * share
        camera.dim = from.dim + (to.dim - from.dim) * Double(share)
        return camera
    }
}
