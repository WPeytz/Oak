import SwiftUI

struct BudgetProgressCard: View {
    let spent: Double
    let budget: Double
    let remaining: Double
    let percentage: Double
    let daysLeft: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Budget", systemImage: "creditcard")
                    .font(.headline)
                Spacer()
                if budget > 0 {
                    Text("\(Int(percentage))%")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(percentageColor)
                }
            }

            if budget > 0 {
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.quaternary)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(progressGradient)
                            .frame(width: min(geo.size.width, geo.size.width * clampedPercentage / 100))
                    }
                }
                .frame(height: 12)

                // Stats row
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Spent")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatDKK(spent))
                            .font(.subheadline.weight(.medium))
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        Text("Remaining")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatDKK(remaining))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(remaining > 0 ? Color.primary : Color.red)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Days left")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(daysLeft)")
                            .font(.subheadline.weight(.medium))
                    }
                }

                if remaining > 0 && daysLeft > 0 {
                    let dailyAllowance = remaining / Double(daysLeft)
                    Text("~\(formatDKK(dailyAllowance)) per day remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                    Text("Set a budget in Settings to track your spending")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .background(.white.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Computed

    private var clampedPercentage: Double {
        min(100, max(0, percentage))
    }

    private var percentageColor: Color {
        if percentage > 100 { return .red }
        if percentage > 80 { return .orange }
        return .green
    }

    private var progressGradient: LinearGradient {
        let color: Color = percentage > 100 ? .red : (percentage > 80 ? .orange : .green)
        return LinearGradient(
            colors: [color.opacity(0.8), color],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

private func formatDKK(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    formatter.groupingSeparator = "."
    let formatted = formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    return "\(formatted) kr"
}

#Preview {
    VStack(spacing: 16) {
        BudgetProgressCard(
            spent: 3200, budget: 5000, remaining: 1800,
            percentage: 64, daysLeft: 9
        )
        BudgetProgressCard(
            spent: 5500, budget: 5000, remaining: 0,
            percentage: 110, daysLeft: 9
        )
    }
    .padding()
}
