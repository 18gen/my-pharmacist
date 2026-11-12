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
/// Each step's page is a picture of the step across the top of the screen, sharp enough
/// to be understood without the words, fading into a dark page with a few cream words.
/// The rest of the app is black on white; the app shows this in the dark colour scheme,
/// so the clock above it is white.
struct OnboardingView: View {
    /// Called once the person skips or finishes, after that has been saved.
    let onDone: () -> Void

    @State private var page = OnboardingPage.welcome

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
                // Kept in place while hidden, so nothing above the pages moves.
                .opacity(hidesSkip ? 0 : 1)
                .animation(.easeInOut(duration: 0.2), value: hidesSkip)
                .disabled(hidesSkip)
                .accessibilityHidden(hidesSkip)
                .accessibilityHint("Skips the introduction")

            // `Tab` needs iOS 18; tagged views page the same way on iOS 17.
            TabView(selection: $page) {
                ForEach(OnboardingPage.allCases) { page in
                    OnboardingPageView(page: page)
                        .tag(page)
                }
            }
            // The system's dots can't be restyled to match; `pageDots` are drawn instead.
            .tabViewStyle(.page(indexDisplayMode: .never))

            pageDots
                .padding(.vertical, 16)

            if isLastPage {
                wideButton("Get Started", systemImage: "checkmark", action: finish)
            } else {
                wideButton("Next", systemImage: "arrow.right") {
                    withAnimation { page = page.next }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background {
            // Each page's wallpaper fades into the next as the pages move on.
            ZStack {
                ForEach(OnboardingPage.allCases) { wallpaper in
                    OnboardingWallpaper(page: wallpaper)
                        .opacity(wallpaper == page ? 1 : 0)
                }
            }
            .background(OnboardingStyle.dark)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.45), value: page)
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

/// The introduction's own colours and measures.
private enum OnboardingStyle {
    /// The words, drawings, dots and buttons.
    static let cream = Color(red: 1.0, green: 0.97, blue: 0.90)
    /// The page under the pictures.
    static let dark = Color(red: 0.13, green: 0.08, blue: 0.06)
    /// How far down the screen a step's picture reaches.
    static let pictureShare: CGFloat = 0.60
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
                // Lifts the words off the lighter parts of a wallpaper.
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

// MARK: - Pictures

/// What a step looks like, drawn to fill whatever space it is given.
private struct OnboardingScene: View {
    let page: OnboardingPage

    /// Where things are in the photo, as shares of its width and height.
    private static let palm = UnitPoint(x: 0.305, y: 0.640)
    private static let whitePill = UnitPoint(x: 0.2925, y: 0.6375)
    private static let yellowPill = UnitPoint(x: 0.3265, y: 0.6475)

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                switch page {
                case .welcome:
                    EmptyView()
                case .scan:
                    // The photo: pills on a palm, the phone held over them.
                    PhotoPlacement(in: size, focus: UnitPoint(x: 0.5, y: 0.625), zoom: 1).image
                case .confirm:
                    // The palm, closer, with each pill circled as the scan shows them.
                    let photo = PhotoPlacement(in: size, focus: Self.palm, at: UnitPoint(x: 0.5, y: 0.40), zoom: 2.3)
                    photo.image
                    PillRing()
                        .frame(width: 78 * photo.scale, height: 50 * photo.scale)
                        .rotationEffect(.degrees(-24))
                        .position(photo.point(Self.whitePill))
                    PillRing()
                        .frame(width: 44 * photo.scale, height: 44 * photo.scale)
                        .position(photo.point(Self.yellowPill))
                case .results:
                    // The table by the window, out of focus behind the results: two pills
                    // to take and one unknown, in the results page's colours and words.
                    PhotoPlacement(in: size, focus: UnitPoint(x: 0.8, y: 0.45), zoom: 1.5).image
                        .blur(radius: 10)
                        .overlay(.black.opacity(0.25))
                    VStack(spacing: 12) {
                        resultCard("checkmark.circle.fill", "OK to take", colour: Palette.ok, fill: Palette.okFill)
                        resultCard("checkmark.circle.fill", "OK to take", colour: Palette.ok, fill: Palette.okFill)
                        resultCard("questionmark.circle.fill", "Unknown – don't take", colour: Palette.danger, fill: Palette.dangerFill)
                    }
                    .frame(width: min(size.width - 56, 330))
                    .position(x: size.width / 2, y: size.height * 0.47)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
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

/// Where the photo sits so that one part of it is at a chosen place in a space, and where
/// anything else in the photo then is: for drawing on top of it.
private struct PhotoPlacement {
    /// The photo's size in pixels.
    private static let pixels = CGSize(width: 852, height: 1846)

    /// Points on screen for each pixel of the photo.
    let scale: CGFloat
    private let origin: CGPoint

    /// - Parameters:
    ///   - focus: The part of the photo to look at, as shares of its width and height.
    ///   - place: Where in the space that part goes.
    ///   - zoom: 1 just covers the space; more shows less of the photo, larger.
    init(in size: CGSize, focus: UnitPoint, at place: UnitPoint = .center, zoom: CGFloat) {
        scale = max(size.width / Self.pixels.width, size.height / Self.pixels.height) * zoom
        let shown = CGSize(width: Self.pixels.width * scale, height: Self.pixels.height * scale)
        // Never past the photo's edge.
        origin = CGPoint(x: min(0, max(size.width - shown.width, place.x * size.width - focus.x * shown.width)),
                         y: min(0, max(size.height - shown.height, place.y * size.height - focus.y * shown.height)))
    }

    func point(_ share: UnitPoint) -> CGPoint {
        CGPoint(x: origin.x + share.x * Self.pixels.width * scale, y: origin.y + share.y * Self.pixels.height * scale)
    }

    var image: some View {
        Image("OnboardingScene")
            .resizable()
            .frame(width: Self.pixels.width * scale, height: Self.pixels.height * scale)
            .position(point(.center))
    }
}

/// What is behind a page.
private struct OnboardingWallpaper: View {
    let page: OnboardingPage

    var body: some View {
        GeometryReader { proxy in
            Group {
                if page == .welcome {
                    welcome(in: proxy.size)
                } else {
                    step(in: proxy.size)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .accessibilityHidden(true)
    }

    /// The step's picture across the top of the screen, fading into the page its words
    /// are on.
    private func step(in size: CGSize) -> some View {
        ZStack(alignment: .top) {
            OnboardingStyle.dark
            OnboardingScene(page: page)
                .frame(height: size.height * OnboardingStyle.pictureShare)
                .mask(LinearGradient(stops: [.init(color: .black, location: 0.80), .init(color: .clear, location: 1)],
                                     startPoint: .top, endPoint: .bottom))
            // Behind the clock and Skip, which are white.
            LinearGradient(colors: [.black.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: size.height * 0.16)
        }
    }

    /// The welcome's: soft shapes of sky, leaves and warm evening light, blurred into each
    /// other like a photo out of focus, and darker behind the clock and from the words down.
    private func welcome(in size: CGSize) -> some View {
        let w = size.width, h = size.height
        return ZStack {
            Color(red: 0.16, green: 0.09, blue: 0.06)
            shape(Color(red: 0.36, green: 0.58, blue: 0.80), w * 1.6, h * 0.50, x: w * 0.10, y: -h * 0.42)
            shape(Color(red: 0.86, green: 0.90, blue: 0.93), w * 0.7, h * 0.07, x: w * 0.25, y: -h * 0.36)
            shape(Color(red: 0.30, green: 0.42, blue: 0.33), w * 0.8, h * 0.50, x: -w * 0.50, y: -h * 0.08)
            shape(Color(red: 0.80, green: 0.45, blue: 0.14), w * 1.1, h * 0.34, x: w * 0.30, y: h * 0.16)
            shape(Color(red: 0.93, green: 0.68, blue: 0.36), w * 0.5, h * 0.12, x: w * 0.38, y: h * 0.06)
            shape(Color(red: 0.36, green: 0.12, blue: 0.07), w * 1.5, h * 0.40, x: -w * 0.10, y: h * 0.46)
        }
        .blur(radius: 60)
        // The blur thins out at the edges; grown a little, they are off the screen.
        .scaleEffect(1.25)
        .overlay(
            LinearGradient(stops: [.init(color: .black.opacity(0.30), location: 0),
                                   .init(color: .clear, location: 0.10),
                                   .init(color: .black.opacity(0.32), location: 0.38),
                                   .init(color: .black.opacity(0.42), location: 1)],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    private func shape(_ colour: Color, _ width: CGFloat, _ height: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Ellipse()
            .fill(colour)
            .frame(width: width, height: height)
            .offset(x: x, y: y)
    }
}

#Preview {
    OnboardingView(onDone: {})
}
