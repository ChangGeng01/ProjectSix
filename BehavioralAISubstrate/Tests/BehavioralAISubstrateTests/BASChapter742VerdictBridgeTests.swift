// MARK: - BASChapter742VerdictBridgeTests
// chapter 七百四十二 第二刀 / M2382
//
// LAYER-MIGRATION ARC Swift bridge smoke tests for the L14
// Sovereign Verdict Engine pure-decision-tree Rust port。
//
// Wire encoding verified:
//   hard_bits u16 bitfield (LSB = BR-001 ... bit 11 = BR-012)
//   soft_ptr  pointer to 7 doubles in §12.2 order
//   domain_raw 0..5 (PureInference / ToolRead / ToolWrite /
//              HostMutate / MemoryPromote / RulePromotion)
//   evidence_sufficient 0/1
//   returns:rank 0..7 or nil on fault

import XCTest
@testable import BASRuntimeCore

final class BASChapter742VerdictBridgeTests: XCTestCase {

    func testABIVersionIsOne() {
        #if os(iOS) || os(macOS)
        XCTAssertEqual(
            BASAutoRouteRanker.verdictDecisionsABIVersion(),
            1)
        #endif
    }

    func testCleanInputsYieldPassRank() {
        #if os(iOS) || os(macOS)
        let bits = BASAutoRouteRanker.verdictHardBitfield()
        let softs = [Double](repeating: 0, count: 7)
        let rank = BASAutoRouteRanker.verdictDeriveLevel(
            hardBits: bits, softSignals: softs,
            domain: .pureInference,
            evidenceSufficient: true)
        XCTAssertEqual(rank, 0,
            "clean inputs + pure_inference + evidence = pass")
        #endif
    }

    func testBR001ArtifactSignatureYieldsDeadStop() {
        #if os(iOS) || os(macOS)
        let bits = BASAutoRouteRanker.verdictHardBitfield(
            artifactSignatureInvalid: true)
        let softs = [Double](repeating: 0, count: 7)
        let rank = BASAutoRouteRanker.verdictDeriveLevel(
            hardBits: bits, softSignals: softs,
            domain: .pureInference,
            evidenceSufficient: true)
        XCTAssertEqual(rank, 7, "BR-001 → deadStop (rank 7)")
        #endif
    }

    func testBR007UnauthorizedSelfMutationYieldsDeadStop() {
        #if os(iOS) || os(macOS)
        let bits = BASAutoRouteRanker.verdictHardBitfield(
            unauthorizedSelfMutation: true)
        let softs = [Double](repeating: 0, count: 7)
        let rank = BASAutoRouteRanker.verdictDeriveLevel(
            hardBits: bits, softSignals: softs,
            domain: .toolWrite,
            evidenceSufficient: true)
        XCTAssertEqual(rank, 7, "BR-007 → deadStop (rank 7)")
        #endif
    }

    func testHighIntegritySoftSignalDeadStops() {
        #if os(iOS) || os(macOS)
        let bits = BASAutoRouteRanker.verdictHardBitfield()
        var softs = [Double](repeating: 0, count: 7)
        softs[0] = 0.95   // integrity
        let rank = BASAutoRouteRanker.verdictDeriveLevel(
            hardBits: bits, softSignals: softs,
            domain: .pureInference,
            evidenceSufficient: true)
        XCTAssertEqual(rank, 7,
            "high integrity soft → deadStop")
        #endif
    }

    func testEvidenceInsufficientUpgradesToToolCut() {
        #if os(iOS) || os(macOS)
        let bits = BASAutoRouteRanker.verdictHardBitfield()
        let softs = [Double](repeating: 0, count: 7)
        let rank = BASAutoRouteRanker.verdictDeriveLevel(
            hardBits: bits, softSignals: softs,
            domain: .toolWrite,
            evidenceSufficient: false)
        XCTAssertEqual(rank, 3,
            "evidence-insufficient + irreversible domain → toolCut (rank 3)")
        #endif
    }

    func testEvidenceInsufficientNoUpgradeForPureInference() {
        #if os(iOS) || os(macOS)
        let bits = BASAutoRouteRanker.verdictHardBitfield()
        let softs = [Double](repeating: 0, count: 7)
        let rank = BASAutoRouteRanker.verdictDeriveLevel(
            hardBits: bits, softSignals: softs,
            domain: .pureInference,
            evidenceSufficient: false)
        XCTAssertEqual(rank, 0,
            "pure_inference is NOT irreversible → no upgrade")
        #endif
    }

    func testInvalidSoftSignalsCountReturnsNil() {
        #if os(iOS) || os(macOS)
        let bits = BASAutoRouteRanker.verdictHardBitfield()
        let badSofts = [Double](repeating: 0, count: 5)
        let rank = BASAutoRouteRanker.verdictDeriveLevel(
            hardBits: bits, softSignals: badSofts,
            domain: .pureInference,
            evidenceSufficient: true)
        XCTAssertNil(rank,
            "softSignals.count != 7 must return nil")
        #endif
    }

    func testHardBitfieldEncodesAllTwelveFlags() {
        // Verify each flag maps to the correct bit position
        let onlyBR001 = BASAutoRouteRanker.verdictHardBitfield(
            artifactSignatureInvalid: true)
        XCTAssertEqual(onlyBR001.value, 0x0001)
        let onlyBR012 = BASAutoRouteRanker.verdictHardBitfield(
            auditAppendFailed: true)
        XCTAssertEqual(onlyBR012.value, 0x0800)
        let allOn = BASAutoRouteRanker.verdictHardBitfield(
            artifactSignatureInvalid: true,
            thoughtFoldChecksumBroken: true,
            externalSideEffectWithoutSCT: true,
            memoryOrHostWriteBypass: true,
            hostRemovalBypassed: true,
            policyBundleTampered: true,
            unauthorizedSelfMutation: true,
            irreversibleHighGSIWithoutEvidence: true,
            runtimeUnstableInHighRisk: true,
            riskPermitHeadConflict: true,
            hostAttemptsBaseBoundaryOverride: true,
            auditAppendFailed: true)
        // 12 bits set = 0x0FFF
        XCTAssertEqual(allOn.value, 0x0FFF)
    }

    func testLexicographicFirstHighPinsVerdict() {
        #if os(iOS) || os(macOS)
        let bits = BASAutoRouteRanker.verdictHardBitfield()
        // Both privilege_violation (index 1) AND
        // irreversible_harm (index 4) high → privilege wins
        // (earlier in order)
        var softs = [Double](repeating: 0, count: 7)
        softs[1] = 0.9  // privilege_violation → quarantine (5)
        softs[4] = 0.9  // irreversible_harm → toolCut (3)
        let rank = BASAutoRouteRanker.verdictDeriveLevel(
            hardBits: bits, softSignals: softs,
            domain: .pureInference,
            evidenceSufficient: true)
        XCTAssertEqual(rank, 5,
            "privilege_violation (earlier in order) pins → quarantine")
        #endif
    }

    func testDeterminismRepeatCalls() {
        #if os(iOS) || os(macOS)
        let bits = BASAutoRouteRanker.verdictHardBitfield(
            thoughtFoldChecksumBroken: true)
        var softs = [Double](repeating: 0, count: 7)
        softs[1] = 0.55  // privilege_violation mid
        for _ in 0..<10 {
            let rank = BASAutoRouteRanker.verdictDeriveLevel(
                hardBits: bits, softSignals: softs,
                domain: .hostMutate,
                evidenceSufficient: true)
            // BR-002 = rollback (rank 6),soft mid = shadowLock (2)
            // Max = rollback
            XCTAssertEqual(rank, 6)
        }
        #endif
    }
}
