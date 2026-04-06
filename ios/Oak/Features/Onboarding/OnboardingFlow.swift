import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case createAccount
    case setGoal
    case connectBank
    case complete
}

struct OnboardingFlow: View {
    @EnvironmentObject var appState: AppState
    @State private var step: OnboardingStep = .welcome
    @State private var createdUser: User?
    @State private var syncedCount: Int = 0
    @State private var accountBalance: Double?

    var body: some View {
        ZStack {
            // Shared green gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.75, green: 0.92, blue: 0.78),
                    Color(red: 0.85, green: 0.96, blue: 0.87),
                    Color(red: 0.92, green: 0.98, blue: 0.93),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress header (not on welcome)
                if step != .welcome {
                    OnboardingHeader(
                        currentStep: progressStep,
                        totalSteps: 4,
                        onBack: {
                            withAnimation {
                                switch step {
                                case .createAccount: step = .welcome
                                case .setGoal: step = .createAccount
                                case .connectBank: step = .setGoal
                                default: break
                                }
                            }
                        }
                    )
                    .padding(.top, 8)
                }

                // Content
                Group {
                    switch step {
                    case .welcome:
                        WelcomeView(
                            onSignUp: { withAnimation { step = .createAccount } },
                            onSignIn: { user in
                                createdUser = user
                                appState.setUser(user)
                                appState.hasCompletedOnboarding = true
                            }
                        )

                    case .createAccount:
                        CreateAccountView { user in
                            createdUser = user
                            appState.setUser(user)
                            withAnimation { step = .setGoal }
                        }

                    case .setGoal:
                        SetNetGoalView(userId: createdUser!.id) {
                            withAnimation { step = .connectBank }
                        }

                    case .connectBank:
                        ConnectBankView(userId: createdUser!.id) { count, balance in
                            syncedCount = count
                            accountBalance = balance
                            withAnimation { step = .complete }
                        }

                    case .complete:
                        OnboardingCompleteView(syncedCount: syncedCount, accountBalance: accountBalance)
                    }
                }
            }
        }
        .environment(\.colorScheme, .light)
    }

    /// Maps the step enum to a 1-based progress number (excluding welcome)
    private var progressStep: Int {
        switch step {
        case .welcome: return 0
        case .createAccount: return 1
        case .setGoal: return 2
        case .connectBank: return 3
        case .complete: return 4
        }
    }
}

// MARK: - Progress header

struct OnboardingHeader: View {
    let currentStep: Int
    let totalSteps: Int
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color(red: 0.2, green: 0.4, blue: 0.22))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.25))

                    Capsule()
                        .fill(Color(red: 0.2, green: 0.5, blue: 0.25))
                        .frame(width: geo.size.width * CGFloat(currentStep) / CGFloat(totalSteps))
                }
            }
            .frame(height: 8)

            Text("\(currentStep)/\(totalSteps)")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color(red: 0.3, green: 0.5, blue: 0.33))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}
