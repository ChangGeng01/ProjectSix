// MARK: - BASTurnAuditProjectionsKunlunSealRiverTests
// chapter 四百九十三 / M1350 — Kunlun jade seal + river origin fold tests

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASPolicy

final class BASTurnAuditProjectionsKunlunSealRiverTests:
    XCTestCase
{

    private let riverOriginTransformationSteps: [String] = [
        "risk.bind", "permit.synthesize", "neural.materialize",
        "tribunal.merge", "audit.emit",
    ]

    // MARK: - 1) Seal shape

    func testSealCarriesCanonicalRefs() {
        let result =
            BASTurnAuditProjectionsKunlunSealRiver.compute(
                sessionID: "S",
                permitMode: .answer,
                requireMirror: false,
                requireCompare: false,
                requireSecondCheck: false,
                verdictID: "VDX",
                verdictLevel: "advisory",
                warrantIDs: ["W1", "W2"],
                candidateIDs: ["C1"],
                quarantineIDs: [],
                thoughtFoldID: "FOLD",
                thoughtFoldChecksum: "checksum-abc",
                riverOriginTransformationSteps:
                    riverOriginTransformationSteps)

        XCTAssertEqual(result.seal.sealID,
                       "jade-permit-S")
        XCTAssertEqual(result.seal.targetRef,
                       "permit-answer")
        XCTAssertEqual(result.seal.objectClass,
                       .actionPermit)
        XCTAssertTrue(result.seal.provenanceRefs
            .contains("verdict-VDX"))
        XCTAssertTrue(result.seal.provenanceRefs
            .contains("W1"))
        XCTAssertTrue(result.seal.provenanceRefs
            .contains("W2"))
        XCTAssertTrue(result.seal.provenanceRefs
            .contains("fold-FOLD"))
        XCTAssertEqual(result.seal.integrityHash,
                       "checksum-abc")
        XCTAssertEqual(result.seal.signatureRef, "VDX")
        XCTAssertFalse(result.seal.replayRequired)
        XCTAssertEqual(result.seal.revocationPath,
                       "rollback-S")
        XCTAssertEqual(result.seal.sourceRiverRef,
                       "river-S")
    }

    // MARK: - 2) replayRequired derives from any-of mirror/compare/secondCheck

    func testReplayRequiredFiresOnMirror() {
        let result =
            BASTurnAuditProjectionsKunlunSealRiver.compute(
                sessionID: "S",
                permitMode: .answer,
                requireMirror: true,
                requireCompare: false,
                requireSecondCheck: false,
                verdictID: "V",
                verdictLevel: "advisory",
                warrantIDs: [],
                candidateIDs: [],
                quarantineIDs: [],
                thoughtFoldID: "",
                thoughtFoldChecksum: "c",
                riverOriginTransformationSteps:
                    riverOriginTransformationSteps)
        XCTAssertTrue(result.seal.replayRequired)
    }

    // MARK: - 3) Empty thoughtFoldID skips fold-* provenance ref

    func testEmptyFoldIDSkipsFoldProvenanceRef() {
        let result =
            BASTurnAuditProjectionsKunlunSealRiver.compute(
                sessionID: "S",
                permitMode: .answer,
                requireMirror: false,
                requireCompare: false,
                requireSecondCheck: false,
                verdictID: "VDX",
                verdictLevel: "advisory",
                warrantIDs: [],
                candidateIDs: [],
                quarantineIDs: [],
                thoughtFoldID: "",
                thoughtFoldChecksum: "c",
                riverOriginTransformationSteps:
                    riverOriginTransformationSteps)
        for ref in result.seal.provenanceRefs {
            XCTAssertFalse(ref.hasPrefix("fold-"))
        }
    }

    // MARK: - 4) Seal verification fires isCanonical when all
    //             required fields populated

    func testSealVerificationIsCanonicalWhenComplete() {
        let result =
            BASTurnAuditProjectionsKunlunSealRiver.compute(
                sessionID: "S",
                permitMode: .answer,
                requireMirror: false,
                requireCompare: false,
                requireSecondCheck: false,
                verdictID: "VDX",
                verdictLevel: "advisory",
                warrantIDs: ["W1"],
                candidateIDs: ["C"],
                quarantineIDs: [],
                thoughtFoldID: "FOLD",
                thoughtFoldChecksum: "checksum-abc",
                riverOriginTransformationSteps:
                    riverOriginTransformationSteps)
        XCTAssertTrue(result.verification.isCanonical)
    }

    // MARK: - 5) River trace carries refs

    func testRiverTraceCarriesRootAuditRefs() {
        let result =
            BASTurnAuditProjectionsKunlunSealRiver.compute(
                sessionID: "S",
                permitMode: .mirror,
                requireMirror: false,
                requireCompare: false,
                requireSecondCheck: false,
                verdictID: "VDX",
                verdictLevel: "advisory",
                warrantIDs: ["W1"],
                candidateIDs: ["C1", "C2"],
                quarantineIDs: ["Q1"],
                thoughtFoldID: "F",
                thoughtFoldChecksum: "c",
                riverOriginTransformationSteps:
                    riverOriginTransformationSteps)
        XCTAssertEqual(result.trace.traceID, "river-S")
        XCTAssertTrue(result.trace.rootSourceRefs
            .contains("session-S"))
        XCTAssertTrue(result.trace.rootSourceRefs
            .contains("verdict-VDX"))
        XCTAssertEqual(result.trace.tributaryRefs,
                       ["C1", "C2"])
        XCTAssertEqual(result.trace.consentRefs, ["Q1"])
        XCTAssertEqual(result.trace.permitRefs,
                       ["permit-mirror"])
        XCTAssertEqual(result.trace.auditRefs,
                       ["audit.S.advisory"])
        XCTAssertEqual(result.trace.transformationSteps,
                       riverOriginTransformationSteps)
    }

    // MARK: - 6) Determinism

    func testFactoryIsDeterministic() {
        let r1 =
            BASTurnAuditProjectionsKunlunSealRiver.compute(
                sessionID: "S",
                permitMode: .mirror,
                requireMirror: false,
                requireCompare: false,
                requireSecondCheck: false,
                verdictID: "V",
                verdictLevel: "advisory",
                warrantIDs: ["W"],
                candidateIDs: ["C"],
                quarantineIDs: [],
                thoughtFoldID: "F",
                thoughtFoldChecksum: "c",
                riverOriginTransformationSteps:
                    riverOriginTransformationSteps)
        let r2 =
            BASTurnAuditProjectionsKunlunSealRiver.compute(
                sessionID: "S",
                permitMode: .mirror,
                requireMirror: false,
                requireCompare: false,
                requireSecondCheck: false,
                verdictID: "V",
                verdictLevel: "advisory",
                warrantIDs: ["W"],
                candidateIDs: ["C"],
                quarantineIDs: [],
                thoughtFoldID: "F",
                thoughtFoldChecksum: "c",
                riverOriginTransformationSteps:
                    riverOriginTransformationSteps)
        XCTAssertEqual(r1.seal.sealID, r2.seal.sealID)
        XCTAssertEqual(r1.seal.provenanceRefs,
                       r2.seal.provenanceRefs)
        XCTAssertEqual(r1.trace.traceID, r2.trace.traceID)
        XCTAssertEqual(r1.verification.isCanonical,
                       r2.verification.isCanonical)
    }
}
