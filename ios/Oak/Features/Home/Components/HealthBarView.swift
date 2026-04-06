import SwiftUI

struct HealthBarView: View {
    let healthScore: Int
    
    // State til haptisk feedback
    @State private var scrollTarget: Int? = 0
    
    private let primaryBarColor = Color(red: 92/255, green: 157/255, blue: 84/255)
    private let totalBars = 80
    private let barWidth: CGFloat = 5
    private let spacing: CGFloat = 6
    
    // Højde-indstillinger
    private let idleHeight: CGFloat = 28.0
    private let scaleFactor: CGFloat = 0.8
    private var maxHeight: CGFloat { idleHeight * (1 + scaleFactor) }

    var body: some View {
        GeometryReader { container in
            let midX = container.size.width / 2
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .center, spacing: spacing) {
                    // Start-spacer
                    Color.clear.frame(width: midX - (barWidth / 2))
                    
                    ForEach(0..<totalBars, id: \.self) { i in
                        Capsule()
                            .fill(primaryBarColor)
                            .frame(width: barWidth, height: idleHeight)
                            .visualEffect { content, proxy in
                                let frame = proxy.frame(in: .scrollView)
                                let distance = abs(frame.midX - midX)
                                
                                // Nåle-effekt kurve
                                let influence = max(0, 1.0 - (distance / 35))
                                let needleFactor = pow(influence, 1.2)
                                
                                // Blur effekt
                                let normalizedDistance = min(distance / (midX * 0.9), 1.0)
                                let blurAmount = normalizedDistance * 3.0
                                
                                return content
                                    .scaleEffect(y: 1.0 + (scaleFactor * needleFactor), anchor: .center)
                                    .blur(radius: blurAmount)
                                    .opacity(0.4 + (0.6 * (1.0 - normalizedDistance)))
                            }
                    }
                    
                    // Slut-spacer
                    Color.clear.frame(width: midX - (barWidth / 2))
                }
                .scrollTargetLayout()
            }
            // Dette sikrer at vi tracker hvilken ID der er i midten til haptics
            .scrollPosition(id: $scrollTarget)
            .scrollTargetBehavior(.viewAligned)
            .coordinateSpace(name: "scroll")
            // Haptisk feedback hver gang scrollTarget ændrer sig
            .sensoryFeedback(.selection, trigger: scrollTarget)
        }
        .frame(height: maxHeight)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.2),
                    .init(color: .black, location: 0.8),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
}

#Preview {
    HealthBarView(healthScore: 50)
        .frame(width: 350, height: 100)
        .background(Color.gray.opacity(0.1))
}
