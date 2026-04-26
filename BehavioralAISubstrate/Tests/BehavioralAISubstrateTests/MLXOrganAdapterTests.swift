import XCTest
@testable import BASOrgan
@testable import BASMLXAdapter

/// M220 — coverage for `MLXOrganAdapter` scaffolding.
///
/// Real model loading + inference is M221. These tests pin the
/// shape of the M220 deliverable:
///
///   - descriptor matches the catalog entry's identity
///   - draft() honestly throws "not loaded yet" with a stable
///     reason code that downstream callers can pattern-match
///   - currentCapacity reports underPressure with a stable reason
///   - the catalog ships exactly the three default Gemma entries
///     hosts can rely on
final class MLXOrganAdapterTests: XCTestCase {

    // MARK: - 1. Descriptor

    func testDescriptorPicksUpCatalogIdentityByDefault() async {
        let adapter = MLXOrganAdapter(
            model: MLXModelCatalog.gemma3n_E4B_4bit)
        XCTAssertEqual(
            adapter.descriptor.providerID,
            "mlx.gemma3n.e4b.it.4bit")
        XCTAssertEqual(
            adapter.descriptor.providerName,
            "Gemma 3n E4B (MLX, 4-bit)")
        XCTAssertTrue(adapter.descriptor.runsOnDevice)
        XCTAssertTrue(adapter.descriptor.supportsStreaming)
        XCTAssertEqual(
            adapter.descriptor.supportedRoles,
            [.scout, .core])
    }

    func testDescriptorOverridesUseExplicitValues() async {
        let adapter = MLXOrganAdapter(
            model: MLXModelCatalog.gemma3_4B_it_4bit,
            providerID: "test.override.v1",
            providerName: "Test Override")
        XCTAssertEqual(
            adapter.descriptor.providerID,
            "test.override.v1")
        XCTAssertEqual(
            adapter.descriptor.providerName,
            "Test Override")
    }

    // MARK: - 2. Draft path is honestly unavailable in M220

    func testDraftThrowsProviderUnavailableWhenModelNotLoaded() async {
        let adapter = MLXOrganAdapter()
        let request = BASOrganRequest(
            requestID: "req-1",
            role: .core,
            preset: .core,
            instruction: "say hi",
            context: [])
        do {
            _ = try await adapter.draft(request)
            XCTFail(
                "fresh adapter must not produce a draft — " +
                "loadModel(progressHandler:) has not been called " +
                "so MLX has no ModelContainer to drive inference")
        } catch BASOrganError.providerUnavailable(let reason) {
            // Either the not-loaded path or the build-unavailable
            // path is acceptable; both are honest "we cannot serve
            // this request" responses.
            XCTAssertTrue(
                reason.contains("mlx-organ-adapter-not-loaded")
                    || reason.contains("MLXLLM framework"),
                "expected a stable not-loaded-or-build reason; " +
                "got: \(reason)")
        } catch {
            XCTFail(
                "expected providerUnavailable but got \(error)")
        }
    }

    func testDraftRejectsUnsupportedRole() async {
        let adapter = MLXOrganAdapter(
            model: MLXModelCatalog.gemma3_4B_it_4bit,
            supportedRoles: [.scout])
        let request = BASOrganRequest(
            requestID: "req-2",
            role: .core,  // not in supported set
            preset: .core,
            instruction: "say hi",
            context: [])
        do {
            _ = try await adapter.draft(request)
            XCTFail("expected unsupportedRole")
        } catch BASOrganError.unsupportedRole(let role) {
            XCTAssertEqual(role, .core)
        } catch {
            XCTFail("expected unsupportedRole but got \(error)")
        }
    }

    // MARK: - 3. Capacity

    func testCapacityReportsUnderPressureWithStableReason() async {
        let adapter = MLXOrganAdapter()
        let cap = await adapter.currentCapacity()
        XCTAssertTrue(cap.underPressure)
        XCTAssertEqual(cap.availableInputTokens, 0)
        XCTAssertEqual(cap.availableOutputTokens, 0)
        let valid = ["MLX_NOT_LOADED", "MLX_UNAVAILABLE_BUILD"]
        XCTAssertTrue(
            cap.reasonCodes.contains(where: { valid.contains($0) }),
            "expected one of \(valid); got \(cap.reasonCodes)")
    }

    // MARK: - 4. Catalog stability

    func testDefaultCatalogShipsCanonicalGemmaEntries() {
        let entries = MLXModelCatalog.defaultEntries
        // M235 added Gemma 4 e4b/e2b alongside the existing
        // Gemma 3 4B + Gemma 3n e4b/e2b. The canonical mlx-community
        // Gemma family is now five entries.
        XCTAssertEqual(entries.count, 5)
        let ids = Set(entries.map(\.id))
        XCTAssertEqual(ids, [
            "mlx-community/gemma-4-e4b-it-4bit",
            "mlx-community/gemma-4-e2b-it-4bit",
            "mlx-community/gemma-3-4b-it-4bit",
            "mlx-community/gemma-3n-E4B-it-lm-4bit",
            "mlx-community/gemma-3n-E2B-it-lm-4bit"
        ])
    }

    func testEachEntryDeclaresGemmaTurnTerminatorForCorrectStop() {
        // Gemma 3 / 3n use `<end_of_turn>`; Gemma 4 uses `<turn|>`.
        // Every entry must declare at least one of these so
        // generation stops at the reply boundary.
        let validTerminators = ["<end_of_turn>", "<turn|>"]
        for entry in MLXModelCatalog.defaultEntries {
            let hasOne = entry.extraEOSTokens.contains(where: {
                validTerminators.contains($0)
            })
            XCTAssertTrue(
                hasOne,
                "entry \(entry.id) must list one of " +
                "\(validTerminators) as an extra EOS token; " +
                "without it generation runs past the reply " +
                "(Gemma 3/3n use <end_of_turn>, Gemma 4 uses " +
                "<turn|>)")
        }
    }

    func testGemmaGenerationFamilyMapsToCorrectTerminator() {
        // Pin the Gemma 3 family → <end_of_turn> mapping.
        XCTAssertTrue(
            MLXModelCatalog.gemma3_4B_it_4bit.extraEOSTokens
                .contains("<end_of_turn>"))
        XCTAssertTrue(
            MLXModelCatalog.gemma3n_E4B_4bit.extraEOSTokens
                .contains("<end_of_turn>"))
        XCTAssertTrue(
            MLXModelCatalog.gemma3n_E2B_4bit.extraEOSTokens
                .contains("<end_of_turn>"))
        // Pin the Gemma 4 family → <turn|> mapping.
        XCTAssertTrue(
            MLXModelCatalog.gemma4_E4B_4bit.extraEOSTokens
                .contains("<turn|>"))
        XCTAssertTrue(
            MLXModelCatalog.gemma4_E2B_4bit.extraEOSTokens
                .contains("<turn|>"))
        // Confirm the families don't accidentally use the wrong
        // terminator (a copy-paste mistake would surface here).
        XCTAssertFalse(
            MLXModelCatalog.gemma3_4B_it_4bit.extraEOSTokens
                .contains("<turn|>"))
        XCTAssertFalse(
            MLXModelCatalog.gemma4_E4B_4bit.extraEOSTokens
                .contains("<end_of_turn>"))
    }

    func testCatalogProviderIDsAreUniqueAndStable() {
        let providers = MLXModelCatalog.defaultEntries
            .map(\.providerID)
        XCTAssertEqual(
            Set(providers).count, providers.count,
            "providerIDs must be unique across catalog entries " +
            "(audit logs rely on them as primary keys)")
    }

    // MARK: - 5. Default pick is the recommended one

    func testInitDefaultsToGemma3nE4Bit() async {
        // Recommended pick per M220 plan §3.1 — Gemma 3n e4b
        // gives Gemma-3-4B-class quality with lower runtime
        // memory and higher tok/s on Apple Silicon.
        let adapter = MLXOrganAdapter()
        XCTAssertEqual(
            adapter.model, MLXModelCatalog.gemma3n_E4B_4bit)
    }

    // MARK: - 6. Preset → GenerateParameters mapping (M226)

    /// Pinning the preset → GenerateParameters translation so a
    /// future tweak to scout/core temperatures gets a visible test
    /// diff. Without this test, swapping the values silently keeps
    /// the suite green while changing every real inference.
    #if canImport(MLXLLM)
    func testGenerateParametersScoutPresetUsesLowTemperature() async {
        let adapter = MLXOrganAdapter()
        let params = await adapter._generateParameters(for: .scout)
        XCTAssertEqual(
            params.temperature, Float(BASOrganPreset.scout.temperature),
            accuracy: 1e-6,
            "scout temperature must mirror BASOrganPreset.scout.temperature")
        XCTAssertEqual(
            params.topP, Float(BASOrganPreset.scout.topP),
            accuracy: 1e-6,
            "scout topP must mirror BASOrganPreset.scout.topP")
    }

    func testGenerateParametersCorePresetUsesMidTemperature() async {
        let adapter = MLXOrganAdapter()
        let params = await adapter._generateParameters(for: .core)
        XCTAssertEqual(
            params.temperature, Float(BASOrganPreset.core.temperature),
            accuracy: 1e-6,
            "core temperature must mirror BASOrganPreset.core.temperature")
        XCTAssertEqual(
            params.topP, Float(BASOrganPreset.core.topP),
            accuracy: 1e-6,
            "core topP must mirror BASOrganPreset.core.topP")
    }

    func testGenerateParametersScoutAndCoreDiffer() async {
        // The two presets exist precisely so `.scout` is more
        // deterministic than `.core`. If they ever produce equal
        // GenerateParameters, the architecture's two-tier organ
        // contract has silently collapsed.
        let adapter = MLXOrganAdapter()
        let scout = await adapter._generateParameters(for: .scout)
        let core = await adapter._generateParameters(for: .core)
        XCTAssertNotEqual(
            scout.temperature, core.temperature,
            "scout and core must produce distinct temperatures " +
            "(otherwise the two-tier organ contract is broken)")
    }
    #endif

    // MARK: - 7. Prompt builder coverage (M226)

    /// Pure prompt-builder helpers exposed for cross-provider
    /// stability — `AppleFoundationOrganAdapter.prompt(for:)` and
    /// `MLXOrganAdapter.prompt(for:)` produce the same shape, so
    /// audit logs from either provider are byte-comparable.
    func testPromptForBareInstructionHasNoContextSection() {
        let request = BASOrganRequest(
            requestID: "r1",
            role: .core,
            preset: .core,
            instruction: "say hi",
            context: [])
        let prompt = MLXOrganAdapter.prompt(for: request)
        XCTAssertTrue(prompt.contains("Instruction:"))
        XCTAssertTrue(prompt.contains("say hi"))
        XCTAssertFalse(
            prompt.contains("Context:"),
            "no context items → no Context: section")
    }

    func testPromptWithContextNumbersItemsStartingAtOne() {
        let request = BASOrganRequest(
            requestID: "r2",
            role: .core,
            preset: .core,
            instruction: "summarize",
            context: ["fact one", "fact two", "fact three"])
        let prompt = MLXOrganAdapter.prompt(for: request)
        XCTAssertTrue(prompt.contains("[1] fact one"))
        XCTAssertTrue(prompt.contains("[2] fact two"))
        XCTAssertTrue(prompt.contains("[3] fact three"))
    }

    func testSystemInstructionsScoutIsShorter() {
        // Scout's system instructions are explicitly the
        // "low-commitment / structured" tier — pin that they
        // mention "Scout" and stay separate from core's wording.
        let scoutReq = BASOrganRequest(
            requestID: "r3",
            role: .scout,
            preset: .scout,
            instruction: "anything",
            context: [])
        let coreReq = BASOrganRequest(
            requestID: "r4",
            role: .core,
            preset: .core,
            instruction: "anything",
            context: [])
        let scoutText = MLXOrganAdapter.systemInstructions(
            for: scoutReq)
        let coreText = MLXOrganAdapter.systemInstructions(
            for: coreReq)
        XCTAssertNotEqual(
            scoutText, coreText,
            "scout vs core system instructions must differ")
        XCTAssertTrue(
            scoutText.contains("Scout"),
            "scout system instructions must mention the role name")
        XCTAssertTrue(
            coreText.contains("Core"),
            "core system instructions must mention the role name")
    }
}
