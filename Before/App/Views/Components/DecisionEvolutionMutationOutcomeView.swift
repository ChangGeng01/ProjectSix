import SwiftUI

struct DecisionEvolutionMutationOutcomeView: View {
    let outcome: DecisionEvolutionMutationOutcome
    let onDismiss: (() -> Void)?

    init(
        outcome: DecisionEvolutionMutationOutcome,
        onDismiss: (() -> Void)? = nil
    ) {
        self.outcome = outcome
        self.onDismiss = onDismiss
    }

    private var tint: Color {
        if outcome.isSuccess {
            return outcome.isDestructive ? BeforeTheme.ember : BeforeTheme.moss
        }
        return .red
    }

    private var iconName: String {
        if outcome.isSuccess {
            return outcome.isDestructive ? "exclamationmark.shield.fill" : "checkmark.seal.fill"
        }
        return "xmark.octagon.fill"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Label(outcome.statusTitle, systemImage: iconName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)

                Spacer()

                if let onDismiss {
                    Button("Dismiss") {
                        onDismiss()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                }
            }

            Text(outcome.title)
                .font(.subheadline.bold())
                .foregroundStyle(BeforeTheme.ink)

            Text(outcome.message)
                .font(.caption)
                .foregroundStyle(.secondary)

            if !outcome.affectedCheckpointIDs.isEmpty {
                Text("Targets: \(outcome.affectedCheckpointIDs.joined(separator: " • "))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}
