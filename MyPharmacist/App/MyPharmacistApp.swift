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
/// fades away over the home screen.
private struct LaunchView: View {
    /// Read once, at launch: resetting the introduction on the About & privacy page shows
    /// it the next time the app is opened, not while that page is open.
    @State private var showsOnboarding = LaunchView.onboardingIsNeeded()

    var body: some View {
        ZStack {
            // The home screen isn't made until the introduction is over, so nothing sits
            // behind it until then.
            if !showsOnboarding {
                RootView()
            }
            if showsOnboarding {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.6)) { showsOnboarding = false }
                }
                .transition(.opacity)
                .zIndex(1)
            }
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
