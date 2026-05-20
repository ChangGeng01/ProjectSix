import SwiftUI

struct DecisionSessionEngineControlMergeReviewCard: View {
    let review: DecisionSessionEngineControlMergeReview
    let actionTitle: String
    let onAction: () -> Void

    private var presentation: DecisionSessionEngineMergeReviewPresentation {
        DecisionSessionEngineMergeReviewPresentation.build(from: review)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(presentation.title)
                .font(.subheadline.weight(.semibold))

            Text(presentation.routeLine)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BeforeTheme.ember)

            DecisionSessionEngineReviewDetailListView(rows: presentation.detailRows)

            DecisionSessionEngineHealthSummaryView(summary: presentation.summary)

            BeforeActionButton(actionTitle, style: .primary) {
                onAction()
            }
        }
    }
}
