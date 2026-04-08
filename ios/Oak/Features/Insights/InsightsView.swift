import SwiftUI

struct InsightsView: View {
    @EnvironmentObject var appState: AppState
    @State private var transactions: [Transaction] = []
    @State private var dashboard: Dashboard?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 40)
                    }
                } else {
                    // Summary (computed from all transactions, not dashboard's current-month subset)
                    if !transactions.isEmpty {
                        Section {
                            HStack(spacing: 12) {
                                SummaryPill(
                                    label: "Income",
                                    value: formatDKK(totalIncome),
                                    color: .green
                                )
                                SummaryPill(
                                    label: "Spending",
                                    value: formatDKK(totalSpending),
                                    color: .red
                                )
                                SummaryPill(
                                    label: "Net",
                                    value: formatDKK(totalIncome - totalSpending),
                                    color: totalIncome > totalSpending ? .green : .red
                                )
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }

                    }

                    // Transactions
                    let grouped = groupTransactions(transactions)
                    ForEach(grouped, id: \.date) { group in
                        Section {
                            ForEach(group.transactions) { txn in
                                TransactionRow(transaction: txn)
                            }
                        } header: {
                            Text(group.displayDate)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Insights")
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
            }
        }
    }

    private var totalIncome: Double {
        transactions.reduce(0.0) { sum, txn in
            let val = NSDecimalNumber(decimal: txn.amount).doubleValue
            return val > 0 ? sum + val : sum
        }
    }

    private var totalSpending: Double {
        transactions.reduce(0.0) { sum, txn in
            let val = NSDecimalNumber(decimal: txn.amount).doubleValue
            return val < 0 ? sum + abs(val) : sum
        }
    }

    private func groupTransactions(_ txns: [Transaction]) -> [TransactionGroup] {
        let grouped = Dictionary(grouping: txns) { $0.bookedAt }
        return grouped.map { date, items in
            TransactionGroup(date: date, transactions: items)
        }
        .sorted { $0.date > $1.date }
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

// MARK: - Transaction grouping

private struct TransactionGroup {
    let date: Date
    let transactions: [Transaction]

    var displayDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "EEEE d MMMM"
        } else {
            formatter.dateFormat = "d MMMM yyyy"
        }
        return formatter.string(from: date)
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
        .background(.white.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Transaction row

private struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForCategory(transaction.normalizedCategory ?? "other"))
                .font(.caption)
                .foregroundStyle(colorForCategory(transaction.normalizedCategory ?? "other"))
                .frame(width: 28, height: 28)
                .background(colorForCategory(transaction.normalizedCategory ?? "other").opacity(0.1))
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

            Text(amountText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(transaction.amount > 0 ? .green : .primary)
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
}

// MARK: - Shared helpers

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
    default: return "circle"
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
    case "income": return .green
    case "transfers": return .teal
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
