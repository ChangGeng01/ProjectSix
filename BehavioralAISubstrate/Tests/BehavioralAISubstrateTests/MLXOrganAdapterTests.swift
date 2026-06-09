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
            model: MLXModelCatalog.gemma4_E4B_4bit)
        XCTAssertEqual(
            adapter.descriptor.providerID,
            "mlx.gemma4.e4b.it.4bit")
        XCTAssertEqual(
            adapter.descriptor.providerName,
            "Gemma 4 E4B (MLX, 4-bit)")
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
        // M236 retired Gemma 3n entries; the catalog is now Gemma
        // 4 e4b/e2b (recommended) + Gemma 3 4B (long-context
        // outlier).
        XCTAssertEqual(entries.count, 3)
        let ids = Set(entries.map(\.id))
        XCTAssertEqual(ids, [
            "mlx-community/gemma-4-e4b-it-4bit",
            "mlx-community/gemma-4-e2b-it-4bit",
            "mlx-community/gemma-3-4b-it-4bit"
        ])
    }

    func testEachEntryDeclaresGemmaTurnTerminatorForCorrectStop() {
        // Gemma 3 4B uses `<end_of_turn>`; Gemma 4 uses `<turn|>`.
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
                "(Gemma 3 4B uses <end_of_turn>, Gemma 4 uses " +
                "<turn|>)")
        }
    }

    func testGemmaGenerationFamilyMapsToCorrectTerminator() {
        // Pin the Gemma 3 family → <end_of_turn> mapping.
        XCTAssertTrue(
            MLXModelCatalog.gemma3_4B_it_4bit.extraEOSTokens
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

    func testInitDefaultsToGemma4E4B() async {
        // M236 retired Gemma 3n; default is now Gemma 4 E4B
        // (newest architecture, recommended for new hosts).
        let adapter = MLXOrganAdapter()
        XCTAssertEqual(
            adapter.model, MLXModelCatalog.gemma4_E4B_4bit)
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

    // ch1066 — every token decode must be bounded. Before this fix
    // `_generateParameters` never set `params.maxTokens`, so generation relied solely
    // on the model emitting EOS; structured/adversarial prompts could run away unbounded.
    // These pin that every decode is now capped — an explicit per-request cap wins, else
    // the PRESET's output budget, clamped to the descriptor ceiling — so `maxTokens` is
    // never nil. (再查: the on-device iter=1 freeze was a zero-token Metal/GPU eval hang,
    // handled by the feed-forward gate + projection sanitization, not this token cap.)
    func testGenerateParametersFallsBackToPresetBudgetByDefault() async {
        let adapter = MLXOrganAdapter()  // default descriptor maxOutputTokens = 4096
        let params = await adapter._generateParameters(for: .core)
        XCTAssertEqual(
            params.maxTokens, BASOrganPreset.core.maxOutputTokens,
            "an unset per-request cap must fall back to the preset's output budget " +
            "(core), clamped to the descriptor — matching the cloud adapter; never nil")
    }

    func testGenerateParametersHonorsExplicitPerRequestCap() async {
        let adapter = MLXOrganAdapter()
        let params = await adapter._generateParameters(
            for: .core, maxOutputTokens: 256)
        XCTAssertEqual(
            params.maxTokens, 256,
            "an explicit per-request maxOutputTokens must cap the decode")
    }

    func testGenerateParametersCustomDescriptorMaxBoundsDecode() async {
        let adapter = MLXOrganAdapter(maxOutputTokens: 512)
        let params = await adapter._generateParameters(for: .core)
        XCTAssertEqual(
            params.maxTokens, 512,
            "the descriptor's maxOutputTokens must bound the decode when no " +
            "per-request cap is supplied")
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

    // MARK: - 7. M256 marker post-processor

    func testMarkerPostprocessingRewritesNeedsVerification() {
        // M251 N=400 found 2/400 cases where M247 LoRA emits
        // [NEEDS_VERIFICATION] for password-update prompts. The
        // post-processor rewrites that marker to [NEEDS_PERMIT]
        // so L11 / L14 gates parse it.
        let raw = "[NEEDS_VERIFICATION] action required. " +
                  "Unable to proceed."
        let processed =
            MLXOrganAdapter.applyMarkerPostprocessing(raw)
        XCTAssertTrue(
            processed.contains("[NEEDS_PERMIT]"),
            "[NEEDS_VERIFICATION] must be rewritten to " +
            "[NEEDS_PERMIT]")
        XCTAssertFalse(
            processed.contains("[NEEDS_VERIFICATION]"),
            "[NEEDS_VERIFICATION] must not survive rewrite")
    }

    func testMarkerPostprocessingPreservesBodyAroundMarker() {
        // Only the marker token gets rewritten; surrounding
        // text is byte-identical.
        let raw = "[NEEDS_VERIFICATION] action required. " +
                  "Unable to proceed."
        let processed =
            MLXOrganAdapter.applyMarkerPostprocessing(raw)
        XCTAssertTrue(
            processed.contains("action required."),
            "body text after marker preserved verbatim")
        XCTAssertTrue(
            processed.contains("Unable to proceed."),
            "body text after marker preserved verbatim")
        XCTAssertEqual(
            processed,
            "[NEEDS_PERMIT] action required. Unable to proceed.")
    }

    func testMarkerPostprocessingNoOpForCanonicalBody() {
        // Bodies that already use the canonical [NEEDS_PERMIT]
        // marker pass through unchanged.
        let canonical = """
            [NEEDS_PERMIT] action: update profile field
                            target: profile.age
                            reversibility: reversible
            I would update the age field. Confirm to proceed.
            """
        XCTAssertEqual(
            MLXOrganAdapter.applyMarkerPostprocessing(canonical),
            canonical,
            "canonical body must pass through unchanged")
    }

    func testMarkerPostprocessingNoOpForRiskOnlyBody() {
        // RISK-emitting bodies without any verification marker
        // pass through unchanged. Don't accidentally munge them.
        let body = """
            [RISK] category: privacy
                   reason: bulk-disclose contact data
            I cannot send your contacts.
            """
        XCTAssertEqual(
            MLXOrganAdapter.applyMarkerPostprocessing(body),
            body)
    }

    func testMarkerPostprocessingRewritesMultipleOccurrences() {
        // If the model emits the substituted marker twice in
        // one body (rare but possible in multi-tool contexts),
        // both get rewritten.
        let raw = "[NEEDS_VERIFICATION] step 1\n" +
                  "[NEEDS_VERIFICATION] step 2"
        let processed =
            MLXOrganAdapter.applyMarkerPostprocessing(raw)
        XCTAssertEqual(
            processed,
            "[NEEDS_PERMIT] step 1\n[NEEDS_PERMIT] step 2")
    }

    func testMarkerPostprocessingIsIdempotent() {
        // Running the post-processor twice must produce the same
        // output as running it once. Hosts that rely on the
        // post-processed body can re-process safely.
        let raw = "[NEEDS_VERIFICATION] x"
        let once =
            MLXOrganAdapter.applyMarkerPostprocessing(raw)
        let twice =
            MLXOrganAdapter.applyMarkerPostprocessing(once)
        XCTAssertEqual(
            once, twice,
            "post-processor must be idempotent")
    }

    // MARK: - 8. M254 multi-turn session pool surface

    func testSessionCountIsZeroOnFreshAdapter() async {
        let adapter = MLXOrganAdapter(
            model: MLXModelCatalog.gemma4_E2B_4bit)
        let count = await adapter.sessionCount()
        XCTAssertEqual(
            count, 0,
            "fresh adapter must have no cached sessions")
    }

    func testClearAllSessionsIsIdempotent() async {
        // Calling clearAllSessions on a fresh adapter is a no-op
        // and must not crash. Subsequent calls return same count.
        let adapter = MLXOrganAdapter(
            model: MLXModelCatalog.gemma4_E2B_4bit)
        await adapter.clearAllSessions()
        let countA = await adapter.sessionCount()
        await adapter.clearAllSessions()
        let countB = await adapter.sessionCount()
        XCTAssertEqual(countA, 0)
        XCTAssertEqual(countB, 0)
    }

    func testClearSessionByIDIsNoOpForUnknownID() async {
        // Clearing an unknown session ID is a defensive no-op
        // (no thrown error, no crash). Hosts that don't track
        // which IDs they used can call this freely.
        let adapter = MLXOrganAdapter(
            model: MLXModelCatalog.gemma4_E2B_4bit)
        await adapter.clearSession(
            sessionID: "never-existed-\(UUID().uuidString)")
        let count = await adapter.sessionCount()
        XCTAssertEqual(count, 0)
    }

    func testDraftMultiTurnThrowsProviderUnavailableWhenNotLoaded()
    async {
        // Same honest-error pattern as draft(_:) — calling
        // draftMultiTurn before loadModel(...) yields a stable
        // reason code so callers can pattern-match.
        let adapter = MLXOrganAdapter(
            model: MLXModelCatalog.gemma4_E2B_4bit)
        let req = BASOrganRequest(
            requestID: "test-mt",
            role: .scout,
            preset: .scout,
            instruction: "hello")
        do {
            _ = try await adapter.draftMultiTurn(
                req, sessionID: "test-session")
            XCTFail(
                "expected providerUnavailable when model is " +
                "not loaded")
        } catch BASOrganError.providerUnavailable(let reason) {
            XCTAssertTrue(
                reason.contains("not-loaded") ||
                reason.contains("MLXLLM framework unavailable"),
                "reason should point at the missing prereq, " +
                "got: \(reason)")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testDraftMultiTurnRejectsUnsupportedRole() async {
        // Same role enforcement as draft(_:). If the adapter is
        // configured with only .scout, calling with .core throws.
        let adapter = MLXOrganAdapter(
            model: MLXModelCatalog.gemma4_E2B_4bit,
            supportedRoles: [.scout])
        let req = BASOrganRequest(
            requestID: "test-mt-role",
            role: .core,
            preset: .core,
            instruction: "hello")
        do {
            _ = try await adapter.draftMultiTurn(
                req, sessionID: "test-session")
            XCTFail(
                "expected unsupportedRole when adapter is " +
                "scout-only")
        } catch BASOrganError.unsupportedRole(let role) {
            XCTAssertEqual(role, .core)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - 9. ADR-038 §11.8 cache-pool cap (the wedge fix)

    func testCacheLimitDefaultsTo512MB() async {
        // The wedge fix ships as a DEFAULT-ON 512 MB cap (ADR-038
        // §11.8). Pin the default value AND that it flows from the
        // single named constant, so a future edit to either surfaces
        // here rather than silently changing the certified ceiling.
        let adapter = MLXOrganAdapter()
        XCTAssertEqual(
            adapter.cacheLimitBytes,
            MLXOrganAdapter.defaultCacheLimitBytes)
        XCTAssertEqual(
            MLXOrganAdapter.defaultCacheLimitBytes,
            512 * 1024 * 1024,
            "the on-device-validated cap is 512 MB; changing it " +
            "moves off the measured evidence (ADR-038 §11.8)")
    }

    func testCacheLimitNilOptOutIsReachable() async {
        // `nil` must restore upstream/unbounded behavior — the cap is
        // a ceiling, and callers (e.g. larger-RAM hosts, A/B vs the
        // unbounded default) must be able to turn it OFF explicitly.
        let adapter = MLXOrganAdapter(cacheLimitBytes: nil)
        XCTAssertNil(adapter.cacheLimitBytes)
    }

    func testCacheLimitHonorsExplicitOverride() async {
        let custom = 384 * 1024 * 1024
        let adapter = MLXOrganAdapter(cacheLimitBytes: custom)
        XCTAssertEqual(adapter.cacheLimitBytes, custom)
    }

    // NOTE on mlxMemoryStatsMB / setGPUCacheLimit / drainGPUCache:
    // these are deliberately NOT unit-tested here. On the macOS SPM
    // host `canImport(MLX)` is TRUE, so the #else (0,0,0) stub is not
    // compiled — yet the real path touches `MLX.Memory.*`, which forces
    // MLX to load its Metal default.metallib. That library is absent in
    // the test bundle, so the very first call aborts the process via
    // MLX's fatalError error-handler trampoline (the same trampoline
    // documented in Transforms+Eval.swift). They are therefore
    // on-device-only surfaces; exercising them is the endurance-run's
    // job (the §11.x `📊 mlx-mem` line), not a macOS unit test. Faking
    // coverage by invoking them here would crash the whole suite.

    // MARK: - 10. Llama 3.2 fallback catalog entry (ADR-038)

    func testLlamaEntryDeclaresEotIdTerminator() {
        // The Llama 3.2 fallback (a wedge-resistant alternative to
        // Gemma-3n) MUST list `<|eot_id|>` or generation runs past
        // the reply boundary.
        XCTAssertTrue(
            MLXModelCatalog.llama3_2_3B_4bit.extraEOSTokens
                .contains("<|eot_id|>"),
            "Llama 3.2 turn terminator is <|eot_id|>")
        XCTAssertEqual(
            MLXModelCatalog.llama3_2_3B_4bit.id,
            "mlx-community/Llama-3.2-3B-Instruct-4bit")
        XCTAssertEqual(
            MLXModelCatalog.llama3_2_3B_4bit.providerID,
            "mlx.llama3_2.3b.it.4bit")
    }

    func testLlamaEntryProviderIDDoesNotCollideWithCatalog() {
        // Audit logs key on providerID; the Llama entry must not
        // collide with any default Gemma entry.
        let defaultIDs = Set(
            MLXModelCatalog.defaultEntries.map(\.providerID))
        XCTAssertFalse(
            defaultIDs.contains(
                MLXModelCatalog.llama3_2_3B_4bit.providerID),
            "Llama providerID collides with a default entry")
    }

    func testLlamaEntryIsNotInDefaultCatalog() {
        // Honesty pin (ADR-038 audit MEDIUM): the Llama entry is an
        // available alternative, NOT a shipped default — it is not
        // on-device certified, so it must stay out of defaultEntries.
        let defaultIDs = Set(MLXModelCatalog.defaultEntries.map(\.id))
        XCTAssertFalse(
            defaultIDs.contains(MLXModelCatalog.llama3_2_3B_4bit.id),
            "Llama 3.2 is an opt-in alternative, not a default")
    }

    // MARK: - 11. Stable-architecture fallback SDK surface (#2)

    func testQwenEntryDeclaresChatMLTerminator() {
        XCTAssertTrue(
            MLXModelCatalog.qwen2_5_3B_4bit.extraEOSTokens
                .contains("<|im_end|>"),
            "Qwen2.5 uses the ChatML terminator <|im_end|>")
        XCTAssertEqual(
            MLXModelCatalog.qwen2_5_3B_4bit.id,
            "mlx-community/Qwen2.5-3B-Instruct-4bit")
        XCTAssertEqual(
            MLXModelCatalog.qwen2_5_3B_4bit.providerID,
            "mlx.qwen2_5.3b.it.4bit")
    }

    func testAvailableAlternativesAreLlamaAndQwenOptIn() {
        // The stable-arch fallbacks exposed to the SDK face: Llama + Qwen,
        // and they MUST stay OUT of the certified defaults (R1 honesty).
        let altIDs = MLXModelCatalog.availableAlternatives.map(\.id)
        XCTAssertEqual(altIDs, [
            "mlx-community/Llama-3.2-3B-Instruct-4bit",
            "mlx-community/Qwen2.5-3B-Instruct-4bit"
        ])
        let defaultIDs = Set(MLXModelCatalog.defaultEntries.map(\.id))
        for alt in MLXModelCatalog.availableAlternatives {
            XCTAssertFalse(
                defaultIDs.contains(alt.id),
                "\(alt.id) is an opt-in alternative — must NOT be a certified default")
        }
    }

    func testAllEntriesProviderIDsAreUniqueAcrossDefaultsAndAlternatives() {
        // providerID is the audit primary key — it must be collision-free across
        // the ENTIRE selectable set, not just within defaults.
        let providers = MLXModelCatalog.allEntries.map(\.providerID)
        XCTAssertEqual(
            Set(providers).count, providers.count,
            "providerIDs must be unique across defaults + alternatives")
        XCTAssertEqual(
            MLXModelCatalog.allEntries.count,
            MLXModelCatalog.defaultEntries.count
                + MLXModelCatalog.availableAlternatives.count,
            "allEntries = defaults + alternatives (no overlap, no drop)")
    }
}
