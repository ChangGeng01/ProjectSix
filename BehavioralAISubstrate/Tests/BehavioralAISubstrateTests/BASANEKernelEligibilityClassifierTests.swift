// MARK: - BASANEKernelEligibilityClassifierTests
// chapter 五百 / M1377 — ANE classifier tests

import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASANEKernelEligibilityClassifierTests:
    XCTestCase
{

    // MARK: - 1) Tier enum has 3 cases

    func testTierEnumHasThreeCases() {
        let cases = BASANEEligibilityTier.allCases
        XCTAssertEqual(cases.count, 3)
        XCTAssertTrue(cases.contains(.aneCapable))
        XCTAssertTrue(cases.contains(.mpsGraphNative))
        XCTAssertTrue(cases.contains(.fallbackRequired))
    }

    // MARK: - 2) All BASNeuralOp cases have a tier

    func testAllBASNeuralOpCasesHaveTier() {
        for op in BASNeuralOp.allCases {
            let tier = BASANEKernelEligibilityClassifier
                .tier(for: op)
            XCTAssertTrue(
                BASANEEligibilityTier.allCases
                    .contains(tier),
                "op \(op) must have a typed tier")
        }
    }

    // MARK: - 3) Specific tier pins (honest classification)

    func testMatMulIsAneCapable() {
        XCTAssertEqual(
            BASANEKernelEligibilityClassifier
                .tier(for: .matMul),
            .aneCapable)
    }

    func testAttentionIsAneCapable() {
        XCTAssertEqual(
            BASANEKernelEligibilityClassifier
                .tier(for: .attention),
            .aneCapable)
    }

    func testRMSNormIsMPSGraphNative() {
        XCTAssertEqual(
            BASANEKernelEligibilityClassifier
                .tier(for: .rmsNorm),
            .mpsGraphNative)
    }

    func testSSMScanIsFallbackRequired() {
        XCTAssertEqual(
            BASANEKernelEligibilityClassifier
                .tier(for: .ssmScan),
            .fallbackRequired,
            "ssmScan production requires custom Metal" +
            " shader OR MLX bridge per Tier 2 phase K" +
            " honest scope")
    }

    // MARK: - 4) Evidence non-empty for every op

    func testEvidenceNonEmptyForEveryOp() {
        for op in BASNeuralOp.allCases {
            let evidence =
                BASANEKernelEligibilityClassifier
                    .evidence(for: op)
            XCTAssertFalse(
                evidence.isEmpty,
                "op \(op) must have non-empty evidence")
        }
    }

    // MARK: - 5) Evidence carries tier-marker prefix

    func testEvidenceCarriesTierMarkerPrefix() {
        XCTAssertTrue(
            BASANEKernelEligibilityClassifier
                .evidence(for: .matMul)
                .hasPrefix("ane-native:"))
        XCTAssertTrue(
            BASANEKernelEligibilityClassifier
                .evidence(for: .rmsNorm)
                .hasPrefix("mpsgraph-native:"))
        XCTAssertTrue(
            BASANEKernelEligibilityClassifier
                .evidence(for: .ssmScan)
                .hasPrefix("fallback-required:"))
    }

    // MARK: - 6) operations(inTier:) partitions correctly

    func testOperationsInTierPartitionsAllOps() {
        let allOps = Set(BASNeuralOp.allCases)
        let aneOps = Set(
            BASANEKernelEligibilityClassifier
                .operations(inTier: .aneCapable))
        let mpsOps = Set(
            BASANEKernelEligibilityClassifier
                .operations(inTier: .mpsGraphNative))
        let fallbackOps = Set(
            BASANEKernelEligibilityClassifier
                .operations(inTier: .fallbackRequired))
        let union = aneOps
            .union(mpsOps)
            .union(fallbackOps)
        XCTAssertEqual(union, allOps,
            "tiers MUST partition BASNeuralOp.allCases" +
            " — every op in exactly one tier")
        // Intersection check (should be empty)
        XCTAssertTrue(
            aneOps.intersection(mpsOps).isEmpty)
        XCTAssertTrue(
            aneOps.intersection(fallbackOps).isEmpty)
        XCTAssertTrue(
            mpsOps.intersection(fallbackOps).isEmpty)
    }

    // MARK: - 7) HONEST scope flag pinned

    func testConsultedByExecutorInProductionIsFalse() {
        XCTAssertFalse(
            BASANEKernelEligibilityClassifier
                .consultedByExecutorInProduction,
            "chapter 500 HONEST scope:executor doesn't" +
            " yet consult this classifier;wire-in" +
            " deferred to follow-up arc")
    }

    // MARK: - 8) Determinism

    func testClassifierIsDeterministic() {
        for op in BASNeuralOp.allCases {
            let t1 = BASANEKernelEligibilityClassifier
                .tier(for: op)
            let t2 = BASANEKernelEligibilityClassifier
                .tier(for: op)
            XCTAssertEqual(t1, t2)
        }
    }

    // MARK: - 9) T1.2 relabel — raw-value byte stability pinned

    /// The 全面进化 T1.2 relabel renamed ONLY the Swift identifier
    /// (`aneNative` → `aneCapable`,capability-not-placement
    /// semantics per ANE_UTILIZATION_FINDINGS)。 The raw value
    /// rides audit evidence strings + Codable wire bytes,so it
    /// MUST stay "ane-native" forever (ADR-014:renaming the
    /// string would mutate audit bytes for zero decision gain)。
    func testAneCapableRawValueIsByteStable() throws {
        XCTAssertEqual(
            BASANEEligibilityTier.aneCapable.rawValue, "ane-native")
        XCTAssertEqual(
            BASANEEligibilityTier(rawValue: "ane-native"), .aneCapable)
        // Codable wire bytes unchanged by the rename。
        let encoded = try JSONEncoder().encode(
            [BASANEEligibilityTier.aneCapable])
        XCTAssertEqual(
            String(decoding: encoded, as: UTF8.self),
            "[\"ane-native\"]")
        // Evidence strings keep the raw-value prefix the doctrine
        // walker greps,while the claim text is capability-only。
        let matMulEvidence = BASANEKernelEligibilityClassifier
            .evidence(for: .matMul)
        XCTAssertTrue(matMulEvidence.hasPrefix("ane-native:"))
        XCTAssertTrue(matMulEvidence.contains("ANE-CAPABLE"))
        XCTAssertFalse(matMulEvidence.contains("maps to ANE"),
            "placement claim was disproven by T1.2 measurement")
    }
}
