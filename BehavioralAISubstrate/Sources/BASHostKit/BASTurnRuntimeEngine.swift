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

    // MARK: - chapter 四百三十五 / M1117 — scheduler integration

    /// Optional per-stage hint sidecar (M1104)。 When
    /// non-nil AND `metalKernelRegistry` + `aneCapability`
    /// are also non-nil,`runWithPlan(...)` consults
    /// `BASHardwareAwareScheduler` for each plan stage
    /// step that has a hint registered。
    private let stagePlanHints:
        BASStagePlanAcceleratorHints?

    /// Lazily-instantiated scheduler。 Created on first
    /// scheduler-consuming `runWithPlan(...)` call when
    /// all 3 prerequisites (hints + registry + capability)
    /// are present。 Reused across calls。
    private var scheduler:
        BASHardwareAwareScheduler?

    /// chapter 四百三十八 / M1128 — host-provided routed
    /// stage executor closure。 Threaded through to
    /// `delegate.runScaffoldedWithAssignments(...)` when
    /// engine takes the routed path。 nil → no-op default。
    private let routedStageExecutor:
        BASNativeStageExecutor.RoutedStageExecutor?

    /// chapter 四百三十八 / M1128 — host-provided fallback
    /// stage executor closure。 Threaded through to
    /// `delegate.runScaffoldedWithAssignments(...)` when
    /// engine takes the routed path AND a stage has no
    /// assignment registered。 nil → no-op default。
    private let fallbackStageExecutor:
        BASNativeStageExecutor.StageExecutor?

    // MARK: - Slot (M1221 chapter 四百六十一 — biomimetic observer)

    /// Optional substrate-side biomimetic observer
    /// invoked once per `runWithPlan(...)` call after
    /// the turn fully completes。 nil → no call made
    /// → V1 byte-equality preserved。 chapter 461 /
    /// M1221 — closes integration debt surfaced by
    /// chapter 459 self-audit。
    private let biomimeticTurnObserver:
        BASBiomimeticTurnObserver?

    /// Optional Sendable closure mapping the completed
    /// turn result into a typed observer signal。 nil
    /// → empty signal (turn-counter-only) when
    /// observer is non-nil。 chapter 461 / M1221。
    private let biomimeticTurnSignalBuilder:
        (@Sendable (BASEBrainTurnResult)
            -> BASBiomimeticTurnSignal)?

    /// Optional cadence for auto-checkpoint emission。
    /// nil OR == 0 disables;>= 1 emits a typed
    /// biomimetic-checkpoint event to `eventLog` every
    /// N observed turns。 Requires `biomimeticTurnObserver`
    /// + `eventLog` to ALSO be wired。 chapter 467 /
    /// M1246。
    private let biomimeticCheckpointEveryNTurns: Int?

    /// chapter 五百三十七 / M1526 — typed observability
    /// sink for the 4 documented silent-swallow paths
    /// (biomimetic observer + 3 event-log append sites)。
    /// nil → behavior unchanged from pre-M1526 (silent
    /// swallow continues as documented per 红线 7);
    /// non-nil → each failed emission also records to
    /// the sink for host inspection。
    private let observationFailureLog:
        BASTurnRuntimeEngineObservationFailureLog?

    // MARK: - Mutable state (actor-isolated)

    private var sequenceCounter: Int = 0

    /// Most-recent `BASTurnRuntimePlanDispatchProbe`
    /// captured by `runWithPlan(...)`。 `unwired()` until
    /// the first `runWithPlan` call。 Surfaced via the
    /// `lastPlanDispatchProbe()` accessor for tests + the
    /// M1102 scheduler + audit consumers。
    private var lastProbe: BASTurnRuntimePlanDispatchProbe =
        .unwired()

    /// Most-recent `BASNativeStageDispatchLedger`
    /// captured by `runWithPlan(...)` when the engine
    /// dispatched through the routed path (chapter 437
    /// M1126)。 `.empty` until the first routed call。
    /// Surfaced via `lastNativeStageDispatchLedger()`
    /// accessor for tests + audit consumers。
    private var lastDispatchLedger:
        BASNativeStageDispatchLedger = .empty

    /// chapter 四百四十 / M1137 — eventID of the most-
    /// recent `BASNativeStageDispatchEventPayload` the
    /// engine emitted to the configured event log,or
    /// nil if the engine has never emitted one (either
    /// because `eventLog` is nil OR the routed
    /// dispatch path hasn't fired)。 Surfaced via
    /// `lastEmittedDispatchEventID()` for tests + audit。
    private var lastEmittedDispatchEventID: String? = nil

    /// chapter 四百四十一 / M1141 — eventID of the most-
    /// recent `BASTurnRuntimePlanAssignmentEventPayload`
    /// the engine auto-emitted to the configured event
    /// log,or nil if the engine has never emitted one
    /// (either because `eventLog` is nil OR no
    /// `runWithPlan(...)` call has captured a non-empty
    /// assignment ledger)。 Surfaced via
    /// `lastEmittedPlanAssignmentEventID()` for tests
    /// + audit。
    private var lastEmittedPlanAssignmentEventID:
        String? = nil

    /// Most-recent `BASTurnRuntimePlanAssignmentLedger`
    /// captured by `runWithPlan(...)`。 `.unwired` until
    /// the first scheduler-consuming call。 Surfaced via
    /// `lastPlanAssignmentLedger()` for audit + tests。
    private var lastAssignmentLedger:
        BASTurnRuntimePlanAssignmentLedger = .unwired

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
        aneCapability: BASANECapability? = nil,
        stagePlanHints:
            BASStagePlanAcceleratorHints? = nil,
        routedStageExecutor:
            BASNativeStageExecutor.RoutedStageExecutor? = nil,
        fallbackStageExecutor:
            BASNativeStageExecutor.StageExecutor? = nil,
        biomimeticTurnObserver:
            BASBiomimeticTurnObserver? = nil,
        biomimeticTurnSignalBuilder:
            (@Sendable (BASEBrainTurnResult)
                -> BASBiomimeticTurnSignal)? = nil,
        biomimeticCheckpointEveryNTurns: Int? = nil,
        observationFailureLog:
            BASTurnRuntimeEngineObservationFailureLog?
            = nil
    ) {
        self.coordinator = coordinator
        self.eventLog = eventLog
        self.eventIDFactory = eventIDFactory
        self.clockMs = clockMs
        self.runtimeMode = runtimeMode
        self.metalKernelRegistry = metalKernelRegistry
        self.aneCapability = aneCapability
        self.stagePlanHints = stagePlanHints
        self.routedStageExecutor = routedStageExecutor
        self.fallbackStageExecutor = fallbackStageExecutor
        self.biomimeticTurnObserver =
            biomimeticTurnObserver
        self.biomimeticTurnSignalBuilder =
            biomimeticTurnSignalBuilder
        self.biomimeticCheckpointEveryNTurns =
            biomimeticCheckpointEveryNTurns
        self.observationFailureLog =
            observationFailureLog
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
            aneCapability: configuration.aneCapability,
            stagePlanHints:
                configuration.stagePlanHints,
            routedStageExecutor:
                configuration.routedStageExecutor,
            fallbackStageExecutor:
                configuration.fallbackStageExecutor,
            biomimeticTurnObserver:
                configuration.biomimeticTurnObserver,
            biomimeticTurnSignalBuilder:
                configuration
                    .biomimeticTurnSignalBuilder,
            biomimeticCheckpointEveryNTurns:
                configuration
                    .biomimeticCheckpointEveryNTurns)
    }

    // MARK: - chapter 四百三十五 / M1117 — assignment ledger accessor

    /// Returns the most-recent assignment ledger captured
    /// by `runWithPlan(...)`。 Returns `.unwired` until
    /// the first scheduler-consuming call。 Used by tests
    /// + audit consumers to verify the M1102 BASHardware
    /// AwareScheduler is genuinely being consulted at
    /// dispatch time。
    public func lastPlanAssignmentLedger()
        -> BASTurnRuntimePlanAssignmentLedger
    {
        return lastAssignmentLedger
    }

    // MARK: - chapter 四百三十七 / M1126 — dispatch ledger accessor

    /// Returns the most-recent dispatch ledger captured
    /// by `runWithPlan(...)` when it dispatched through
    /// the routed delegate path (chapter 437 M1126
    /// wiring)。 Returns `.empty` for runs where
    /// assignments was empty (V1-fallback path) or no
    /// `runWithPlan` call has occurred。 Used by tests +
    /// audit consumers to verify scheduler decisions are
    /// HONORED at execution time,not just captured。
    public func lastNativeStageDispatchLedger()
        -> BASNativeStageDispatchLedger
    {
        return lastDispatchLedger
    }

    // MARK: - chapter 四百四十 / M1137 — emitted event ID accessor

    /// Returns the eventID of the most-recent
    /// `BASNativeStageDispatchEventPayload` the engine
    /// auto-emitted to the configured event log。
    /// Returns nil when `eventLog` is nil (no emission
    /// happens) OR when no `runWithPlan(...)` call has
    /// ever taken the routed path (lastDispatchLedger
    /// stays empty,emission gate skips)。 Used by
    /// tests + audit consumers to verify dispatch
    /// event emission fires end-to-end。
    public func lastEmittedNativeStageDispatchEventID()
        -> String?
    {
        return lastEmittedDispatchEventID
    }

    // MARK: - chapter 四百四十一 / M1141 — emitted plan-assignment event ID accessor

    /// Returns the eventID of the most-recent
    /// `BASTurnRuntimePlanAssignmentEventPayload` the
    /// engine auto-emitted to the configured event log。
    /// Returns nil when `eventLog` is nil (no emission
    /// happens) OR when no `runWithPlan(...)` call has
    /// ever captured a non-empty assignment ledger
    /// (lastAssignmentLedger.recordCount stays 0,
    /// emission gate skips)。 Used by tests + audit
    /// consumers to verify plan-assignment event
    /// emission fires end-to-end。
    public func lastEmittedPlanAssignmentEventIDValue()
        -> String?
    {
        return lastEmittedPlanAssignmentEventID
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

    /// V2 runTurn:dispatches on `runtimeMode`。`.v1ByteEqual` (and
    /// `.stressSweepDual`) delegate to the V1 coordinator, then emit a
    /// `.complete` audit envelope on the wired event log (when present)。
    /// `.nativeV2` dispatches `runWithPlan(...)` (the real native stage
    /// executors)。 In ALL modes the returned `BASEBrainTurnResult` is
    /// byte-equal to V1's result — `runWithPlan` returns the same
    /// `coordinator.runTurn(request)` value, proven across canonical60 by
    /// `BASEBrainTurnResultReplayHarness.v1VsRunWithPlanParityVerdict`。
    ///
    /// ADR-033 Step 3b — HONEST .nativeV2:BEFORE Step 3b `runTurn`
    /// ignored `runtimeMode` and was always V1 (the ch1044 严查 #1
    /// finding); it now READS the mode。 `BASCognitiveBrain.process()`
    /// calls THIS method but its engine is built at the `.v1ByteEqual`
    /// init-default (NOT via `.default()`),so the brain's main path
    /// stays V1-byte-equal。 NOTE: `.default() == .nativeV2`, so a host
    /// constructing the engine via `init(coordinator:configuration:
    /// .default())` now takes the native dispatch (byte-equal result;
    /// the only delta is extra stage-ledger / dispatch telemetry)。
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
        // ADR-033 Step 3b — honest .nativeV2: when the host opted into native execution,
        // dispatch the REAL native stage executors via runWithPlan. The returned
        // BASEBrainTurnResult stays V1-derived and is BYTE-EQUAL to the .v1ByteEqual path —
        // proven across canonical60 by
        // BASEBrainTurnResultReplayHarness.v1VsRunWithPlanParityVerdict (the evidence gate).
        // .v1ByteEqual (default) + .stressSweepDual leave the V1 path below textually
        // unchanged (ADR-014 byte-equal-off / R1). The native path's only observable effect
        // is additional stage-ledger / dispatch telemetry, NOT a different answer.
        if runtimeMode == .nativeV2 {
            return await runWithPlan(
                request,
                plan: stagePlan ?? BASTurnRuntimeStagePlan.canonical(),
                timestampMsOverride: timestampMsOverride)
        }
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
        // chapter 四百三十五 / M1117 — consult scheduler if
        // all 3 prerequisites (hints + registry + capability)
        // are present。 Captures per-stage assignments into
        // `lastAssignmentLedger` so audit consumers see the
        // M1102 BASHardwareAwareScheduler decisions made
        // for this turn。 Pure observation — V1 dispatch
        // path is untouched (ADR-014 OPT-IN preserved)。
        let turnIDForLedger =
            request.hostID + ":" +
            String(Int(
                request.recordedAt
                    .timeIntervalSince1970))
        lastAssignmentLedger = await
            captureSchedulerAssignmentsIfWired(
                plan: plan,
                turnID: turnIDForLedger)
        // Resolve delegate: caller-provided OR fresh
        // identity-default。 Default delegate uses the
        // canonical plan;explicit `plan:` parameter
        // overrides。
        let activeDelegate = delegate
            ?? BASRuntimeInternalDelegate(
                stagePlan: plan)
        // chapter 四百三十七 / M1126 — routed dispatch:
        // when the captured assignment ledger has at
        // least one record (scheduler was consulted +
        // produced decisions),dispatch through the
        // M1125 routed delegate path。 Captures the
        // dispatch ledger so audit consumers can prove
        // decisions were HONORED at execution time。
        // When assignment ledger is empty (no scheduler
        // consultation),fall back to the M998
        // unrouted path — V1 byte-equality preserved。
        let stageLedger: BASTurnRuntimeStageLedger
        if lastAssignmentLedger.recordCount > 0 {
            // chapter 四百三十八 / M1129 — thread host-
            // provided routed + fallback closures through
            // delegate boundary。 nil → no-op defaults
            // preserve V1 byte-equality for hosts that
            // haven't wired real backends yet。
            let routed = routedStageExecutor
                ?? { _, _, _ in 0 }
            let fallback = fallbackStageExecutor
                ?? { _, _ in 0 }
            let routedResult = await activeDelegate
                .runScaffoldedWithAssignments(
                    request: request,
                    assignments: lastAssignmentLedger,
                    routedExecutor: routed,
                    fallbackExecutor: fallback)
            stageLedger = routedResult.stageLedger
            lastDispatchLedger = routedResult
                .dispatchLedger
        } else {
            // Unrouted path — empty dispatch ledger
            stageLedger = await activeDelegate
                .runScaffolded(request: request)
            lastDispatchLedger = .empty
        }
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
        // chapter 四百四十 / M1137 — auto-emit dispatch
        // event payload to the configured event log when
        // (1) eventLog is wired AND (2) the routed
        // dispatch path actually fired (executionCount
        // > 0)。 Connects chapter 439 typed payload to
        // chapter 437 routed dispatch through the
        // unified event log。 V1 byte-equality preserved
        // when eventLog == nil OR ledger empty。
        await emitNativeStageDispatchEventIfNeeded(
            for: result,
            timestampMsOverride: timestampMsOverride)
        // chapter 四百四十一 / M1141 — auto-emit plan-
        // assignment event payload (sibling of dispatch
        // auto-emit;upstream half of the routed surface)。
        // Gated on (1) eventLog wired AND (2)
        // lastAssignmentLedger has at least one record
        // (scheduler was consulted with all 3 prerequisites)。
        // V1 byte-equality preserved when eventLog == nil
        // OR ledger empty。
        await emitPlanAssignmentEventIfNeeded(
            for: result,
            timestampMsOverride: timestampMsOverride)
        // chapter 461 / M1221 — biomimetic turn observer
        // hook (closes integration debt surfaced by
        // chapter 459 self-audit)。 Fires AFTER all
        // existing emits + ledger captures + V1 result
        // is produced。 Errors from observer are
        // SWALLOWED (the observer is observation/
        // audit,not commitment authority — 红线 7)。
        // ADR-014 OPT-IN:nil → no call → V1 byte-
        // equality preserved。
        if let observer = biomimeticTurnObserver {
            let signal = biomimeticTurnSignalBuilder?(
                result) ?? BASBiomimeticTurnSignal()
            // chapter 五百三十七 / M1526 — wire-in of
            // typed observability sink (M1525)。 nil log
            // → behavior unchanged (silent swallow per
            // 红线 7);non-nil → record failure。
            do {
                _ = try await observer.observe(signal)
            } catch {
                if let log = observationFailureLog {
                    await log.record(
                        kind: .biomimeticObserverObserve,
                        error: error,
                        sessionID: result
                            .runtimeTrace.sessionID)
                }
            }
            // chapter 467 / M1246 — auto-checkpoint
            // emission。 Three prerequisites must ALL
            // be wired:observer (above),event log,
            // and cadence >= 1。 When all present AND
            // observer.turnsObservedCount() %
            // everyN == 0,emit a typed biomimetic-
            // checkpoint event。 Errors swallowed via
            // try? (红线 7)。 ADR-014 OPT-IN:any of
            // the 3 missing → no emission → V1 byte-
            // equality preserved。
            if let eventLog = eventLog,
               let everyN = biomimeticCheckpointEveryNTurns,
               everyN >= 1 {
                let count = await observer
                    .turnsObservedCount()
                if count % everyN == 0 {
                    let snapshot = await observer
                        .exportAggregate()
                    let sid = result.runtimeTrace
                        .sessionID
                    let payload =
                        BASBiomimeticCheckpointEventPayload(
                            snapshot: snapshot,
                            turnIndex: count,
                            everyNTurns: everyN,
                            sessionID: sid)
                    let entry = BASEventLogEntry
                        .biomimeticCheckpointEvent(
                            eventID: eventIDFactory(),
                            timestampMs:
                                timestampMsOverride
                                ?? clockMs(),
                            sessionID: sid,
                            payload: payload)
                    // chapter 五百三十七 / M1526 —
                    // wire-in of typed observability
                    // sink (M1525)。
                    do {
                        try await eventLog
                            .append(entry)
                    } catch {
                        if let log =
                            observationFailureLog
                        {
                            await log.record(
                                kind:
                                .autoCheckpointEventLogAppend,
                                error: error,
                                sessionID: sid)
                        }
                    }
                }
            }
        }
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

    // MARK: - chapter 四百三十五 / M1117 — scheduler consultation

    /// Consult `BASHardwareAwareScheduler` for each plan
    /// stage step that has a hint registered in the
    /// configuration's sidecar。 Returns `.empty(turnID:)`
    /// when any of the 3 prerequisites (hints + registry
    /// + capability) is absent — V1 byte-equal path is
    /// fully preserved。
    ///
    /// Lazily constructs the scheduler on first
    /// scheduler-consuming call;reuses the same
    /// scheduler instance for subsequent calls。 Pure
    /// observation — no V1 dispatch path mutation。
    private func captureSchedulerAssignmentsIfWired(
        plan: BASTurnRuntimeStagePlan,
        turnID: String
    ) async -> BASTurnRuntimePlanAssignmentLedger {
        // Prerequisite check — all 3 must be wired
        guard let hints = stagePlanHints,
              let registry = metalKernelRegistry,
              let capability = aneCapability
        else {
            return .empty(turnID: turnID)
        }
        // Resolve / create scheduler (lazy)
        if scheduler == nil {
            scheduler = BASHardwareAwareScheduler(
                registry: registry)
        }
        guard let activeScheduler = scheduler else {
            return .empty(turnID: turnID)
        }
        // Walk each plan step's stages,consulting the
        // scheduler for each stage that has a hint
        var ledger = BASTurnRuntimePlanAssignmentLedger
            .empty(turnID: turnID)
        var sequenceIndex = 0
        for step in plan.steps {
            for stage in step.stages {
                guard let hint = hints.hint(
                    for: stage)
                else {
                    continue
                }
                let assignment =
                    await activeScheduler.assign(
                        hint: hint,
                        capability: capability,
                        thermal: capability
                            .thermalSnapshot)
                let record =
                    BASTurnRuntimeStageAssignmentRecord(
                        stageRawValue: stage.rawValue,
                        hint: hint,
                        assignment: assignment,
                        sequenceIndex: sequenceIndex)
                ledger = ledger.appending(record)
                sequenceIndex += 1
            }
        }
        return ledger
    }

    // MARK: - chapter 四百四十 / M1137 — auto-emit helper

    /// Emit a `BASNativeStageDispatchEventPayload` to
    /// the configured event log when:
    ///   1. `eventLog` is wired (non-nil)
    ///   2. `lastDispatchLedger.executionCount > 0`
    ///      (routed dispatch fired,not just empty
    ///      fallback)
    ///
    /// When either condition fails,helper is a no-op
    /// and `lastEmittedDispatchEventID` stays nil
    /// (engine took the V1-fallback path or has no
    /// event log to emit to)。 Pure additive
    /// observability — V1 byte-equality preserved。
    private func emitNativeStageDispatchEventIfNeeded(
        for result: BASEBrainTurnResult,
        timestampMsOverride: Int64?
    ) async {
        guard let log = eventLog else { return }
        guard lastDispatchLedger.executionCount > 0
        else { return }
        let timestampMs = timestampMsOverride ?? clockMs()
        let nextSeq = sequenceCounter
        sequenceCounter += 1
        let turnID =
            result.sovereignAuditEntry?.turnID ??
            result.runtimeTrace.sessionID
        let payload = BASNativeStageDispatchEventPayload
            .from(
                ledger: lastDispatchLedger,
                turnID: turnID)
        let eventID = eventIDFactory()
        let entry = BASEventLogEntry
            .nativeStageDispatchEvent(
                eventID: eventID,
                timestampMs: timestampMs,
                sessionID: result.runtimeTrace.sessionID,
                sequenceNumber: Int64(nextSeq),
                payload: payload)
        // BASEventLogStorage.append is async throws —
        // swallow any storage failure here。 Audit
        // emission is hint-only (红线 7);failure to
        // emit must not break runtime correctness。
        // chapter 五百三十七 / M1526 — wire-in of typed
        // observability sink (M1525)。
        do {
            try await log.append(entry)
        } catch {
            if let failureLog = observationFailureLog {
                await failureLog.record(
                    kind:
                    .nativeStageDispatchEventLogAppend,
                    error: error,
                    sessionID: result
                        .runtimeTrace.sessionID)
            }
        }
        lastEmittedDispatchEventID = eventID
    }

    // MARK: - chapter 四百四十一 / M1141 — plan-assignment auto-emit helper

    /// Emit a `BASTurnRuntimePlanAssignmentEventPayload`
    /// to the configured event log when:
    ///   1. `eventLog` is wired (non-nil)
    ///   2. `lastAssignmentLedger.recordCount > 0`
    ///      (scheduler was consulted with all 3
    ///      prerequisites — hints + registry +
    ///      capability — and produced decisions)
    ///
    /// When either condition fails,helper is a no-op
    /// and `lastEmittedPlanAssignmentEventID` stays nil
    /// (engine took the V1-fallback path or has no
    /// event log to emit to)。 Pure additive
    /// observability — V1 byte-equality preserved。
    private func emitPlanAssignmentEventIfNeeded(
        for result: BASEBrainTurnResult,
        timestampMsOverride: Int64?
    ) async {
        guard let log = eventLog else { return }
        guard lastAssignmentLedger.recordCount > 0
        else { return }
        let timestampMs = timestampMsOverride ?? clockMs()
        let nextSeq = sequenceCounter
        sequenceCounter += 1
        let payload =
            BASTurnRuntimePlanAssignmentEventPayload
                .from(ledger: lastAssignmentLedger)
        let eventID = eventIDFactory()
        let entry = BASEventLogEntry
            .planAssignmentEvent(
                eventID: eventID,
                timestampMs: timestampMs,
                sessionID: result.runtimeTrace.sessionID,
                sequenceNumber: Int64(nextSeq),
                payload: payload)
        // BASEventLogStorage.append is async throws —
        // swallow any storage failure here。 Audit
        // emission is hint-only (红线 7);failure to
        // emit must not break runtime correctness。
        // chapter 五百三十七 / M1526 — wire-in of typed
        // observability sink (M1525)。
        do {
            try await log.append(entry)
        } catch {
            if let failureLog = observationFailureLog {
                await failureLog.record(
                    kind:
                    .planAssignmentEventLogAppend,
                    error: error,
                    sessionID: result
                        .runtimeTrace.sessionID)
            }
        }
        lastEmittedPlanAssignmentEventID = eventID
    }
}
