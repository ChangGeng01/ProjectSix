import SwiftUI

struct BeforeActionButton: View {
    enum Style {
        case primary
        case secondary
        case tertiary
    }

    let title: String
    let style: Style
    let isEnabled: Bool
    let accessibilityIdentifier: String?
    let action: () -> Void

    init(
        _ title: String,
        style: Style = .primary,
        isEnabled: Bool = true,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.isEnabled = isEnabled
        self.accessibilityIdentifier = accessibilityIdentifier
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
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.58)
        .buttonStyle(.plain)
        .beforeAccessibilityIdentifier(accessibilityIdentifier)
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
                .fill(isEnabled ? BeforeTheme.ink : Color.gray)
        case .secondary:
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(isEnabled ? 0.74 : 0.5))
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
