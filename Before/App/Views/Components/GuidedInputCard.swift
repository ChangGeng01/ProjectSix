import SwiftUI

struct GuidedInputCard: View {
    let title: String
    let subtitle: String?
    let placeholder: String
    let suggestions: [String]
    @Binding var text: String

    init(
        title: String,
        subtitle: String? = nil,
        placeholder: String,
        suggestions: [String] = [],
        text: Binding<String>
    ) {
        self.title = title
        self.subtitle = subtitle
        self.placeholder = placeholder
        self.suggestions = suggestions
        _text = text
    }

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                TextField(placeholder, text: $text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...5)

                if trimmedText.isEmpty, !suggestions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(suggestions, id: \.self) { suggestion in
                                Button {
                                    text = suggestion
                                } label: {
                                    Text(suggestion)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(BeforeTheme.ink)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
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
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
