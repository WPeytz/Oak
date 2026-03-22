import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "leaf.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            VStack(spacing: 12) {
                Text("Welcome to Oak")
                    .font(.largeTitle.bold())

                Text("Watch your finances grow.\nConnect your bank and see your spending\ncome to life as a living tree.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            Button(action: onContinue) {
                Text("Get Started")
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
    }
}

#Preview {
    WelcomeView(onContinue: {})
}
