import SwiftUI

struct InsightsView: View {
    @EnvironmentObject var appState: AppState
    @State private var transactions: [Transaction] = []
    @State private var dashboard: Dashboard?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView()
                        .padding(.top, 80)
                } else {
                    VStack(spacing: 20) {
                        // Summary cards
                        if let dashboard {
                            HStack(spacing: 12) {
                                SummaryPill(
                                    label: "Income",
                                    value: formatDKK(dashboard.totalIncome),
                                    color: .green
                                )
                                SummaryPill(
                                    label: "Spending",
                                    value: formatDKK(dashboard.totalSpending),
                                    color: .red
                                )
                                SummaryPill(
                                    label: "Net",
                                    value: formatDKK(dashboard.totalIncome - dashboard.totalSpending),
                                    color: dashboard.totalIncome > dashboard.totalSpending ? .green : .red
                                )
                            }

                            // Category breakdown
                            if !dashboard.topCategories.isEmpty {
                                SpendingInsightsCard(
                                    categories: dashboard.topCategories,
                                    totalSpending: dashboard.totalSpending
                                )
                            }
                        }

                        // Recent transactions
                        if !transactions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Recent transactions")
                                    .font(.headline)

                                ForEach(transactions.prefix(20)) { txn in
                                    TransactionRow(transaction: txn)
                                }
                            }
                            .padding(20)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Insights")
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
            }
        }
    }

    private func loadData() async {
        guard let userId = appState.userId else { return }
        do {
            async let d = APIClient.shared.getDashboard(userId: userId)
            async let t = APIClient.shared.listTransactions(userId: userId)
            dashboard = try await d
            transactions = try await t
        } catch {}
        isLoading = false
    }
}

// MARK: - Summary pill

private struct SummaryPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Transaction row

private struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: categoryIcon)
                .font(.caption)
                .foregroundStyle(categoryColor)
                .frame(width: 28, height: 28)
                .background(categoryColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchant ?? "Unknown")
                    .font(.subheadline)
                    .lineLimit(1)

                Text(displayCategory)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(amountText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(transaction.amount > 0 ? .green : .primary)

                Text(formattedDate)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private var categoryIcon: String {
        guard let cat = transaction.normalizedCategory else { return "questionmark.circle" }
        switch cat {
        case "groceries": return "cart"
        case "eating_out": return "fork.knife"
        case "shopping": return "bag"
        case "transport": return "car"
        case "subscriptions": return "repeat"
        case "income": return "arrow.down.circle"
        default: return "circle"
        }
    }

    private var categoryColor: Color {
        guard let cat = transaction.normalizedCategory else { return .gray }
        switch cat {
        case "groceries": return .green
        case "eating_out": return .orange
        case "shopping": return .pink
        case "transport": return .blue
        case "subscriptions": return .purple
        case "income": return .green
        default: return .gray
        }
    }

    private var displayCategory: String {
        (transaction.normalizedCategory ?? "other")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private var amountText: String {
        let value = NSDecimalNumber(decimal: transaction.amount).doubleValue
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: NSNumber(value: abs(value))) ?? "\(Int(abs(value)))"
        return value >= 0 ? "+\(formatted) kr" : "-\(formatted) kr"
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: transaction.bookedAt)
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
