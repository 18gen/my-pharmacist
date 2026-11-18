//
//  OnboardingView.swift
//  MyPharmacist
//

import SwiftUI

/// Whether the person has been through the introduction. Shown on the first launch only;
/// "Reset intro" on the About & privacy page shows it again, at once.
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

    /// The welcome; in debug builds, `-demoOnboardingPage <n>` opens on page n, for screenshots.
    private static var startPage: OnboardingPage {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-demoOnboardingPage"), arguments.indices.contains(index + 1),
           let number = Int(arguments[index + 1]), let page = OnboardingPage(rawValue: number) {
            return page
        }
        #endif
        return .welcome
    }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The page Next is taking the pages to, until they get there.
    @State private var nextTarget: OnboardingPage?
    /// Counts taps on Next, Skip and Get Started, and pages reached by swiping: each is
    /// felt as it happens.
    @State private var taps = 0
    @State private var swipedPages = 0

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
                .foregroundStyle(Palette.cream)
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
                        taps += 1
                        nextTarget = page.next
                        // Slow enough to watch the picture move to the next step.
                        withAnimation(.smooth(duration: 0.9)) { scrolledPage = page.next }
                    }
                }
            }
            .padding(.horizontal, OnboardingStyle.sideMargin)
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
        // A button is felt when it is tapped; a swipe when it reaches a page. Next's own
        // move to its page isn't felt a second time.
        .onChange(of: page) { _, page in
            if page == nextTarget {
                nextTarget = nil
            } else {
                swipedPages += 1
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
        .sensoryFeedback(.selection, trigger: swipedPages)
        #if DEBUG
        .task {
            guard Self.startPage != .welcome else { return }
            try? await Task.sleep(for: .milliseconds(400))
            scrolledPage = Self.startPage
        }
        #endif
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
                    .fill(Palette.cream.opacity(dot == page ? 1 : 0.35))
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
        .tint(Palette.cream)
    }

    private func finish() {
        taps += 1
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

/// The introduction's own measures. Its cream and dark brown are the app's: `Palette`.
enum OnboardingStyle {
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
                        .foregroundStyle(Palette.cream)
                        .accessibilityAddTraits(.isHeader)
                    Text(marked(page.text))
                        .font(.title3)
                        .foregroundStyle(Palette.cream.opacity(0.92))
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
        .foregroundStyle(Palette.cream)
        .frame(height: 150)
        .accessibilityHidden(true)
    }
}

// MARK: - The picture behind the pages

#if DEBUG
#Preview {
    OnboardingView(onDone: {})
}
#endif
