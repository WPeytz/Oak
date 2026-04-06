import SceneKit
import SwiftUI

// MARK: - 1. Glass Card UI Component (Dette giver effekten)
struct LiquidGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Selve glas-fladen (Semi-transparent hvid)
                    RoundedRectangle(cornerRadius: 32)
                        .fill(Color.white.opacity(0.6))
                    
                    // Lys-kant (Bezel) i toppen
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                        .offset(y: 1)
                }
            )
            // Meget blød skygge
            .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 10)
            .clipShape(RoundedRectangle(cornerRadius: 32))
    }
}

extension View {
    func liquidGlassCard() -> some View {
        self.modifier(LiquidGlassModifier())
    }
}

// MARK: - 2. Home View
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
            // Background gradient (RGB: 130, 213, 120)
            LinearGradient(
                colors: [
                    Color.white,
                    Color(red: 130/255, green: 213/255, blue: 120/255)
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
                                    .foregroundStyle(Color(red: 0.2, green: 0.4, blue: 0.2))
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                        // Tree
                        VoxelTreeView(healthPercentage: CGFloat(dashboard.healthScore) / 100.0)
                            .frame(height: 400)
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

                        // --- NYT: Financial Health Glass Card ---
                        HStack {
                            Text("Financial Health")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color(red: 0.2, green: 0.3, blue: 0.2))

                            Spacer()

                            Text("\(dashboard.healthScore)%")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(healthColor)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .liquidGlassCard() // HER påføres glasset
                        .padding(.horizontal, 24)
                        .padding(.top, 24)

                        // --- NYT: Recent Transactions Glass Card ---
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text("Recent Transactions")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color(red: 0.2, green: 0.4, blue: 0.2))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                            .padding(.bottom, 12)

                            if transactions.isEmpty {
                                Text("No transactions yet")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(24)
                            } else {
                                ForEach(transactions.prefix(5)) { txn in
                                    HomeTransactionRow(transaction: txn)
                                    
                                    if txn.id != transactions.prefix(5).last?.id {
                                        Rectangle()
                                            .fill(Color.black.opacity(0.05))
                                            .frame(height: 1)
                                            .padding(.horizontal, 24)
                                    }
                                }
                                .padding(.bottom, 12)
                            }
                        }
                        .liquidGlassCard() // HER påføres glasset
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
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
                .foregroundStyle(Color.primary.opacity(0.8))
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
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
}

