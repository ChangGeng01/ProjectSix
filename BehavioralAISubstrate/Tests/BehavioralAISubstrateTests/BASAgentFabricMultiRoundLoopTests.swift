// arc ③ — proofs for the Agent Fabric MULTI-ROUND AUTHORITATIVE loop.
//
// Proves the loop is byte-equal-off (.observationOnly ⇒ inert, dispatch never called), deterministic,
// converges on a digest fixpoint, respects the budget cap (terminates even when never converging),
// early-stops on a nil projection, pins nowNanos + per-round turnID (no wall-clock), threads the refine
// seam, drives the real runtime via the live overload, and that its converged output flows through the
// existing host feed-forward into the SAME verdict-gated cascade (the sovereign verdict stays sole
// authority — input-class, 红线 7 / 不变量 #2).

import XCTest
import Foundation
@testable import BASHostKit
@testable import BASMemory

#if !os(iOS) // ch1022 source-gate parity (mirrors BASAgentFabricAuthoritativeProjectionTests)
final class BASAgentFabricMultiRoundLoopTests: XCTestCase {

    // MARK: - deterministic stub fabric (no live LLM seats)

    /// Drives each round's output by a `plan(round) -> (emittedID, accepted)` so tests control
    /// convergence/divergence; records every input seen (spy for byte-equal-off + nowNanos/turnID).
    private final class StubFabric: @unchecked Sendable {
        private(set) var seen: [BASAgentTurnInput] = []
        private let plan: (Int) -> (emittedID: String, accepted: [String])
        init(_ plan: @escaping (Int) -> (emittedID: String, accepted: [String])) { self.plan = plan }

        func dispatch(_ input: BASAgentTurnInput) -> BASAgentTurnResult {
            let round = seen.count
            seen.append(input)
            let (id, accepted) = plan(round)
            let emitted = accepted.isEmpty ? [] : [Self.delta(id)]
            return Self.result(emitted: emitted, accepted: accepted)
        }

        static func delta(_ id: String) -> BASAgentDelta {
            BASAgentDelta(
                deltaID: id, agentID: "planner",
                targetObjectRef: "candidateFrontier#obj-\(id)",
                deltaType: .replace, patchJson: "{\"k\":\"\(id)\"}",
                confidence: 0.9, createdAtNanos: 0,
                reasonCodes: ["planner.primary"], dependencies: [], conflictRefs: [])
        }
        static func result(emitted: [BASAgentDelta], accepted: [String]) -> BASAgentTurnResult {
            BASAgentTurnResult(
                emittedDeltas: emitted,
                mergeResult: BASAgentMergeResult(
                    mergeID: "m", acceptedDeltaIDs: accepted, rejectedDeltaIDs: [],
                    conflictResolution: [], resultingStateRef: "candidateFrontier#obj",
                    mergeReasonCodes: []),
                applyOutcomes: [], finalSeq: emitted.count, evidenceDebt: .empty)
        }
    }

    private func config(_ maxRounds: Int, nowNanos: Int64 = 1_700_000_000)
        -> BASAgentFabricMultiRoundConfig {
        BASAgentFabricMultiRoundConfig(maxRounds: maxRounds, baseTurnID: "T", nowNanos: nowNanos)
    }

    // MARK: - byte-equal-off

    func testObservationOnlyIsInertAndNeverDispatches() async {
        let stub = StubFabric { _ in ("const", ["const"]) }
        let r = await BASAgentFabricMultiRoundLoop.run(
            mode: .observationOnly, initialInput: BASAgentTurnInput(turnID: "T"),
            config: config(5), dispatch: { stub.dispatch($0) })
        XCTAssertEqual(r.roundsRun, 0)
        XCTAssertNil(r.finalProjection)
        XCTAssertEqual(r.stopReason, "mode-inert")
        XCTAssertTrue(stub.seen.isEmpty, "dispatch must NEVER be called when off (byte-equal-off)")
    }

    // MARK: - determinism

    func testDeterministicAcrossRuns() async {
        func once() async -> BASAgentFabricMultiRoundResult {
            let stub = StubFabric { round in round == 0 ? ("a", ["a"]) : ("b", ["b"]) }
            return await BASAgentFabricMultiRoundLoop.run(
                mode: .authoritative, initialInput: BASAgentTurnInput(turnID: "T"),
                config: config(8), dispatch: { stub.dispatch($0) })
        }
        let r1 = await once()
        let r2 = await once()
        XCTAssertEqual(r1, r2, "same stub + config ⇒ identical multi-round result")
    }

    // MARK: - convergence

    func testReachesDigestFixpoint() async {
        let stub = StubFabric { _ in ("const", ["const"]) }
        let r = await BASAgentFabricMultiRoundLoop.run(
            mode: .authoritative, initialInput: BASAgentTurnInput(turnID: "T"),
            config: config(10), dispatch: { stub.dispatch($0) })
        XCTAssertTrue(r.converged)
        XCTAssertEqual(r.stopReason, "digest-fixpoint")
        XCTAssertEqual(r.roundsRun, 2, "constant conclusion ⇒ fixpoint detected on round 2")
        XCTAssertNotNil(r.finalProjection)
    }

    func testBudgetCapTerminatesAndRefineIsWired() async {
        final class Counter: @unchecked Sendable { var refineCalls = 0 }
        let counter = Counter()
        // Ever-changing conclusion ⇒ never a fixpoint ⇒ must hit the cap.
        let stub = StubFabric { round in ("r\(round)", ["r\(round)"]) }
        let r = await BASAgentFabricMultiRoundLoop.run(
            mode: .authoritative, initialInput: BASAgentTurnInput(turnID: "T"),
            config: config(4),
            dispatch: { stub.dispatch($0) },
            refine: { input, _ in counter.refineCalls += 1; return input })
        XCTAssertEqual(r.roundsRun, 4)
        XCTAssertFalse(r.converged)
        XCTAssertEqual(r.stopReason, "budget-cap")
        XCTAssertEqual(r.perRoundDigests.count, 4)
        XCTAssertEqual(Set(r.perRoundDigests).count, 4, "each round's digest is distinct (ever-changing)")
        XCTAssertEqual(counter.refineCalls, 4, "refine is threaded once per non-terminal round")
    }

    func testDetectsDigestCycleBeforeBudgetCap() async {
        // Oscillating accepted-set A,B,A,B… → a 2-cycle the budget cap would otherwise burn through.
        let stub = StubFabric { round in round % 2 == 0 ? ("a", ["a"]) : ("b", ["b"]) }
        let r = await BASAgentFabricMultiRoundLoop.run(
            mode: .authoritative, initialInput: BASAgentTurnInput(turnID: "T"),
            config: config(20), dispatch: { stub.dispatch($0) })
        XCTAssertEqual(r.stopReason, "digest-cycle")
        XCTAssertFalse(r.converged, "a 2-cycle is bounded but not a single fixpoint")
        XCTAssertEqual(r.roundsRun, 3,
            "cycle detected when digest A reappears (round 3), not at the cap (20)")
        XCTAssertLessThan(r.roundsRun, 20, "stopped well before the budget cap")
    }

    func testNilProjectionEarlyStop() async {
        let stub = StubFabric { _ in ("x", []) } // no accepted deltas ⇒ projection nil
        let r = await BASAgentFabricMultiRoundLoop.run(
            mode: .authoritative, initialInput: BASAgentTurnInput(turnID: "T"),
            config: config(5), dispatch: { stub.dispatch($0) })
        XCTAssertEqual(r.roundsRun, 1)
        XCTAssertNil(r.finalProjection)
        XCTAssertEqual(r.stopReason, "nil-projection")
    }

    // MARK: - determinism surface: pinned nowNanos + per-round turnID

    func testStampsPinnedNowNanosAndPerRoundTurnID() async {
        let stub = StubFabric { round in ("r\(round)", ["r\(round)"]) }
        _ = await BASAgentFabricMultiRoundLoop.run(
            mode: .authoritative,
            initialInput: BASAgentTurnInput(turnID: "ignored", nowNanos: 999),
            config: config(3, nowNanos: 42),
            dispatch: { stub.dispatch($0) })
        XCTAssertEqual(stub.seen.map(\.turnID), ["T#r0", "T#r1", "T#r2"],
            "each round runs under a deterministic per-round turnID")
        XCTAssertTrue(stub.seen.allSatisfy { $0.nowNanos == 42 },
            "every round stamped with the PINNED nowNanos (no wall-clock in the loop)")
    }

    // MARK: - sovereign: the loop's output flows through the verdict-gated cascade

    func testFinalProjectionFlowsThroughVerdictGatedCascade() async throws {
        let stub = StubFabric { _ in ("frontier-1", ["frontier-1"]) }
        let r = await BASAgentFabricMultiRoundLoop.run(
            mode: .authoritative, initialInput: BASAgentTurnInput(turnID: "T"),
            config: config(5), dispatch: { stub.dispatch($0) })
        let proj = try XCTUnwrap(r.finalProjection)

        let base = BASCoordinatorTestStubs.makeStubRequest(userInput: "hi")
        let enriched = BASAgentFabricAuthoritativeProjection.enrichedRequest(base, with: proj)
        XCTAssertNotEqual(enriched.userInput, base.userInput,
            "the loop's converged conclusions fold into the next userInput (authoritative effect)")

        // Fresh real brains; decomposeFrame is input-derived + deterministic (mirrors the projection test).
        let brainA = try await BASCognitiveBrain.makeWithDefaults()
        let brainB = try await BASCognitiveBrain.makeWithDefaults()
        let plain = await brainA.process(base.userInput)
        let enr = await brainB.process(enriched.userInput)
        XCTAssertNotEqual(plain.decomposeFrame, enr.decomposeFrame,
            "the folded fabric conclusions change what the cascade derives")
        XCTAssertNotNil(enr.sovereignVerdict,
            "the sovereign verdict still runs on the enriched turn — verdict path intact (sole authority)")
    }

    // MARK: - live-fabric overload (real runtime + in-memory graph)

    private func authoritativeRuntime() -> BASAgentFabricRuntime {
        BASAgentFabricRuntime(
            roster: BASAgentTurnRoster(
                scout: BASAgentSpec(
                    agentID: "scout.1", role: .scout, writeDomains: [.situationField],
                    defaultLeaseProfile: .hotSeat, visibility: .high),
                planner: BASAgentSpec(
                    agentID: "planner.1", role: .planner, writeDomains: [.candidateFrontier],
                    defaultLeaseProfile: .hotSeat, visibility: .high),
                risk: BASAgentSpec(
                    agentID: "risk.1", role: .risk, writeDomains: [.riskField],
                    defaultLeaseProfile: .hotSeat, visibility: .high),
                surface: BASAgentSpec(
                    agentID: "surface.1", role: .surface, writeDomains: [.renderFrame],
                    defaultLeaseProfile: .hotSeat, visibility: .high)),
            graph: BASSharedStateGraph(),
            mode: .authoritative)
    }

    func testLiveRuntimeOverloadTerminatesDeterministically() async {
        func once() async -> BASAgentFabricMultiRoundResult {
            await BASAgentFabricMultiRoundLoop.run(
                runtime: authoritativeRuntime(),
                initialInput: BASAgentTurnInput(turnID: "T"),
                config: config(4))
        }
        let r1 = await once()
        let r2 = await once()
        // Binds + terminates within the cap, whatever the seats emit.
        XCTAssertGreaterThanOrEqual(r1.roundsRun, 1)
        XCTAssertLessThanOrEqual(r1.roundsRun, 4)
        XCTAssertEqual(r1.roundsRun, r2.roundsRun, "the live overload is deterministic across runs")
        XCTAssertEqual(r1.perRoundDigests, r2.perRoundDigests)
        XCTAssertEqual(r1.stopReason, r2.stopReason)
        // Non-vacuity (B4 / audit ch1040): assert the CONCRETE terminal outcome, not just the
        // round bounds — otherwise a regression that made the real fabric stop at "nil-projection"
        // or run to the budget cap would still pass this "live" test green. The surface seat
        // always emits, so the loop reaches a content-digest fixpoint with a usable projection.
        XCTAssertTrue(r1.converged, "stable seat output ⇒ the live loop converges")
        XCTAssertEqual(r1.stopReason, "digest-fixpoint")
        XCTAssertNotNil(r1.finalProjection, "a converged authoritative loop yields a projection")
    }

    func testLiveRuntimeObservationOnlyIsInert() async {
        let runtime = BASAgentFabricRuntime(
            roster: authoritativeRuntime().roster,
            graph: BASSharedStateGraph(),
            mode: .observationOnly)
        let r = await BASAgentFabricMultiRoundLoop.run(
            runtime: runtime, initialInput: BASAgentTurnInput(turnID: "T"), config: config(4))
        XCTAssertEqual(r.roundsRun, 0)
        XCTAssertEqual(r.stopReason, "mode-inert")
        XCTAssertNil(r.finalProjection)
    }
}
#endif
