import SwiftUI

struct DecisionSessionEngineResultActionsCard: View {
    let sessionID: String?
    let headline: String
    let detail: String
    let correctionTitle: String
    let correctionPlaceholder: String
    let correctionReason: String

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(headline)
                    .font(.headline)
                    .foregroundStyle(BeforeTheme.ink)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let sessionID {
                    VStack(spacing: 12) {
                        DecisionSessionEngineActionBarView(
                            sessionID: sessionID,
                            openButtonTitle: "Open Session Engine",
                            importButtonTitle: "Import bundle",
                            exportButtonTitle: "Export recovery line",
                            correctionButtonTitle: correctionTitle,
                            correctionPlaceholder: correctionPlaceholder,
                            correctionReason: correctionReason
                        )
                    }
                } else {
                    Text("This result has not been bound to a Session Engine recovery line yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
