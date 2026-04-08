import SwiftUI

struct BeforeActionButton: View {
    enum Style {
        case primary
        case secondary
        case tertiary
    }

    let title: String
    let style: Style
    let action: () -> Void

    init(
        _ title: String,
        style: Style = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(foregroundStyle)
                .frame(maxWidth: .infinity)
                .padding(.vertical, verticalPadding)
                .background(backgroundView)
        }
        .buttonStyle(.plain)
    }

    private var foregroundStyle: Color {
        switch style {
        case .primary:
            .white
        case .secondary, .tertiary:
            BeforeTheme.ink
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(BeforeTheme.ink)
        case .secondary:
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.74))
        case .tertiary:
            Color.clear
        }
    }

    private var verticalPadding: CGFloat {
        switch style {
        case .primary, .secondary:
            18
        case .tertiary:
            6
        }
    }
}
