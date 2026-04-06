import SceneKit
import SwiftUI

// MARK: - 1. Liquid Glass Modifier
struct LiquidGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.4), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 10)
    }
}

extension View {
    func liquidGlassCard() -> some View {
        self.modifier(LiquidGlassModifier())
    }
}

// MARK: - Clamp helper
extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - 2. Home View
struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var dashboard: Dashboard?
    @State private var transactions: [Transaction] = []
    @State private var isLoading = true
    @State private var showSettings = false
    @State private var selectedDate: Date = Date()
    @State private var selectedHealthScore: Int?

    enum SheetPosition { case collapsed, expanded }
    @State private var sheetPosition: SheetPosition = .collapsed
    @State private var dragOffset: CGFloat = 0

    private let oakBrandGreen = Color(red: 0.2, green: 0.4, blue: 0.2)

    var body: some View {
        ZStack(alignment: .top) {
            // LAG 1: BAGGRUND
            LinearGradient(
                colors: [Color.white, Color(red: 130/255, green: 213/255, blue: 120/255)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                if let dashboard = dashboard {
                    VoxelTreeView(healthPercentage: CGFloat(displayHealthScore) / 100.0)
                        .frame(height: 350)
                        .padding(.top, 60)

                    Text(formattedDate(selectedDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    HealthBarView(
                        healthScore: dashboard.healthScore,
                        transactions: transactions
                    ) { date, score in
                        selectedDate = date
                        selectedHealthScore = score
                    }
                    .padding(.horizontal, 60)
                }
                Spacer()
            }

            // LAG 2: SHEET
            GeometryReader { proxy in
                let fullHeight = proxy.size.height
                let expandedOffset: CGFloat = 80
                let collapsedOffset = fullHeight - 320

                let baseOffset: CGFloat = sheetPosition == .collapsed ? collapsedOffset : expandedOffset
                let liveOffset = (baseOffset + dragOffset)
                    .clamped(to: expandedOffset...(collapsedOffset + 60))

                VStack(spacing: 0) {
                    Capsule()
                        .fill(Color.black.opacity(0.1))
                        .frame(width: 40, height: 5)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            financialHealthSection
                            transactionsSection
                            Color.clear.frame(height: 150)
                        }
                    }
                    .scrollDisabled(sheetPosition == .collapsed || dragOffset > 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .liquidGlassCard()
                .padding(.horizontal, 10)
                .offset(y: liveOffset)
                .gesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { value in
                            dragOffset = value.translation.height
                        }
                        .onEnded { value in
                            let velocity = value.velocity.height
                            let predictedEnd = baseOffset + value.predictedEndTranslation.height

                            let newPosition: SheetPosition
                            if velocity < -600 {
                                newPosition = .expanded
                            } else if velocity > 600 {
                                newPosition = .collapsed
                            } else {
                                let midpoint = (expandedOffset + collapsedOffset) / 2
                                newPosition = predictedEnd < midpoint ? .expanded : .collapsed
                            }

                            withAnimation(.spring(response: 0.4, dampingFraction: 0.82, blendDuration: 0)) {
                                sheetPosition = newPosition
                                dragOffset = 0
                            }
                        }
                )
            }
            .ignoresSafeArea(edges: .bottom)

            // LAG 3: NAVIGATION
            HStack {
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(oakBrandGreen)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.15), radius: 8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
        }
        .task { await loadDashboard() }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: - Sections
    private var financialHealthSection: some View {
        HStack {
            Text("Financial Health")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(oakBrandGreen.opacity(0.8)))
            Spacer()
            Text("\(displayHealthScore)%")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(oakBrandGreen)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color.white.opacity(0.35)))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.5), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent Transactions")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(oakBrandGreen.opacity(0.9))
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                if transactions.isEmpty {
                    Text("Ingen transaktioner endnu").font(.caption).foregroundStyle(.secondary).padding(20)
                } else {
                    ForEach(transactions.prefix(5)) { txn in
                        HomeTransactionRow(transaction: txn)
                        if txn.id != transactions.prefix(5).last?.id {
                            Divider().padding(.horizontal, 20).opacity(0.2)
                        }
                    }
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 28).fill(Color.white.opacity(0.35)))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.5), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private var displayHealthScore: Int {
        selectedHealthScore ?? dashboard?.healthScore ?? 50
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            f.dateFormat = "'Today' – EEE. d. MMM."
        } else {
            f.dateFormat = "EEE. d. MMM."
        }
        return f.string(from: date)
    }

    private func loadDashboard() async {
        guard let userId = appState.userId else { return }
        isLoading = true
        do {
            dashboard = try await APIClient.shared.getDashboard(userId: userId)
            transactions = try await APIClient.shared.listTransactions(userId: userId)
        } catch { print(error) }
        isLoading = false
    }
}

// MARK: - Row Styling
private struct HomeTransactionRow: View {
    let transaction: Transaction
    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(Color.white.opacity(0.5)).frame(width: 36, height: 36)
                .overlay(Image(systemName: "leaf.fill").font(.system(size: 12)).foregroundStyle(.green))
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchant ?? "Ukendt").font(.system(size: 14, weight: .semibold))
                Text("I dag").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            let value = NSDecimalNumber(decimal: transaction.amount).doubleValue
            Text("\(transaction.amount > 0 ? "+" : "")\(String(format: "%.2f", value).replacingOccurrences(of: ".", with: ",")) kr.")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(transaction.amount > 0 ? .green : .primary)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
    }
}
