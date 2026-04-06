import SceneKit
import SwiftUI

struct TreeView: View {
    @EnvironmentObject var appState: AppState
    @State private var dashboard: Dashboard?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView()
                        .padding(.top, 80)
                } else if let dashboard {
                    VStack(spacing: 24) {
                        // Large tree visualization
                        VoxelTreeView(healthPercentage: CGFloat(dashboard.healthScore))
                            .frame(height: 420)
                        
                        // Health breakdown
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Health factors")
                                .font(.headline)

                            HealthFactorRow(
                                icon: "creditcard",
                                label: "Budget usage",
                                value: "\(Int(dashboard.budgetPercentage))%",
                                status: budgetStatus
                            )

                            HealthFactorRow(
                                icon: "banknote",
                                label: "Savings progress",
                                value: "\(Int(dashboard.savingsProgress * 100))%",
                                status: savingsStatus
                            )

                            HealthFactorRow(
                                icon: "arrow.up.arrow.down",
                                label: "Spending trend",
                                value: dashboard.trend.capitalized,
                                status: trendStatus
                            )

                            HealthFactorRow(
                                icon: "leaf",
                                label: "Leaf density",
                                value: "\(Int(dashboard.leafDensity * 100))%",
                                status: dashboard.leafDensity > 0.6 ? .good : (dashboard.leafDensity > 0.3 ? .warning : .bad)
                            )
                        }
                        .padding(20)
                        .background(.white.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Your Tree")
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
            }
        }
    }

    private var budgetStatus: FactorStatus {
        if dashboard?.budgetPercentage ?? 0 > 100 { return .bad }
        if dashboard?.budgetPercentage ?? 0 > 80 { return .warning }
        return .good
    }

    private var savingsStatus: FactorStatus {
        if dashboard?.savingsProgress ?? 0 >= 1.0 { return .good }
        if dashboard?.savingsProgress ?? 0 > 0.5 { return .warning }
        return .bad
    }

    private var trendStatus: FactorStatus {
        switch dashboard?.trend {
        case "improving": return .good
        case "worsening": return .bad
        default: return .neutral
        }
    }

    private func loadData() async {
        guard let userId = appState.userId else { return }
        do {
            dashboard = try await APIClient.shared.getDashboard(userId: userId)
        } catch {}
        isLoading = false
    }
}

// MARK: - Health factor row

enum FactorStatus {
    case good, warning, bad, neutral

    var color: Color {
        switch self {
        case .good: return .green
        case .warning: return .orange
        case .bad: return .red
        case .neutral: return .secondary
        }
    }

    var icon: String {
        switch self {
        case .good: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .bad: return "xmark.circle.fill"
        case .neutral: return "minus.circle.fill"
        }
    }
}

struct HealthFactorRow: View {
    let icon: String
    let label: String
    let value: String
    let status: FactorStatus

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.medium))

            Image(systemName: status.icon)
                .font(.caption)
                .foregroundStyle(status.color)
        }
    }
}
