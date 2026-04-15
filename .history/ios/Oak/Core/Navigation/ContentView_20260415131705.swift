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
        .tint(Color(red: 92/255, green: 157/255, blue: 84/255))
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
        
        // Selected tab bruger Oak grøn (#5C9D54), med hvidt ikon/tekst.
        let activeColor = UIColor(red: 92/255, green: 157/255, blue: 84/255, alpha: 1.0)
        UITabBar.appearance().tintColor = activeColor
        let selectorColor = activeColor.withAlphaComponent(0.95)
        let selectorImage = makeSelectionIndicatorImage(color: selectorColor)
        appearance.selectionIndicatorImage = selectorImage
        UITabBar.appearance().selectionIndicatorImage = selectorImage

        appearance.stackedLayoutAppearance.selected.iconColor = .white
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.inlineLayoutAppearance.selected.iconColor = .white
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.compactInlineLayoutAppearance.selected.iconColor = .white
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    private func makeSelectionIndicatorImage(color: UIColor) -> UIImage? {
        let size = CGSize(width: 90, height: 44)
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { _ in
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 14)
            color.setFill()
            path.fill()
        }

        return image.resizableImage(
            withCapInsets: UIEdgeInsets(top: 22, left: 45, bottom: 22, right: 45),
            resizingMode: .stretch
        )
    }
}

#Preview {
    // Vi skaber en frisk instans af AppState til previewet
    let state = AppState()
    
    return ContentView()
        .environmentObject(state)
}
