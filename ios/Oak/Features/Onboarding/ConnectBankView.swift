import SwiftUI
import UniformTypeIdentifiers

struct ConnectBankView: View {
    let userId: UUID
    let onComplete: (Int, Double?) -> Void

    @State private var institutions: [Institution] = []
    @State private var isLoadingInstitutions = true
    @State private var selectedInstitution: Institution?
    @State private var errorMessage: String?
    @State private var showCSVPicker = false
    @State private var isImporting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title
            VStack(alignment: .leading, spacing: 4) {
                Text("Connect Bank")
                    .font(.title.bold())
                    .foregroundStyle(Color(red: 0.15, green: 0.3, blue: 0.18))
                Text("Import your transactions via CSV")
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

            if isImporting {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Importing transactions from \(selectedInstitution?.name ?? "bank")...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
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
                        if isLoadingInstitutions {
                            ProgressView()
                                .padding(.vertical, 20)
                        } else {
                            ForEach(institutions) { inst in
                                Button {
                                    selectedInstitution = inst
                                    showCSVPicker = true
                                } label: {
                                    HStack(spacing: 14) {
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

            if !isImporting {
                Button("Skip for now") {
                    onComplete(0, nil)
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
        .fileImporter(
            isPresented: $showCSVPicker,
            allowedContentTypes: [.commaSeparatedText, .plainText, .data],
            allowsMultipleSelection: false
        ) { result in
            Task { await handleCSVImport(result) }
        }
    }

    // MARK: - CSV Import

    private func handleCSVImport(_ result: Result<[URL], Error>) async {
        guard case .success(let urls) = result,
              let url = urls.first else {
            errorMessage = "Could not read file"
            return
        }

        let accessed = url.startAccessingSecurityScopedResource()
        let data: Data
        let filename = url.lastPathComponent
        do {
            data = try Data(contentsOf: url)
        } catch {
            if accessed { url.stopAccessingSecurityScopedResource() }
            errorMessage = "Import failed: \(error.localizedDescription)"
            return
        }
        if accessed { url.stopAccessingSecurityScopedResource() }

        isImporting = true
        errorMessage = nil

        do {
            let response = try await APIClient.shared.importCSV(
                userId: userId,
                csvData: data,
                filename: filename
            )
            onComplete(response.transactionsImported, nil)
        } catch {
            errorMessage = "Import failed: \(error.localizedDescription)"
        }
        isImporting = false
    }

    private func loadInstitutions() async {
        do {
            institutions = try await APIClient.shared.listInstitutions()
        } catch {
            errorMessage = "Could not load banks"
        }
        isLoadingInstitutions = false
    }
}
