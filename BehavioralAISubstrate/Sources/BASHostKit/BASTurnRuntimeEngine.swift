// MARK: - BASTurnRuntimeEngine — chapter 四百四 / M968
// 系统熵 reduction 第二章 第六刀
//
// Phase 2 entropy chapter 四百四 sixth cut:V2 runtime engine
// actor that wraps `BASEBrainRuntimeCoordinator` (V1 struct)
// and adds the M963 lifecycle audit channel (`turn:complete`
// envelope emission)。Pure delegation V1 invocation;byte-equal
// `BASEBrainTurnResult`。 Future commits incrementally replace
// stages with native V2 actor logic。
//
// ## Why this exists (system entropy framing)
//
// Per the chapter 四百三 entropy audit + M932 LLM Engine
// pattern:
//
//   > V1 runTurn has no per-turn lifecycle channel comparable
//   > to M932 LLM Engine's start/complete event pair。 V2
//   > actor centralizes audit emission via
//   > BASTurnRuntimeAuditEnvelope。
//
// V2 actor's first-shipped surface (M968) is just delegation
// + complete-envelope emission。 V1 stays unchanged。 Hosts
// opt into V2 by constructing a `BASTurnRuntimeEngine`
// wrapping their existing coordinator + an event log。
//
// ## What this ships (M968)
//
//   - `BASTurnRuntimeEngine` actor with:
//       * coordinator: BASEBrainRuntimeCoordinator (held by ref-
//         like value semantics — struct copies are cheap +
//         immutable services keep working)
//       * eventLog: any BASEventLogStorage? (optional)
//       * sequenceCounter: per-engine monotonic sequence
//   - `runTurn(_:timestampMsOverride:)` async method
//   - When `eventLog` is wired,emits a `.complete` envelope
//     after V1 returns,with payloadJson built from
//     `BASRuntimeAuditEmissionSummary` (M967)
//   - `.start` envelope deferred to future commit (requires
//     pre-V1 sessionID/turnID derivation,which needs context
//     analysis we can't easily replicate at the V2 surface
//     yet)
//
// ## Doctrine pins held
//
//   - All chapter 四百三/四百四 doctrine pins
//   - chapter 二百一一 single-source-of-truth — V2's audit
//     emission collapses through ONE envelope channel
//   - chapter 三百九二 (M892) replay-determinism — pure
//     delegation + sorted-keys JSON encoding produces byte-
//     stable output for same input
//   - ADR-014 OPT-IN — V1 coordinator unchanged;hosts opt
//     into V2 by wrapping

import Foundation
import BASOrchestration
import BASRuntimeCore
import BASMetalSubstrate

/// V2 runtime engine actor wrapping V1 `BASEBrainRuntimeCoordinator`
/// + adding the M963 lifecycle audit channel。
public actor BASTurnRuntimeEngine {

    // MARK: - Dependencies

    private let coordinator: BASEBrainRuntimeCoordinator
    private let eventLog: (any BASEventLogStorage)?
    private let eventIDFactory: @Sendable () -> String
    private let clockMs: @Sendable () -> Int64

    // MARK: - Phase F wiring (M1101)

    /// Runtime mode from M1100 configuration bundle。
    /// Dispatched on by `runWithPlan(...)` to choose the
    /// V1-byte-equal vs native-V2 vs stress-sweep-dual
    /// path。 At M1101 only `.v1ByteEqual` is wired into
    /// behavior;the other modes carry forward but still
    /// fall through to the V1 path until the M1102
    /// scheduler + M1103 dual-mode harness ship。
    private let runtimeMode: BASTurnRuntimeMode

    /// Optional kernel dispatch table from M1100
    /// configuration。 Captured into the dispatch probe
    /// every `runWithPlan` call so audit consumers see
    /// "registry of N kernels was visible at dispatch"。
    private let metalKernelRegistry:
        BASMetalKernelRegistry?

    /// Optional ANE capability snapshot from M1100
    /// configuration。 Captured into the dispatch probe;
    /// future M1102 scheduler reads it to make routing
    /// decisions。
    private let aneCapability: BASANECapability?

    // MARK: - Mutable state (actor-isolated)

    private var sequenceCounter: Int = 0

    /// Most-recent `BASTurnRuntimePlanDispatchProbe`
    /// captured by `runWithPlan(...)`。 `unwired()` until
    /// the first `runWithPlan` call。 Surfaced via the
    /// `lastPlanDispatchProbe()` accessor for tests + the
    /// M1102 scheduler + audit consumers。
    private var lastProbe: BASTurnRuntimePlanDispatchProbe =
        .unwired()

    // MARK: - Init

    public init(
        coordinator: BASEBrainRuntimeCoordinator,
        eventLog: (any BASEventLogStorage)? = nil,
        eventIDFactory: @escaping @Sendable () -> String =
            { UUID().uuidString },
        clockMs: @escaping @Sendable () -> Int64 =
            { Int64(Date().timeIntervalSince1970 * 1000) },
        runtimeMode: BASTurnRuntimeMode = .v1ByteEqual,
        metalKernelRegistry:
            BASMetalKernelRegistry? = nil,
        aneCapability: BASANECapability? = nil
    ) {
        self.coordinator = coordinator
        self.eventLog = eventLog
        self.eventIDFactory = eventIDFactory
        self.clockMs = clockMs
        self.runtimeMode = runtimeMode
        self.metalKernelRegistry = metalKernelRegistry
        self.aneCapability = aneCapability
    }

    /// chapter 四百七 / M998 — convenience init taking the
    /// typed `BASTurnRuntimeEngineConfiguration` bundle (M998)
    /// instead of 4 separate params。 Hosts construct one
    /// config + reuse across multiple actor instances or host
    /// runtime restarts。
    ///
    /// chapter 四百三十二 / M1101 extension:bundle now also
    /// carries `runtimeMode` + `metalKernelRegistry` +
    /// `aneCapability`,which the engine threads into its
    /// dispatch probe + dispatch path。
    public init(
        coordinator: BASEBrainRuntimeCoordinator,
        configuration: BASTurnRuntimeEngineConfiguration
    ) {
        self.init(
            coordinator: coordinator,
            eventLog: configuration.eventLog,
            eventIDFactory: configuration.eventIDFactory,
            clockMs: configuration.clockMs,
            runtimeMode: configuration.runtimeMode,
            metalKernelRegistry:
                configuration.metalKernelRegistry,
            aneCapability: configuration.aneCapability)
    }

    // MARK: - Phase F dispatch probe accessor (M1101)

    /// Returns the most-recent probe captured by
    /// `runWithPlan(...)`。 Returns `.unwired()` until the
    /// first call。 Used by tests + audit consumers + the
    /// M1102 hardware-aware scheduler to verify the M1100
    /// configuration slots are actually consulted at
    /// dispatch time。
    public func lastPlanDispatchProbe()
        -> BASTurnRuntimePlanDispatchProbe
    {
        return lastProbe
    }

    /// Build a probe from the current engine state without
    /// requiring a `runWithPlan` call first。 Reads live
    /// kernel registry count + capability accelerator
    /// priority。 Used by the M1102 scheduler at scheduling
    /// time。
    public func currentDispatchProbe() async
        -> BASTurnRuntimePlanDispatchProbe
    {
        let registryCount: Int
        if let registry = metalKernelRegistry {
            registryCount = await registry.kernelCount
        } else {
            registryCount = 0
        }
        let priority = aneCapability?
            .acceleratorPriority ?? .gpuOnly
        let supportedCount = aneCapability?
            .supportedOps.count ?? 0
        return BASTurnRuntimePlanDispatchProbe(
            runtimeMode: runtimeMode,
            kernelRegistryCount: registryCount,
            aneAcceleratorPriority: priority,
            aneSupportedOpCount: supportedCount)
    }

    // MARK: - runTurn

    /// V2 runTurn:delegates to V1 coordinator,then emits a
    /// `.complete` audit envelope on the wired event log
    /// (when present)。Byte-equal to V1's result。
    ///
    /// chapter 四百六 / M989:`auditProjections` parameter
    /// added。 Hosts pre-build the M976
    /// `BASRuntimeAuditProjectionsBundle` (5 namespace slots
    /// for kunlun / abyssal / cthulhu / tribunal /
    /// riskCalibration) and pass it here。 The V2 actor
    /// surfaces the bundle's `populatedSlotCount` in the
    /// `.complete` envelope payload for downstream audit
    /// consumers。
    public func runTurn(
        _ request: BASEBrainTurnRequest,
        auditProjections:
            BASRuntimeAuditProjectionsBundle? = nil,
        permitEscalationLedger:
            BASPermitEscalationLedger? = nil,
        stageLedger:
            BASTurnRuntimeStageLedger? = nil,
        stagePlan:
            BASTurnRuntimeStagePlan? = nil,
        timestampMsOverride: Int64? = nil
    ) async -> BASEBrainTurnResult {
        let result = coordinator.runTurn(request)
        // chapter 四百六 / M991: V2 actor now emits BOTH .start
        // and .complete lifecycle envelopes per turn。 Both fire
        // post-V1 so they share the V1-derived sessionID/turnID
        // (audit-consistent;sacrifices "start fires before V1"
        // semantics for ID-coherence which audit consumers
        // prioritize)。 Sequence numbers preserve start-before-
        // complete ordering。
        // chapter 四百六 v2 / M996: optional permitEscalationLedger
        // (M966 typed) param threads firedStageCount into the
        // .complete envelope payload。
        // chapter 四百八 / M1004: optional stageLedger (M1003
        // typed) param threads stageCount/failedStageCount/
        // totalStageDurationMs into the payload。
        // chapter 四百九 / M1008: optional stagePlan (M1006
        // typed) param threads stagePlanStepCount/
        // stagePlanIsCanonical into the payload。
        await emitStartEnvelope(
            for: result,
            timestampMsOverride: timestampMsOverride)
        await emitCompleteEnvelope(
            for: result,
            auditProjections: auditProjections,
            permitEscalationLedger: permitEscalationLedger,
            stageLedger: stageLedger,
            stagePlan: stagePlan,
            timestampMsOverride: timestampMsOverride)
        return result
    }

    // MARK: - chapter 四百二十七 / M1082 — runWithPlan composition

    /// REAL composition surface that drives the 4 typed
    /// executors shipped at chapter 四百二十五-四百二十六
    /// (M1070 BASPermitEscalationFoldExecutor + M1072
    /// BASParallelStageDispatchExecutor + M1074 BASStress
    /// SweepHarness + M1075 BASNativeStageExecutor) via
    /// the M1080 BASRuntimeInternalDelegate against an
    /// M1006 stage plan。
    ///
    /// This is the FIRST function to wire all 4 REAL
    /// executors together end-to-end。 Previously the V2
    /// actor's `runTurn` just delegated to V1;the 6 typed
    /// scaffolding params (auditProjections / permitEscalation
    /// Ledger / stageLedger / stagePlan / timestampMsOverride)
    /// were dead-on-arrival。 Now `runWithPlan` activates
    /// them via `BASRuntimeInternalDelegate.runScaffolded`。
    ///
    /// Pure delegation — no state mutation;byte-stable
    /// result derived from V1's coordinator output (chapter
    /// 三百九二) PLUS a typed M1003 stage ledger from the
    /// native executor。 The returned `BASEBrainTurnResult`
    /// remains V1-derived for ADR-014 OPT-IN compliance;
    /// the stage ledger is emitted via the .complete
    /// envelope payload。
    public func runWithPlan(
        _ request: BASEBrainTurnRequest,
        plan: BASTurnRuntimeStagePlan =
            BASTurnRuntimeStagePlan.canonical(),
        delegate: BASRuntimeInternalDelegate? = nil,
        timestampMsOverride: Int64? = nil
    ) async -> BASEBrainTurnResult {
        // chapter 四百三十二 / M1101 — capture the dispatch
        // probe FIRST so the wiring is observable even on
        // paths where downstream work fails partway through。
        // The probe reads live registry count + capability
        // priority,proving the M1100 configuration slots
        // are CONSULTED at dispatch time (not just stored)。
        lastProbe = await currentDispatchProbe()
        // Resolve delegate: caller-provided OR fresh
        // identity-default。 Default delegate uses the
        // canonical plan;explicit `plan:` parameter
        // overrides。
        let activeDelegate = delegate
            ?? BASRuntimeInternalDelegate(
                stagePlan: plan)
        // Drive the M1075 native stage executor via the
        // delegate to produce a typed M1003 ledger
        let stageLedger = await activeDelegate
            .runScaffolded(request: request)
        // Run V1 coordinator for the byte-stable
        // BASEBrainTurnResult (ADR-014 OPT-IN preserved
        // until `BASTurnRuntimeMode.nativeV2` flips at
        // M1103 default)
        let result = coordinator.runTurn(request)
        // Emit lifecycle envelopes with the REAL stage
        // ledger threaded through the .complete payload
        await emitStartEnvelope(
            for: result,
            timestampMsOverride: timestampMsOverride)
        await emitCompleteEnvelope(
            for: result,
            auditProjections: nil,
            permitEscalationLedger: nil,
            stageLedger: stageLedger,
            stagePlan: plan,
            timestampMsOverride: timestampMsOverride)
        return result
    }

    // MARK: - Audit emission

    private func emitStartEnvelope(
        for result: BASEBrainTurnResult,
        timestampMsOverride: Int64?
    ) async {
        guard let log = eventLog else { return }
        let timestampMs = timestampMsOverride ?? clockMs()
        let nextSeq = sequenceCounter
        sequenceCounter += 1
        let turnID =
            result.sovereignAuditEntry?.turnID ??
            result.runtimeTrace.sessionID
        let envelope = BASTurnRuntimeAuditEnvelope.start(
            turnID: turnID,
            sessionID: result.runtimeTrace.sessionID,
            timestampMs: timestampMs,
            sequenceNumber: nextSeq)
        // chapter 四百六 v2 / M995 — typed extension collapses
        // 9-line entry construction + append to 1 call。
        await log.appendTurnEnvelope(
            envelope,
            eventID: eventIDFactory())
    }

    private func emitCompleteEnvelope(
        for result: BASEBrainTurnResult,
        auditProjections:
            BASRuntimeAuditProjectionsBundle?,
        permitEscalationLedger:
            BASPermitEscalationLedger?,
        stageLedger: BASTurnRuntimeStageLedger?,
        stagePlan: BASTurnRuntimeStagePlan?,
        timestampMsOverride: Int64?
    ) async {
        guard let log = eventLog else { return }
        let timestampMs = timestampMsOverride ?? clockMs()
        let nextSeq = sequenceCounter
        sequenceCounter += 1

        // chapter 四百六 / M993 + M996 + M1004 + M1008 — typed
        // factory call collapses summary construction + threads
        // permit escalation ledger + stage ledger + stage plan
        // metrics into the .complete envelope payload。
        let summary = BASRuntimeAuditEmissionSummary.from(
            result: result,
            auditProjections: auditProjections,
            permitEscalationLedger: permitEscalationLedger,
            stageLedger: stageLedger,
            stagePlan: stagePlan)

        let turnID =
            result.sovereignAuditEntry?.turnID ??
            result.runtimeTrace.sessionID
        let envelope = BASTurnRuntimeAuditEnvelope.complete(
            turnID: turnID,
            sessionID: result.runtimeTrace.sessionID,
            timestampMs: timestampMs,
            sequenceNumber: nextSeq,
            payloadJson: summary.payloadJson())
        // chapter 四百六 v2 / M995 — typed extension collapses
        // 9-line entry construction + append to 1 call。
        await log.appendTurnEnvelope(
            envelope,
            eventID: eventIDFactory())
    }
}
