import Foundation
import BASOrgan

/// observe→DISPOSE (Line A) — the real-runtime wiring seam for the factual-belief adjudicator.
///
/// ## Why this exists
///
/// The audit found the adjudicator DORMANT in production: the only construction that routes an organ
/// through `BASLLMNeuralCoreService.adjudicating(_:)` is `makeDefault(...)`, which the live runtime does not
/// call — the real `BASHostRuntime` builds `BASHostRuntimeEBrainNeuralCoreService` (organ-ROUTING, no LLM
/// adapter) directly in `EBrainHostRuntimeSynthesis.swift`. So neither the non-streaming nor the streaming
/// draft path ever saw the verdict.
///
/// This extension gives the runtime a first-class, default-OFF construction site: a host wraps the live
/// organ adapter it is about to register (MLX / Apple FoundationModels / remote) with
/// `runtime.adjudicatingOrgan(organ)` BEFORE handing it to its `BASOrganRegistry` / organ endpoint. Because
/// the wrapper now conforms to `BASStreamingOrganAdapter`, the chat loop's `as? BASStreamingOrganAdapter`
/// probe resolves the wrapper and the verdict is prepended into the request BEFORE the inner `streamDraft`
/// runs — closing the streaming bypass on the live path.
///
/// ## Doctrine pins held
///
/// - ADR-014 OPT-IN / default-OFF byte-equal: `BAS_FACTUAL_ADJUDICATE` unset ⇒ returns `organ` UNCHANGED
///   (no wrapper, no allocation) so every existing host is byte-identical.
/// - FAIL-OPEN: a missing MiniLM provider / empty corpus ⇒ `organ` unchanged (never breaks the live organ).
/// - 单提交口 untouched: the verdict rides only in the user-turn `.instruction`; the sovereign byte-parity
///   verdict path is never read or perturbed here.
public extension BASHostRuntime {

    /// Route a live organ adapter through the factual-belief adjudicator wrap (default-OFF preserved).
    ///
    /// Hosts call this at the organ-registration seam, e.g.:
    /// ```swift
    /// let registry = BASOrganRegistry()
    /// await registry.register(runtime.adjudicatingOrgan(mlxAdapter))
    /// ```
    /// When `BAS_FACTUAL_ADJUDICATE=1` the returned adapter is a `BASSemanticAdjudicatingOrganAdapter`
    /// (which streams); otherwise it is exactly `organ` (byte-equal).
    ///
    /// - Parameters:
    ///   - organ: the live neural organ adapter the host is about to register.
    ///   - enabled: opt-in gate; defaults to the `BAS_FACTUAL_ADJUDICATE` env probe.
    ///   - gate: the NEUROMODULATION gate deciding, per turn, whether to pay the expensive verification by
    ///     `stakes × headroom` (NOT ε — ε is a compute throttle, backwards for a verify organ; see
    ///     `BASAdjudicationGate`). Defaults to the `BAS_ADJ_GATE`-derived gate (`.always` when unset). A host
    ///     holding a richer stakes signal injects `.when { req in … }`; `.thermalHeadroom()` / `.roles([.core])`
    ///     / `.stakesEstimated` work with no extra plumbing.
    /// - Returns: `organ` wrapped by the adjudicator when enabled+available, else `organ` unchanged.
    func adjudicatingOrgan(
        _ organ: any BASOrganAdapter,
        enabled: Bool = BASFactualAdjudicatorWiring.isEnabled(),
        gate: BASAdjudicationGate = BASAdjudicationGate.fromEnvironment(),
        observer: BASAdjudicationObserver? = BASAdjudicationObservation.defaultObserverIfEnabled()
    ) -> any BASOrganAdapter {
        BASLLMNeuralCoreService.adjudicating(organ, enabled: enabled, gate: gate, observer: observer)
    }
}
