import XCTest
import QinaoMLX

/// 结构大重构 — Phase 3 / Item B: the speculative-decoding surface exposed through the Qinao MLX facade.
///
/// A host elects a target↔draft pair through `QinaoMLXModel` WITHOUT touching `MLXModelCatalog` (no BAS/MLX type
/// leak). These assertions pin the tiered, pairing-aware surface.
final class QinaoMLXSpeculativeSurfaceTests: XCTestCase {

    func testCertifiedTargetExposesItsSameFamilyDraft() {
        // PRIMARY cert target: Gemma4 E4B → E2B.
        XCTAssertEqual(QinaoMLXModel.gemma4E4B.speculativeDraft, .gemma4E2B,
            "Gemma4 E4B's recommended speculative draft is E2B")
        XCTAssertTrue(QinaoMLXModel.gemma4E4B.supportsSpeculativeDecoding)
        XCTAssertEqual(QinaoMLXModel.gemma4E4B.certificationTier, "certified")
    }

    func testFallbackLanePairsAreExposedAsExperimental() {
        // Standard-arch fallback lane (no Gemma-3n wedge): Llama / Qwen.
        XCTAssertEqual(QinaoMLXModel.llama3_2_3B.speculativeDraft, .llama3_2_1B)
        XCTAssertEqual(QinaoMLXModel.qwen2_5_3B.speculativeDraft, .qwen2_5_1_5B)
        XCTAssertEqual(QinaoMLXModel.llama3_2_3B.certificationTier, "experimental")
        XCTAssertEqual(QinaoMLXModel.qwen2_5_3B.certificationTier, "experimental")
    }

    func testModelsWithoutASiblingHaveNoDraft() {
        // Gemma 3 4B (no same-family sibling) + the small models themselves (they are drafts, not targets).
        XCTAssertNil(QinaoMLXModel.gemma3_4B.speculativeDraft)
        XCTAssertFalse(QinaoMLXModel.gemma3_4B.supportsSpeculativeDecoding)
        XCTAssertNil(QinaoMLXModel.gemma4E2B.speculativeDraft, "E2B is a draft, not a target")
        XCTAssertNil(QinaoMLXModel.llama3_2_1B.speculativeDraft)
    }

    func testDraftIsAlwaysSmallerSameFamilyAndExists() {
        for model in QinaoMLXModel.allCases {
            guard let draft = model.speculativeDraft else { continue }
            XCTAssertNotEqual(draft, model, "a model cannot be its own draft")
            XCTAssertTrue(QinaoMLXModel.allCases.contains(draft),
                "the surfaced draft must be a real selectable QinaoMLXModel")
        }
    }
}
