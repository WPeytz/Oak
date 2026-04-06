import SwiftUI

struct SetNetGoalView: View {
    let userId: UUID
    let onComplete: () -> Void

    @State private var netGoalText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title
            VStack(alignment: .leading, spacing: 4) {
                Text("Set your goal")
                    .font(.title.bold())
                    .foregroundStyle(Color(red: 0.15, green: 0.3, blue: 0.18))
                Text("How much do you want to save each month?")
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.3, green: 0.5, blue: 0.33))
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            // Explanation
            VStack(alignment: .leading, spacing: 8) {
                Text("Your tree grows when you hit your goal")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(red: 0.2, green: 0.35, blue: 0.22))

                Text("Set a monthly net target — that's your income minus spending. If you reach it, your tree will be at full health.")
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.3, green: 0.5, blue: 0.33))
            }
            .padding(16)
            .background(.white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)
            .padding(.top, 20)

            // Input field
            VStack(alignment: .leading, spacing: 6) {
                Text("Monthly net goal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.2, green: 0.45, blue: 0.25))

                HStack {
                    TextField("e.g. 2000", text: $netGoalText)
                        .keyboardType(.numberPad)
                        .font(.title2.weight(.semibold))

                    Text("DKK")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.white.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)

            // Helper text
            if let goal = Double(netGoalText), goal > 0 {
                Text("If you earn 15.000 and spend 13.000, your net is 2.000")
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.3, green: 0.5, blue: 0.33))
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }

            Spacer()

            // Continue button
            Button(action: saveGoal) {
                Group {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Continue")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isValid
                    ? Color(red: 0.22, green: 0.33, blue: 0.24)
                    : Color.gray.opacity(0.3))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!isValid || isLoading)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    private var isValid: Bool {
        guard let goal = Double(netGoalText), goal != 0 else { return false }
        return true
    }

    private func saveGoal() {
        guard let netGoal = Double(netGoalText) else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                _ = try await APIClient.shared.upsertGoal(
                    userId: userId,
                    budget: 0,
                    savingsTarget: 0,
                    netGoal: netGoal
                )
                onComplete()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
