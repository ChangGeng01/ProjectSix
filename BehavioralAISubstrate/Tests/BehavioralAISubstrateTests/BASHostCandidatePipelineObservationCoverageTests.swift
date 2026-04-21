import XCTest
import BASRuntimeCore
@testable import BASMemory

/// M40 — L5 host-constitution pipeline coverage projection tests.
///
/// Exercises the pure `projectCoverage(from:turnID:sessionID:
/// emittedAt:)` helper (no actor hop) and the async
/// `coverageSummary(turnID:sessionID:emittedAt:)` on the actor.
/// Both paths must produce byte-identical summaries for the same
/// input — the M6 parity discipline extended into the coverage
/// audit surface.
final class BASHostCandidatePipelineObservationCoverageTests:
    XCTestCase
{
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Fixtures

    private static func baseConstitution(
        activeVersion: String = "host.v1"
    ) -> BASHostConstitution {
        BASHostConstitution(
            hostID: "host",
            activeVersion: activeVersion,
            narrativeLoom: BASNarrativeLoom(
                longFormSummary: "stable",
                currentPhase: "stable",
                continuityLinks: [],
                unresolvedTensions: []))
    }

    private static func baseVersionTree(
        activeVersionID: String = "host.v1",
        extraVersions: [String] = [],
        pending: [String] = [],
        frozen: [String] = []
    ) -> BASHostVersionTree {
        var versions: [BASHostVersion] = [
            BASHostVersion(
                versionID: activeVersionID,
                createdAt: Date(timeIntervalSince1970: 1_600_000_000),
                changedFields: ["identity_lattice"],
                reason: "bootstrap",
                approvedByPolicy: true)
        ]
        for v in extraVersions {
            versions.append(
                BASHostVersion(
                    versionID: v,
                    createdAt: Date(timeIntervalSince1970: 1_600_000_000),
                    changedFields: ["goal_spine"],
                    reason: "extension",
                    approvedByPolicy: true))
        }
        return BASHostVersionTree(
            activeVersionID: activeVersionID,
            versions: versions,
            pendingCandidateIDs: pending,
            frozenVersionIDs: frozen)
    }

    private static func candidate(
        id: String
    ) -> BASHostChangeCandidate {
        BASHostChangeCandidate(
            candidateID: id,
            changeType: "goal_spine",
            proposedDelta: ["goal_spine"],
            evidenceRefs: ["memory.turn.1"],
            confidence: 0.8,
            conflictRefs: [])
    }

    private func makeSnapshot(
        activeVersionID: String = "host.v1",
        committed: [String] = ["host.v1"],
        pending: [String] = [],
        rejected: [String] = [],
        frozen: [String] = []
    ) -> BASHostCandidatePipelineObservationSnapshot {
        BASHostCandidatePipelineObservationSnapshot(
            activeVersionID: activeVersionID,
            committedVersionIDs: committed,
            pendingCandidateIDs: pending,
            rejectedCandidateIDs: rejected,
            frozenVersionIDs: frozen)
    }

    // MARK: - Shape

    func testProjectCoverageCarriesLayerAndFields() {
        let snap = makeSnapshot(
            activeVersionID: "host.v1",
            committed: ["host.v1"],
            pending: ["c-1"],
            rejected: [],
            frozen: [])
        let s = BASHostCandidatePipeline.projectCoverage(
            from: snap,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: t0)
        XCTAssertEqual(s.layer, .hostConstitution)
        XCTAssertEqual(s.turnID, "t-1")
        XCTAssertEqual(s.sessionID, "s-1")
        XCTAssertEqual(
            s.totalObservations, 3,
            "activeVersion (1) + 1 committed + 1 pending = 3")
        XCTAssertEqual(
            s.distinctSubjectCount, 2,
            "host.v1 collapses (active = committed); c-1 is second")
        XCTAssertTrue(s.hasCoreSignalCoverage)
        XCTAssertEqual(s.emittedAt, t0)
    }

    // MARK: - hasCoreSignalCoverage semantics

    func testPipelineWithoutActiveVersionHasNoCoreCoverage() {
        // Bootstrap-less pipeline: identity anchor missing. Even
        // though we might still be logging rejections, L5 has not
        // published a governance identity for the turn.
        let snap = makeSnapshot(
            activeVersionID: "",
            committed: [],
            pending: [],
            rejected: ["c-1"],
            frozen: [])
        let s = BASHostCandidatePipeline.projectCoverage(
            from: snap,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: t0)
        XCTAssertFalse(
            s.hasCoreSignalCoverage,
            "no active version = no core identity anchor")
        XCTAssertEqual(
            s.totalObservations, 1,
            "only the single rejection observation is counted")
        XCTAssertEqual(s.distinctSubjectCount, 1)
    }

    func testActiveVersionAloneIsCoreSignal() {
        let snap = makeSnapshot(
            activeVersionID: "host.v1",
            committed: ["host.v1"],
            pending: [],
            rejected: [],
            frozen: [])
        let s = BASHostCandidatePipeline.projectCoverage(
            from: snap,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: t0)
        XCTAssertTrue(
            s.hasCoreSignalCoverage,
            "a bootstrapped active version is enough signal")
        XCTAssertEqual(
            s.totalObservations, 2,
            "1 active-version anchor + 1 committed row")
        XCTAssertEqual(
            s.distinctSubjectCount, 1,
            "active and committed collapse into a single ID")
    }

    // MARK: - Subject union semantics

    func testFrozenVersionCollapsesWithCommittedVersion() {
        // host.v1 is both committed and frozen — must be counted
        // once in distinctSubjectCount. Total observations, however,
        // still sees both records (committed + frozen = 2 events).
        let snap = makeSnapshot(
            activeVersionID: "host.v1",
            committed: ["host.v1", "host.v2"],
            pending: [],
            rejected: [],
            frozen: ["host.v1"])
        let s = BASHostCandidatePipeline.projectCoverage(
            from: snap,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: t0)
        XCTAssertEqual(
            s.totalObservations,
            1 + 2 + 0 + 0 + 1,
            "active + 2 committed + 0 pending + 0 rejected + 1 frozen")
        XCTAssertEqual(
            s.distinctSubjectCount, 2,
            "host.v1 and host.v2 — frozen host.v1 is not a new subject")
    }

    func testRejectionAndPendingCollapseOnSameCandidateID() {
        // If the same ID appears both in the rejection log and the
        // pending list (pathological — shouldn't happen — but the
        // projection must be robust), it collapses to one subject.
        let snap = makeSnapshot(
            activeVersionID: "host.v1",
            committed: ["host.v1"],
            pending: ["c-1"],
            rejected: ["c-1"],
            frozen: [])
        let s = BASHostCandidatePipeline.projectCoverage(
            from: snap,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: t0)
        XCTAssertEqual(s.totalObservations, 4, "1 + 1 + 1 + 1 = 4")
        XCTAssertEqual(
            s.distinctSubjectCount, 2,
            "host.v1 + c-1 (pending∩rejected collapsed)")
    }

    // MARK: - Budget

    func testBudgetLinearlySumsComponents() {
        let snap = makeSnapshot(
            activeVersionID: "host.v1",
            committed: ["host.v1", "host.v2"],
            pending: ["c-1", "c-2"],
            rejected: ["c-3"],
            frozen: ["host.v1"])
        // active 0.02
        // + 2 committed × 0.01 = 0.02
        // + 2 pending × 0.05 = 0.10
        // + 1 rejected × 0.03 = 0.03
        // + 1 frozen × 0.04 = 0.04
        // = 0.21
        let s = BASHostCandidatePipeline.projectCoverage(
            from: snap,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: t0)
        XCTAssertEqual(s.budgetTotalCost, 0.21, accuracy: 1e-9)
    }

    func testBudgetSkipsActiveComponentWhenEmpty() {
        let snap = makeSnapshot(
            activeVersionID: "",
            committed: [],
            pending: ["c-1"],
            rejected: [],
            frozen: [])
        let s = BASHostCandidatePipeline.projectCoverage(
            from: snap,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: t0)
        XCTAssertEqual(s.budgetTotalCost, 0.05, accuracy: 1e-9)
    }

    func testBudgetClampsAtOne() {
        // 25 pending candidates × 0.05 = 1.25, clamp to 1.0
        let pending = (0..<25).map { "c-\($0)" }
        let snap = makeSnapshot(
            activeVersionID: "host.v1",
            committed: ["host.v1"],
            pending: pending,
            rejected: [],
            frozen: [])
        let s = BASHostCandidatePipeline.projectCoverage(
            from: snap,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: t0)
        XCTAssertEqual(s.budgetTotalCost, 1.0, accuracy: 1e-12)
    }

    // MARK: - Async path parity

    func testAsyncCoverageSummaryMatchesPurePath() async throws {
        let base = Self.baseConstitution()
        let tree = Self.baseVersionTree()
        let fixedClock: @Sendable () -> Date = {
            Date(timeIntervalSince1970: 1_730_000_000)
        }
        let pipeline = BASHostCandidatePipeline(
            constitution: base,
            versionTree: tree,
            clock: fixedClock)

        // Drive a realistic flow: one approved, one pending, one
        // rejection logged.
        _ = try await pipeline.submit(
            Self.candidate(id: "c-approved"))
        _ = try await pipeline.approve("c-approved")
        _ = try await pipeline.submit(
            Self.candidate(id: "c-pending"))
        _ = try await pipeline.submit(
            Self.candidate(id: "c-rejected"))
        _ = try await pipeline.reject(
            "c-rejected", reason: "conflicts-with-boundary")

        let actorSummary = await pipeline.coverageSummary(
            turnID: "t-1", sessionID: "s-1", emittedAt: t0)
        let snapshot = await pipeline.currentCoverageSnapshot()
        let pureSummary = BASHostCandidatePipeline.projectCoverage(
            from: snapshot,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: t0)

        XCTAssertEqual(actorSummary, pureSummary)
        XCTAssertEqual(actorSummary.layer, .hostConstitution)
        XCTAssertTrue(actorSummary.hasCoreSignalCoverage)
    }

    // MARK: - Cross-layer report integration

    func testHostConstitutionSummaryFeedsReconciliationReport(
    ) async throws {
        let pipeline = BASHostCandidatePipeline(
            constitution: Self.baseConstitution(),
            versionTree: Self.baseVersionTree())
        let summary = await pipeline.coverageSummary(
            turnID: "t-1", sessionID: "s-1", emittedAt: t0)
        let report = BASObservationReconciliationReport(
            turnID: "t-1", sessionID: "s-1",
            summaries: [summary])
        XCTAssertEqual(report.coveredLayers, [.hostConstitution])
        XCTAssertTrue(
            report.isFullyObserved(
                expected: [.hostConstitution]))
    }
}
