import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 1

    var body: some View {
        TabView(selection: $selectedTab) {
            // HISTORY
            InsightsView()
                .tabItem {
                    Image("time-past")
                        .renderingMode(.template)
                    Text("History")
                }
                .tag(0)

            // HOME
            HomeView()
                .tabItem {
                    Image("tree-deciduous")
                        .renderingMode(.template)
                    Text("Home")
                }
                .tag(1)

            // GOALS
            GoalsView()
                .tabItem {
                    Image("tree-sapling")
                        .renderingMode(.template)
                    Text("Goals")
                }
                .tag(2)
        }
        // Farven på det aktive ikon og tekst
        .tint(Color(red: 0.28, green: 0.58, blue: 0.32))
        .onAppear {
            setupTabBarAppearance()
        }
    }

    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        
        // Her integrerer du dit "LiquidGlass" look ved at gøre baggrunden gennemsigtig
        // eller bruge en Blur-effekt, hvis biblioteket ikke gør det automatisk
        appearance.configureWithDefaultBackground()
        
        // Sikrer at ikonerne har den rigtige farve (grå når inaktive)
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.gray.withAlphaComponent(0.5)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.gray.withAlphaComponent(0.5)]
        
        // Sikrer at det aktive ikon bruger din tint-farve
        let activeColor = UIColor(red: 0.28, green: 0.58, blue: 0.32, alpha: 1.0)
        appearance.stackedLayoutAppearance.selected.iconColor = activeColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: activeColor]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

#Preview {
    // Vi skaber en frisk instans af AppState til previewet
    let state = AppState()
    
    return ContentView()
        .environmentObject(state)
}
