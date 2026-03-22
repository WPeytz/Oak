import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var dashboard: Dashboard?
    @State private var isLoading = true
    @State private var isSyncing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    VStack(spacing: 16) {
                        Spacer(minLength: 80)
                        ProgressView()
                        Text("Loading your tree...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                } else if let dashboard {
                    VStack(spacing: 20) {
                        // Money Tree
                        MoneyTreeCard(
                            treeState: dashboard.treeState,
                            healthScore: dashboard.healthScore,
                            leafDensity: dashboard.leafDensity,
                            explanation: dashboard.explanation
                        )

                        // Budget Progress
                        BudgetProgressCard(
                            spent: dashboard.discretionarySpent,
                            budget: dashboard.discretionaryBudget,
                            remaining: dashboard.budgetRemaining,
                            percentage: dashboard.budgetPercentage,
                            daysLeft: dashboard.daysLeftInMonth
                        )

                        // Top Spending
                        if !dashboard.topCategories.isEmpty {
                            SpendingInsightsCard(
                                categories: dashboard.topCategories,
                                totalSpending: dashboard.totalSpending
                            )
                        }

                        // Actions
                        if !dashboard.actions.isEmpty {
                            ActionsCard(actions: dashboard.actions)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
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
                    .padding(.top, 80)
                }
            }
            .navigationTitle("Oak")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await syncAndRefresh() }
                    } label: {
                        if isSyncing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                    .disabled(isSyncing)
                }
            }
            .refreshable {
                await syncAndRefresh()
            }
            .task {
                await loadDashboard()
            }
        }
    }

    private func loadDashboard() async {
        guard let userId = appState.userId else { return }
        isLoading = true
        errorMessage = nil

        do {
            dashboard = try await APIClient.shared.getDashboard(userId: userId)
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
            dashboard = try await APIClient.shared.getDashboard(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSyncing = false
    }
}
