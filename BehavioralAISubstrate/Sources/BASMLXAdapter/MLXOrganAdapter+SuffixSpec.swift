import Foundation
import BASRuntimeCore
import BASOrgan
#if canImport(MLXLLM)
import MLX
import MLXLLM
import MLXLMCommon
#endif

/// Universal Draft Layer — Phase 1 production entry: host-electable CROSS-TURN prompt-lookup. Drives the SAME
/// byte-identical `BASPromptLookupDecoder` loop as `respondPromptLookup`, but the draft SOURCE is a
/// `BASCrossTurnDrafter` seeded with the conversation's PRIOR-TURN tokens (kept in the actor's `crossTurnStore`).
/// So a later turn can reuse tokens from earlier turns — the cross-turn repetition of RAG / agentic / tool-loop
/// workloads — where single-sequence prompt-lookup sees nothing. Byte-identity is structural (the verifier only
/// emits the target's argmax); the cross-turn corpus only changes the acceptance rate.
extension MLXOrganAdapter {

    /// **ADR-014 DEFAULT-OFF + fail-closed + byte-safe**, exactly like `respondPromptLookup`: runs the cross-turn
    /// lane ONLY when the host elected it AND the request is greedy (`temperature == 0`); every other case falls
    /// back to `draft(_:)`, byte-equal to today. With an EMPTY prior corpus this is byte-identical to
    /// `respondPromptLookup` (the cross-turn automaton's `propose` is parity-proven equal to the linear drafter
    /// over the same tokens) — the regression anchor. After the turn, this turn's (prompt + generated) tokens are
    /// folded into the conversation corpus for the next turn's draft.
    public func respondCrossTurnLookup(
        for request: BASOrganRequest, electCrossTurn: Bool, sessionID: String,
        ngramMin: Int = 1, ngramMax: Int = 3, numDraftTokens: Int = 4
    ) async throws -> BASOrganDraft {
        guard descriptor.supportedRoles.contains(request.role) else {
            throw BASOrganError.unsupportedRole(request.role)
        }
        #if canImport(MLXLLM)
        // Fail-closed: not elected OR not greedy → the EXACT normal path (byte-equal, ADR-014).
        guard Self.shouldUsePromptLookup(elect: electCrossTurn, request: request) else {
            return try await draft(request)
        }
        let drafter = BASCrossTurnDrafter(
            priorTokens: crossTurnStore.tokens(session: sessionID),
            ngramMin: ngramMin, ngramMax: ngramMax, numDraftTokens: numDraftTokens)
        let g = try await _generateModelFree(for: request, drafter: drafter)
        // Carry THIS turn (prompt + generated) into the conversation corpus for the next turn's cross-turn draft.
        crossTurnStore.append(session: sessionID, contentsOf: g.promptTokens + g.genTokens)
        return _modelFreeDraft(body: g.body, request: request)
        #else
        throw BASOrganError.providerUnavailable(
            reason: MLXOrganAdapter.frameworkUnavailableReason
                + MLXOrganAdapter.frameworkUnavailablePlatformSuffix)
        #endif
    }

    /// Universal Draft Layer — the unified, ROUTER-DRIVEN entry. **Phase-1, host-electable, NOT yet wired into the
    /// default production path** (no caller today; the live accelerated path is `respondPromptLookup` via
    /// `draft(_:electAccelerated:)`). Measure-only until the device promotion gate passes — wiring a possibly-net-loss
    /// lane default-on is gated on that. Given the turn's `purpose`, the
    /// `BASDecodeLanePolicy.source(for:profiler:)` router picks the best NET-POSITIVE model-free source from the
    /// online `draftProfiler`: `.none` → plain `draft(_:)` (free-form / not worth speculating, @1×);
    /// `.promptLookup` → single-sequence n-gram; `.suffixAutomaton` → cross-turn. Each accelerated turn folds its
    /// acceptance telemetry back into `draftProfiler` so the router learns online. Fail-closed + byte-identical:
    /// any non-greedy preset (temp != 0) routes to `.none`/`draft(_:)`; tree-verify is never selected (a 亏).
    public func respondAccelerated(
        for request: BASOrganRequest, purpose: BASDecodeLanePolicy.Purpose, sessionID: String,
        ngramMin: Int = 1, ngramMax: Int = 3, numDraftTokens: Int = 4
    ) async throws -> BASOrganDraft {
        guard descriptor.supportedRoles.contains(request.role) else {
            throw BASOrganError.unsupportedRole(request.role)
        }
        #if canImport(MLXLLM)
        // Greedy-only byte-safety gate ∘ source router (pure + unit-pinned in BASDecodeLanePolicy.acceleratedChoice).
        let choice = BASDecodeLanePolicy.acceleratedChoice(
            temperature: request.preset.temperature, purpose: purpose, profiler: draftProfiler)
        switch choice {
        case .none:
            return try await draft(request)   // fallback @1×
        case .promptLookup:
            // Warm-start the draft width from the profiler's learned acceptance (cold → full `numDraftTokens`),
            // so a high-acceptance lane skips the decoder's cold adaptive-K ramp. Byte-safe (K is only a cap).
            let k = draftProfiler.recommendedK(
                sourceID: BASDraftSourceChoice.promptLookupID, purpose: purpose, cap: numDraftTokens)
            let drafter = BASPromptLookupDrafter(ngramMin: ngramMin, ngramMax: ngramMax, numDraftTokens: k)
            let g = try await _generateModelFree(for: request, drafter: drafter)
            // Fold telemetry keyed by the drafter's OWN sourceID (single source of truth — no inline literal drift).
            draftProfiler = draftProfiler.observing(
                sourceID: drafter.sourceID, purpose: purpose,
                accepted: g.accepted, proposed: g.proposed, rounds: g.rounds)
            return _modelFreeDraft(body: g.body, request: request)
        case .suffixAutomaton:
            let k = draftProfiler.recommendedK(
                sourceID: BASDraftSourceChoice.suffixAutomatonID, purpose: purpose, cap: numDraftTokens)
            let drafter = BASCrossTurnDrafter(
                priorTokens: crossTurnStore.tokens(session: sessionID),
                ngramMin: ngramMin, ngramMax: ngramMax, numDraftTokens: k)
            let g = try await _generateModelFree(for: request, drafter: drafter)
            // NOTE (deferred, latent): folds the full re-rendered prompt + gen. If a HOST carries growing chat
            // history in `request.context`, the re-rendered prompt re-contains prior turns → duplicate re-appends
            // + premature FIFO eviction of useful prior-turn tokens. Safe today (no production caller; AB uses
            // context:[]). When wired, the host should accumulate via sessionID, NOT re-send history in context;
            // a store-level synced cursor (mirroring BASCrossTurnDrafter.synced) is the eventual fix.
            crossTurnStore.append(session: sessionID, contentsOf: g.promptTokens + g.genTokens)
            draftProfiler = draftProfiler.observing(
                sourceID: drafter.sourceID, purpose: purpose,
                accepted: g.accepted, proposed: g.proposed, rounds: g.rounds)
            return _modelFreeDraft(body: g.body, request: request)
        }
        #else
        throw BASOrganError.providerUnavailable(
            reason: MLXOrganAdapter.frameworkUnavailableReason
                + MLXOrganAdapter.frameworkUnavailablePlatformSuffix)
        #endif
    }

    #if canImport(MLXLLM)
    /// The production decode STOP set — the tokenizer's `eosTokenId` plus the resolvable chat terminators (Llama-3
    /// `<|eot_id|>`/`<|end_of_text|>`, ChatML `<|im_end|>`, `</s>`). Shared by every model-free decode path so the
    /// stop rule stays identical across production + measure lanes. (Tier-C4 dedup of 3 byte-identical copies.)
    /// Takes the two capabilities (not the tokenizer) to avoid the cross-module `Tokenizer` type-name ambiguity.
    static func _productionEOSTokenIds(eosTokenId: Int?, resolve: (String) -> Int?) -> Set<Int> {
        var eos = Set([eosTokenId].compactMap { $0 })
        for name in ["<|eot_id|>", "<|end_of_text|>", "<|im_end|>", "</s>"] {
            if let id = resolve(name) { eos.insert(id) }
        }
        return eos
    }

    /// Shared decode: run a model-free source through the byte-identical `BASPromptLookupDecoder` loop in one
    /// container pass; return the postprocessed body + this turn's prompt/gen tokens + acceptance telemetry.
    // `internal` (not `private`) so the Tier-C3 funnel in MLXOrganAdapter+PromptLookup.swift (a different file)
    // can reuse this exact decode path. `notLoadedHint` lets each caller preserve its original not-loaded error text.
    func _generateModelFree(
        for request: BASOrganRequest, drafter: any BASUniversalDraftSource,
        notLoadedHint: String = "loadModel(...) before an accelerated draft"
    ) async throws -> (body: String, promptTokens: [Int], genTokens: [Int], accepted: Int, proposed: Int, rounds: Int) {
        guard let mainContainer = self._loadedContainerForStreaming() else {
            throw BASOrganError.providerUnavailable(
                reason: MLXOrganAdapter.notLoadedReason(notLoadedHint))
        }
        var messages: [Chat.Message] = []
        let instructions = Self.systemInstructions(for: request)
        if !instructions.isEmpty { messages.append(.system(instructions)) }
        messages.append(.user(Self.prompt(for: request)))
        let input = try await mainContainer.prepare(input: UserInput(chat: messages))
        let params = self._greedyParameters(for: request.preset, maxOutputTokens: request.maxOutputTokens)

        let raw: _GenRaw = try await mainContainer.perform(nonSendable: input) { ctx, input in
            // Production parity: stop on the model's chat terminators too (same superset as respondPromptLookup).
            let eos = Self._productionEOSTokenIds(
                eosTokenId: ctx.tokenizer.eosTokenId, resolve: { ctx.tokenizer.convertTokenToId($0) })
            let r = try BASPromptLookupDecoder.generate(
                input: input, model: ctx.model, parameters: params,
                drafter: drafter, eosTokenIds: eos, adaptiveK: true)
            return _GenRaw(
                body: ctx.tokenizer.decode(tokenIds: r.tokens), tokens: r.tokens,
                accepted: r.accepted, proposed: r.proposed, rounds: r.rounds,
                promptTokens: input.text.tokens.asArray(Int.self))
        }
        return (Self.applyMarkerPostprocessing(raw.body), raw.promptTokens, raw.tokens,
                raw.accepted, raw.proposed, raw.rounds)
    }

    /// Sendable payload carried out of the non-Sendable container closure.
    fileprivate struct _GenRaw: Sendable {
        let body: String; let tokens: [Int]
        let accepted: Int; let proposed: Int; let rounds: Int
        let promptTokens: [Int]
    }
    #endif

    /// Canonical `BASOrganDraft` builder — identical fields for EVERY decode lane (S1 dedup). `completionMetrics`
    /// is nil for the model-free loop (no `GenerateCompletionInfo`) and the captured metrics for the
    /// ChatSession/speculative paths. Replaces field-for-field copies in `draft(_:)`/`_draftSpeculative`/Saguaro.
    func _buildDraft(
        body: String, request: BASOrganRequest,
        completionMetrics: BASOrganCompletionMetrics? = nil
    ) -> BASOrganDraft {
        BASOrganDraft(
            requestID: request.requestID,
            providerID: descriptor.providerID,
            role: request.role,
            body: body,
            inputTokensEstimated: BASOrganDeterministicAdapter
                .estimateTokens(from: [request.instruction] + request.context),
            outputTokensEstimated: BASOrganDeterministicAdapter.estimateTokens(from: [body]),
            producedAt: Date(),
            traceID: BASOrganDeterministicAdapter.digest(
                for: request, providerID: descriptor.providerID),
            completionMetrics: completionMetrics)
    }

    /// Model-free accelerated turn draft (metrics nil — the prompt-lookup loop emits no `GenerateCompletionInfo`).
    func _modelFreeDraft(body: String, request: BASOrganRequest) -> BASOrganDraft {
        _buildDraft(body: body, request: request)
    }

    /// Per-turn cross-turn-spec vs single-model-greedy-baseline result (for the on-device probe).
    public struct CrossTurnAB: Sendable {
        public let turn: Int
        public let specTokens: [Int]
        public let specMs: Double
        public let baseTokens: [Int]
        public let baseMs: Double
        public let rounds: Int
        public let proposed: Int
        public let accepted: Int
    }

    /// Run a CONVERSATION (ordered turns) through the cross-turn lane vs the null-drafter baseline in one model
    /// pass, accumulating the cross-turn corpus across turns exactly as production would. Each turn compares spec
    /// (cross-turn drafter seeded with all PRIOR turns' tokens) vs baseline (same decoder, null drafter = pure
    /// single-model greedy) by TOKEN sequence (true byte-identity) + timing. The win shows up on LATER turns,
    /// where the draft reuses earlier turns' tokens (the cross-turn property single-sequence prompt-lookup lacks).
    public func crossTurnLookupAB(
        forTurns prompts: [String], role: BASOrganRole = .core,
        ngramMin: Int = 1, ngramMax: Int = 3, numDraftTokens: Int = 4, capacityPerSession: Int = 8192
    ) async throws -> [CrossTurnAB] {
        #if canImport(MLXLLM)
        // Local cross-turn corpus (probe-owned, not the adapter's) so the measurement is self-contained.
        var corpus = BASSuffixAutomaton(
            ngramMin: ngramMin, ngramMax: ngramMax, numDraftTokens: numDraftTokens, capacity: capacityPerSession)
        var results: [CrossTurnAB] = []
        for (i, p) in prompts.enumerated() {
            // Each turn runs in its OWN async scope (the helper) so the non-Sendable LMInput never crosses the
            // loop's actor-isolation region — the Swift-6-safe shape (mirrors the single-call production methods).
            let turn = try await _crossTurnTurnAB(
                index: i, prompt: p, role: role, priorTokens: corpus.currentTokens(),
                ngramMin: ngramMin, ngramMax: ngramMax, numDraftTokens: numDraftTokens,
                capacityPerSession: capacityPerSession)
            results.append(turn.ab)
            corpus.append(contentsOf: turn.append)   // prompt + the model's own greedy gen → next turn's prior
        }
        return results
        #else
        throw BASOrganError.providerUnavailable(
            reason: MLXOrganAdapter.frameworkUnavailableReason
                + MLXOrganAdapter.frameworkUnavailablePlatformSuffix)
        #endif
    }

    #if canImport(MLXLLM)
    /// One turn of the cross-turn AB: spec (cross-turn drafter seeded with `priorTokens`) vs null-drafter baseline
    /// in one container pass. Returns the per-turn measurement + the tokens to fold into the corpus for the next
    /// turn (this turn's prompt + the baseline greedy generation). Own scope = no cross-iteration isolation race.
    private func _crossTurnTurnAB(
        index: Int, prompt: String, role: BASOrganRole, priorTokens: [Int],
        ngramMin: Int, ngramMax: Int, numDraftTokens: Int, capacityPerSession: Int
    ) async throws -> (ab: CrossTurnAB, append: [Int]) {
        guard let mainContainer = self._loadedContainerForStreaming() else {
            throw BASOrganError.providerUnavailable(
                reason: MLXOrganAdapter.notLoadedReason("loadModel(...) before crossTurnLookupAB"))
        }
        let request = BASOrganRequest(
            requestID: "ct-\(index)", role: role, preset: .greedyDeterministic, instruction: prompt, context: [])
        var messages: [Chat.Message] = []
        let instructions = Self.systemInstructions(for: request)
        if !instructions.isEmpty { messages.append(.system(instructions)) }
        messages.append(.user(Self.prompt(for: request)))
        let input = try await mainContainer.prepare(input: UserInput(chat: messages))
        let params = self._greedyParameters(for: request.preset, maxOutputTokens: request.maxOutputTokens)
        let null = Self.nullDrafter
        let specDrafter = BASCrossTurnDrafter(
            priorTokens: priorTokens, ngramMin: ngramMin, ngramMax: ngramMax,
            numDraftTokens: numDraftTokens, capacityPerSession: capacityPerSession)

        let raw: _TurnRaw = try await mainContainer.perform(nonSendable: input) { ctx, input in
            // Stop EXACTLY as production (`_generateModelFree`) does — the chat-terminator superset, not just
            // eosTokenId — so the promotion-gate speedup is measured under the same stop rule that ships.
            let eos = Self._productionEOSTokenIds(
                eosTokenId: ctx.tokenizer.eosTokenId, resolve: { ctx.tokenizer.convertTokenToId($0) })
            let s0 = DispatchTime.now().uptimeNanoseconds
            let spec = try BASPromptLookupDecoder.generate(
                input: input, model: ctx.model, parameters: params,
                drafter: specDrafter, eosTokenIds: eos, adaptiveK: true)
            let sMs = Double(DispatchTime.now().uptimeNanoseconds &- s0) / 1_000_000
            let b0 = DispatchTime.now().uptimeNanoseconds
            let base = try BASPromptLookupDecoder.generate(
                input: input, model: ctx.model, parameters: params, drafter: null, eosTokenIds: eos)
            let bMs = Double(DispatchTime.now().uptimeNanoseconds &- b0) / 1_000_000
            return _TurnRaw(
                spec: spec.tokens, specMs: sMs, base: base.tokens, baseMs: bMs,
                rounds: spec.rounds, proposed: spec.proposed, accepted: spec.accepted,
                promptTokens: input.text.tokens.asArray(Int.self))
        }
        let ab = CrossTurnAB(
            turn: index, specTokens: raw.spec, specMs: raw.specMs, baseTokens: raw.base, baseMs: raw.baseMs,
            rounds: raw.rounds, proposed: raw.proposed, accepted: raw.accepted)
        return (ab, raw.promptTokens + raw.base)
    }

    /// Sendable payload carried out of the non-Sendable container closure.
    fileprivate struct _TurnRaw: Sendable {
        let spec: [Int]; let specMs: Double
        let base: [Int]; let baseMs: Double
        let rounds: Int; let proposed: Int; let accepted: Int
        let promptTokens: [Int]
    }
    #endif

    /// DIAGNOSTIC: measure whether a K-token multi-token verify forward equals a single-token forward at the SAME
    /// committed position on the window-masked cache. Pins the byte_identical<8/8 residual: a SMALL max_logit_diff
    /// (~1e-3) ⇒ bf16 reduction-order ULP (fp32 verify-lane attention would fix it); a LARGE diff ⇒ a systematic
    /// Gemma multi-vs-single forward difference (fp32 would NOT help). Run at a short offset and a >window offset.
    public func windowForwardDiag(prompt: String, draftLen: Int = 4, role: BASOrganRole = .core) async throws -> String {
        #if canImport(MLXLLM)
        guard let mainContainer = self._loadedContainerForStreaming() else {
            throw BASOrganError.providerUnavailable(
                reason: MLXOrganAdapter.notLoadedReason("loadModel(...) before windowForwardDiag"))
        }
        let request = BASOrganRequest(
            requestID: "fwddiag", role: role, preset: .greedyDeterministic, instruction: prompt, context: [])
        var messages: [Chat.Message] = []
        let instructions = Self.systemInstructions(for: request)
        if !instructions.isEmpty { messages.append(.system(instructions)) }
        messages.append(.user(Self.prompt(for: request)))
        let input = try await mainContainer.prepare(input: UserInput(chat: messages))
        let params = self._greedyParameters(for: request.preset, maxOutputTokens: request.maxOutputTokens)
        let dLen = draftLen
        return try await mainContainer.perform(nonSendable: input) { ctx, input in
            let cache = BASWindowMaskedCache.verifyCache(for: ctx.model, parameters: params)
            let sampler = params.sampler()
            var firstTok: Int32 = 0
            var state0: LMOutput.State? = nil
            switch try ctx.model.prepare(input, cache: cache, windowSize: params.prefillStepSize) {
            case .tokens(let toks):
                firstTok = toks.tokens.asArray(Int32.self).last ?? 0
            case .logits(let result):
                let tok = sampler.sample(logits: result.logits[0..., -1, 0...])
                eval(tok)
                firstTok = tok.item(Int32.self)
                state0 = result.state
            }
            let offsetAtCompare = cache.first?.offset ?? 0
            // Snapshot the post-prefill cache so both forwards start from the identical state.
            let snap = cache.map { ($0.state, $0.metaState) }
            // (A) single-token forward of `firstTok` → logits for the next position.
            let rA = ctx.model(LMInput.Text(tokens: MLXArray([firstTok]))[text: .newAxis], cache: cache, state: state0)
            let logitsA = rA.logits[0..., -1, 0...].asArray(Float.self)
            // Restore, then (B) multi-token forward of [firstTok, draft×dLen] → logits at position 0 (== after firstTok).
            for i in cache.indices {
                var c = cache[i]
                c.state = snap[i].0
                c.metaState = snap[i].1
            }
            let multi = concatenated([MLXArray([firstTok]), MLXArray(Array(repeating: firstTok, count: dLen))])
            let rB = ctx.model(LMInput.Text(tokens: multi)[text: .newAxis], cache: cache, state: state0)
            let logitsB0 = rB.logits[0..., 0, 0...].asArray(Float.self)
            let n = Swift.min(logitsA.count, logitsB0.count)
            var maxDiff: Float = 0
            for i in 0..<n { maxDiff = Swift.max(maxDiff, abs(logitsA[i] - logitsB0[i])) }
            func argmax(_ a: ArraySlice<Float>) -> Int {
                var bi = a.startIndex; var bv = -Float.infinity
                for i in a.indices where a[i] > bv { bv = a[i]; bi = i }
                return bi - a.startIndex
            }
            let agree = argmax(logitsA[0..<n]) == argmax(logitsB0[0..<n])
            return String(
                format: "fwddiag offset=%d draftLen=%d vocab=%d max_logit_diff=%.5f argmax_agree=%@",
                offsetAtCompare, dLen, n, maxDiff, agree ? "YES" : "NO")
        }
        #else
        throw BASOrganError.providerUnavailable(reason: MLXOrganAdapter.frameworkUnavailableReason)
        #endif
    }

    /// Wall-ms of `forwards` single-token GPU forwards of the loaded target (each reads the full weights — the
    /// memory-bandwidth unit the ρ probe needs). Uses BASWindowMaskedCache so it works on SLIDING-WINDOW models
    /// (Gemma E4B) where `saguaroTargetForwardsMs`'s BASSaguaroMLXTarget fail-closes on the non-trimmable
    /// RotatingKVCache (`nonTrimmableCache`). No accept/trim — just N forwards; result = the GPU verify timing for ρ.
    public func rawTargetForwardsMs(for request: BASOrganRequest, forwards: Int) async throws -> Double {
        #if canImport(MLXLLM)
        guard let mainContainer = self._loadedContainerForStreaming() else {
            throw BASOrganError.providerUnavailable(
                reason: MLXOrganAdapter.notLoadedReason("loadModel(...) before rawTargetForwardsMs"))
        }
        var messages: [Chat.Message] = []
        let instructions = Self.systemInstructions(for: request)
        if !instructions.isEmpty { messages.append(.system(instructions)) }
        messages.append(.user(Self.prompt(for: request)))
        let input = try await mainContainer.prepare(input: UserInput(chat: messages))
        let params = self._greedyParameters(for: request.preset, maxOutputTokens: request.maxOutputTokens)
        return try await mainContainer.perform(nonSendable: input) { ctx, input in
            let cache = BASWindowMaskedCache.verifyCache(for: ctx.model, parameters: params)
            let sampler = params.sampler()
            var y: LMInput.Text
            var state: LMOutput.State? = nil
            switch try ctx.model.prepare(input, cache: cache, windowSize: params.prefillStepSize) {
            case .tokens(let toks):
                y = toks
            case .logits(let result):
                let tok = sampler.sample(logits: result.logits[0..., -1, 0...])
                eval(tok); y = .init(tokens: tok); state = result.state
            }
            let t0 = DispatchTime.now().uptimeNanoseconds
            var i = 0
            while i < forwards {
                let r = ctx.model(y[text: .newAxis], cache: cache, state: state)
                state = r.state
                let tok = sampler.sample(logits: r.logits[0..., -1, 0...])
                eval(tok)
                y = .init(tokens: tok)
                i += 1
            }
            return Double(DispatchTime.now().uptimeNanoseconds &- t0) / 1_000_000
        }
        #else
        throw BASOrganError.providerUnavailable(reason: MLXOrganAdapter.frameworkUnavailableReason)
        #endif
    }
}
