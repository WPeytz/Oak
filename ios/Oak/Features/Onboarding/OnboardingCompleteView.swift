import SwiftUI

struct OnboardingCompleteView: View {
    @EnvironmentObject var appState: AppState

    @State private var showCheckmark = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.green.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                    .scaleEffect(showCheckmark ? 1.0 : 0.5)
                    .opacity(showCheckmark ? 1.0 : 0.0)
            }

            VStack(spacing: 12) {
                Text("You're all set!")
                    .font(.title.bold())

                Text("Your Oak tree is ready to grow.\nKeep an eye on it to track your\nfinancial health.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button {
                appState.hasCompletedOnboarding = true
            } label: {
                Text("Start using Oak")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showCheckmark = true
            }
        }
    }
}

#Preview {
    OnboardingCompleteView()
        .environmentObject(AppState())
}
