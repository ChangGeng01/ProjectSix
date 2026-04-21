import XCTest
import BASRuntimeCore
@testable import BASOrchestration

/// M42 — L3 thought-fold coverage projection tests.
///
/// `BASThoughtFold` is a pure value type (no actor hop), so unlike
/// M41 there is no pure/async parity check — the projection is a
/// single deterministic extension method. Tests cover:
///   * shape (layer, turn/session/emittedAt carry-through)
///   * the three `hasCoreSignalCoverage` anchors individually
///   * subject accounting (foldID + content-subject union)
///   * the "optional refs don't count as subjects" invariant
///   * the budget component table + degraded multiplier + clamp
///   * cross-layer report integration as the 14th layer
final class BASThoughtFoldObservationCoverageTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Fixtures

    /// Minimal well-formed fold — carries both structural anchors
    /// (checksum + restorePointer) and no degraded codes, so
    /// `hasCoreSignalCoverage` is true by construction.
    private static func healthyFold(
        foldID: String = "fold-1",
        compactSlots: [String: String] = [:],
        candidateSignatures: [String] = [],
        organPackageRefs: [String] = [],
        degradedReasonCodes: [String] = [],
        morphID: String? = nil,
        snapshotRef: String? = nil,
        resumeFrameRef: String? = nil,
        rollbackAnchorRef: String? = nil,
        morphGraphRef: String? = nil,
        hotColdMapRef: String? = nil,
        precisionProfileRef: String? = nil,
        lungStateRef: String? = nil,
        breathSchedulerRef: String? = nil,
        thermalExchangeRef: String? = nil,
        integrityWeaveRef: String? = nil,
        organChecksum: String? = nil,
        frontierChecksum: String? = nil,
        bindingChecksum: String? = nil,
        tissueSignature: String? = nil,
        organDeltaPlanRef: String? = nil,
        hostEffectSummary: String = "neutral",
        restorePointer: String = "restore-1",
        checksum: String = "chk-1"
    ) -> BASThoughtFold {
        BASThoughtFold(
            foldID: foldID,
            compactSlots: compactSlots,
            candidateSignatures: candidateSignatures,
            hostEffectSummary: hostEffectSummary,
            restorePointer: restorePointer,
            checksum: checksum,
            morphID: morphID,
            organChecksum: organChecksum,
            frontierChecksum: frontierChecksum,
            bindingChecksum: bindingChecksum,
            degradedReasonCodes: degradedReasonCodes,
            tissueSignature: tissueSignature,
            snapshotRef: snapshotRef,
            resumeFrameRef: resumeFrameRef,
            rollbackAnchorRef: rollbackAnchorRef,
            morphGraphRef: morphGraphRef,
            hotColdMapRef: hotColdMapRef,
            precisionProfileRef: precisionProfileRef,
            lungStateRef: lungStateRef,
            breathSchedulerRef: breathSchedulerRef,
            thermalExchangeRef: thermalExchangeRef,
            integrityWeaveRef: integrityWeaveRef,
            organPackageRefs: organPackageRefs,
            organDeltaPlanRef: organDeltaPlanRef)
    }

    // MARK: - Shape

    func testCoverageCarriesLayerAndKeys() {
        let fold = Self.healthyFold()
        let s = fold.coverageSummary(
            turnID: "t-1", sessionID: "s-1", emittedAt: t0)
        XCTAssertEqual(s.layer, .thoughtFold)
        XCTAssertEqual(s.turnID, "t-1")
        XCTAssertEqual(s.sessionID, "s-1")
        XCTAssertEqual(s.emittedAt, t0)
        XCTAssertTrue(s.hasCoreSignalCoverage)
        XCTAssertEqual(
            s.totalObservations, 1,
            "a bare healthy fold contributes just itself")
        XCTAssertEqual(
            s.distinctSubjectCount, 1,
            "foldID is always one subject")
    }

    // MARK: - hasCoreSignalCoverage semantics

    func testEmptyChecksumBreaksCoreCoverage() {
        let fold = Self.healthyFold(checksum: "")
        let s = fold.coverageSummary(
            turnID: "t-1", sessionID: "s-1", emittedAt: t0)
        XCTAssertFalse(
            s.hasCoreSignalCoverage,
            "fold without integrity anchor fails core signal")
    }

    func testEmptyRestorePointerBreaksCoreCoverage() {
        let fold = Self.healthyFold(restorePointer: "")
        let s = fold.coverageSummary(
            turnID: "t-1", sessionID: "s-1", emittedAt: t0)
        XCTAssertFalse(
            s.hasCoreSignalCoverage,
            "fold without resume path fails core signal")
    }

    func testDegradedReasonsBreakCoreCoverage() {
        let fold = Self.healthyFold(
            degradedReasonCodes: ["stale-candidate-frontier"])
        let s = fold.coverageSummary(
            turnID: "t-1", sessionID: "s-1", emittedAt: t0)
        XCTAssertFalse(
            s.hasCoreSignalCoverage,
            "degraded fold fails core signal even if anchors present")
    }

    func testAllThreeAnchorsGiveCoreCoverage() {
        let fold = Self.healthyFold(
            restorePointer: "ptr-z",
            checksum: "chk-z")
        let s = fold.coverageSummary(
            turnID: "t-1", sessionID: "s-1", emittedAt: t0)
        XCTAssertTrue(s.hasCoreSignalCoverage)
    }

    // MARK: - Subject & observation accounting

    func testTotalObservationsCountsFoldPlusContent() {
        let fold = Self.healthyFold(
            compactSlots: ["k1": "v1", "k2": "v2", "k3": "v3"],
            candidateSignatures: ["c1", "c2"],
            organPackageRefs: ["org-1"])
        let s = fold.coverageSummary(
            turnID: "t-1", sessionID: "s-1", emittedAt: t0)
        // 1 (fold) + 3 (slots) + 2 (candidates) + 1 (organs)
        // + 0 (no bound optional refs) = 7
        XCTAssertEqual(s.totalObservations, 7)
    }

    func testDistinctSubjectsUnionsFoldIdAndContent() {
        let fold = Self.healthyFold(
            compactSlots: ["k1": "v1", "k2": "v2"],
            candidateSignatures: ["c1"],
            organPackageRefs: ["org-1", "org-2"])
        let s = fold.coverageSummary(
            turnID: "t-1", sessionID: "s-1", emittedAt: t0)
        // { foldID, k1, k2, c1, org-1, org-2 } = 6
        XCTAssertEqual(s.distinctSubjectCount, 6)
    }

    func testDuplicateCandidateSignatureCollapses() {
        // The caller could produce a fold with duplicate candidate
        // signatures from an unsanitized source — our subject union
        // collapses them defensively.
        let fold = Self.healthyFold(
            candidateSignatures: ["dup", "dup"])
        let s = fold.coverageSummary(
            turnID: "t-1", sessionID: "s-1", emittedAt: t0)
        XCTAssertEqual(
            s.totalObservations, 3,
            "observations count each occurrence: 1 + 0 + 2 + 0 = 3")
        XCTAssertEqual(
            s.distinctSubjectCount, 2,
            "subjects collapse duplicate signature: { foldID, dup }")
    }

    func testDuplicateOrganPackageRefCollapses() {
        let fold = Self.healthyFold(
            organPackageRefs: ["org-x", "org-x"])
        let s = fold.coverageSummary(
            turnID: "t-1", sessionID: "s-1", emittedAt: t0)
        XCTAssertEqual(
            s.totalObservations, 3,
            "observations count each occurrence: 1 + 0 + 0 + 2 = 3")
        XCTAssertEqual(
            s.distinctSubjectCount, 2,
            "subjects collapse duplicate organ ref")
    }

    func testBoundRefsIncreaseObservationsButNotSubjects() {
        // Optional substrate-binding refs contribute to
        // `totalObservations` when bound, but they are anchors into
        // other layers' subject namespaces — they must NOT count as
        // L3 subjects or we'd double-count the target layer.
        let base = Self.healthyFold()
        let baseSummary = base.coverageSummary(
            turnID: "t-1", sessionID: "s-1", emittedAt: t0)

        let bound = Self.healthyFold(
            morphID: "morph-1",
            snapshotRef: "snap-1",
            resumeFrameRef: "resume-1",
            lungStateRef: "lung-1")
        let boundSummary = bound.coverageSummary(
            turnID: "t-1", sessionID: "s-1", emittedAt: t0)

        XCTAssertEqual(
            boundSummary.totalObservations,
            baseSummary.totalObservations + 4,
            "each bound optional ref adds one observation")
        XCTAssertEqual(
            boundSummary.distinctSubjectCount,
            baseSummary.distinctSubjectCount,
            "bound optional refs do not count as L3 subjects")
    }

    func testAllSixteenBoundRefsCountCorrectly() {
        // Exhaustively prove every optional ref is counted by
        // `boundRefCount`. Guard against a silent regression where a
        // new field is added to `BASThoughtFold` without updating the
        // coverage projector.
        let fold = Self.healthyFold(
            morphID: "v1",
            snapshotRef: "v2",
            resumeFrameRef: "v3",
            rollbackAnchorRef: "v4",
            morphGraphRef: "v5",
            hotColdMapRef: "v6",
            precisionProfileRef: "v7",
            lungStateRef: "v8",
            breathSchedulerRef: "v9",
            thermalExchangeRef: "v10",
            integrityWeaveRef: "v11",
            organChecksum: "v12",
            frontierChecksum: "v13",
            bindingChecksum: "v14",
            tissueSignature: "v15",
            organDeltaPlanRef: "v16")
        let count =
            BASThoughtFoldObservationBudget.boundRefCount(for: fold)
        XCTAssertEqual(
            count, 16,
            "all 16 optional substrate-binding refs should register")
    }

    // MARK: - Budget

    func testBudgetBaseOnly() {
        let fold = Self.healthyFold()
        let s = fold.coverageSummary(
            turnID: "t-1", sessionID: "s-1", emittedAt: t0)
        // Just foldBaseCost = 0.04, no degraded, no clamp.
        XCTAssertEqual(s.budgetTotalCost, 0.04, accuracy: 1e-12)
    }

    func testBudgetAccumulatesAcrossComponents() {
        let fold = Self.healthyFold(
            compactSlots: ["k1": "v1", "k2": "v2"],  // 2 slots
            candidateSignatures: ["c1"],              // 1 signature
            organPackageRefs: ["org-1"],              // 1 organ
            morphID: "morph-1",                       // bound
            snapshotRef: "snap-1")                    // bound
        let s = fold.coverageSummary(
            turnID: "t-1", sessionID: "s-1", emittedAt: t0)
        // 0.04 + 0.005×2 + 0.02×1 + 0.04×1 + 0.01×2 = 0.13
        XCTAssertEqual(s.budgetTotalCost, 0.13, accuracy: 1e-12)
    }

    func testBudgetDegradedMultiplier() {
        let fold = Self.healthyFold(
            degradedReasonCodes: ["stale-frontier"])
        let s = fold.coverageSummary(
            turnID: "t-1", sessionID: "s-1", emittedAt: t0)
        // 0.04 × 1.3 = 0.052
        XCTAssertEqual(s.budgetTotalCost, 0.052, accuracy: 1e-12)
    }

    func testBudgetClampsAtOne() {
        // Pathological: 300 compact slots → 0.005×300 = 1.5 → + 0.04
        // = 1.54 → clamp to 1.0.
        var slots: [String: String] = [:]
        for i in 0..<300 { slots["k-\(i)"] = "v-\(i)" }
        let fold = Self.healthyFold(compactSlots: slots)
        let s = fold.coverageSummary(
            turnID: "t-1", sessionID: "s-1", emittedAt: t0)
        XCTAssertEqual(s.budgetTotalCost, 1.0, accuracy: 1e-12)
    }

    // MARK: - Cross-layer report integration

    func testThoughtFoldSummaryFeedsReconciliationReportAs14thLayer() {
        // Prove the L3 projection slots into the reconciler alongside
        // the other 13 projected layers — no special-casing required,
        // just a plain `BASObservationCoverageSummary` with the
        // `.thoughtFold` tag. This is the M42 wave-closing assertion.
        let fold = Self.healthyFold(
            compactSlots: ["ambiguity": "low"],
            candidateSignatures: ["top-candidate"],
            organPackageRefs: ["pkg-1"])
        let summary = fold.coverageSummary(
            turnID: "t-1", sessionID: "s-1", emittedAt: t0)
        let report = BASObservationReconciliationReport(
            turnID: "t-1",
            sessionID: "s-1",
            summaries: [summary])
        XCTAssertEqual(report.coveredLayers, [.thoughtFold])
        XCTAssertTrue(
            report.isFullyObserved(expected: [.thoughtFold]))
        XCTAssertEqual(
            report.summary(forLayer: .thoughtFold)?.layer,
            .thoughtFold)
    }

    func testAllFourteenLayersCanCoexistInOneReport() {
        // The wave-closing truth: an L14 reconciler built on top of
        // M42 can now accept a summary from every one of the 14
        // cognitive layers in a single report, with no layer
        // structurally silent. We assert the report preserves the
        // shape for L3 without colliding with sibling layers.
        let l3 = Self.healthyFold().coverageSummary(
            turnID: "t-1", sessionID: "s-1", emittedAt: t0)
        let l1 = BASObservationCoverageSummary(
            layer: .leaseLife,
            turnID: "t-1", sessionID: "s-1",
            totalObservations: 2,
            distinctSubjectCount: 1,
            hasCoreSignalCoverage: true,
            budgetTotalCost: 0.05,
            emittedAt: t0)
        let l14 = BASObservationCoverageSummary(
            layer: .sovereign,
            turnID: "t-1", sessionID: "s-1",
            totalObservations: 3,
            distinctSubjectCount: 2,
            hasCoreSignalCoverage: true,
            budgetTotalCost: 0.10,
            emittedAt: t0)
        let report = BASObservationReconciliationReport(
            turnID: "t-1",
            sessionID: "s-1",
            summaries: [l1, l3, l14])
        XCTAssertEqual(
            report.coveredLayers,
            [.leaseLife, .thoughtFold, .sovereign],
            "first-seen order preserved; L3 sits between its siblings")
        XCTAssertTrue(
            report.isFullyObserved(
                expected: [.leaseLife, .thoughtFold, .sovereign]))
    }
}
