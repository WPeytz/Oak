import SwiftUI

struct SpendingInsightsCard: View {
    let categories: [CategoryBreakdown]
    let totalSpending: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Spending", systemImage: "chart.bar")
                .font(.headline)

            // Category bars
            ForEach(categories.prefix(5)) { category in
                CategoryRow(
                    category: category,
                    maxTotal: categories.first?.total ?? 1
                )
            }

            // Total
            HStack {
                Text("Total spending")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatDKK(totalSpending))
                    .font(.caption.weight(.semibold))
            }
            .padding(.top, 4)
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct CategoryRow: View {
    let category: CategoryBreakdown
    let maxTotal: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: iconForCategory(category.category))
                    .font(.caption)
                    .foregroundStyle(colorForCategory(category.category))
                    .frame(width: 20)

                Text(category.displayName)
                    .font(.subheadline)

                if category.isEssential {
                    Text("Essential")
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }

                Spacer()

                Text(formatDKK(category.total))
                    .font(.subheadline.weight(.medium))

                Text("(\(category.count))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Bar
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3)
                    .fill(colorForCategory(category.category).opacity(0.6))
                    .frame(
                        width: max(4, geo.size.width * category.total / maxTotal)
                    )
            }
            .frame(height: 6)
        }
    }
}

private func iconForCategory(_ cat: String) -> String {
    switch cat {
    case "groceries": return "cart"
    case "eating_out": return "fork.knife"
    case "shopping": return "bag"
    case "transport": return "car"
    case "housing": return "house"
    case "utilities": return "bolt"
    case "subscriptions": return "repeat"
    case "health": return "heart"
    case "education": return "book"
    case "entertainment": return "film"
    case "travel": return "airplane"
    case "income": return "arrow.down.circle"
    case "transfers": return "arrow.left.arrow.right"
    default: return "questionmark.circle"
    }
}

private func colorForCategory(_ cat: String) -> Color {
    switch cat {
    case "groceries": return .green
    case "eating_out": return .orange
    case "shopping": return .pink
    case "transport": return .blue
    case "housing": return .indigo
    case "utilities": return .yellow
    case "subscriptions": return .purple
    case "health": return .red
    case "education": return .cyan
    case "entertainment": return .mint
    case "travel": return .teal
    default: return .gray
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
    SpendingInsightsCard(
        categories: [
            CategoryBreakdown(category: "shopping", total: 4599, count: 3, isEssential: false),
            CategoryBreakdown(category: "groceries", total: 1034, count: 4, isEssential: true),
            CategoryBreakdown(category: "eating_out", total: 874, count: 3, isEssential: false),
            CategoryBreakdown(category: "subscriptions", total: 698, count: 3, isEssential: false),
        ],
        totalSpending: 7205
    )
    .padding()
}
