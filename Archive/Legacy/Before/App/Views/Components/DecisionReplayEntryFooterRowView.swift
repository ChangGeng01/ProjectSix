import SwiftUI

struct DecisionReplayEntryFooterRowView: View {
    let timestamp: Date?
    let accentText: String?
    let accentColor: Color

    init(
        timestamp: Date? = nil,
        accentText: String? = nil,
        accentColor: Color = BeforeTheme.moss
    ) {
        self.timestamp = timestamp
        self.accentText = accentText
        self.accentColor = accentColor
    }

    var body: some View {
        HStack {
            if let timestamp {
                Text(timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let accentText, !accentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(accentText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(accentColor)
            }
        }
    }
}
