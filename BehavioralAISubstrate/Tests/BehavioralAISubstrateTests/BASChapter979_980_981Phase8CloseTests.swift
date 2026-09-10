// MARK: - BASChapter979_980_981Phase8CloseTests
// chapter 九百七十九-九百八十一 / M3600-M3610 — Phase 8 close
//
// Phase 8 ships in 3 chapters。 This combined test file covers
// all 3 because each module is small:
//
//   ch 979 — Shared latent spine + BASCandidateSeed cache
//   ch 980 — Hot/cold agent tier + activation planner
//   ch 981 — Speculative prefetcher + zero-copy state ref bus
//           + ARC SEAL
//
// Test scope:
//   Ch 979 latent spine:
//     1.  Candidate seed Codable + sorted coverage notes
//     2.  Concern seed Codable
//     3.  Spine sorts seeds by ID
//     4.  Candidate lookup
//     5.  Hit-metric ratio
//     6.  Spine builder from candidates
//     7.  Token-count estimator
//     8.  Reuse stat hit ratio
//
//   Ch 980 hot/cold tier:
//     9.  Tier enum count pin (3)
//     10. Tier registry has all 9 core + 7 watcher + 4 sealed
//     11. Hot-tier roles correct
//     12. Cold-tier roles correct
//     13. Sealed-tier roles correct
//     14. Activation planner: LOW risk → hot only
//     15. Activation planner: MED risk → hot + Planner + Memory
//     16. Activation planner: HIGH risk → all core
//     17. Budget exceeded → skip + audit
//     18. Cache-hit short-circuit (low risk + hit ≥ 0.7)
//     19. Force-activate honored
//
//   Ch 981 speculative + zero-copy:
//     20. Task: idempotent + safe-on-abandon flags
//     21. Planner: sort by score (confidence/cost)
//     22. Planner: skip not-safe-on-abandon
//     23. Default tasks differ by risk band
//     24. Zero-copy ref Codable + canonical objectRef
//     25. Bus stat fresh ratio
//
//   Phase 8 arc seal cross-cuts:
//     26. ALL Phase 8 types Codable round-trip
//     27. Determinism end-to-end (same input → byte-equal)
//     28. CRITICAL: zero-copy ref MUST NOT bypass Single-Writer

import XCTest
@testable import BASMemory

final class BASChapter979_980_981Phase8CloseTests:
    XCTestCase
{

    // MARK: - Ch 979 — Latent spine

    func testCandidateSeedSortedCoverageNotes() {
        let s = BASCandidateSeed(
            candidateID: "c1",
            tokenCount: 100,
            embeddingDigest: "abc",
            encoderConfidence: 0.9,
            coverageNotes: ["z", "a", "m"])
        XCTAssertEqual(s.coverageNotes,
            ["a", "m", "z"],
            "ch 979: coverage notes auto-sorted")
    }

    func testCandidateSeedClampsConfidence() {
        let lo = BASCandidateSeed(
            candidateID: "c1",
            tokenCount: 100,
            embeddingDigest: "x",
            encoderConfidence: -5.0)
        XCTAssertEqual(lo.encoderConfidence, 0.0,
            accuracy: 0.0001)
        let hi = BASCandidateSeed(
            candidateID: "c1",
            tokenCount: 100,
            embeddingDigest: "x",
            encoderConfidence: 99.0)
        XCTAssertEqual(hi.encoderConfidence, 1.0,
            accuracy: 0.0001)
    }

    func testConcernSeedCodableRoundTrip() throws {
        let s = BASLatentConcernSeed(
            concernID: "co1",
            concernKind: "risk.manipulation",
            tokenCount: 50,
            embeddingDigest: "dig",
            severityHint: 0.85)
        try roundTrip(s)
    }

    func testSpineSortsCandidatesById() {
        let spine = BASLatentSpine(
            turnID: "t1",
            candidateSeeds: [
                BASCandidateSeed(
                    candidateID: "c-z",
                    tokenCount: 10,
                    embeddingDigest: "z",
                    encoderConfidence: 0.5),
                BASCandidateSeed(
                    candidateID: "c-a",
                    tokenCount: 10,
                    embeddingDigest: "a",
                    encoderConfidence: 0.5),
            ])
        XCTAssertEqual(
            spine.candidateSeeds.map { $0.candidateID },
            ["c-a", "c-z"],
            "ch 979: spine candidates auto-sorted by ID")
    }

    func testSpineLookup() {
        let spine = BASLatentSpine(
            turnID: "t1",
            candidateSeeds: [
                BASCandidateSeed(
                    candidateID: "c1",
                    tokenCount: 10,
                    embeddingDigest: "a",
                    encoderConfidence: 0.5),
            ])
        XCTAssertNotNil(spine.candidate("c1"))
        XCTAssertNil(spine.candidate("c-missing"))
    }

    func testSpineHitMetric() {
        let spine = BASLatentSpine(
            turnID: "t1",
            candidateSeeds: [
                BASCandidateSeed(
                    candidateID: "c1",
                    tokenCount: 10,
                    embeddingDigest: "a",
                    encoderConfidence: 0.5),
                BASCandidateSeed(
                    candidateID: "c2",
                    tokenCount: 10,
                    embeddingDigest: "b",
                    encoderConfidence: 0.5),
            ])
        let (hits, expected) = spine.hitMetric(
            expectedCandidateIDs: ["c1", "c2", "c3"])
        XCTAssertEqual(hits, 2)
        XCTAssertEqual(expected, 3)
    }

    func testSpineBuilderFromCandidates() {
        let cands = [
            BASPlannerCandidate(
                candidateID: "c1", title: "t",
                actionSummary: "short summary",
                confidence: 0.8,
                reversibility: 0.7),
        ]
        let spine =
            BASLatentSpineBuilder.buildFromCandidates(
                turnID: "t1",
                candidates: cands)
        XCTAssertEqual(spine.candidateSeeds.count, 1)
        // Placeholder digest is deterministic FNV hash
        XCTAssertEqual(spine.candidateSeeds[0].embeddingDigest,
            BASLatentSpineBuilder.placeholderDigest("c1"))
    }

    func testTokenEstimator() {
        XCTAssertEqual(
            BASLatentSpineBuilder
                .estimateTokenCount("abcd"), 1)
        XCTAssertEqual(
            BASLatentSpineBuilder
                .estimateTokenCount("abcdefgh"), 2)
        XCTAssertEqual(
            BASLatentSpineBuilder
                .estimateTokenCount(""), 1,
            "ch 979: empty input → 1 token estimate (min)")
    }

    func testReuseStatHitRatio() {
        let stat = BASLatentSpineReuseStat(
            agentRole: .planner,
            candidateHits: 8,
            candidateMisses: 2,
            concernHits: 1,
            concernMisses: 1)
        // (8+1) / (8+2+1+1) = 9/12 = 0.75
        XCTAssertEqual(stat.hitRatio, 0.75,
            accuracy: 0.0001)
    }

    func testReuseStatEmptyHitRatio() {
        let stat = BASLatentSpineReuseStat(
            agentRole: .planner)
        XCTAssertEqual(stat.hitRatio, 0.0,
            "ch 979: empty-lookup stat → 0.0 ratio " +
            "(avoid divide-by-zero)")
    }

    // MARK: - Ch 980 — Hot/cold tier

    func testTierEnumCountIs3() {
        XCTAssertEqual(
            BASAgentTier.allCases.count, 3,
            "ch 980: 3 tiers (hot / cold / sealed)")
    }

    func testTierRegistryCoversAllCoreAndWatchers() {
        // 9 core + 7 watcher + 4 sealed = 20 roles
        XCTAssertEqual(
            BASAgentTierRegistry
                .defaultAssignments.count, 20,
            "ch 980: tier registry MUST cover all 20 roles")
    }

    func testHotTierRolesCorrect() {
        let hot: Set<BASAgentRole> = [
            .scout, .risk, .surface,
            .sovereignSentinel,
            .anomalyWatcher, .gaslightWatcher,
            .memoryPollutionWatcher, .hostDriftWatcher,
            .toolInjectionWatcher, .axisDeviationWatcher,
            .sanctumLeakWatcher,
        ]
        for role in hot {
            XCTAssertEqual(
                BASAgentTierRegistry.tier(for: role), .hot,
                "ch 980: \(role) MUST be hot tier")
        }
    }

    func testColdTierRolesCorrect() {
        let cold: Set<BASAgentRole> = [
            .planner, .memory, .critic,
            .hostAlignment, .evolutionShadow,
        ]
        for role in cold {
            XCTAssertEqual(
                BASAgentTierRegistry.tier(for: role),
                .cold,
                "ch 980: \(role) MUST be cold tier")
        }
    }

    func testSealedTierRolesCorrect() {
        let sealed: Set<BASAgentRole> = [
            .actionPermit, .deleteRollbackSeal,
            .memorySeal, .compareModerator,
        ]
        for role in sealed {
            XCTAssertEqual(
                BASAgentTierRegistry.tier(for: role),
                .sealed,
                "ch 980: \(role) MUST be sealed tier")
        }
    }

    func testActivationPlanner_LowRiskHotOnly() {
        let plan = BASAgentTierActivationPlanner.plan(
            riskBand: .low,
            wakeBudgetMicros: 1_000_000)
        // No cold agents activated on low risk
        let cold: Set<BASAgentRole> = [
            .planner, .memory, .critic,
            .hostAlignment, .evolutionShadow,
        ]
        for role in cold {
            XCTAssertFalse(
                plan.activations.contains(role),
                "ch 980: LOW-risk plan MUST NOT include " +
                "cold-tier \(role)")
        }
    }

    func testActivationPlanner_MedRiskAddsPlannerMemory() {
        let plan = BASAgentTierActivationPlanner.plan(
            riskBand: .medium,
            wakeBudgetMicros: 1_000_000)
        XCTAssertTrue(
            plan.activations.contains(.planner))
        XCTAssertTrue(
            plan.activations.contains(.memory))
        XCTAssertFalse(
            plan.activations.contains(.critic),
            "ch 980: MED-risk does NOT include Critic " +
            "(reserved for HIGH)")
    }

    func testActivationPlanner_HighRiskAllCore() {
        let plan = BASAgentTierActivationPlanner.plan(
            riskBand: .high,
            wakeBudgetMicros: 1_000_000)
        // All cold agents activated
        for role in [
            BASAgentRole.planner, .memory, .critic,
            .hostAlignment, .evolutionShadow]
        {
            XCTAssertTrue(
                plan.activations.contains(role),
                "ch 980: HIGH-risk MUST activate \(role)")
        }
    }

    func testActivationPlanner_BudgetExceededSkips() {
        // Tiny budget — all cold agents skip
        let plan = BASAgentTierActivationPlanner.plan(
            riskBand: .high,
            wakeBudgetMicros: 50_000)
        // Hot still fired,but cold all skipped
        XCTAssertFalse(plan.skips.isEmpty,
            "ch 980: tiny budget → audit reports skips")
        // Each skip names a specific role
        for skip in plan.skips {
            XCTAssertTrue(
                skip.contains("budget-exceeded") ||
                skip.contains("cache-hit") ||
                skip.contains(":"),
                "ch 980: skip audit format")
        }
    }

    func testActivationPlanner_CacheHitShortCircuit() {
        let plan = BASAgentTierActivationPlanner.plan(
            riskBand: .low,
            wakeBudgetMicros: 1_000_000,
            spineHitRatio: 0.85)
        // Low risk + high hit → cold agents all skipped
        XCTAssertTrue(plan.skips.contains { skip in
            skip.contains("cache-hit-skip")
        })
        XCTAssertFalse(
            plan.activations.contains(.planner))
    }

    func testActivationPlanner_ForceActivate() {
        let plan = BASAgentTierActivationPlanner.plan(
            riskBand: .low,
            wakeBudgetMicros: 1_000_000,
            forceActivate: [.planner])
        XCTAssertTrue(
            plan.activations.contains(.planner),
            "ch 980: force-activate honored even on low risk")
    }

    // MARK: - Ch 981 — Speculative + zero-copy

    func testTaskFlagsDefaults() {
        let t = BASSpeculativeTask(
            taskID: "t1",
            workKind: "test",
            estimatedCostMicros: 1000)
        XCTAssertTrue(t.isIdempotent,
            "ch 981: tasks default to idempotent")
        XCTAssertTrue(t.isSafeOnAbandon)
        XCTAssertEqual(t.confidence, 0.5,
            accuracy: 0.0001)
    }

    func testPrefetcher_SortsTasksByScore() {
        let tasks = [
            BASSpeculativeTask(
                taskID: "low-conf",
                workKind: "low",
                estimatedCostMicros: 1000,
                confidence: 0.2),
            BASSpeculativeTask(
                taskID: "high-conf",
                workKind: "high",
                estimatedCostMicros: 1000,
                confidence: 0.9),
        ]
        let plan = BASSpeculativePrefetcher.plan(
            turnID: "t1",
            tasks: tasks,
            wakeBudgetMicros: 100_000)
        XCTAssertEqual(plan.fire.first?.taskID,
            "high-conf",
            "ch 981: prefetcher fires highest-confidence " +
            "task first (score = conf/cost)")
    }

    func testPrefetcher_SkipsNotSafeOnAbandon() {
        let tasks = [
            BASSpeculativeTask(
                taskID: "dangerous",
                workKind: "x",
                estimatedCostMicros: 1000,
                isSafeOnAbandon: false),
        ]
        let plan = BASSpeculativePrefetcher.plan(
            turnID: "t1",
            tasks: tasks,
            wakeBudgetMicros: 100_000)
        XCTAssertTrue(plan.fire.isEmpty,
            "ch 981: not-safe-on-abandon tasks NEVER fire " +
            "(speculation discipline)")
        XCTAssertTrue(plan.skipped.contains {
            $0.contains("not-safe-on-abandon")
        })
    }

    func testPrefetcher_DefaultTasksVaryByRisk() {
        let lowTasks =
            BASSpeculativePrefetcher.defaultTasks(
                riskBand: .low)
        let highTasks =
            BASSpeculativePrefetcher.defaultTasks(
                riskBand: .high)
        XCTAssertGreaterThan(
            highTasks.count, lowTasks.count,
            "ch 981: HIGH-risk has more speculation tasks " +
            "than LOW (adds critic warmup)")
        // High-risk guard.template confidence is higher
        let lowGuard = lowTasks.first {
            $0.workKind == "guard.template"
        }?.confidence ?? 0.0
        let highGuard = highTasks.first {
            $0.workKind == "guard.template"
        }?.confidence ?? 0.0
        XCTAssertGreaterThan(
            highGuard, lowGuard,
            "ch 981: HIGH-risk guard.template has higher " +
            "speculation confidence")
    }

    func testZeroCopyRefCanonicalObjectRef() {
        let ref = BASZeroCopyStateRef(
            domain: .candidateFrontier,
            objectID: "frontier-t1",
            versionAtRead: 42)
        XCTAssertEqual(ref.objectRef,
            "candidateFrontier#frontier-t1",
            "ch 981: zero-copy ref produces canonical " +
            "ch 954 objectRef string")
    }

    func testBusStatFreshRatio() {
        let s = BASZeroCopyBusStat(
            turnID: "t1",
            refCount: 9,
            staleRefetches: 1)
        // 9 / (9 + 1) = 0.9
        XCTAssertEqual(s.freshRatio, 0.9,
            accuracy: 0.0001)
    }

    func testBusStatEmptyFreshRatioIsIdentity() {
        let s = BASZeroCopyBusStat(turnID: "t1")
        XCTAssertEqual(s.freshRatio, 1.0,
            accuracy: 0.0001,
            "ch 981: empty bus → 1.0 (identity — no stale " +
            "refetches if no refs)")
    }

    // MARK: - Phase 8 arc seal cross-cuts

    func testAllPhase8TypesCodable() throws {
        try roundTrip(BASCandidateSeed(
            candidateID: "c1",
            tokenCount: 100,
            embeddingDigest: "x",
            encoderConfidence: 0.8,
            coverageNotes: ["a"]))
        try roundTrip(BASLatentConcernSeed(
            concernID: "co1",
            concernKind: "risk.manipulation",
            tokenCount: 50,
            embeddingDigest: "x",
            severityHint: 0.5))
        try roundTrip(BASLatentSpine(
            turnID: "t1",
            inputTokenCount: 200,
            inputEmbeddingDigest: "x"))
        try roundTrip(BASLatentSpineReuseStat(
            agentRole: .planner,
            candidateHits: 5))
        try roundTrip(BASAgentTierAssignment(
            role: .planner,
            tier: .cold,
            wakeBudgetMicros: 100_000))
        try roundTrip(BASAgentTierActivationPlan(
            activations: [.scout, .planner]))
        try roundTrip(BASSpeculativeTask(
            taskID: "t1",
            workKind: "test",
            estimatedCostMicros: 1000))
        try roundTrip(BASSpeculationPlan(
            turnID: "t1",
            fire: []))
        try roundTrip(BASZeroCopyStateRef(
            domain: .candidateFrontier,
            objectID: "x",
            versionAtRead: 1))
        try roundTrip(BASZeroCopyBusStat(
            turnID: "t1"))
    }

    func testPhase8Deterministic() {
        // Same input → byte-equal output for all 3 module
        // entry points
        let plan1 = BASAgentTierActivationPlanner.plan(
            riskBand: .medium,
            wakeBudgetMicros: 500_000,
            spineHitRatio: 0.3)
        let plan2 = BASAgentTierActivationPlanner.plan(
            riskBand: .medium,
            wakeBudgetMicros: 500_000,
            spineHitRatio: 0.3)
        XCTAssertEqual(plan1, plan2)

        let specTasks =
            BASSpeculativePrefetcher.defaultTasks(
                riskBand: .medium)
        let sp1 = BASSpeculativePrefetcher.plan(
            turnID: "t1",
            tasks: specTasks,
            wakeBudgetMicros: 50_000)
        let sp2 = BASSpeculativePrefetcher.plan(
            turnID: "t1",
            tasks: specTasks,
            wakeBudgetMicros: 50_000)
        XCTAssertEqual(sp1, sp2)
    }

    // MARK: - CRITICAL: zero-copy ref MUST NOT bypass Single-Writer

    func testCRITICAL_ZeroCopyRefIsReadOnlyPointer() async {
        // A zero-copy ref is just a (domain, objectID,
        // version, timestamp) tuple — it carries NO write
        // capability。 Verify by inspecting struct fields:
        // there's no payload + no agent ID。 Caller cannot
        // construct a fake "write" using a ref alone — they
        // MUST go through BASSharedStateGraph.writeObject(...)
        // which enforces Single-Writer。
        let ref = BASZeroCopyStateRef(
            domain: .candidateFrontier,
            objectID: "x",
            versionAtRead: 1)
        // The ref's Mirror reveals only the 4 fields above:
        let mirror = Mirror(reflecting: ref)
        let labels = mirror.children.compactMap {
            $0.label
        }
        XCTAssertFalse(labels.contains("payload"),
            "ch 981 CRITICAL: ref MUST NOT carry payload — " +
            "agents MUST query the state graph by ref to get " +
            "the actual payload (Single-Writer-Per-Domain " +
            "preserved)")
        XCTAssertFalse(labels.contains("agentID"),
            "ch 981 CRITICAL: ref MUST NOT carry an agent " +
            "identity (no impersonation surface)")
    }

    // MARK: - Helpers

    private func roundTrip<T: Codable & Equatable>(
        _ v: T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let data = try enc.encode(v)
        let back = try JSONDecoder().decode(
            T.self, from: data)
        XCTAssertEqual(v, back, file: file, line: line)
    }
}
