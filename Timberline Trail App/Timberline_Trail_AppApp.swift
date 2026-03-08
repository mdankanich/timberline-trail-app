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
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
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
}
