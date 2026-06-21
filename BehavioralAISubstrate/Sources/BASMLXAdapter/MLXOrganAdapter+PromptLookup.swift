import Foundation
import BASRuntimeCore
import BASOrgan
#if canImport(MLXLLM)
import MLXLLM
import MLXLMCommon
#endif

/// Universal prompt-lookup speculative decode entry for `MLXOrganAdapter` (Track A). Runs the BAS-owned
/// `BASPromptLookupDecoder` (greedy, byte-identical, no draft model) and an apples-to-apples baseline (the SAME
/// decoder with a null drafter = pure single-model greedy), so the probe can compare TOKEN sequences directly
/// (true byte-identity) and timing (speedup) without detokenization fragility. Does NOT touch the production
/// decode path — the probe calls this directly. Observation-only (红线 7), MLX reasoning lane.
extension MLXOrganAdapter {

    /// Paired prompt-lookup vs single-model-greedy result for one prompt.
    public struct PromptLookupAB: Sendable {
        public let specTokens: [Int]
        public let specMs: Double
        public let baseTokens: [Int]
        public let baseMs: Double
        public let rounds: Int
        public let proposed: Int
        public let accepted: Int
    }

    /// A drafter that never proposes (ngram longer than any short generation) → the decoder degrades to pure
    /// single-model greedy, the byte-identity + timing baseline.
    static var nullDrafter: BASPromptLookupDrafter {
        BASPromptLookupDrafter(ngramMin: 100_000, ngramMax: 100_000, numDraftTokens: 1)
    }

    /// The byte-safety routing gate for the host-electable prompt-lookup production path (the MECHANISM end of
    /// the doctrine→mechanism contract; the DOCTRINE end is `BASDecodeLanePolicy.promptLookupEligible(for:)` in
    /// BASOrgan). Pure + framework-free + host-testable (no container) — mirrors `requestEligibleForSpeculation`.
    ///
    /// Prompt-lookup runs ONLY when the host elected it AND the request is ALREADY greedy (`temperature == 0`):
    /// prompt-lookup byte-identity is a GREEDY property — its argmax-equality accept is valid only at temp 0, so
    /// a scout (0.1) / core (0.7) request must NEVER be routed through it (that would change the output). The
    /// purpose→`elect` decision stays host-side so this adapter keeps NO BASOrgan-policy coupling (same split as
    /// `requestEligibleForSpeculation`, which keys on `temperature`, not on a BASOrgan enum).
    public nonisolated static func shouldUsePromptLookup(
        elect: Bool, request: BASOrganRequest
    ) -> Bool {
        elect && BASDecodeLanePolicy.isGreedyByteSafe(temperature: request.preset.temperature)
    }

    /// Generate the same prompt under prompt-lookup (spec) and the null-drafter baseline, in ONE container pass.
    public func promptLookupAB(
        for request: BASOrganRequest,
        drafter: BASPromptLookupDrafter,
        adaptiveK: Bool = true
    ) async throws -> PromptLookupAB {
        #if canImport(MLXLLM)
        guard let mainContainer = self._loadedContainerForStreaming() else {
            throw BASOrganError.providerUnavailable(
                reason: MLXOrganAdapter.notLoadedReason("loadModel(...) before promptLookupAB"))
        }
        // Build the LMInput exactly as the single-model path does (identical prompt tokenization).
        var messages: [Chat.Message] = []
        let instructions = Self.systemInstructions(for: request)
        if !instructions.isEmpty { messages.append(.system(instructions)) }
        messages.append(.user(Self.prompt(for: request)))
        let input = try await mainContainer.prepare(input: UserInput(chat: messages))
        let params = self._greedyParameters(
            for: request.preset, maxOutputTokens: request.maxOutputTokens)
        let null = Self.nullDrafter

        return try await mainContainer.perform(nonSendable: input) { ctx, input in
            let eos = Set([ctx.tokenizer.eosTokenId].compactMap { $0 })

            let sSpec = DispatchTime.now().uptimeNanoseconds
            let spec = try BASPromptLookupDecoder.generate(
                input: input, model: ctx.model, parameters: params, drafter: drafter, eosTokenIds: eos,
                adaptiveK: adaptiveK)
            let specMs = Double(DispatchTime.now().uptimeNanoseconds &- sSpec) / 1_000_000

            let sBase = DispatchTime.now().uptimeNanoseconds
            let base = try BASPromptLookupDecoder.generate(
                input: input, model: ctx.model, parameters: params, drafter: null, eosTokenIds: eos)
            let baseMs = Double(DispatchTime.now().uptimeNanoseconds &- sBase) / 1_000_000

            return PromptLookupAB(
                specTokens: spec.tokens, specMs: specMs,
                baseTokens: base.tokens, baseMs: baseMs,
                rounds: spec.rounds, proposed: spec.proposed, accepted: spec.accepted)
        }
        #else
        throw BASOrganError.providerUnavailable(
            reason: MLXOrganAdapter.frameworkUnavailableReason
                + MLXOrganAdapter.frameworkUnavailablePlatformSuffix)
        #endif
    }

    /// Host-electable PRODUCTION decode via the universal prompt-lookup speculative decoder (Track A).
    ///
    /// **ADR-014: DEFAULT-OFF.** Existing call sites are unchanged — a host opts a turn in by calling THIS method
    /// with `electPromptLookup = true` (typically `BASDecodeLanePolicy.promptLookupEligible(for: purpose)`,
    /// computed host-side so this adapter stays free of BASOrgan-policy coupling). Nothing routes here by default,
    /// so adopting it changes no bytes until a host elects a turn.
    ///
    /// **Fail-closed + byte-safe routing:** runs the prompt-lookup decoder ONLY when `shouldUsePromptLookup`
    /// holds (elected AND greedy, temp 0); every other case falls back to `draft(_:)`, byte-identical to today.
    /// On the prompt-lookup path the emitted tokens are TOKEN-identical to greedy single-model decode
    /// (`BASPromptLookupDecoder`'s construction; the device probe verified spec==baseline tokens 5/5), and the
    /// terminating EOS is excluded (the vendor's stop-before-EOS contract). The body is bulk-decoded via the
    /// vendor's canonical final-output convention `tokenizer.decode(tokenIds:)` (Evaluate.swift:1405); for
    /// identical tokens this yields the same text as the production path MODULO streaming-detokenizer boundary
    /// effects — TOKEN-identity is proven, exact TEXT byte-equality to the streamed body is NOT asserted.
    /// `completionMetrics` is honestly `nil` (the prompt-lookup loop emits no `GenerateCompletionInfo`).
    public func respondPromptLookup(
        for request: BASOrganRequest,
        electPromptLookup: Bool,
        drafter: BASPromptLookupDrafter = BASPromptLookupDrafter()
    ) async throws -> BASOrganDraft {
        guard descriptor.supportedRoles.contains(request.role) else {
            throw BASOrganError.unsupportedRole(request.role)
        }
        #if canImport(MLXLLM)
        // Fail-closed: not elected OR not greedy → the EXACT normal path (byte-equal, ADR-014).
        guard Self.shouldUsePromptLookup(elect: electPromptLookup, request: request) else {
            return try await draft(request)
        }
        // Tier-C3: funnel into the shared model-free decode + draft builder (this block was byte-for-byte the
        // same as _generateModelFree — same prepare/_greedyParameters/EOS-superset/BASPromptLookupDecoder.generate
        // /applyMarkerPostprocessing/BASOrganDraft). notLoadedHint preserves the EXACT original not-loaded error text.
        let g = try await _generateModelFree(
            for: request, drafter: drafter,
            notLoadedHint: "loadModel(...) before respondPromptLookup")
        return _modelFreeDraft(body: g.body, request: request)
        #else
        throw BASOrganError.providerUnavailable(
            reason: MLXOrganAdapter.frameworkUnavailableReason
                + MLXOrganAdapter.frameworkUnavailablePlatformSuffix)
        #endif
    }

    /// ADR-014 default-off accelerated draft (the `BASOrganAdapter` requirement). When a host elects an eligible
    /// (factual/deterministic) turn, decode via the model-free prompt-lookup lane — TOKEN-identical to `draft(_:)`
    /// under greedy, ~1.58x on repetitive output; every other case (not elected, or temp>0) fail-closes to
    /// `draft(_:)`, byte-equal. This is the production wire for `respondPromptLookup` (previously reachable only
    /// from probes); the eligibility decision stays host-side so this adapter keeps NO BASOrgan-policy coupling.
    /// CANONICAL accelerated draft entry (DecodePlan S5): the host passes the turn's PURPOSE and the single planner
    /// (`BASDecodeLanePolicy.decodeStrategy`) picks the lane (Option-3 auto-select). Output is byte-identical
    /// regardless of which lane runs — every lane emits the target's argmax (ADR-039) — so only latency/lane changes.
    ///
    /// `decodePlannerAutoSelect` is a runtime KILL-SWITCH: when off, fall back to the legacy prompt-lookup path
    /// (prompt-lookup iff the purpose is eligible), which is byte-equal to the pre-planner behavior.
    public func draft(_ request: BASOrganRequest, purpose: BASDecodeLanePolicy.Purpose) async throws -> BASOrganDraft {
        guard decodePlannerAutoSelect else {
            return try await respondPromptLookup(
                for: request, electPromptLookup: BASDecodeLanePolicy.promptLookupEligible(for: purpose))
        }
        #if canImport(MLXLLM)
        guard descriptor.supportedRoles.contains(request.role) else {
            throw BASOrganError.unsupportedRole(request.role)
        }
        let strategy = BASDecodeLanePolicy.decodeStrategy(
            purpose: purpose,
            temperature: request.preset.temperature,
            capabilities: _decodeCapabilities(),
            profiler: draftProfiler,
            numDraftTokens: numDraftTokens)
        return try await _execute(strategy, for: request)
        #else
        return try await respondPromptLookup(
            for: request, electPromptLookup: BASDecodeLanePolicy.promptLookupEligible(for: purpose))
        #endif
    }

    /// COMPATIBILITY elect-Bool entry — RETAINED, not deleted (production uses `draft(_:purpose:)`; this stays a
    /// thin shim for any remaining Bool callers). Shims to the purpose entry via the legacy eligibility mapping —
    /// byte-equal because `promptLookupEligible(_purposeForElect(e)) == e`.
    public func draft(_ request: BASOrganRequest, electAccelerated: Bool) async throws -> BASOrganDraft {
        try await draft(request, purpose: Self._purposeForElect(electAccelerated))
    }

    /// Elect→purpose shim mapping (used by the retained compatibility elect entry). `true` → `.factual` (eligible), `false` →
    /// `.scoutDefault` (not eligible), so it reproduces the legacy `promptLookupEligible` elect gate exactly.
    static func _purposeForElect(_ elect: Bool) -> BASDecodeLanePolicy.Purpose {
        elect ? .factual : .scoutDefault
    }

    #if canImport(MLXLLM)
    /// The decode lanes physically available right now, for the planner (keeps the planner pure / MLX-free).
    func _decodeCapabilities() -> BASDecodeCapabilities {
        BASDecodeCapabilities(
            draftModelLoaded: isSpeculationActive,                 // draftContainer loaded + mode != .off
            saguaroAvailable: false,                               // no injected CoreAI speculator on this entry
            modelFreeAvailable: _loadedContainerForStreaming() != nil)
    }
    #endif
}
