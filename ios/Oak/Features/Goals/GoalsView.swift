import SwiftUI

struct GoalsView: View {
    @EnvironmentObject var appState: AppState
    @State private var goals: [SavingsGoal] = []
    @State private var selectedGoalIndex: Int = 0
    @State private var isLoading = true
    @State private var showAddGoal = false
    @State private var showEditGoal = false

    var body: some View {
        ZStack {
            // Background
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
            } else if goals.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Selected goal header
                        if let goal = selectedGoal {
                            // Title
                            HStack(alignment: .firstTextBaseline) {
                                Text("Goal \(selectedGoalIndex + 1)")
                                    .font(.title.bold())
                                    .foregroundStyle(Color(red: 0.2, green: 0.45, blue: 0.25))
                                Text(goal.name)
                                    .font(.title3)
                                    .foregroundStyle(Color(red: 0.2, green: 0.45, blue: 0.25).opacity(0.7))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.top, 16)

                            // Tree visualization
                            GoalTreeView(progress: goal.progress)
                                .padding(.top, 8)

                            // Progress bar
                            VStack(spacing: 8) {
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.gray.opacity(0.2))

                                        Capsule()
                                            .fill(Color(red: 0.2, green: 0.6, blue: 0.3))
                                            .frame(width: max(8, geo.size.width * min(1, goal.progress)))
                                    }
                                }
                                .frame(height: 10)

                                // Amount text
                                Text(formatAmount(goal.currentAmount) + " | " + formatAmount(goal.targetAmount))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 40)
                            .padding(.top, 8)

                            // Edit button
                            Button {
                                showEditGoal = true
                            } label: {
                                Text("Edit Goal")
                                    .font(.caption)
                                    .foregroundStyle(Color(red: 0.2, green: 0.5, blue: 0.25))
                            }
                            .padding(.top, 8)
                        }

                        // All Goals header
                        HStack {
                            Text("All Goals")
                                .font(.subheadline.weight(.medium))
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Button {
                                showAddGoal = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color(red: 0.2, green: 0.55, blue: 0.3))
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 8)

                        Divider()
                            .padding(.horizontal, 24)

                        // Goal list
                        ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                            Button {
                                withAnimation { selectedGoalIndex = index }
                            } label: {
                                HStack {
                                    Text("Goal \(index + 1)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(selectedGoalIndex == index
                                            ? Color(red: 0.2, green: 0.5, blue: 0.25)
                                            : .primary)

                                    Text(goal.name)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    Text(formatAmount(goal.targetAmount))
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color(red: 0.2, green: 0.5, blue: 0.25))
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(selectedGoalIndex == index
                                    ? Color(red: 0.2, green: 0.6, blue: 0.3).opacity(0.05)
                                    : Color.clear)
                            }

                            if index < goals.count - 1 {
                                Divider()
                                    .padding(.leading, 24)
                            }
                        }

                        Spacer(minLength: 100)
                    }
                }
            }
        }
        .task {
            await loadGoals()
        }
        .refreshable {
            await loadGoals()
        }
        .sheet(isPresented: $showAddGoal) {
            AddGoalSheet { await loadGoals() }
        }
        .sheet(isPresented: $showEditGoal) {
            if let goal = selectedGoal {
                EditGoalSheet(goal: goal) { await loadGoals() }
            }
        }
    }

    private var selectedGoal: SavingsGoal? {
        guard selectedGoalIndex < goals.count else { return nil }
        return goals[selectedGoalIndex]
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            GoalTreeView(progress: 0)
                .frame(height: 150)
            Text("No goals yet")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
            Text("Set a savings goal and watch\nyour tree grow toward it")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Button {
                showAddGoal = true
            } label: {
                Text("Add Goal")
                    .font(.headline)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.2, green: 0.55, blue: 0.3))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            Spacer()
        }
    }

    private func loadGoals() async {
        guard let userId = appState.userId else { return }
        do {
            goals = try await APIClient.shared.listSavingsGoals(userId: userId)
            if selectedGoalIndex >= goals.count {
                selectedGoalIndex = max(0, goals.count - 1)
            }
        } catch {}
        isLoading = false
    }
}

// MARK: - Add Goal Sheet

private struct AddGoalSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    let onSaved: () async -> Void

    @State private var name = ""
    @State private var targetText = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Goal name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g. MacBook Air M5", text: $name)
                        .padding()
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Target amount")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("DKK")
                            .foregroundStyle(.secondary)
                        TextField("e.g. 9999", text: $targetText)
                            .keyboardType(.decimalPad)
                    }
                    .padding()
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Spacer()
            }
            .padding()
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(name.isEmpty || Double(targetText) == nil || isSaving)
                }
            }
        }
    }

    private func save() async {
        guard let userId = appState.userId,
              let target = Double(targetText) else { return }
        isSaving = true
        _ = try? await APIClient.shared.createSavingsGoal(
            userId: userId, name: name, targetAmount: target
        )
        await onSaved()
        dismiss()
    }
}

// MARK: - Edit Goal Sheet

private struct EditGoalSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    let goal: SavingsGoal
    let onSaved: () async -> Void

    @State private var name: String
    @State private var targetText: String
    @State private var currentText: String
    @State private var isSaving = false

    init(goal: SavingsGoal, onSaved: @escaping () async -> Void) {
        self.goal = goal
        self.onSaved = onSaved
        _name = State(initialValue: goal.name)
        _targetText = State(initialValue: String(format: "%.0f", goal.targetAmount))
        _currentText = State(initialValue: String(format: "%.2f", goal.currentAmount))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Goal name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Name", text: $name)
                        .padding()
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Target amount")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("DKK")
                            .foregroundStyle(.secondary)
                        TextField("Target", text: $targetText)
                            .keyboardType(.decimalPad)
                    }
                    .padding()
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Current amount saved")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("DKK")
                            .foregroundStyle(.secondary)
                        TextField("Saved so far", text: $currentText)
                            .keyboardType(.decimalPad)
                    }
                    .padding()
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func save() async {
        guard let userId = appState.userId else { return }
        isSaving = true
        _ = try? await APIClient.shared.updateSavingsGoal(
            userId: userId,
            goalId: goal.id,
            name: name,
            targetAmount: Double(targetText),
            currentAmount: Double(currentText)
        )
        await onSaved()
        dismiss()
    }
}

// MARK: - Helpers

private func formatAmount(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = 2
    formatter.maximumFractionDigits = 2
    formatter.groupingSeparator = "."
    formatter.decimalSeparator = ","
    return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
}
