import XCTest
@testable import BASMemory

/// M341 — pin the L13 self-evolution lifecycle structural fingerprint.
///
/// ## Why this exists
///
/// `BASEvolutionLifecycleStructuralFingerprint` (M341) supplies the
/// **regression gate** leg of the v5 doctrine triple
/// (typed pin → measurement → regression gate) for the L13
/// self-evolution candidate parked in `QINAO_MANIFESTO_V5_DOCTRINE`
/// appendix.
///
/// This test pins:
///
///   1. `current()` (live fingerprint derived from the runtime
///      enums + `BASEvolutionLifecyclePolicy`) equals
///      `canonical` (the doctrine-pinned shape).
///   2. The 8 stages, 7 actions, and 13 transition edges are
///      exactly what M333 demonstrated walking through.
///   3. `detectDrift(...)` returns empty when comparing live vs
///      canonical — the only way this test fails is if someone
///      changed the policy without updating the canonical
///      fingerprint in the same PR.
///   4. The SHA-256 hash is byte-stable across runs (no random
///      seed, no per-process variation — same trap as M336 hit).
final class M341EvolutionLifecycleFingerprintTests: XCTestCase {

    func testLiveFingerprintEqualsCanonical() {
        let live = BASEvolutionLifecycleStructuralFingerprint
            .current()
        let pinned = BASEvolutionLifecycleStructuralFingerprint
            .canonical
        let reports = BASEvolutionLifecycleStructuralFingerprint
            .detectDrift(live: live, pinned: pinned)
        XCTAssertEqual(
            reports, [],
            "L13 lifecycle structural fingerprint drifted from " +
            "canonical: \(reports). If this is intentional, " +
            "update `canonical` in BASEvolutionLifecycleStructural" +
            "Fingerprint.swift in the same PR and document the " +
            "doctrine impact in honesty board.")
    }

    func testCanonicalHasEightStages() {
        let pinned = BASEvolutionLifecycleStructuralFingerprint
            .canonical
        XCTAssertEqual(pinned.stageRawValues.count, 8)
        XCTAssertEqual(
            Set(pinned.stageRawValues),
            Set([
                "proposed",
                "candidateRegistered",
                "shadowTrialing",
                "trialFinalized",
                "promoted",
                "retracted",
                "rejected",
                "withdrawn",
            ]))
    }

    func testCanonicalHasThreeTerminalStages() {
        let pinned = BASEvolutionLifecycleStructuralFingerprint
            .canonical
        XCTAssertEqual(
            pinned.terminalStageRawValues,
            ["rejected", "retracted", "withdrawn"])
    }

    func testCanonicalHasSevenActions() {
        let pinned = BASEvolutionLifecycleStructuralFingerprint
            .canonical
        XCTAssertEqual(pinned.actionRawValues.count, 7)
        XCTAssertEqual(
            Set(pinned.actionRawValues),
            Set([
                "registerCandidate",
                "startShadowTrial",
                "finalizeTrial",
                "promote",
                "retract",
                "fail",
                "withdraw",
            ]))
    }

    func testCanonicalHasExpectedEdgeCount() {
        let pinned = BASEvolutionLifecycleStructuralFingerprint
            .canonical
        let nonTerminalEdgeCount = pinned.transitionMatrix
            .values
            .map(\.count)
            .reduce(0, +)
        // Expected 11 edges:
        //   proposed: 2 (registerCandidate, withdraw)
        //   candidateRegistered: 2 (startShadowTrial, withdraw)
        //   shadowTrialing: 3 (finalizeTrial, fail, withdraw)
        //   trialFinalized: 3 (promote, fail, withdraw)
        //   promoted: 1 (retract — withdraw is INTENTIONALLY
        //                excluded; retraction is the only post-
        //                promotion exit path)
        //   terminals: 0
        XCTAssertEqual(nonTerminalEdgeCount, 11)
    }

    func testPromotedHasOnlyRetractEdge() {
        let pinned = BASEvolutionLifecycleStructuralFingerprint
            .canonical
        let edges = pinned.transitionMatrix["promoted"] ?? [:]
        XCTAssertEqual(edges, ["retract": "retracted"],
            "Doctrine: from .promoted only .retract is " +
            "permitted. .withdraw must NOT be reachable post-" +
            "promotion (retraction is the only exit path).")
    }

    func testTerminalStagesHaveEmptyEdges() {
        let pinned = BASEvolutionLifecycleStructuralFingerprint
            .canonical
        for terminal in pinned.terminalStageRawValues {
            let edges = pinned.transitionMatrix[terminal] ?? [:]
            XCTAssertEqual(
                edges, [:],
                "terminal stage \(terminal) must have empty " +
                "edge set; got \(edges)")
        }
    }

    func testHashIsStableAcrossInvocations() {
        let h1 = BASEvolutionLifecycleStructuralFingerprint
            .current().matrixHash
        let h2 = BASEvolutionLifecycleStructuralFingerprint
            .current().matrixHash
        let h3 = BASEvolutionLifecycleStructuralFingerprint
            .current().matrixHash
        XCTAssertEqual(h1, h2)
        XCTAssertEqual(h2, h3)
        XCTAssertEqual(
            h1.count, 64,
            "SHA-256 hex must be exactly 64 chars; got \(h1.count)")
    }

    func testHashMatchesCanonical() {
        let live = BASEvolutionLifecycleStructuralFingerprint
            .current()
        XCTAssertEqual(
            live.matrixHash,
            BASEvolutionLifecycleStructuralFingerprint
                .canonical.matrixHash,
            "live matrix hash must equal canonical hash. If " +
            "this fails, either someone changed the policy " +
            "(update canonical) or the SHA-256 implementation " +
            "drifted (investigate the hasher).")
    }

    func testDriftDetectionFlagsMissingStage() {
        let pinned = BASEvolutionLifecycleStructuralFingerprint
            .canonical
        let synthesized = BASEvolutionLifecycleStructuralFingerprint(
            stageRawValues: pinned.stageRawValues
                .filter { $0 != "withdrawn" },
            terminalStageRawValues: pinned.terminalStageRawValues,
            actionRawValues: pinned.actionRawValues,
            transitionMatrix: pinned.transitionMatrix,
            matrixHash: pinned.matrixHash)
        let reports = BASEvolutionLifecycleStructuralFingerprint
            .detectDrift(live: synthesized, pinned: pinned)
        XCTAssertFalse(
            reports.isEmpty,
            "missing-stage drift must be detected")
        XCTAssertTrue(
            reports.contains { $0.kind == "stage-set-changed" })
    }

    func testDriftDetectionFlagsExtraEdge() {
        let pinned = BASEvolutionLifecycleStructuralFingerprint
            .canonical
        var matrix = pinned.transitionMatrix
        // Synthesize a forbidden edge: withdraw from .promoted.
        var promotedEdges = matrix["promoted"] ?? [:]
        promotedEdges["withdraw"] = "withdrawn"
        matrix["promoted"] = promotedEdges
        let synthesized = BASEvolutionLifecycleStructuralFingerprint(
            stageRawValues: pinned.stageRawValues,
            terminalStageRawValues: pinned.terminalStageRawValues,
            actionRawValues: pinned.actionRawValues,
            transitionMatrix: matrix,
            matrixHash: BASEvolutionLifecycleStructuralFingerprint
                .computeMatrixHash(matrix: matrix))
        let reports = BASEvolutionLifecycleStructuralFingerprint
            .detectDrift(live: synthesized, pinned: pinned)
        XCTAssertFalse(reports.isEmpty)
        XCTAssertTrue(
            reports.contains {
                $0.kind == "transition-matrix-changed"
            })
    }

    func testCodableRoundTrip() throws {
        let pinned = BASEvolutionLifecycleStructuralFingerprint
            .canonical
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(pinned)
        let decoded = try JSONDecoder().decode(
            BASEvolutionLifecycleStructuralFingerprint.self,
            from: data)
        XCTAssertEqual(pinned, decoded)
    }
}
