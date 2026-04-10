import Foundation
import Testing
@testable import BASMemory

@Suite("BASCurrentBrain Persistence Core")
struct BASCurrentBrainPersistenceCoreTests {
    @Test("update input derives canonical brain snapshot fields")
    func updateInputDerivesCanonicalBrainSnapshotFields() {
        let input = BASCurrentBrainPersistenceApplier.updateInput(
            mode: " quick ",
            bootstrapped: BASBootstrappedBrainState(
                brainState: BASDecisionBrainState(
                    profileCore: [],
                    activeGoals: [],
                    relevantMemories: [],
                    sessionBiases: [],
                    retrievalTags: ["night", "night", " texting "],
                    reactionWeights: BASReactionWeights(
                        briefLanguage: 0.22,
                        warmDirectTone: 0.91,
                        lowCognitiveLoad: 0.32,
                        interruptiveActionBias: 0.12,
                        boundaryNamingBias: 0.24,
                        tradeoffClarityBias: 0.61
                    ),
                    loadedAt: Date(timeIntervalSince1970: 1_744_200_000)
                ),
                dominantGoal: "  Wait until morning ",
                activeConstraints: ["late_hour", " late_hour ", "slow_down"],
                activeTemplateIDs: ["template.breath", "template.breath", "template.pause"],
                failureGuardIDs: ["night_fast_path_failure", " night_fast_path_failure ", "reply_spiral"]
            )
        )

        #expect(input.mode == "quick")
        #expect(input.dominantGoal == "Wait until morning")
        #expect(input.dominantReactionWeight == BASReactionWeightKey.warmDirectTone.rawValue)
        #expect(input.fingerprint.isEmpty == false)
        #expect(input.activeConstraints == ["late_hour", "slow_down"])
        #expect(input.activeTemplateIDs == ["template.breath", "template.pause"])
        #expect(input.failureGuardIDs == ["night_fast_path_failure", "reply_spiral"])
    }

    @Test("retained update ids keep newest fresh entries only")
    func retainedUpdateIDsKeepNewestFreshEntriesOnly() {
        let now = Date(timeIntervalSince1970: 1_744_300_000)
        let retained = BASCurrentBrainPersistenceApplier.retainedUpdateIDs(
            in: [
                BASCurrentBrainUpdateStoredFields(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                    createdAt: now.addingTimeInterval(-60),
                    source: "launch",
                    mode: "quick",
                    dominantGoal: "c",
                    dominantReactionWeight: BASReactionWeightKey.briefLanguage.rawValue,
                    fingerprint: "c",
                    activeConstraints: [],
                    activeTemplateIDs: [],
                    failureGuardIDs: []
                ),
                BASCurrentBrainUpdateStoredFields(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                    createdAt: now.addingTimeInterval(-60),
                    source: "launch",
                    mode: "quick",
                    dominantGoal: "a",
                    dominantReactionWeight: BASReactionWeightKey.briefLanguage.rawValue,
                    fingerprint: "a",
                    activeConstraints: [],
                    activeTemplateIDs: [],
                    failureGuardIDs: []
                ),
                BASCurrentBrainUpdateStoredFields(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                    createdAt: now.addingTimeInterval(-BASCurrentBrainPersistenceApplier.defaultRetentionInterval - 1),
                    source: "launch",
                    mode: "quick",
                    dominantGoal: "stale",
                    dominantReactionWeight: BASReactionWeightKey.briefLanguage.rawValue,
                    fingerprint: "stale",
                    activeConstraints: [],
                    activeTemplateIDs: [],
                    failureGuardIDs: []
                )
            ],
            now: now,
            maxEntries: 1
        )

        #expect(retained == [UUID(uuidString: "00000000-0000-0000-0000-000000000001")!])
    }
}
