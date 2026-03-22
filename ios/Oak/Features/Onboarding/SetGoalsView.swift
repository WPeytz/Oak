import SwiftUI

struct SetGoalsView: View {
    let userId: UUID
    let onComplete: () -> Void

    @State private var budgetText = ""
    @State private var savingsText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("Set your goals")
                    .font(.title2.bold())
                Text("How much do you want to spend\nand save each month?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                GoalInputField(
                    label: "Monthly discretionary budget",
                    placeholder: "e.g. 5000",
                    text: $budgetText
                )

                GoalInputField(
                    label: "Monthly savings target",
                    placeholder: "e.g. 2000",
                    text: $savingsText
                )

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 12) {
                Button(action: saveGoals) {
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
                    .background(isValid ? .green : .gray.opacity(0.3))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!isValid || isLoading)

                Button("Skip for now", action: onComplete)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private var isValid: Bool {
        guard let budget = Double(budgetText), budget > 0 else { return false }
        guard let savings = Double(savingsText), savings >= 0 else { return false }
        return true
    }

    private func saveGoals() {
        guard let budget = Double(budgetText),
              let savings = Double(savingsText) else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                _ = try await APIClient.shared.upsertGoal(
                    userId: userId,
                    budget: budget,
                    savingsTarget: savings
                )
                onComplete()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

private struct GoalInputField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("DKK")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField(placeholder, text: $text)
                    .keyboardType(.numberPad)
            }
            .padding()
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    SetGoalsView(userId: UUID(), onComplete: {})
}
