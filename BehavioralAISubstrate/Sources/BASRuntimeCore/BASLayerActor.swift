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
public struct BASLayerActorInput: BASSchemaVersioned, Sendable, Hashable {
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
public struct BASLayerActorOutput: BASSchemaVersioned, Sendable, Hashable {
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

// MARK: - Pure semantic layer membrane values

public protocol BASSemanticLayerCore: Sendable {
    associatedtype Input: Codable & Sendable & Hashable
    associatedtype Output: Codable & Sendable & Hashable

    static var layerID: BASSemanticLayerID { get }

    func evaluate(
        _ input: Input
    ) throws -> BASLayerCoreDecision<Output>

    func resume(
        _ actorOutput: BASLayerActorOutput,
        input: Input
    ) throws -> Output
}

public enum BASLayerCoreDecision<
    Output: Codable & Sendable & Hashable
>: Codable, Sendable, Hashable {
    case emit(Output)
    case invoke(BASLayerActorInput)
    case remand(BASRemandArtifact)
    case refuse(BASRefusalArtifact)
}

public struct BASLayerCellIngressBody<
    Input: Codable & Sendable & Hashable
>: Codable, Sendable, Hashable {
    public static var currentSchemaVersion: String { "1.0.0" }

    public let inputArtifactID: BASArtifactID
    public let orderedParentArtifactIDs: [BASArtifactID]
    public let payload: Input
    public let grantArtifactID: BASArtifactID
    public let turnOperationRef: BASTurnOperationRef
    public let causalTurnBranchRef: BASTurnBranchRef?
    public let logicalEpoch: UInt64
    public let snapshotRootArtifactID: BASArtifactID
    public let killGeneration: UInt64
    public let revocationGeneration: UInt64
    public let monotonicDeadlineNanos: UInt64
    public let budget: BASLayerSlice

    public init(
        inputArtifactID: BASArtifactID,
        orderedParentArtifactIDs: [BASArtifactID],
        payload: Input,
        grantArtifactID: BASArtifactID,
        turnOperationRef: BASTurnOperationRef,
        causalTurnBranchRef: BASTurnBranchRef? = nil,
        logicalEpoch: UInt64,
        snapshotRootArtifactID: BASArtifactID,
        killGeneration: UInt64,
        revocationGeneration: UInt64,
        monotonicDeadlineNanos: UInt64,
        budget: BASLayerSlice
    ) {
        self.inputArtifactID = inputArtifactID
        self.orderedParentArtifactIDs = orderedParentArtifactIDs
        self.payload = payload
        self.grantArtifactID = grantArtifactID
        self.turnOperationRef = turnOperationRef
        self.causalTurnBranchRef = causalTurnBranchRef
        self.logicalEpoch = logicalEpoch
        self.snapshotRootArtifactID = snapshotRootArtifactID
        self.killGeneration = killGeneration
        self.revocationGeneration = revocationGeneration
        self.monotonicDeadlineNanos = monotonicDeadlineNanos
        self.budget = budget
    }
}

public typealias BASLayerCellIngress<
    Input: Codable & Sendable & Hashable
> = BASFrameEnvelope<BASLayerCellIngressBody<Input>>

public struct BASLayerCellEgressBody<
    Output: Codable & Sendable & Hashable
>: Codable, Sendable, Hashable {
    public let output: Output?
    public let outputArtifactID: BASArtifactID?
    public let capabilityUseReceiptArtifactID: BASArtifactID?
    public let orderedParentArtifactIDs: [BASArtifactID]
    public let terminalState: BASControlRingTerminalState

    fileprivate init(
        output: Output?,
        outputArtifactID: BASArtifactID?,
        capabilityUseReceiptArtifactID: BASArtifactID?,
        orderedParentArtifactIDs: [BASArtifactID],
        terminalState: BASControlRingTerminalState
    ) {
        self.output = output
        self.outputArtifactID = outputArtifactID
        self.capabilityUseReceiptArtifactID =
            capabilityUseReceiptArtifactID
        self.orderedParentArtifactIDs = orderedParentArtifactIDs
        self.terminalState = terminalState
    }
}

public typealias BASLayerCellEgress<
    Output: Codable & Sendable & Hashable
> = BASResult<BASLayerCellEgressBody<Output>>

public struct BASLayerCellMembraneContext: Sendable, Equatable {
    public let inputArtifactID: BASArtifactID
    public let orderedParentArtifactIDs: [BASArtifactID]
    public let grantArtifactID: BASArtifactID
    public let turnOperationRef: BASTurnOperationRef
    public let causalTurnBranchRef: BASTurnBranchRef?
    public let logicalEpoch: UInt64
    public let snapshotRootArtifactID: BASArtifactID
    public let killSwitchState: BASLayerKillSwitchState
    public let revocationGeneration: UInt64
    public let monotonicDeadlineNanos: UInt64
    public let monotonicNowNanos: UInt64
    public let budget: BASLayerSlice

    public init(
        inputArtifactID: BASArtifactID,
        orderedParentArtifactIDs: [BASArtifactID],
        grantArtifactID: BASArtifactID,
        turnOperationRef: BASTurnOperationRef,
        causalTurnBranchRef: BASTurnBranchRef? = nil,
        logicalEpoch: UInt64,
        snapshotRootArtifactID: BASArtifactID,
        killSwitchState: BASLayerKillSwitchState,
        revocationGeneration: UInt64,
        monotonicDeadlineNanos: UInt64,
        monotonicNowNanos: UInt64,
        budget: BASLayerSlice
    ) {
        self.inputArtifactID = inputArtifactID
        self.orderedParentArtifactIDs = orderedParentArtifactIDs
        self.grantArtifactID = grantArtifactID
        self.turnOperationRef = turnOperationRef
        self.causalTurnBranchRef = causalTurnBranchRef
        self.logicalEpoch = logicalEpoch
        self.snapshotRootArtifactID = snapshotRootArtifactID
        self.killSwitchState = killSwitchState
        self.revocationGeneration = revocationGeneration
        self.monotonicDeadlineNanos = monotonicDeadlineNanos
        self.monotonicNowNanos = monotonicNowNanos
        self.budget = budget
    }
}

public enum BASLayerCellError: Error, Sendable, Equatable {
    case unsupportedIngressSchema(found: String)
    case invalidArtifactID(field: String)
    case invalidKillSwitchAuthority
    case invalidBudgetProjection
    case inputArtifactMismatch
    case orderedParentArtifactsMismatch
    case grantMismatch
    case turnOperationMismatch
    case causalBranchMismatch
    case branchParentMismatch
    case logicalEpochMismatch
    case snapshotRootMismatch
    case revocationGenerationMismatch
    case deadlineMismatch
    case budgetMismatch
    case semanticActorLayerMismatch
    case budgetLayerMismatch
    case killSwitchLayerMismatch
    case killSwitchActive
    case killGenerationMismatch
    case killStateChanged
    case monotonicClockRegressed
    case deadlineExpired
    case invalidActorInputSchema(found: String)
    case coreActorLayerMismatch
    case preparedActorMismatch
    case mechanismNotRequested
    case actorOutputRequired
    case actorOutputForbidden
    case actorOutputMismatch
    case capabilityUseReceiptRequired
    case capabilityUseReceiptForbidden
}

public struct BASLayerActorMechanismAdapter<
    Actor: BASLayerActor
>: Sendable {
    public let actor: Actor

    public init(actor: Actor) {
        self.actor = actor
    }

    public func invoke(
        _ request: BASLayerActorInput,
        turnOperationRef: BASTurnOperationRef
    ) async throws -> BASLayerActorOutput {
        guard request.schemaVersion
                == BASLayerActorInput.currentSchemaVersion,
              actor.layerID == request.layerID
        else {
            throw BASLayerActorError.internalFailure(
                layerID: request.layerID,
                message: "actor input identity mismatch")
        }
        let legacyTurnID: String
        do {
            legacyTurnID = try turnOperationRef.canonicalLegacyProjection()
        } catch {
            throw BASLayerActorError.internalFailure(
                layerID: request.layerID,
                message: "actor input identity mismatch")
        }
        guard request.turnID == legacyTurnID else {
            throw BASLayerActorError.internalFailure(
                layerID: request.layerID,
                message: "actor input identity mismatch")
        }
        let output = try await actor.process(input: request)
        guard output.schemaVersion
                == BASLayerActorOutput.currentSchemaVersion,
              output.layerID == request.layerID,
              output.turnID == legacyTurnID
        else {
            throw BASLayerActorError.internalFailure(
                layerID: request.layerID,
                message: "actor identity mismatch")
        }
        return output
    }
}

public struct BASLayerCellPreparedState<
    Core: BASSemanticLayerCore,
    Actor: BASLayerActor
>: Sendable {
    public let ingress: BASLayerCellIngress<Core.Input>
    public let decision: BASLayerCoreDecision<Core.Output>

    public var requiresMechanism: Bool {
        if case .invoke = decision { return true }
        return false
    }

    fileprivate let validatedContext: BASLayerCellMembraneContext
    fileprivate let preparedCore: Core
    fileprivate let preparedMechanism: BASLayerActorMechanismAdapter<Actor>

    fileprivate init(
        ingress: BASLayerCellIngress<Core.Input>,
        decision: BASLayerCoreDecision<Core.Output>,
        validatedContext: BASLayerCellMembraneContext,
        preparedCore: Core,
        preparedMechanism: BASLayerActorMechanismAdapter<Actor>
    ) {
        self.ingress = ingress
        self.decision = decision
        self.validatedContext = validatedContext
        self.preparedCore = preparedCore
        self.preparedMechanism = preparedMechanism
    }
}

public struct BASLayerCellResolvedState<
    Core: BASSemanticLayerCore,
    Actor: BASLayerActor
>: Sendable {
    public let prepared: BASLayerCellPreparedState<Core, Actor>
    public let output: Core.Output?
    public let terminalState: BASControlRingTerminalState

    fileprivate init(
        prepared: BASLayerCellPreparedState<Core, Actor>,
        output: Core.Output?,
        terminalState: BASControlRingTerminalState
    ) {
        self.prepared = prepared
        self.output = output
        self.terminalState = terminalState
    }
}

private enum BASLayerCellValidation {
    static func artifactID(
        _ artifactID: BASArtifactID,
        field: String
    ) throws {
        do {
            _ = try artifactID.storageScalar
        } catch {
            throw BASLayerCellError.invalidArtifactID(field: field)
        }
    }

    static func artifactIDs(
        _ artifactIDs: [BASArtifactID],
        field: String
    ) throws {
        for (index, artifactID) in artifactIDs.enumerated() {
            try self.artifactID(
                artifactID,
                field: "\(field)[\(index)]")
        }
    }

    static func budgetProjection(_ budget: BASLayerSlice) throws {
        guard budget.schemaVersion == BASLayerSlice.currentSchemaVersion else {
            throw BASLayerCellError.invalidBudgetProjection
        }
        do {
            guard try budget.attenuated() == budget else {
                throw BASLayerCellError.invalidBudgetProjection
            }
        } catch let error as BASLayerCellError {
            throw error
        } catch {
            throw BASLayerCellError.invalidBudgetProjection
        }
    }

    static func killState(
        _ state: BASLayerKillSwitchState
    ) throws {
        let authority = state.authority
        let trimmed = authority.trimmingCharacters(
            in: .whitespacesAndNewlines)
        guard authority == trimmed,
              (1...256).contains(authority.utf8.count)
        else {
            throw BASLayerCellError.invalidKillSwitchAuthority
        }
        if let signature = state.signatureAttestationArtifactID {
            try artifactID(
                signature,
                field: "killSwitchState.signatureAttestationArtifactID")
        }
    }

    static func validate<Input>(
        _ ingress: BASLayerCellIngress<Input>,
        context: BASLayerCellMembraneContext,
        semanticLayerID: BASSemanticLayerID,
        actorLayerID: BASMotherboardLayer14
    ) throws where Input: Codable & Sendable & Hashable {
        guard ingress.header.schemaVersion
                == BASLayerCellIngressBody<Input>.currentSchemaVersion
        else {
            throw BASLayerCellError.unsupportedIngressSchema(
                found: ingress.header.schemaVersion)
        }

        try artifactID(
            ingress.body.inputArtifactID,
            field: "ingress.inputArtifactID")
        try artifactIDs(
            ingress.body.orderedParentArtifactIDs,
            field: "ingress.orderedParentArtifactIDs")
        try artifactID(
            ingress.body.grantArtifactID,
            field: "ingress.grantArtifactID")
        try artifactID(
            ingress.body.turnOperationRef.artifactID,
            field: "ingress.turnOperationRef.artifactID")
        if let branch = ingress.body.causalTurnBranchRef {
            try artifactID(
                branch.turnOperationRef.artifactID,
                field: "ingress.causalTurnBranchRef.turnOperationRef.artifactID")
        }
        try artifactID(
            ingress.body.snapshotRootArtifactID,
            field: "ingress.snapshotRootArtifactID")

        try artifactID(
            context.inputArtifactID,
            field: "context.inputArtifactID")
        try artifactIDs(
            context.orderedParentArtifactIDs,
            field: "context.orderedParentArtifactIDs")
        try artifactID(
            context.grantArtifactID,
            field: "context.grantArtifactID")
        try artifactID(
            context.turnOperationRef.artifactID,
            field: "context.turnOperationRef.artifactID")
        if let branch = context.causalTurnBranchRef {
            try artifactID(
                branch.turnOperationRef.artifactID,
                field: "context.causalTurnBranchRef.turnOperationRef.artifactID")
        }
        try artifactID(
            context.snapshotRootArtifactID,
            field: "context.snapshotRootArtifactID")
        try killState(context.killSwitchState)
        try budgetProjection(ingress.body.budget)
        try budgetProjection(context.budget)

        guard ingress.body.inputArtifactID == context.inputArtifactID else {
            throw BASLayerCellError.inputArtifactMismatch
        }
        guard ingress.body.orderedParentArtifactIDs
                == context.orderedParentArtifactIDs
        else {
            throw BASLayerCellError.orderedParentArtifactsMismatch
        }
        guard ingress.body.grantArtifactID == context.grantArtifactID else {
            throw BASLayerCellError.grantMismatch
        }
        guard ingress.body.turnOperationRef == context.turnOperationRef else {
            throw BASLayerCellError.turnOperationMismatch
        }
        guard ingress.body.causalTurnBranchRef
                == context.causalTurnBranchRef
        else {
            throw BASLayerCellError.causalBranchMismatch
        }
        if let branch = ingress.body.causalTurnBranchRef,
           branch.turnOperationRef != ingress.body.turnOperationRef
        {
            throw BASLayerCellError.branchParentMismatch
        }
        guard ingress.body.logicalEpoch == context.logicalEpoch else {
            throw BASLayerCellError.logicalEpochMismatch
        }
        guard ingress.body.snapshotRootArtifactID
                == context.snapshotRootArtifactID
        else {
            throw BASLayerCellError.snapshotRootMismatch
        }
        guard ingress.body.revocationGeneration
                == context.revocationGeneration
        else {
            throw BASLayerCellError.revocationGenerationMismatch
        }
        guard ingress.body.monotonicDeadlineNanos
                == context.monotonicDeadlineNanos
        else {
            throw BASLayerCellError.deadlineMismatch
        }
        guard ingress.body.budget == context.budget else {
            throw BASLayerCellError.budgetMismatch
        }

        let layerID = semanticLayerID.motherboardLayer14
        guard actorLayerID == layerID else {
            throw BASLayerCellError.semanticActorLayerMismatch
        }
        guard context.budget.layerID == layerID,
              ingress.body.budget.layerID == layerID
        else {
            throw BASLayerCellError.budgetLayerMismatch
        }
        guard context.killSwitchState.switchID.motherboardLayer == layerID else {
            throw BASLayerCellError.killSwitchLayerMismatch
        }
        guard !context.killSwitchState.active else {
            throw BASLayerCellError.killSwitchActive
        }
        guard ingress.body.killGeneration
                == context.killSwitchState.monotonicGeneration
        else {
            throw BASLayerCellError.killGenerationMismatch
        }
        guard context.monotonicNowNanos
                < context.monotonicDeadlineNanos
        else {
            throw BASLayerCellError.deadlineExpired
        }
    }

    static func canonicalDecision<Output>(
        _ decision: BASLayerCoreDecision<Output>,
        turnOperationRef: BASTurnOperationRef,
        semanticLayerID: BASSemanticLayerID
    ) throws -> BASLayerCoreDecision<Output>
    where Output: Codable & Sendable & Hashable {
        guard case let .invoke(proposed) = decision else {
            return decision
        }
        guard proposed.schemaVersion
                == BASLayerActorInput.currentSchemaVersion
        else {
            throw BASLayerCellError.invalidActorInputSchema(
                found: proposed.schemaVersion)
        }
        guard proposed.layerID == semanticLayerID.motherboardLayer14 else {
            throw BASLayerCellError.coreActorLayerMismatch
        }
        let canonicalTurnID = try turnOperationRef
            .canonicalLegacyProjection()
        var canonical = proposed
        canonical.turnID = canonicalTurnID
        return .invoke(canonical)
    }

    static func samePreparedContext(
        _ initial: BASLayerCellMembraneContext,
        _ fresh: BASLayerCellMembraneContext
    ) -> Bool {
        initial.inputArtifactID == fresh.inputArtifactID
            && initial.orderedParentArtifactIDs
                == fresh.orderedParentArtifactIDs
            && initial.grantArtifactID == fresh.grantArtifactID
            && initial.turnOperationRef == fresh.turnOperationRef
            && initial.causalTurnBranchRef == fresh.causalTurnBranchRef
            && initial.logicalEpoch == fresh.logicalEpoch
            && initial.snapshotRootArtifactID
                == fresh.snapshotRootArtifactID
            && initial.killSwitchState == fresh.killSwitchState
            && initial.revocationGeneration == fresh.revocationGeneration
            && initial.monotonicDeadlineNanos
                == fresh.monotonicDeadlineNanos
            && initial.budget == fresh.budget
    }

    static func validateActorOutput(
        _ output: BASLayerActorOutput,
        request: BASLayerActorInput
    ) throws {
        guard output.schemaVersion
                == BASLayerActorOutput.currentSchemaVersion,
              output.layerID == request.layerID,
              output.turnID == request.turnID
        else {
            throw BASLayerCellError.actorOutputMismatch
        }
    }
}

// BEGIN BASLayerCell
public struct BASLayerCell<
    Core: BASSemanticLayerCore,
    Actor: BASLayerActor
>: Sendable {
    public let core: Core
    public let mechanism: BASLayerActorMechanismAdapter<Actor>

    public init(core: Core, actor: Actor) {
        self.core = core
        self.mechanism = BASLayerActorMechanismAdapter(actor: actor)
    }

    public func prepare(
        _ ingress: BASLayerCellIngress<Core.Input>,
        context: BASLayerCellMembraneContext
    ) throws -> BASLayerCellPreparedState<Core, Actor> {
        try BASLayerCellValidation.validate(
            ingress,
            context: context,
            semanticLayerID: Core.layerID,
            actorLayerID: mechanism.actor.layerID)
        let proposed = try core.evaluate(ingress.body.payload)
        let decision = try BASLayerCellValidation.canonicalDecision(
            proposed,
            turnOperationRef: ingress.body.turnOperationRef,
            semanticLayerID: Core.layerID)
        return BASLayerCellPreparedState(
            ingress: ingress,
            decision: decision,
            validatedContext: context,
            preparedCore: core,
            preparedMechanism: mechanism)
    }

    public func revalidateAndInvoke(
        _ prepared: BASLayerCellPreparedState<Core, Actor>,
        context freshContext: BASLayerCellMembraneContext
    ) async throws -> BASLayerActorOutput {
        guard prepared.preparedMechanism.actor === mechanism.actor else {
            throw BASLayerCellError.preparedActorMismatch
        }
        guard case let .invoke(request) = prepared.decision else {
            throw BASLayerCellError.mechanismNotRequested
        }
        try BASLayerCellValidation.validate(
            prepared.ingress,
            context: freshContext,
            semanticLayerID: Core.layerID,
            actorLayerID: mechanism.actor.layerID)
        guard BASLayerCellValidation.samePreparedContext(
            prepared.validatedContext,
            freshContext)
        else {
            throw BASLayerCellError.killStateChanged
        }
        guard freshContext.monotonicNowNanos
                >= prepared.validatedContext.monotonicNowNanos
        else {
            throw BASLayerCellError.monotonicClockRegressed
        }
        let output = try await mechanism.invoke(
            request,
            turnOperationRef: prepared.ingress.body.turnOperationRef)
        return output
    }

    public func resume(
        _ prepared: BASLayerCellPreparedState<Core, Actor>,
        actorOutput: BASLayerActorOutput?
    ) throws -> BASLayerCellResolvedState<Core, Actor> {
        switch prepared.decision {
        case let .emit(output):
            guard actorOutput == nil else {
                throw BASLayerCellError.actorOutputForbidden
            }
            return BASLayerCellResolvedState(
                prepared: prepared,
                output: output,
                terminalState: .converged)
        case let .invoke(request):
            guard let actorOutput else {
                throw BASLayerCellError.actorOutputRequired
            }
            try BASLayerCellValidation.validateActorOutput(
                actorOutput,
                request: request)
            let output = try prepared.preparedCore.resume(
                actorOutput,
                input: prepared.ingress.body.payload)
            return BASLayerCellResolvedState(
                prepared: prepared,
                output: output,
                terminalState: .converged)
        case .remand:
            guard actorOutput == nil else {
                throw BASLayerCellError.actorOutputForbidden
            }
            return BASLayerCellResolvedState(
                prepared: prepared,
                output: nil,
                terminalState: .deferred)
        case .refuse:
            guard actorOutput == nil else {
                throw BASLayerCellError.actorOutputForbidden
            }
            return BASLayerCellResolvedState(
                prepared: prepared,
                output: nil,
                terminalState: .rejected)
        }
    }

    public func makeEgress(
        from resolved: BASLayerCellResolvedState<Core, Actor>,
        outputArtifactID: BASArtifactID,
        capabilityUseReceiptArtifactID: BASArtifactID?
    ) throws -> BASLayerCellEgress<Core.Output> {
        try BASLayerCellValidation.artifactID(
            outputArtifactID,
            field: "outputArtifactID")
        if let capabilityUseReceiptArtifactID {
            try BASLayerCellValidation.artifactID(
                capabilityUseReceiptArtifactID,
                field: "capabilityUseReceiptArtifactID")
        }
        let success: Bool
        switch resolved.prepared.decision {
        case .invoke:
            guard capabilityUseReceiptArtifactID != nil else {
                throw BASLayerCellError.capabilityUseReceiptRequired
            }
            success = true
        case .emit:
            guard capabilityUseReceiptArtifactID == nil else {
                throw BASLayerCellError.capabilityUseReceiptForbidden
            }
            success = true
        case .remand, .refuse:
            guard capabilityUseReceiptArtifactID == nil else {
                throw BASLayerCellError.capabilityUseReceiptForbidden
            }
            success = false
        }
        return BASResult(
            success: success,
            body: BASLayerCellEgressBody(
                output: resolved.output,
                outputArtifactID: outputArtifactID,
                capabilityUseReceiptArtifactID:
                    capabilityUseReceiptArtifactID,
                orderedParentArtifactIDs:
                    resolved.prepared.ingress.body
                        .orderedParentArtifactIDs,
                terminalState: resolved.terminalState),
            diagnostics: [])
    }
}
// END BASLayerCell

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
