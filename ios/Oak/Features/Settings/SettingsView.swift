import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showGoalEditor = false
    @State private var budgetText = ""
    @State private var savingsText = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    if let user = appState.currentUser {
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(user.email)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button("Sign Out", role: .destructive) {
                        appState.signOut()
                    }
                }

                Section("Goals") {
                    Button {
                        showGoalEditor = true
                    } label: {
                        HStack {
                            Text("Edit Budget & Savings")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Section("Sync") {
                    Button {
                        Task { await syncTransactions() }
                    } label: {
                        Label("Sync Transactions Now", systemImage: "arrow.triangle.2.circlepath")
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("0.1.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showGoalEditor) {
                GoalEditorSheet(
                    userId: appState.userId ?? UUID(),
                    isPresented: $showGoalEditor
                )
            }
        }
    }

    private func syncTransactions() async {
        guard let userId = appState.userId else { return }
        _ = try? await APIClient.shared.syncTransactions(userId: userId)
    }
}

// MARK: - Goal editor sheet

struct GoalEditorSheet: View {
    let userId: UUID
    @Binding var isPresented: Bool

    @State private var budgetText = ""
    @State private var savingsText = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Monthly discretionary budget")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("DKK")
                            .foregroundStyle(.secondary)
                        TextField("5000", text: $budgetText)
                            .keyboardType(.numberPad)
                    }
                    .padding()
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Monthly savings target")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("DKK")
                            .foregroundStyle(.secondary)
                        TextField("2000", text: $savingsText)
                            .keyboardType(.numberPad)
                    }
                    .padding()
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Edit Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(isSaving || !isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        guard let b = Double(budgetText), b > 0 else { return false }
        guard let s = Double(savingsText), s >= 0 else { return false }
        return true
    }

    private func save() async {
        guard let budget = Double(budgetText),
              let savings = Double(savingsText) else { return }
        isSaving = true
        do {
            _ = try await APIClient.shared.upsertGoal(
                userId: userId,
                budget: budget,
                savingsTarget: savings
            )
            isPresented = false
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
