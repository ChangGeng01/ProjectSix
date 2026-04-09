import SwiftUI

struct WatchPauseView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pause Flow")
                    .font(.headline)
                Text("Breathe once. Name the urge. Put it somewhere slower than your thumb.")
                    .font(.footnote)

                Button("Send A Pause To Before") {
                    WatchHandoffCoordinator.enqueue(
                        DecisionIntentEnvelope(
                            kind: .predictiveIntervention,
                            sourceSurface: .watch,
                            entrySource: .watch,
                            preferredMode: .mirror,
                            promptSeed: "Pause before acting",
                            riskLevel: .medium,
                            triggerReason: "A watch pause flow asked the iPhone brain to reopen this more slowly."
                        )
                    )
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Pause")
        }
    }
}
