import AuthenticationServices
import SwiftUI

struct ConnectBankView: View {
    let userId: UUID
    let onComplete: () -> Void

    @State private var institutions: [Institution] = []
    @State private var isLoadingInstitutions = true
    @State private var selectedInstitution: Institution?
    @State private var isConnecting = false
    @State private var connectionId: UUID?
    @State private var authorizationURL: URL?
    @State private var isPolling = false
    @State private var connectionStatus: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Connect your bank")
                    .font(.title2.bold())
                Text("Select your bank to securely link\nyour account via Open Banking")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            if isPolling {
                pollingView
            } else if isLoadingInstitutions {
                Spacer()
                ProgressView("Loading banks...")
                Spacer()
            } else {
                institutionList
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }

            // Skip button
            if !isPolling {
                Button("Skip for now", action: onComplete)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 32)
            }
        }
        .task {
            await loadInstitutions()
        }
        .sheet(item: $authorizationURL) { url in
            BankAuthView(url: url) { callbackURL in
                authorizationURL = nil
                handleBankCallback(callbackURL)
            }
        }
    }

    // MARK: - Subviews

    private var institutionList: some View {
        List(institutions) { institution in
            Button {
                selectInstitution(institution)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "building.columns")
                        .font(.title3)
                        .foregroundStyle(.green)
                        .frame(width: 40, height: 40)
                        .background(.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(institution.name)
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text(institution.id)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    if isConnecting && selectedInstitution?.id == institution.id {
                        ProgressView()
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .disabled(isConnecting)
        }
        .listStyle(.plain)
    }

    private var pollingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            VStack(spacing: 8) {
                Text("Connecting...")
                    .font(.headline)

                Text(connectionStatusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
    }

    private var connectionStatusMessage: String {
        switch connectionStatus {
        case "linked":
            return "Your bank account is connected!"
        case "expired", "revoked":
            return "Connection failed. Please try again."
        default:
            return "Waiting for bank authorization...\nThis may take a moment."
        }
    }

    // MARK: - Actions

    private func loadInstitutions() async {
        do {
            institutions = try await APIClient.shared.listInstitutions()
            isLoadingInstitutions = false
        } catch {
            errorMessage = "Could not load banks: \(error.localizedDescription)"
            isLoadingInstitutions = false
        }
    }

    private func selectInstitution(_ institution: Institution) {
        selectedInstitution = institution
        isConnecting = true
        errorMessage = nil

        Task {
            do {
                let connection = try await APIClient.shared.createConnection(
                    userId: userId,
                    institutionId: institution.id
                )

                connectionId = connection.id

                if connection.status == "linked" {
                    // Sandbox: already linked, skip auth
                    onComplete()
                } else if let urlString = connection.authorizationUrl,
                          let url = URL(string: urlString) {
                    // Live: open Tink Link bank auth page
                    // After auth, Tink redirects to our backend callback,
                    // which then redirects to oak://bank-callback
                    authorizationURL = url
                } else {
                    // No auth URL — start polling
                    startPolling(connectionId: connection.id)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isConnecting = false
        }
    }

    private func handleBankCallback(_ callbackURL: URL?) {
        guard let callbackURL,
              let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            // User cancelled or no callback — start polling if we have a connection
            if let connectionId {
                startPolling(connectionId: connectionId)
            }
            return
        }

        let params = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? [])
                .compactMap { item in item.value.map { (item.name, $0) } }
        )

        let status = params["status"]
        let callbackConnectionId = params["connection_id"].flatMap(UUID.init)

        if status == "success" {
            onComplete()
        } else if status == "expired" || status == "revoked" || status == "error" {
            errorMessage = "Bank connection failed. Please try again."
        } else {
            // pending or unknown — poll
            startPolling(connectionId: callbackConnectionId ?? connectionId ?? UUID())
        }
    }

    private func startPolling(connectionId: UUID) {
        isPolling = true

        Task {
            for _ in 0..<30 {
                do {
                    let status = try await APIClient.shared.pollConnectionStatus(
                        userId: userId,
                        connectionId: connectionId
                    )
                    connectionStatus = status.status

                    if status.status == "linked" {
                        try? await Task.sleep(for: .seconds(1))
                        onComplete()
                        return
                    } else if status.status == "expired" || status.status == "revoked" {
                        errorMessage = "Bank connection failed. Please try again."
                        isPolling = false
                        return
                    }
                } catch {
                    // Continue polling on network errors
                }

                try? await Task.sleep(for: .seconds(2))
            }

            errorMessage = "Connection timed out. Please try again."
            isPolling = false
        }
    }
}

// MARK: - URL Identifiable conformance for sheet

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
