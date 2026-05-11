// MARK: - BASArbitrationObservationFrameTests
// chapter 五百八 / M1409 — 3rd Tier C primitive tests

import XCTest
@testable import BASRuntimeCore

private struct SampleArbitrationBody:
    Equatable, Hashable, Codable, Sendable
{
    let summary: String
    let resolutionScore: Double
}

final class BASArbitrationObservationFrameTests:
    XCTestCase
{

    private func sampleBody() -> SampleArbitrationBody {
        return SampleArbitrationBody(
            summary: "test",
            resolutionScore: 0.5)
    }

    // MARK: - 1) Stage enum has 4 cases

    func testStageEnumHasFourCases() {
        let cases = BASArbitrationStage.allCases
        XCTAssertEqual(cases.count, 4)
        XCTAssertTrue(cases.contains(.review))
        XCTAssertTrue(cases.contains(.negotiate))
        XCTAssertTrue(cases.contains(.converged))
        XCTAssertTrue(cases.contains(.escalated))
    }

    // MARK: - 2) Construction holds all fields

    func testConstructionHoldsAllFields() {
        let frame = BASArbitrationObservationFrame(
            arbitrationID: "ARB-1",
            schemaVersion: "1.0.0",
            arbiterRefs: ["alice", "bob"],
            disputedClaimRefs: ["claim-1", "claim-2"],
            stage: .review,
            arbitrationPolicy: "policy-a",
            verdictHint: nil,
            arbitratedAtMs: 0,
            body: sampleBody())
        XCTAssertEqual(frame.arbitrationID, "ARB-1")
        XCTAssertEqual(frame.arbiterRefs,
                       ["alice", "bob"])
        XCTAssertEqual(frame.disputedClaimRefs,
                       ["claim-1", "claim-2"])
        XCTAssertEqual(frame.stage, .review)
        XCTAssertEqual(frame.arbitrationPolicy,
                       "policy-a")
        XCTAssertNil(frame.verdictHint)
    }

    // MARK: - 3) hasReachedVerdict requires .converged
    //             AND verdictHint

    func testHasReachedVerdictRequiresBoth() {
        // Converged without verdict hint → false
        let r1 = BASArbitrationObservationFrame(
            arbitrationID: "A",
            schemaVersion: "1.0.0",
            arbiterRefs: ["a"],
            disputedClaimRefs: ["c"],
            stage: .converged,
            arbitrationPolicy: "p",
            verdictHint: nil,
            arbitratedAtMs: 0,
            body: sampleBody())
        XCTAssertFalse(r1.hasReachedVerdict)

        // Non-converged with verdict hint → false
        let r2 = BASArbitrationObservationFrame(
            arbitrationID: "A",
            schemaVersion: "1.0.0",
            arbiterRefs: ["a"],
            disputedClaimRefs: ["c"],
            stage: .review,
            arbitrationPolicy: "p",
            verdictHint: "spurious",
            arbitratedAtMs: 0,
            body: sampleBody())
        XCTAssertFalse(r2.hasReachedVerdict)

        // Converged WITH verdict hint → true
        let r3 = BASArbitrationObservationFrame(
            arbitrationID: "A",
            schemaVersion: "1.0.0",
            arbiterRefs: ["a"],
            disputedClaimRefs: ["c"],
            stage: .converged,
            arbitrationPolicy: "p",
            verdictHint: "decision-x",
            arbitratedAtMs: 0,
            body: sampleBody())
        XCTAssertTrue(r3.hasReachedVerdict)
    }

    // MARK: - 4) requiresSovereignEscalation when escalated

    func testRequiresSovereignEscalationWhenEscalated() {
        let escalated = BASArbitrationObservationFrame(
            arbitrationID: "A",
            schemaVersion: "1.0.0",
            arbiterRefs: ["a"],
            disputedClaimRefs: ["c"],
            stage: .escalated,
            arbitrationPolicy: "p",
            arbitratedAtMs: 0,
            body: sampleBody())
        XCTAssertTrue(
            escalated.requiresSovereignEscalation)

        let review = BASArbitrationObservationFrame(
            arbitrationID: "A",
            schemaVersion: "1.0.0",
            arbiterRefs: ["a"],
            disputedClaimRefs: ["c"],
            stage: .review,
            arbitrationPolicy: "p",
            arbitratedAtMs: 0,
            body: sampleBody())
        XCTAssertFalse(
            review.requiresSovereignEscalation)
    }

    // MARK: - 5) distinctArbiterCount dedups

    func testDistinctArbiterCountDedups() {
        let frame = BASArbitrationObservationFrame(
            arbitrationID: "A",
            schemaVersion: "1.0.0",
            arbiterRefs: [
                "alice", "bob", "alice", "charlie",
                "bob"
            ],
            disputedClaimRefs: ["c"],
            stage: .review,
            arbitrationPolicy: "p",
            arbitratedAtMs: 0,
            body: sampleBody())
        XCTAssertEqual(frame.distinctArbiterCount, 3)
    }

    // MARK: - 6) Codable round-trip

    func testCodableRoundTrip() throws {
        let original = BASArbitrationObservationFrame(
            arbitrationID: "A",
            schemaVersion: "1.0.0",
            arbiterRefs: ["a", "b"],
            disputedClaimRefs: ["c", "d"],
            stage: .converged,
            arbitrationPolicy: "p",
            verdictHint: "decision-x",
            arbitratedAtMs: 1_700_000_000_000,
            body: sampleBody(),
            diagnostics: ["d1"])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASArbitrationObservationFrame<
                SampleArbitrationBody>.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - 7) Stage Codable round-trip

    func testStageCodableRoundTrip() throws {
        for stage in BASArbitrationStage.allCases {
            let data = try JSONEncoder().encode(stage)
            let decoded = try JSONDecoder().decode(
                BASArbitrationStage.self, from: data)
            XCTAssertEqual(decoded, stage)
        }
    }

    // MARK: - 8) Hashable

    func testHashable() {
        let f1 = BASArbitrationObservationFrame(
            arbitrationID: "A",
            schemaVersion: "1.0.0",
            arbiterRefs: ["a"],
            disputedClaimRefs: ["c"],
            stage: .review,
            arbitrationPolicy: "p",
            arbitratedAtMs: 0,
            body: sampleBody())
        let f2 = BASArbitrationObservationFrame(
            arbitrationID: "A",
            schemaVersion: "1.0.0",
            arbiterRefs: ["a"],
            disputedClaimRefs: ["c"],
            stage: .review,
            arbitrationPolicy: "p",
            arbitratedAtMs: 0,
            body: sampleBody())
        XCTAssertEqual(f1.hashValue, f2.hashValue)
    }

    // MARK: - 9) Sendable

    func testSendable() async {
        let frame = BASArbitrationObservationFrame(
            arbitrationID: "A",
            schemaVersion: "1.0.0",
            arbiterRefs: ["a"],
            disputedClaimRefs: ["c"],
            stage: .escalated,
            arbitrationPolicy: "p",
            arbitratedAtMs: 0,
            body: sampleBody())
        let captured = frame
        let task = Task {
            captured.requiresSovereignEscalation
        }
        let result = await task.value
        XCTAssertTrue(result)
    }
}
