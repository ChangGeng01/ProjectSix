import SwiftUI

struct DecisionReplayEntryHeaderRowView: View {
    enum TimestampStyle {
        case relative
        case absoluteShort
    }

    enum AccentStyle {
        case pill
        case text(Color)
    }

    let labelTitle: String?
    let labelSymbolName: String?
    let leadingText: String?
    let secondaryText: String?
    let trailingAccentText: String?
    let trailingAccentStyle: AccentStyle?
    let trailingTimestamp: Date?
    let trailingTimestampStyle: TimestampStyle?

    init(
        labelTitle: String? = nil,
        labelSymbolName: String? = nil,
        leadingText: String? = nil,
        secondaryText: String? = nil,
        trailingAccentText: String? = nil,
        trailingAccentStyle: AccentStyle? = nil,
        trailingTimestamp: Date? = nil,
        trailingTimestampStyle: TimestampStyle? = nil
    ) {
        self.labelTitle = labelTitle
        self.labelSymbolName = labelSymbolName
        self.leadingText = leadingText
        self.secondaryText = secondaryText
        self.trailingAccentText = trailingAccentText
        self.trailingAccentStyle = trailingAccentStyle
        self.trailingTimestamp = trailingTimestamp
        self.trailingTimestampStyle = trailingTimestampStyle
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let labelTitle, let labelSymbolName {
                Label(labelTitle, systemImage: labelSymbolName)
            } else if let leadingText, !leadingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(leadingText)
            }

            if let secondaryText, !secondaryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(secondaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let trailingTimestamp, let trailingTimestampStyle {
                switch trailingTimestampStyle {
                case .relative:
                    Text(trailingTimestamp, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .absoluteShort:
                    Text(trailingTimestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let trailingAccentText, !trailingAccentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                switch trailingAccentStyle ?? .text(BeforeTheme.moss) {
                case .pill:
                    Text(trailingAccentText)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(BeforeTheme.ember.opacity(0.18))
                        )
                case .text(let color):
                    Text(trailingAccentText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color)
                }
            }
        }
    }
}
