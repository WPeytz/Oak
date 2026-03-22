import SwiftUI

@main
struct OakApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.hasCompletedOnboarding {
                    ContentView()
                } else {
                    OnboardingFlow()
                }
            }
            .environmentObject(appState)
            .task {
                await appState.restoreSession()
            }
        }
    }
}
