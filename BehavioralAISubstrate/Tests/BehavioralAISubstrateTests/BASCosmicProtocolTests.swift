import XCTest
@testable import BASOrchestration
import BASRuntimeCore

/// M439 (chapter 一百十四) — parity-lock tests for the 7 new
/// L4/L7/L9/L10 schemas in `BASCosmicProtocol.swift`. Each
/// schema gets:
///
///   1. Codable round-trip (encode/decode preserves all fields)
///   2. Field clamping invariants (`[0, 1]` doubles + non-empty
///      string IDs)
///
/// Each helper enum gets:
///
///   1. Cardinality pin (`.allCases.count` matches doctrine)
///   2. Raw-value stability pin (exact strings, drift detector)
///
/// Doctrine pins:
///
///   - chapter 一百三 / 一百十三 magic-number doctrine: `[0, 1]`
///     clamping enforced via `min(1, max(0, x))` in init
///   - chapter 八十七 / M287 stable kebab-case raw values
///   - chapter 一百十 schema bump doctrine: each schema has a
///     `currentSchemaVersion` field pinned in tests
///
/// Total: 7 schemas × 2 tests + 4 enums × 2 tests = 22 tests.
final class BASCosmicProtocolTests: XCTestCase {

    // MARK: - 1. BASCosmicScaleHorizon enum

    func testBASCosmicScaleHorizonHasSixCases() {
        XCTAssertEqual(
            BASCosmicScaleHorizon.allCases.count, 6,
            "doctrine: 6 horizon cases (3 temporal + 3 spatial)")
    }

    func testBASCosmicScaleHorizonRawValuesAreStable() {
        XCTAssertEqual(
            BASCosmicScaleHorizon.temporalShort.rawValue,
            "temporal-short")
        XCTAssertEqual(
            BASCosmicScaleHorizon.temporalMedium.rawValue,
            "temporal-medium")
        XCTAssertEqual(
            BASCosmicScaleHorizon.temporalDeep.rawValue,
            "temporal-deep")
        XCTAssertEqual(
            BASCosmicScaleHorizon.spatialLocal.rawValue,
            "spatial-local")
        XCTAssertEqual(
            BASCosmicScaleHorizon.spatialBroad.rawValue,
            "spatial-broad")
        XCTAssertEqual(
            BASCosmicScaleHorizon.spatialCosmic.rawValue,
            "spatial-cosmic")
    }

    // MARK: - 2. BASOntologyFogQuality enum

    func testBASOntologyFogQualityHasThreeCases() {
        XCTAssertEqual(
            BASOntologyFogQuality.allCases.count, 3,
            "doctrine: 3 grasp quality levels")
    }

    func testBASOntologyFogQualityRawValuesAreStable() {
        XCTAssertEqual(
            BASOntologyFogQuality.partialGrasp.rawValue,
            "partial-grasp")
        XCTAssertEqual(
            BASOntologyFogQuality.provisionalNaming.rawValue,
            "provisional-naming")
        XCTAssertEqual(
            BASOntologyFogQuality.unnameable.rawValue,
            "unnameable")
    }

    // MARK: - 3. BASOntologyShiftAxis enum

    func testBASOntologyShiftAxisHasFiveCases() {
        XCTAssertEqual(
            BASOntologyShiftAxis.allCases.count, 5,
            "doctrine: 5 shift axes (relation/power/narrative/" +
            "intent/causality)")
    }

    func testBASOntologyShiftAxisRawValuesAreStable() {
        XCTAssertEqual(
            BASOntologyShiftAxis.relation.rawValue, "relation")
        XCTAssertEqual(
            BASOntologyShiftAxis.power.rawValue, "power")
        XCTAssertEqual(
            BASOntologyShiftAxis.narrative.rawValue, "narrative")
        XCTAssertEqual(
            BASOntologyShiftAxis.intent.rawValue, "intent")
        XCTAssertEqual(
            BASOntologyShiftAxis.causality.rawValue, "causality")
    }

    // MARK: - 4. BASNonEuclideanFailureMode enum

    func testBASNonEuclideanFailureModeHasFourCases() {
        XCTAssertEqual(
            BASNonEuclideanFailureMode.allCases.count, 4,
            "doctrine: 4 canonical failure modes")
    }

    func testBASNonEuclideanFailureModeRawValuesAreStable() {
        XCTAssertEqual(
            BASNonEuclideanFailureMode.collapsedOnGrasp.rawValue,
            "collapsed-on-grasp")
        XCTAssertEqual(
            BASNonEuclideanFailureMode.boundaryViolation.rawValue,
            "boundary-violation")
        XCTAssertEqual(
            BASNonEuclideanFailureMode.topologyDistortion.rawValue,
            "topology-distortion")
        XCTAssertEqual(
            BASNonEuclideanFailureMode.consistencyLoss.rawValue,
            "consistency-loss")
    }

    // MARK: - 5. BASCosmicScaleView round-trip + clamping

    func testBASCosmicScaleViewCodableRoundTrip() throws {
        let original = BASCosmicScaleView(
            scaleID: "cosmic-scale-test-1",
            observedSubjectRef: "subject-1",
            temporalHorizon: .temporalDeep,
            spatialHorizon: .spatialCosmic,
            agenticHorizonScale: 0.7,
            consequenceDilutionWarning: true)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let restored = try decoder.decode(
            BASCosmicScaleView.self, from: data)
        XCTAssertEqual(original, restored)
    }

    func testBASCosmicScaleViewClampsAgenticHorizonScale() {
        let high = BASCosmicScaleView(
            scaleID: "high",
            observedSubjectRef: "x",
            temporalHorizon: .temporalShort,
            spatialHorizon: .spatialLocal,
            agenticHorizonScale: 5.0,  // out of range
            consequenceDilutionWarning: false)
        XCTAssertEqual(high.agenticHorizonScale, 1.0)
        let low = BASCosmicScaleView(
            scaleID: "low",
            observedSubjectRef: "x",
            temporalHorizon: .temporalShort,
            spatialHorizon: .spatialLocal,
            agenticHorizonScale: -2.0,  // out of range
            consequenceDilutionWarning: false)
        XCTAssertEqual(low.agenticHorizonScale, 0.0)
    }

    // MARK: - 6. BASTemporalDepthMap round-trip + clamping

    func testBASTemporalDepthMapCodableRoundTrip() throws {
        let original = BASTemporalDepthMap(
            mapID: "depth-map-test-1",
            timelineRefs: ["t1", "t2", "t3"],
            sedimentLayers: [.temporalShort, .temporalDeep],
            nonSimultaneityMarks: ["past-vs-plan"],
            observationWindow: "lifetime")
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(
            BASTemporalDepthMap.self, from: data)
        XCTAssertEqual(original, restored)
    }

    func testBASTemporalDepthMapTrimsAndFiltersEmptyRefs() {
        let m = BASTemporalDepthMap(
            mapID: "  trim-id  ",
            timelineRefs: ["  t1  ", "", "  ", "t2"],
            sedimentLayers: [],
            nonSimultaneityMarks: [" mark1 ", ""],
            observationWindow: "  window  ")
        XCTAssertEqual(m.mapID, "trim-id")
        XCTAssertEqual(m.timelineRefs, ["t1", "t2"])
        XCTAssertEqual(m.nonSimultaneityMarks, ["mark1"])
        XCTAssertEqual(m.observationWindow, "window")
    }

    // MARK: - 7. BASOntologyFog round-trip + clamping

    func testBASOntologyFogCodableRoundTrip() throws {
        let original = BASOntologyFog(
            fogID: "fog-test-1",
            fogRegions: ["region-A", "region-B"],
            nameableAnchors: ["anchor-1"],
            unnameableMarks: ["mark-1"],
            partialGraspQuality: .provisionalNaming)
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(
            BASOntologyFog.self, from: data)
        XCTAssertEqual(original, restored)
    }

    func testBASOntologyFogTrimsAndFiltersEmptyEntries() {
        let f = BASOntologyFog(
            fogID: "  fog  ",
            fogRegions: ["  r1  ", "", "r2"],
            nameableAnchors: ["a", " ", "b"],
            unnameableMarks: ["", "m1"],
            partialGraspQuality: .unnameable)
        XCTAssertEqual(f.fogID, "fog")
        XCTAssertEqual(f.fogRegions, ["r1", "r2"])
        XCTAssertEqual(f.nameableAnchors, ["a", "b"])
        XCTAssertEqual(f.unnameableMarks, ["m1"])
    }

    // MARK: - 8. BASOntologyShiftMark round-trip + clamping

    func testBASOntologyShiftMarkCodableRoundTrip() throws {
        let original = BASOntologyShiftMark(
            markID: "shift-mark-test-1",
            targetSubjectRef: "subject-1",
            observedShiftAxes: [.relation, .narrative, .intent],
            prePostAnchors: ["pre-1", "post-1", "pre-2", "post-2"],
            shiftConfidence: 0.85)
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(
            BASOntologyShiftMark.self, from: data)
        XCTAssertEqual(original, restored)
    }

    func testBASOntologyShiftMarkClampsConfidence() {
        let high = BASOntologyShiftMark(
            markID: "high",
            targetSubjectRef: "x",
            observedShiftAxes: [.power],
            prePostAnchors: [],
            shiftConfidence: 1.5)
        XCTAssertEqual(high.shiftConfidence, 1.0)
        let low = BASOntologyShiftMark(
            markID: "low",
            targetSubjectRef: "x",
            observedShiftAxes: [.power],
            prePostAnchors: [],
            shiftConfidence: -0.3)
        XCTAssertEqual(low.shiftConfidence, 0.0)
    }

    // MARK: - 9. BASNonEuclideanCandidate round-trip + clamping

    func testBASNonEuclideanCandidateCodableRoundTrip() throws {
        let original = BASNonEuclideanCandidate(
            candidateID: "noneuclidean-test-1",
            nonStandardTopology: "recursive-self-reference",
            consistentUnderPartialView: true,
            failureModeWhenGrasped: .topologyDistortion,
            supportingAnchors: ["anchor-A", "anchor-B"])
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(
            BASNonEuclideanCandidate.self, from: data)
        XCTAssertEqual(original, restored)
    }

    func testBASNonEuclideanCandidateTrimsSupportingAnchors() {
        let c = BASNonEuclideanCandidate(
            candidateID: " cand ",
            nonStandardTopology: "  topo  ",
            consistentUnderPartialView: false,
            failureModeWhenGrasped: .consistencyLoss,
            supportingAnchors: ["", " a ", "b", "  "])
        XCTAssertEqual(c.candidateID, "cand")
        XCTAssertEqual(c.nonStandardTopology, "topo")
        XCTAssertEqual(c.supportingAnchors, ["a", "b"])
    }

    // MARK: - 10. BASUnknownRetentionLoop round-trip + clamping

    func testBASUnknownRetentionLoopCodableRoundTrip() throws {
        let original = BASUnknownRetentionLoop(
            loopID: "retention-loop-test-1",
            preservedUnknownRefs: ["unknown-A", "unknown-B"],
            coolingPeriodSeconds: 3600,
            safeAssertionCeiling: 0.4,
            reExamineTriggers: ["new-evidence", "host-request"])
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(
            BASUnknownRetentionLoop.self, from: data)
        XCTAssertEqual(original, restored)
    }

    func testBASUnknownRetentionLoopClampsCoolingAndCeiling() {
        let neg = BASUnknownRetentionLoop(
            loopID: "neg",
            preservedUnknownRefs: [],
            coolingPeriodSeconds: -100,  // negative clamps to 0
            safeAssertionCeiling: -0.5,  // clamps to 0
            reExamineTriggers: [])
        XCTAssertEqual(neg.coolingPeriodSeconds, 0)
        XCTAssertEqual(neg.safeAssertionCeiling, 0.0)
        let high = BASUnknownRetentionLoop(
            loopID: "high",
            preservedUnknownRefs: [],
            coolingPeriodSeconds: 86400,
            safeAssertionCeiling: 2.5,  // clamps to 1.0
            reExamineTriggers: [])
        XCTAssertEqual(high.coolingPeriodSeconds, 86400)
        XCTAssertEqual(high.safeAssertionCeiling, 1.0)
    }

    // MARK: - 11. BASCosmicColdCounterweight round-trip + clamping

    func testBASCosmicColdCounterweightCodableRoundTrip() throws {
        let original = BASCosmicColdCounterweight(
            counterweightID: "counterweight-test-1",
            dignityBias: 0.8,
            agencyFloor: 0.6,
            antiFatalism: 0.7,
            antiPaternalism: 0.9)
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(
            BASCosmicColdCounterweight.self, from: data)
        XCTAssertEqual(original, restored)
    }

    func testBASCosmicColdCounterweightClampsAllFourFields() {
        let cw = BASCosmicColdCounterweight(
            counterweightID: "clamp",
            dignityBias: 1.5,    // clamps to 1.0
            agencyFloor: -0.5,    // clamps to 0.0
            antiFatalism: 5.0,    // clamps to 1.0
            antiPaternalism: -2.0)  // clamps to 0.0
        XCTAssertEqual(cw.dignityBias, 1.0)
        XCTAssertEqual(cw.agencyFloor, 0.0)
        XCTAssertEqual(cw.antiFatalism, 1.0)
        XCTAssertEqual(cw.antiPaternalism, 0.0)
    }

    /// Pin: `aggregateStrength` is the pure mean of the 4
    /// fields. Drift here would change the cross-package
    /// comparison contract (chapter 一百八七 M287 doctrine —
    /// weighting belongs to policy, not the schema).
    func testBASCosmicColdCounterweightAggregateStrengthIsMean() {
        let cw = BASCosmicColdCounterweight(
            counterweightID: "agg",
            dignityBias: 0.8,
            agencyFloor: 0.6,
            antiFatalism: 0.4,
            antiPaternalism: 0.2)
        // Mean = (0.8 + 0.6 + 0.4 + 0.2) / 4 = 0.5
        XCTAssertEqual(
            cw.aggregateStrength, 0.5, accuracy: 0.0001)
    }

    // MARK: - 12. Schema-version invariants

    /// All 7 schemas pin to v1.0.0 on chapter 一百十四 / M439
    /// initial ship. Drift here would silently break Codable
    /// version-check downstream (chapter 一百十 schema-bump
    /// doctrine).
    func testAllSchemasShipAtVersionOnePointZero() {
        XCTAssertEqual(
            BASCosmicScaleView.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASTemporalDepthMap.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASOntologyFog.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASOntologyShiftMark.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASNonEuclideanCandidate.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASUnknownRetentionLoop.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASCosmicColdCounterweight.currentSchemaVersion, "1.0.0")
    }
}
