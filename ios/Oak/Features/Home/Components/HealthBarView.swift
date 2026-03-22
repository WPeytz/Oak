import SwiftUI

struct HealthBarView: View {
    let healthScore: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<20, id: \.self) { i in
                let barHealth = Double(i) / 20.0 * 100.0
                let isActive = barHealth < Double(healthScore)
                RoundedRectangle(cornerRadius: 1)
                    .fill(isActive ? barColor : Color.gray.opacity(0.15))
                    .frame(width: 4, height: barHeight(for: i))
            }
        }
        .frame(height: 24)
    }

    private var barColor: Color {
        if healthScore >= 70 { return Color(red: 0.2, green: 0.65, blue: 0.3) }
        if healthScore >= 40 { return Color(red: 0.8, green: 0.6, blue: 0.2) }
        return Color(red: 0.8, green: 0.3, blue: 0.2)
    }

    private func barHeight(for index: Int) -> CGFloat {
        // Create a heartbeat-like pattern
        let pattern: [CGFloat] = [
            0.4, 0.5, 0.45, 0.6, 0.5, 0.7, 0.9, 0.5, 0.3, 0.8,
            0.6, 0.5, 0.7, 0.4, 0.85, 0.6, 0.5, 0.65, 0.45, 0.55,
        ]
        return pattern[index % pattern.count] * 24
    }
}
