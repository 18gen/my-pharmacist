//
//  MyPharmacistApp.swift
//  MyPharmacist
//
//  Created by Gen Ichihashi on 2026-10-14.
//

import SwiftUI

@main
struct MyPharmacistApp: App {
    var body: some Scene {
        WindowGroup {
            LaunchView()
        }
    }
}

/// What the app opens on: the introduction the first time, then the home screen. A view
/// rather than part of the `App`, whose own changes aren't animated: the introduction
/// fades away over the home screen, and fades back in over it when "Reset intro" on the
/// About & privacy page asks for it again.
private struct LaunchView: View {
    @State private var showsOnboarding = LaunchView.onboardingIsNeeded()
    /// Whether the introduction has been finished, as saved: "Reset intro" clears it.
    @AppStorage(Onboarding.key) private var onboardingIsDone = false

    /// How long the introduction takes to fade in or out.
    private static let fade = 0.6

    var body: some View {
        ZStack {
            // The home screen isn't made until the introduction is over, so nothing sits
            // behind it until then.
            if !showsOnboarding {
                RootView()
                    // There at once when the introduction ends; when it comes back, the
                    // home screen stays under it until it has faded in.
                    .transition(.asymmetric(insertion: .identity,
                                            removal: .opacity.animation(.linear(duration: 0.01).delay(Self.fade))))
            }
            if showsOnboarding {
                OnboardingView {
                    withAnimation(.easeInOut(duration: Self.fade)) { showsOnboarding = false }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        // "Reset intro": the introduction again, from its welcome, without reopening the
        // app. The home screen it returns to afterwards is a new one, back on Home.
        .onChange(of: onboardingIsDone) { _, isDone in
            guard !isDone, !showsOnboarding else { return }
            withAnimation(.easeInOut(duration: Self.fade)) { showsOnboarding = true }
        }
        // The app is black on white; the introduction is on dark wallpapers, and in the
        // dark scheme the clock above it is white.
        .preferredColorScheme(showsOnboarding ? .dark : .light)
    }

    /// The first launch, or the first after "Reset intro". Debug demos open where
    /// they are asked to instead; `-demoOnboarding` shows the introduction regardless.
    private static func onboardingIsNeeded() -> Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-demoOnboarding") { return true }
        if DemoScan.isRequested { return false }
        #endif
        return !Onboarding.isDone()
    }
}
