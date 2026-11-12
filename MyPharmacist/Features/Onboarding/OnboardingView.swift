//
//  OnboardingView.swift
//  MyPharmacist
//

import SwiftUI

/// Whether the person has been through the introduction. Shown on the first launch only;
/// "Reset Onboarding" on the About & privacy page shows it again on the next launch.
/// Saved on the device.
enum Onboarding {
    /// The UserDefaults key.
    static let key = "onboarding.v1.done"

    static func isDone(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: key)
    }

    static func markDone(in defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: key)
    }

    /// Forgets only that the introduction was seen; nothing else saved is touched.
    static func reset(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}

/// The introduction shown before the home screen on the first launch: a welcome, then
/// three pages on how to scan pills, check that each was found, and read the result.
/// Swiping or Next moves on; Skip and Get Started both finish it for good.
///
/// Behind all four pages is one photo of pills being scanned, and the pages are one
/// move through it (`OnboardingBackdrop`): out of focus behind the welcome, sharp for
/// the scan, closer on the phone's screen where the pills are circled, then into that
/// screen for the results. The move follows the finger while swiping. The words are
/// cream on dark, unlike the rest of the app; the app shows this in the dark colour
/// scheme, so the clock above it is white.
struct OnboardingView: View {
    /// Called once the person skips or finishes, after that has been saved.
    let onDone: () -> Void

    /// The page the pages' scroll view is at, or is asked to go to.
    @State private var scrolledPage: OnboardingPage? = .welcome
    /// How far through the pages the scroll view is: 0 on the welcome, 1.5 halfway
    /// between the scan and the circles, 3 on the results.
    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The page that is showing, or mostly showing while swiping.
    private var page: OnboardingPage {
        OnboardingPage(rawValue: Int(progress.rounded())) ?? .welcome
    }
    private var isLastPage: Bool { page == OnboardingPage.allCases.last }
    /// Skip is for the pages in between: the welcome only leads on, and the last page
    /// has Get Started.
    private var hidesSkip: Bool { page == .welcome || isLastPage }

    var body: some View {
        VStack(spacing: 0) {
            Button("Skip", action: finish)
                .font(.title3.weight(.medium))
                .foregroundStyle(OnboardingStyle.cream)
                // It sits on the picture.
                .shadow(color: .black.opacity(0.5), radius: 6)
                .frame(minWidth: 44, minHeight: 44)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, OnboardingStyle.sideMargin)
                // Kept in place while hidden, so nothing above the pages moves.
                .opacity(hidesSkip ? 0 : 1)
                .animation(.easeInOut(duration: 0.2), value: hidesSkip)
                .disabled(hidesSkip)
                .accessibilityHidden(hidesSkip)
                .accessibilityHint("Skips the introduction")

            pages

            pageDots
                .padding(.vertical, 16)

            Group {
                if isLastPage {
                    wideButton("Get Started", systemImage: "checkmark", action: finish)
                } else {
                    wideButton("Next", systemImage: "arrow.right") {
                        // Slow enough to watch the picture move to the next step.
                        withAnimation(.smooth(duration: 0.9)) { scrolledPage = page.next }
                    }
                }
            }
            .padding(.horizontal, OnboardingStyle.sideMargin)
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background {
            // With Reduce Motion on, the picture changes with the page instead of moving.
            OnboardingBackdrop(progress: reduceMotion ? progress.rounded() : progress)
                .ignoresSafeArea()
        }
    }

    /// The pages side by side, one screen each. A scroll view rather than a paged
    /// `TabView`, which doesn't say how far a swipe has got: the picture behind moves
    /// with it.
    private var pages: some View {
        // Measured here, so each page can be given exactly the space between Skip and
        // the dots: a sideways scroll view is otherwise only as tall as its content asks.
        GeometryReader { space in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(OnboardingPage.allCases, id: \.self) { page in
                        OnboardingPageView(page: page)
                            .padding(.horizontal, OnboardingStyle.sideMargin)
                            .frame(width: space.size.width, height: space.size.height)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrolledPage)
            .scrollIndicators(.hidden)
            .modifier(PagesProgress(progress: $progress, scrolledPage: scrolledPage))
        }
    }

    /// Which of the pages is showing.
    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingPage.allCases) { dot in
                Capsule()
                    .fill(OnboardingStyle.cream.opacity(dot == page ? 1 : 0.35))
                    .frame(width: dot == page ? 24 : 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: page)
        .accessibilityElement()
        .accessibilityLabel("Page \(page.rawValue + 1) of \(OnboardingPage.allCases.count)")
    }

    /// `WideButton` in cream with dark words: the app's black button would sink into the
    /// dark page.
    private func wideButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, minHeight: 34)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(OnboardingStyle.cream)
    }

    private func finish() {
        Onboarding.markDone()
        onDone()
    }
}

/// Keeps `progress` at how far the pages' scroll view has been scrolled, in pages.
private struct PagesProgress: ViewModifier {
    @Binding var progress: CGFloat
    /// The page the scroll view says it is at.
    let scrolledPage: OnboardingPage?

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            // As it scrolls, so the picture behind follows the finger.
            content.onScrollGeometryChange(for: CGFloat.self) { scroll in
                scroll.containerSize.width > 0 ? scroll.contentOffset.x / scroll.containerSize.width : 0
            } action: { _, pages in
                progress = pages
            }
        } else {
            // iOS 17's scroll view doesn't say how far it has scrolled, only which page
            // it has reached: the picture then makes its move to that page by itself.
            content.onChange(of: scrolledPage) { _, page in
                withAnimation(.smooth(duration: 0.9)) { progress = CGFloat(page?.rawValue ?? 0) }
            }
        }
    }
}

/// The introduction's own colours and measures.
private enum OnboardingStyle {
    /// The words, drawings, dots and buttons.
    static let cream = Color(red: 1.0, green: 0.97, blue: 0.90)
    /// The page under the picture.
    static let dark = Color(red: 0.13, green: 0.08, blue: 0.06)
    /// How far down the screen a step's picture reaches.
    static let pictureShare: CGFloat = 0.60
    /// Between the screen's sides and the words and buttons.
    static let sideMargin: CGFloat = 20
}

/// The introduction's pages, in order.
private enum OnboardingPage: Int, CaseIterable, Identifiable {
    case welcome, scan, confirm, results

    var id: Int { rawValue }

    /// The page after this one; the last page stays.
    var next: OnboardingPage { OnboardingPage(rawValue: rawValue + 1) ?? self }

    /// Markdown: the second line is italic.
    var title: String {
        switch self {
        case .welcome: "Welcome to\n*My Pharmacist*"
        case .scan: "Scan\n*Your Pills*"
        case .confirm: "Is Every Pill\n*Circled?*"
        case .results: "Review\n*the Results*"
        }
    }

    /// Markdown, so the words that appear on screen can be bold.
    var text: String {
        switch self {
        case .welcome: "A double-check for the pills in your hand, before you take them."
        case .scan: "Put your pills on your palm.\nTap **Scan Pills** and hold the phone over your hand."
        case .confirm: "Look for a circle around every pill. If one is missing, take the photo again."
        case .results: "Green is OK to take now.\nIf a pill is **Unknown** or has a warning, don't take it. Ask your pharmacist."
        }
    }
}

/// Words with Markdown's bold and italic, keeping their line breaks.
private func marked(_ words: String) -> AttributedString {
    let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    return (try? AttributedString(markdown: words, options: options)) ?? AttributedString(words)
}

/// One page's words: under the app's drawing on the welcome, and at the bottom, below the
/// picture behind them, on each step's page.
private struct OnboardingPageView: View {
    let page: OnboardingPage

    /// The title is larger than any text style, and still grows with the person's text size.
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 46

    var body: some View {
        GeometryReader { proxy in
            // Scrolls at the largest text sizes, where the words no longer fit.
            ScrollView {
                VStack(spacing: page == .welcome ? 24 : 14) {
                    if page == .welcome {
                        appDrawing
                    }
                    Text(marked(page.title))
                        .font(.system(size: titleSize, design: .serif))
                        .foregroundStyle(OnboardingStyle.cream)
                        .accessibilityAddTraits(.isHeader)
                    Text(marked(page.text))
                        .font(.title3)
                        .foregroundStyle(OnboardingStyle.cream.opacity(0.92))
                }
                // Lifts the words off the lighter parts of the picture.
                .shadow(color: .black.opacity(0.35), radius: 8, y: 1)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, page == .welcome ? 72 : 0)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height, alignment: page == .welcome ? .top : .bottom)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    /// The app icon's drawing: a pill under a magnifying glass.
    private var appDrawing: some View {
        ZStack {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 110, weight: .medium))
            Image(systemName: "pill.fill")
                .font(.system(size: 37))
                .offset(x: -10, y: -10)
        }
        .foregroundStyle(OnboardingStyle.cream)
        .frame(height: 150)
        .accessibilityHidden(true)
    }
}

// MARK: - The picture behind the pages

/// The photo behind every page, seen as if by a camera that moves from page to page:
/// - welcome: the whole scene, out of focus and dimmed, behind the words;
/// - scan: the same scene sharp, moved up to the top of the screen: pills on a palm, the
///   phone held over them;
/// - circles: closer on the phone's screen, with each pill on it circled as the scan does;
/// - results: into the phone's screen, out of focus behind what the results look like.
/// Between pages everything is in between, so a swipe moves the camera with the finger.
private struct OnboardingBackdrop: View, Animatable {
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

            ZStack(alignment: .topLeading) {
                OnboardingStyle.dark

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
                                       .init(color: .black.opacity(0.32), location: 0.38),
                                       .init(color: .black.opacity(0.42), location: 1)],
                               startPoint: .top, endPoint: .bottom)
                    .opacity(welcome)
                // A step's words are on the dark page its picture fades into.
                LinearGradient(stops: [.init(color: .clear, location: OnboardingStyle.pictureShare * 0.80),
                                       .init(color: OnboardingStyle.dark, location: OnboardingStyle.pictureShare),
                                       .init(color: OnboardingStyle.dark, location: 1)],
                               startPoint: .top, endPoint: .bottom)
                    .opacity(1 - welcome)
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
            PhotoCamera(in: size, focus: .center, zoom: 1.05, blur: 4, dim: 0.25),
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

#Preview {
    OnboardingView(onDone: {})
}
