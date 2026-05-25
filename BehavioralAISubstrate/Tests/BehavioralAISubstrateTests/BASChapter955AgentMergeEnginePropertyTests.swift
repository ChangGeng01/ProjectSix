// MARK: - BASChapter955AgentMergeEnginePropertyTests
// chapter 九百五十五 / M3480 (Phase 0 / ch3)
//
// Property tests for BASAgentMergeEngine pure-function merge。 Per
// plan ch 955 knife 4: property test 10K random delta sets,assert
// priority invariants。
//
// Reduced to 100 here for local CI; device runs via env scaling。
//
// Invariants asserted:
//   1. Same input → same output (purity / determinism)
//   2. Sovereign tier ALWAYS beats lower tiers in conflict
//   3. Within tier, higher agentPriority wins
//   4. Within priority, higher confidence wins
//   5. Within confidence, lex-smaller deltaID wins (determinism)
//   6. Non-conflicting deltas all accepted
//   7. Empty input → empty result
//   8. Single delta → accepted

import XCTest
@testable import BASMemory

final class BASChapter955AgentMergeEnginePropertyTests:
    XCTestCase
{

    // MARK: - Helpers

    private func mkDelta(
        id: String,
        agent: String = "a",
        target: String = "candidateFrontier#cf",
        confidence: Double = 0.5,
        type: BASAgentDeltaType = .add
    ) -> BASAgentDelta {
        BASAgentDelta(
            deltaID: id,
            agentID: agent,
            targetObjectRef: target,
            deltaType: type,
            patchJson: "{}",
            confidence: confidence,
            reasonCodes: [],
            dependencies: [],
            conflictRefs: [])
    }

    // MARK: - 1. Determinism

    func testSameInputSameOutput() {
        let deltas = [
            mkDelta(id: "d1", agent: "planner.1",
                    target: "candidateFrontier#cf-1"),
            mkDelta(id: "d2", agent: "critic.1",
                    target: "candidateFrontier#cf-1"),
        ]
        let ctx = BASMergePriorityContext(
            sovereignAgentIDs: [],
            riskAgentIDs: [],
            hostAgentIDs: [],
            agentPriorities: ["planner.1": 5, "critic.1": 3])
        let r1 = BASAgentMergeEngine.merge(
            deltas, context: ctx, turnID: "t1")
        let r2 = BASAgentMergeEngine.merge(
            deltas, context: ctx, turnID: "t1")
        XCTAssertEqual(r1, r2)
    }

    // MARK: - 2. Sovereign beats everything

    func testSovereignBeatsAllOtherTiers() {
        let deltas = [
            mkDelta(id: "d-evidence", agent: "planner.1",
                    target: "x#1", confidence: 0.9),
            mkDelta(id: "d-host", agent: "host.1",
                    target: "x#1", confidence: 0.7),
            mkDelta(id: "d-risk", agent: "risk.1",
                    target: "x#1", confidence: 0.6),
            mkDelta(id: "d-sovereign", agent: "sovereign.1",
                    target: "x#1", confidence: 0.1),
        ]
        let ctx = BASMergePriorityContext(
            sovereignAgentIDs: ["sovereign.1"],
            riskAgentIDs: ["risk.1"],
            hostAgentIDs: ["host.1"],
            agentPriorities: [:])
        let result = BASAgentMergeEngine.merge(
            deltas, context: ctx, turnID: "t1")
        XCTAssertEqual(result.acceptedDeltaIDs,
                       ["delta:d-sovereign"])
        XCTAssertEqual(Set(result.rejectedDeltaIDs), Set([
            "delta:d-evidence", "delta:d-host", "delta:d-risk",
        ]))
    }

    // MARK: - 3. Within-tier priority

    func testHigherAgentPriorityWinsWithinTier() {
        // Both planner.1 + planner.2 are evidence-tier;
        // tie-break on agentPriority then confidence
        let deltas = [
            mkDelta(id: "d-lowprio", agent: "planner.1",
                    target: "x#1", confidence: 0.9),
            mkDelta(id: "d-highprio", agent: "planner.2",
                    target: "x#1", confidence: 0.9),
        ]
        let ctx = BASMergePriorityContext(
            agentPriorities: [
                "planner.1": 1, "planner.2": 10,
            ])
        let result = BASAgentMergeEngine.merge(
            deltas, context: ctx, turnID: "t1")
        XCTAssertEqual(result.acceptedDeltaIDs,
                       ["delta:d-highprio"])
    }

    // MARK: - 4. Within-priority confidence

    func testHigherConfidenceWinsWithinPriority() {
        let deltas = [
            mkDelta(id: "d-low", agent: "a",
                    target: "x#1", confidence: 0.6),
            mkDelta(id: "d-high", agent: "a",
                    target: "x#1", confidence: 0.95),
        ]
        let ctx = BASMergePriorityContext(
            agentPriorities: ["a": 5])
        let result = BASAgentMergeEngine.merge(
            deltas, context: ctx, turnID: "t1")
        XCTAssertEqual(result.acceptedDeltaIDs,
                       ["delta:d-high"])
    }

    // MARK: - 5. Lex-smaller deltaID wins on full tie

    func testLexicographicTieBreak() {
        let deltas = [
            mkDelta(id: "z", agent: "a",
                    target: "x#1", confidence: 0.7),
            mkDelta(id: "a", agent: "a",
                    target: "x#1", confidence: 0.7),
        ]
        let ctx = BASMergePriorityContext()
        let result = BASAgentMergeEngine.merge(
            deltas, context: ctx, turnID: "t1")
        XCTAssertEqual(result.acceptedDeltaIDs, ["delta:a"])
    }

    // MARK: - 6. Non-conflicting deltas all accepted

    func testNonConflictingDeltasAllAccepted() {
        let deltas = [
            mkDelta(id: "d1", target: "candidateFrontier#cf-1"),
            mkDelta(id: "d2", target: "candidateFrontier#cf-2"),
            mkDelta(id: "d3", target: "riskField#rf-1"),
            mkDelta(id: "d4", target: "memoryBundle#mb-1"),
        ]
        let ctx = BASMergePriorityContext()
        let result = BASAgentMergeEngine.merge(
            deltas, context: ctx, turnID: "t1")
        XCTAssertEqual(result.acceptedDeltaIDs.count, 4)
        XCTAssertTrue(result.rejectedDeltaIDs.isEmpty)
        XCTAssertTrue(result.conflictResolution.isEmpty)
    }

    // MARK: - 7. Empty input

    func testEmptyInputReturnsEmptyResult() {
        let ctx = BASMergePriorityContext()
        let result = BASAgentMergeEngine.merge(
            [], context: ctx, turnID: "t1")
        XCTAssertTrue(result.acceptedDeltaIDs.isEmpty)
        XCTAssertTrue(result.rejectedDeltaIDs.isEmpty)
    }

    // MARK: - 8. Single delta

    func testSingleDeltaAccepted() {
        let ctx = BASMergePriorityContext()
        let result = BASAgentMergeEngine.merge(
            [mkDelta(id: "only")],
            context: ctx, turnID: "t1")
        XCTAssertEqual(result.acceptedDeltaIDs, ["delta:only"])
    }

    // MARK: - 9. Tier ordering invariant (10K-iter fuzz, reduced to 100)

    /// Per plan: 10K random delta sets。 Reduced to 100 for CI;
    /// device run can scale via BAS_FUZZ_ITER env。
    ///
    /// Invariant: for any conflict group,the accepted delta MUST
    /// have tier ≥ every other delta in the group。
    func testFuzzTierOrderingInvariant() {
        let iters = Self.fuzzIterCount
        for i in 0..<iters {
            var rng = BASFuzzRng(seed: testSeed(iteration: i))
            let ctx = procGenContext(rng: &rng)
            let deltaCount = rng.nextInt(in: 2...10)
            // Force all to same target so they form one conflict
            // group (otherwise fuzz might generate all-distinct
            // targets → no conflicts → trivial pass)
            let target = "candidateFrontier#cf-\(i)"
            let agentPool = [
                "planner.1", "critic.1", "memory.1", "risk.1",
                "host.1", "sovereign.1", "evolution.1",
            ]
            let deltas = (0..<deltaCount).map { j in
                mkDelta(
                    id: "d-\(i)-\(j)",
                    agent: rng.pick(agentPool),
                    target: target,
                    confidence:
                        Double(rng.nextFloat(in: 0...1)))
            }
            let result = BASAgentMergeEngine.merge(
                deltas, context: ctx, turnID: "t-\(i)")
            XCTAssertEqual(result.acceptedDeltaIDs.count, 1,
                "iter=\(i): conflict group should yield 1 accept")
            // Get accepted delta
            let acceptedID =
                result.acceptedDeltaIDs[0]
                    .replacingOccurrences(of: "delta:", with: "")
            let accepted = deltas.first {
                $0.deltaID == acceptedID
            }!
            let acceptedTier = BASAgentMergeEngine.tier(
                for: accepted, in: ctx)
            // Assert no other delta in the group has HIGHER tier
            for d in deltas where d.deltaID != acceptedID {
                let t = BASAgentMergeEngine.tier(for: d, in: ctx)
                XCTAssertGreaterThanOrEqual(
                    acceptedTier.rawValue, t.rawValue,
                    "iter=\(i): accepted tier \(acceptedTier) " +
                    "< competitor tier \(t)")
            }
        }
    }

    // MARK: - 10. mergeID + reasonCodes format

    func testMergeReasonCodesEmitted() {
        let deltas = [
            mkDelta(id: "d1", agent: "planner.1",
                    target: "x#1"),
            mkDelta(id: "d2", agent: "planner.1",
                    target: "x#1"),  // conflict
        ]
        let result = BASAgentMergeEngine.merge(
            deltas, context: BASMergePriorityContext(),
            turnID: "t1")
        XCTAssertTrue(result.mergeReasonCodes.contains(where: {
            $0.hasPrefix("merge.conflicts-resolved=")
        }))
        XCTAssertTrue(result.mergeReasonCodes.contains(
            "merge.priority=sovereign-risk-host-evidence-agent-recency"
        ))
        XCTAssertFalse(result.conflictResolution.isEmpty)
    }

    // MARK: - Proc-gen helpers

    private static let fuzzIterCount: Int = {
        if let env = ProcessInfo.processInfo
            .environment["BAS_FUZZ_ITER"],
           let n = Int(env), n > 0 { return n }
        return 100
    }()

    private func procGenContext(
        rng: inout BASFuzzRng
    ) -> BASMergePriorityContext {
        let agentPool = [
            "planner.1", "critic.1", "memory.1", "risk.1",
            "host.1", "sovereign.1", "evolution.1",
        ]
        var sovereign: Set<String> = []
        var risk: Set<String> = []
        var host: Set<String> = []
        if rng.nextBool(p: 0.7) { sovereign.insert("sovereign.1") }
        if rng.nextBool(p: 0.7) { risk.insert("risk.1") }
        if rng.nextBool(p: 0.7) { host.insert("host.1") }
        var priorities: [String: Int] = [:]
        for a in agentPool {
            priorities[a] = rng.nextInt(in: 0...20)
        }
        return BASMergePriorityContext(
            sovereignAgentIDs: sovereign,
            riskAgentIDs: risk,
            hostAgentIDs: host,
            agentPriorities: priorities,
            evidenceConfidenceFloor:
                Double(rng.nextFloat(in: 0.3...0.7)))
    }
}
