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
        // M969 bump:Phase 2 entropy chapter 四百三 + chapter
        // 四百四 v1 close-out。 V2 actor delegation skeleton
        // + composition-entropy ledger + threading entropy
        // collapse + naming bridge + bundle protocol + 9 typed
        // primitives shipped。 ADR-014 OPT-IN held;V1
        // byte-equality preserved across 4700+ BAS tests。
        XCTAssertEqual(
            BASCognitiveOSCompletionDoctrine
                .doctrineVersion,
            "ADR-016.M1932",
            "Doctrine version pin。 M1299 chapter 四百" +
            "八十 Phase C ANE default + MPSGraph cache:" +
            " bumped through chapters 453-480 —" +
            " biomimetic build-out (453-459) + debt" +
            " repayment (460-462) + doctrine-collapse" +
            " (463-466) + auto-checkpoint (467) +" +
            " recovery loop (468) + BCM (469) + hier" +
            " slot (470) + Mamba bench (471) + bundle" +
            " proj (472) + self-audit cleanup (473) +" +
            " ANE live + registry dispatch + e2e (474)" +
            " + MPSGraph numerical PROOF (475) +" +
            " RMSNorm + RotaryEmbedding + first" +
            " BASBundle (476) + attention PROOF + honest" +
            " re-scoring (477) + V1 fold PILOT (478) +" +
            " softmax + layerNorm + conv2D kernels" +
            " 7-of-8 coverage (479) + ANE default flip" +
            " + cache observation + 45×-gap benchmark" +
            " (480)")
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
        // M917+M918:G8 + G11 transitioned from `.external`
        // to `.externalSubstrateContractTyped` because the
        // substrate-side typed contracts shipped (Mamba
        // training corpus schema + CoreML conversion contract)。
        XCTAssertEqual(
            BASCognitiveOSCompletionDoctrine
                .status(of: .g8MambaSSM),
            .externalSubstrateContractTyped,
            "G8 still external (Python training pipeline + " +
            "GPU + corpus) but now has typed substrate-side " +
            "contract via M917 BASMambaTrainingCorpusSchema")
        XCTAssertEqual(
            BASCognitiveOSCompletionDoctrine
                .status(of: .g11MLXCoreML),
            .externalSubstrateContractTyped,
            "G11 still external (mlx → coreml CLI driver) " +
            "but now has typed substrate-side contract via " +
            "M918 BASCoreMLConversionContract")
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
        // M918:`.external` (pure) now narrows to G13 only。
        // G8 + G11 moved to `.externalSubstrateContractTyped`。
        let external = BASCognitiveOSCompletionDoctrine
            .externalGaps()
        let expected: Set<BASCognitiveOSGap> = [
            .g13MambaFrontier,
        ]
        XCTAssertEqual(Set(external), expected,
            "Pure-external gaps after M918:only G13 " +
            "frontier research (no substrate-side contract)")
        XCTAssertEqual(external.count, 1)
    }

    /// M918:G8 + G11 now have typed substrate-side contracts
    /// shipped。Tests pin the new typed-contract aggregate。
    func testExternalContractTypedGapsListMatchesExpected() {
        let typed = BASCognitiveOSCompletionDoctrine
            .externalContractTypedGaps()
        let expected: Set<BASCognitiveOSGap> = [
            .g8MambaSSM,
            .g11MLXCoreML,
        ]
        XCTAssertEqual(Set(typed), expected,
            "Typed-contract external gaps:G8 (M917 " +
            "MambaTrainingCorpusSchema) + G11 (M918 " +
            "CoreMLConversionContract)")
        XCTAssertEqual(typed.count, 2)
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

    func testSubstrateClosureRatioIsTwelveOfThirteen() {
        // M918:9 substrateClosed + 1 SDK-bridge-pending +
        // 2 typed-contract-external (G8 + G11) = 12 substrate-
        // tractable / 13 total = 0.923...
        let ratio = BASCognitiveOSCompletionDoctrine
            .substrateClosureRatio()
        XCTAssertEqual(
            ratio, 12.0 / 13.0, accuracy: 0.0001,
            "Substrate closure ratio post-M918: 12/13 ≈ " +
            "92.3% (9 closed + 1 SDK-bridge-pending + 2 " +
            "typed-contract-external) / 13 total")
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
