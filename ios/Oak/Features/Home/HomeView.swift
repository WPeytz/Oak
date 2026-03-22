import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var dashboard: Dashboard?
    @State private var transactions: [Transaction] = []
    @State private var isLoading = true
    @State private var isSyncing = false
    @State private var errorMessage: String?
    @State private var showSettings = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.92, green: 0.97, blue: 0.92),
                    Color(red: 0.96, green: 0.99, blue: 0.96),
                    .white,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if isLoading {
                ProgressView()
            } else if let dashboard {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Settings gear
                        HStack {
                            Spacer()
                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gearshape")
                                    .font(.title3)
                                    .foregroundStyle(Color(red: 0.3, green: 0.5, blue: 0.35))
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                        // Tree
                        PixelTreeView(
                            healthScore: dashboard.healthScore,
                            treeState: dashboard.treeState
                        )
                        .padding(.top, 20)

                        // Date
                        Text(todayFormatted)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)

                        // Health bars
                        HealthBarView(healthScore: dashboard.healthScore)
                            .padding(.horizontal, 60)
                            .padding(.top, 16)

                        // Financial Health pill
                        HStack {
                            Text("Financial Health")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)

                            Spacer()

                            Text("\(dashboard.healthScore)%")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(healthColor)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(red: 0.15, green: 0.15, blue: 0.15))
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                        // Recent Transactions
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text("Recent Transactions")
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                            .padding(.bottom, 12)

                            Divider()
                                .padding(.horizontal, 24)

                            if transactions.isEmpty {
                                Text("No transactions yet")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(24)
                            } else {
                                ForEach(transactions.prefix(5)) { txn in
                                    HomeTransactionRow(transaction: txn)
                                    if txn.id != transactions.prefix(5).last?.id {
                                        Divider()
                                            .padding(.leading, 60)
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 100)
                    }
                }
                .refreshable {
                    await syncAndRefresh()
                }
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Retry") { Task { await loadDashboard() } }
                }
            }
        }
        .task {
            await loadDashboard()
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showSettings = false }
                        }
                    }
            }
        }
    }

    private var healthColor: Color {
        guard let d = dashboard else { return .green }
        if d.healthScore >= 70 { return Color(red: 0.3, green: 0.85, blue: 0.4) }
        if d.healthScore >= 40 { return .orange }
        return .red
    }

    private var todayFormatted: String {
        let f = DateFormatter()
        f.dateFormat = "EEE. d. MMM."
        return f.string(from: Date())
    }

    private func loadDashboard() async {
        guard let userId = appState.userId else { return }
        isLoading = true
        errorMessage = nil

        do {
            async let d = APIClient.shared.getDashboard(userId: userId)
            async let t = APIClient.shared.listTransactions(userId: userId)
            dashboard = try await d
            transactions = try await t
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func syncAndRefresh() async {
        guard let userId = appState.userId else { return }
        isSyncing = true
        do {
            _ = try await APIClient.shared.syncTransactions(userId: userId)
            async let d = APIClient.shared.getDashboard(userId: userId)
            async let t = APIClient.shared.listTransactions(userId: userId)
            dashboard = try await d
            transactions = try await t
        } catch {
            errorMessage = error.localizedDescription
        }
        isSyncing = false
    }
}

// MARK: - Transaction row (home style)

private struct HomeTransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: categoryIcon)
                .font(.body)
                .foregroundStyle(categoryColor)
                .frame(width: 32, height: 32)

            Text(transaction.merchant ?? "Unknown")
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            Text(amountText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(transaction.amount > 0 ? Color(red: 0.2, green: 0.65, blue: 0.3) : .primary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }

    private var categoryIcon: String {
        guard let cat = transaction.normalizedCategory else { return "circle" }
        switch cat {
        case "groceries": return "cart"
        case "eating_out": return "fork.knife"
        case "shopping": return "bag"
        case "transport": return "car"
        case "housing": return "house"
        case "utilities": return "bolt"
        case "subscriptions": return "repeat"
        case "health": return "heart"
        case "income": return "arrow.down.circle"
        case "transfers": return "arrow.left.arrow.right"
        default: return "circle"
        }
    }

    private var categoryColor: Color {
        guard let cat = transaction.normalizedCategory else { return .gray }
        switch cat {
        case "groceries": return Color(red: 0.2, green: 0.65, blue: 0.3)
        case "eating_out": return .orange
        case "shopping": return .pink
        case "transport": return .blue
        case "income": return Color(red: 0.2, green: 0.65, blue: 0.3)
        default: return .gray
        }
    }

    private var amountText: String {
        let value = NSDecimalNumber(decimal: transaction.amount).doubleValue
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        let formatted = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
        return formatted
    }
}
