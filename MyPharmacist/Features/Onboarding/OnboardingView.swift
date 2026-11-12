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
/// Every page is cream words and drawings on a dark, blurred wallpaper of its own, unlike
/// the rest of the app, which is black on white. The app shows it in the dark colour
/// scheme, so the clock above it is white.
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
                .font(.title3)
                .foregroundStyle(OnboardingStyle.cream)
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
                    .fill(OnboardingStyle.cream.opacity(dot == page ? 1 : 0.4))
                    .frame(width: dot == page ? 24 : 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: page)
        .accessibilityElement()
        .accessibilityLabel("Page \(page.rawValue + 1) of \(OnboardingPage.allCases.count)")
    }

    /// `WideButton` in the wallpaper's cream with dark words: the app's black button
    /// would sink into the dark picture.
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

/// The introduction's own colours.
private enum OnboardingStyle {
    /// The words, drawings, dots and buttons on the wallpapers.
    static let cream = Color(red: 1.0, green: 0.97, blue: 0.90)
    /// Under the wallpapers, and what they darken towards.
    static let dark = Color(red: 0.16, green: 0.09, blue: 0.06)
}

/// The introduction's pages, in order.
private enum OnboardingPage: Int, CaseIterable, Identifiable {
    case welcome, scan, confirm, results

    var id: Int { rawValue }

    /// The page after this one; the last page stays.
    var next: OnboardingPage { OnboardingPage(rawValue: rawValue + 1) ?? self }

    /// Markdown: the second line is italic.
    var title: LocalizedStringKey {
        switch self {
        case .welcome: "Welcome to\n*My Pharmacist*"
        case .scan: "Scan\n*Your Pills*"
        case .confirm: "Is Every Pill\n*Circled?*"
        case .results: "Review\n*the Results*"
        }
    }

    /// Markdown, so the words that appear on screen can be bold.
    var text: LocalizedStringKey {
        switch self {
        case .welcome: "A double-check for the pills in your hand, before you take them."
        case .scan: "Put your pills on your palm. Tap **Scan Pills** and hold the phone over your hand."
        case .confirm: "After the photo, look for a circle around every pill. If one is missing, take the photo again."
        case .results: "See which pills match your schedule now. If a pill is **Unknown** or has a warning, don't take it. Ask your pharmacist."
        }
    }
}

/// One page: a drawing, then what to do in a few large words.
private struct OnboardingPageView: View {
    let page: OnboardingPage

    /// The title is larger than any text style, and still grows with the person's text size.
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 46

    var body: some View {
        // Scrolls at the largest text sizes, where the words no longer fit under the picture.
        ScrollView {
            VStack(spacing: 24) {
                picture
                    .frame(width: 240, height: 150)
                    // The words say the same.
                    .accessibilityHidden(true)
                Text(page.title)
                    .font(.system(size: titleSize, design: .serif))
                    .foregroundStyle(OnboardingStyle.cream)
                    .accessibilityAddTraits(.isHeader)
                Text(page.text)
                    .font(.title3)
                    .foregroundStyle(OnboardingStyle.cream.opacity(0.92))
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.top, 72)
            .padding(.bottom, 8)
            // Lifts the words off the lighter parts of a wallpaper.
            .shadow(color: .black.opacity(0.35), radius: 8, y: 1)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    @ViewBuilder
    private var picture: some View {
        switch page {
        case .welcome:
            // The app icon's drawing: a pill under a magnifying glass.
            ZStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 110, weight: .medium))
                Image(systemName: "pill.fill")
                    .font(.system(size: 37))
                    .offset(x: -10, y: -10)
            }
            .foregroundStyle(OnboardingStyle.cream)
        case .scan:
            // The camera's frame around pills, as on the scan's own "aim" picture.
            ZStack {
                Image(systemName: "viewfinder")
                    .font(.system(size: 124, weight: .light))
                Image(systemName: "pills.fill")
                    .font(.system(size: 50))
            }
            .foregroundStyle(OnboardingStyle.cream)
        case .confirm:
            // Each pill circled, as the scan shows them on the photo.
            ZStack {
                circledPill.offset(x: -62, y: -30)
                circledPill.rotationEffect(.degrees(60)).offset(x: 58, y: -22)
                circledPill.rotationEffect(.degrees(-25)).offset(x: -4, y: 38)
            }
        case .results:
            // Two rows of the results page: one pill to take, one unknown. Their marks
            // keep the results page's green and red.
            VStack(spacing: 12) {
                resultRow("checkmark.circle.fill", colour: Palette.ok)
                resultRow("questionmark.circle.fill", colour: Palette.danger)
            }
        }
    }

    private var circledPill: some View {
        Image(systemName: "pill.fill")
            .font(.system(size: 34))
            .foregroundStyle(OnboardingStyle.cream)
            .padding(.horizontal, 11)
            .padding(.vertical, 13)
            .overlay(PillRing())
    }

    private func resultRow(_ symbol: String, colour: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "pill.fill")
                .font(.system(size: 28))
                .foregroundStyle(OnboardingStyle.cream)
            Capsule()
                .fill(OnboardingStyle.cream.opacity(0.45))
                .frame(height: 10)
            Image(systemName: symbol)
                .font(.system(size: 34))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, colour)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .frame(height: 66)
        .background(Capsule().fill(.black.opacity(0.28)))
        .overlay(Capsule().strokeBorder(OnboardingStyle.cream.opacity(0.85), lineWidth: 2))
    }
}

/// The picture behind a page, out of focus and darkened so the cream words on it are easy
/// to read. The welcome's is drawn; the others are one photo of pills being scanned,
/// each page looking at a different part of it.
private struct OnboardingWallpaper: View {
    let page: OnboardingPage

    var body: some View {
        GeometryReader { proxy in
            Group {
                switch page {
                case .welcome: drawn(in: proxy.size)
                // The whole scene: the pills on a palm under the phone.
                case .scan: photo(zoom: 1.08, on: .center, blur: 7)
                // Closer on the phone's screen, where the pills are framed.
                case .confirm: photo(zoom: 1.9, on: UnitPoint(x: 0.72, y: 0.68), blur: 9)
                // The table by the window, with the pill box and the bottle.
                case .results: photo(zoom: 1.7, on: UnitPoint(x: 0.95, y: 0.42), blur: 11)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .overlay(shade)
            .clipped()
        }
        .accessibilityHidden(true)
    }

    /// Darker behind the clock, and from the words down.
    private var shade: some View {
        LinearGradient(stops: [.init(color: .black.opacity(0.30), location: 0),
                               .init(color: .clear, location: 0.10),
                               .init(color: .black.opacity(0.32), location: 0.38),
                               .init(color: .black.opacity(0.42), location: 1)],
                       startPoint: .top, endPoint: .bottom)
    }

    /// Part of the photo, out of focus.
    /// - Parameters:
    ///   - zoom: How much larger than the screen it is shown.
    ///   - anchor: The part of the photo the zoom keeps in view.
    private func photo(zoom: CGFloat, on anchor: UnitPoint, blur: CGFloat) -> some View {
        Image("OnboardingScene")
            .resizable()
            .scaledToFill()
            .scaleEffect(zoom, anchor: anchor)
            .blur(radius: blur)
            // The photo is bright; the words need it dimmer than the drawn wallpaper.
            .overlay(OnboardingStyle.dark.opacity(0.30))
    }

    /// Soft shapes of sky, leaves and warm evening light, blurred into each other like a
    /// photo out of focus.
    private func drawn(in size: CGSize) -> some View {
        let w = size.width, h = size.height
        return ZStack {
            OnboardingStyle.dark
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
