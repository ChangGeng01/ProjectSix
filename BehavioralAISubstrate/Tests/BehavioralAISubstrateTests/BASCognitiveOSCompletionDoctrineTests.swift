// MARK: - BASCognitiveOSCompletionDoctrineTests
//                                       — chapter 三百八四 / M872
//
// Test coverage for ADR-016 cognitive OS substrate completion
// doctrine。Pins the closure status of every G1-G13 gap so
// future status transitions are caught by failing tests rather
// than slipping silently through commit messages。

import XCTest
@testable import BASRuntimeCore

final class BASCognitiveOSCompletionDoctrineTests:
    XCTestCase
{

    // MARK: - Doctrine version pin

    func testDoctrineVersionPin() {
        XCTAssertEqual(
            BASCognitiveOSCompletionDoctrine
                .doctrineVersion,
            "ADR-016.M872",
            "Doctrine version pin: bumping requires explicit " +
            "audit migration per chapter 八十七 raw value " +
            "stability doctrine")
    }

    // MARK: - Per-gap status pins

    func testP1FoundationGapsAreSubstrateClosed() {
        let p1Closed: [BASCognitiveOSGap] = [
            .g1EventLog,
            .g2UserState,
            .g3ConstitutionGate,
            .g4VectorRAG,
            .g5LayerFactories,
            .g7ActiveVerifier,
        ]
        for gap in p1Closed {
            XCTAssertEqual(
                BASCognitiveOSCompletionDoctrine
                    .status(of: gap),
                .substrateClosed,
                "P1 foundation gap \(gap.rawValue) must be " +
                "substrateClosed (M841-M870 closure)")
        }
    }

    func testG6IsSubstrateClosedSDKBridgePending() {
        XCTAssertEqual(
            BASCognitiveOSCompletionDoctrine
                .status(of: .g6AFMToolCalling),
            .substrateClosedSDKBridgePending,
            "G6 typed primitives shipped (M851-M853);AFM " +
            "SDK Tool conformer bridge pending iOS 26 " +
            "stabilization。M870 emits LOUD audit signal " +
            "instead of silent drop。")
    }

    func testP2IntelligenceGapsHaveCorrectStatus() {
        XCTAssertEqual(
            BASCognitiveOSCompletionDoctrine
                .status(of: .g9KnowledgeGraph),
            .substrateClosed,
            "G9 closed by M856-M860 + M866 + M869")
        XCTAssertEqual(
            BASCognitiveOSCompletionDoctrine
                .status(of: .g10LayerActors),
            .substrateClosed,
            "G10 closed by M855")
        XCTAssertEqual(
            BASCognitiveOSCompletionDoctrine
                .status(of: .g8MambaSSM),
            .external,
            "G8 needs Python training pipeline + GPU " +
            "+ corpus — genuinely external")
        XCTAssertEqual(
            BASCognitiveOSCompletionDoctrine
                .status(of: .g11MLXCoreML),
            .external,
            "G11 needs external toolchain (mlx → coreml " +
            "conversion CLI)")
    }

    func testG12IsSubstrateClosed() {
        XCTAssertEqual(
            BASCognitiveOSCompletionDoctrine
                .status(of: .g12AutoEval),
            .substrateClosed,
            "G12 closed: M861 typed primitives + M863 " +
            "SQLite storage + M864 orchestration actor")
    }

    func testG13IsExternalDeferredResearch() {
        XCTAssertEqual(
            BASCognitiveOSCompletionDoctrine
                .status(of: .g13MambaFrontier),
            .external,
            "G13 P3 research deferred per M840 roadmap")
    }

    // MARK: - Aggregate queries

    func testClosedGapsListMatchesExpected() {
        let closed = BASCognitiveOSCompletionDoctrine
            .closedGaps()
        let expected: Set<BASCognitiveOSGap> = [
            .g1EventLog,
            .g2UserState,
            .g3ConstitutionGate,
            .g4VectorRAG,
            .g5LayerFactories,
            .g7ActiveVerifier,
            .g9KnowledgeGraph,
            .g10LayerActors,
            .g12AutoEval,
        ]
        XCTAssertEqual(Set(closed), expected,
            "closedGaps must list exactly the substrate-" +
            "closed gaps")
        XCTAssertEqual(closed.count, 9)
    }

    func testSdkBridgePendingGapsListIsG6Only() {
        let pending = BASCognitiveOSCompletionDoctrine
            .sdkBridgePendingGaps()
        XCTAssertEqual(pending, [.g6AFMToolCalling],
            "Only G6 currently pending the SDK bridge")
    }

    func testExternalGapsListMatchesExpected() {
        let external = BASCognitiveOSCompletionDoctrine
            .externalGaps()
        let expected: Set<BASCognitiveOSGap> = [
            .g8MambaSSM,
            .g11MLXCoreML,
            .g13MambaFrontier,
        ]
        XCTAssertEqual(Set(external), expected,
            "External gaps:G8 SSM training + G11 MLX→CoreML " +
            "conversion + G13 Mamba frontier research")
        XCTAssertEqual(external.count, 3)
    }

    func testEnvironmentalGapsListIsEmpty() {
        let env = BASCognitiveOSCompletionDoctrine
            .environmentalGaps()
        XCTAssertTrue(env.isEmpty,
            "No M840-roadmap gap is currently in the " +
            "environmental bucket。The known BASMLXAdapter " +
            "macros plugin issue is a build-env issue,not " +
            "an unshipped roadmap capability")
    }

    func testSubstrateClosureRatioIsTenOfThirteen() {
        // 9 substrateClosed + 1 substrateClosedSDKBridgePending
        // = 10 substrate-tractable / 13 total = 0.769...
        let ratio = BASCognitiveOSCompletionDoctrine
            .substrateClosureRatio()
        XCTAssertEqual(
            ratio, 10.0 / 13.0, accuracy: 0.0001,
            "Substrate closure ratio: 10/13 ≈ 76.9% " +
            "(9 closed + 1 SDK-bridge-pending) / 13 total")
    }

    // MARK: - Lint guards

    func testEveryGapAnswersStatusWithoutCrashing() {
        // Lint guard: status(of:) must answer for every
        // CaseIterable gap。If a new case is added without a
        // status mapping,the switch's exhaustiveness check
        // catches it at compile time;this test catches any
        // runtime fall-through (eg. via dynamic dispatch
        // edge cases)。
        for gap in BASCognitiveOSGap.allCases {
            let s = BASCognitiveOSCompletionDoctrine
                .status(of: gap)
            XCTAssertTrue(
                BASCognitiveOSGapStatus.allCases.contains(s),
                "Status for \(gap.rawValue) must be a typed " +
                "case from BASCognitiveOSGapStatus.allCases")
        }
    }

    func testGapAndStatusAreCodableRoundTrip() throws {
        // Pin: both enums are Codable so doctrine-state can
        // ship as audit JSON in eval runs / observability hooks
        let allGapsJSON = try JSONEncoder().encode(
            BASCognitiveOSGap.allCases)
        let decoded = try JSONDecoder().decode(
            [BASCognitiveOSGap].self, from: allGapsJSON)
        XCTAssertEqual(
            decoded, BASCognitiveOSGap.allCases)
    }

    func testGapCountMatchesM840Roadmap() {
        // M840 roadmap defines G1-G13 = 13 gaps total
        XCTAssertEqual(
            BASCognitiveOSGap.allCases.count, 13,
            "M840 roadmap defines 13 cognitive OS gaps " +
            "(G1-G13)")
    }
}
