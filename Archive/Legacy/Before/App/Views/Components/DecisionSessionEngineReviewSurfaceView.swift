import SwiftUI

struct DecisionSessionEngineReviewSurfaceView: View {
    let items: [DecisionSessionEngineReviewItemPresentation]
    let pendingImportPreview: DecisionSessionEngineImportPreviewPresentation?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DecisionSessionEngineReviewDigestView(items: items)

            if let pendingImportPreview {
                DecisionSessionEnginePendingImportBlockView(
                    presentation: pendingImportPreview
                )
            }
        }
    }
}
