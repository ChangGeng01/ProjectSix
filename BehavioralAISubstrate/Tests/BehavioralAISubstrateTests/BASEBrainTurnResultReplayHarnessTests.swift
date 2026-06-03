// Step 1 — proofs for the full-result byte-equal replay harness.
//
// Positive: the canonical full-result digest is byte-stable across re-runs (single fixture +
// all canonical60) and V1 ≡ runWithPlan. Negative control (deterministic, non-flaky): the RAW
// digest reflects retrievedAt drift while the canonical digest collapses it — proving the
// harness is non-vacuous. Over-reach guard (R1): canonicalization changes ONLY
// memoryBundle.retrievedAt — after pinning that one field on the raw result, the two results are
// FULLY Equatable-equal, so no authorization-bearing field can have changed.

import XCTest
import Foundation
@testable import BASHostKit
@testable import BASRuntimeCore
import BASMemory

final class BASEBrainTurnResultReplayHarnessTests: XCTestCase {

    // MARK: - (A) determinism (positive)

    func testDeterminismIsByteStableForStubCoordinator() {
        let verdict = BASEBrainTurnResultReplayHarness.determinismVerdict(
            coordinatorFactory: BASCoordinatorTestStubs.makeStub,
            request: BASCoordinatorTestStubs.makeStubRequest(),
            runCount: 3)
        XCTAssertTrue(verdict.isStable,
            "full-result canonical digest must be byte-stable across re-runs")
        XCTAssertEqual(verdict.distinctDigestCount, 1)
        XCTAssertNil(verdict.divergingRunIndex)
    }

    func testDeterminismAcrossCanonical60() {
        for key in BASStressSweepCanonical60Driver.canonicalFixtureSet().keys {
            let request = BASTurnRuntimeFullSummaryStressSweepRunner
                .defaultRequestBuilder(for: key)
            let verdict = BASEBrainTurnResultReplayHarness.determinismVerdict(
                coordinatorFactory: BASCoordinatorTestStubs.makeStub,
                request: request,
                runCount: 2)
            XCTAssertTrue(verdict.isStable,
                "fixture \(key.label) must produce a byte-stable full-result digest")
        }
    }

    // MARK: - negative control (deterministic, proves the harness is non-vacuous)

    func testRawDigestReflectsRetrievedAtDriftButCanonicalCollapsesIt() {
        let base = BASCoordinatorTestStubs.makeStub()
            .runTurn(BASCoordinatorTestStubs.makeStubRequest())
        var a = base
        a.memoryBundle.retrievedAt = Date(timeIntervalSince1970: 111)
        var b = base
        b.memoryBundle.retrievedAt = Date(timeIntervalSince1970: 222)

        // RAW digests MUST differ (retrievedAt is in the encoded bytes) — the harness can
        // detect drift, so a passing positive test is meaningful.
        let rawA = BASEBrainTurnResultReplayDigest.from(
            result: a, producedAt: .init(timeIntervalSince1970: 0), canonicalize: false)
        let rawB = BASEBrainTurnResultReplayDigest.from(
            result: b, producedAt: .init(timeIntervalSince1970: 0), canonicalize: false)
        XCTAssertNotEqual(rawA.digestString, rawB.digestString,
            "raw digest must reflect retrievedAt drift (harness must be non-vacuous)")

        // CANONICAL digests MUST match (the observation-clock drift is collapsed).
        let canonA = BASEBrainTurnResultReplayDigest.from(
            result: a, producedAt: .init(timeIntervalSince1970: 0))
        let canonB = BASEBrainTurnResultReplayDigest.from(
            result: b, producedAt: .init(timeIntervalSince1970: 0))
        XCTAssertEqual(canonA.digestString, canonB.digestString,
            "canonicalization must collapse the observation-clock drift")
    }

    // MARK: - (B) Codable round-trip

    func testCodableRoundTripIsByteStable() {
        let result = BASCoordinatorTestStubs.makeStub()
            .runTurn(BASCoordinatorTestStubs.makeStubRequest())
        XCTAssertTrue(
            BASEBrainTurnResultReplayHarness.codableRoundTripIsByteStable(result),
            "full BASEBrainTurnResult must be a byte-stable Codable fixed-point")
    }

    // MARK: - (C) V1-vs-runWithPlan parity

    func testV1VsRunWithPlanParityIsByteEqual() async {
        let verdict = await BASEBrainTurnResultReplayHarness.v1VsRunWithPlanParityVerdict(
            coordinatorFactory: BASCoordinatorTestStubs.makeStub,
            request: BASCoordinatorTestStubs.makeStubRequest())
        XCTAssertTrue(verdict.isStable,
            "runWithPlan must return a full-result byte-equal to coordinator.runTurn (ADR-014)")
    }

    func testV1VsRunWithPlanParityAcrossFixtures() async {
        for key in BASStressSweepCanonical60Driver.canonicalFixtureSet().keys.prefix(12) {
            let request = BASTurnRuntimeFullSummaryStressSweepRunner
                .defaultRequestBuilder(for: key)
            let verdict = await BASEBrainTurnResultReplayHarness.v1VsRunWithPlanParityVerdict(
                coordinatorFactory: BASCoordinatorTestStubs.makeStub,
                request: request)
            XCTAssertTrue(verdict.isStable,
                "V1 ≡ runWithPlan parity must hold for fixture \(key.label)")
        }
    }

    // MARK: - canonicalizer over-reach guard (R1)

    func testCanonicalizerChangesOnlyTheObservationClockField() {
        let raw = BASCoordinatorTestStubs.makeStub()
            .runTurn(BASCoordinatorTestStubs.makeStubRequest())
        let canon = BASEBrainTurnResultReplayCanonicalizer.canonicalized(raw)

        // It DID pin the observation clock:
        XCTAssertEqual(canon.memoryBundle.retrievedAt,
            BASEBrainTurnResultReplayCanonicalizer.zeroSentinel)

        // And it changed NOTHING ELSE: pinning the same field on `raw` makes the two FULLY
        // Equatable-equal. This is a single whole-struct comparison, so it covers EVERY
        // authorization-bearing field without having to enumerate them — if canonicalization
        // touched any of them, this assertion fails (R1 tripwire).
        var rawPinned = raw
        rawPinned.memoryBundle.retrievedAt =
            BASEBrainTurnResultReplayCanonicalizer.zeroSentinel
        XCTAssertEqual(rawPinned, canon,
            "R1 over-reach guard: canonicalization must change ONLY memoryBundle.retrievedAt")

        XCTAssertEqual(
            BASEBrainTurnResultReplayCanonicalizer.canonicalizedFields,
            ["memoryBundle.retrievedAt"])
    }
}
