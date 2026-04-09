import SwiftUI

struct WatchBrainGlanceView: View {
    private var snapshot: WidgetSnapshot {
        WidgetSnapshotStore.load()
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                Text("Brain Glance")
                    .font(.headline)
                Text(snapshot.messageHeadline)
                    .font(.subheadline.bold())
                Text(snapshot.messageBody)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Updated \(snapshot.updatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Glance")
        }
    }
}
