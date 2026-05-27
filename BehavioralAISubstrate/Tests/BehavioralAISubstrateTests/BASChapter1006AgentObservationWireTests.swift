// MARK: - BASChapter1006AgentObservationWireTests
// chapter 一千零六 / M3735 — wires `BASAgentObservation` from
// SCAFFOLD-but-actually-DEAD → ✅ WIRED
//
// Pre-ch-1006: `Docs/SCAFFOLD_VS_WIRED.md` ch 996 inventory
// claimed BASAgentObservation was 🪜 SCAFFOLD with "L14 audit
// reads", but grep proved NO substrate consumer reads it
// anywhere outside its own definition + ch 953's schema test。
// True status was 💀 DEAD, mislabeled。
//
// Ch 1006 ships:
//   1. BASAgentObservationAuditEmitter.signalRefs(from:) —
//      deterministic ref serialization
//   2. BASAgentObservationAuditEmitter
//      .observationFromAnnotator(input:agentSpec:) —
//      observation projection of TraceAnnotator input
//   3. Test coverage for both + a roundtrip through the L14
//      sovereign audit ledger
//
// Tests pin:
//   1. observationFromAnnotator emits zero on empty input
//   2. observationFromAnnotator emits exactly 1 on non-empty
//   3. observation contents reflect the input summary
//   4. signalRefs sort byte-equal for same input
//   5. signalRefs encode observationID + agentID + domain +
//      flags + confidence band
//   6. CRITICAL end-to-end: observation roundtrips through a
//      live BASSovereignAuditLedger via signalRefs (the actual
//      wire that closes the dead-letter condition)
//   7. confidence band thresholds: low <0.4, med <0.7, high >=0.7

import XCTest
import CryptoKit
@testable import BASMemory
@testable import BASSovereign
@testable import BASRuntimeCore

final class BASChapter1006AgentObservationWireTests: XCTestCase {

    private static func makeAnnotatorSpec() -> BASAgentSpec {
        BASAgentSpec(
            agentID: "ch1006.trace",
            role: .scout,
            writeDomains: [.traceAnnotation],
            defaultLeaseProfile: .watcher,
            visibility: .low)
    }

    private static func makeDelta(
        agent: String, turnID: String, seq: Int
    ) -> BASAgentDelta {
        BASAgentDelta(
            deltaID: "delta.\(turnID).\(agent).\(seq)",
            agentID: agent,
            targetObjectRef:
                "candidateFrontier#frontier-\(turnID)",
            deltaType: .add,
            patchJson: "{}",
            confidence: 0.5)
    }

    // MARK: - 1 + 2 + 3. observationFromAnnotator shape

    func test_EmptyInput_EmitsZeroObservations() {
        let input = BASTraceAnnotatorInput(
            turnID: "t-empty", emittedDeltas: [])
        var seq = 0
        let out = BASAgentObservationAuditEmitter
            .observationFromAnnotator(
                input: input,
                agentSpec: Self.makeAnnotatorSpec(),
                seq: &seq)
        XCTAssertEqual(out.count, 0,
            "ch 1006: empty input MUST produce zero observations")
        XCTAssertEqual(seq, 0,
            "ch 1006: seq MUST NOT bump on empty input")
    }

    func test_NonEmptyInput_EmitsExactlyOneObservation() {
        let deltas = [
            Self.makeDelta(
                agent: "ch1006.planner", turnID: "t-1", seq: 1),
            Self.makeDelta(
                agent: "ch1006.critic", turnID: "t-1", seq: 1),
        ]
        let input = BASTraceAnnotatorInput(
            turnID: "t-1", emittedDeltas: deltas)
        var seq = 0
        let out = BASAgentObservationAuditEmitter
            .observationFromAnnotator(
                input: input,
                agentSpec: Self.makeAnnotatorSpec(),
                seq: &seq)
        XCTAssertEqual(out.count, 1,
            "ch 1006: non-empty input MUST emit exactly 1 " +
            "observation")
        let obs = out[0]
        XCTAssertEqual(obs.agentID, "ch1006.trace")
        XCTAssertEqual(obs.observedDomain, .traceAnnotation,
            "ch 1006: observation domain MUST be .traceAnnotation " +
            "(matches the ch 1002 single-writer domain)")
        XCTAssertTrue(
            obs.flags.contains("trace-summary"),
            "ch 1006: observation MUST carry trace-summary flag")
        XCTAssertEqual(obs.sourceRefs.count, 2,
            "ch 1006: sourceRefs MUST reference all input deltas")
        XCTAssertEqual(seq, 1,
            "ch 1006: seq MUST bump exactly +1")
    }

    func test_ObservationSummary_ContainsTurnID() {
        let input = BASTraceAnnotatorInput(
            turnID: "t-summary",
            emittedDeltas: [
                Self.makeDelta(
                    agent: "p", turnID: "t-summary", seq: 1),
            ])
        var seq = 0
        let out = BASAgentObservationAuditEmitter
            .observationFromAnnotator(
                input: input,
                agentSpec: Self.makeAnnotatorSpec(),
                seq: &seq)
        XCTAssertTrue(
            out[0].summary.contains("t-summary"),
            "ch 1006: summary MUST include turnID for replay")
    }

    // MARK: - 4. signalRefs determinism

    func test_SignalRefs_AreSortedByObservationID() {
        let obs1 = BASAgentObservation(
            observationID: "obs.z",
            agentID: "a",
            observedDomain: .traceAnnotation,
            summary: "z",
            confidence: 0.5)
        let obs2 = BASAgentObservation(
            observationID: "obs.a",
            agentID: "b",
            observedDomain: .traceAnnotation,
            summary: "a",
            confidence: 0.5)
        let obs3 = BASAgentObservation(
            observationID: "obs.m",
            agentID: "c",
            observedDomain: .traceAnnotation,
            summary: "m",
            confidence: 0.5)
        let refs = BASAgentObservationAuditEmitter
            .signalRefs(from: [obs1, obs2, obs3])
        XCTAssertEqual(refs.count, 3)
        XCTAssertTrue(refs[0].contains("obs.a"))
        XCTAssertTrue(refs[1].contains("obs.m"))
        XCTAssertTrue(refs[2].contains("obs.z"))
    }

    // MARK: - 5. signalRefs encode all key fields

    func test_SignalRef_EncodesAllKeyFields() {
        let obs = BASAgentObservation(
            observationID: "obs.test",
            agentID: "ch1006.trace",
            observedDomain: .traceAnnotation,
            summary: "test",
            confidence: 0.8,
            flags: ["trace-summary", "agent-count=2"])
        let refs = BASAgentObservationAuditEmitter
            .signalRefs(from: [obs])
        XCTAssertEqual(refs.count, 1)
        let ref = refs[0]
        XCTAssertTrue(ref.contains("observation.obs.test"),
            "ch 1006: ref MUST include observationID prefix")
        XCTAssertTrue(ref.contains("agent=ch1006.trace"),
            "ch 1006: ref MUST include agentID")
        XCTAssertTrue(ref.contains("domain=traceAnnotation"),
            "ch 1006: ref MUST include domain")
        XCTAssertTrue(ref.contains("conf=high"),
            "ch 1006: ref MUST include confidence band " +
            "(>=0.7 → high)")
        // Flags MUST be sorted
        XCTAssertTrue(
            ref.contains("flags=agent-count=2,trace-summary"),
            "ch 1006: flags MUST be sorted alphabetically " +
            "for byte-equal output, got: \(ref)")
    }

    // MARK: - 6. CRITICAL end-to-end via audit ledger

    func testCRITICAL_ObservationRoundtripsThroughLedger()
        async throws
    {
        let secret = SymmetricKey(size: .bits256)
        let ledger = BASSovereignAuditLedger(
            signingSecret: secret)
        let input = BASTraceAnnotatorInput(
            turnID: "t-e2e",
            emittedDeltas: [
                Self.makeDelta(
                    agent: "ch1006.planner",
                    turnID: "t-e2e",
                    seq: 1),
            ])
        var seq = 0
        let observations = BASAgentObservationAuditEmitter
            .observationFromAnnotator(
                input: input,
                agentSpec: Self.makeAnnotatorSpec(),
                seq: &seq)
        XCTAssertEqual(observations.count, 1)
        let signalRefs = BASAgentObservationAuditEmitter
            .signalRefs(from: observations)
        // Append to ledger as observation-class audit entry
        let entry = BASSovereignAuditEntry(
            schemaVersion: "1.1.0",
            auditID: "obs.audit.t-e2e.1",
            sessionID: "session-ch1006",
            turnID: "t-e2e",
            verdictRef: "observation:trace:t-e2e",
            ruleIDs: [],
            signalRefs: signalRefs,
            actionRefs: [],
            snapshotRef: "",
            actor: .system,
            signature: "",
            appendedAt: Date())
        let appended = try await ledger.append(entry)
        XCTAssertFalse(appended.entry.signature.isEmpty,
            "ch 1006: ledger MUST sign the entry (HMAC mode)")
        XCTAssertEqual(appended.entry.signalRefs, signalRefs,
            "ch 1006 CRITICAL: ledger MUST preserve signalRefs " +
            "verbatim — closes the BASAgentObservation " +
            "dead-letter condition end-to-end")
        XCTAssertTrue(
            appended.entry.signalRefs[0].contains(
                "observation."),
            "ch 1006: signalRef in ledger MUST carry observation " +
            "prefix for audit replay scoping")
    }

    // MARK: - 7. Confidence band thresholds

    func test_ConfidenceBand_LowMedHigh() {
        let lo = BASAgentObservation(
            observationID: "obs.low",
            agentID: "a",
            observedDomain: .traceAnnotation,
            summary: "",
            confidence: 0.3)
        let me = BASAgentObservation(
            observationID: "obs.med",
            agentID: "a",
            observedDomain: .traceAnnotation,
            summary: "",
            confidence: 0.5)
        let hi = BASAgentObservation(
            observationID: "obs.high",
            agentID: "a",
            observedDomain: .traceAnnotation,
            summary: "",
            confidence: 0.8)
        let refs = BASAgentObservationAuditEmitter
            .signalRefs(from: [lo, me, hi])
        // Refs are sorted by observationID — high, low, med
        XCTAssertTrue(refs[0].contains("conf=high"),
            "ch 1006: 0.8 → high")
        XCTAssertTrue(refs[1].contains("conf=low"),
            "ch 1006: 0.3 → low")
        XCTAssertTrue(refs[2].contains("conf=med"),
            "ch 1006: 0.5 → med")
    }
}
