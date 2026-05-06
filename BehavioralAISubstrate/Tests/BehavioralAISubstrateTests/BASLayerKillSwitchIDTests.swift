// MARK: - BASLayerKillSwitchIDTests — chapter 三百〇一 / M788
//
// Phase Beta 第三刀 (final foundation cut) 测试覆盖:14-case kill
// switch enum + state record + 8-case reason enum + 5-case
// fallthrough strategy + error boundary report (with derive helper).

import XCTest
@testable import BASRuntimeCore

final class BASLayerKillSwitchIDTests: XCTestCase {

    private let referenceDate = Date(
        timeIntervalSince1970: 1_700_000_000)

    // MARK: - 14-case kill switch enum

    func testKillSwitchIDCardinality() {
        XCTAssertEqual(
            BASLayerKillSwitchID.allCases.count, 14,
            "14 cases match BASMotherboardLayer14 1:1 — chapter " +
            "二百九十九 plan extended from 3 to 14 per附录 W §W.3")
    }

    func testKillSwitchIDRawValueStability() {
        let expected: [(BASLayerKillSwitchID, String)] = [
            (.l1Wake, "l1-wake"),
            (.l2NeuralOrgan, "l2-neural-organ"),
            (.l3FoldedLung, "l3-folded-lung"),
            (.l4Horizon, "l4-horizon"),
            (.l5HostConstitution, "l5-host-constitution"),
            (.l6Situation, "l6-situation"),
            (.l7MirrorBlade, "l7-mirror-blade"),
            (.l8Memory, "l8-memory"),
            (.l9Dream, "l9-dream"),
            (.l10Tribunal, "l10-tribunal"),
            (.l11Risk, "l11-risk"),
            (.l12SoftHand, "l12-soft-hand"),
            (.l13Evolution, "l13-evolution"),
            (.l14Sovereign, "l14-sovereign")
        ]
        for (id, raw) in expected {
            XCTAssertEqual(id.rawValue, raw)
        }
    }

    func testKillSwitchIDLayerMappingBijection() {
        // Forward: switchID → layer
        // Inverse: layer → switchID
        // Compose: forLayer(motherboardLayer) == self for every case
        for switchID in BASLayerKillSwitchID.allCases {
            let layer = switchID.motherboardLayer
            let roundTrip = BASLayerKillSwitchID.forLayer(layer)
            XCTAssertEqual(
                roundTrip, switchID,
                "bijection invariant: " +
                "BASLayerKillSwitchID.forLayer(switchID.motherboardLayer)" +
                " == switchID for every case")
        }
        // Cover: every layer has a switchID
        for layer in BASMotherboardLayer14.allCases {
            let switchID = BASLayerKillSwitchID.forLayer(layer)
            XCTAssertEqual(switchID.motherboardLayer, layer)
        }
    }

    // MARK: - 8-case reason enum

    func testKillSwitchReasonCardinality() {
        XCTAssertEqual(
            BASLayerKillSwitchReason.allCases.count, 8,
            "8 reason cases enumerate observability vs sovereign-" +
            "scoped trip causes")
    }

    func testKillSwitchReasonRawValueStability() {
        XCTAssertEqual(
            BASLayerKillSwitchReason.manual.rawValue, "manual")
        XCTAssertEqual(
            BASLayerKillSwitchReason.thermalEmergency.rawValue,
            "thermal-emergency")
        XCTAssertEqual(
            BASLayerKillSwitchReason.sovereignVerdict.rawValue,
            "sovereign-verdict")
        XCTAssertEqual(
            BASLayerKillSwitchReason.budgetCascade.rawValue,
            "budget-cascade")
        XCTAssertEqual(
            BASLayerKillSwitchReason.observabilityHalt.rawValue,
            "observability-halt")
        XCTAssertEqual(
            BASLayerKillSwitchReason.quarantineEscalation.rawValue,
            "quarantine-escalation")
        XCTAssertEqual(
            BASLayerKillSwitchReason.errorBoundaryTrip.rawValue,
            "error-boundary-trip")
        XCTAssertEqual(
            BASLayerKillSwitchReason.dependencyMissing.rawValue,
            "dependency-missing")
    }

    // MARK: - State record

    func testStateDefaults() {
        let state = BASLayerKillSwitchState(
            switchID: .l11Risk,
            active: false)
        XCTAssertEqual(state.schemaVersion, "1.0.0")
        XCTAssertEqual(state.reason, .manual)
        XCTAssertEqual(state.detail, "")
        XCTAssertNil(state.activatedAt)
        XCTAssertNil(state.activatedBy)
    }

    func testStateTrimsStrings() {
        let state = BASLayerKillSwitchState(
            switchID: .l9Dream,
            active: true,
            reason: .sovereignVerdict,
            detail: "  thermal critical  \n",
            activatedAt: referenceDate,
            activatedBy: "  sentinel-x  ")
        XCTAssertEqual(state.detail, "thermal critical")
        XCTAssertEqual(state.activatedBy, "sentinel-x")
    }

    func testStateCodableRoundTrip() throws {
        let original = BASLayerKillSwitchState(
            switchID: .l14Sovereign,
            active: true,
            reason: .quarantineEscalation,
            detail: "contamination-suspected",
            activatedAt: referenceDate,
            activatedBy: "audit-agent")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASLayerKillSwitchState.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Fallthrough strategy enum

    func testFallthroughStrategyCardinality() {
        XCTAssertEqual(
            BASLayerErrorFallthroughStrategy.allCases.count, 5)
    }

    func testFallthroughStrategyRawValueStability() {
        XCTAssertEqual(
            BASLayerErrorFallthroughStrategy.gracefulSkip.rawValue,
            "graceful-skip")
        XCTAssertEqual(
            BASLayerErrorFallthroughStrategy.useLastKnown.rawValue,
            "use-last-known")
        XCTAssertEqual(
            BASLayerErrorFallthroughStrategy.mlHeadFallthrough
                .rawValue,
            "ml-head-fallthrough")
        XCTAssertEqual(
            BASLayerErrorFallthroughStrategy.abortTurn.rawValue,
            "abort-turn")
        XCTAssertEqual(
            BASLayerErrorFallthroughStrategy.sovereignEscalate
                .rawValue,
            "sovereign-escalate")
    }

    // MARK: - Error boundary report

    func testReportDefaults() {
        let report = BASLayerErrorBoundaryReport(
            layerID: .l9,
            errorKind: "budget-exceeded",
            capturedAt: referenceDate)
        XCTAssertEqual(report.schemaVersion, "1.0.0")
        XCTAssertEqual(
            report.fallthroughStrategy, .gracefulSkip)
        XCTAssertTrue(report.gracefulSkipApplied)
        XCTAssertEqual(report.detail, "")
    }

    func testReportCodableRoundTrip() throws {
        let original = BASLayerErrorBoundaryReport(
            layerID: .l11,
            errorKind: "kill-switch-active",
            detail: "thermal critical",
            fallthroughStrategy: .sovereignEscalate,
            gracefulSkipApplied: false,
            capturedAt: referenceDate)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASLayerErrorBoundaryReport.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Error boundary `from` builder doctrine pins

    func testFromBuilderL1WakeForcesAbortTurn() {
        let error = BASLayerActorError.internalFailure(
            layerID: .l1, message: "wake failed")
        let report = BASLayerErrorBoundaryReport.from(
            error: error, capturedAt: referenceDate)
        XCTAssertEqual(report.layerID, .l1)
        XCTAssertEqual(
            report.fallthroughStrategy, .abortTurn,
            "L1 wake error must abort turn (不变量 #1 — without " +
            "wake the turn cannot honor 先醒再答 doctrine)")
        XCTAssertFalse(report.gracefulSkipApplied)
    }

    func testFromBuilderL11RiskForcesSovereignEscalate() {
        let error = BASLayerActorError.budgetExceeded(
            layerID: .l11, allowedMs: 5)
        let report = BASLayerErrorBoundaryReport.from(
            error: error, capturedAt: referenceDate)
        XCTAssertEqual(
            report.fallthroughStrategy, .sovereignEscalate,
            "L11 permit error must escalate to sovereign (单提交口 " +
            "doctrine: permit authority cannot graceful-skip)")
    }

    func testFromBuilderL14SovereignForcesSovereignEscalate() {
        let error = BASLayerActorError.internalFailure(
            layerID: .l14, message: "verdict engine fault")
        let report = BASLayerErrorBoundaryReport.from(
            error: error, capturedAt: referenceDate)
        XCTAssertEqual(
            report.fallthroughStrategy, .sovereignEscalate)
    }

    func testFromBuilderQuarantineAlwaysEscalates() {
        // Even on observability layer, quarantine must escalate
        let error = BASLayerActorError.quarantine(
            layerID: .l9, reason: "contamination suspected")
        let report = BASLayerErrorBoundaryReport.from(
            error: error, capturedAt: referenceDate)
        XCTAssertEqual(
            report.fallthroughStrategy, .sovereignEscalate,
            "quarantine error always escalates regardless of " +
            "layer (chapter 一百三十 / BR-014 sovereign-domain-" +
            "scope: contamination requires L14 review)")
    }

    func testFromBuilderObservabilityLayerGracefulSkipsByDefault() {
        let error = BASLayerActorError.budgetExceeded(
            layerID: .l9, allowedMs: 50)
        let report = BASLayerErrorBoundaryReport.from(
            error: error, capturedAt: referenceDate)
        XCTAssertEqual(
            report.fallthroughStrategy, .gracefulSkip,
            "observability layers default to graceful-skip — " +
            "lose this turn's L9 dream loop output, turn continues")
        XCTAssertTrue(report.gracefulSkipApplied)
        XCTAssertEqual(report.errorKind, "budget-exceeded")
        XCTAssertEqual(report.detail, "allowed-ms:50.0")
    }

    func testFromBuilderCapturesErrorKindForAllFiveErrorVariants() {
        let cases: [(BASLayerActorError, String, String)] = [
            (.budgetExceeded(
                layerID: .l9, allowedMs: 5),
             "budget-exceeded",
             "allowed-ms:5.0"),
            (.killSwitchActive(
                layerID: .l11, reason: "manual"),
             "kill-switch-active",
             "manual"),
            (.dependencyMissing(
                layerID: .l4, missingRef: "world-prior-v2"),
             "dependency-missing",
             "world-prior-v2"),
            (.quarantine(
                layerID: .l14, reason: "sentinel"),
             "quarantine",
             "sentinel"),
            (.internalFailure(
                layerID: .l8, message: "store unreachable"),
             "internal-failure",
             "store unreachable")
        ]
        for (error, expectedKind, expectedDetail) in cases {
            let report = BASLayerErrorBoundaryReport.from(
                error: error, capturedAt: referenceDate)
            XCTAssertEqual(report.errorKind, expectedKind)
            XCTAssertEqual(report.detail, expectedDetail)
        }
    }
}
