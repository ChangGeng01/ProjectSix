// MARK: - BASLayerCascadeRunner — chapter 三百一二 / M799
//
// Phase Delta 第三刀:typed cascade runner that walks a layer's
// slot list in priority order,invoking each head until confidence
// ≥ floor (or all exhausted)。Encodes chapter 一百七十七 cascading
// inference doctrine into testable code。
//
// chapter 一百七十七 vision § 10 cascading inference describes
// rules → small ML → big ML → AFM → cloud LLM as the typical
// stack。Layer actors don't need to manually walk this stack —
// the cascade runner does it given a registry + a layer ID + an
// input frame。
//
// ## 这一刀 ship 什么
//
// 3 typed primitives:
//
//   - `BASLayerCascadeOutcome` (4-case enum) — typed runner result:
//     headMatched / floorMet / fallenThrough / noHeadsRegistered
//   - `BASLayerCascadeResult` (BASSchemaVersioned 1.0.0) — full
//     typed runner output: outcome + matched headID +
//     output frame + cascade audit trail (which heads tried)
//   - `BASLayerCascadeRunner` — typed namespace exposing static
//     `run(input:registry:layerID:)` async function。Does NOT
//     hold state — pure dispatcher。
//
// ## Why a stateless runner (not a layer-actor field)
//
// Cascade is pure dispatch logic over a registry's slot list。
// Embedding it in `BASLayerActor` protocol would couple every
// layer's process() implementation to one specific cascade
// strategy。A standalone runner lets:
// 1) Future Phase Delta cuts ship alternative cascade strategies
//    (parallel inference / quorum vote / etc) without breaking
//    actor protocol
// 2) Tests verify cascade behavior without constructing full
//    layer actor stack
// 3) Layer actors call the runner from inside their process()
//    without inheriting cascade-specific state
//
// **0 behavior change**:purely additive new file。No layer actor
// currently invokes the runner。
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — runner is dispatch logic, not
//     verdict authority
//   - 红线 7 watcher hint only — runner walks ML head outputs
//     (hints), layer actor decides whether to act on the
//     winning hint
//   - 单提交口 (L11/L14) 不变 — runner doesn't issue permits
//   - chapter 二百一一 single-source-of-truth: ONE runner for
//     cascading inference (vs scattered cascade loops in
//     each layer actor)
//   - chapter 一百八十五 anti-magic-number: outcome enum 4 cases,
//     all error paths typed
//   - chapter 一百三 schema-version: 1.0.0 invariant for
//     BASLayerCascadeResult
//   - chapter 一百三十 BASLearnabilityClass: cascade audit trail
//     is observability metadata, semi-learnable
//   - chapter 三百 BASLayerMLHead protocol: runner consumes
//     `(any BASLayerMLHead, BASLayerMLHeadSlot)` pairs from
//     registry's enabledHeads()
//   - chapter 三百一一 BASRulesBasedLayerMLHead: rules-tier heads
//     are typical priority-0 cascade entries

import Foundation

// MARK: - Cascade outcome enum

/// 4-case typed cascade runner result classifier。Each case
/// matches a distinct decision path the runner can take。
public enum BASLayerCascadeOutcome:
    String,
    Sendable,
    Equatable,
    Hashable,
    Codable,
    CaseIterable
{
    /// At least one head returned `confidence >= floor`. The
    /// matched head's output is the runner's authoritative result.
    case headMatched = "head-matched"

    /// First head tried returned `confidence == floor` exactly
    /// (counts as match;included as separate case for diagnostic
    /// audit clarity — e.g. `.medium` floor matched by `.medium`).
    case floorMet = "floor-met"

    /// All registered heads tried, none returned `confidence >=
    /// floor`. Caller must fall back to layer's own rules logic
    /// (chapter 三百〇一 `mlHeadFallthrough` status).
    case fallenThrough = "fallen-through"

    /// Layer has no enabled heads in registry. Caller falls back
    /// to its hardcoded path. Diagnostic-only — distinguishes
    /// "registry empty" from "all heads tried + missed floor".
    case noHeadsRegistered = "no-heads-registered"
}

// MARK: - Cascade result record

/// Full typed runner output frame。Hosts emit this into audit
/// trail to show which heads were tried + which one won (if any)。
public struct BASLayerCascadeResult:
    BASSchemaVersioned, Sendable, Equatable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String

    /// Typed outcome classifier (4-case).
    public var outcome: BASLayerCascadeOutcome

    /// Layer the cascade ran for.
    public var layerID: BASMotherboardLayer14

    /// HeadID that won (only meaningful when outcome ==
    /// `.headMatched` or `.floorMet`).
    public var matchedHeadID: String?

    /// Inference output from the winning head, or nil for
    /// `.fallenThrough` / `.noHeadsRegistered`.
    public var matchedOutput: BASLayerInferenceOutput?

    /// Audit trail: list of (headID, confidence) pairs in the
    /// order they were tried. Includes ALL heads attempted, not
    /// just the winner. Useful for emitting cascade audit codes.
    public var triedHeads: [BASLayerCascadeAttempt]

    public init(
        schemaVersion: String
            = BASLayerCascadeResult.currentSchemaVersion,
        outcome: BASLayerCascadeOutcome,
        layerID: BASMotherboardLayer14,
        matchedHeadID: String? = nil,
        matchedOutput: BASLayerInferenceOutput? = nil,
        triedHeads: [BASLayerCascadeAttempt] = []
    ) {
        self.schemaVersion = schemaVersion
        self.outcome = outcome
        self.layerID = layerID
        self.matchedHeadID = matchedHeadID?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.matchedOutput = matchedOutput
        self.triedHeads = triedHeads
    }
}

/// Per-attempt audit trail entry — head tried + confidence
/// returned。Lets audit emission show why earlier heads were
/// skipped (confidence < floor)。
public struct BASLayerCascadeAttempt:
    Sendable, Equatable, Hashable, Codable
{
    public let headID: String
    public let kind: BASLayerMLHeadKind
    public let confidence: BASLayerInferenceConfidence
    public let met: Bool

    public init(
        headID: String,
        kind: BASLayerMLHeadKind,
        confidence: BASLayerInferenceConfidence,
        met: Bool
    ) {
        self.headID = headID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.kind = kind
        self.confidence = confidence
        self.met = met
    }
}

// MARK: - Cascade runner

/// Stateless typed dispatcher that walks a registry's slot list
/// for a given layer in priority order, calling each head's
/// `infer(input:)` until one returns `confidence >= floor`
/// (where floor is read from `input.confidenceFloor`)。
public enum BASLayerCascadeRunner {

    /// Walk the cascade。Returns typed result with outcome +
    /// matched head + audit trail。
    ///
    /// Confidence ordering (chapter 三百 BASLayerInferenceConfidence
    /// rank):
    ///   - `.high` = 3
    ///   - `.medium` = 2
    ///   - `.low` = 1
    ///   - `.unknown` = 0
    /// Match means `outputConfidence >= floor` per this ordering.
    /// `.unknown` only matches when floor is also `.unknown`.
    ///
    /// - Parameters:
    ///   - input: typed inference input (input.confidenceFloor
    ///     drives match)
    ///   - registry: source of slot bindings + head instances
    ///   - layerID: which layer's slots to walk (overrides
    ///     input.layerID for slot lookup; input.layerID still
    ///     reaches each head)
    /// - Returns: typed result. Outcome enum classifies which
    ///   path the cascade took.
    /// - Throws: re-throws caller's head error if any head's
    ///   infer() throws. Cascade aborts on first error (no
    ///   silent error swallowing).
    public static func run(
        input: BASLayerInferenceInput,
        registry: BASLayerMLHeadRegistry,
        layerID: BASMotherboardLayer14
    ) async throws -> BASLayerCascadeResult {
        let pairs = await registry.enabledHeads(
            forLayer: layerID)

        guard !pairs.isEmpty else {
            return BASLayerCascadeResult(
                outcome: .noHeadsRegistered,
                layerID: layerID)
        }

        let floor = input.confidenceFloor
        var trail: [BASLayerCascadeAttempt] = []

        for (head, slot) in pairs {
            let output = try await head.infer(input: input)
            let met = isConfidenceMet(
                output: output.confidence, floor: floor)
            let attempt = BASLayerCascadeAttempt(
                headID: head.headID,
                kind: slot.kind,
                confidence: output.confidence,
                met: met)
            trail.append(attempt)
            if met {
                let outcome: BASLayerCascadeOutcome =
                    output.confidence == floor
                        ? .floorMet
                        : .headMatched
                return BASLayerCascadeResult(
                    outcome: outcome,
                    layerID: layerID,
                    matchedHeadID: head.headID,
                    matchedOutput: output,
                    triedHeads: trail)
            }
            // confidence < floor → continue cascade
        }

        // All heads tried, none met floor.
        return BASLayerCascadeResult(
            outcome: .fallenThrough,
            layerID: layerID,
            triedHeads: trail)
    }

    /// Confidence ordering check:does `output` confidence meet
    /// or exceed `floor`?
    public static func isConfidenceMet(
        output: BASLayerInferenceConfidence,
        floor: BASLayerInferenceConfidence
    ) -> Bool {
        confidenceRank(output) >= confidenceRank(floor)
    }

    /// Map 4-case confidence enum to monotonic Int rank for
    /// comparison。`.unknown` is lowest (0),`.high` is highest
    /// (3)。
    public static func confidenceRank(
        _ confidence: BASLayerInferenceConfidence
    ) -> Int {
        switch confidence {
        case .unknown: return 0
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }

    /// Helper:emit canonical typed reason codes for a cascade
    /// result。Used by layer actors to feed cascade audit trail
    /// into their output.reasonCodes。
    public static func reasonCodes(
        for result: BASLayerCascadeResult
    ) -> [String] {
        var codes: [String] = [
            "cascade-outcome:\(result.outcome.rawValue)",
            "cascade-layer:\(result.layerID.rawValue)",
            "cascade-attempts:\(result.triedHeads.count)"
        ]
        if let matched = result.matchedHeadID {
            codes.append("cascade-matched-head:\(matched)")
        }
        return codes
    }
}
