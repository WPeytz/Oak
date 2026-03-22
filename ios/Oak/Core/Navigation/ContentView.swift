import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 1

    var body: some View {
        TabView(selection: $selectedTab) {
            InsightsView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(0)

            HomeView()
                .tabItem {
                    Label("Home", systemImage: "leaf.fill")
                }
                .tag(1)

            GoalsView()
                .tabItem {
                    Label("Goals", systemImage: "target")
                }
                .tag(2)
        }
        .tint(Color(red: 0.2, green: 0.55, blue: 0.3))
    }
}
