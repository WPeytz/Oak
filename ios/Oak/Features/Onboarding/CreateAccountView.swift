import SwiftUI

struct CreateAccountView: View {
    let onCreated: (User) -> Void

    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var agreedToTerms = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title
            VStack(alignment: .leading, spacing: 4) {
                Text("Create account")
                    .font(.title.bold())
                    .foregroundStyle(Color(red: 0.15, green: 0.3, blue: 0.18))
                Text("start growing your financial tree")
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.3, green: 0.5, blue: 0.33))
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            // Form fields
            VStack(spacing: 20) {
                OnboardingField(label: "Full name", placeholder: "Enter your full name", text: $fullName)

                OnboardingField(label: "Email", placeholder: "Enter a valid email", text: $email, keyboardType: .emailAddress)

                OnboardingField(label: "Password", placeholder: "Create a password", text: $password, isSecure: true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)

            // Terms
            HStack(spacing: 10) {
                Button {
                    agreedToTerms.toggle()
                } label: {
                    Image(systemName: agreedToTerms ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(agreedToTerms
                            ? Color(red: 0.2, green: 0.5, blue: 0.25)
                            : .gray.opacity(0.4))
                }

                Text("Agree to the ") +
                Text("Terms of use").bold() +
                Text(" and ") +
                Text("Privacy Policy").bold()
            }
            .font(.caption)
            .foregroundStyle(Color(red: 0.3, green: 0.45, blue: 0.33))
            .padding(.horizontal, 24)
            .padding(.top, 20)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }

            Spacer()

            // Create button
            Button(action: createAccount) {
                Group {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Create Account")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isFormValid
                    ? Color(red: 0.22, green: 0.33, blue: 0.24)
                    : Color.gray.opacity(0.3))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!isFormValid || isLoading)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    private var isFormValid: Bool {
        !fullName.isEmpty && !email.isEmpty && !password.isEmpty && agreedToTerms
    }

    private func createAccount() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let user = try await APIClient.shared.createUser(
                    email: email, name: fullName
                )
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

// MARK: - Styled input field

struct OnboardingField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(red: 0.2, green: 0.45, blue: 0.25))

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                }
            }
            .padding()
            .background(.white.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
