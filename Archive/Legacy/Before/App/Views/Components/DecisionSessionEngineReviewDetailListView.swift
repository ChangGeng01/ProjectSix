import SwiftUI

struct DecisionSessionEngineReviewDetailListView: View {
    let rows: [DecisionSessionEngineReviewDetailPresentation]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                VStack(alignment: .leading, spacing: 3) {
                    Text(row.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(row.value)
                        .font(.caption2)
                        .foregroundStyle(BeforeTheme.ink)
                }

                if index < rows.count - 1 {
                    Divider()
                }
            }
        }
    }
}
