import SwiftUI

struct OnboardingView: View {
    let dismiss: () -> Void

    var body: some View {
        ZStack {
            BeforeBackground()

            VStack(alignment: .leading, spacing: 28) {
                Spacer()

                Text("Before")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(BeforeTheme.ink)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Not here to run your life.")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text("Quick calls get a stoplight. Trade-offs get a balance board. Heavier questions get a mirror.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                PanelCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("No shame.", systemImage: "face.smiling")
                        Label("No forced verdicts on heavy questions.", systemImage: "square.split.2x1")
                        Label("No lecture.", systemImage: "quote.bubble")
                    }
                    .font(.headline)
                }

                BeforeActionButton("Start using Before") {
                    dismiss()
                }

                Spacer()
            }
            .padding(24)
        }
    }
}
