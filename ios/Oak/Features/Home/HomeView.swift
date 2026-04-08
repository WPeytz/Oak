import SceneKit
import SwiftUI

// MARK: - 1. Glass Card UI Component
struct LiquidGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Semi-transparent base
                    RoundedRectangle(cornerRadius: 32)
                        .fill(Color.white.opacity(0.6))
                    
                    // Subtle top bezel
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                        .offset(y: 1)
                }
            )
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
    @State private var showSettings = false
    
    // Time Travel State
    @State private var selectedDate: Date = Date()
    @State private var selectedHealthScore: Int?
    
    // Bottom Sheet Physics State
    enum SheetPosition { case collapsed, expanded }
    @State private var sheetPosition: SheetPosition = .collapsed
    @State private var dragOffset: CGFloat = 0
    
    private let oakBrandGreen = Color(red: 0.2, green: 0.4, blue: 0.2)

    var body: some View {
        ZStack(alignment: .top) {
            // LAYER 1: GRADIENT BACKGROUND
            LinearGradient(
                colors: [Color.white, Color(red: 130/255, green: 213/255, blue: 120/255)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            // LAYER 2: BACKGROUND TREE & DATE
            VStack(spacing: 0) {
                if let _ = dashboard {
                    VoxelTreeView(healthPercentage: CGFloat(displayHealthScore) / 100.0)
                        .frame(height: 380)
                        .padding(.top, 40)
                    
                    Text(formattedDate(selectedDate))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(oakBrandGreen.opacity(0.7))
                        .padding(.top, -20)
                }
                Spacer()
            }

            // LAYER 3: INTERACTIVE BOTTOM SHEET
            GeometryReader { proxy in
                let fullHeight = proxy.size.height
                let expandedOffset: CGFloat = 100
                let collapsedOffset = fullHeight - 340
                
                let baseOffset = (sheetPosition == .expanded) ? expandedOffset : collapsedOffset
                let currentOffset = baseOffset + dragOffset

                VStack(spacing: 0) {
                    // Pull Handle
                    Capsule()
                        .fill(Color.black.opacity(0.1))
                        .frame(width: 40, height: 5)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            
                            // 1. Timeline Scroller (Explicit height ensures it shows up)
                            if let dashboard = dashboard {
                                HealthBarView(
                                    healthScore: dashboard.healthScore,
                                    transactions: transactions
                                ) { date, score in
                                    selectedDate = date
                                    selectedHealthScore = score
                                }
                                .frame(height: 80)
                                .padding(.horizontal, 20)
                                .padding(.top, 5)
                            }
                            
                            // 2. Financial Health Card
                            HStack {
                                Text("Financial Health")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(oakBrandGreen)
                                Spacer()
                                Text("\(displayHealthScore)%")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(healthColor)
                            }
                            .padding(20)
                            .liquidGlassCard()
                            .padding(.horizontal, 16)

                            // 3. Recent Transactions Card
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Recent Transactions")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(oakBrandGreen)
                                    .padding([.top, .leading], 20)
                                    .padding(.bottom, 10)

                                if transactions.isEmpty {
                                    Text("No transactions yet")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(20)
                                } else {
                                    ForEach(transactions.prefix(6)) { txn in
                                        HomeTransactionRow(transaction: txn)
                                        if txn.id != transactions.prefix(6).last?.id {
                                            Divider().padding(.horizontal, 20).opacity(0.1)
                                        }
                                    }
                                }
                            }
                            .padding(.bottom, 10)
                            .liquidGlassCard()
                            .padding(.horizontal, 16)
                            
                            // Extra space to ensure user can scroll past the bottom
                            Color.clear.frame(height: 150)
                        }
                    }
                    .scrollDisabled(sheetPosition == .collapsed || dragOffset > 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                )
                .offset(y: currentOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let translation = value.translation.height
                            // Apply Rubber-banding if pulling above expansion point
                            if sheetPosition == .expanded && translation < 0 {
                                dragOffset = translation * 0.3
                            } else {
                                dragOffset = translation
                            }
                        }
                        .onEnded { value in
                            let velocity = value.velocity.height
                            let predictedEnd = baseOffset + value.predictedEndTranslation.height
                            let midpoint = (expandedOffset + collapsedOffset) / 2
                            
                            let target: SheetPosition
                            // High velocity flick overrides midpoint logic
                            if velocity < -500 {
                                target = .expanded
                            } else if velocity > 500 {
                                target = .collapsed
                            } else {
                                target = predictedEnd < midpoint ? .expanded : .collapsed
                            }

                            // Smooth Apple-style spring animation
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.82, blendDuration: 0)) {
                                sheetPosition = target
                                dragOffset = 0
                            }
                        }
                )
            }
            .ignoresSafeArea(edges: .bottom)

            // LAYER 4: TOP UI ELEMENTS
            HStack {
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(oakBrandGreen)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 5)
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

    // MARK: - Computed Properties & Helpers
    private var displayHealthScore: Int {
        selectedHealthScore ?? dashboard?.healthScore ?? 50
    }

    private var healthColor: Color {
        let score = displayHealthScore
        if score >= 70 { return Color(red: 0.3, green: 0.7, blue: 0.3) }
        if score >= 40 { return .orange }
        return .red
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            f.dateFormat = "'Today' – EEE d. MMM"
        } else {
            f.dateFormat = "EEE d. MMM"
        }
        return f.string(from: date)
    }

    private func loadDashboard() async {
        guard let userId = appState.userId else { return }
        isLoading = true
        do {
            async let d = APIClient.shared.getDashboard(userId: userId)
            async let t = APIClient.shared.listTransactions(userId: userId)
            dashboard = try await d
            transactions = try await t
        } catch {
            print("Error loading home data: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Transaction Row Component
private struct HomeTransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.white.opacity(0.5))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchant ?? "Unknown")
                    .font(.system(size: 14, weight: .semibold))
                Text("Today")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            let amount = NSDecimalNumber(decimal: transaction.amount).doubleValue
            Text("\(amount > 0 ? "+" : "")\(String(format: "%.2f", amount).replacingOccurrences(of: ".", with: ",")) kr.")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(amount > 0 ? .green : .primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

