import Foundation
import Testing
@testable import BASAppleAdapters
@testable import BASMemory

@Suite("BASApple Current Brain Runtime Bridge")
struct BASAppleCurrentBrainRuntimeBridgeTests {
    @Test("session bridge compiles prompt fragments into a bootstrap input")
    func sessionBridgeCompilesPromptFragmentsIntoBootstrapInput() {
        let input = BASAppleCurrentBrainSessionBridgeInput(
            modeID: "primary",
            promptFragments: ["  should ", "I", "wait?  "],
            preferredLanguages: ["en-AU"],
            now: Date(timeIntervalSince1970: 1_765_000_000),
            projection: BASBrainProjection(
                records: [],
                candidates: [],
                recentEvents: []
            ),
            retrievalMode: "filtered"
        )

        let bootstrapInput = BASAppleCurrentBrainRuntimeBridgeBuilder.sessionBootstrapInput(
            from: input
        )

        #expect(bootstrapInput.modeID == "primary")
        #expect(bootstrapInput.prompt == "should I wait?")
        #expect(bootstrapInput.triggerID == BASCurrentBrainBootstrapTrigger.sessionPrime.rawValue)
        #expect(bootstrapInput.retrievalMode == "filtered")
        #expect(bootstrapInput.preferredLanguages == ["en-AU"])
    }

    @Test("active bridge falls back to task graph seed and carries task graph hint")
    func activeBridgeFallsBackToTaskGraphSeedAndCarriesTaskGraphHint() {
        let input = BASAppleCurrentBrainActiveRefreshBridgeInput(
            promptFragmentsByModeID: [:],
            modePriority: ["primary", "comparative", "reflective"],
            taskGraphModeID: "reflective",
            taskGraphPromptSeed: "resume this tomorrow",
            preferredLanguages: ["en-AU"],
            now: Date(timeIntervalSince1970: 1_765_000_000),
            projection: BASBrainProjection(
                records: [],
                candidates: [],
                recentEvents: []
            ),
            taskGraphHint: BASAppleCurrentBrainBootstrapHostTaskGraphInput(
                headline: "Return to the mirror lane",
                activeNodeCount: 2,
                hasResumeCandidate: true,
                resumeHint: "Resume the unresolved self-check"
            ),
            retrievalModesByModeID: ["reflective": "filtered"],
            triggerID: BASCurrentBrainBootstrapTrigger.sceneActive.rawValue
        )

        let bootstrapInput = BASAppleCurrentBrainRuntimeBridgeBuilder.activeBootstrapInput(
            from: input
        )

        #expect(bootstrapInput.modeID == "reflective")
        #expect(bootstrapInput.prompt == "resume this tomorrow")
        #expect(bootstrapInput.retrievalMode == "filtered")
        #expect(bootstrapInput.taskGraphHeadline == "Return to the mirror lane")
        #expect(bootstrapInput.taskGraphActiveNodeCount == 2)
        #expect(bootstrapInput.taskGraphHasResumeCandidate == true)
        #expect(bootstrapInput.taskGraphResumeHint == "Resume the unresolved self-check")
        #expect(bootstrapInput.triggerID == BASCurrentBrainBootstrapTrigger.sceneActive.rawValue)
    }
}
