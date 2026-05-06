// MARK: - BASLayerActor — chapter 二百九十九 / M786
//
// Phase Beta 第一刀:Per-layer concurrency foundation。Phase Alpha
// (chapters 二百七十五 → 二百九十八)把 4 个 god file + 1 个 god test
// file 拆成 layer-isolated files;Phase Beta 在那个 file 划分上面盖
// 上 typed actor + budget slice + ML head slot 协议层。
//
// ## 这一刀 ship 什么
//
// 4 个 typed value-types + 1 个 protocol:
//
//   - `BASLayerActorInput` (BASSchemaVersioned 1.0.0) — per-layer
//     input frame: layer ID / turn ID / payload reference / arrival
//     time / parent layer ref(可选)
//   - `BASLayerActorOutput` (BASSchemaVersioned 1.0.0) — per-layer
//     output frame: layer ID / turn ID / status / payload reference
//     / latency ms / confidence / reason codes
//   - `BASLayerActorStatus` (8-case) — completed / skippedByGate /
//     skippedByKill / errorBoundaryHandled / budgetExceeded /
//     mlHeadFallthrough / partial / quarantined
//   - `BASLayerInferenceConfidence` (4-case) — high / medium / low /
//     unknown — used by ML cascade fallthrough policy
//   - `BASLayerActor` protocol — `layerID: BASMotherboardLayer14` +
//     `process(input:) async throws -> BASLayerActorOutput`
//
// ## Why a protocol now
//
// Phase Beta later cuts (chapters 三百 / 三百〇一) add `BASLayerSlice`
// per-layer budget + 14-case `BASKillSwitchID` + ML head slot. By
// shipping the protocol contract first, the later cuts can be
// purely additive (extend the protocol or add associated types).
//
// **0 behavior change**:purely additive new file, no existing
// runtime code changes。Phase Alpha file split is the prerequisite
// — each layer's types now live in its own file (e.g.
// `EBrainL2NeuralOrganCore.swift` for L2),so wiring future actor
// conformance to those types is a localized edit per file。
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 (no L1 wake / L2 weight / L3 audit
//     path changes)
//   - 红线 7 watcher hint only:layer actors are observation +
//     budgeting boundary,不是 verdict logic boundary
//   - 单提交口 (L11 permit / L14 warrant single commit mouth) 不变
//   - chapter 二百一一 single-source-of-truth: protocol owned by
//     this file, typed inputs/outputs owned by this file
//   - chapter 一百八十五 anti-magic-number: status enum 8 cases,
//     confidence enum 4 cases — 全部 typed,no magic strings
//   - chapter 二百一一 doctrine D actor matrix preserved: this is
//     internal substrate concurrency primitive, not a new actor

import Foundation

// MARK: - Confidence enum (used by ML cascade fallthrough)

/// L2 ML head inference confidence tier。`high` 不需 cascade,
/// `medium` 可考虑 cascade 到更强 head,`low` 强制 cascade,
/// `unknown` 表示 head 没回 confidence(treat as `low`)。
///
/// 4 cases match chapter 一百三十 typed enum doctrine + chapter
/// 一百七十七 cascading inference design (rules → small ML →
/// big ML → AFM → cloud LLM).
public enum BASLayerInferenceConfidence:
    String,
    Sendable,
    Equatable,
    Hashable,
    Codable,
    CaseIterable
{
    case high
    case medium
    case low
    case unknown
}

// MARK: - Status enum (output dispatch)

/// L1-L14 layer actor 处理结果状态。每 case 对应一种 audit code
/// reason prefix(chapter 二百一一 single-source-of-truth)。
///
/// 8 cases:
///   - `completed` — normal completion
///   - `skippedByGate` — gate condition declined to fire (e.g.
///     L11 permit 已 issue,L9 dream loop 不必跑)
///   - `skippedByKill` — kill switch fired (chapter 三百〇一+)
///   - `errorBoundaryHandled` — typed error caught + graceful skip
///   - `budgetExceeded` — per-layer budget slice exceeded
///   - `mlHeadFallthrough` — ML head returned `low`/`unknown`
///     confidence,fall back to rules logic (chapter 三百一三+
///     CoreML mesh)
///   - `partial` — layer ran but emitted only partial output
///     (e.g. L9 dream loop ran 1 candidate not full set)
///   - `quarantined` — L14 sovereign quarantine asserted
public enum BASLayerActorStatus:
    String,
    Sendable,
    Equatable,
    Hashable,
    Codable,
    CaseIterable
{
    case completed
    case skippedByGate = "skipped-by-gate"
    case skippedByKill = "skipped-by-kill"
    case errorBoundaryHandled = "error-boundary-handled"
    case budgetExceeded = "budget-exceeded"
    case mlHeadFallthrough = "ml-head-fallthrough"
    case partial
    case quarantined
}

// MARK: - Input frame

/// L1-L14 layer actor 输入 frame。Per-call typed input。
///
/// Field semantics:
///   - `layerID` — which layer is processing
///   - `turnID` — substrate turn ID (chapter 二百一一 audit chain
///     anchor)
///   - `payloadRef` — opaque payload identifier; actor implementations
///     resolve through their own context. Schema-level pin: every
///     input has a stable ID for trace correlation.
///   - `parentLayerID` — previous layer in pipeline if applicable;
///     nil for entry points (L1 wake) and parallel layers
///   - `arrivedAt` — wall-clock arrival time; latency math anchor
///   - `correlationID` — caller-supplied correlation token (e.g.
///     audit ID, request ID); chains across multi-turn flows
public struct BASLayerActorInput: BASSchemaVersioned, Sendable {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var layerID: BASMotherboardLayer14
    public var turnID: String
    public var payloadRef: String
    public var parentLayerID: BASMotherboardLayer14?
    public var arrivedAt: Date
    public var correlationID: String?

    public init(
        schemaVersion: String = BASLayerActorInput.currentSchemaVersion,
        layerID: BASMotherboardLayer14,
        turnID: String,
        payloadRef: String,
        parentLayerID: BASMotherboardLayer14? = nil,
        arrivedAt: Date,
        correlationID: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.layerID = layerID
        self.turnID = turnID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.payloadRef = payloadRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.parentLayerID = parentLayerID
        self.arrivedAt = arrivedAt
        self.correlationID = correlationID?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Output frame

/// L1-L14 layer actor 输出 frame。Per-call typed output。
///
/// Field semantics:
///   - `layerID` — which layer produced this output
///   - `turnID` — substrate turn ID (chains with input.turnID)
///   - `status` — typed result status (8 cases)
///   - `payloadRef` — opaque output identifier (caller resolves)
///   - `latencyMs` — wall-clock processing latency in milliseconds
///     (clamped to ≥0)
///   - `confidence` — inference confidence if ML head fired,
///     `.unknown` otherwise
///   - `reasonCodes` — typed reason code list (chapter 二百一一
///     audit doctrine);kebab-case strings,匹配 lint helpers
///   - `producedAt` — wall-clock completion time
public struct BASLayerActorOutput: BASSchemaVersioned, Sendable {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var layerID: BASMotherboardLayer14
    public var turnID: String
    public var status: BASLayerActorStatus
    public var payloadRef: String?
    public var latencyMs: Double
    public var confidence: BASLayerInferenceConfidence
    public var reasonCodes: [String]
    public var producedAt: Date

    public init(
        schemaVersion: String = BASLayerActorOutput.currentSchemaVersion,
        layerID: BASMotherboardLayer14,
        turnID: String,
        status: BASLayerActorStatus,
        payloadRef: String? = nil,
        latencyMs: Double = 0,
        confidence: BASLayerInferenceConfidence = .unknown,
        reasonCodes: [String] = [],
        producedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.layerID = layerID
        self.turnID = turnID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.status = status
        self.payloadRef = payloadRef?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.latencyMs = max(0, latencyMs)
        self.confidence = confidence
        self.reasonCodes = reasonCodes
            .map { $0.trimmingCharacters(
                in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.producedAt = producedAt
    }
}

// MARK: - Layer actor protocol

/// L1-L14 layer actor 协议。每 layer 的处理边界:
/// `process(input:) async throws -> output`。
///
/// ## Doctrine pins
///
/// - **Layer ID identity**: `layerID` 必须返回固定值 — 一个 actor
///   实例只服务一 layer。Layer routing is done at construction
///   time, not at call time。
/// - **Async-throws contract**: `process` 是 async + throws,
///   layer 内部 budget overflow / kill switch 抛 typed error,
///   coordinator 捕获并 graceful skip(chapter 三百〇一 error
///   boundary)。
/// - **No mutual await**: layer A 的 `process` 不应 await layer B
///   的 actor — turn coordinator 单向调度,layer 间通过 audit
///   ledger / shared bus 解耦。
/// - **Output 必须含 turnID**: `process` 返回的 output.turnID 必须
///   等于 input.turnID(audit chain integrity)。
///
/// ## Future cuts(chapter 三百+)
///
/// - chapter 三百 加 `currentBudget: BASLayerSlice` 默认 property
/// - chapter 三百〇一 加 `mlHeadSlot: (any BASLayerMLHead)?` 默认
///   property + cascading inference logic
public protocol BASLayerActor: Actor {
    /// Which layer this actor serves。固定值,不在 process 中变化。
    nonisolated var layerID: BASMotherboardLayer14 { get }

    /// Process one layer-level input frame, returning a typed
    /// output frame。Async + throws; budget overflow / kill switch
    /// throws typed errors that the turn coordinator catches.
    func process(
        input: BASLayerActorInput
    ) async throws -> BASLayerActorOutput
}

// MARK: - Typed error boundary

/// `BASLayerActor.process` 可抛的 typed errors。Chapter 三百〇一
/// per-layer error boundary 使用此 enum 区分 fail-safe 路径。
///
/// 5 cases:
///   - `budgetExceeded(layerID, allowedMs)` — per-layer budget
///     slice 用尽
///   - `killSwitchActive(layerID, reason)` — chapter 三百〇一 kill
///     switch fired
///   - `dependencyMissing(layerID, missingRef)` — required upstream
///     payload not available
///   - `quarantine(layerID, reason)` — L14 sovereign quarantine
///   - `internalFailure(layerID, message)` — fail-safe escape hatch;
///     coordinator graceful skip + audit
public enum BASLayerActorError: Error, Sendable, Equatable {
    case budgetExceeded(
        layerID: BASMotherboardLayer14,
        allowedMs: Double
    )
    case killSwitchActive(
        layerID: BASMotherboardLayer14,
        reason: String
    )
    case dependencyMissing(
        layerID: BASMotherboardLayer14,
        missingRef: String
    )
    case quarantine(
        layerID: BASMotherboardLayer14,
        reason: String
    )
    case internalFailure(
        layerID: BASMotherboardLayer14,
        message: String
    )
}
