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

/// The introduction shown before the home screen on the first launch: three pages on how
/// to scan pills, check that each was found, and read the result. Swiping or Next moves
/// on; Skip and Get Started both finish it for good.
struct OnboardingView: View {
    /// Called once the person skips or finishes, after that has been saved.
    let onDone: () -> Void

    @State private var page = OnboardingPage.scan

    private var isLastPage: Bool { page == OnboardingPage.allCases.last }

    var body: some View {
        VStack(spacing: 0) {
            Button("Skip", action: finish)
                .font(.title3)
                .foregroundStyle(Palette.textPrimary)
                .frame(minWidth: 44, minHeight: 44)
                .frame(maxWidth: .infinity, alignment: .trailing)
                // Kept in place on the last page, so nothing above the pages moves.
                .opacity(isLastPage ? 0 : 1)
                .disabled(isLastPage)
                .accessibilityHidden(isLastPage)
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
            } else {
                WideButton(title: "Next", systemImage: "arrow.right") {
                    withAnimation { page = page.next }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(Palette.background.ignoresSafeArea())
    }

    /// Which of the pages is showing.
    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingPage.allCases) { dot in
                Capsule()
                    .fill(dot == page ? Palette.textPrimary : Palette.skeleton)
                    .frame(width: dot == page ? 24 : 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: page)
        .accessibilityElement()
        .accessibilityLabel("Page \(page.rawValue + 1) of \(OnboardingPage.allCases.count)")
    }

    private func finish() {
        Onboarding.markDone()
        onDone()
    }
}

/// The introduction's pages, in order.
private enum OnboardingPage: Int, CaseIterable, Identifiable {
    case scan, confirm, results

    var id: Int { rawValue }

    /// The page after this one; the last page stays.
    var next: OnboardingPage { OnboardingPage(rawValue: rawValue + 1) ?? self }

    var title: String {
        switch self {
        case .scan: "Scan Your Pills"
        case .confirm: "Check Every Pill Is Circled"
        case .results: "Review the Results"
        }
    }

    /// Markdown, so the words that appear on screen can be bold.
    var text: LocalizedStringKey {
        switch self {
        case .scan: "Put your pills on your palm. Tap **Scan Pills** and hold the phone over your hand."
        case .confirm: "After the photo, look for a circle around every pill. If one is missing, take the photo again."
        case .results: "See which pills match your schedule now. If a pill is **Unknown** or has a warning, don't take it. Ask your pharmacist."
        }
    }
}

/// One page: a large picture, then what to do in a few large words.
private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        // Scrolls at the largest text sizes, where the words no longer fit under the picture.
        ScrollView {
            VStack(spacing: 24) {
                picture
                    .frame(width: 220, height: 220)
                    // The words say the same.
                    .accessibilityHidden(true)
                Text(page.title)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(page.text)
                    .font(.title3)
                    .foregroundStyle(Palette.textBody)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
            .padding(.bottom, 8)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    @ViewBuilder
    private var picture: some View {
        switch page {
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

#Preview {
    OnboardingView(onDone: {})
}
