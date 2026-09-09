import Foundation
import Testing
@testable import BASMemory

@Suite("BASCurrentBrain Persistence Core")
struct BASCurrentBrainPersistenceCoreTests {
    private func update(
        id: String,
        createdAt: Date,
        fingerprint: String? = nil
    ) -> BASCurrentBrainUpdateStoredFields {
        BASCurrentBrainUpdateStoredFields(
            id: UUID(uuidString: id)!,
            createdAt: createdAt,
            source: "launch",
            mode: "primary",
            dominantGoal: fingerprint,
            dominantReactionWeight: BASReactionWeightKey.briefLanguage.rawValue,
            fingerprint: fingerprint ?? id,
            activeConstraints: [],
            activeTemplateIDs: [],
            failureGuardIDs: []
        )
    }

    @Test("update input derives canonical brain snapshot fields")
    func updateInputDerivesCanonicalBrainSnapshotFields() {
        let input = BASCurrentBrainPersistenceApplier.updateInput(
            mode: " primary ",
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

        #expect(input.mode == "primary")
        #expect(input.dominantGoal == "Wait until morning")
        #expect(input.dominantReactionWeight == BASReactionWeightKey.warmDirectTone.rawValue)
        #expect(input.fingerprint.isEmpty == false)
        #expect(input.activeConstraints == ["late_hour", "slow_down"])
        #expect(input.activeTemplateIDs == ["template.breath", "template.pause"])
        #expect(input.failureGuardIDs == ["night_fast_path_failure", "reply_spiral"])
    }

    @Test("retained update ids protect every entry inside the minimum recovery age")
    func retainedUpdateIDsProtectEveryEntryInsideMinimumRecoveryAge() {
        let now = Date(timeIntervalSince1970: 1_744_300_000)
        let retained = BASCurrentBrainPersistenceApplier.retainedUpdateIDs(
            in: [
                BASCurrentBrainUpdateStoredFields(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                    createdAt: now.addingTimeInterval(-60),
                    source: "launch",
                    mode: "primary",
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
                    mode: "primary",
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
                    mode: "primary",
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

        #expect(retained == Set([
            UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        ]))
    }

    @Test("default update cap is soft while sixty-one entries are fresh")
    func defaultUpdateCapIsSoftWhileSixtyOneEntriesAreFresh() {
        let now = Date(timeIntervalSince1970: 1_744_300_000)
        let updates = (1...61).map { index in
            update(
                id: String(format: "00000000-0000-0000-0000-%012d", index),
                createdAt: now.addingTimeInterval(-Double(index))
            )
        }

        let retained = BASCurrentBrainPersistenceApplier.retainedUpdateIDs(
            in: updates,
            now: now
        )

        #expect(retained == Set(updates.map(\.id)))
    }

    @Test("update minimum recovery age is inclusive and protects future entries")
    func updateMinimumRecoveryAgeIsInclusiveAndProtectsFutureEntries() {
        let now = Date(timeIntervalSince1970: 1_744_300_000)
        let boundary = update(
            id: "00000000-0000-0000-0000-000000000001",
            createdAt: now.addingTimeInterval(-259_200)
        )
        let tooOld = update(
            id: "00000000-0000-0000-0000-000000000002",
            createdAt: now.addingTimeInterval(-259_201)
        )
        let future = update(
            id: "00000000-0000-0000-0000-000000000003",
            createdAt: now.addingTimeInterval(60)
        )

        let retained = BASCurrentBrainPersistenceApplier.retainedUpdateIDs(
            in: [tooOld, future, boundary],
            now: now,
            maxEntries: 0,
            retentionInterval: 60 * 60
        )

        #expect(retained == Set([boundary.id, future.id]))
    }

    @Test("update counts preserve fresh entries and use canonical older allowance")
    func updateCountsPreserveFreshEntriesAndUseCanonicalOlderAllowance() {
        let now = Date(timeIntervalSince1970: 1_744_300_000)
        let fresh = update(
            id: "00000000-0000-0000-0000-000000000009",
            createdAt: now.addingTimeInterval(-60)
        )
        let olderA = update(
            id: "00000000-0000-0000-0000-000000000001",
            createdAt: now.addingTimeInterval(-259_201)
        )
        let olderB = update(
            id: "00000000-0000-0000-0000-000000000002",
            createdAt: olderA.createdAt
        )
        let outsideWindow = update(
            id: "00000000-0000-0000-0000-000000000003",
            createdAt: now.addingTimeInterval(-BASCurrentBrainPersistenceApplier.defaultRetentionInterval - 1)
        )
        let updates = [olderB, outsideWindow, fresh, olderA]

        for count in [0, -1, 1] {
            let retained = BASCurrentBrainPersistenceApplier.retainedUpdateIDs(
                in: updates,
                now: now,
                maxEntries: count
            )
            #expect(retained == Set([fresh.id]))
        }

        let retainedWithOlderAllowance = BASCurrentBrainPersistenceApplier.retainedUpdateIDs(
            in: updates,
            now: now,
            maxEntries: 2
        )
        #expect(retainedWithOlderAllowance == Set([fresh.id, olderA.id]))
    }

    @Test("invalid update intervals cannot remove protected entries")
    func invalidUpdateIntervalsCannotRemoveProtectedEntries() {
        let now = Date(timeIntervalSince1970: 1_744_300_000)
        let protected = update(
            id: "00000000-0000-0000-0000-000000000001",
            createdAt: now.addingTimeInterval(-259_200)
        )
        let old = update(
            id: "00000000-0000-0000-0000-000000000002",
            createdAt: now.addingTimeInterval(-259_201)
        )

        for interval in [0, -1, .nan, -.infinity] as [TimeInterval] {
            let retained = BASCurrentBrainPersistenceApplier.retainedUpdateIDs(
                in: [old, protected],
                now: now,
                maxEntries: 2,
                retentionInterval: interval
            )
            #expect(retained == Set([protected.id]))
        }

        let retainedWithInfiniteWindow = BASCurrentBrainPersistenceApplier.retainedUpdateIDs(
            in: [old, protected],
            now: now,
            maxEntries: 2,
            retentionInterval: .infinity
        )
        #expect(retainedWithInfiniteWindow == Set([protected.id, old.id]))
    }
}
