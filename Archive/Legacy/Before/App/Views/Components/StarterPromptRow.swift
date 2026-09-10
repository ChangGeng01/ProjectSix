import SwiftUI

struct StarterPromptRow: View {
    let title: String
    let suggestions: [DecisionStarterPrompt]
    let action: (DecisionStarterPrompt) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(BeforeTheme.ink)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(suggestions) { suggestion in
                        Button {
                            action(suggestion)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: suggestion.mode.symbolName)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(BeforeTheme.ember)

                                Text(suggestion.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(BeforeTheme.ink)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(.white.opacity(0.72))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}
