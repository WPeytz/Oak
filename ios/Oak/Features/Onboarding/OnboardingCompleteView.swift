import SwiftUI

struct OnboardingCompleteView: View {
    @EnvironmentObject var appState: AppState
    var syncedCount: Int = 0

    @State private var showCheckmark = false

    var body: some View {
        VStack(spacing: 0) {
            // Title
            VStack(alignment: .leading, spacing: 4) {
                Text("You're all set!")
                    .font(.title.bold())
                    .foregroundStyle(Color(red: 0.15, green: 0.3, blue: 0.18))
                Text("Your bank account has now connected")
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.3, green: 0.5, blue: 0.33))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Spacer()

            // Checkmark
            ZStack {
                Circle()
                    .stroke(Color(red: 0.2, green: 0.5, blue: 0.25), lineWidth: 3)
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark")
                    .font(.system(size: 50, weight: .semibold))
                    .foregroundStyle(Color(red: 0.2, green: 0.5, blue: 0.25))
                    .scaleEffect(showCheckmark ? 1.0 : 0.3)
                    .opacity(showCheckmark ? 1.0 : 0)
            }

            Spacer()

            // Stats card
            if syncedCount > 0 {
                VStack(spacing: 8) {
                    HStack {
                        Text("Transactions synced:")
                            .font(.subheadline)
                        Spacer()
                        Text("\(syncedCount)")
                            .font(.subheadline.bold())
                    }
                }
                .padding(20)
                .background(.white.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 32)
            }

            Spacer()

            // CTA button
            Button {
                appState.hasCompletedOnboarding = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .font(.body)
                    Text("Go to my Oak")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(red: 0.22, green: 0.33, blue: 0.24))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)

            Text("You can add more\nbank accounts later")
                .font(.caption)
                .foregroundStyle(Color(red: 0.3, green: 0.5, blue: 0.33))
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                .padding(.bottom, 40)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showCheckmark = true
            }
        }
    }
}
