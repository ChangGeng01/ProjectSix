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
        switch outcome.presentation.tone {
        case .success:
            BeforeTheme.moss
        case .caution:
            BeforeTheme.ember
        case .failure:
            .red
        }
    }

    var body: some View {
        let presentation = outcome.presentation

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Label(presentation.statusTitle, systemImage: presentation.iconName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)

                Spacer()

                if let onDismiss {
                    Button(presentation.dismissTitle) {
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

            if let targetsLine = presentation.targetsLine(outcome.affectedCheckpointIDs) {
                Text(targetsLine)
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
