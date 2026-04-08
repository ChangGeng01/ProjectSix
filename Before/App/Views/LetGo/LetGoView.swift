import SwiftUI
import UIKit

struct LetGoView: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @StateObject private var motionMonitor = LetGoMotionMonitor()

    let context: LetGoContext

    @State private var phase: Phase = .ready
    @State private var cardOffset: CGFloat = 0
    @State private var cardRotation: Double = 0
    @State private var cardOpacity = 1.0
    @State private var cardScale: CGFloat = 1

    var body: some View {
        ZStack {
            BeforeBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SectionHeader(
                        eyebrow: context.eyebrow,
                        title: phase == .settled ? context.completionTitle : context.title,
                        subtitle: phase == .settled ? context.completionSubtitle : context.subtitle
                    )

                    if phase == .ready {
                        releaseCard
                        instructionCard
                        actionButtons
                    } else {
                        settledCard
                        settledActions
                    }
                }
                .padding(20)
            }
        }
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(phase == .ready)
        .onAppear {
            motionMonitor.start { direction in
                triggerRelease(direction: direction)
            }
        }
        .onDisappear {
            motionMonitor.stop()
        }
    }

    private var releaseCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    Label(context.mode.shortTitle, systemImage: context.mode.symbolName)
                        .font(.headline)
                        .foregroundStyle(BeforeTheme.ink)
                    Spacer()
                    Text("Moved")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BeforeTheme.ember)
                }

                Text(context.itemTitle)
                    .font(.title3.bold())
                    .foregroundStyle(BeforeTheme.ink)

                Text(context.itemDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .offset(x: cardOffset)
        .rotationEffect(.degrees(cardRotation))
        .opacity(cardOpacity)
        .scaleEffect(cardScale)
    }

    private var instructionCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 10) {
                Label(context.instructionTitle, systemImage: "iphone.radiowaves.left.and.right")
                    .font(.headline)
                    .foregroundStyle(BeforeTheme.ember)

                Text(
                    motionMonitor.isAvailable
                    ? context.instructionDetail
                    : "Motion is not available here, so you can finish the handoff with the button below instead."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            BeforeActionButton("Put it down without motion", style: .secondary) {
                finishWithoutMotion()
            }

            BeforeActionButton("Skip for now", style: .tertiary) {
                appModel.dismissLetGo(to: context.primaryTarget)
            }
        }
    }

    private var settledCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Out of the foreground", systemImage: "tray.and.arrow.down.fill")
                    .font(.headline)
                    .foregroundStyle(BeforeTheme.moss)

                Text("You can leave this in Tomorrow Box and come back when timing is cleaner.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var settledActions: some View {
        VStack(spacing: 12) {
            BeforeActionButton(context.primaryActionTitle) {
                appModel.dismissLetGo(to: context.primaryTarget)
            }

            if let secondaryTitle = context.secondaryActionTitle,
               let secondaryTarget = context.secondaryTarget {
                BeforeActionButton(secondaryTitle, style: .secondary) {
                    appModel.dismissLetGo(to: secondaryTarget)
                }
            }
        }
    }

    private func triggerRelease(direction: LetGoFlickDirection) {
        guard phase == .ready else { return }

        phase = .releasing
        let sign: CGFloat = direction == .right ? 1 : -1
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        withAnimation(.easeInOut(duration: BeforePolicy.LetGo.releaseAnimationDuration)) {
            cardOffset = sign * BeforePolicy.LetGo.releaseTravelDistance
            cardRotation = sign * BeforePolicy.LetGo.releaseRotationDegrees
            cardOpacity = 0
            cardScale = 0.92
        }

        Task {
            try? await Task.sleep(nanoseconds: UInt64(BeforePolicy.LetGo.releaseAnimationDuration * 1_000_000_000))
            await MainActor.run {
                phase = .settled
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    private func finishWithoutMotion() {
        guard phase == .ready else { return }

        withAnimation(.easeInOut(duration: BeforePolicy.LetGo.completionTransitionDuration)) {
            cardOpacity = 0
            cardScale = 0.96
        }

        Task {
            try? await Task.sleep(nanoseconds: UInt64(BeforePolicy.LetGo.completionTransitionDuration * 1_000_000_000))
            await MainActor.run {
                phase = .settled
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }
}

private extension LetGoView {
    enum Phase {
        case ready
        case releasing
        case settled
    }
}
