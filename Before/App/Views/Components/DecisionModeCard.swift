import SwiftUI

struct DecisionModeCard: View {
    let mode: DecisionMode
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: mode.symbolName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(BeforeTheme.ember)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 6) {
                    Text(mode.title)
                        .font(.headline)
                        .foregroundStyle(BeforeTheme.ink)
                    Text(mode.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.white.opacity(0.74))
            )
        }
        .buttonStyle(.plain)
    }
}
