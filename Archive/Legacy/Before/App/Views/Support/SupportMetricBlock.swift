import SwiftUI

struct SupportMetricBlock: View {
    let title: String
    let count: Int
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(count)")
                .font(.title2.bold())
                .foregroundStyle(accent)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
