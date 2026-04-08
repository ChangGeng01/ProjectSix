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
                    Text("Not here to stop you.")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text("Before helps you see the now-perspective, the after-perspective, and one clean next move before you act.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                PanelCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("No shame.", systemImage: "face.smiling")
                        Label("No streaks.", systemImage: "line.3.horizontal.decrease.circle")
                        Label("No lecture.", systemImage: "quote.bubble")
                    }
                    .font(.headline)
                }

                Button(action: dismiss) {
                    Text("Start using Before")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(BeforeTheme.ink)
                        )
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(24)
        }
    }
}
