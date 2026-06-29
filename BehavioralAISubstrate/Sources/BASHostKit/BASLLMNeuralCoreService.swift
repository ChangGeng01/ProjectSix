// MARK: - BASLLMNeuralCoreService — chapter 四百一 / M933
//
// Phase A step 6 of the LLM Extraction Engine MVP per user
// vision §18: typed production-wire entry point that hosts use
// to invoke the M932 engine inside their own session-loop。
//
// ## Why a NEW typed protocol vs. replacing BASNeuralCoreServicing
//
// Pre-M933 design considered making this a `BASNeuralCoreServicing`
// conformer that REPLACES the existing stub at
// `BASEBrainRuntimeCoordinator.neuralCoreService`。But:
//
//   - The existing protocol is SYNC (`func synthesize(...) ->
//     BASNeuralCoreFrame`)。M932 engine is async (calls LLM
//     adapter)。Bridging async→sync would require Task+
//     semaphore — blocks the calling thread and is an
//     anti-pattern in Swift 6 strict concurrency。
//   - The existing protocol's `BASNeuralCoreFrame` is about
//     ORGAN ROUTING (which AFM tier to use, what tissue state),
//     NOT about LLM call RESULTS (text answer + 9 byproducts)。
//     Conflating these is a doctrine violation (chapter 二百一一
//     single-source-of-truth — distinct concerns get distinct
//     types)。
//
// Post-M933 design: ship a NEW typed protocol
// `BASLLMNeuralCoreServicing` parallel to (not replacing) the
// existing one, plus a concrete `BASLLMNeuralCoreService`
// struct that wraps M932 engine。Hosts opt in by calling the
// new service FROM their `BASEBrainRuntimeCoordinator.neuralCore
// Service` implementation (or directly from their session loop)。
//
// This approach:
//   - Preserves the existing protocol's contract (no break for
//     M72 BASHostRuntimeEBrainNeuralCoreService consumers)
//   - Stays async-native (no thread-blocking bridge)
//   - Surfaces the 9-byproduct typed result for downstream
//     pipelines (M903 corpus, M917 training, etc.)
//   - ADR-014 OPT-IN doctrine — hosts that don't need LLM
//     execution use the existing stub unchanged
//
// ## Doctrine pins held
//
// - 不变量 #1/#2/#3 — service is observation through extraction
// - 红线 7 hint-only — service returns HINTS, gate at L11
//   still decides
// - 单提交口 (L11/L14) 不变 — service doesn't bypass L11
// - chapter 二百一一 single-source-of-truth — ONE typed
//   service for LLM execution, parallel to organ-routing
//   service (no conflation)
// - chapter 一百八十五 anti-magic-number — typed defaults
// - chapter 三百四七 (M834) bundle-lifecycle — service owns
//   engine ref for its lifetime
// - ADR-014 OPT-IN — hosts opt in;default `runTurn()` stub
//   unchanged

import Foundation
import BASOrgan
import BASRuntimeCore
import BASAppleAdapters   // observe→DISPOSE: BASMiniLMEmbeddingProvider for the on-device semantic adjudicator

// MARK: - Servicing protocol

/// Typed protocol for the LLM-execution slot in a host's
/// turn loop。Parallel to `BASNeuralCoreServicing` (which
/// is organ-routing-class, sync) — this protocol is async
/// because invoking an LLM is async-by-nature。
public protocol BASLLMNeuralCoreServicing: Sendable {
    /// Run one LLM call through the engine。Returns the
    /// typed extraction result with 9 byproducts。
    func executeLLMTurn(
        rawInput: BASLLMRawInput,
        context: BASLLMCompilerContext,
        toolHints: [BASTool],
        outputSchema: BASGuidedGenerationSchema?
    ) async throws -> BASLLMExtractionResult
}

// MARK: - Concrete service

/// Concrete `BASLLMNeuralCoreServicing` conformer wrapping
/// the M932 `BASLLMExtractionEngine`。Hosts construct one
/// per session (engine is an actor;the service is
/// Sendable struct holding the actor ref)。
public struct BASLLMNeuralCoreService:
    BASLLMNeuralCoreServicing
{
    private let engine: BASLLMExtractionEngine

    public init(engine: BASLLMExtractionEngine) {
        self.engine = engine
    }

    public func executeLLMTurn(
        rawInput: BASLLMRawInput,
        context: BASLLMCompilerContext = .empty,
        toolHints: [BASTool] = [],
        outputSchema: BASGuidedGenerationSchema? = nil
    ) async throws -> BASLLMExtractionResult {
        try await engine.run(
            input: rawInput,
            context: context,
            toolHints: toolHints,
            outputSchema: outputSchema)
    }
}

// MARK: - Convenience factory

extension BASLLMNeuralCoreService {

    /// Convenience factory for hosts that want a default
    /// engine wired around just an adapter + event log。
    /// Equivalent to:
    ///
    ///   let engine = BASLLMExtractionEngine(
    ///       adapter: adapter,
    ///       eventLog: eventLog)
    ///   let service = BASLLMNeuralCoreService(
    ///       engine: engine)
    public static func makeDefault(
        adapter: any BASOrganAdapter,
        eventLog: any BASEventLogStorage,
        contractInstall: BASLLMContractInstall? = .observeOnly(purpose: .decompose)
    ) -> BASLLMNeuralCoreService {
        // ADR-031 §4 step 1 (opt-in / byte-equal-off): when an install is supplied, every LLM call
        // through this engine is contracted (fail-closed) + traced; nil → adapter used unwrapped,
        // identical to before (no behavior change).
        let contracted: any BASOrganAdapter = contractInstall?.wrap(adapter) ?? adapter
        // observe→DISPOSE: opt-in (BAS_FACTUAL_ADJUDICATE) — wrap the live organ with the semantic
        // factual-belief adjudicator. This is the runtime construction site the audit found MISSING (the
        // adjudicator was DORMANT — built only in Tests/). Default-OFF ⇒ `contracted` unchanged.
        let effectiveAdapter = Self.adjudicating(contracted)
        return BASLLMNeuralCoreService(
            engine: BASLLMExtractionEngine(
                adapter: effectiveAdapter,
                eventLog: eventLog))
    }

    /// When `BAS_FACTUAL_ADJUDICATE=1`, wrap the live organ with the semantic adjudicator (bundled corpus +
    /// on-device MiniLM). Default-OFF ⇒ returns `inner` byte-equal. FAIL-OPEN: missing provider/corpus ⇒
    /// `inner` (the dispose path never breaks the live organ). Only injects a verdict on a covered, confident
    /// factual-belief turn — otherwise the request passes through untouched.
    ///
    /// `public` so the real runtime / a live host can route its organ adapter through the wrap at the
    /// adapter-registration seam (see `BASHostRuntime.adjudicatingOrgan(_:)`), not just the in-package
    /// `makeDefault(...)` extraction path. The returned wrapper conforms to `BASStreamingOrganAdapter`, so the
    /// chat loop's `as? BASStreamingOrganAdapter` probe resolves it and the verdict reaches `streamDraft`.
    public static func adjudicating(
        _ inner: any BASOrganAdapter,
        enabled: Bool = BASFactualAdjudicatorWiring.isEnabled(),
        gate: BASAdjudicationGate = BASAdjudicationGate.fromEnvironment(),
        observer: BASAdjudicationObserver? = BASAdjudicationObservation.defaultObserverIfEnabled(),
        nliProbe: BASNLIEntailmentProbe? = nil
    ) -> any BASOrganAdapter {
        guard enabled else { return inner }
        let facts = BASBundledFactCorpus.load()
        guard !facts.isEmpty, let provider = BASMiniLMEmbeddingProvider() else { return inner }
        let bank = BASEmbeddingFactBank(facts: facts, provider: provider)
        // NEUROMODULATION: the gate (default `.always`, or `BAS_ADJ_GATE`-derived) decides per turn whether to
        // pay the embed/retrieve — so the adjudicator is a tier engaged by stakes × headroom (NOT ε), not always-on.
        // OBSERVE: the observer (default `BAS_ADJ_OBSERVE`-gated os_log, else nil) records the per-turn outcome
        // so an operator can MEASURE skip/inject/abstain rates and tune the gate. Both default to byte-equal.
        // NLI: an optional gaslight-reducer probe (default nil ⇒ alias-only). The device-only CoreAI verifier is
        // supplied by the edge (host/endpoint) so the 82–313 MB asset never weighs down hosts that don't want
        // the synonym tail — see `BASNLIEntailmentProbe`.
        return BASSemanticAdjudicatingOrganAdapter(
            wrapping: inner, bank: bank, enabled: true, gate: gate, observer: observer, nliProbe: nliProbe)
    }

    /// Pre-embed the adjudicator's fact bank (idempotent) so the FIRST live ON turn doesn't pay the corpus
    /// load cost synchronously before the first token. NO-OP when `adapter` is not the adjudicator wrapper —
    /// i.e. default-OFF, where `adjudicating(_:)` returned the bare organ and this downcast simply fails (so
    /// the OFF path stays byte-equal: O(1) failed downcast, no embed, no allocation). Hosts call this once at
    /// endpoint construction, right after `adjudicating(_:)`, before registering the organ.
    public static func prewarmAdjudicator(_ adapter: any BASOrganAdapter) async {
        await (adapter as? BASSemanticAdjudicatingOrganAdapter)?.warmUp()
    }
}
