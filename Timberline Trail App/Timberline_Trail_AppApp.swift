//
//  Timberline_Trail_AppApp.swift
//  Timberline Trail App
//
//  Created by Michael Dankanich on 3/5/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct Timberline_Trail_AppApp: App {
    init() {
#if canImport(UIKit)
        configureAppearance()
#endif
#if canImport(FirebaseCore)
        configureFirebaseIfPossible()
#endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(.green)
        }
    }

#if canImport(UIKit)
    private func configureAppearance() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().prefersLargeTitles = true

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
#endif

#if canImport(FirebaseCore)
    private func configureFirebaseIfPossible() {
        guard FirebaseApp.app() == nil else { return }
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") else {
            print("Firebase disabled: GoogleService-Info.plist not found in app bundle.")
            return
        }
        guard let options = FirebaseOptions(contentsOfFile: path) else {
            print("Firebase disabled: unable to load GoogleService-Info.plist.")
            return
        }
        if let configuredBundleID = options.bundleID, configuredBundleID != bundleID {
            print("Firebase disabled: plist bundle ID \(configuredBundleID) does not match app bundle ID \(bundleID).")
            return
        }
        FirebaseApp.configure(options: options)
    }
#endif
}
