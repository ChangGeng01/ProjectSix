// MARK: - BASHostRuntimeMeshHook — chapter 三百二三 / M810
//
// Phase F (附录 X) 第四刀:opt-in production wire from
// `BASHostRuntime` to the chapter 三百 (M787) typed
// `BASLayerMLHeadRegistry` mesh。Closes v9 §8 non-promise #2
// (Substrate consumer wire-up — BASHostRuntime mesh consumption)。
//
// **0 default behavior change**:default `BASHostRuntime` init
// keeps `meshRegistry: nil`,so no existing call site is
// affected。Hosts that want the chapter 三百二〇/三百二一 mesh
// available pass a populated `BASLayerMLHeadRegistry` at runtime
// construction,then call `runMeshCascade(input:layerID:)` at
// whatever seam fits their orchestration。
//
// ## Why opt-in not default
//
//   - Phase Beta + Delta foundation (chapters 二百九十九-三百一三)
//     intentionally stopped at "actor + ML slot ready" and did
//     NOT wire heads into the default substrate path
//   - Phase Gamma (default-behavior mutation) is a separate plan
//     domain with stricter doctrine review (per chapter 二百二十二
//     ADR-014 OPT-IN → PROD migration doctrine)
//   - This chapter ships the OPT-IN side of that contract:
//     hosts can NOW consume the mesh; PROD migration is a
//     future doctrine decision
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — opt-in only,permit/verdict
//     paths untouched
//   - 红线 7 watcher hint only — `runMeshCascade(...)` returns
//     typed cascade outcome,host coordinator decides whether
//     to act
//   - 单提交口 (L11/L14) 不变 — mesh result is hint, not commit
//   - chapter 二百一一 single-source-of-truth:`BASHostRuntime`
//     is the single host-facing API surface;mesh accessor
//     lives on it (not on configuration / dependencies / vault)
//   - chapter 三百二〇 (M807) BASCoreMLLayerHead +
//     chapter 三百二一 (M808) BASChengluMeshRegistration:
//     this chapter lets hosts call those primitives from
//     within `BASHostRuntime` orchestration
//   - chapter 三百一二 (M799) BASLayerCascadeRunner: the
//     mesh consultation reuses the typed cascade dispatcher
//
// ## Non-goals (deferred to future Phase Gamma chapters)
//
//   - Default substrate path consulting the mesh
//   - Auto-construction of registry inside BASHostRuntime
//   - L11 permit / L14 verdict mutation based on mesh hints
//   - Cross-instance mesh sync transport (chapter 三百一九
//     BASMeshSyncFrame is schema-only)

import Foundation
import BASRuntimeCore

// MARK: - Mesh consultation result

/// Typed wrapper for `BASLayerCascadeResult` augmented with the
/// canonical audit reason codes hosts emit into their trace。
public struct BASHostMeshConsultationResult:
    Sendable, Equatable
{
    /// The underlying typed cascade result。
    public let cascadeResult: BASLayerCascadeResult

    /// Typed audit reason codes for emission into substrate
    /// trace。Caller appends these to whatever audit ledger
    /// they're emitting into。Format mirrors chapter 三百二一's
    /// `mesh-coreml:*` prefix doctrine for consistent grep。
    public let reasonCodes: [String]

    public init(
        cascadeResult: BASLayerCascadeResult,
        reasonCodes: [String]
    ) {
        self.cascadeResult = cascadeResult
        self.reasonCodes = reasonCodes
    }
}

// MARK: - Reason code synthesis

/// Build canonical reason codes from a cascade result。Helpers
/// preserved for tests + advanced hosts that want to compose
/// codes manually。
public enum BASHostMeshReasonCodes {

    public static let prefix: String = "mesh-coreml"

    /// Build the canonical reason-code list for a given
    /// cascade result。Format:
    ///   - `mesh-coreml:cascade:<outcome>`
    ///   - `mesh-coreml:layer:<layerID>`
    ///   - `mesh-coreml:matched-head:<headID>` (when matched)
    ///   - `mesh-coreml:tried:<count>`
    public static func codes(
        for result: BASLayerCascadeResult
    ) -> [String] {
        var codes: [String] = [
            "\(prefix):cascade:\(rawOutcome(result.outcome))",
            "\(prefix):layer:\(result.layerID.rawValue)",
            "\(prefix):tried:\(result.triedHeads.count)"
        ]
        if let matchedHeadID = result.matchedHeadID {
            codes.append(
                "\(prefix):matched-head:\(matchedHeadID)")
        }
        return codes
    }

    /// Stable kebab-case raw value for outcome enum cases。
    /// Pinned by tests for grep-friendliness (chapter 八十七
    /// M287 raw value stability doctrine)。
    public static func rawOutcome(
        _ outcome: BASLayerCascadeOutcome
    ) -> String {
        switch outcome {
        case .headMatched: return "head-matched"
        case .floorMet: return "floor-met"
        case .fallenThrough: return "fallen-through"
        case .noHeadsRegistered: return "no-heads-registered"
        }
    }
}

// MARK: - Typed errors (chapter 三百四八 / M835)

/// Typed error cases for mesh consultation。Lets hot-path callers
/// distinguish "registry not wired" from cascade-runner failures
/// (bad head, infer-throw, etc.)。
public enum BASHostMeshError: Error, Equatable, Sendable {
    /// `runMeshCascadeRequired(...)` was called on a runtime that
    /// has no mesh registry wired。The non-Optional contract makes
    /// this an explicit invariant violation rather than a silent
    /// nil return。Carries the layer the caller attempted for
    /// diagnostic context。
    case noRegistryWired(attemptedLayer: BASMotherboardLayer14)
}

// MARK: - BASHostRuntime extension

public extension BASHostRuntime {

    /// Consult the host's optional mesh registry for the given
    /// layer。Returns the cascade outcome wrapped with canonical
    /// audit reason codes,or nil if no registry is wired。
    ///
    /// **Default behavior (no registry wired): returns nil — no
    /// behavior change vs pre-chapter 三百二三 BASHostRuntime
    /// instances.** Existing call sites that don't pass a registry
    /// see exactly the same execution profile as before。
    ///
    /// **Hot-path tip (chapter 三百四八 / M835)**: the nil-bail
    /// is synchronous (no `await` is reached when registry is nil),
    /// so the async hop is cheap in modern Swift。But for tight
    /// inference loops where `meshRegistry` is statically known,
    /// pre-checking `hasMeshRegistry` once at construction time +
    /// skipping the call is still the cleanest pattern。If the
    /// caller has already verified `hasMeshRegistry == true`,
    /// prefer `runMeshCascadeRequired(...)` which returns a
    /// non-Optional result and throws `BASHostMeshError.
    /// noRegistryWired` if the precondition is violated。
    ///
    /// Hosts that want mesh consultation:
    ///   1. Construct + populate a registry (chapter 三百二一
    ///      `BASChengluMeshRegistration.assemble(into:options:)`)
    ///   2. Pass it to `BASHostRuntime` constructor
    ///   3. Call this method between turns at appropriate seams
    ///
    /// - Parameters:
    ///   - input: typed inference input (caller builds via
    ///     chapter 三百二二 `BASChengluFeatureRefBuilder.build(...)`)
    ///   - layerID: which canonical layer's slots to walk
    /// - Returns: typed result wrapping cascade + reason codes,
    ///   or nil if no registry was wired at construction
    /// - Throws: re-throws whatever the cascade runner throws
    ///   (head infer error)
    func runMeshCascade(
        input: BASLayerInferenceInput,
        layerID: BASMotherboardLayer14
    ) async throws -> BASHostMeshConsultationResult? {
        // Sync fast-path:bail before any `await` when no registry
        // wired。Modern Swift's async machinery makes this nearly
        // free,but the explicit guard keeps the intent legible
        // (chapter 三百四八 / M835 HIGH #4 backlog item)。
        guard hasMeshRegistry else { return nil }
        return try await runMeshCascadeRequired(
            input: input, layerID: layerID)
    }

    /// Non-Optional variant of `runMeshCascade` for hot-path
    /// callers that have already verified `hasMeshRegistry == true`。
    /// Throws `BASHostMeshError.noRegistryWired` if the precondition
    /// is violated — explicit invariant failure beats silent nil。
    ///
    /// **When to use this instead of `runMeshCascade`**:
    ///   - Tight inference loops where the registry presence is
    ///     a static invariant (host pre-checks at construction)
    ///   - Code paths where a nil result indicates a programmer
    ///     error rather than an opt-in toggle
    ///
    /// Otherwise prefer `runMeshCascade(...)` — its Optional
    /// signature is the canonical opt-in API per chapter 三百二三
    /// (M810) doctrine。
    ///
    /// Chapter 三百四八 / M835 — closes the backlog item raised
    /// in chapter 三百四七 / M834 audit (HIGH #4 async-when-nil
    /// cost / API clarity)。
    ///
    /// - Parameters:
    ///   - input: typed inference input
    ///   - layerID: which canonical layer's slots to walk
    /// - Returns: typed cascade result + reason codes
    /// - Throws: `BASHostMeshError.noRegistryWired(attemptedLayer:)`
    ///   if no registry is wired;else re-throws cascade runner
    ///   errors
    func runMeshCascadeRequired(
        input: BASLayerInferenceInput,
        layerID: BASMotherboardLayer14
    ) async throws -> BASHostMeshConsultationResult {
        guard let registry = meshRegistry else {
            throw BASHostMeshError.noRegistryWired(
                attemptedLayer: layerID)
        }
        let cascade = try await BASLayerCascadeRunner.run(
            input: input,
            registry: registry,
            layerID: layerID)
        let codes = BASHostMeshReasonCodes.codes(for: cascade)
        return BASHostMeshConsultationResult(
            cascadeResult: cascade,
            reasonCodes: codes)
    }

    /// Convenience predicate: does this runtime have a wired
    /// mesh registry? Cheap stored-property check — safe to call
    /// at every host turn boundary。
    ///
    /// Chapter 三百四八 / M835: marked `@inlinable` so cross-module
    /// callers (SampleHost / Before / Widget / Watch) can elide
    /// the call entirely when used as a guard expression。Body is
    /// a single nil-comparison on a `let` property,so the inlined
    /// expansion is zero-cost。
    @inlinable
    var hasMeshRegistry: Bool {
        meshRegistry != nil
    }
}
