// MARK: - BASHostRuntimeMeshSweep — chapter 三百二五 / M812
//
// Phase F (附录 X) 第五刀:multi-layer sweep API + Chenglu
// canonical sweep convenience。Builds on chapter 三百二三
// `BASHostRuntime.runMeshCascade(input:layerID:)` to let hosts
// consult multiple layers in one call instead of N calls。
//
// **0 default behavior change**:hosts still must opt in by
// passing a populated `meshRegistry` to `BASHostRuntime` — same
// gate as chapter 三百二三。Sweeping is a thin coordinator above
// `runMeshCascade`,not a new substrate path。
//
// ## What this ships
//
//   - `BASHostMeshSweepResult` — typed Sendable+Equatable bundle
//     holding per-layer cascade results + aggregated reason codes
//   - `BASHostMeshSweepLayerEntry` — typed Sendable per-layer
//     wrapper coupling layerID to its consultation result
//   - `BASHostRuntime.runMeshSweep(input:layers:)` — primary
//     multi-layer sweep entry point;walks layers in caller-supplied
//     order;skips layers when no registry wired (returns empty
//     sweep)
//   - `BASHostRuntime.runChengluCanonicalSweep(input:)` — convenience
//     that walks the 8 canonical Chenglu layers per附录 X §X.2
//     doctrine in priority order (l1 → l4 → l6 → l8 → l11 → l12)
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — sweep is opt-in hint composition,
//     no permit/verdict mutation
//   - 红线 7 watcher hint only — hosts walk results,decide
//   - 单提交口 (L11/L14) 不变 — sweep results never replace
//     permit/verdict authority
//   - chapter 二百一一 single-source-of-truth: `runMeshSweep`
//     internally calls `runMeshCascade` per layer (no parallel
//     dispatch path)
//   - chapter 一百八十五 anti-magic-number: canonical layer list
//     constant `chengluCanonicalLayers` named, not inline
//   - chapter 三百二一 (M808) §X.2 doctrine: canonical layer set
//     mirrors the 8-slot doctrine
//   - chapter 三百二三 (M810) opt-in hook: sweep returns empty
//     sweep result when no registry wired (preserves opt-in
//     contract)
//
// ## Non-goals
//
//   - Parallel dispatch: layers consulted sequentially (each
//     cascade is an `await`)
//   - Aggregation policy: callers receive per-layer results +
//     aggregated codes;deciding what to act on is host coordinator
//     responsibility,not this method's

import Foundation
import BASRuntimeCore

// MARK: - Per-layer sweep entry

/// Typed wrapper coupling a layer ID to its consultation result。
/// Carries `BASHostMeshConsultationResult` (chapter 三百二三)
/// directly so callers can inspect cascade outcome + reason codes
/// per layer。
public struct BASHostMeshSweepLayerEntry: Sendable, Equatable, Codable {
    public let layerID: BASMotherboardLayer14
    public let consultation: BASHostMeshConsultationResult

    public init(
        layerID: BASMotherboardLayer14,
        consultation: BASHostMeshConsultationResult
    ) {
        self.layerID = layerID
        self.consultation = consultation
    }
}

// MARK: - Sweep result

/// Typed result of a multi-layer sweep。Holds per-layer entries
/// (in the order they were consulted) + aggregated reason codes
/// across all layers (deduplication NOT performed — caller
/// inspects raw codes for grep)。
public struct BASHostMeshSweepResult: Sendable, Equatable, Codable {
    /// Per-layer consultation results in caller-supplied order。
    public let layerEntries: [BASHostMeshSweepLayerEntry]

    /// Aggregated reason codes from all layer consultations。
    /// Order: codes from each layer in the order layers were
    /// consulted (cascade-emission order within each layer
    /// preserved per chapter 三百二三 doctrine)。
    public let aggregatedReasonCodes: [String]

    /// Number of layers consulted (== `layerEntries.count`)。
    public var layerCount: Int { layerEntries.count }

    /// Number of layers where cascade matched a head (i.e.
    /// outcome ∈ {.headMatched, .floorMet})。
    public var matchedLayerCount: Int {
        layerEntries.filter { entry in
            switch entry.consultation.cascadeResult.outcome {
            case .headMatched, .floorMet: return true
            case .fallenThrough, .noHeadsRegistered: return false
            }
        }.count
    }

    public init(
        layerEntries: [BASHostMeshSweepLayerEntry],
        aggregatedReasonCodes: [String]
    ) {
        self.layerEntries = layerEntries
        self.aggregatedReasonCodes = aggregatedReasonCodes
    }
}

// MARK: - Canonical Chenglu layer set

/// Canonical Chenglu layer set per附录 X §X.2 doctrine。Used by
/// `runChengluCanonicalSweep(input:)`。Order is priority-ordered
/// (early-cognition → late-output)。
///
/// Layers covered (8 canonical slots distributed across 6 layers):
///   - l1 (wake-policy + compute-cost-predictor)
///   - l4 (question-type)
///   - l6 (emotion-classifier)
///   - l8 (importance-scorer)
///   - l11 (risk-scorer + safety-action-selector)
///   - l12 (density-controller)
public let chengluCanonicalLayers: [BASMotherboardLayer14] = [
    .l1, .l4, .l6, .l8, .l11, .l12
]

// MARK: - BASHostRuntime sweep extension

public extension BASHostRuntime {

    /// Sweep multiple layers with the given input。Each layer is
    /// consulted via `runMeshCascade(input:layerID:)` (chapter
    /// 三百二三)。Returns empty sweep when no registry wired
    /// (preserves opt-in contract)。
    ///
    /// Layers are consulted **sequentially** in caller-supplied
    /// order;each `runMeshCascade` is an independent `await`。
    /// Errors short-circuit the sweep (re-thrown from the failing
    /// layer's cascade)。
    ///
    /// - Parameters:
    ///   - input: typed inference input (caller builds via
    ///     `BASChengluFeatureRefBuilder.build(...)` from chapter
    ///     三百二二)。`input.layerID` is overridden per-layer
    ///     during dispatch
    ///   - layers: ordered list of layers to consult
    /// - Returns: typed sweep result。Empty when no registry
    ///   wired or when `layers` is empty
    /// - Throws: re-throws first cascade error
    func runMeshSweep(
        input: BASLayerInferenceInput,
        layers: [BASMotherboardLayer14]
    ) async throws -> BASHostMeshSweepResult {
        guard !layers.isEmpty else {
            return BASHostMeshSweepResult(
                layerEntries: [], aggregatedReasonCodes: [])
        }
        guard hasMeshRegistry else {
            return BASHostMeshSweepResult(
                layerEntries: [], aggregatedReasonCodes: [])
        }

        var entries: [BASHostMeshSweepLayerEntry] = []
        var aggregated: [String] = []
        for layer in layers {
            // Pass input down with caller's layerID;cascade uses
            // explicit `layerID` parameter for slot lookup but
            // input.layerID still reaches each head per chapter
            // 三百一二 BASLayerCascadeRunner doctrine。
            let layerInput = BASLayerInferenceInput(
                layerID: layer,
                featureRef: input.featureRef,
                confidenceFloor: input.confidenceFloor)
            guard let result = try await runMeshCascade(
                input: layerInput, layerID: layer)
            else {
                // Chapter 三百四七 / M834 fix: previous defensive
                // bail-out returned partial result with NO
                // reason code → host saw silent truncation。
                // If `hasMeshRegistry` returned true at line 162
                // but `runMeshCascade` returns nil here,that's
                // an invariant violation (registry actor became
                // invalid mid-sweep — should be impossible
                // because BASHostRuntime.meshRegistry is a `let`
                // and the actor is reference-stable)。
                //
                // Emit typed reason code so audit can detect
                // this state if it ever occurs,instead of
                // silent truncation。
                aggregated.append(
                    "mesh-sweep:partial-bail-out:" +
                    "after-layer:\(layer.rawValue):" +
                    "invariant-violated")
                return BASHostMeshSweepResult(
                    layerEntries: entries,
                    aggregatedReasonCodes: aggregated)
            }
            entries.append(BASHostMeshSweepLayerEntry(
                layerID: layer, consultation: result))
            aggregated.append(contentsOf: result.reasonCodes)
        }

        return BASHostMeshSweepResult(
            layerEntries: entries,
            aggregatedReasonCodes: aggregated)
    }

    /// Convenience:sweep the 8 canonical Chenglu slots per附录 X
    /// §X.2 doctrine (6 layers,8 total slots)。Equivalent to:
    /// `runMeshSweep(input:layers: chengluCanonicalLayers)`。
    func runChengluCanonicalSweep(
        input: BASLayerInferenceInput
    ) async throws -> BASHostMeshSweepResult {
        try await runMeshSweep(
            input: input, layers: chengluCanonicalLayers)
    }
}
