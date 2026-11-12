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
struct OnboardingView: View {
    /// Called once the person skips or finishes, after that has been saved.
    let onDone: () -> Void

    @State private var page = OnboardingPage.welcome

    private var isLastPage: Bool { page == OnboardingPage.allCases.last }
    /// Skip is for the pages in between: the welcome only leads on, and the last page
    /// has Get Started.
    private var hidesSkip: Bool { page == .welcome || isLastPage }
    /// The welcome is on its wallpaper: what sits on it is light instead of dark.
    private var onWallpaper: Bool { page == .welcome }

    var body: some View {
        VStack(spacing: 0) {
            Button("Skip", action: finish)
                .font(.title3)
                .foregroundStyle(Palette.textPrimary)
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
            // The system's dots are white, which can't be seen on this white page.
            .tabViewStyle(.page(indexDisplayMode: .never))

            pageDots
                .padding(.vertical, 16)

            if isLastPage {
                WideButton(title: "Get Started", systemImage: "checkmark", action: finish)
            } else if onWallpaper {
                lightNextButton
            } else {
                WideButton(title: "Next", systemImage: "arrow.right") {
                    withAnimation { page = page.next }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background {
            // Behind the welcome only; it fades to the plain page as the pages move on.
            ZStack {
                Palette.background
                OnboardingWallpaper()
                    .opacity(onWallpaper ? 1 : 0)
            }
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.35), value: onWallpaper)
        }
    }

    /// `WideButton` in the wallpaper's cream with dark words: black would sink into the
    /// dark picture.
    private var lightNextButton: some View {
        Button {
            withAnimation { page = page.next }
        } label: {
            Label("Next", systemImage: "arrow.right")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, minHeight: 34)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(OnboardingWallpaper.cream)
    }

    /// Which of the pages is showing.
    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingPage.allCases) { dot in
                Capsule()
                    .fill(dotColour(isCurrent: dot == page))
                    .frame(width: dot == page ? 24 : 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: page)
        .accessibilityElement()
        .accessibilityLabel("Page \(page.rawValue + 1) of \(OnboardingPage.allCases.count)")
    }

    private func dotColour(isCurrent: Bool) -> Color {
        if onWallpaper { return OnboardingWallpaper.cream.opacity(isCurrent ? 1 : 0.4) }
        return isCurrent ? Palette.textPrimary : Palette.skeleton
    }

    private func finish() {
        Onboarding.markDone()
        onDone()
    }
}

/// The introduction's pages, in order.
private enum OnboardingPage: Int, CaseIterable, Identifiable {
    case welcome, scan, confirm, results

    var id: Int { rawValue }

    /// The page after this one; the last page stays.
    var next: OnboardingPage { OnboardingPage(rawValue: rawValue + 1) ?? self }

    /// Markdown, for the welcome's italic line.
    var title: LocalizedStringKey {
        switch self {
        case .welcome: "Welcome to\n*My Pharmacist*"
        case .scan: "Scan Your Pills"
        case .confirm: "Check Every Pill Is Circled"
        case .results: "Review the Results"
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

/// One page: a large picture, then what to do in a few large words.
private struct OnboardingPageView: View {
    let page: OnboardingPage

    /// The welcome's title is larger than any text style, and still grows with the
    /// person's text size.
    @ScaledMetric(relativeTo: .largeTitle) private var welcomeTitleSize: CGFloat = 46

    /// The welcome is on its wallpaper: cream serif words instead of black ones.
    private var onWallpaper: Bool { page == .welcome }

    var body: some View {
        // Scrolls at the largest text sizes, where the words no longer fit under the picture.
        ScrollView {
            VStack(spacing: 24) {
                picture
                    .frame(width: 220, height: onWallpaper ? 130 : 220)
                    // The words say the same.
                    .accessibilityHidden(true)
                Text(page.title)
                    .font(onWallpaper ? .system(size: welcomeTitleSize, design: .serif) : .largeTitle.weight(.bold))
                    .foregroundStyle(onWallpaper ? OnboardingWallpaper.cream : Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(page.text)
                    .font(.title3)
                    .foregroundStyle(onWallpaper ? OnboardingWallpaper.cream.opacity(0.9) : Palette.textBody)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.top, onWallpaper ? 96 : 24)
            .padding(.bottom, 8)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    @ViewBuilder
    private var picture: some View {
        switch page {
        case .welcome:
            // The app icon's drawing, a pill under a magnifying glass, on the wallpaper.
            ZStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 110, weight: .medium))
                Image(systemName: "pill.fill")
                    .font(.system(size: 37))
                    .offset(x: -10, y: -10)
            }
            .foregroundStyle(OnboardingWallpaper.cream)
        case .scan:
            // The camera's frame around pills, as on the scan's own "aim" picture.
            ZStack {
                Circle().fill(Palette.cardFill)
                Image(systemName: "viewfinder")
                    .font(.system(size: 150, weight: .ultraLight))
                Image(systemName: "pills.fill")
                    .font(.system(size: 62))
            }
            .foregroundStyle(Palette.textPrimary)
        case .confirm:
            // A photo with each pill circled, as the scan shows it.
            ZStack {
                RoundedRectangle(cornerRadius: 44, style: .continuous).fill(Color(white: 0.2))
                circledPill.offset(x: -46, y: -44)
                circledPill.rotationEffect(.degrees(60)).offset(x: 50, y: -8)
                circledPill.rotationEffect(.degrees(-25)).offset(x: -22, y: 52)
            }
        case .results:
            // Two rows of the results page: one pill to take, one unknown.
            VStack(spacing: 14) {
                resultRow("checkmark.circle.fill", colour: Palette.ok, fill: Palette.okFill)
                resultRow("questionmark.circle.fill", colour: Palette.danger, fill: Palette.dangerFill)
            }
            .padding(.horizontal, 10)
        }
    }

    private var circledPill: some View {
        Image(systemName: "pill.fill")
            .font(.system(size: 40))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .overlay(PillRing())
    }

    private func resultRow(_ symbol: String, colour: Color, fill: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "pill.fill")
                .font(.system(size: 34))
                .foregroundStyle(Palette.textSecondary)
            Capsule()
                .fill(Palette.skeleton)
                .frame(height: 14)
            Image(systemName: symbol)
                .font(.system(size: 40))
                .foregroundStyle(colour)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .frame(height: 92)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(fill))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(colour, lineWidth: 2))
    }
}

/// The picture behind the welcome: soft shapes of sky, leaves and warm evening light,
/// blurred into each other like a photo out of focus. Drawn here rather than kept as an
/// image, so it fits every screen. Light at the very top, where the clock is black;
/// darker from there down, where the words are cream.
private struct OnboardingWallpaper: View {
    /// The words, dots and button on the wallpaper.
    static let cream = Color(red: 1.0, green: 0.97, blue: 0.90)

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            ZStack {
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
                // Darker under the words, so cream on it is easy to read.
                LinearGradient(stops: [.init(color: .clear, location: 0.08),
                                       .init(color: .black.opacity(0.32), location: 0.38),
                                       .init(color: .black.opacity(0.42), location: 1)],
                               startPoint: .top, endPoint: .bottom)
            )
            .clipped()
        }
        .accessibilityHidden(true)
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
