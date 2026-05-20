import SwiftUI

struct DecisionRoutePreviewCard: View {
    let mode: DecisionMode
    let title: String
    let detail: String
    let isPinned: Bool

    var body: some View {
        PanelCard {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: mode.symbolName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(BeforeTheme.ember)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 6) {
                    Text(isPinned ? "HOME PROMPT DEFAULT" : "ROUTE PREVIEW")
                        .font(.caption.weight(.semibold))
                        .tracking(1.1)
                        .foregroundStyle(BeforeTheme.ember)

                    Text(title)
                        .font(.headline)
                        .foregroundStyle(BeforeTheme.ink)

                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
        }
    }
}
