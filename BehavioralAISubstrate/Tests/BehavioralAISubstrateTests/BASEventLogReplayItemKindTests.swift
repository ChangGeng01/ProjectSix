// MARK: - BASEventLogReplayItemKindTests
// chapter 六百八十三 / M2110 第二刀 — anti-drift PROOF tests
//                                  for the typed event-kind
//                                  enum bridge

import XCTest
@testable import BASRuntimeCore

final class BASEventLogReplayItemKindTests: XCTestCase {

    typealias K = BASEventLogReplayItemKind

    // MARK: - Case count

    func testCaseCountIs8() {
        XCTAssertEqual(K.allCases.count, 8)
    }

    func testGlobalCountConstantMatches() {
        XCTAssertEqual(
            basEventLogReplayItemKindCount, 8)
        XCTAssertEqual(
            basEventLogReplayItemKindCount,
            K.allCases.count)
    }

    func testAllEightKindsNamed() {
        let expected: [K] = [
            .memoryAtom,
            .turnLifecycle,
            .parallelStage,
            .permitEscalation,
            .nativeStageDispatch,
            .planAssignment,
            .nativeStagePerStep,
            .biomimeticCheckpoint
        ]
        for k in expected {
            XCTAssertTrue(K.allCases.contains(k))
        }
    }

    func testCaseNamesAllUnique() {
        let names = K.allCases.map { $0.rawValue }
        XCTAssertEqual(Set(names).count, names.count)
    }

    // MARK: - Raw value pins

    func testRawValuesAreKebabCase() {
        XCTAssertEqual(K.memoryAtom.rawValue, "memory-atom")
        XCTAssertEqual(
            K.turnLifecycle.rawValue, "turn-lifecycle")
        XCTAssertEqual(
            K.parallelStage.rawValue, "parallel-stage")
        XCTAssertEqual(
            K.permitEscalation.rawValue,
            "permit-escalation")
        XCTAssertEqual(
            K.nativeStageDispatch.rawValue,
            "native-stage-dispatch")
        XCTAssertEqual(
            K.planAssignment.rawValue,
            "plan-assignment")
        XCTAssertEqual(
            K.nativeStagePerStep.rawValue,
            "native-stage-per-step")
        XCTAssertEqual(
            K.biomimeticCheckpoint.rawValue,
            "biomimetic-checkpoint")
    }

    // MARK: - M-number provenance

    func testMemoryAtomIntroducedAt941() {
        XCTAssertEqual(
            K.memoryAtom.introducedAtMNumber, 941)
    }

    func testBiomimeticCheckpointIntroducedAt1245() {
        XCTAssertEqual(
            K.biomimeticCheckpoint.introducedAtMNumber,
            1245)
    }

    func testAllMNumbersAreInSubstrateRange() {
        for k in K.allCases {
            XCTAssertGreaterThanOrEqual(
                k.introducedAtMNumber, 941,
                "first event kind landed at M941")
            XCTAssertLessThanOrEqual(
                k.introducedAtMNumber, 1245,
                "biomimeticCheckpoint at M1245 is " +
                "newest kind")
        }
    }

    func testMNumberOrderingIsChronological() {
        let mNumbers = K.allCases.map {
            $0.introducedAtMNumber
        }
        for i in 1..<mNumbers.count {
            XCTAssertGreaterThanOrEqual(
                mNumbers[i], mNumbers[i-1],
                "case order must be chronological by " +
                "M-number")
        }
    }

    // MARK: - Chapter provenance

    func testMemoryAtomIntroducedAtChapter402() {
        XCTAssertEqual(
            K.memoryAtom.introducedAtChapter,
            "chapter 四百二")
    }

    func testBiomimeticCheckpointAtChapter467() {
        XCTAssertEqual(
            K.biomimeticCheckpoint.introducedAtChapter,
            "chapter 四百六十七")
    }

    // MARK: - Codable

    func testCodableRoundTrip() throws {
        let original: K = .nativeStageDispatch
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            K.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testEncodesAsRawString() throws {
        let data = try JSONEncoder().encode(
            K.permitEscalation)
        let json = String(
            data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("permit-escalation"))
    }

    // MARK: - Anti-drift against BASSweepDoctrineExpectations

    func testCountMatchesSweepExpectation() {
        XCTAssertEqual(
            basEventLogReplayItemKindCount,
            BASSweepDoctrineExpectations
                .eventPayloadKindCount)
    }

    // MARK: - Determinism

    func testAllCasesOrderIsDeterministic() {
        let cases1 = K.allCases
        let cases2 = K.allCases
        XCTAssertEqual(cases1, cases2)
    }

    // MARK: - Hashable

    func testHashableConsistency() {
        let a: K = .memoryAtom
        let b: K = .memoryAtom
        XCTAssertEqual(a.hashValue, b.hashValue)
    }
}
