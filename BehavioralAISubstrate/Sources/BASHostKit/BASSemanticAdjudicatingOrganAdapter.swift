import Foundation
import BASOrgan
import BASSovereign

/// observe→DISPOSE (Line A) — the FRONTIER runtime wiring: a decorator that drives a live turn through the
/// full semantic pipeline (extract → SEMANTIC retrieve via `BASEmbeddingFactBank` → alias-aware verify →
/// verdict-instruction → wrapped organ). This is the async counterpart of `BASAdjudicatingOrganAdapter`
/// (which uses the sync substring `BASFactBank`); it swaps in the embedding bank so paraphrased questions
/// resolve instead of silently abstaining.
///
/// Default-OFF (`BAS_FACTUAL_ADJUDICATE`) + abstain-by-default: flag unset, no recognized assertion, or the
/// bank's cosine below its threshold ⇒ the request passes through to the inner organ UNCHANGED. The verdict
/// rides in the user-turn instruction (never `systemInstructions`); never mutates input; never touches the
/// sovereign byte-parity verdict.
///
/// ## Streaming (audit fix)
///
/// The decorator also conforms to `BASStreamingOrganAdapter` (see the extension below). The live chat loop
/// resolves an adapter and probes `as? BASStreamingOrganAdapter`; a decorator that only overrode `draft(_:)`
/// was TRANSPARENT to that probe, so the inner organ's `streamDraft` was reached directly and adjudication
/// was bypassed on the streaming path. With the conformance, the SAME adjudicated request (verdict prepended
/// BEFORE the inner generates) is what the inner's `streamDraft` consumes — closing the streaming bypass.
public final class BASSemanticAdjudicatingOrganAdapter: BASOrganAdapter {

    private let inner: BASOrganAdapter
    private let bank: BASEmbeddingFactBank
    private let extractAssertion: @Sendable (String) -> String?
    private let enabled: Bool
    /// NEUROMODULATION gate — engage/skip the expensive embed+retrieve per turn by `stakes × headroom` (NOT ε;
    /// ε is a compute throttle, backwards for a verify organ — see `BASAdjudicationGate`).
    /// Default `.always` ⇒ byte-equal with the pre-gate ON behavior.
    private let gate: BASAdjudicationGate
    /// OBSERVE lane — a per-turn record of the gate/adjudication outcome. Default `nil` ⇒ byte-equal no-op.
    private let observer: BASAdjudicationObserver?
    /// NLI gaslight-REDUCER probe (Phase 2). Default `nil` ⇒ alias-only verify (byte-equal). When set, a
    /// high-confidence entailment RESCUES an alias `.contradicts` to `.agrees` (a synonym/paraphrase the table
    /// missed); it NEVER manufactures a contradiction. See `BASNLIEntailmentProbe`.
    private let nliProbe: BASNLIEntailmentProbe?
    /// Minimum entailment confidence to rescue a contradiction. Conservative (0.9) — a weak entailment leaves
    /// the alias verdict untouched, preserving the false-abstain-over-false-affirm bias.
    private let nliThreshold: Float
    /// P1(c) 全面优化 (SYSTEM_EFFICIENCY_CAMPAIGN): when true, a covered-and-confident factual-belief turn
    /// (assertion recognized + bank resolves + verdict ≠ unknown after NLI reconcile) RETURNS the bank's
    /// verdict AS the draft — no LLM call at all. Off-corpus / abstain / gated turns pass through untouched.
    /// Default false = byte-equal (ADR-014). This is the propose/dispose frame made load-bearing: on the
    /// covered subset the deterministic adjudicator IS the answerer (P0 baseline: every avoided call
    /// ≈ −4 s wall / −99% of turn compute).
    private let shortCircuitCovered: Bool

    public init(
        wrapping inner: BASOrganAdapter,
        bank: BASEmbeddingFactBank,
        extractAssertion: @escaping @Sendable (String) -> String? = { BASBeliefAssertionParser.assertedValue(in: $0) },
        enabled: Bool = BASFactualAdjudicatorWiring.isEnabled(),
        gate: BASAdjudicationGate = .always,
        observer: BASAdjudicationObserver? = nil,
        nliProbe: BASNLIEntailmentProbe? = nil,
        nliThreshold: Float = 0.9,
        shortCircuitCovered: Bool = false
    ) {
        self.shortCircuitCovered = shortCircuitCovered
        self.inner = inner
        self.bank = bank
        self.extractAssertion = extractAssertion
        self.enabled = enabled
        self.gate = gate
        self.observer = observer
        self.nliProbe = nliProbe
        self.nliThreshold = nliThreshold
    }

    public var descriptor: BASOrganDescriptor { inner.descriptor }

    public func currentCapacity() async -> BASOrganCapacity { await inner.currentCapacity() }

    /// Pre-embed the bank (idempotent) so the first live turn doesn't pay the load cost. Optional.
    public func warmUp() async { await bank.load() }

    public func draft(_ request: BASOrganRequest) async throws -> BASOrganDraft {
        if let short = await shortCircuited(request) { return short }
        return try await inner.draft(await adjudicated(request))
    }

    /// observe→DISPOSE: stay transparent across the FULL adapter surface. The ACCELERATED overloads are
    /// protocol REQUIREMENTS (ADR-014, dynamic dispatch); inheriting their defaults would route a
    /// purpose-/elect-based caller through plain `draft(_:)` and silently DROP the inner's accelerated decode
    /// lane (MLX prompt-lookup / speculative) even when the verdict is injected. Override them to adjudicate
    /// FIRST, then delegate to the inner's own accelerated overload — so the verdict rides into whichever lane
    /// the inner picks. Default-OFF / abstain ⇒ `adjudicated` returns the request unchanged ⇒ byte-equal with
    /// the inner's accelerated path.
    public func draft(
        _ request: BASOrganRequest, electAccelerated: Bool
    ) async throws -> BASOrganDraft {
        if let short = await shortCircuited(request) { return short }
        return try await inner.draft(await adjudicated(request), electAccelerated: electAccelerated)
    }

    public func draft(
        _ request: BASOrganRequest, purpose: BASDecodeLanePolicy.Purpose
    ) async throws -> BASOrganDraft {
        if let short = await shortCircuited(request) { return short }
        return try await inner.draft(await adjudicated(request), purpose: purpose)
    }

    /// P1(c): the covered-and-confident short-circuit. Returns a deterministic draft when (and only when)
    /// the FULL adjudication chain lands on a definite verdict: opt-in flag + enabled + gate engages +
    /// assertion recognized + semantic bank resolves + (NLI-reconciled) verdict ∈ {agrees, contradicts}.
    /// Every other outcome returns nil — the request flows to the LLM exactly as before (same conservative
    /// false-abstain-over-false-affirm bias; the bank's cosine threshold IS the confidence gate).
    func shortCircuited(_ request: BASOrganRequest) async -> BASOrganDraft? {
        guard shortCircuitCovered, enabled else { return nil }
        guard await gate.shouldEngage(request) else { return nil }        // gate skip → normal path
        guard let asserted = extractAssertion(request.instruction) else { return nil }
        guard let resolved = await bank.resolve(question: request.instruction, assertedValue: asserted)
        else { return nil }
        let verdict = await reconciled(resolved.groundTruth, reference: resolved.reference, claim: asserted)
        let ref = resolved.reference.trimmingCharacters(in: .whitespacesAndNewlines)
        let body: String
        switch verdict {
        case .agrees:
            body = "Correct — \(ref)"
        case .contradicts:
            body = "That is not correct. \(ref)"
        case .unknown:
            return nil                                                    // never manufacture an answer
        }
        await observe(request, .shortCircuited)
        return BASOrganDraft(
            requestID: request.requestID,
            providerID: descriptor.providerID,
            role: request.role,
            body: body,
            inputTokensEstimated: BASOrganDeterministicAdapter
                .estimateTokens(from: [request.instruction] + request.context),
            outputTokensEstimated: BASOrganDeterministicAdapter.estimateTokens(from: [body]),
            producedAt: Date(),
            traceID: BASOrganDeterministicAdapter.digest(
                for: request, providerID: descriptor.providerID))
    }

    /// Enabled + gate engages + recognized assertion + semantic bank hit ⇒ a fresh request with the verdict
    /// prepended; otherwise `request` unchanged (default-OFF / gate-skip / no-claim / below-threshold all
    /// abstain). The NEUROMODULATION gate is consulted FIRST — before the cheap parse and the expensive
    /// embed/retrieve — so a skip is pure avoided-compute (`stakes × headroom`, biomimetic-brain-efficiency).
    func adjudicated(_ request: BASOrganRequest) async -> BASOrganRequest {
        guard enabled else { return request }
        guard await gate.shouldEngage(request) else {            // tier-skip ⇒ no parse, no embed
            await observe(request, .gateSkipped); return request
        }
        guard let asserted = extractAssertion(request.instruction) else {
            await observe(request, .noAssertion); return request
        }
        guard let resolved = await bank.resolve(question: request.instruction, assertedValue: asserted) else {
            await observe(request, .belowThreshold); return request
        }
        // NLI gaslight-REDUCER (Phase 2, conservative): rescue an alias `.contradicts` to `.agrees` ONLY when a
        // probe reports high-confidence entailment of the asserted VALUE by the reference (a synonym/paraphrase
        // the alias table missed). Never manufactures a contradiction; nil probe ⇒ alias verdict unchanged.
        let groundTruth = await reconciled(resolved.groundTruth, reference: resolved.reference, claim: asserted)
        await observe(request, .injected)
        return BASFactualAdjudicatorWiring.applyIfEnabled(
            to: request, groundTruth: groundTruth, reference: resolved.reference, enabled: true)
    }

    /// Apply the NLI gaslight-reducer to an alias verdict. Only `.contradicts` is eligible (the reducer can
    /// SOFTEN a correction, never create one); only a high-confidence entailment flips it. Any other case —
    /// no probe, non-contradiction, no NLI answer, or low confidence — returns `groundTruth` unchanged.
    func reconciled(
        _ groundTruth: BASFactualBeliefAdjudicator.GroundTruth, reference: String, claim: String
    ) async -> BASFactualBeliefAdjudicator.GroundTruth {
        guard groundTruth == .contradicts, let probe = nliProbe,
              let r = await probe(reference, claim), r.entails, r.confidence >= nliThreshold
        else { return groundTruth }
        return .agrees
    }

    /// Emit a per-turn OBSERVE record. No-op when no observer is wired (byte-equal). Never gates.
    private func observe(_ request: BASOrganRequest, _ outcome: BASAdjudicationObservationRecord.Outcome) async {
        await observer?(BASAdjudicationObservationRecord(
            requestID: request.requestID, role: request.role, outcome: outcome))
    }
}

// MARK: - Streaming (audit fix: close the streaming-path bypass)

/// observe→DISPOSE (Line A) — streaming refinement. The chat loop drives the live turn through
/// `streamDraft(_:)`, probing the resolved adapter `as? BASStreamingOrganAdapter`. By conforming here the
/// decorator surfaces to that probe (instead of being transparent), and the verdict is prepended into the
/// request BEFORE the inner organ's `streamDraft` runs.
///
/// - Default-OFF / abstain ⇒ `adjudicated(_:)` returns the request UNCHANGED, so the stream is a pure
///   pass-through of the inner organ's `streamDraft` (byte-equal with the un-wrapped path).
/// - FAIL-OPEN: if the inner organ does not itself stream, the verdict is STILL delivered — the wrapper
///   falls back to the inner's non-streaming `draft(_:)` and emits its body as one terminal chunk. The
///   decorator never blocks the live organ and never touches the sovereign byte-parity verdict.
extension BASSemanticAdjudicatingOrganAdapter: BASStreamingOrganAdapter {

    public func streamDraft(
        _ request: BASOrganRequest
    ) -> AsyncThrowingStream<BASOrganDraftChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // P1(c): a covered-and-confident short-circuit ends the stream with ONE terminal chunk —
                    // the LLM never runs (opt-in; nil → unchanged behavior).
                    if let short = await self.shortCircuited(request) {
                        continuation.yield(BASOrganDraftChunk(
                            requestID: short.requestID,
                            providerID: short.providerID,
                            role: short.role,
                            bodyDelta: short.body,
                            cumulativeBody: short.body,
                            producedAt: short.producedAt))
                        continuation.finish()
                        return
                    }
                    // Prepend the verdict (or pass through unchanged when disabled / abstaining) BEFORE the
                    // inner organ generates a single token.
                    let adjudicatedRequest = await self.adjudicated(request)
                    if let streamingInner = self.inner as? BASStreamingOrganAdapter {
                        for try await chunk in streamingInner.streamDraft(adjudicatedRequest) {
                            continuation.yield(chunk)
                        }
                    } else {
                        // FAIL-OPEN: inner can't stream → still deliver the adjudicated turn as one chunk.
                        let draft = try await self.inner.draft(adjudicatedRequest)
                        continuation.yield(BASOrganDraftChunk(
                            requestID: draft.requestID,
                            providerID: draft.providerID,
                            role: draft.role,
                            bodyDelta: draft.body,
                            cumulativeBody: draft.body,
                            producedAt: draft.producedAt))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
