import SwiftUI

struct DecisionSessionEnginePendingImportBlockView: View {
    let presentation: DecisionSessionEngineImportPreviewPresentation
    let showsSourceLine: Bool
    let showsIntegrityLine: Bool

    init(
        presentation: DecisionSessionEngineImportPreviewPresentation,
        showsSourceLine: Bool = false,
        showsIntegrityLine: Bool = false
    ) {
        self.presentation = presentation
        self.showsSourceLine = showsSourceLine
        self.showsIntegrityLine = showsIntegrityLine
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Pending import")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("Draft")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(BeforeTheme.ember)
            }

            DecisionSessionEngineImportPreviewDigestView(
                presentation: presentation,
                showsSourceLine: showsSourceLine,
                showsIntegrityLine: showsIntegrityLine
            )
        }
        .padding(.vertical, 2)
    }
}
