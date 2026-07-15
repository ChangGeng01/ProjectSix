// MARK: - BASChapter599MLXAdapterCodableWaveOneProofTests
// chapter 五百九十九 / M1774 — PROOF tests for the 2
//                          newly-Codable BASMLXAdapter
//                          types shipped at M1773
//                          (FRESH MODULE TERRITORY
//                          wave 1)
//
// ## Coverage (2 compile-time conformance tests)
//
// BASMLXAdapter first-ever Codable extension wave 1。
// 8th module entry into ledger-serializable contract
// surface (after chapter 598 BASOrgan first-ever 7th-
// module entry)。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these 2 newly-Codable types
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1773 → M1774

import XCTest
@testable import BASMLXAdapter

final class BASChapter599MLXAdapterCodableWaveOneProofTests:
    XCTestCase
{

    func testMLXModelCatalogEntryConformsToCodable() {
        // #18: real round-trip
        let value = MLXModelCatalog.Entry(
            id: "",
            providerID: "",
            providerName: "",
            extraEOSTokens: [],
            localDirectoryName: nil)
        assertCodableRoundTrips(value)
    }

    func testMLXLoRATrainerTrainingProgressConformsToCodable() {
        // #18: real round-trip (non-CaseIterable enum with
        // associated values — cover a payload case + a nested-URL
        // case to exercise the synthesized Codable both ways)
        assertCodableRoundTrips(
            MLXLoRATrainer.TrainingProgress.complete(
                totalIterations: 0))
        assertCodableRoundTrips(
            MLXLoRATrainer.TrainingProgress.trainStep(
                iteration: 0, loss: 0.0, tokensPerSecond: 0.0))
        assertCodableRoundTrips(
            MLXLoRATrainer.TrainingProgress.saved(
                iteration: 0,
                adapterURL: URL(fileURLWithPath: "/")))
    }
}
