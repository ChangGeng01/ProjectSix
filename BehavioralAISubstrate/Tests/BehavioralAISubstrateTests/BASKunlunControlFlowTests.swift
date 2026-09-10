import XCTest
@testable import BASOrchestration

/// M465-M470 (chapter 一百二十二 / Stream A α) — Kunlun control-
/// flow schema tests.
final class BASKunlunControlFlowTests: XCTestCase {

    // MARK: - BASAscentMode helper enum

    func testAscentModeCardinalityIsFive() {
        XCTAssertEqual(BASAscentMode.allCases.count, 5,
                       "Kunlun TARGET §5.1 lists 5 ascent modes")
    }

    func testAscentModeRawValuesAreStable() {
        XCTAssertEqual(BASAscentMode.morningAscent.rawValue,
                       "morning-ascent")
        XCTAssertEqual(BASAscentMode.ascending.rawValue, "ascending")
        XCTAssertEqual(BASAscentMode.returning.rawValue, "returning")
        XCTAssertEqual(BASAscentMode.eveningRest.rawValue,
                       "evening-rest")
        XCTAssertEqual(BASAscentMode.sealed.rawValue, "sealed")
    }

    // MARK: - M465 BASAscentLease

    func testAscentLeaseSchemaVersion() {
        XCTAssertEqual(BASAscentLease.currentSchemaVersion, "1.0.0")
    }

    func testAscentLeaseClampsNegativeIntsToZero() {
        let lease = BASAscentLease(
            leaseID: "  L1  ",
            runLeaseRef: "rl-1",
            ascentMode: .ascending,
            maxSteps: -5,
            gateBudget: -3,
            returnRequired: false,
            sovereignReserve: -1)
        XCTAssertEqual(lease.leaseID, "L1")
        XCTAssertEqual(lease.maxSteps, 0)
        XCTAssertEqual(lease.gateBudget, 0)
        XCTAssertEqual(lease.sovereignReserve, 0)
    }

    func testAscentLeaseHonorsReturnInvariantWhenReturnRequired() {
        // returnRequired=true + gateBudget=0 → invariant violated
        let bad = BASAscentLease(
            leaseID: "bad", runLeaseRef: "rl",
            ascentMode: .ascending, maxSteps: 5, gateBudget: 0,
            returnRequired: true, sovereignReserve: 0)
        XCTAssertFalse(bad.honorsReturnInvariant,
                       "returnRequired=true requires gateBudget>0")

        // returnRequired=true + gateBudget=2 → invariant honored
        let good = BASAscentLease(
            leaseID: "good", runLeaseRef: "rl",
            ascentMode: .ascending, maxSteps: 5, gateBudget: 2,
            returnRequired: true, sovereignReserve: 0)
        XCTAssertTrue(good.honorsReturnInvariant)

        // returnRequired=false + gateBudget=0 → invariant trivially honored
        let optional = BASAscentLease(
            leaseID: "opt", runLeaseRef: "rl",
            ascentMode: .morningAscent, maxSteps: 5, gateBudget: 0,
            returnRequired: false, sovereignReserve: 0)
        XCTAssertTrue(optional.honorsReturnInvariant)
    }

    func testAscentLeaseRoundTripCodable() throws {
        let lease = BASAscentLease(
            leaseID: "rt", runLeaseRef: "rl-rt",
            ascentMode: .returning, maxSteps: 10, gateBudget: 4,
            returnRequired: true, sovereignReserve: 1)
        let data = try JSONEncoder().encode(lease)
        let decoded = try JSONDecoder().decode(
            BASAscentLease.self, from: data)
        XCTAssertEqual(lease, decoded)
    }

    func testAscentLeaseAllAscentModesAccepted() {
        for mode in BASAscentMode.allCases {
            let lease = BASAscentLease(
                leaseID: "m-\(mode.rawValue)",
                runLeaseRef: "rl",
                ascentMode: mode,
                maxSteps: 1, gateBudget: 1,
                returnRequired: false, sovereignReserve: 0)
            XCTAssertEqual(lease.ascentMode, mode)
        }
    }

    // MARK: - M466 BASAxisDeviation

    func testAxisDeviationSchemaVersion() {
        XCTAssertEqual(BASAxisDeviation.currentSchemaVersion, "1.0.0")
    }

    func testAxisDeviationScoreClampsTo01() {
        let high = BASAxisDeviation(
            deviationID: "h", situationRef: "s",
            centerlineRef: "c",
            deviationScore: 1.5,
            reasonCodes: [])
        XCTAssertEqual(high.deviationScore, 1.0)
        let low = BASAxisDeviation(
            deviationID: "l", situationRef: "s",
            centerlineRef: "c",
            deviationScore: -0.5,
            reasonCodes: [])
        XCTAssertEqual(low.deviationScore, 0.0)
    }

    func testAxisDeviationTrimsAndFiltersReasonCodes() {
        let dev = BASAxisDeviation(
            deviationID: "d", situationRef: "s",
            centerlineRef: "c",
            deviationScore: 0.4,
            reasonCodes: ["short-term", "  ", "value-shift", ""],
            correctionHint: "  return-to-axis  ")
        XCTAssertEqual(dev.reasonCodes,
                       ["short-term", "value-shift"])
        XCTAssertEqual(dev.correctionHint, "return-to-axis")
    }

    func testAxisDeviationRoundTripCodable() throws {
        let dev = BASAxisDeviation(
            deviationID: "rt", situationRef: "s",
            centerlineRef: "c",
            deviationScore: 0.75,
            reasonCodes: ["x", "y"],
            correctionHint: "z")
        let data = try JSONEncoder().encode(dev)
        let decoded = try JSONDecoder().decode(
            BASAxisDeviation.self, from: data)
        XCTAssertEqual(dev, decoded)
    }

    // MARK: - M467 BASGatePressure

    func testGatePressureSchemaVersion() {
        XCTAssertEqual(BASGatePressure.currentSchemaVersion, "1.0.0")
    }

    func testGatePressureUrgencyClampsTo01() {
        let high = BASGatePressure(
            pressureID: "h", situationRef: "s",
            approachingDomains: ["host-version"],
            urgency: 5.0, reversible: true, gateRequired: true)
        XCTAssertEqual(high.urgency, 1.0)
        let low = BASGatePressure(
            pressureID: "l", situationRef: "s",
            approachingDomains: ["public"],
            urgency: -2.0, reversible: false, gateRequired: false)
        XCTAssertEqual(low.urgency, 0.0)
    }

    func testGatePressureFiltersEmptyDomains() {
        let p = BASGatePressure(
            pressureID: "p", situationRef: "s",
            approachingDomains: ["host-version", "  ", "public", ""],
            urgency: 0.5, reversible: true, gateRequired: false)
        XCTAssertEqual(p.approachingDomains,
                       ["host-version", "public"])
    }

    func testGatePressureRoundTripCodable() throws {
        let p = BASGatePressure(
            pressureID: "rt", situationRef: "s",
            approachingDomains: ["x"],
            urgency: 0.6, reversible: true, gateRequired: true)
        let data = try JSONEncoder().encode(p)
        let decoded = try JSONDecoder().decode(
            BASGatePressure.self, from: data)
        XCTAssertEqual(p, decoded)
    }

    // MARK: - M468 BASAscentBranch

    func testAscentBranchSchemaVersion() {
        XCTAssertEqual(BASAscentBranch.currentSchemaVersion, "1.0.0")
    }

    /// **Doctrine pin** — every ascent must have a return path
    /// (Kunlun §5.9 dignity preservation).
    func testAscentBranchDignityInvariantWithReturnPath() {
        let withReturn = BASAscentBranch(
            branchID: "b", candidateRef: "c",
            ascentConditions: [],
            gateSequence: [],
            evidenceRequirements: [],
            returnPathRef: "return-path-1",
            stopPoints: [])
        XCTAssertTrue(withReturn.honorsDignityInvariant)
    }

    func testAscentBranchDignityInvariantViolatedWithEmptyReturnPath() {
        let withoutReturn = BASAscentBranch(
            branchID: "b", candidateRef: "c",
            ascentConditions: [],
            gateSequence: [],
            evidenceRequirements: [],
            returnPathRef: "",
            stopPoints: [])
        XCTAssertFalse(withoutReturn.honorsDignityInvariant,
                       "empty returnPathRef violates §5.9 doctrine")
    }

    func testAscentBranchTrimsAndFilters() {
        let b = BASAscentBranch(
            branchID: "  b  ", candidateRef: "  c  ",
            ascentConditions: ["axis-aligned", "  ", ""],
            gateSequence: ["gate-1", " gate-2 "],
            evidenceRequirements: [""],
            returnPathRef: "  return-x  ",
            stopPoints: ["s1", "s2"])
        XCTAssertEqual(b.branchID, "b")
        XCTAssertEqual(b.candidateRef, "c")
        XCTAssertEqual(b.ascentConditions, ["axis-aligned"])
        XCTAssertEqual(b.gateSequence, ["gate-1", "gate-2"])
        XCTAssertEqual(b.evidenceRequirements, [])
        XCTAssertEqual(b.returnPathRef, "return-x")
        XCTAssertEqual(b.stopPoints, ["s1", "s2"])
    }

    func testAscentBranchRoundTripCodable() throws {
        let b = BASAscentBranch(
            branchID: "rt", candidateRef: "c",
            ascentConditions: ["a"],
            gateSequence: ["g"],
            evidenceRequirements: ["e"],
            returnPathRef: "r",
            stopPoints: ["s"])
        let data = try JSONEncoder().encode(b)
        let decoded = try JSONDecoder().decode(
            BASAscentBranch.self, from: data)
        XCTAssertEqual(b, decoded)
    }

    // MARK: - M469 BASRestStep

    func testRestStepSchemaVersion() {
        XCTAssertEqual(BASRestStep.currentSchemaVersion, "1.0.0")
    }

    func testRestStepTrimsAndFiltersAllArrays() {
        let r = BASRestStep(
            restID: "  r  ", candidateRef: "c",
            reasonCodes: ["awaiting-evidence", "  ", ""],
            allowedIntermediateActions: ["observe", "summarize"],
            resumeConditions: ["evidence-arrived"])
        XCTAssertEqual(r.restID, "r")
        XCTAssertEqual(r.reasonCodes, ["awaiting-evidence"])
        XCTAssertEqual(r.allowedIntermediateActions,
                       ["observe", "summarize"])
        XCTAssertEqual(r.resumeConditions, ["evidence-arrived"])
    }

    func testRestStepRoundTripCodable() throws {
        let r = BASRestStep(
            restID: "rt", candidateRef: "c",
            reasonCodes: ["x"],
            allowedIntermediateActions: ["observe"],
            resumeConditions: ["y"])
        let data = try JSONEncoder().encode(r)
        let decoded = try JSONDecoder().decode(
            BASRestStep.self, from: data)
        XCTAssertEqual(r, decoded)
    }

    // MARK: - M470 BASReturnPath

    func testReturnPathSchemaVersion() {
        XCTAssertEqual(BASReturnPath.currentSchemaVersion, "1.0.0")
    }

    func testReturnPathPreservesFlags() {
        let dignified = BASReturnPath(
            returnID: "d", candidateRef: "c",
            dignityPreserved: true,
            rollbackPossible: true,
            nextSafeStep: "summarize-and-pause")
        XCTAssertTrue(dignified.dignityPreserved)
        XCTAssertTrue(dignified.rollbackPossible)
        XCTAssertEqual(dignified.nextSafeStep, "summarize-and-pause")
    }

    func testReturnPathTrimsNextSafeStep() {
        let p = BASReturnPath(
            returnID: "  p  ", candidateRef: "c",
            dignityPreserved: false,
            rollbackPossible: false,
            nextSafeStep: "  step-x  ")
        XCTAssertEqual(p.returnID, "p")
        XCTAssertEqual(p.nextSafeStep, "step-x")
    }

    func testReturnPathRoundTripCodable() throws {
        let p = BASReturnPath(
            returnID: "rt", candidateRef: "c",
            dignityPreserved: true,
            rollbackPossible: false,
            nextSafeStep: "x")
        let data = try JSONEncoder().encode(p)
        let decoded = try JSONDecoder().decode(
            BASReturnPath.self, from: data)
        XCTAssertEqual(p, decoded)
    }

    // MARK: - Cross-schema doctrine pins

    /// All 6 schemas at v1.0.0.
    func testAllChapter122SchemasAtV1Point0() {
        XCTAssertEqual(BASAscentLease.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(BASAxisDeviation.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(BASGatePressure.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(BASAscentBranch.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(BASRestStep.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(BASReturnPath.currentSchemaVersion, "1.0.0")
    }

    /// 守正三件套 doctrine per Kunlun TARGET §5.9 line 1702:
    /// "守正必须同时提供 AscentBranch、RestStep 与 ReturnPath".
    /// Pin: all 3 types exist + can be constructed together.
    func testThreePartsOf守正DoctrineCoexist() {
        let returnPath = BASReturnPath(
            returnID: "rp-1", candidateRef: "c",
            dignityPreserved: true,
            rollbackPossible: true,
            nextSafeStep: "summarize")
        let restStep = BASRestStep(
            restID: "rs-1", candidateRef: "c",
            reasonCodes: ["awaiting"],
            allowedIntermediateActions: ["observe"],
            resumeConditions: ["evidence"])
        let branch = BASAscentBranch(
            branchID: "ab-1", candidateRef: "c",
            ascentConditions: ["axis-aligned"],
            gateSequence: ["gate-a"],
            evidenceRequirements: ["evidence-1"],
            returnPathRef: returnPath.returnID,
            stopPoints: [restStep.restID])
        XCTAssertTrue(branch.honorsDignityInvariant,
                      "守正三件套 — every ascent MUST have return path")
        XCTAssertEqual(branch.returnPathRef, returnPath.returnID)
        XCTAssertEqual(branch.stopPoints, [restStep.restID])
    }
}
