import SwiftUI

struct GuidedInputCard: View {
    let title: String
    let subtitle: String?
    let placeholder: String
    @Binding var text: String

    init(
        title: String,
        subtitle: String? = nil,
        placeholder: String,
        text: Binding<String>
    ) {
        self.title = title
        self.subtitle = subtitle
        self.placeholder = placeholder
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
            }
        }
    }
}
