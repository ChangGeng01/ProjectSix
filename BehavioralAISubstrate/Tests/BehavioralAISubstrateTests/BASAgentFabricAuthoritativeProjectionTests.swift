// Step 5 — proofs for the Agent Fabric authoritative host feed-forward projection.
//
// Proves: the projection is MODE-GATED (.observationOnly / no-accepted-deltas ⇒ nil — byte-equal-off);
// .authoritative projects the merge-accepted deltas into a typed input; enrichedRequest folds a
// labeled block into userInput without mutating the original; and (the (b) effect the user chose)
// the folded conclusions actually CHANGE what the real brain's cascade derives from the input —
// while the sovereign verdict still runs (the verdict path is untouched / input-class, 红线 7).

import XCTest
import Foundation
@testable import BASHostKit
@testable import BASMemory

#if !os(iOS) // ch1022 source-gate parity
final class BASAgentFabricAuthoritativeProjectionTests: XCTestCase {

    // MARK: - fixtures

    private func delta(
        _ id: String, domain: String = "render",
        type: BASAgentDeltaType = .replace, conf: Double = 0.9
    ) -> BASAgentDelta {
        BASAgentDelta(
            deltaID: id, agentID: "planner",
            targetObjectRef: "\(domain)#obj-\(id)",
            deltaType: type, patchJson: "{\"k\":\"\(id)\"}",
            confidence: conf, createdAtNanos: 0,
            reasonCodes: ["planner.primary"], dependencies: [], conflictRefs: [])
    }

    private func fabricResult(
        emitted: [BASAgentDelta], accepted: [String]
    ) -> BASAgentTurnResult {
        BASAgentTurnResult(
            emittedDeltas: emitted,
            mergeResult: BASAgentMergeResult(
                mergeID: "m1", acceptedDeltaIDs: accepted, rejectedDeltaIDs: [],
                conflictResolution: [], resultingStateRef: "render#obj", mergeReasonCodes: []),
            applyOutcomes: [], finalSeq: emitted.count, evidenceDebt: .empty)
    }

    // MARK: - mode gating (byte-equal-off)

    func testProjectIsNilForObservationOnly() {
        let r = fabricResult(emitted: [delta("d1")], accepted: ["d1"])
        XCTAssertNil(BASAgentFabricAuthoritativeProjection.project(
            fabricResult: r, mode: .observationOnly, sourceTurnID: "t1"),
            ".observationOnly must never produce a feed-forward input")
    }

    func testProjectIsNilWhenNoAcceptedDeltas() {
        let r = fabricResult(emitted: [delta("d1")], accepted: [])
        XCTAssertNil(BASAgentFabricAuthoritativeProjection.project(
            fabricResult: r, mode: .authoritative, sourceTurnID: "t1"),
            "no accepted deltas ⇒ nothing to feed forward")
    }

    func testProjectNormalizesMergeRefFormatAcceptedIDs() throws {
        // The REAL merge reports accepted IDs in the dependency-REF format `delta:<deltaID>`; the
        // projection must normalize the prefix to match the raw emitted deltaIDs. REGRESSION: before the
        // fix this returned nil (the authoritative feed-forward was dead end-to-end with the real fabric;
        // the bare-ID stub fixtures above masked it).
        let r = BASAgentTurnResult(
            emittedDeltas: [delta("delta.T.scout.1"), delta("delta.T.planner.2")],
            mergeResult: BASAgentMergeResult(
                mergeID: "m1",
                acceptedDeltaIDs: ["delta:delta.T.scout.1", "delta:delta.T.planner.2"],
                rejectedDeltaIDs: [], conflictResolution: [],
                resultingStateRef: "x", mergeReasonCodes: []),
            applyOutcomes: [], finalSeq: 2, evidenceDebt: .empty)
        let input = try XCTUnwrap(BASAgentFabricAuthoritativeProjection.project(
            fabricResult: r, mode: .authoritative, sourceTurnID: "T"),
            "ref-format accepted IDs must normalize + match the emitted deltas (was nil before the fix)")
        XCTAssertEqual(input.acceptedDeltaIDs.sorted(), ["delta.T.planner.2", "delta.T.scout.1"])
        XCTAssertEqual(input.conclusions.count, 2)
    }

    // MARK: - authoritative projection

    func testProjectProducesInputForAuthoritative() throws {
        // d1 accepted, d2 emitted-but-rejected → only d1 surfaces.
        let r = fabricResult(
            emitted: [delta("d1", domain: "render"), delta("d2", domain: "risk")],
            accepted: ["d1"])
        let input = try XCTUnwrap(BASAgentFabricAuthoritativeProjection.project(
            fabricResult: r, mode: .authoritative, sourceTurnID: "t1"))
        XCTAssertEqual(input.acceptedDeltaIDs, ["d1"])
        XCTAssertEqual(input.conclusions.count, 1)
        XCTAssertEqual(input.conclusions.first?.domain, "render")
        XCTAssertEqual(input.conclusions.first?.deltaType, "replace")
        XCTAssertTrue(input.contextBlock.contains("fabric-authoritative"))
        XCTAssertTrue(input.contextBlock.contains("render"))
        XCTAssertFalse(input.digest.isEmpty)
    }

    // MARK: - enrichment (fold into userInput)

    func testEnrichedRequestFoldsLabeledBlockAndLeavesOriginalUnmutated() throws {
        let r = fabricResult(emitted: [delta("d1")], accepted: ["d1"])
        let input = try XCTUnwrap(BASAgentFabricAuthoritativeProjection.project(
            fabricResult: r, mode: .authoritative, sourceTurnID: "t1"))
        let base = BASCoordinatorTestStubs.makeStubRequest(userInput: "original input")
        let enriched = BASAgentFabricAuthoritativeProjection.enrichedRequest(base, with: input)

        XCTAssertEqual(base.userInput, "original input", "the original request must not be mutated")
        XCTAssertTrue(enriched.userInput.hasPrefix("original input\n\n"))
        XCTAssertTrue(enriched.userInput.contains("fabric-authoritative"))
        // deterministic
        let enriched2 = BASAgentFabricAuthoritativeProjection.enrichedRequest(base, with: input)
        XCTAssertEqual(enriched.userInput, enriched2.userInput)
    }

    // MARK: - (b) the brain consumes it — the folded conclusions change the cascade's output

    func testEnrichedInputChangesTheBrainsDecomposeFrameAndVerdictStillRuns() async throws {
        let r = fabricResult(
            emitted: [delta("d1", domain: "risk", type: .merge),
                      delta("d2", domain: "render", type: .replace)],
            accepted: ["d1", "d2"])
        let input = try XCTUnwrap(BASAgentFabricAuthoritativeProjection.project(
            fabricResult: r, mode: .authoritative, sourceTurnID: "turn-N"))
        let base = BASCoordinatorTestStubs.makeStubRequest(userInput: "hi")
        let enriched = BASAgentFabricAuthoritativeProjection.enrichedRequest(base, with: input)

        // Fresh real brains; decomposeFrame is input-derived and carries no UUIDs (deterministic).
        let brainA = try await BASCognitiveBrain.makeWithDefaults()
        let brainB = try await BASCognitiveBrain.makeWithDefaults()
        let plain = await brainA.process(base.userInput)
        let enr = await brainB.process(enriched.userInput)

        XCTAssertNotEqual(plain.decomposeFrame, enr.decomposeFrame,
            "the folded fabric conclusions must change what the cascade derives from the input")
        XCTAssertNotNil(enr.sovereignVerdict,
            "the sovereign verdict still runs on the enriched turn — input-class, verdict path intact")
    }

    // MARK: - ch1066 prompt-safety: the enriched block must be sanitized + bounded

    func testContextBlockSanitizesStructuralJSONAndBoundsLength() throws {
        // The authoritative summary is raw patch JSON; feeding `{...}`/`"`/`<...>` verbatim to a
        // small 4-bit on-device decoder WEDGED it (uncancellable Metal eval, zero token
        // progress). The folded block must carry NO raw structural punctuation from the summary
        // and stay bounded — while keeping the label + domain the cascade needs.
        let r = fabricResult(
            emitted: [delta("d1", domain: "render")], accepted: ["d1"])
        let input = try XCTUnwrap(BASAgentFabricAuthoritativeProjection.project(
            fabricResult: r, mode: .authoritative, sourceTurnID: "t1"))
        for ch in ["{", "}", "\"", "<", ">"] {
            XCTAssertFalse(input.contextBlock.contains(ch),
                "the enriched block must not carry raw structural char \(ch)")
        }
        XCTAssertTrue(input.contextBlock.contains("render"),
            "the domain must survive sanitization (the cascade keys on it)")
        XCTAssertTrue(input.contextBlock.contains("[planner.primary]"),
            "WS1: the line carries the typed top reason code, not the patchJson free-text")
        XCTAssertTrue(input.contextBlock.contains("fabric-authoritative"),
            "the provenance label must survive sanitization")
        XCTAssertLessThanOrEqual(
            input.contextBlock.count,
            BASAgentFabricAuthoritativeProjection.maxContextBlockChars,
            "the enriched block must stay bounded so it can't dominate the prefill")
    }

    func testContextBlockHardCapsLongAcceptedDeltaSet() throws {
        let deltas = (0..<20).map { i in
            BASAgentDelta(
                deltaID: "d\(i)", agentID: "planner",
                targetObjectRef: "render#obj-\(i)",
                deltaType: .replace,
                patchJson: String(repeating: "{\"risk\":\"repeat\"}", count: 40),
                confidence: 0.9, createdAtNanos: 0,
                reasonCodes: ["planner.primary"], dependencies: [], conflictRefs: [])
        }
        let r = fabricResult(emitted: deltas, accepted: deltas.map(\.deltaID))
        let input = try XCTUnwrap(BASAgentFabricAuthoritativeProjection.project(
            fabricResult: r, mode: .authoritative, sourceTurnID: "t-long"))
        XCTAssertLessThanOrEqual(
            input.contextBlock.count,
            BASAgentFabricAuthoritativeProjection.maxContextBlockChars,
            "many accepted deltas must still produce a bounded context block")
        XCTAssertTrue(input.contextBlock.hasSuffix(" …"),
            "truncated context blocks should make the truncation visible")
    }

    // MARK: - WS1 typed-summary: typed reason code only, no patchJson free-text

    func testContextBlockEmitsTypedReasonCodeNotPatchJson() throws {
        let d = BASAgentDelta(
            deltaID: "dx", agentID: "planner", targetObjectRef: "risk#obj-x",
            deltaType: .merge, patchJson: "{\"secretPayloadToken\":\"zzz\"}",
            confidence: 0.8, createdAtNanos: 0,
            reasonCodes: ["evidence.recent"], dependencies: [], conflictRefs: [])
        let r = fabricResult(emitted: [d], accepted: ["dx"])
        let input = try XCTUnwrap(BASAgentFabricAuthoritativeProjection.project(
            fabricResult: r, mode: .authoritative, sourceTurnID: "t1"))
        XCTAssertTrue(input.contextBlock.contains("[evidence.recent]"),
            "the typed top reason code must appear in brackets")
        XCTAssertFalse(input.contextBlock.contains("secretPayloadToken"),
            "the patchJson free-text must NOT enter the prompt (WS1 OOD-prefill prevention)")
        XCTAssertTrue(input.contextBlock.contains("risk (merge, conf 0.80)"),
            "the typed fields (domain/type/conf) carry through")
    }

    func testContextBlockEmptyReasonCodesFallsBack() throws {
        let d = BASAgentDelta(
            deltaID: "de", agentID: "planner", targetObjectRef: "render#obj-e",
            deltaType: .replace, patchJson: "{\"k\":\"e\"}",
            confidence: 0.7, createdAtNanos: 0,
            reasonCodes: [], dependencies: [], conflictRefs: [])
        let r = fabricResult(emitted: [d], accepted: ["de"])
        let input = try XCTUnwrap(BASAgentFabricAuthoritativeProjection.project(
            fabricResult: r, mode: .authoritative, sourceTurnID: "t1"))
        XCTAssertTrue(input.contextBlock.contains(
            "[\(BASAgentFabricAuthoritativeProjection.reasonCodeFallback)]"),
            "empty reasonCodes must fall back to the fixed literal token")
    }

    func testPlainSummaryStripsEveryStructuralPunctuationChar() {
        // ch1066 再查 — pin plainSummary against the SAME constant it uses, so the stripper
        // and this test can't drift (the contextBlock tests above only check a header-safe
        // subset, since the provenance header legitimately contains [ ]).
        let punct = BASAgentFabricAuthoritativeProjection.structuralPunctuation
        let dirty = punct.map(String.init).joined() + "keepThis123"
        let clean = BASAgentFabricAuthoritativeProjection.plainSummary(dirty)
        for ch in punct {
            XCTAssertFalse(clean.contains(ch),
                "plainSummary must strip the structural char \(ch)")
        }
        XCTAssertTrue(clean.contains("keepThis123"),
            "plainSummary must keep ordinary content")
    }
}
#endif
