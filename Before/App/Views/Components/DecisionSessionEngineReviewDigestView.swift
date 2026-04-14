import SwiftUI

struct DecisionSessionEngineReviewDigestView: View {
    let items: [DecisionSessionEngineReviewItemPresentation]

    var body: some View {
        if items.isEmpty == false {
            VStack(alignment: .leading, spacing: 8) {
                Text("Review digest")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(item.severity == .critical ? BeforeTheme.ember : BeforeTheme.ink)

                        Text(item.detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
