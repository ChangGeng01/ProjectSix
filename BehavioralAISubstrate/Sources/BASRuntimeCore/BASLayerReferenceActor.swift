// MARK: - BASLayerReferenceActor — chapter 三百一六 / M803
//
// Phase Epsilon 第三刀:reference implementation of `BASLayerActor`
// that demonstrates correct integration of Phase Beta + Delta
// foundations。Hosts implementing concrete layer actors copy this
// pattern instead of figuring out the typed-primitive composition
// from scratch。
//
// chapter 二百九十九 (M786) shipped `BASLayerActor` protocol。
// chapter 三百 (M787) shipped `BASLayerSlice` + `BASLayerMLHead`。
// chapter 三百〇一 (M788) shipped `BASLayerKillSwitchID` + error
// boundary。
// chapter 三百一〇 (M797) shipped `BASLayerMLHeadRegistry`。
// chapter 三百一二 (M799) shipped `BASLayerCascadeRunner`。
//
// **This chapter** (chapter 三百一六, M803) ships a CONCRETE actor
// that wires all of those together,with budget enforcement +
// kill switch checks + ML head cascade + typed error boundary +
// audit trail emission。Pure additive — no production path
// changes;just a reference + test fixture pattern。
//
// ## What this ships
//
// 1 typed actor + 1 typed value type:
//
//   - `BASLayerReferenceActor` — concrete `BASLayerActor`
//     conformer with full Phase Beta + Delta integration
//     (budget tracking + kill switch consultation + ML head
//     registry walk via cascade runner + typed error boundary
//     + audit trail composition)
//   - `BASLayerReferenceActorConfig` — typed configuration
//     bundle (layerID + budget + registry reference + kill
//     switch state lookup closure)
//
// ## Usage pattern
//
//     let registry = BASLayerMLHeadRegistry()
//     // ... register heads ...
//
//     let config = BASLayerReferenceActorConfig(
//         layerID: .l4,
//         budget: BASLayerSlice(
//             layerID: .l4,
//             allocatedMs: 50,
//             hardCapMs: 200),
//         registry: registry,
//         killSwitchLookup: { _ in nil })
//     let actor = BASLayerReferenceActor(config: config)
//
//     let input = BASLayerActorInput(
//         layerID: .l4,
//         turnID: "turn-1",
//         payloadRef: "payload-1",
//         arrivedAt: .now)
//     let output = try await actor.process(input: input)
//     // output.status / output.confidence / output.reasonCodes
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — reference actor is hint-class,
//     never gates verdict authority
//   - 红线 7 watcher hint only — actor walks ML hints, layer
//     coordinator decides whether to act on winning hint
//   - 单提交口 (L11/L14) 不变 — reference actor doesn't issue
//     permits/warrants
//   - chapter 二百一一 single-source-of-truth: ONE reference
//     pattern (vs N hosts each writing their own boilerplate)
//   - chapter 一百八十五 anti-magic-number: budget thresholds
//     come from BASLayerSlice typed config
//   - chapter 二百九十九 BASLayerActor protocol: this is the
//     canonical conformer
//   - chapter 三百〇一 BASLayerErrorBoundaryReport.from(error:)
//     doctrine pins (L1 abortTurn / L11/L14 sovereignEscalate /
//     etc) — reference actor's catch path uses the typed
//     derive helper

import Foundation

// MARK: - Reference actor configuration

/// Typed configuration bundle for `BASLayerReferenceActor`。
/// Keeps actor init signature compact + audit-friendly。
public struct BASLayerReferenceActorConfig: Sendable {
    public let layerID: BASMotherboardLayer14
    public let budget: BASLayerSlice
    public let registry: BASLayerMLHeadRegistry
    /// Closure that returns the current kill switch state for
    /// this layer's switchID。Caller-supplied so reference actor
    /// doesn't depend on a global kill switch store。Returning
    /// nil = switch not active。
    public let killSwitchLookup:
        @Sendable (BASLayerKillSwitchID)
            -> BASLayerKillSwitchState?

    public init(
        layerID: BASMotherboardLayer14,
        budget: BASLayerSlice,
        registry: BASLayerMLHeadRegistry,
        killSwitchLookup:
            @escaping @Sendable (BASLayerKillSwitchID)
                -> BASLayerKillSwitchState?
    ) {
        self.layerID = layerID
        self.budget = budget
        self.registry = registry
        self.killSwitchLookup = killSwitchLookup
    }
}

// MARK: - Reference actor

/// Reference implementation of `BASLayerActor`。Demonstrates correct
/// integration of all Phase Beta + Delta typed primitives in one
/// concrete actor。
///
/// ## Process pipeline
///
/// `process(input:)` walks 5 stages in sequence. Each stage may
/// short-circuit to typed status:
///
/// 1. **Kill switch check** — query `killSwitchLookup`. Active
///    switch → return `BASLayerActorOutput(status: .skippedByKill)`.
///
/// 2. **Budget enforcement check** — log start time. Will check
///    elapsed against `budget.hardCapMs` after stage 4.
///
/// 3. **ML head cascade** — convert `BASLayerActorInput` to
///    `BASLayerInferenceInput`, run cascade via
///    `BASLayerCascadeRunner.run`. Outcome classifies status:
///    - `.headMatched` / `.floorMet` → completed (with cascade hint)
///    - `.fallenThrough` → mlHeadFallthrough (caller falls back
///      to its own logic — reference actor returns partial output
///      with cascade trail in reasonCodes)
///    - `.noHeadsRegistered` → completed-no-mesh (caller falls
///      back to its own logic)
///
/// 4. **Budget cap check** — if elapsed > hardCapMs, return
///    `BASLayerActorOutput(status: .budgetExceeded)`.
///
/// 5. **Compose typed output** — combine input + cascade result
///    + budget metadata into typed `BASLayerActorOutput`.
public actor BASLayerReferenceActor: BASLayerActor {

    public nonisolated let layerID: BASMotherboardLayer14

    private let config: BASLayerReferenceActorConfig

    public init(config: BASLayerReferenceActorConfig) {
        self.layerID = config.layerID
        self.config = config
    }

    public func process(
        input: BASLayerActorInput
    ) async throws -> BASLayerActorOutput {
        let startTime = Date()
        var reasonCodes: [String] = []

        // Stage 1: kill switch check
        let switchID = BASLayerKillSwitchID.forLayer(
            config.layerID)
        if let killState = config.killSwitchLookup(switchID),
           killState.active
        {
            reasonCodes.append(
                "kill-switch:active:\(killState.reason.rawValue)")
            return BASLayerActorOutput(
                layerID: config.layerID,
                turnID: input.turnID,
                status: .skippedByKill,
                latencyMs: elapsedMs(since: startTime),
                confidence: .unknown,
                reasonCodes: reasonCodes,
                producedAt: Date())
        }

        // Stage 2: log layer start (budget tracking begins)
        reasonCodes.append("layer-start:\(config.layerID.rawValue)")
        reasonCodes.append(
            "budget:allocated-ms:\(config.budget.allocatedMs)")
        reasonCodes.append(
            "budget:hard-cap-ms:\(config.budget.hardCapMs)")

        // Stage 3: ML head cascade
        let inferenceInput = BASLayerInferenceInput(
            layerID: input.layerID,
            featureRef: input.payloadRef,
            confidenceFloor: .medium,
            correlationID: input.correlationID)

        let cascadeResult: BASLayerCascadeResult
        do {
            cascadeResult = try await BASLayerCascadeRunner.run(
                input: inferenceInput,
                registry: config.registry,
                layerID: config.layerID)
        } catch {
            // Cascade error → typed error boundary report
            let report = BASLayerErrorBoundaryReport.from(
                error: BASLayerActorError.internalFailure(
                    layerID: config.layerID,
                    message: "cascade-error:\(error)"),
                capturedAt: Date())
            reasonCodes.append(
                "cascade-error:\(report.errorKind)")
            reasonCodes.append(
                "fallthrough-strategy:" +
                report.fallthroughStrategy.rawValue)
            return BASLayerActorOutput(
                layerID: config.layerID,
                turnID: input.turnID,
                status: .errorBoundaryHandled,
                latencyMs: elapsedMs(since: startTime),
                confidence: .unknown,
                reasonCodes: reasonCodes,
                producedAt: Date())
        }

        // Append cascade reason codes to actor's audit trail
        reasonCodes.append(
            contentsOf: BASLayerCascadeRunner.reasonCodes(
                for: cascadeResult))

        // Stage 4: budget cap check
        let elapsedAtCap = elapsedMs(since: startTime)
        if elapsedAtCap > config.budget.hardCapMs {
            reasonCodes.append(
                "budget:cap-exceeded:" +
                "\(elapsedAtCap)>\(config.budget.hardCapMs)")
            return BASLayerActorOutput(
                layerID: config.layerID,
                turnID: input.turnID,
                status: .budgetExceeded,
                latencyMs: elapsedAtCap,
                confidence: cascadeResult
                    .matchedOutput?.confidence ?? .unknown,
                reasonCodes: reasonCodes,
                producedAt: Date())
        }

        // Stage 5: compose typed output
        let status: BASLayerActorStatus
        let confidence: BASLayerInferenceConfidence
        let payloadRef: String?

        switch cascadeResult.outcome {
        case .headMatched, .floorMet:
            status = .completed
            confidence = cascadeResult
                .matchedOutput?.confidence ?? .unknown
            payloadRef = cascadeResult.matchedHeadID
        case .fallenThrough:
            status = .mlHeadFallthrough
            confidence = .unknown
            payloadRef = nil
        case .noHeadsRegistered:
            // No mesh available — return partial completion
            status = .partial
            confidence = .unknown
            payloadRef = nil
        }

        return BASLayerActorOutput(
            layerID: config.layerID,
            turnID: input.turnID,
            status: status,
            payloadRef: payloadRef,
            latencyMs: elapsedMs(since: startTime),
            confidence: confidence,
            reasonCodes: reasonCodes,
            producedAt: Date())
    }

    // MARK: - Helpers

    private func elapsedMs(since startTime: Date) -> Double {
        Date().timeIntervalSince(startTime) * 1000
    }
}
