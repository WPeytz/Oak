import AuthenticationServices
import SwiftUI

struct ConnectBankView: View {
    let userId: UUID
    let onComplete: () -> Void

    @State private var institutions: [Institution] = []
    @State private var isLoadingInstitutions = true
    @State private var isConnecting = false
    @State private var selectedInstitution: Institution?
    @State private var connectionId: UUID?
    @State private var authorizationURL: URL?
    @State private var isPolling = false
    @State private var connectionStatus: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title
            VStack(alignment: .leading, spacing: 4) {
                Text("Connect Bank")
                    .font(.title.bold())
                    .foregroundStyle(Color(red: 0.15, green: 0.3, blue: 0.18))
                Text("Read-only | Secured by MitID")
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.3, green: 0.5, blue: 0.33))
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            // Security card
            HStack(spacing: 14) {
                Image(systemName: "shield.checkered")
                    .font(.title2)
                    .foregroundStyle(Color(red: 0.2, green: 0.5, blue: 0.25))

                VStack(alignment: .leading, spacing: 2) {
                    (Text("Oak ").font(.subheadline) +
                     Text("never sees").font(.subheadline).bold() +
                     Text(" your login credentials. Your banks handles all ").font(.subheadline) +
                     Text("authentication.").font(.subheadline).bold())
                    .foregroundStyle(Color(red: 0.2, green: 0.35, blue: 0.22))
                }
            }
            .padding(16)
            .background(.white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)
            .padding(.top, 20)

            // Bank list
            if isConnecting {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Connecting to \(selectedInstitution?.name ?? "bank")...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else if isPolling {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Waiting for authorization...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else if isLoadingInstitutions {
                Spacer()
                HStack { Spacer(); ProgressView(); Spacer() }
                Spacer()
            } else {
                Text("Select your Bank")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color(red: 0.3, green: 0.5, blue: 0.33))
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 8)

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(institutions) { inst in
                            Button {
                                selectInstitution(inst)
                            } label: {
                                HStack(spacing: 14) {
                                    // Bank icon placeholder
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(red: 0.2, green: 0.35, blue: 0.5).opacity(0.15))
                                        .frame(width: 44, height: 44)
                                        .overlay {
                                            Text(String(inst.name.prefix(2)))
                                                .font(.caption.bold())
                                                .foregroundStyle(Color(red: 0.2, green: 0.35, blue: 0.5))
                                        }

                                    Text(inst.name)
                                        .font(.body)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(.white.opacity(0.7))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }

            // Skip
            if !isConnecting && !isPolling {
                Button("Skip for now") {
                    onComplete()
                }
                .font(.subheadline)
                .foregroundStyle(Color(red: 0.3, green: 0.5, blue: 0.33))
                .frame(maxWidth: .infinity)
                .padding(.bottom, 32)
                .padding(.top, 12)
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

    // MARK: - Actions

    private func loadInstitutions() async {
        do {
            institutions = try await APIClient.shared.listInstitutions()
        } catch {
            errorMessage = "Could not load banks"
        }
        isLoadingInstitutions = false
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
                    _ = try? await APIClient.shared.syncTransactions(userId: userId)
                    onComplete()
                } else if let urlString = connection.authorizationUrl,
                          let url = URL(string: urlString) {
                    authorizationURL = url
                } else {
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
            if let connectionId { startPolling(connectionId: connectionId) }
            return
        }

        let params = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? [])
                .compactMap { item in item.value.map { (item.name, $0) } }
        )

        if params["status"] == "success" {
            onComplete()
        } else if params["status"] == "expired" || params["status"] == "revoked" {
            errorMessage = "Bank connection failed. Please try again."
        } else {
            let id = params["connection_id"].flatMap(UUID.init) ?? connectionId ?? UUID()
            startPolling(connectionId: id)
        }
    }

    private func startPolling(connectionId: UUID) {
        isPolling = true
        Task {
            for _ in 0..<30 {
                do {
                    let status = try await APIClient.shared.pollConnectionStatus(
                        userId: userId, connectionId: connectionId
                    )
                    connectionStatus = status.status
                    if status.status == "linked" {
                        _ = try? await APIClient.shared.syncTransactions(userId: userId)
                        onComplete()
                        return
                    } else if status.status == "expired" || status.status == "revoked" {
                        errorMessage = "Connection failed. Please try again."
                        isPolling = false
                        return
                    }
                } catch {}
                try? await Task.sleep(for: .seconds(2))
            }
            errorMessage = "Connection timed out."
            isPolling = false
        }
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
