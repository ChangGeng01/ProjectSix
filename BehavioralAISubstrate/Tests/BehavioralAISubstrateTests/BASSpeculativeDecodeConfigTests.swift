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

    // MARK: - 2c. Greedy default-on (gated + capability auto-select + byte-identical fallback)

    func testDefaultModeIsGreedyAndAutoResolvesDraft() {
        // Default-on (operator-elected): a bare adapter is greedy with the curated same-family draft resolved.
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.gemma4_E4B_4bit)
        XCTAssertEqual(adapter.speculativeDecoding, .greedy, "speculation defaults ON (greedy)")
        XCTAssertEqual(adapter.draftModel, MLXModelCatalog.gemma4_E2B_4bit,
            "the draft is auto-resolved from speculativePairings when none is passed")
    }

    func testGemmaDefaultDoesNotEngageSpeculation() {
        // Gemma4 E4B+E2B (~4.2GB) exceeds the 3000MB fit budget ⇒ draft NOT loaded ⇒ single-model (byte-identical).
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.gemma4_E4B_4bit)
        XCTAssertFalse(adapter.willEngageSpeculation,
            "the certified-family Gemma pair does NOT fit 8GB ⇒ stays single-model even with default-on greedy")
    }

    func testLlamaTargetEngagesSpeculation() {
        // Llama-3.2 3B+1B (~2.5GB) fits the budget ⇒ speculation engages.
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.llama3_2_3B_4bit)
        XCTAssertEqual(adapter.draftModel, MLXModelCatalog.llama3_2_1B_4bit)
        XCTAssertTrue(adapter.willEngageSpeculation,
            "the certified Llama 3B↔1B pair fits ⇒ greedy speculation auto-engages")
    }

    func testTargetWithoutPairingStaysSingleModel() {
        // Gemma 3 4B has no same-family sibling ⇒ no draft resolved ⇒ never speculates.
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.gemma3_4B_it_4bit)
        XCTAssertNil(adapter.draftModel)
        XCTAssertFalse(adapter.willEngageSpeculation)
    }

    func testExplicitOffDisablesEverything() {
        let adapter = MLXOrganAdapter(
            model: MLXModelCatalog.llama3_2_3B_4bit, speculativeDecoding: .off)
        XCTAssertNil(adapter.draftModel, "off ⇒ no draft auto-resolved")
        XCTAssertFalse(adapter.willEngageSpeculation)
    }

    func testNilFitBudgetDisablesTheFitGate() {
        // A host on an entitled / higher-memory device can pass nil to load any configured pair.
        let adapter = MLXOrganAdapter(
            model: MLXModelCatalog.gemma4_E4B_4bit, speculativeFitBudgetBytes: nil)
        XCTAssertTrue(adapter.willEngageSpeculation,
            "nil fit budget ⇒ fit-gate off ⇒ the resolved Gemma draft would load (host opted into the heavier pair)")
    }

    // MARK: - 2d. Byte-safety: only GREEDY requests are eligible (scout/core never converted)

    func testOnlyGreedyRequestsAreEligibleUnderGreedyMode() {
        func req(_ preset: BASOrganPreset) -> BASOrganRequest {
            BASOrganRequest(requestID: "r", role: .core, preset: preset, instruction: "hi", context: [])
        }
        // Greedy mode: ONLY a temperature-0 request is eligible — scout (0.1) / core (0.7) are NOT (converting
        // them to greedy would change their output → byte-equality break).
        XCTAssertTrue(MLXOrganAdapter.requestEligibleForSpeculation(
            mode: .greedy, request: req(.greedyDeterministic)))
        XCTAssertFalse(MLXOrganAdapter.requestEligibleForSpeculation(
            mode: .greedy, request: req(.scout)), "scout (temp 0.1) must NOT be converted to greedy")
        XCTAssertFalse(MLXOrganAdapter.requestEligibleForSpeculation(
            mode: .greedy, request: req(.core)), "core (temp 0.7) must NOT be converted to greedy")
        // Sampling mode eligibility is the mirror (temp > 0); off is never eligible.
        XCTAssertTrue(MLXOrganAdapter.requestEligibleForSpeculation(mode: .sampling, request: req(.core)))
        XCTAssertFalse(MLXOrganAdapter.requestEligibleForSpeculation(mode: .sampling, request: req(.greedyDeterministic)))
        XCTAssertFalse(MLXOrganAdapter.requestEligibleForSpeculation(mode: .off, request: req(.greedyDeterministic)))
    }

    // MARK: - 2e. Satisfaction pass: optimal-target pointer + post-load reality signals

    func testSpeculativeOptimalTargetIsTheCertifiedLlamaPair() {
        XCTAssertEqual(MLXModelCatalog.speculativeOptimalTarget, MLXModelCatalog.llama3_2_3B_4bit,
            "the speculation-optimal pointer names the on-device-certified enable pair's target")
        // And it actually engages under the default fit budget (the whole point of the pointer).
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.speculativeOptimalTarget)
        XCTAssertTrue(adapter.willEngageSpeculation)
        // The DEFAULT target stays Gemma (quality default unchanged — the honest trade is documented).
        XCTAssertEqual(MLXOrganAdapter().model, MLXModelCatalog.gemma4_E4B_4bit)
    }

    #if canImport(MLXLLM)
    func testSpeculationRealitySignalsBeforeLoad() async {
        // Pre-load: the PLAN says engage, the REALITY says not yet (no container), and no failure is recorded.
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.speculativeOptimalTarget)
        XCTAssertTrue(adapter.willEngageSpeculation, "plan: the pair fits ⇒ will engage")
        let active = await adapter.isSpeculationActive
        let reason = await adapter.draftLoadFailureReason
        XCTAssertFalse(active, "reality: nothing loaded yet ⇒ not active (plan ≠ reality)")
        XCTAssertNil(reason, "no auto-load attempted ⇒ no failure reason")
    }
    #endif

    func testMemoryBudgetFitDiscriminatesPairs() {
        let budget = BASMLXMemoryBudget.defaultSpeculativeFitBudgetBytes
        XCTAssertTrue(BASMLXMemoryBudget.dualResidencyFits(
            targetProviderID: "mlx.llama3_2.3b.it.4bit", draftProviderID: "mlx.llama3_2.1b.it.4bit",
            budgetBytes: budget), "Llama 3B+1B (~2.5GB) fits the 3000MB budget")
        XCTAssertFalse(BASMLXMemoryBudget.dualResidencyFits(
            targetProviderID: "mlx.gemma4.e4b.it.4bit", draftProviderID: "mlx.gemma4.e2b.it.4bit",
            budgetBytes: budget), "Gemma4 E4B+E2B (~4.2GB) exceeds the 3000MB budget")
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

    func testSamplingModeStillRequiresLoadedDraft() async {
        // .sampling is wired (Leviathan rejection sampling) but on-device-certified doNotEnable (latency loss),
        // so it is never the default. If a host explicitly elects it, it still cannot engage until the draft
        // container is actually loaded.
        let adapter = MLXOrganAdapter(
            model: MLXModelCatalog.gemma4_E4B_4bit,
            draftModel: MLXModelCatalog.gemma4_E2B_4bit,
            speculativeDecoding: .sampling)
        let request = BASOrganRequest(
            requestID: "r", role: .core, preset: .core, instruction: "hi", context: [])
        let speculate = await adapter.shouldSpeculate(for: request)
        XCTAssertFalse(speculate, "no loaded draft container ⇒ sampling stays single-model")
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
