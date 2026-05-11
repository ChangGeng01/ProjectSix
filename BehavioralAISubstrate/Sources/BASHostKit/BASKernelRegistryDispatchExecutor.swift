// MARK: - BASKernelRegistryDispatchExecutor
// chapter 四百七十四 / M1273 — POST-PHASE-3 hot-path attack
//
// Real hot-path attack 第二刀 — closes the "MPSGraph kernels
// shipped but no production caller" gap that the chapter
// 四百七十三 deep-review scored 4/10 (kernels exist but
// nobody dispatches through them)。
//
// ## Why this exists (system entropy framing)
//
// `BASMetalKernelRegistry` (M1098) ships an actor-owned
// dispatch table with MPSGraph kernels registered for
// matMul / RMSNorm / rotaryEmbedding / attention (chapter
// 四百四十七+)。 `BASStageAcceleratorAssignment` carries a
// `selectedKernelKey: BASKernelKey?` field (M1102)。
// `BASNativeStageExecutor.executePlanWithAssignments` (M1121)
// already routes through caller-provided closures with the
// assignment as input。
//
// The MISSING glue:a factory that takes a registry +
// fallback closure + caller-provided input builder and
// returns a `BASNativeStageExecutor.RoutedStageExecutor`
// closure that:
//   - Inspects `assignment.selectedKernelKey`
//   - When non-nil + kernel found in registry:invokes
//     caller's input builder + dispatches through
//     `registry.dispatch(key:inputs:)` + returns the
//     `BASKernelDispatchResult` directly
//   - When kernel key is nil OR not in registry OR input
//     builder returns nil:falls through to the caller's
//     fallback closure
//
// This is the FIRST surface in the substrate that
// connects `BASMetalKernelRegistry` to plan-stage
// execution。 Before M1273 the registry was a dead end
// (callers could register but nobody dispatched)。
//
// ## What this ships (M1273)
//
//   - `BASKernelRegistryDispatchExecutor.makeRoutedExecutor(
//       registry:inputBuilder:fallback:)` static factory
//     returning a `BASNativeStageExecutor.RoutedStageExecutor`
//   - `BASKernelRegistryDispatchExecutor.InputBuilder`
//     typealias for the input builder closure
//   - Diagnostic outcomes via `BASKernelRegistryDispatchOutcome`
//     enum (4 cases: dispatched / fallback-no-key /
//     fallback-no-kernel / fallback-no-inputs)
//
// ## Determinism / replay
//
// The factory is pure dispatch — same registry contents +
// same assignment + same input builder → same dispatch
// path。 Kernel-internal nondeterminism (e.g. MPSGraph
// reduction order on Float32) is the kernel's concern,
// not this executor's。 The outcome enum lets tests pin
// which dispatch path fired without inspecting wall-clock
// timing。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (typed
//     outcome enum,typed key,typed inputs)
//   - chapter 二百一一 — single source-of-truth (one
//     dispatch path through registry,one fallback
//     contract,one outcome enum)
//   - chapter 三百九二 — replay-determinism (same inputs
//     route same path;outcome enum makes path observable)
//   - ADR-014 OPT-IN — additive only。 Existing
//     `executePlanWithAssignments` callers unaffected
//     unless they explicitly construct a routed executor
//     via this factory
//   - 红线 7 — hint-only (factory builds dispatch routing;
//     never mutates registry or commitment state)

import Foundation
import BASMetalSubstrate
import BASRuntimeCore

// MARK: - Outcome enum

/// Typed outcome of one kernel-registry dispatch attempt。
/// Surfaced via the input-builder closure's optional
/// outcome-handler callback so tests + observability can
/// pin which dispatch path fired per stage。
public enum BASKernelRegistryDispatchOutcome:
    String, Codable, Equatable, Hashable, Sendable, CaseIterable
{

    /// Assignment had a key + kernel was registered +
    /// inputs built + kernel evaluated successfully。
    case dispatched = "dispatched"

    /// Assignment.selectedKernelKey was nil — the
    /// scheduler chose no kernel for this stage (e.g。
    /// pure-CPU rationale)。 Routed to fallback closure。
    case fallbackNoKey = "fallback-no-key"

    /// Assignment had a key but the registry has no
    /// kernel registered under it。 Routed to fallback
    /// closure。 Indicates registry / hint mismatch — the
    /// kernel registry should register a kernel for any
    /// key the scheduler might return。
    case fallbackNoKernel = "fallback-no-kernel"

    /// Assignment had a key + kernel was registered but
    /// the caller's input builder returned nil (e.g.
    /// stage doesn't have its tensor inputs available
    /// yet)。 Routed to fallback closure。
    case fallbackNoInputs = "fallback-no-inputs"

    /// Assignment had a key + kernel was registered +
    /// inputs built but the kernel threw an error。
    /// Routed to fallback closure。 Indicates a kernel-
    /// internal issue (shape mismatch,etc.)。
    case fallbackKernelError = "fallback-kernel-error"
}

// MARK: - Factory

/// Factory namespace producing routed-executor closures
/// that dispatch through `BASMetalKernelRegistry` when the
/// scheduler chose a kernel key,otherwise fall through
/// to a caller-provided fallback closure。
public enum BASKernelRegistryDispatchExecutor {

    /// Input builder closure — given a stage + assignment
    /// + request,produce the `BASKernelInputs` to dispatch
    /// through the registered kernel。 Return nil if the
    /// stage doesn't have its tensor inputs available
    /// (executor falls through to fallback)。
    public typealias InputBuilder = @Sendable (
        BASTurnRuntimeStage,
        BASStageAcceleratorAssignment,
        BASEBrainTurnRequest
    ) async -> BASKernelInputs?

    /// Optional outcome handler — invoked after each
    /// dispatch attempt with the typed outcome enum。
    /// Useful for tests / observability。 Optional so
    /// production callers can omit it for zero overhead。
    public typealias OutcomeHandler = @Sendable (
        BASTurnRuntimeStage,
        BASKernelRegistryDispatchOutcome
    ) async -> Void

    /// Build a routed-executor closure that dispatches
    /// through the given registry when the assignment
    /// carries a kernel key + the kernel is registered +
    /// inputs are buildable。 Falls through to the
    /// fallback closure for all other cases。
    ///
    /// The returned closure conforms to
    /// `BASNativeStageExecutor.RoutedStageExecutor` so
    /// it can be passed directly to
    /// `executePlanWithAssignments(...)`。
    public static func makeRoutedExecutor(
        registry: BASMetalKernelRegistry,
        inputBuilder: @escaping InputBuilder,
        outcomeHandler: OutcomeHandler? = nil,
        fallback: @escaping BASNativeStageExecutor
            .RoutedStageExecutor
    ) -> BASNativeStageExecutor.RoutedStageExecutor {
        return { stage, assignment, request in
            guard let key = assignment.selectedKernelKey
            else {
                if let h = outcomeHandler {
                    await h(stage, .fallbackNoKey)
                }
                return await fallback(
                    stage, assignment, request)
            }
            guard
                await registry.kernel(for: key) != nil
            else {
                if let h = outcomeHandler {
                    await h(stage, .fallbackNoKernel)
                }
                return await fallback(
                    stage, assignment, request)
            }
            guard
                let inputs = await inputBuilder(
                    stage, assignment, request)
            else {
                if let h = outcomeHandler {
                    await h(stage, .fallbackNoInputs)
                }
                return await fallback(
                    stage, assignment, request)
            }
            do {
                let result = try await registry.dispatch(
                    key: key, inputs: inputs)
                if let h = outcomeHandler {
                    await h(stage, .dispatched)
                }
                return result
            } catch {
                if let h = outcomeHandler {
                    await h(stage, .fallbackKernelError)
                }
                return await fallback(
                    stage, assignment, request)
            }
        }
    }
}
