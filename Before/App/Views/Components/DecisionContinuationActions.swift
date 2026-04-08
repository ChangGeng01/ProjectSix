import SwiftUI

struct DecisionContinuationActions: View {
    let reopenTitle: String
    let reopenStyle: BeforeActionButton.Style
    let postponeTitle: String
    let postponeStyle: BeforeActionButton.Style
    let reopenAction: () -> Void
    let postponeAction: () -> Void

    init(
        reopenTitle: String,
        reopenStyle: BeforeActionButton.Style = .primary,
        postponeTitle: String = "Move this to Tomorrow Box",
        postponeStyle: BeforeActionButton.Style = .secondary,
        reopenAction: @escaping () -> Void,
        postponeAction: @escaping () -> Void
    ) {
        self.reopenTitle = reopenTitle
        self.reopenStyle = reopenStyle
        self.postponeTitle = postponeTitle
        self.postponeStyle = postponeStyle
        self.reopenAction = reopenAction
        self.postponeAction = postponeAction
    }

    var body: some View {
        VStack(spacing: 12) {
            BeforeActionButton(reopenTitle, style: reopenStyle) {
                reopenAction()
            }

            BeforeActionButton(postponeTitle, style: postponeStyle) {
                postponeAction()
            }
        }
    }
}
