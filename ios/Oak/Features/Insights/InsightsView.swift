import SwiftUI

struct InsightsView: View {
    @EnvironmentObject var appState: AppState
    @State private var transactions: [Transaction] = []
    @State private var dashboard: Dashboard?
    @State private var isLoading = true

    private let greenText = Color(red: 0.3, green: 0.5, blue: 0.33)
    private let darkGreen = Color(red: 0.15, green: 0.3, blue: 0.18)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.85, green: 0.96, blue: 0.87),
                    Color(red: 0.75, green: 0.92, blue: 0.78),
                    Color(red: 0.65, green: 0.85, blue: 0.68)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if isLoading {
                ProgressView()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Summary pills
                        if !transactions.isEmpty {
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
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                        }

                        // Grouped transactions
                        let grouped = groupTransactions(transactions)
                        ForEach(grouped, id: \.date) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(group.displayDate)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(greenText)
                                    .padding(.horizontal, 20)

                                VStack(spacing: 0) {
                                    ForEach(Array(group.transactions.enumerated()), id: \.element.id) { index, txn in
                                        TransactionRow(transaction: txn)

                                        if index < group.transactions.count - 1 {
                                            Divider()
                                                .padding(.horizontal, 16)
                                        }
                                    }
                                }
                                .background(.white.opacity(0.7))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .padding(.horizontal, 20)
                            }
                        }

                        Color.clear.frame(height: 80)
                    }
                }
            }
        }
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
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
        } else {
            formatter.dateFormat = "EEE d. MMM"
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
                .foregroundStyle(Color(red: 0.3, green: 0.5, blue: 0.33))
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Transaction row

private struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.merchant ?? "Unknown")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(red: 0.15, green: 0.3, blue: 0.18))
                    .lineLimit(1)

                Text(dateText)
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.3, green: 0.5, blue: 0.33))
            }

            Spacer()

            Text(amountText)
                .font(.title3.weight(.medium))
                .foregroundStyle(transaction.amount > 0
                    ? Color(red: 0.2, green: 0.6, blue: 0.3)
                    : Color(red: 0.15, green: 0.3, blue: 0.18))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d. MMM"
        return formatter.string(from: transaction.bookedAt)
    }

    private var amountText: String {
        let value = NSDecimalNumber(decimal: transaction.amount).doubleValue
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.decimalSeparator = ","
        formatter.groupingSeparator = "."
        let formatted = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return formatted
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
