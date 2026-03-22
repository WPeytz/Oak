import SwiftUI

struct ActionsCard: View {
    let actions: [ActionRecommendation]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Recommendations", systemImage: "lightbulb")
                .font(.headline)

            ForEach(actions) { action in
                ActionRow(action: action)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct ActionRow: View {
    let action: ActionRecommendation

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: action.icon)
                .font(.body)
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(action.title)
                    .font(.subheadline.weight(.semibold))

                Text(action.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }

    private var iconColor: Color {
        switch action.priority {
        case 1: return .red
        case 2: return .orange
        default: return .green
        }
    }
}

#Preview {
    ActionsCard(actions: [
        ActionRecommendation(
            icon: "exclamationmark.triangle",
            title: "Over budget",
            description: "You've exceeded your budget by 500 DKK. Try to avoid non-essential purchases.",
            priority: 1
        ),
        ActionRecommendation(
            icon: "arrow.triangle.2.circlepath",
            title: "Frequent Shopping spending",
            description: "You've spent 4,599 DKK on Shopping across 3 transactions this month.",
            priority: 2
        ),
        ActionRecommendation(
            icon: "star.fill",
            title: "Savings goal met!",
            description: "You've reached your monthly savings target. Well done!",
            priority: 3
        ),
    ])
    .padding()
}
