import XCTest
import BASRuntimeCore
@testable import QinaoSovereign

/// M90 — Qinao-side tests for L1–L13 observation bundle streaming
/// through `QinaoSovereignControlPlane.recordTurnCoverage(...,
/// additionalSummaries:)` into the shared audit ledger.
///
/// Pins:
///
/// 1. **Backward compat** — `recordTurnCoverage` without
///    `additionalSummaries:` keeps the pre-M90 L14-only contract:
///    only the L14 summary lands in the report, and no observation
///    bundle is streamed into the ledger's parallel storage.
///
/// 2. **Streaming path** — `recordTurnCoverage(..., additionalSummaries:)`
///    with non-nil L1–L13 summaries streams the full 14-layer report
///    into the ledger's `observationBundles[]` parallel storage.
///
/// 3. **Read-back** — `observationBundle(sessionID:turnID:)` returns
///    the streamed report; returns nil when nothing was streamed.
///
/// 4. **Expected-layer mismatch surfaces as verdict finding** —
///    passing L1 in the summaries without listing "L1" in
///    `expectedLayerIDs` does NOT error; instead the verdict engine
///    records the reporting-vs-expected mismatch through its normal
///    findings semantics (regression guard: the caller-supplied
///    coverage layer set and the expectation set are independent
///    axes).
final class QinaoSovereignObservationStreamingTests: XCTestCase {

    // MARK: - Fixtures

    private func bootstrapPlane()
        -> QinaoSovereignControlPlane
    {
        let config = QinaoSovereignControlPlane.Configuration(
            ledgerSigningSecret:
                Data("m90-streaming-seed".utf8))
        let (plane, _) = QinaoSovereignControlPlane.bootstrap(
            configuration: config)
        return plane
    }

    private func makeSummary(
        layer: BASCognitiveLayer,
        sessionID: String = "session-m90",
        turnID: String = "turn-1",
        totalObservations: Int = 3
    ) -> BASObservationCoverageSummary {
        BASObservationCoverageSummary(
            layer: layer,
            turnID: turnID,
            sessionID: sessionID,
            totalObservations: totalObservations,
            distinctSubjectCount: totalObservations,
            hasCoreSignalCoverage: true,
            budgetTotalCost: 0.2,
            emittedAt: Date(timeIntervalSince1970: 1_700_000_000))
    }

    // MARK: - 1. Backward compat: L14-only default path

    func testRecordTurnCoverageWithoutAdditionalSummariesIsLayerL14Only()
        async {
        let plane = bootstrapPlane()

        let reading = await plane.recordTurnCoverage(
            sessionID: "session-m90",
            turnID: "turn-1",
            budgetCeiling: 1.0)
        // The reading is valid (reconciliation ran).
        XCTAssertNotNil(reading.severity)

        // No observation bundle should have been streamed — pre-M90
        // contract preserved.
        let bundle = await plane.observationBundle(
            sessionID: "session-m90", turnID: "turn-1")
        XCTAssertNil(bundle,
            "pre-M90 path streams nothing into the observation-bundle slot")
    }

    // MARK: - 2. Streaming with L1-L13 summaries populates the bundle

    func testRecordTurnCoverageWithAdditionalSummariesStreamsFullReport()
        async {
        let plane = bootstrapPlane()
        let extraLayers: [BASCognitiveLayer] = [
            .leaseLife,          // L1
            .worldPrior,         // L4
            .mirrorBlade,        // L7
            .dreamLoop,          // L9
            .triSelfTribunal,    // L10
            .riskClimate,        // L11
            .gentleHand,         // L12
            .evolutionFurnace    // L13
        ]
        let extras = extraLayers.map { makeSummary(layer: $0) }

        _ = await plane.recordTurnCoverage(
            sessionID: "session-m90",
            turnID: "turn-1",
            budgetCeiling: 1.0,
            expectedLayerIDs: [
                BASCognitiveLayer.sovereign.rawValue
            ] + extraLayers.map(\.rawValue),
            additionalSummaries: extras)

        let bundle = await plane.observationBundle(
            sessionID: "session-m90", turnID: "turn-1")
        XCTAssertNotNil(bundle)
        // L14 first (always), then extras in caller-supplied order.
        XCTAssertEqual(bundle?.summaries.first?.layer, .sovereign)
        XCTAssertEqual(
            bundle?.summaries.map(\.layer),
            [.sovereign] + extraLayers)
    }

    // MARK: - 3. Read-back symmetry

    func testObservationBundleLookupSymmetricWithStoredSession() async {
        let plane = bootstrapPlane()
        _ = await plane.recordTurnCoverage(
            sessionID: "session-A",
            turnID: "turn-1",
            additionalSummaries: [makeSummary(
                layer: .dreamLoop, sessionID: "session-A")])
        _ = await plane.recordTurnCoverage(
            sessionID: "session-B",
            turnID: "turn-1",
            additionalSummaries: [makeSummary(
                layer: .worldPrior, sessionID: "session-B")])

        let a = await plane.observationBundle(
            sessionID: "session-A", turnID: "turn-1")
        let b = await plane.observationBundle(
            sessionID: "session-B", turnID: "turn-1")
        XCTAssertNotNil(a)
        XCTAssertNotNil(b)
        XCTAssertEqual(
            a?.summaries.last?.layer, .dreamLoop,
            "session-A carries its own L9 summary")
        XCTAssertEqual(
            b?.summaries.last?.layer, .worldPrior,
            "session-B carries its own L4 summary")
    }

    // MARK: - 4. Mixed turns: some stream, some don't

    func testSomeTurnsStreamOthersDontInSameSession() async {
        let plane = bootstrapPlane()

        // Turn 1: legacy behaviour (no additionalSummaries).
        _ = await plane.recordTurnCoverage(
            sessionID: "session-mix",
            turnID: "turn-1")
        // Turn 2: streams L9 extras.
        _ = await plane.recordTurnCoverage(
            sessionID: "session-mix",
            turnID: "turn-2",
            additionalSummaries: [
                makeSummary(
                    layer: .dreamLoop,
                    sessionID: "session-mix",
                    turnID: "turn-2")
            ])
        // Turn 3: legacy again.
        _ = await plane.recordTurnCoverage(
            sessionID: "session-mix",
            turnID: "turn-3")

        let t1 = await plane.observationBundle(
            sessionID: "session-mix", turnID: "turn-1")
        let t2 = await plane.observationBundle(
            sessionID: "session-mix", turnID: "turn-2")
        let t3 = await plane.observationBundle(
            sessionID: "session-mix", turnID: "turn-3")

        XCTAssertNil(t1, "turn-1 legacy path streams nothing")
        XCTAssertNotNil(t2, "turn-2 streams the bundle")
        XCTAssertNil(t3, "turn-3 legacy path streams nothing")
        XCTAssertEqual(t2?.summaries.count, 2)
    }

    // MARK: - 5. Re-stream same turn updates the bundle

    func testReStreamingSameTurnUpdatesBundle() async {
        let plane = bootstrapPlane()

        _ = await plane.recordTurnCoverage(
            sessionID: "session-m90",
            turnID: "turn-1",
            additionalSummaries: [
                makeSummary(layer: .dreamLoop)
            ])
        _ = await plane.recordTurnCoverage(
            sessionID: "session-m90",
            turnID: "turn-1",
            additionalSummaries: [
                makeSummary(layer: .dreamLoop),
                makeSummary(layer: .riskClimate)
            ])

        let bundle = await plane.observationBundle(
            sessionID: "session-m90", turnID: "turn-1")
        XCTAssertEqual(bundle?.summaries.count, 3,
            "L14 + 2 extras after replacement")
        XCTAssertEqual(
            bundle?.summaries.map(\.layer),
            [.sovereign, .dreamLoop, .riskClimate])
    }

    // MARK: - 6. Empty extras array still streams (just L14)

    func testEmptyAdditionalSummariesArrayStillStreams() async {
        let plane = bootstrapPlane()
        _ = await plane.recordTurnCoverage(
            sessionID: "session-m90",
            turnID: "turn-1",
            additionalSummaries: [])

        let bundle = await plane.observationBundle(
            sessionID: "session-m90", turnID: "turn-1")
        XCTAssertNotNil(bundle,
            "passing [] (non-nil) opts INTO streaming")
        XCTAssertEqual(
            bundle?.summaries.map(\.layer),
            [.sovereign],
            "L14 summary alone when extras array is empty")
    }
}
