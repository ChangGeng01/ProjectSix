// MARK: - BASLayerSliceAndMLHead — chapter 三百 / M787
//
// Phase Beta 第二刀:per-layer budget slice + ML head slot 协议。
// chapter 二百九十九 (M786) 已 ship `BASLayerActor` 协议;本刀 ship
// 两个伴随类型,让 actor 实现可以 declare per-call budget +
// optional ML head slot。
//
// ## 这一刀 ship 什么
//
// 4 个 typed value-types + 1 个 protocol:
//
//   - `BASLayerSlice` (BASSchemaVersioned 1.0.0) — per-layer budget
//     子分配 (sub-allocation from BASBudgetFrame turn-level budget)
//     - layerID / allocatedMs / hardCapMs / decodeTokenAllowance /
//       loopAllowance / observabilityOnly(bool — 红线 7 hint-only
//       layers like watcher heads ride here)
//   - `BASLayerInferenceInput` (BASSchemaVersioned 1.0.0) — ML head
//     输入 frame: layerID / featureRef / confidenceFloor /
//     correlationID
//   - `BASLayerInferenceOutput` (BASSchemaVersioned 1.0.0) — ML head
//     输出 frame: layerID / scores / confidence / recommendedAction /
//     reasonCodes / inferenceLatencyMs
//   - `BASLayerMLHeadKind` (5-case) — typed slot kind classifier:
//     rules / coremlOnDevice / mlxLocal / appleFoundationModel /
//     externalProvider — used by chapter 三百一四+ device tiering
//   - `BASLayerMLHead` protocol — `headID: String` + `kind:
//     BASLayerMLHeadKind` + `infer(input:) async throws -> output`
//
// ## Why now
//
// chapter 一百七十七 vision 的 P0-P6 roadmap 把 Core ML 反射 mesh
// 跨 14 层,每 layer 0-N heads。Phase Beta foundation work 必须
// declared the contract before Phase Delta (chapter 三百一四+) ships
// real mlpackage adapters。让 future heads 实现 protocol 即可挂入
// `BASLayerActor.mlHeadSlot`。
//
// **0 behavior change**:purely additive new file, no existing
// runtime code changes。
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保
//   - 红线 7 watcher hint only:`observabilityOnly` field on
//     LayerSlice + `recommendedAction` is hint not gate
//   - 单提交口 (L11/L14) 不变 — ML heads produce hints, never
//     issue permits / warrants
//   - chapter 一百七十七 cascading inference doctrine: rules → small
//     ML → big ML → AFM → cloud LLM。`kind` enum 5 cases match
//     this stack
//   - chapter 一百三十 BASLearnabilityClass: ML head outputs are
//     observability metadata, semi-learnable — never feed weights
//   - chapter 一百八十五 anti-magic-number: kind enum 5 cases,
//     all clamping invariants typed
//   - chapter 二百一一 single-source-of-truth: protocol owned by
//     this file

import Foundation

// MARK: - BASLayerSlice — per-layer budget sub-allocation

/// Per-layer budget slice — sub-allocation from
/// `BASBudgetFrame` turn-level budget。每 layer actor 在 process
/// 调用时拿到自己的 slice,内部决定如何花掉。
///
/// Field semantics:
///   - `layerID` — which layer this slice serves
///   - `allocatedMs` — soft target millisecond budget (typical
///     case);clamped ≥0
///   - `hardCapMs` — hard ceiling beyond which `BASLayerActorError
///     .budgetExceeded` is thrown by enforcement layer (chapter
///     三百〇一);clamped ≥`allocatedMs`
///   - `decodeTokenAllowance` — for L2/L9 layers that decode tokens;
///     0 for layers that don't decode (clamped ≥0)
///   - `loopAllowance` — for L9 dream-loop / L10 tribunal layers
///     that iterate;1 for non-iterative layers (clamped ≥1)
///   - `observabilityOnly` — true for watcher / hint-only layers
///     (红线 7);output never feeds permit/verdict logic
public struct BASLayerSlice: BASSchemaVersioned, Sendable {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var layerID: BASMotherboardLayer14
    public var allocatedMs: Double
    public var hardCapMs: Double
    public var decodeTokenAllowance: Int
    public var loopAllowance: Int
    public var observabilityOnly: Bool

    public init(
        schemaVersion: String = BASLayerSlice.currentSchemaVersion,
        layerID: BASMotherboardLayer14,
        allocatedMs: Double,
        hardCapMs: Double,
        decodeTokenAllowance: Int = 0,
        loopAllowance: Int = 1,
        observabilityOnly: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.layerID = layerID
        let clampedAllocated = max(0, allocatedMs)
        self.allocatedMs = clampedAllocated
        // hardCap 必须 ≥ allocated;否则 budget 矛盾
        self.hardCapMs = max(clampedAllocated, hardCapMs)
        self.decodeTokenAllowance = max(0, decodeTokenAllowance)
        self.loopAllowance = max(1, loopAllowance)
        self.observabilityOnly = observabilityOnly
    }
}

// MARK: - BASLayerMLHeadKind — typed slot classifier

/// ML head slot 类型分类器。Phase Delta (chapter 三百一四+) 用此
/// enum 选 device tier(Lite / Standard / Pro / Research)+
/// cascading inference order(rules-fastest / on-device-fast /
/// cloud-slowest)。
///
/// 5 cases, ordered by typical inference latency:
///   - `rules` — pure-function classifier;sub-millisecond,
///     deterministic,zero ML
///   - `coremlOnDevice` — `.mlpackage` ANE-accelerated;1-10ms
///     typical (chapter 一百七十七 P0 ChengluPreflight)
///   - `mlxLocal` — MLX-Swift Gemma local;100ms-2s typical
///   - `appleFoundationModel` — Apple FM (iOS 18 / macOS 15);
///     200ms-3s typical
///   - `externalProvider` — cloud LLM via chat completions / etc;
///     500ms-30s typical
public enum BASLayerMLHeadKind:
    String,
    Sendable,
    Equatable,
    Hashable,
    Codable,
    CaseIterable
{
    case rules
    case coremlOnDevice = "coreml-on-device"
    case mlxLocal = "mlx-local"
    case appleFoundationModel = "apple-foundation-model"
    case externalProvider = "external-provider"
}

// MARK: - BASLayerInferenceInput — ML head input frame

/// ML head 输入 frame。Layer actor 把当前 turn 的 layer-level
/// payload 抽出 feature reference 喂给 head。
///
/// Field semantics:
///   - `layerID` — which layer is asking
///   - `featureRef` — opaque feature payload identifier; head
///     implementation 自己 resolve(可能是 prompt + context, 可能是
///     audit signal vector,etc)
///   - `confidenceFloor` — head 必须达到此 confidence 才算 useful;
///     低于此 floor 时 actor 走 cascade fallthrough
///   - `correlationID` — caller-supplied correlation token (audit ID,
///     turn ID, etc)
public struct BASLayerInferenceInput:
    BASSchemaVersioned, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var layerID: BASMotherboardLayer14
    public var featureRef: String
    public var confidenceFloor: BASLayerInferenceConfidence
    public var correlationID: String?

    public init(
        schemaVersion: String
            = BASLayerInferenceInput.currentSchemaVersion,
        layerID: BASMotherboardLayer14,
        featureRef: String,
        confidenceFloor: BASLayerInferenceConfidence = .medium,
        correlationID: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.layerID = layerID
        self.featureRef = featureRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.confidenceFloor = confidenceFloor
        self.correlationID = correlationID?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - BASLayerInferenceOutput — ML head output frame

/// ML head 输出 frame。
///
/// Field semantics:
///   - `layerID` — which layer's head produced this
///   - `scores` — head-specific score map (e.g. {"intent":0.83,
///     "risk":0.12});empty if no scores produced
///   - `confidence` — head's self-reported confidence
///   - `recommendedAction` — optional hint string;**红线 7**:
///     actor 决定是否 act on,head 不直接 gate
///   - `reasonCodes` — typed reason codes for audit trail
///   - `inferenceLatencyMs` — wall-clock head inference latency
///     (clamped ≥0)
public struct BASLayerInferenceOutput:
    BASSchemaVersioned, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var layerID: BASMotherboardLayer14
    public var scores: [String: Double]
    public var confidence: BASLayerInferenceConfidence
    public var recommendedAction: String?
    public var reasonCodes: [String]
    public var inferenceLatencyMs: Double

    public init(
        schemaVersion: String
            = BASLayerInferenceOutput.currentSchemaVersion,
        layerID: BASMotherboardLayer14,
        scores: [String: Double] = [:],
        confidence: BASLayerInferenceConfidence = .unknown,
        recommendedAction: String? = nil,
        reasonCodes: [String] = [],
        inferenceLatencyMs: Double = 0
    ) {
        self.schemaVersion = schemaVersion
        self.layerID = layerID
        self.scores = scores
        self.confidence = confidence
        self.recommendedAction = recommendedAction?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.reasonCodes = reasonCodes
            .map { $0.trimmingCharacters(
                in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.inferenceLatencyMs = max(0, inferenceLatencyMs)
    }
}

// MARK: - BASLayerMLHead — protocol slot for layer actors

/// ML head 协议。每 `BASLayerActor` 实现可以 (optionally) 声明一个
/// `mlHeadSlot: (any BASLayerMLHead)?` 来支持 cascading inference。
///
/// ## Doctrine pins
///
/// - **headID 稳定**:每 head 实例有固定 `headID`,用于 audit /
///   trace correlation。
/// - **kind 决定 cascade order**:`BASLayerMLHeadKind` 5 cases
///   按典型 latency 排序;chapter 三百一四+ cascading-inference
///   policy 用此选 head。
/// - **infer 是 hint**:输出 `recommendedAction` 是 hint,actor
///   仍是 verdict authority(红线 7)。
/// - **No mutual await**:head 内不应 await 其他 head 或 layer
///   actor — 走 typed Sendable input/output 解耦。
public protocol BASLayerMLHead: Sendable {
    /// Stable head identifier (audit + trace correlation 锚点)。
    var headID: String { get }

    /// Typed slot classifier (cascade order + device tiering 用)。
    var kind: BASLayerMLHeadKind { get }

    /// One-shot inference call。Async + throws (timeouts /
    /// model-unavailable / context-overflow 通过 typed Error
    /// 抛出)。
    func infer(
        input: BASLayerInferenceInput
    ) async throws -> BASLayerInferenceOutput
}
