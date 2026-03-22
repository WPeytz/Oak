import SwiftUI

struct MoneyTreeCard: View {
    let treeState: String
    let healthScore: Int
    let leafDensity: Double
    let explanation: String

    var body: some View {
        VStack(spacing: 16) {
            // Tree visualization
            ZStack {
                // Background glow
                Circle()
                    .fill(treeColor.opacity(0.1))
                    .frame(width: 180, height: 180)

                // Tree
                VStack(spacing: 0) {
                    // Canopy
                    TreeCanopyShape()
                        .fill(canopyGradient)
                        .frame(width: canopySize, height: canopySize * 0.8)
                        .opacity(leafDensity * 0.7 + 0.3)

                    // Trunk
                    RoundedRectangle(cornerRadius: 4)
                        .fill(trunkColor)
                        .frame(width: 16, height: 40)
                        .offset(y: -4)
                }

                // Falling leaves for stressed/decaying
                if treeState == "stressed" || treeState == "decaying" {
                    ForEach(0..<fallingLeafCount, id: \.self) { i in
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(fallingLeafColor)
                            .offset(
                                x: CGFloat.random(in: -60...60),
                                y: CGFloat.random(in: 20...80)
                            )
                            .opacity(0.6)
                    }
                }
            }
            .frame(height: 200)

            // Score
            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(healthScore)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(treeColor)

                    Text("/ 100")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(stateLabel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(treeColor)

                Text(explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Computed

    private var treeColor: Color {
        switch treeState {
        case "thriving": return .green
        case "healthy": return .green.opacity(0.8)
        case "stressed": return .orange
        case "decaying": return .red
        default: return .green
        }
    }

    private var stateLabel: String {
        switch treeState {
        case "thriving": return "Thriving"
        case "healthy": return "Healthy"
        case "stressed": return "Stressed"
        case "decaying": return "Needs attention"
        default: return treeState.capitalized
        }
    }

    private var canopySize: CGFloat {
        let base: CGFloat = 80
        return base + CGFloat(leafDensity) * 40
    }

    private var canopyGradient: LinearGradient {
        let baseColor = treeColor
        return LinearGradient(
            colors: [baseColor, baseColor.opacity(0.7)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var trunkColor: Color {
        treeState == "decaying" ? .brown.opacity(0.5) : .brown
    }

    private var fallingLeafCount: Int {
        treeState == "decaying" ? 5 : 2
    }

    private var fallingLeafColor: Color {
        treeState == "decaying" ? .brown : .orange
    }
}

// MARK: - Tree canopy shape

struct TreeCanopyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Three overlapping ellipses for a natural canopy
        path.addEllipse(in: CGRect(x: w * 0.15, y: h * 0.3, width: w * 0.7, height: h * 0.7))
        path.addEllipse(in: CGRect(x: 0, y: h * 0.1, width: w * 0.6, height: h * 0.65))
        path.addEllipse(in: CGRect(x: w * 0.35, y: 0, width: w * 0.65, height: h * 0.7))

        return path
    }
}

#Preview {
    VStack(spacing: 20) {
        MoneyTreeCard(
            treeState: "thriving",
            healthScore: 85,
            leafDensity: 0.85,
            explanation: "You're within your budget and on track with savings."
        )
        MoneyTreeCard(
            treeState: "stressed",
            healthScore: 42,
            leafDensity: 0.4,
            explanation: "You've exceeded your budget. Spending is trending up."
        )
    }
    .padding()
}
