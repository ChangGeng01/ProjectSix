import Foundation
import BASOrgan
import BASAppleAdapters
import BASHostKit   // observe→DISPOSE: BASLLMNeuralCoreService.adjudicating (default-OFF factual-belief wrap)
import QinaoLoop

/// M180 — public factory for the most common Qinao + Apple
/// FoundationModels host configuration.
///
/// ## Why this exists
///
/// Pre-M180 a host that wanted to drive `QinaoLoop.generateCandidates`
/// with Apple's on-device LLM had to write ~25 lines of glue:
///
/// 1. Construct `BASOrganRegistry` (substrate type)
/// 2. Register `AppleFoundationOrganAdapter()` (substrate type)
/// 3. Implement a custom `QinaoOrganEndpoint` conformance that
///    walks the registry, translates `QinaoLoop.OrganRole` ↔
///    `BASOrganRole`, calls `adapter.draft(...)`, and translates
///    the resulting `BASOrganDraft` back into a `QinaoLoop.OrganResponse`
///
/// `BASOrganRegistryEndpoint` already does all of step 3 inside
/// QinaoLoop, but it's `package`-scoped (so substrate type names
/// don't leak into the public API). Hosts couldn't use it directly.
/// Result: every host with the same need duplicated the same wrapper.
///
/// `QinaoAppleFoundation` is a thin separate library that lifts the
/// wrapper to a one-call factory. The factory's signature is
/// substrate-free (`async -> any QinaoOrganEndpoint`); BAS types
/// appear only inside the function body, so the redaction scanner
/// stays clean.
///
/// ## Why a separate library
///
/// Hosts that don't want Apple-specific code don't import this
/// target — `QinaoLoop` keeps its production graph free of
/// `BASAppleAdapters` (and transitively `FoundationModels`).
/// Hosts wanting Apple LLM add one line:
///
/// ```swift
/// import QinaoAppleFoundation
/// let endpoint = await QinaoLoop.makeAppleFoundationEndpoint()
/// let loop = QinaoLoop(organEndpoint: endpoint)
/// ```
///
/// ## Behavior under unavailability
///
/// On macOS 26+ / iOS 26+ / visionOS 26+ with Apple Intelligence
/// reachable: real `LanguageModelSession.respond(to:)` drives every
/// `produceBody(...)` call.
///
/// On older OS / hardware / Apple Intelligence disabled:
/// `AppleFoundationOrganAdapter.draft(_:)` throws
/// `BASOrganError.providerUnavailable`. The endpoint translates this
/// to `QinaoLoop.LoopError.organUnavailable(reason:)` so callers can
/// surface a typed refusal.
///
/// ## ⚠️ `includeDeterministicFallback` IS A NO-OP TODAY (verified 2026-07-14)
///
/// It registers a `BASOrganDeterministicAdapter`, but that adapter is
/// UNREACHABLE on every host, so nothing ever "falls back". Three verified
/// links, each sufficient on its own:
///
///  1. `BASOrganRegistry.adapter(providerID:)` performs exact lookup and never
///     retries another provider on failure. It never calls `currentCapacity()`.
///  2. This factory binds the wrapped Apple organ's descriptor ID explicitly;
///     registration order cannot redirect it to the deterministic adapter.
///  3. The wrapped Apple adapter forwards that same descriptor identity even on
///     hosts where `draft(_:)` throws.
///
/// So on an unavailable Apple FM this endpoint THROWS; it does not degrade.
/// The prior text here ("silently falls back to the deterministic adapter on an
/// unavailable Apple FM") was false, and so is the claim that this is "useful
/// for offline development".
///
/// Making it real needs a router, and that is DEFERRED on a hard blocker:
/// `BASRoutingOrganAdapter` does not conform to `BASStreamingOrganAdapter`
/// (BASOrgan/BASRoutingOrganAdapter.swift:68, admitted at :57-59), while
/// `BASOrganRegistryEndpoint` resolves streaming via `as? BASStreamingOrganAdapter`
/// with no `draft()` degrade (QinaoLoop/BASOrganRegistryEndpoint.swift:116-125).
/// Wrapping the organ in the router today would silently convert working
/// streaming into `organUnavailable(reason: "endpoint-not-streaming")`. The
/// router is also INERT until `AppleFoundationOrganAdapter` maps raw
/// FoundationModels errors to `BASOrganError` — it fails over only on
/// `.providerUnavailable` / `.pressureRefusal` (BASRoutingOrganAdapter.swift:161-164).
///
/// TRIGGER to revisit: `BASRoutingOrganAdapter` gains streaming conformance
/// (the M255-followup named at BASRoutingOrganAdapter.swift:57-59) AND the
/// adapter's error mapping lands. Until then this parameter is kept only for
/// source compatibility — prefer leaving it `false`.
public extension QinaoLoop {

    /// One-call factory wiring Apple FoundationModels behind a
    /// `QinaoOrganEndpoint`. See file-level doc for full behavior.
    ///
    /// - Parameter includeDeterministicFallback: ⚠️ NO-OP — see the file-level
    ///   doc. It registers `BASOrganDeterministicAdapter`, but the endpoint binds
    ///   the Apple organ's provider ID explicitly, so an
    ///   unavailable Apple FM still THROWS rather than falling through. Kept for
    ///   source compatibility; leave `false`.
    /// - Returns: an opaque endpoint hosts pass to
    ///   `QinaoLoop.init(organEndpoint:)`.
    static func makeAppleFoundationEndpoint(
        includeDeterministicFallback: Bool = false
    ) async -> any QinaoOrganEndpoint {
        let registry = BASOrganRegistry()
        if includeDeterministicFallback {
            // NO-OP in practice: the endpoint below explicitly binds the Apple
            // organ's provider ID, so this one is never selected. Retained for
            // source compatibility until a streaming-capable router exists.
            await registry.register(BASOrganDeterministicAdapter())
        }
        // observe→DISPOSE (Line A): route the live Apple FM organ through the factual-belief adjudicator.
        // Default-OFF (`BAS_FACTUAL_ADJUDICATE` unset) ⇒ returns the adapter byte-equal; ON ⇒ the
        // streaming-capable wrapper, so the chat loop's `as? BASStreamingOrganAdapter` probe resolves it and
        // the verdict reaches `streamDraft`. The wrapper forwards `descriptor`, preserving the exact provider
        // identity bound by the endpoint below. FAIL-OPEN:
        // missing provider/corpus ⇒ the adapter is returned unchanged.
        let organ = BASLLMNeuralCoreService.adjudicating(
            AppleFoundationOrganAdapter(),
            // charter audit 2026-07-12 T4: the embedder is constructed HERE (LLM-side
            // module) and injected — BASHostKit no longer builds the concrete MiniLM.
            embeddingProvider: BASMiniLMEmbeddingProvider())
        // Pre-embed the fact bank so the first ON turn doesn't stall before the first token (no-op when OFF).
        await BASLLMNeuralCoreService.prewarmAdjudicator(organ)
        await registry.register(organ)
        return BASOrganRegistryEndpoint(
            registry: registry,
            providerID: organ.descriptor.providerID)
    }
}
