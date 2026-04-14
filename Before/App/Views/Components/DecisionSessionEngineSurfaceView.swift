import SwiftUI

struct DecisionSessionEngineSurfaceView: View {
    let presentation: DecisionSessionEnginePresentation
    let showsTitle: Bool
    let maxRecentSessions: Int
    let recoverButtonTitle: String
    let correctionButtonTitle: String
    let correctionPlaceholder: String
    let correctionReason: String

    init(
        presentation: DecisionSessionEnginePresentation,
        showsTitle: Bool = true,
        maxRecentSessions: Int = 2,
        recoverButtonTitle: String = "Recover line",
        correctionButtonTitle: String = "Create correction branch",
        correctionPlaceholder: String,
        correctionReason: String
    ) {
        self.presentation = presentation
        self.showsTitle = showsTitle
        self.maxRecentSessions = maxRecentSessions
        self.recoverButtonTitle = recoverButtonTitle
        self.correctionButtonTitle = correctionButtonTitle
        self.correctionPlaceholder = correctionPlaceholder
        self.correctionReason = correctionReason
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DecisionSessionEnginePanelView(
                presentation: presentation,
                showsTitle: showsTitle,
                maxRecentSessions: maxRecentSessions
            )

            DecisionSessionEngineActionBarView(
                sessionID: presentation.activeSession?.sessionID,
                recoverButtonTitle: recoverButtonTitle,
                canRecover: presentation.activeSession?.canRecover == true,
                correctionButtonTitle: correctionButtonTitle,
                correctionPlaceholder: correctionPlaceholder,
                correctionReason: correctionReason
            )
        }
    }
}
