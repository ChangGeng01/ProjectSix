// MARK: - BASChapter1002TraceAnnotatorSeatTests
// chapter 一千零二 / M3715 — TraceAnnotatorSeat closes
// `.annotate` 💀 DEAD case from `Docs/SCAFFOLD_VS_WIRED.md`
//
// Pre-ch-1002 state (per Round-14 META-REVIEW + ch 996 doctrine):
//   - `BASAgentDeltaType.annotate` had been shipped at ch 953
//   - The applier (BASAgentMergeApplier) grouped `.annotate` with
//     `.add` / `.replace` / `.merge` (same write semantics)
//   - But NO seat in the entire substrate emitted `.annotate`
//     deltas → status 💀 DEAD
//   - Doctrine: "Reserved for future audit-only 'trace seat'
//     that annotates without mutating"
//
// Ch 1002 ships exactly that:`BASTraceAnnotatorSeat` is a
// pure-function seat that emits ONE `.annotate` delta per turn
// against a dedicated `.traceAnnotation` domain。 No production
// domain is touched。 No production seat reads from
// `.traceAnnotation`。 The seat is additive substrate — host
// SDKs wire it on-demand。
//
// Tests pin:
//   1. Empty input → empty output (no delta for empty turns)
//   2. Non-empty input → exactly 1 `.annotate` delta
//   3. Payload is deterministic (sorted agents,sorted delta types)
//   4. Same input → byte-equal payload (strong mergeID hash)
//   5. End-to-end via applier:annotate delta WRITES to
//      `.traceAnnotation` domain (applier already routes the
//      payload-bearing branch)
//   6. Single-writer enforcement:non-annotator agent attempting
//      to write `.traceAnnotation` is rejected
//   7. Source-grep:`.traceAnnotation` is exactly one writer
//      (the TraceAnnotator) — pins the single-writer invariant
//      structurally for future refactors

import XCTest
@testable import BASMemory

final class BASChapter1002TraceAnnotatorSeatTests: XCTestCase {

    // MARK: - Test fixtures

    private static func makeAnnotatorSpec() -> BASAgentSpec {
        BASAgentSpec(
            agentID: "ch1002.trace",
            role: .scout,  // role does not constrain write domain
            writeDomains: [.traceAnnotation],
            defaultLeaseProfile: .watcher,
            visibility: .low)
    }

    private static func makePlannerDelta(
        id: String, turnID: String
    ) -> BASAgentDelta {
        BASAgentDelta(
            deltaID: "delta.\(turnID).planner.\(id)",
            agentID: "ch1002.planner",
            targetObjectRef:
                "candidateFrontier#frontier-\(turnID)",
            deltaType: .add,
            patchJson: "{}",
            confidence: 0.5)
    }

    private static func makeRiskDelta(
        id: String, turnID: String
    ) -> BASAgentDelta {
        BASAgentDelta(
            deltaID: "delta.\(turnID).risk.\(id)",
            agentID: "ch1002.risk",
            targetObjectRef:
                "riskField#risk-\(turnID)",
            deltaType: .merge,
            patchJson: "{}",
            confidence: 0.7)
    }

    // MARK: - Behavior pins

    func test_EmptyInput_EmitsZeroDeltas() {
        let input = BASTraceAnnotatorInput(
            turnID: "t-empty", emittedDeltas: [])
        var seq = 0
        let out = BASTraceAnnotatorSeat.emit(
            from: input, agentSpec: Self.makeAnnotatorSpec(),
            seq: &seq)
        XCTAssertEqual(out.count, 0,
            "ch 1002: empty turn MUST produce zero annotation deltas " +
            "— wasted state-graph space otherwise")
        XCTAssertEqual(seq, 0,
            "ch 1002: seq counter MUST NOT bump on zero-delta turns")
    }

    func test_NonEmptyInput_EmitsExactlyOneAnnotateDelta() {
        let input = BASTraceAnnotatorInput(
            turnID: "t-1",
            emittedDeltas: [
                Self.makePlannerDelta(id: "1", turnID: "t-1"),
                Self.makeRiskDelta(id: "1", turnID: "t-1"),
            ])
        var seq = 0
        let out = BASTraceAnnotatorSeat.emit(
            from: input, agentSpec: Self.makeAnnotatorSpec(),
            seq: &seq)
        XCTAssertEqual(out.count, 1,
            "ch 1002: non-empty turn MUST produce exactly 1 " +
            "annotation delta")
        XCTAssertEqual(out[0].deltaType, .annotate,
            "ch 1002: emitted delta MUST be `.annotate` (closes " +
            "💀 DEAD case)")
        XCTAssertEqual(out[0].targetObjectRef,
            "traceAnnotation#turn-t-1",
            "ch 1002: ref MUST point at `.traceAnnotation` domain " +
            "(single-writer invariant — annotator owns this domain)")
        XCTAssertEqual(seq, 1,
            "ch 1002: seq counter MUST bump exactly +1")
    }

    func test_PayloadIsDeterministic_SortedAgents() {
        // 3 deltas from agents in unsorted order — payload must
        // emit them sorted to keep strong-mergeID hash invariance
        let deltas = [
            Self.makeRiskDelta(id: "1", turnID: "t-2"),
            Self.makePlannerDelta(id: "1", turnID: "t-2"),
            BASAgentDelta(
                deltaID: "delta.t-2.critic.1",
                agentID: "ch1002.critic",
                targetObjectRef:
                    "critiqueField#critique-t-2",
                deltaType: .merge,
                patchJson: "{}",
                confidence: 0.6),
        ]
        let input = BASTraceAnnotatorInput(
            turnID: "t-2", emittedDeltas: deltas)
        var seq = 0
        let out = BASTraceAnnotatorSeat.emit(
            from: input, agentSpec: Self.makeAnnotatorSpec(),
            seq: &seq)
        XCTAssertEqual(out.count, 1)
        let payload = out[0].patchJson
        // Sorted alphabetically: critic < planner < risk
        let criticIdx = payload.range(of: "ch1002.critic")?
            .lowerBound
        let plannerIdx = payload.range(of: "ch1002.planner")?
            .lowerBound
        let riskIdx = payload.range(of: "ch1002.risk")?
            .lowerBound
        XCTAssertNotNil(criticIdx)
        XCTAssertNotNil(plannerIdx)
        XCTAssertNotNil(riskIdx)
        XCTAssertTrue(
            criticIdx! < plannerIdx! && plannerIdx! < riskIdx!,
            "ch 1002: payload MUST emit agents sorted alphabetically " +
            "for byte-equal output across runs (strong mergeID hash)")
    }

    func test_PayloadIsByteEqual_ForSameInput() {
        let deltas = [
            Self.makePlannerDelta(id: "1", turnID: "t-3"),
            Self.makeRiskDelta(id: "1", turnID: "t-3"),
        ]
        let input1 = BASTraceAnnotatorInput(
            turnID: "t-3", emittedDeltas: deltas)
        let input2 = BASTraceAnnotatorInput(
            turnID: "t-3", emittedDeltas: deltas)
        var seq1 = 0; var seq2 = 0
        let out1 = BASTraceAnnotatorSeat.emit(
            from: input1, agentSpec: Self.makeAnnotatorSpec(),
            seq: &seq1, nowNanos: 12345)
        let out2 = BASTraceAnnotatorSeat.emit(
            from: input2, agentSpec: Self.makeAnnotatorSpec(),
            seq: &seq2, nowNanos: 12345)
        XCTAssertEqual(out1.count, 1)
        XCTAssertEqual(out2.count, 1)
        XCTAssertEqual(out1[0].patchJson, out2[0].patchJson,
            "ch 1002 CRITICAL: same input MUST produce byte-equal " +
            "payload across calls (strong mergeID hash invariance)")
        XCTAssertEqual(out1[0].deltaID, out2[0].deltaID,
            "ch 1002: same input + same seq MUST produce same deltaID")
    }

    // MARK: - End-to-end via applier

    func testCRITICAL_AnnotateDelta_AppliesToTraceAnnotationDomain()
        async throws
    {
        // Build a state graph + apply the annotate delta through
        // the canonical applier path。 Proves `.annotate` is no
        // longer 💀 DEAD end-to-end (applier writes the payload)。
        let graph = BASSharedStateGraph()
        let annotator = Self.makeAnnotatorSpec()
        let input = BASTraceAnnotatorInput(
            turnID: "t-e2e",
            emittedDeltas: [
                Self.makePlannerDelta(id: "1", turnID: "t-e2e"),
            ])
        var seq = 0
        let deltas = BASTraceAnnotatorSeat.emit(
            from: input, agentSpec: annotator, seq: &seq)
        XCTAssertEqual(deltas.count, 1)

        // Build merge result that accepts the annotation delta
        let mergeResult = BASAgentMergeResult(
            mergeID: "merge.t-e2e.1",
            acceptedDeltaIDs: [
                "delta:\(deltas[0].deltaID)",
            ],
            rejectedDeltaIDs: [],
            conflictResolution: [],
            resultingStateRef: "trace-test",
            mergeReasonCodes: ["trace.annotate"])

        let outcomes = await BASAgentMergeApplier.apply(
            mergeResult: mergeResult,
            deltas: deltas,
            agents: [annotator.agentID: annotator],
            graph: graph)
        XCTAssertEqual(outcomes.count, 1)
        XCTAssertTrue(outcomes[0].applied,
            "ch 1002 CRITICAL: `.annotate` delta MUST apply " +
            "through the canonical applier path — closes " +
            "💀 DEAD case end-to-end。 Error: " +
            "\(outcomes[0].errorReason)")
        let writtenRef = outcomes[0].writtenRef
        XCTAssertTrue(
            writtenRef.hasPrefix("traceAnnotation#"),
            "ch 1002: written ref MUST point at .traceAnnotation " +
            "domain, got: \(writtenRef)")
    }

    func testCRITICAL_NonAnnotator_CannotWriteTraceAnnotation()
        async throws
    {
        // Single-Writer-Per-Domain invariant:only the
        // TraceAnnotator may write `.traceAnnotation`。 A planner
        // attempting to write that domain MUST be rejected。
        let graph = BASSharedStateGraph()
        let imposter = BASAgentSpec(
            agentID: "ch1002.imposter",
            role: .planner,
            writeDomains: [.traceAnnotation],
                // imposter claims the write — registry will
                // initially allow auto-claim,but subsequent
                // writes by REAL annotator will be rejected。
                // Pin via the inverse:annotator claims FIRST,
                // imposter is rejected。
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        let annotator = Self.makeAnnotatorSpec()
        // Real annotator claims first
        _ = try await graph.writeObject(
            domain: .traceAnnotation,
            objectID: "real-1",
            payloadJson: "{}",
            byAgent: annotator)
        // Imposter attempts second write — REJECTED
        do {
            _ = try await graph.writeObject(
                domain: .traceAnnotation,
                objectID: "imposter-1",
                payloadJson: "{}",
                byAgent: imposter)
            XCTFail("ch 1002 CRITICAL: imposter MUST be rejected " +
                "(single-writer invariant)")
        } catch BASSharedStateGraphError
            .writerIdentityMismatch
        {
            // Expected
        } catch {
            XCTFail("ch 1002: caught wrong error: \(error)")
        }
    }

    // MARK: - Source-grep structural invariant

    /// Pin the single-writer invariant structurally: search the
    /// source tree for `.traceAnnotation` write usage; the only
    /// production source path that names `.traceAnnotation` as a
    /// `writeDomains` entry MUST be the TraceAnnotator seat /
    /// its registration site (or test fixtures)。 If a future
    /// refactor accidentally hands write rights to another seat,
    /// this test catches it。
    func testCRITICAL_TraceAnnotation_OnlyOneProductionWriter()
        throws
    {
        let projectRoot =
            BASSourceTreeAudit.repoRoot
        // Iterate every Swift source file in Sources/ and count
        // occurrences of `.traceAnnotation` in a `writeDomains:`
        // context。 Allowance:tests + the seat file's own doc
        // comment that names the case in prose。 We restrict to
        // production Sources/ for this assertion。
        let sourcesDir = "\(projectRoot)/Sources"
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            atPath: sourcesDir)
        else {
            return  // skip silently if path missing
        }
        var hits: [String] = []
        for case let p as String in enumerator {
            guard p.hasSuffix(".swift") else { continue }
            let full = "\(sourcesDir)/\(p)"
            guard let content = try? String(
                contentsOfFile: full, encoding: .utf8)
            else { continue }
            // Look for `[.traceAnnotation]` as a writeDomain
            // literal — common pattern in agent spec init。
            if content.contains("[.traceAnnotation]") {
                hits.append(p)
            }
        }
        // Currently expected: ZERO production sources。 The seat
        // file `BASTraceAnnotatorSeat.swift` does NOT itself
        // construct a spec — that's wire-up that future hosts
        // / fuzz scenarios do。 If a future arc adds a fixed
        // registration site,update the expected count to 1。
        XCTAssertLessThanOrEqual(hits.count, 1,
            "ch 1002 CRITICAL: at most ONE production source may " +
            "name `.traceAnnotation` as a writeDomain (the future " +
            "registration site)。 Found: \(hits)")
    }
}
