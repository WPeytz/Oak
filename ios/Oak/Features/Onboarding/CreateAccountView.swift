import SwiftUI

struct CreateAccountView: View {
    let onCreated: (User) -> Void

    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("Create your account")
                    .font(.title2.bold())
                Text("Enter your email to get started")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 16) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding()
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            Button(action: createAccount) {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Continue")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isValidEmail ? .green : .gray.opacity(0.3))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!isValidEmail || isLoading)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private var isValidEmail: Bool {
        let pattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
        return email.wholeMatch(of: pattern) != nil
    }

    private func createAccount() {
        guard isValidEmail else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let user = try await APIClient.shared.createUser(email: email)
                onCreated(user)
            } catch let error as APIError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    CreateAccountView { _ in }
}
