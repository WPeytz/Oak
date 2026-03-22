import SwiftUI

struct CreateAccountView: View {
    let onCreated: (User, Bool) -> Void  // (user, isExistingUser)

    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isLoginMode = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text(isLoginMode ? "Welcome back" : "Create your account")
                    .font(.title2.bold())
                Text(isLoginMode ? "Enter your email to sign in" : "Enter your email to get started")
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

            VStack(spacing: 12) {
                Button(action: submit) {
                    Group {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(isLoginMode ? "Sign In" : "Continue")
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

                Button {
                    isLoginMode.toggle()
                    errorMessage = nil
                } label: {
                    Text(isLoginMode ? "Don't have an account? Sign up" : "Already have an account? Sign in")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private var isValidEmail: Bool {
        let pattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
        return email.wholeMatch(of: pattern) != nil
    }

    private func submit() {
        guard isValidEmail else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let user: User
                if isLoginMode {
                    user = try await APIClient.shared.loginUser(email: email)
                } else {
                    user = try await APIClient.shared.createUser(email: email)
                }
                onCreated(user, isLoginMode)
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
    CreateAccountView { _, _ in }
}
