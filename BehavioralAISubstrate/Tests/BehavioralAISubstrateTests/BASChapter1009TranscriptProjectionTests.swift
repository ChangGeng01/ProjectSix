// MARK: - BASChapter1009TranscriptProjectionTests
// chapter 一千零九 / M3750 — `Gate.TranscriptMode` per-agent
// summary projection
//
// Pre-ch-1009: `BASAgentFabricGate.TranscriptMode.{singleAgent,
// compareAll,compareSelected}` shipped at ch 993 as
// host-observable signal,parsed into Activation,surfaced in
// diagnostics,but NO substrate-side branch — decorative echo
// per ch 995.5。
//
// Full multi-chapter wire (per-agent transcript output paths
// with new BASRenderFrame variants) is Phase 9+。 But a real
// SUBSTRATE-side substantive output difference IS achievable
// today: produce a per-agent activity summary that differs by
// mode。
//
// Tests pin:
//   1. `.singleAgent` produces nil (byte-equal back-compat)
//   2. `.compareAll` produces summary covering all agents
//   3. `.compareSelected` scopes to selectedAgents only
//   4. perAgent entries sorted by agentID (byte-equal)
//   5. delta types sorted within each entry
//   6. totalDeltas correctly aggregates after scope filter
//   7. mode rawValue echoed in result
//   8. CRITICAL: same input produces byte-equal output
//      across calls (strong-mergeID-hash equivalent)

import XCTest
@testable import BASMemory
@testable import BASHostKit

final class BASChapter1009TranscriptProjectionTests: XCTestCase {

    private static func makeDelta(
        agent: String,
        deltaType: BASAgentDeltaType = .merge
    ) -> BASAgentDelta {
        BASAgentDelta(
            deltaID: "delta.\(agent).\(deltaType.rawValue)",
            agentID: agent,
            targetObjectRef: "candidateFrontier#test",
            deltaType: deltaType,
            patchJson: "{}",
            confidence: 0.5)
    }

    // MARK: - 1. singleAgent → nil

    func testCRITICAL_SingleAgent_ReturnsNil() {
        let deltas = [
            Self.makeDelta(agent: "planner"),
            Self.makeDelta(agent: "critic"),
        ]
        let result = BASAgentFabricTranscriptProjection
            .summarize(
                deltas: deltas,
                mode: .singleAgent)
        XCTAssertNil(result,
            "ch 1009 CRITICAL: .singleAgent MUST return nil " +
            "(byte-equal back-compat pre-ch-1009 behavior)")
    }

    // MARK: - 2. compareAll covers all agents

    func testCRITICAL_CompareAll_CoversAllAgents() {
        let deltas = [
            Self.makeDelta(agent: "planner", deltaType: .add),
            Self.makeDelta(agent: "planner", deltaType: .merge),
            Self.makeDelta(agent: "critic", deltaType: .merge),
            Self.makeDelta(agent: "risk", deltaType: .merge),
        ]
        let result = BASAgentFabricTranscriptProjection
            .summarize(
                deltas: deltas,
                mode: .compareAll)
        XCTAssertNotNil(result)
        guard let summary = result else { return }
        XCTAssertEqual(summary.perAgent.count, 3,
            "ch 1009 CRITICAL: compareAll MUST cover all 3 " +
            "agents")
        XCTAssertEqual(summary.totalDeltas, 4)
        XCTAssertEqual(
            summary.modeRawValue, "compareAll")
        XCTAssertEqual(summary.selectedAgents, [],
            "ch 1009: compareAll has no selectedAgents scope")
    }

    // MARK: - 3. compareSelected scopes

    func testCRITICAL_CompareSelected_ScopesToList() {
        let deltas = [
            Self.makeDelta(agent: "planner"),
            Self.makeDelta(agent: "critic"),
            Self.makeDelta(agent: "memory"),
            Self.makeDelta(agent: "risk"),
        ]
        let result = BASAgentFabricTranscriptProjection
            .summarize(
                deltas: deltas,
                mode: .compareSelected,
                selectedAgents: ["planner", "critic"])
        guard let summary = result else {
            XCTFail("ch 1009: compareSelected MUST produce " +
                "summary")
            return
        }
        XCTAssertEqual(summary.perAgent.count, 2,
            "ch 1009: compareSelected MUST exclude memory + " +
            "risk (not in selectedAgents)")
        XCTAssertEqual(summary.totalDeltas, 2)
        XCTAssertEqual(
            summary.selectedAgents.sorted(),
            ["critic", "planner"],
            "ch 1009: selectedAgents echo MUST be sorted + " +
            "lowercased for byte-equal output")
    }

    // MARK: - 4 + 5. Sorting determinism

    func test_PerAgentEntries_SortedByAgentID() {
        let deltas = [
            Self.makeDelta(agent: "zebra"),
            Self.makeDelta(agent: "alpha"),
            Self.makeDelta(agent: "midway"),
        ]
        let result = BASAgentFabricTranscriptProjection
            .summarize(deltas: deltas, mode: .compareAll)
        guard let summary = result else { return }
        XCTAssertEqual(summary.perAgent[0].agentID, "alpha")
        XCTAssertEqual(summary.perAgent[1].agentID, "midway")
        XCTAssertEqual(summary.perAgent[2].agentID, "zebra")
    }

    func test_DeltaTypes_SortedWithinEntry() {
        let deltas = [
            Self.makeDelta(
                agent: "planner", deltaType: .merge),
            Self.makeDelta(
                agent: "planner", deltaType: .add),
            Self.makeDelta(
                agent: "planner", deltaType: .replace),
        ]
        let result = BASAgentFabricTranscriptProjection
            .summarize(deltas: deltas, mode: .compareAll)
        guard let summary = result else { return }
        XCTAssertEqual(summary.perAgent.count, 1)
        XCTAssertEqual(
            summary.perAgent[0].deltaTypes,
            ["add", "merge", "replace"],
            "ch 1009: deltaTypes within agent entry MUST be " +
            "sorted alphabetically for byte-equal output")
    }

    // MARK: - 6. Total correctly aggregates

    func test_TotalDeltas_AggregatesAfterScopeFilter() {
        let deltas = (0..<10).map { i in
            Self.makeDelta(
                agent: i < 3 ? "planner" :
                       i < 6 ? "critic" : "memory")
        }
        // Scope to only planner + critic
        let result = BASAgentFabricTranscriptProjection
            .summarize(
                deltas: deltas,
                mode: .compareSelected,
                selectedAgents: ["planner", "critic"])
        guard let summary = result else { return }
        XCTAssertEqual(summary.totalDeltas, 6,
            "ch 1009: totalDeltas MUST count only deltas " +
            "passing the scope filter (3 planner + 3 critic = 6, " +
            "not 10)")
    }

    // MARK: - 7. Mode echo

    func test_ModeRawValue_EchoedInResult() {
        let result = BASAgentFabricTranscriptProjection
            .summarize(
                deltas: [Self.makeDelta(agent: "p")],
                mode: .compareAll)
        XCTAssertEqual(result?.modeRawValue, "compareAll")
    }

    // MARK: - 8. Byte-equal output

    func testCRITICAL_SameInput_ProducesByteEqualOutput() {
        let deltas = [
            Self.makeDelta(agent: "planner", deltaType: .add),
            Self.makeDelta(agent: "critic", deltaType: .merge),
        ]
        let r1 = BASAgentFabricTranscriptProjection
            .summarize(deltas: deltas, mode: .compareAll)
        let r2 = BASAgentFabricTranscriptProjection
            .summarize(deltas: deltas, mode: .compareAll)
        XCTAssertEqual(r1, r2,
            "ch 1009 CRITICAL: same input MUST produce " +
            "byte-equal output across calls (strong-mergeID-" +
            "hash equivalent determinism)")
    }
}
