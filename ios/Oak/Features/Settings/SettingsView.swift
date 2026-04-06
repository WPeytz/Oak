import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showGoalEditor = false
    @State private var showConnectBank = false
    @State private var showCSVPicker = false
    @State private var isSyncing = false
    @State private var syncResult: String?
    @State private var isImporting = false
    @State private var importResult: String?

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

                Section("Bank") {
                    Button {
                        showConnectBank = true
                    } label: {
                        HStack {
                            Label("Connect Bank", systemImage: "building.columns")
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
                        HStack {
                            Label("Sync Transactions Now", systemImage: "arrow.triangle.2.circlepath")
                            Spacer()
                            if isSyncing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isSyncing)

                    Button {
                        showCSVPicker = true
                    } label: {
                        HStack {
                            Label("Import CSV", systemImage: "doc.badge.plus")
                            Spacer()
                            if isImporting {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isImporting)

                    if let syncResult {
                        Text(syncResult)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let importResult {
                        Text(importResult)
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
            .sheet(isPresented: $showConnectBank) {
                NavigationStack {
                    ConnectBankView(userId: appState.userId ?? UUID()) { _, _ in
                        showConnectBank = false
                    }
                    .navigationTitle("Connect Bank")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showConnectBank = false }
                        }
                    }
                }
            }
            .sheet(isPresented: $showGoalEditor) {
                GoalEditorSheet(
                    userId: appState.userId ?? UUID(),
                    isPresented: $showGoalEditor
                )
            }
            .fileImporter(
                isPresented: $showCSVPicker,
                allowedContentTypes: [.commaSeparatedText, .plainText, .data],
                allowsMultipleSelection: false
            ) { result in
                Task { await handleCSVImport(result) }
            }
        }
    }

    private func handleCSVImport(_ result: Result<[URL], Error>) {
        guard let userId = appState.userId else { return }

        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Read file data synchronously while we have security-scoped access
            let accessed = url.startAccessingSecurityScopedResource()
            let data: Data
            let filename = url.lastPathComponent
            do {
                data = try Data(contentsOf: url)
            } catch {
                if accessed { url.stopAccessingSecurityScopedResource() }
                importResult = "Import failed: \(error.localizedDescription)"
                return
            }
            if accessed { url.stopAccessingSecurityScopedResource() }

            // Now upload async
            isImporting = true
            importResult = nil

            Task {
                do {
                    let response = try await APIClient.shared.importCSV(
                        userId: userId,
                        csvData: data,
                        filename: filename
                    )
                    importResult = "\(response.transactionsImported) transactions imported"
                } catch {
                    importResult = "Import failed: \(error.localizedDescription)"
                }
                isImporting = false
            }

        case .failure(let error):
            importResult = "Could not select file: \(error.localizedDescription)"
        }
    }

    private func syncTransactions() async {
        guard let userId = appState.userId else { return }
        isSyncing = true
        syncResult = nil

        do {
            let result = try await APIClient.shared.syncTransactions(userId: userId)
            syncResult = "\(result.transactionsSynced) transactions synced"
        } catch {
            syncResult = "Sync failed: \(error.localizedDescription)"
        }
        isSyncing = false
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
