import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case createAccount
    case setGoals
    case connectBank
    case complete
}

struct OnboardingFlow: View {
    @EnvironmentObject var appState: AppState
    @State private var step: OnboardingStep = .welcome
    @State private var createdUser: User?
    @State private var goalSet = false

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .welcome:
                    WelcomeView(onContinue: { step = .createAccount })

                case .createAccount:
                    CreateAccountView { user in
                        createdUser = user
                        appState.setUser(user)
                        step = .setGoals
                    }

                case .setGoals:
                    SetGoalsView(userId: createdUser!.id) {
                        goalSet = true
                        step = .connectBank
                    }

                case .connectBank:
                    ConnectBankView(userId: createdUser!.id) {
                        step = .complete
                    }

                case .complete:
                    OnboardingCompleteView()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: step)
        }
    }
}
