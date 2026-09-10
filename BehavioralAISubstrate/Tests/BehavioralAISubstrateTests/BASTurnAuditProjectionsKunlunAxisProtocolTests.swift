// MARK: - BASTurnAuditProjectionsKunlunAxisProtocolTests
// chapter 四百九十三 / M1348 — Kunlun axis + alignment fold tests

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore

final class BASTurnAuditProjectionsKunlunAxisProtocolTests:
    XCTestCase
{

    // MARK: - Fixture inputs

    private let kunlunActiveLayerRefs: [String] = [
        "L1", "L2", "L3", "L4", "L5", "L6",
        "L7", "L8", "L9", "L10", "L11", "L12",
        "L13", "L14",
    ]

    private func centerlineRules(
        for mode: BASActionPermitMode
    ) -> [String] {
        [
            "respects-host-boundary",
            "honors-world-anchor",
            "permit-mode-\(mode.rawValue)",
        ]
    }

    // MARK: - 1) Cooperative case — 3-of-3 matched

    func testAllPredicatesPassYieldsMatchedThree() {
        let result = BASTurnAuditProjectionsKunlunAxisProtocol
            .compute(
                sessionID: "S",
                hostID: "H",
                permitMode: .answer,
                riskLevel: .low,
                quarantineRecordsIsEmpty: true,
                humanAnchorRecommendedSurfaceTone:
                    .plain,
                sovereignEscalationHint: nil,
                primaryCandidateID: "C",
                kunlunActiveLayerRefs:
                    kunlunActiveLayerRefs,
                centerlineRules:
                    centerlineRules(for: .answer),
                kunlunAxisDeviationThreshold: 0.7)

        XCTAssertEqual(result.matched, 3)
        XCTAssertTrue(result.deviationCodes.isEmpty)
        XCTAssertEqual(result.axis.axisID, "axis-S")
        XCTAssertEqual(result.axis.hostRef, "H")
        XCTAssertEqual(result.alignment.targetRef, "C")
    }

    // MARK: - 2) Quarantine + block permit collapses host
    //             boundary predicate

    func testQuarantineAndBlockPermitFailsHostBoundary() {
        let result = BASTurnAuditProjectionsKunlunAxisProtocol
            .compute(
                sessionID: "S",
                hostID: "H",
                permitMode: .block,
                riskLevel: .high,
                quarantineRecordsIsEmpty: false,
                humanAnchorRecommendedSurfaceTone:
                    .plain,
                sovereignEscalationHint: nil,
                primaryCandidateID: "C",
                kunlunActiveLayerRefs:
                    kunlunActiveLayerRefs,
                centerlineRules:
                    centerlineRules(for: .block),
                kunlunAxisDeviationThreshold: 0.7)

        XCTAssertEqual(result.matched, 1)
        XCTAssertTrue(result.deviationCodes
            .contains("host-boundary-not-respected"))
        XCTAssertTrue(result.deviationCodes
            .contains("permit-mode-non-cooperative"))
        XCTAssertTrue(result.deviationCodes
            .contains("risk-high-narrows-axis"))
    }

    // MARK: - 3) Reserved tone + escalation hint fails
    //             world anchor predicate

    func testReservedToneAndEscalationFailsWorldAnchor() {
        let result = BASTurnAuditProjectionsKunlunAxisProtocol
            .compute(
                sessionID: "S",
                hostID: "H",
                permitMode: .answer,
                riskLevel: .extreme,
                quarantineRecordsIsEmpty: true,
                humanAnchorRecommendedSurfaceTone:
                    .reserved,
                sovereignEscalationHint:
                    "escalate-hint",
                primaryCandidateID: "C",
                kunlunActiveLayerRefs:
                    kunlunActiveLayerRefs,
                centerlineRules:
                    centerlineRules(for: .answer),
                kunlunAxisDeviationThreshold: 0.7)

        XCTAssertEqual(result.matched, 2)
        XCTAssertTrue(result.deviationCodes
            .contains("world-anchor-not-honored"))
        XCTAssertTrue(result.deviationCodes
            .contains("risk-extreme-axis-overreach"))
    }

    // MARK: - 4) Alignment requiresGate when matched/3 < 0.7

    func testAlignmentRequiresGateBelowThreshold() {
        let result = BASTurnAuditProjectionsKunlunAxisProtocol
            .compute(
                sessionID: "S",
                hostID: "H",
                permitMode: .block,
                riskLevel: .high,
                quarantineRecordsIsEmpty: false,
                humanAnchorRecommendedSurfaceTone:
                    .reserved,
                sovereignEscalationHint:
                    "esc",
                primaryCandidateID: "C",
                kunlunActiveLayerRefs:
                    kunlunActiveLayerRefs,
                centerlineRules:
                    centerlineRules(for: .block),
                kunlunAxisDeviationThreshold: 0.7)
        XCTAssertTrue(result.alignment.requiresGate)
    }

    // MARK: - 5) Determinism

    func testFactoryIsDeterministic() {
        let r1 = BASTurnAuditProjectionsKunlunAxisProtocol
            .compute(
                sessionID: "S",
                hostID: "H",
                permitMode: .mirror,
                riskLevel: .medium,
                quarantineRecordsIsEmpty: true,
                humanAnchorRecommendedSurfaceTone:
                    .plain,
                sovereignEscalationHint: nil,
                primaryCandidateID: "C",
                kunlunActiveLayerRefs:
                    kunlunActiveLayerRefs,
                centerlineRules:
                    centerlineRules(for: .mirror),
                kunlunAxisDeviationThreshold: 0.7)
        let r2 = BASTurnAuditProjectionsKunlunAxisProtocol
            .compute(
                sessionID: "S",
                hostID: "H",
                permitMode: .mirror,
                riskLevel: .medium,
                quarantineRecordsIsEmpty: true,
                humanAnchorRecommendedSurfaceTone:
                    .plain,
                sovereignEscalationHint: nil,
                primaryCandidateID: "C",
                kunlunActiveLayerRefs:
                    kunlunActiveLayerRefs,
                centerlineRules:
                    centerlineRules(for: .mirror),
                kunlunAxisDeviationThreshold: 0.7)
        XCTAssertEqual(r1.matched, r2.matched)
        XCTAssertEqual(r1.deviationCodes,
                       r2.deviationCodes)
        XCTAssertEqual(r1.axis.axisID, r2.axis.axisID)
    }

    // MARK: - 6) Sendable conformance

    func testBundleIsSendable() async {
        let result = BASTurnAuditProjectionsKunlunAxisProtocol
            .compute(
                sessionID: "S",
                hostID: "H",
                permitMode: .answer,
                riskLevel: .low,
                quarantineRecordsIsEmpty: true,
                humanAnchorRecommendedSurfaceTone:
                    .plain,
                sovereignEscalationHint: nil,
                primaryCandidateID: "C",
                kunlunActiveLayerRefs:
                    kunlunActiveLayerRefs,
                centerlineRules:
                    centerlineRules(for: .answer),
                kunlunAxisDeviationThreshold: 0.7)
        let captured = result
        let task = Task {
            captured.matched
        }
        let value = await task.value
        XCTAssertEqual(value, 3)
    }
}
