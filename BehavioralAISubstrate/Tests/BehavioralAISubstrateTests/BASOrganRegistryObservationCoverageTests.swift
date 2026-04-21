import XCTest
import BASRuntimeCore
@testable import BASOrgan

/// M41 — L2 neural-organ registry coverage projection tests.
///
/// Exercises the pure `projectCoverage(from:turnID:sessionID:
/// emittedAt:)` helper (no actor hop) and the async
/// `coverageSummary(turnID:sessionID:emittedAt:)` on the actor.
/// Both paths must produce byte-identical summaries for the same
/// input — the M6 parity discipline extended into the coverage
/// audit surface.
final class BASOrganRegistryObservationCoverageTests:
    XCTestCase
{
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Fixtures

    private static func descriptor(
        id: String,
        roles: Set<BASOrganRole> = [.scout, .core],
        runsOnDevice: Bool = true
    ) -> BASOrganDescriptor {
        BASOrganDescriptor(
            providerID: id,
            providerName: "provider-\(id)",
            supportsStreaming: false,
            maxInputTokens: 8_192,
            maxOutputTokens: 2_048,
            runsOnDevice: runsOnDevice,
            supportedRoles: roles)
    }

    private static func snapshot(
        _ descriptors: [BASOrganDescriptor]
    ) -> BASOrganRegistryObservationSnapshot {
        BASOrganRegistryObservationSnapshot(
            descriptors: descriptors)
    }

    // MARK: - Shape

    func testProjectCoverageCarriesLayerAndFields() {
        let snap = Self.snapshot([
            Self.descriptor(id: "p-1", roles: [.scout, .core])
        ])
        let s = BASOrganRegistry.projectCoverage(
            from: snap,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: t0)
        XCTAssertEqual(s.layer, .neuralOrgan)
        XCTAssertEqual(s.turnID, "t-1")
        XCTAssertEqual(s.sessionID, "s-1")
        XCTAssertEqual(
            s.totalObservations, 3,
            "1 descriptor + 2 roles = 3 observations")
        XCTAssertEqual(s.distinctSubjectCount, 1)
        XCTAssertTrue(s.hasCoreSignalCoverage)
        XCTAssertEqual(s.emittedAt, t0)
    }

    // MARK: - hasCoreSignalCoverage semantics

    func testEmptyRegistryHasNoCoreCoverage() {
        let snap = Self.snapshot([])
        let s = BASOrganRegistry.projectCoverage(
            from: snap,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: t0)
        XCTAssertFalse(
            s.hasCoreSignalCoverage,
            "an empty registry has no two-tier organ surface")
        XCTAssertEqual(s.totalObservations, 0)
        XCTAssertEqual(s.distinctSubjectCount, 0)
        XCTAssertEqual(s.budgetTotalCost, 0.0, accuracy: 1e-12)
    }

    func testScoutOnlyDoesNotGiveCoreCoverage() {
        let snap = Self.snapshot([
            Self.descriptor(id: "p-1", roles: [.scout])
        ])
        let s = BASOrganRegistry.projectCoverage(
            from: snap,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: t0)
        XCTAssertFalse(
            s.hasCoreSignalCoverage,
            "scout-only registry cannot sustain L9/L10 deliberation")
        XCTAssertEqual(s.totalObservations, 2)
    }

    func testCoreOnlyDoesNotGiveCoreCoverage() {
        let snap = Self.snapshot([
            Self.descriptor(id: "p-1", roles: [.core])
        ])
        let s = BASOrganRegistry.projectCoverage(
            from: snap,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: t0)
        XCTAssertFalse(
            s.hasCoreSignalCoverage,
            "core-only registry cannot serve L1 prefilter cheaply")
        XCTAssertEqual(s.totalObservations, 2)
    }

    func testScoutAndCoreGiveCoreCoverage() {
        let snap = Self.snapshot([
            Self.descriptor(id: "p-1", roles: [.scout, .core])
        ])
        let s = BASOrganRegistry.projectCoverage(
            from: snap,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: t0)
        XCTAssertTrue(s.hasCoreSignalCoverage)
    }

    func testTwoProvidersEachWithOneRoleGiveCoreCoverage() {
        // Split two-tier: one provider does scouts, another does
        // cores. The registry still covers both roles — the
        // reconciler should treat this as healthy.
        let snap = Self.snapshot([
            Self.descriptor(id: "scout-1", roles: [.scout]),
            Self.descriptor(id: "core-1", roles: [.core])
        ])
        let s = BASOrganRegistry.projectCoverage(
            from: snap,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: t0)
        XCTAssertTrue(
            s.hasCoreSignalCoverage,
            "scout+core split across providers still covers L2")
        XCTAssertEqual(
            s.totalObservations, 4,
            "2 descriptors + 1 role each = 4 observations")
        XCTAssertEqual(s.distinctSubjectCount, 2)
    }

    // MARK: - Subject and observation accounting

    func testTotalObservationsCountsDescriptorPlusRoles() {
        let snap = Self.snapshot([
            Self.descriptor(id: "p-1", roles: [.scout]),
            Self.descriptor(id: "p-2", roles: [.scout, .core]),
            Self.descriptor(id: "p-3", roles: [.core])
        ])
        let s = BASOrganRegistry.projectCoverage(
            from: snap,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: t0)
        // (1+1) + (1+2) + (1+1) = 2 + 3 + 2 = 7
        XCTAssertEqual(s.totalObservations, 7)
    }

    func testDistinctSubjectsCountsUniqueProviders() {
        // Pathological: same providerID appears twice. The registry
        // invariant prevents this in practice (re-registration
        // overwrites), but the pure helper collapses defensively.
        let snap = Self.snapshot([
            Self.descriptor(id: "p-dup", roles: [.scout]),
            Self.descriptor(id: "p-dup", roles: [.core])
        ])
        let s = BASOrganRegistry.projectCoverage(
            from: snap,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: t0)
        XCTAssertEqual(
            s.distinctSubjectCount, 1,
            "duplicate providerID collapses to one subject")
    }

    // MARK: - Budget

    func testBudgetOnDeviceDiscount() {
        let snap = Self.snapshot([
            Self.descriptor(
                id: "p-1",
                roles: [.scout, .core],
                runsOnDevice: true)
        ])
        let s = BASOrganRegistry.projectCoverage(
            from: snap,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: t0)
        // raw = 0.03 + 2 × 0.01 = 0.05
        // × onDeviceMultiplier (0.7) = 0.035
        XCTAssertEqual(s.budgetTotalCost, 0.035, accuracy: 1e-12)
    }

    func testBudgetRemotePremium() {
        let snap = Self.snapshot([
            Self.descriptor(
                id: "p-1",
                roles: [.scout, .core],
                runsOnDevice: false)
        ])
        let s = BASOrganRegistry.projectCoverage(
            from: snap,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: t0)
        // raw = 0.03 + 2 × 0.01 = 0.05
        // × remoteMultiplier (1.2) = 0.06
        XCTAssertEqual(s.budgetTotalCost, 0.06, accuracy: 1e-12)
    }

    func testBudgetSumsAcrossProviders() {
        let snap = Self.snapshot([
            // on-device, scout-only: (0.03+0.01) × 0.7 = 0.028
            Self.descriptor(
                id: "scout-1",
                roles: [.scout],
                runsOnDevice: true),
            // remote, core-only: (0.03+0.01) × 1.2 = 0.048
            Self.descriptor(
                id: "core-1",
                roles: [.core],
                runsOnDevice: false)
        ])
        let s = BASOrganRegistry.projectCoverage(
            from: snap,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: t0)
        // 0.028 + 0.048 = 0.076
        XCTAssertEqual(s.budgetTotalCost, 0.076, accuracy: 1e-12)
    }

    func testBudgetClampsAtOne() {
        // 100 remote providers each with both roles:
        // raw 0.05 × 1.2 = 0.06 per provider × 100 = 6.0 → clamp 1.0
        let descriptors = (0..<100).map {
            Self.descriptor(
                id: "p-\($0)",
                roles: [.scout, .core],
                runsOnDevice: false)
        }
        let snap = Self.snapshot(descriptors)
        let s = BASOrganRegistry.projectCoverage(
            from: snap,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: t0)
        XCTAssertEqual(s.budgetTotalCost, 1.0, accuracy: 1e-12)
    }

    // MARK: - Async path parity

    func testAsyncCoverageSummaryMatchesPurePath() async throws {
        let registry = BASOrganRegistry()
        let adapter1 = BASOrganDeterministicAdapter(
            providerID: "det.scout.v1",
            supportedRoles: [.scout])
        let adapter2 = BASOrganDeterministicAdapter(
            providerID: "det.core.v1",
            supportedRoles: [.core])
        await registry.register(adapter1)
        await registry.register(adapter2)

        let actorSummary = await registry.coverageSummary(
            turnID: "t-1", sessionID: "s-1", emittedAt: t0)
        let snapshot = await registry.currentCoverageSnapshot()
        let pureSummary = BASOrganRegistry.projectCoverage(
            from: snapshot,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: t0)

        XCTAssertEqual(actorSummary, pureSummary)
        XCTAssertEqual(actorSummary.layer, .neuralOrgan)
        XCTAssertTrue(actorSummary.hasCoreSignalCoverage)
        XCTAssertEqual(actorSummary.distinctSubjectCount, 2)
    }

    func testAsyncCoverageReflectsUnregister() async throws {
        let registry = BASOrganRegistry()
        let adapter1 = BASOrganDeterministicAdapter(
            providerID: "det.scout.v1",
            supportedRoles: [.scout])
        let adapter2 = BASOrganDeterministicAdapter(
            providerID: "det.core.v1",
            supportedRoles: [.core])
        await registry.register(adapter1)
        await registry.register(adapter2)

        try await registry.unregister(providerID: "det.core.v1")

        let summary = await registry.coverageSummary(
            turnID: "t-1", sessionID: "s-1", emittedAt: t0)
        XCTAssertFalse(
            summary.hasCoreSignalCoverage,
            "unregistering the only core provider drops core coverage")
        XCTAssertEqual(summary.distinctSubjectCount, 1)
    }

    // MARK: - Cross-layer report integration

    func testNeuralOrganSummaryFeedsReconciliationReport(
    ) async throws {
        let registry = BASOrganRegistry()
        let adapter = BASOrganDeterministicAdapter(
            providerID: "det.v1",
            supportedRoles: [.scout, .core])
        await registry.register(adapter)

        let summary = await registry.coverageSummary(
            turnID: "t-1", sessionID: "s-1", emittedAt: t0)
        let report = BASObservationReconciliationReport(
            turnID: "t-1", sessionID: "s-1",
            summaries: [summary])
        XCTAssertEqual(report.coveredLayers, [.neuralOrgan])
        XCTAssertTrue(
            report.isFullyObserved(
                expected: [.neuralOrgan]))
    }
}
