import SwiftUI
import BASHostKit

struct SampleHostView: View {
    @ObservedObject var model: SampleHostModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SampleHost")
                            .font(.largeTitle.weight(.bold))
                        Text("Minimal private SDK integration proving lifecycle bootstrap, session start, reopen, current-brain render, and console inspection through BASHostKit.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        Button("Bootstrap") { model.bootstrap() }
                        Button("Rapid") { model.start(.rapid) }
                        Button("Deliberate") { model.start(.deliberate) }
                        Button("Reflective") { model.start(.reflective) }
                        Button("Reopen") { model.reopen() }
                    }
                    .buttonStyle(.borderedProminent)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.result.activeSessionTitle)
                            .font(.headline)
                        Text("Workflow: \(model.result.currentBrain.workflowTitle)")
                            .font(.subheadline.weight(.medium))
                        if !model.result.currentBrain.dominantGoals.isEmpty {
                            Text(model.result.currentBrain.dominantGoals.joined(separator: " • "))
                                .font(.subheadline)
                        }
                        if !model.result.currentBrain.activeConstraints.isEmpty {
                            Text(model.result.currentBrain.activeConstraints.joined(separator: " • "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !model.result.notices.isEmpty {
                            Text(model.result.notices.joined(separator: " • "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    BASHostConsoleView(snapshot: model.result.consoleSnapshot)
                }
                .padding(24)
            }
            .navigationTitle("BASHostKit")
        }
    }
}
