import SwiftUI

struct WelcomeView: View {
    let onSignUp: () -> Void
    let onSignIn: (User) -> Void

    @State private var showLogin = false
    @State private var loginEmail = ""
    @State private var loginPassword = ""
    @State private var isLoggingIn = false
    @State private var loginError: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Voxel tree
            VoxelTreeView(healthPercentage: 0.9)
                .frame(width: 220, height: 280)
                .padding(.bottom, 20)

            // Tagline
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Text("Your money,")
                        .font(.system(size: 28, weight: .bold))
                    Text("growing")
                        .font(.system(size: 28, weight: .medium, design: .serif))
                        .italic()
                }
                .foregroundStyle(Color(red: 0.15, green: 0.3, blue: 0.18))

                Text("like an Oak")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color(red: 0.15, green: 0.3, blue: 0.18))
            }
            .padding(.bottom, 40)

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                Button(action: onSignUp) {
                    Text("Sign up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(red: 0.22, green: 0.33, blue: 0.24))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    showLogin = true
                } label: {
                    Text("Sign in")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white.opacity(0.8))
                        .foregroundStyle(Color(red: 0.22, green: 0.33, blue: 0.24))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .sheet(isPresented: $showLogin) {
            loginSheet
        }
    }

    private var loginSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Text("Welcome back")
                    .font(.title2.bold())
                    .foregroundStyle(Color(red: 0.15, green: 0.3, blue: 0.18))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Email")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(red: 0.2, green: 0.45, blue: 0.25))
                    TextField("Enter your email", text: $loginEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 32)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Password")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(red: 0.2, green: 0.45, blue: 0.25))
                    SecureField("Enter your password", text: $loginPassword)
                        .textContentType(.password)
                        .padding()
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 32)

                if let loginError {
                    Text(loginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()

                Button {
                    Task { await login() }
                } label: {
                    Group {
                        if isLoggingIn {
                            ProgressView().tint(.white)
                        } else {
                            Text("Sign in")
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(red: 0.22, green: 0.33, blue: 0.24))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(loginEmail.isEmpty || loginPassword.isEmpty || isLoggingIn)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.75, green: 0.92, blue: 0.78),
                        Color(red: 0.92, green: 0.98, blue: 0.93),
                    ],
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showLogin = false }
                }
            }
        }
    }

    private func login() async {
        isLoggingIn = true
        loginError = nil
        do {
            let user = try await APIClient.shared.loginUser(
                email: loginEmail, password: loginPassword
            )
            showLogin = false
            onSignIn(user)
        } catch {
            loginError = error.localizedDescription
        }
        isLoggingIn = false
    }
}
