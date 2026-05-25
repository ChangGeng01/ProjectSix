// MARK: - BASChapter956_5UserPassFixesTests
// chapter 九百五十六.5 / M3485.5 USER-PASS fix-of-fix
//
// User caught 5 real gaps in Phase 0 implementation:
//
//   1. Single-Writer-Per-Domain only checked per-agent writeDomains,
//      no global registry → two agents both claiming `.candidateFrontier`
//      could both write,violating Root Law 3 at system level
//   2. Merge engine returned accepted/rejected delta IDs but never
//      applied patchJson to state graph (pure metadata shuffle)
//   3. BASAgentDelta declared `dependencies` + `conflictRefs` fields
//      but merge engine ignored them
//   4. mergeID = `turnID + count` collided when two merges in same
//      turn had same delta count
//   5. "Recency" tie-breaker used lex deltaID proxy, not real timestamp
//
// Following ch 943.1 corrigendum discipline:fixes ship as
// regression tests that fail-loud on revert + audit-trail of which
// gap each test pins。

import XCTest
@testable import BASMemory

final class BASChapter956_5UserPassFixesTests: XCTestCase {

    // MARK: - Gap #1: global Single-Writer-Per-Domain registry

    /// Pre-fix: two agents with `.candidateFrontier` in writeDomains
    /// could both write,violating Root Law 3。 Post-fix: only the
    /// first-writer (or explicit registerWriter) can write — second
    /// agent throws writerIdentityMismatch。
    func testGap1_GlobalSingleWriterRegistryRejectsSecondAgent()
        async throws
    {
        let graph = BASSharedStateGraph()
        let planner1 = BASAgentSpec(
            agentID: "planner.1",
            role: .planner,
            writeDomains: [.candidateFrontier],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        let planner2 = BASAgentSpec(
            agentID: "planner.2",
            role: .planner,
            writeDomains: [.candidateFrontier],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        // First writer auto-claims domain
        _ = try await graph.writeObject(
            domain: .candidateFrontier,
            objectID: "cf-1",
            payloadJson: "{}",
            byAgent: planner1)
        let claimedBy =
            await graph.writerForDomain(.candidateFrontier)
        XCTAssertEqual(claimedBy, "planner.1")
        // Second writer (different agent,same role,same writeDomains)
        // must be rejected
        do {
            _ = try await graph.writeObject(
                domain: .candidateFrontier,
                objectID: "cf-2",
                payloadJson: "{}",
                byAgent: planner2)
            XCTFail(
                "ch 956.5 gap #1 REGRESSION: second writer must " +
                "throw writerIdentityMismatch")
        } catch BASSharedStateGraphError
            .writerIdentityMismatch(
                let domain, let registered, let attempting)
        {
            XCTAssertEqual(domain, .candidateFrontier)
            XCTAssertEqual(registered, "planner.1")
            XCTAssertEqual(attempting, "planner.2")
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }

    /// Explicit registerWriter API: writer registered upfront,
    /// duplicate registration of DIFFERENT agent throws
    /// domainAlreadyClaimed。
    func testGap1_ExplicitRegisterWriterRejectsDuplicate()
        async throws
    {
        let graph = BASSharedStateGraph()
        try await graph.registerWriter(
            agentID: "planner.1", domain: .candidateFrontier)
        // Re-register SAME agent → idempotent (no throw)
        try await graph.registerWriter(
            agentID: "planner.1", domain: .candidateFrontier)
        // Register DIFFERENT agent → throws
        do {
            try await graph.registerWriter(
                agentID: "planner.2",
                domain: .candidateFrontier)
            XCTFail("ch 956.5 gap #1 REGRESSION: duplicate " +
                    "writer registration must throw")
        } catch BASSharedStateGraphError.domainAlreadyClaimed(
            let domain, let existing, let new)
        {
            XCTAssertEqual(domain, .candidateFrontier)
            XCTAssertEqual(existing, "planner.1")
            XCTAssertEqual(new, "planner.2")
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }

    // MARK: - Gap #2: merge engine actually applies patchJson

    /// Pre-fix:`BASAgentMergeEngine.merge` returned accepted IDs
    /// but no patches were written to state graph。 Post-fix:
    /// `BASAgentMergeApplier.apply` writes the patches。
    func testGap2_MergeApplierWritesPatchesToStateGraph()
        async throws
    {
        let graph = BASSharedStateGraph()
        let planner = BASAgentSpec(
            agentID: "planner.1",
            role: .planner,
            writeDomains: [.candidateFrontier],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        let delta = BASAgentDelta(
            deltaID: "d1",
            agentID: "planner.1",
            targetObjectRef: "candidateFrontier#cf-1",
            deltaType: .add,
            patchJson: "{\"candidate\":\"option-A\"}",
            confidence: 0.8,
            createdAtNanos: 1_700_000_000_000_000_000)
        let mergeResult = BASAgentMergeEngine.merge(
            [delta],
            context: BASMergePriorityContext(),
            turnID: "t1")
        XCTAssertEqual(
            mergeResult.acceptedDeltaIDs, ["delta:d1"])
        // Pre-fix: this would PASS even though graph stayed empty。
        // Post-fix: applier actually writes,so we can read back。
        let outcomes = await BASAgentMergeApplier.apply(
            mergeResult: mergeResult,
            deltas: [delta],
            agents: ["planner.1": planner],
            graph: graph)
        XCTAssertEqual(outcomes.count, 1)
        XCTAssertTrue(outcomes[0].applied,
            "ch 956.5 gap #2 REGRESSION: applier must write")
        XCTAssertEqual(
            outcomes[0].writtenRef,
            "candidateFrontier#cf-1")
        // Read back via authorized reader
        let reader = BASAgentSpec(
            agentID: "reader.1",
            role: .surface,
            readDomains: [.candidateFrontier],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        let obj = try await graph.readObject(
            ref: "candidateFrontier#cf-1", byAgent: reader)
        XCTAssertEqual(
            obj.payloadJson,
            "{\"candidate\":\"option-A\"}")
    }

    /// Applier respects delta.remove tombstone convention。
    func testGap2_MergeApplierWritesTombstoneOnRemove()
        async throws
    {
        let graph = BASSharedStateGraph()
        let memory = BASAgentSpec(
            agentID: "memory.1",
            role: .memory,
            writeDomains: [.memoryBundle],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        let removeDelta = BASAgentDelta(
            deltaID: "d-remove",
            agentID: "memory.1",
            targetObjectRef: "memoryBundle#mb-1",
            deltaType: .remove,
            patchJson: "{\"original\":\"data\"}",
            confidence: 1.0)
        let mergeResult = BASAgentMergeEngine.merge(
            [removeDelta],
            context: BASMergePriorityContext(),
            turnID: "t1")
        let outcomes = await BASAgentMergeApplier.apply(
            mergeResult: mergeResult,
            deltas: [removeDelta],
            agents: ["memory.1": memory],
            graph: graph)
        XCTAssertTrue(outcomes[0].applied)
        // Verify tombstone (empty payload)
        let reader = BASAgentSpec(
            agentID: "reader.1",
            role: .planner,
            readDomains: [.memoryBundle],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        let obj = try await graph.readObject(
            ref: "memoryBundle#mb-1", byAgent: reader)
        XCTAssertEqual(obj.payloadJson, "",
            "ch 956.5 gap #2 REGRESSION: .remove must write " +
            "empty tombstone payload")
    }

    // MARK: - Gap #3: dependencies + conflictRefs actually used

    /// dependencies field actually drives processing order +
    /// dependency-unsatisfied rejection。
    func testGap3_DependencyUnsatisfiedRejectsDownstream() {
        // d1 conflicts with d2 — only one wins
        // d3 depends on d1
        // If d1 loses to d2 → d3 must be rejected (dep unsatisfied)
        let d1 = BASAgentDelta(
            deltaID: "d1", agentID: "low-prio.1",
            targetObjectRef: "candidateFrontier#cf-shared",
            deltaType: .add,
            confidence: 0.3)
        let d2 = BASAgentDelta(
            deltaID: "d2", agentID: "high-prio.1",
            targetObjectRef: "candidateFrontier#cf-shared",
            deltaType: .add,
            confidence: 0.9)
        let d3 = BASAgentDelta(
            deltaID: "d3", agentID: "downstream.1",
            targetObjectRef: "riskField#rf-1",
            deltaType: .add,
            confidence: 0.8,
            dependencies: ["delta:d1"])  // depends on losing d1
        let result = BASAgentMergeEngine.merge(
            [d1, d2, d3],
            context: BASMergePriorityContext(),
            turnID: "t1")
        XCTAssertTrue(
            result.acceptedDeltaIDs.contains("delta:d2"),
            "ch 956.5 gap #3: high-confidence d2 must win")
        XCTAssertTrue(
            result.rejectedDeltaIDs.contains("delta:d1"),
            "d1 must be rejected")
        XCTAssertTrue(
            result.rejectedDeltaIDs.contains("delta:d3"),
            "ch 956.5 gap #3 REGRESSION: d3 must be rejected " +
            "because its dependency d1 was rejected")
        XCTAssertTrue(
            result.conflictResolution.contains { audit in
                audit.contains("delta:d3") &&
                audit.contains("dependency-unsatisfied")
            },
            "ch 956.5 gap #3 REGRESSION: rejection reason " +
            "must include dependency-unsatisfied")
    }

    /// Dependency cycle → all participants rejected with
    /// dependency-cycle reason。
    func testGap3_DependencyCycleAllRejected() {
        let d1 = BASAgentDelta(
            deltaID: "d1", agentID: "a.1",
            targetObjectRef: "candidateFrontier#cf-1",
            deltaType: .add,
            confidence: 0.5,
            dependencies: ["delta:d2"])
        let d2 = BASAgentDelta(
            deltaID: "d2", agentID: "a.1",
            targetObjectRef: "candidateFrontier#cf-2",
            deltaType: .add,
            confidence: 0.5,
            dependencies: ["delta:d1"])
        let result = BASAgentMergeEngine.merge(
            [d1, d2],
            context: BASMergePriorityContext(),
            turnID: "t1")
        XCTAssertTrue(
            result.rejectedDeltaIDs.contains("delta:d1"))
        XCTAssertTrue(
            result.rejectedDeltaIDs.contains("delta:d2"))
        XCTAssertTrue(result.conflictResolution.contains { audit in
            audit.contains("delta:d1") &&
            audit.contains("dependency-cycle")
        })
    }

    /// Explicit conflictRefs causes loser demotion even when targets
    /// differ。
    func testGap3_ExplicitConflictRefsDemoteLoser() {
        let d1 = BASAgentDelta(
            deltaID: "d1", agentID: "high-prio.1",
            targetObjectRef: "candidateFrontier#cf-1",
            deltaType: .add,
            confidence: 0.9,
            conflictRefs: ["delta:d2"])
        let d2 = BASAgentDelta(
            deltaID: "d2", agentID: "low-prio.1",
            targetObjectRef: "riskField#rf-1",  // different target!
            deltaType: .add,
            confidence: 0.3,
            conflictRefs: ["delta:d1"])
        // No target conflict (different refs),but explicit
        // adversarial pair → tier-resolve and demote loser
        let result = BASAgentMergeEngine.merge(
            [d1, d2],
            context: BASMergePriorityContext(),
            turnID: "t1")
        XCTAssertTrue(
            result.acceptedDeltaIDs.contains("delta:d1"))
        XCTAssertTrue(
            result.rejectedDeltaIDs.contains("delta:d2"),
            "ch 956.5 gap #3 REGRESSION: explicit conflictRefs " +
            "must demote lower-confidence delta even when " +
            "targets differ")
        XCTAssertTrue(result.conflictResolution.contains { audit in
            audit.contains("explicit-conflict") &&
            audit.contains("loser=delta:d2")
        })
    }

    // MARK: - Gap #4: stronger mergeID (no collision)

    /// Pre-fix: `merge.<turnID>.<count>` collided when two merges
    /// in same turn had same delta count。 Post-fix: content hash
    /// suffix makes IDs unique per delta set。
    func testGap4_DifferentDeltaSetsProduceDifferentMergeIDs() {
        let delta1 = BASAgentDelta(
            deltaID: "alpha-1", agentID: "a",
            targetObjectRef: "candidateFrontier#x",
            deltaType: .add,
            confidence: 0.5)
        let delta2 = BASAgentDelta(
            deltaID: "beta-2", agentID: "a",
            targetObjectRef: "candidateFrontier#y",
            deltaType: .add,
            confidence: 0.5)
        let delta3 = BASAgentDelta(
            deltaID: "gamma-3", agentID: "a",
            targetObjectRef: "candidateFrontier#z",
            deltaType: .add,
            confidence: 0.5)
        let r1 = BASAgentMergeEngine.merge(
            [delta1, delta2],
            context: BASMergePriorityContext(),
            turnID: "t1")
        let r2 = BASAgentMergeEngine.merge(
            [delta1, delta3],  // SAME count, DIFFERENT delta IDs
            context: BASMergePriorityContext(),
            turnID: "t1")
        XCTAssertNotEqual(r1.mergeID, r2.mergeID,
            "ch 956.5 gap #4 REGRESSION: different delta sets " +
            "with same turnID + count must have different " +
            "mergeIDs (was collision: \(r1.mergeID))")
    }

    /// Same input → same mergeID (deterministic content hash)。
    func testGap4_SameInputSameMergeID() {
        let delta = BASAgentDelta(
            deltaID: "d1", agentID: "a",
            targetObjectRef: "candidateFrontier#x",
            deltaType: .add,
            confidence: 0.5)
        let r1 = BASAgentMergeEngine.merge(
            [delta],
            context: BASMergePriorityContext(),
            turnID: "t1")
        let r2 = BASAgentMergeEngine.merge(
            [delta],
            context: BASMergePriorityContext(),
            turnID: "t1")
        XCTAssertEqual(r1.mergeID, r2.mergeID)
        XCTAssertTrue(
            r1.mergeID.hasPrefix("merge.t1.1."),
            "mergeID format prefix preserved")
    }

    // MARK: - Gap #5: real createdAtNanos timestamp recency

    /// Pre-fix: tie-break used lex deltaID。 Post-fix: when all other
    /// dims tie, HIGHER createdAtNanos wins (more recent)。
    func testGap5_RealTimestampWinsOverLexDeltaIDOnTie() {
        // Both same tier, same priority, same confidence
        // d-zzz has EARLIER timestamp; d-aaa has LATER timestamp
        // Pre-fix: d-aaa wins by lex < d-zzz
        // Post-fix: d-aaa wins because it's MORE RECENT (timestamp)
        let dOld = BASAgentDelta(
            deltaID: "d-aaa-old",
            agentID: "a",
            targetObjectRef: "candidateFrontier#x",
            deltaType: .add,
            confidence: 0.5,
            createdAtNanos: 1_000_000_000_000_000_000)
        let dNew = BASAgentDelta(
            deltaID: "d-zzz-new",
            agentID: "a",
            targetObjectRef: "candidateFrontier#x",
            deltaType: .add,
            confidence: 0.5,
            createdAtNanos: 2_000_000_000_000_000_000)
        let result = BASAgentMergeEngine.merge(
            [dOld, dNew],
            context: BASMergePriorityContext(),
            turnID: "t1")
        XCTAssertEqual(
            result.acceptedDeltaIDs, ["delta:d-zzz-new"],
            "ch 956.5 gap #5 REGRESSION: HIGHER createdAtNanos " +
            "(more recent) must beat lex-smaller deltaID")
    }

    /// When BOTH deltas have createdAtNanos=0 (legacy), fall back
    /// to lex deltaID for determinism。
    func testGap5_LegacyZeroTimestampFallsBackToLexDeltaID() {
        let dA = BASAgentDelta(
            deltaID: "d-aaa",
            agentID: "a",
            targetObjectRef: "candidateFrontier#x",
            deltaType: .add,
            confidence: 0.5,
            createdAtNanos: 0)  // legacy / unknown
        let dZ = BASAgentDelta(
            deltaID: "d-zzz",
            agentID: "a",
            targetObjectRef: "candidateFrontier#x",
            deltaType: .add,
            confidence: 0.5,
            createdAtNanos: 0)
        let result = BASAgentMergeEngine.merge(
            [dA, dZ],
            context: BASMergePriorityContext(),
            turnID: "t1")
        // Both 0 → fall back to lex,d-aaa wins
        XCTAssertEqual(
            result.acceptedDeltaIDs, ["delta:d-aaa"])
    }

    // MARK: - Cumulative invariant: all 5 fixes together don't break

    /// End-to-end:5-delta scenario exercising all 5 fixes in one
    /// merge call。
    func testCumulativeAllFiveFixesIntegrated() async throws {
        let graph = BASSharedStateGraph()
        try await graph.registerWriter(
            agentID: "planner.1",
            domain: .candidateFrontier)
        try await graph.registerWriter(
            agentID: "memory.1",
            domain: .memoryBundle)
        let planner = BASAgentSpec(
            agentID: "planner.1",
            role: .planner,
            writeDomains: [.candidateFrontier],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        let memory = BASAgentSpec(
            agentID: "memory.1",
            role: .memory,
            writeDomains: [.memoryBundle],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        let d1 = BASAgentDelta(
            deltaID: "d1",
            agentID: "planner.1",
            targetObjectRef: "candidateFrontier#cf-1",
            deltaType: .add,
            patchJson: "{\"v\":1}",
            confidence: 0.7,
            createdAtNanos: 1_700_000_000_000_000_000)
        let d2 = BASAgentDelta(
            deltaID: "d2",
            agentID: "memory.1",
            targetObjectRef: "memoryBundle#mb-1",
            deltaType: .add,
            patchJson: "{\"episode\":\"abc\"}",
            confidence: 0.9,
            createdAtNanos: 1_700_000_000_000_000_001,
            dependencies: ["delta:d1"])  // gap #3
        let result = BASAgentMergeEngine.merge(
            [d1, d2],
            context: BASMergePriorityContext(),
            turnID: "t-integ")
        // gap #4: strong mergeID
        XCTAssertTrue(
            result.mergeID.hasPrefix("merge.t-integ.2."))
        XCTAssertEqual(
            result.mergeID.split(separator: ".").count, 4)
        // gap #2 + #3: apply with dep ordering
        let outcomes = await BASAgentMergeApplier.apply(
            mergeResult: result,
            deltas: [d1, d2],
            agents: [
                "planner.1": planner,
                "memory.1": memory,
            ],
            graph: graph)
        XCTAssertEqual(outcomes.count, 2)
        for o in outcomes {
            XCTAssertTrue(o.applied,
                "delta \(o.deltaID) should apply: \(o.errorReason)")
        }
    }
}
