import SwiftUI

struct DecisionSystemFlightDeckSessionEngineView: View {
    let presentation: DecisionSessionEnginePresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Session Engine line")
                .font(.caption.weight(.semibold))
                .foregroundStyle(BeforeTheme.ember)

            DecisionSessionEnginePanelView(
                presentation: presentation,
                showsTitle: false,
                maxRecentSessions: 1
            )
        }
    }
}
