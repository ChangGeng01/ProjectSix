import XCTest
@testable import BASOrchestration
import BASRuntimeCore

/// M440 (chapter 一百十五) — parity-lock tests for the L1/L3/L8/L13
/// layer-naming schemas in `BASAbyssalLayerNaming.swift`.
///
/// Test matrix:
///
///   - 4 enums × (cardinality + raw-value stability) = 8 tests
///   - 2 schemas × (Codable round-trip + clamping) = 4 tests
///   - Schema-version pin = 1 test
///   - AbyssBudget aggregateAvailability mean pin = 1 test
///   - ForbiddenCandidateZone parallel-array invariant = 1 test
///
/// Total: 15 tests.
final class BASAbyssalLayerNamingTests: XCTestCase {

    // MARK: - L1 BASAbyssalRunMode

    func testBASAbyssalRunModeHasSixCases() {
        XCTAssertEqual(
            BASAbyssalRunMode.allCases.count, 6,
            "Cthulhu Spec V1 §5.1 enumerates 6 modes")
    }

    func testBASAbyssalRunModeRawValuesAreStable() {
        XCTAssertEqual(
            BASAbyssalRunMode.tideSurface.rawValue, "tide-surface")
        XCTAssertEqual(
            BASAbyssalRunMode.nearShore.rawValue, "near-shore")
        XCTAssertEqual(
            BASAbyssalRunMode.deepDive.rawValue, "deep-dive")
        XCTAssertEqual(
            BASAbyssalRunMode.stormGuard.rawValue, "storm-guard")
        XCTAssertEqual(
            BASAbyssalRunMode.sealedHarbor.rawValue, "sealed-harbor")
        XCTAssertEqual(
            BASAbyssalRunMode.sunkenSeal.rawValue, "sunken-seal")
    }

    // MARK: - L1 BASAbyssBudget

    func testBASAbyssBudgetCodableRoundTrip() throws {
        let original = BASAbyssBudget(
            budgetID: "abyss-budget-test-1",
            deepDiveQuota: 0.6,
            anomalyTolerance: 0.4,
            safeSurfaceFloor: 0.3,
            sovereignReserve: 0.2)
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(
            BASAbyssBudget.self, from: data)
        XCTAssertEqual(original, restored)
    }

    func testBASAbyssBudgetClampsAllFourFields() {
        let cw = BASAbyssBudget(
            budgetID: "clamp",
            deepDiveQuota: 1.5,    // clamps to 1.0
            anomalyTolerance: -0.5,  // clamps to 0.0
            safeSurfaceFloor: 5.0,    // clamps to 1.0
            sovereignReserve: -2.0)  // clamps to 0.0
        XCTAssertEqual(cw.deepDiveQuota, 1.0)
        XCTAssertEqual(cw.anomalyTolerance, 0.0)
        XCTAssertEqual(cw.safeSurfaceFloor, 1.0)
        XCTAssertEqual(cw.sovereignReserve, 0.0)
    }

    /// Pin: aggregateAvailability is the pure mean of 4 fields
    /// (chapter 一百八七 M287 doctrine — weighting belongs to
    /// policy, not schema).
    func testBASAbyssBudgetAggregateAvailabilityIsMean() {
        let b = BASAbyssBudget(
            budgetID: "agg",
            deepDiveQuota: 0.8,
            anomalyTolerance: 0.6,
            safeSurfaceFloor: 0.4,
            sovereignReserve: 0.2)
        // Mean = (0.8 + 0.6 + 0.4 + 0.2) / 4 = 0.5
        XCTAssertEqual(
            b.aggregateAvailability, 0.5, accuracy: 0.0001)
    }

    // MARK: - L3 BASAbyssFoldLayer

    func testBASAbyssFoldLayerHasFiveCases() {
        XCTAssertEqual(
            BASAbyssFoldLayer.allCases.count, 5,
            "Cthulhu Spec V1 §5.3 enumerates 5 fold layers")
    }

    func testBASAbyssFoldLayerRawValuesAreStable() {
        XCTAssertEqual(
            BASAbyssFoldLayer.surfaceFold.rawValue, "surface-fold")
        XCTAssertEqual(
            BASAbyssFoldLayer.midFold.rawValue, "mid-fold")
        XCTAssertEqual(
            BASAbyssFoldLayer.deepFold.rawValue, "deep-fold")
        XCTAssertEqual(
            BASAbyssFoldLayer.abyssalFold.rawValue, "abyssal-fold")
        XCTAssertEqual(
            BASAbyssFoldLayer.oldSealFold.rawValue, "old-seal-fold")
    }

    // MARK: - L3 BASFoldRecoveryState

    func testBASFoldRecoveryStateHasThreeCases() {
        XCTAssertEqual(
            BASFoldRecoveryState.allCases.count, 3,
            "Cthulhu Spec V1 §5.3 enumerates 3 recovery states")
    }

    func testBASFoldRecoveryStateRawValuesAreStable() {
        XCTAssertEqual(
            BASFoldRecoveryState.abyssFold.rawValue, "abyss-fold")
        XCTAssertEqual(
            BASFoldRecoveryState.sealBound.rawValue, "seal-bound")
        XCTAssertEqual(
            BASFoldRecoveryState.purged.rawValue, "purged")
    }

    // MARK: - L8 BASMemoryTemperatureLayer

    func testBASMemoryTemperatureLayerHasFiveCases() {
        XCTAssertEqual(
            BASMemoryTemperatureLayer.allCases.count, 5,
            "Cthulhu Spec V1 §5.8 enumerates 5 thermal layers")
    }

    func testBASMemoryTemperatureLayerRawValuesAreStable() {
        XCTAssertEqual(
            BASMemoryTemperatureLayer.tideSurfaceMemory.rawValue,
            "tide-surface-memory")
        XCTAssertEqual(
            BASMemoryTemperatureLayer.midLayerMemory.rawValue,
            "mid-layer-memory")
        XCTAssertEqual(
            BASMemoryTemperatureLayer.deepWellMemory.rawValue,
            "deep-well-memory")
        XCTAssertEqual(
            BASMemoryTemperatureLayer.abyssalMemory.rawValue,
            "abyssal-memory")
        XCTAssertEqual(
            BASMemoryTemperatureLayer.oldSealMemory.rawValue,
            "old-seal-memory")
    }

    // MARK: - L13 BASForbiddenCandidateZone

    func testBASForbiddenCandidateZoneCodableRoundTrip() throws {
        let original = BASForbiddenCandidateZone(
            zoneID: "forbidden-zone-test-1",
            quarantinedCandidateRefs: ["cand-A", "cand-B"],
            quarantineReasonCodes: [
                "abyssal-pressure-high",
                "contamination-lineage",
            ],
            releaseConditions: [
                "sovereign-warrant",
                "host-explicit-recall",
            ],
            auditRef: "audit-zone-1")
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(
            BASForbiddenCandidateZone.self, from: data)
        XCTAssertEqual(original, restored)
    }

    /// Pin: parallel-array invariant — when
    /// `quarantinedCandidateRefs.count != quarantineReasonCodes.count`
    /// the init truncates to the shorter length so consumers
    /// can iterate by index without bounds checks.
    func testBASForbiddenCandidateZoneTruncatesParallelArrays() {
        let z = BASForbiddenCandidateZone(
            zoneID: "truncate",
            quarantinedCandidateRefs: ["cand-A", "cand-B", "cand-C"],
            quarantineReasonCodes: ["reason-1", "reason-2"],
            releaseConditions: [],
            auditRef: "audit")
        XCTAssertEqual(z.quarantinedCandidateRefs.count, 2)
        XCTAssertEqual(z.quarantineReasonCodes.count, 2)
        XCTAssertEqual(z.quarantinedCandidateRefs, ["cand-A", "cand-B"])
        XCTAssertEqual(z.quarantineReasonCodes, ["reason-1", "reason-2"])
    }

    // MARK: - Schema version pin

    func testAllSchemasShipAtVersionOnePointZero() {
        XCTAssertEqual(BASAbyssBudget.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASForbiddenCandidateZone.currentSchemaVersion, "1.0.0")
    }
}
