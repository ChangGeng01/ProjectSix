import Foundation
import BASHostKit

@MainActor
final class SampleHostModel: ObservableObject {
    @Published private(set) var result: BASHostSessionResult

    private let runtime: BASHostRuntime

    init(runtime: BASHostRuntime = BASHostRuntime()) {
        self.runtime = runtime
        self.result = runtime.bootstrap(
            BASHostLifecycleRequest(
                phase: .initialAppearance,
                preferredMode: .quick,
                sourceSurface: .app,
                promptSeed: "Load the substrate before the host asks it to speak."
            )
        )
    }

    func bootstrap() {
        result = runtime.bootstrap(
            BASHostLifecycleRequest(
                phase: .sceneActive,
                preferredMode: .quick,
                sourceSurface: .app,
                promptSeed: "Refresh the current brain and restore the shell."
            )
        )
    }

    func start(_ mode: BASDecisionMode) {
        let prompts: [BASDecisionMode: String] = [
            .quick: "Should I do this right now?",
            .balance: "What tradeoff am I refusing to name?",
            .mirror: "What is the honest story here?"
        ]
        result = runtime.startSession(
            BASHostSessionRequest(
                kind: mode == .quick ? .quick : mode == .balance ? .balance : .mirror,
                mode: mode,
                surface: .app,
                prompt: prompts[mode] ?? "Hold this decision for one more beat.",
                title: "\(mode.title) from SampleHost",
                riskLevel: mode == .mirror ? .medium : .low
            )
        )
    }

    func reopen() {
        result = runtime.reopen(
            BASHostReopenRequest(
                mode: .balance,
                title: "Reopen this held decision",
                detail: "SampleHost is proving the reopen path through BASHostKit.",
                promptSeed: "Take one slower pass before committing.",
                riskLevel: .high,
                reopenHint: "Reopen with more structure",
                templateHint: "Use a cooling template before acting.",
                interventionHistorySummary: "High-risk reopen requests should restore more friction."
            )
        )
    }
}
