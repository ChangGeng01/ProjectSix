import XCTest
@testable import BASOrgan
@testable import BASMLXAdapter
#if canImport(MLXLLM)
import MLXLMCommon
#endif

/// 结构大重构 — Phase 0/1: coverage for the speculative-decoding CONFIG surface + the greedy-lane preconditions.
///
/// The full token-identity proof (greedy spec output == greedy target-only output) requires running two real
/// models and is the on-device cert (Phase 6). Here we pin the host-testable guarantees:
///   - the mode enum + the additive greedy preset (pure)
///   - the pure pairing-validity rule (shared tokenizer required, distinct model)
///   - the ADR-014 byte-identity witness: spec-decode OFF ⇒ `shouldSpeculate` false (no speculative path)
///   - the greedy-lane precondition: greedy params force temperature 0, and temperature 0 selects the
///     `ArgMaxSampler` whose exact-equality acceptance IS what makes greedy speculation token-identical.
final class BASSpeculativeDecodeConfigTests: XCTestCase {

    // MARK: - 1. Mode enum + additive greedy preset (pure)

    func testSpeculativeModeRoundTripsAndDefaultsConceptuallyOff() throws {
        for mode in BASSpeculativeMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let back = try JSONDecoder().decode(BASSpeculativeMode.self, from: data)
            XCTAssertEqual(mode, back, "BASSpeculativeMode must round-trip through Codable")
        }
        XCTAssertEqual(BASSpeculativeMode.allCases.count, 3, "off / greedy / sampling")
    }

    func testGreedyDeterministicPresetIsAdditiveAndGreedy() {
        let p = BASOrganPreset.greedyDeterministic
        XCTAssertEqual(p.temperature, 0, "greedy preset must be temperature 0 (argmax)")
        XCTAssertTrue(p.deterministic, "greedy preset is deterministic")
        XCTAssertEqual(p.name, "bas.greedy.v1")
        // Additive — the existing presets are byte-unchanged.
        XCTAssertEqual(BASOrganPreset.scout.temperature, 0.1, "scout preset must be untouched")
        XCTAssertEqual(BASOrganPreset.core.temperature, 0.7, "core preset must be untouched")
    }

    // MARK: - 2. Pure pairing validity

    func testValidSameFamilyPairings() {
        XCTAssertTrue(MLXOrganAdapter.isValidDraftPairing(
            target: MLXModelCatalog.gemma4_E4B_4bit, draft: MLXModelCatalog.gemma4_E2B_4bit),
            "Gemma4 E4B↔E2B share the <turn|> tokenizer family")
        XCTAssertTrue(MLXOrganAdapter.isValidDraftPairing(
            target: MLXModelCatalog.llama3_2_3B_4bit, draft: MLXModelCatalog.llama3_2_1B_4bit),
            "Llama-3.2 3B↔1B share the <|eot_id|> tokenizer family")
        XCTAssertTrue(MLXOrganAdapter.isValidDraftPairing(
            target: MLXModelCatalog.qwen2_5_3B_4bit, draft: MLXModelCatalog.qwen2_5_1_5B_4bit),
            "Qwen2.5 3B↔1.5B share the <|im_end|> tokenizer family")
    }

    func testCrossFamilyPairingsAreRejected() {
        XCTAssertFalse(MLXOrganAdapter.isValidDraftPairing(
            target: MLXModelCatalog.gemma4_E4B_4bit, draft: MLXModelCatalog.llama3_2_1B_4bit),
            "Gemma target with a Llama draft is a tokenizer mismatch — rejected")
        XCTAssertFalse(MLXOrganAdapter.isValidDraftPairing(
            target: MLXModelCatalog.gemma4_E4B_4bit, draft: MLXModelCatalog.gemma3_4B_it_4bit),
            "Gemma4 (<turn|>) and Gemma3 (<end_of_turn>) are different families — rejected")
        XCTAssertFalse(MLXOrganAdapter.isValidDraftPairing(
            target: MLXModelCatalog.gemma4_E4B_4bit, draft: MLXModelCatalog.gemma4_E4B_4bit),
            "a model cannot be its own draft")
    }

    // MARK: - 2b. Curated speculative pairings (Phase 3)

    func testCuratedSpeculativePairingsAreValidAndSameFamily() {
        // The PRIMARY cert target + the two fallback-lane pairs.
        XCTAssertEqual(
            MLXModelCatalog.recommendedDraft(forTargetProviderID: MLXModelCatalog.gemma4_E4B_4bit.providerID),
            MLXModelCatalog.gemma4_E2B_4bit, "Gemma4 E4B's curated draft is E2B (primary cert target)")
        XCTAssertEqual(
            MLXModelCatalog.recommendedDraft(forTargetProviderID: MLXModelCatalog.llama3_2_3B_4bit.providerID),
            MLXModelCatalog.llama3_2_1B_4bit, "Llama-3.2 3B's curated draft is 1B (fallback lane)")
        XCTAssertEqual(
            MLXModelCatalog.recommendedDraft(forTargetProviderID: MLXModelCatalog.qwen2_5_3B_4bit.providerID),
            MLXModelCatalog.qwen2_5_1_5B_4bit, "Qwen2.5 3B's curated draft is 1.5B (fallback lane)")
        // Every curated pair must pass the validity rule.
        for (targetID, draft) in MLXModelCatalog.speculativePairings {
            let target = MLXModelCatalog.allEntries.first { $0.providerID == targetID }!
            XCTAssertTrue(MLXOrganAdapter.isValidDraftPairing(target: target, draft: draft),
                "curated pairing \(targetID)→\(draft.providerID) must satisfy isValidDraftPairing")
        }
    }

    func testGemma3HasNoCuratedDraft() {
        XCTAssertNil(
            MLXModelCatalog.recommendedDraft(forTargetProviderID: MLXModelCatalog.gemma3_4B_it_4bit.providerID),
            "Gemma 3 4B has no same-family sibling ⇒ speculative decoding honestly unavailable")
    }

    // MARK: - 3. ADR-014 byte-identity witness: OFF ⇒ no speculative path

    #if canImport(MLXLLM)
    func testShouldSpeculateFalseWhenModeOff() async {
        let adapter = MLXOrganAdapter(
            model: MLXModelCatalog.gemma4_E4B_4bit,
            draftModel: MLXModelCatalog.gemma4_E2B_4bit,
            speculativeDecoding: .off)   // off ⇒ never speculate, even with a draft configured
        let request = BASOrganRequest(
            requestID: "r", role: .core, preset: .greedyDeterministic,
            instruction: "hi", context: [])
        let speculate = await adapter.shouldSpeculate(for: request)
        XCTAssertFalse(speculate, "mode .off ⇒ shouldSpeculate false ⇒ byte-identical single-model path")
    }

    func testShouldSpeculateFalseWhenDraftNotLoaded() async {
        // Mode greedy + draft configured, but loadDraftModel never ran ⇒ no draft container ⇒ no speculation.
        let adapter = MLXOrganAdapter(
            model: MLXModelCatalog.gemma4_E4B_4bit,
            draftModel: MLXModelCatalog.gemma4_E2B_4bit,
            speculativeDecoding: .greedy)
        let request = BASOrganRequest(
            requestID: "r", role: .core, preset: .greedyDeterministic,
            instruction: "hi", context: [])
        let speculate = await adapter.shouldSpeculate(for: request)
        XCTAssertFalse(speculate, "no loaded draft container ⇒ shouldSpeculate false (fail-honest fallback)")
    }

    func testShouldSpeculateFalseForSamplingWithoutLoadedDraft() async {
        // Phase 2: .sampling IS wired (Leviathan rejection sampling), but like .greedy it still requires a loaded
        // draft container — without one it falls back to single-model (the fail-honest path).
        let adapter = MLXOrganAdapter(
            model: MLXModelCatalog.gemma4_E4B_4bit,
            draftModel: MLXModelCatalog.gemma4_E2B_4bit,
            speculativeDecoding: .sampling)
        let request = BASOrganRequest(
            requestID: "r", role: .core, preset: .core, instruction: "hi", context: [])
        let speculate = await adapter.shouldSpeculate(for: request)
        XCTAssertFalse(speculate, ".sampling with no loaded draft container ⇒ single-model fallback")
    }

    // MARK: - 4. Greedy-lane precondition: temp 0 → ArgMaxSampler (the token-identity guarantee)

    func testGreedyParametersForceTemperatureZero() async {
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.gemma4_E4B_4bit)
        let params = await adapter._greedyParameters(for: .core)   // core is temp 0.7
        XCTAssertEqual(params.temperature, 0,
            "greedy lane forces temperature 0 regardless of the preset (core is 0.7)")
    }

    func testTemperatureZeroSelectsArgMaxSampler() {
        // The token-identity guarantee rests on this: at temperature 0 the vendored sampler is ArgMaxSampler,
        // whose deterministic argmax makes the speculative exact-equality acceptance token-identical to greedy
        // target-only decoding. If a vendor refresh changed this, greedy speculation would NOT be byte-identical.
        var params = GenerateParameters()
        params.temperature = 0
        XCTAssertTrue(params.sampler() is ArgMaxSampler,
            "temperature 0 must select ArgMaxSampler — the precondition for greedy token-identity")
    }
    #endif
}
