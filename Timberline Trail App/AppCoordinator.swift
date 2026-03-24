//
//  AppCoordinator.swift
//  Timberline Trail App
//
//  Created by Michael Dankanich on 3/6/26.
//

import SwiftUI

struct AppFlowCoordinatorView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var locationTracker: LocationTracker

    var body: some View {
        switch store.flowState {
        case .unauthenticated:
            AuthView(store: store)
        case .onboardingRequired:
            OnboardingView(store: store)
        case .ready:
            MainTabView(store: store, locationTracker: locationTracker)
        }
    }
}
