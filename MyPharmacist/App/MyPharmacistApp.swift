//
//  MyPharmacistApp.swift
//  MyPharmacist
//
//  Created by Gen Ichihashi on 2026-10-14.
//

import SwiftUI

@main
struct MyPharmacistApp: App {
    /// Read once, at launch: resetting the introduction on the About & privacy page shows
    /// it the next time the app is opened, not while that page is open.
    @State private var showsOnboarding = MyPharmacistApp.onboardingIsNeeded()

    var body: some Scene {
        WindowGroup {
            Group {
                if showsOnboarding {
                    // The home screen isn't made until the introduction is over, so
                    // nothing sits behind it.
                    OnboardingView {
                        withAnimation { showsOnboarding = false }
                    }
                    .transition(.opacity)
                } else {
                    RootView()
                        .transition(.opacity)
                }
            }
            .preferredColorScheme(.light)
        }
    }

    /// The first launch, or the first after "Reset Onboarding". Debug demos open where
    /// they are asked to instead; `-demoOnboarding` shows the introduction regardless.
    private static func onboardingIsNeeded() -> Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-demoOnboarding") { return true }
        if DemoScan.isRequested { return false }
        #endif
        return !Onboarding.isDone()
    }
}
