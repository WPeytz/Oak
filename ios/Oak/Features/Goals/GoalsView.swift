import SwiftUI

struct GoalsView: View {
    @EnvironmentObject var appState: AppState
    @State private var goals: [SavingsGoal] = []
    @State private var isLoading = true
    @State private var showAddGoal = false
    
    let figmaDarkGreen = Color(red: 0.35, green: 0.55, blue: 0.35)
    let figmaLightBg = Color(red: 0.92, green: 0.97, blue: 0.92)

    var body: some View {
        NavigationStack {
            ZStack {
                figmaLightBg.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                } else if goals.isEmpty {
                    emptyState
                } else {
                    List {
                        // Vi placerer headeren her for at få den til at rulle med
                        Section {
                            ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                                ZStack {
                                    // 1. Det usynlige link (fjerner pilen)
                                    NavigationLink(destination: GoalDetailView(goal: goal)) {
                                        EmptyView()
                                    }
                                    .opacity(0)

                                    // 2. Dit flotte kort (vises ovenpå)
                                    GoalCardView(index: index + 1, goal: goal)
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            }
                            .onDelete(perform: deleteGoal)
                        } header: {
                            headerView
                                .padding(.bottom, 20)
                                .textCase(nil)
                        }
                    }
                    .listStyle(.plain)
                    .background(figmaLightBg)
                    .scrollIndicators(.hidden)
                }
            }
            .task { await loadGoals() }
            .refreshable { await loadGoals() }
            .sheet(isPresented: $showAddGoal) {
                AddGoalSheet { await loadGoals() }
            }
        }
    }

    private var headerView: some View {
        HStack {
            Text("Goals")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(figmaDarkGreen)
            Spacer()
            Button {
                showAddGoal = true
            } label: {
                HStack(spacing: 4) {
                    Text("Add goal")
                    Image(systemName: "plus.circle.fill")
                }
                .font(.subheadline.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.7))
                .foregroundStyle(figmaDarkGreen)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    private func loadGoals() async {
        guard let userId = appState.userId else { return }
        do {
            goals = try await APIClient.shared.listSavingsGoals(userId: userId)
        } catch {}
        isLoading = false
    }

    private func deleteGoal(at offsets: IndexSet) {
        guard let userId = appState.userId else { return }
        
        offsets.forEach { index in
            let goalId = goals[index].id
            Task {
                // Vi kalder API'et. Hvis din APIClient ikke har deleteSavingsGoal endnu,
                // vil denne linje fejle - se forklaring under koden.
                try? await APIClient.shared.deleteSavingsGoal(userId: userId, goalId: goalId)
            }
        }
        goals.remove(atOffsets: offsets)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            GoalTreeView(progress: 0).frame(height: 150)
            Text("No goals yet").font(.title3.weight(.medium)).foregroundStyle(.secondary)
            Button { showAddGoal = true } label: {
                Text("Add Goal").font(.headline).padding(.horizontal, 32).padding(.vertical, 14)
                    .background(figmaDarkGreen).foregroundStyle(.white).clipShape(Capsule())
            }
            Spacer()
        }
    }
}

// MARK: - Goal Card View
struct GoalCardView: View {
    let index: Int
    let goal: SavingsGoal
    let figmaDarkGreen = Color(red: 0.35, green: 0.55, blue: 0.35)

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 12) {
                    Text("Goal \(index)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(figmaDarkGreen)
                    Text(goal.name)
                        .font(.system(size: 20))
                        .foregroundStyle(.gray)
                }
                Spacer()
                Text("\(Int(goal.progress * 100))%")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(figmaDarkGreen)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(figmaDarkGreen.opacity(0.15))
                    Capsule()
                        .fill(figmaDarkGreen)
                        .frame(width: geo.size.width * CGFloat(min(goal.progress, 1.0)))
                }
            }
            .frame(height: 12)

            HStack {
                Text(formatAmount(goal.currentAmount))
                Spacer()
                Text(formatAmount(goal.targetAmount))
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.gray.opacity(0.6))
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(28)
        .padding(.horizontal, 24)
        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Navigation Destination (Hvor træet bor)
struct GoalDetailView: View {
    let goal: SavingsGoal
    var body: some View {
        ZStack {
            Color(red: 0.92, green: 0.97, blue: 0.92).ignoresSafeArea()
            VStack {
                Text(goal.name).font(.title.bold())
                GoalTreeView(progress: goal.progress)
                    .frame(height: 300)
                Text("\(Int(goal.progress * 100))% saved")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Add Goal Sheet
struct AddGoalSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    let onSaved: () async -> Void

    @State private var name = ""
    @State private var targetText = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Goal name", text: $name)
                TextField("Target amount", text: $targetText)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("New Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(name.isEmpty || targetText.isEmpty || isSaving)
                }
            }
        }
    }

    private func save() async {
        guard let userId = appState.userId, let target = Double(targetText) else { return }
        isSaving = true
        _ = try? await APIClient.shared.createSavingsGoal(userId: userId, name: name, targetAmount: target)
        await onSaved()
        dismiss()
    }
}

// MARK: - Helpers
func formatAmount(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = 2
    formatter.maximumFractionDigits = 2
    formatter.groupingSeparator = "."
    formatter.decimalSeparator = ","
    return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
}
