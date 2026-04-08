import SwiftUI

struct WaitView: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session: QuickCheckSession
    @State private var secondsRemaining = 0
    @State private var timerActive = true
    @State private var reminderText: String?

    var body: some View {
        ZStack {
            BeforeBackground()

            VStack(alignment: .leading, spacing: 24) {
                Spacer()

                Text("Let the urge breathe.")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("You are not saying no forever. Just not from peak blur.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                PanelCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(countdownText)
                            .font(.system(size: 56, weight: .black, design: .rounded))
                            .foregroundStyle(BeforeTheme.ink)

                        if let reminderText {
                            Text("“\(reminderText)”")
                                .font(.headline)
                        } else {
                            Text("Step away from the stimulus if you can. Distance is part of the tool.")
                                .font(.headline)
                        }
                    }
                }

                VStack(spacing: 12) {
                    BeforeActionButton("I still want to do it") {
                        Task {
                            NotificationService.shared.cancelWaitFinishedNotification(sessionID: session.id)
                            await appModel.completeCheck(using: session, action: .goAheadAnyway)
                            dismiss()
                        }
                    }

                    BeforeActionButton("Move it to tomorrow", style: .secondary) {
                        Task {
                            NotificationService.shared.cancelWaitFinishedNotification(sessionID: session.id)
                            await appModel.completeCheck(using: session, action: .decideTomorrow)
                            dismiss()
                        }
                    }

                    BeforeActionButton("Step away first", style: .tertiary) {
                        Task {
                            NotificationService.shared.cancelWaitFinishedNotification(sessionID: session.id)
                            await appModel.completeCheck(using: session, action: .leaveStimulus)
                            dismiss()
                        }
                    }

                    if !timerActive {
                        BeforeActionButton(appModel.preferences.quickBufferDuration.resetTitle, style: .tertiary) {
                            secondsRemaining = appModel.preferences.quickBufferDuration.seconds
                            timerActive = true
                            Task {
                                await NotificationService.shared.scheduleWaitFinishedNotification(
                                    sessionID: session.id,
                                    duration: appModel.preferences.quickBufferDuration
                                )
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(24)
        }
        .task {
            if secondsRemaining == 0 {
                secondsRemaining = appModel.preferences.quickBufferDuration.seconds
            }
            reminderText = appModel.bestReminder(
                for: session.scenario,
                prompt: session.note,
                mode: .quick
            )
            await NotificationService.shared.scheduleWaitFinishedNotification(
                sessionID: session.id,
                duration: appModel.preferences.quickBufferDuration
            )
        }
        .task(id: secondsRemaining) {
            guard timerActive, secondsRemaining > 0 else { return }
            try? await Task.sleep(for: .seconds(1))
            secondsRemaining -= 1
        }
        .onChange(of: secondsRemaining) { _, newValue in
            if newValue == 0 { timerActive = false }
        }
        .onDisappear {
            NotificationService.shared.cancelWaitFinishedNotification(sessionID: session.id)
            session.isShowingWaitSheet = false
        }
    }

    private var countdownText: String {
        let minutes = secondsRemaining / 60
        let seconds = secondsRemaining % 60
        return "\(minutes):" + String(format: "%02d", seconds)
    }
}
