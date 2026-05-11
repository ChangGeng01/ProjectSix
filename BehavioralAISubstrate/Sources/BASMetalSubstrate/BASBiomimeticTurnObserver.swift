// MARK: - BASBiomimeticTurnObserver — chapter 四百五十六 / M1201
// 系统熵 reduction
//
// **POST-SWEEP BIOMIMETIC** chapter 6 — first
// substrate-level cross-primitive ORCHESTRATOR
// bundling the 3 biomimetic primitives shipped in
// chapters 450-454 behind ONE typed observe() entry
// point。 Hosts who want adaptation + learning +
// recurrent memory wire ONE actor into their turn
// loop;chapter 456 handles cross-primitive dispatch
// + aggregate snapshot/restore using chapter 455's
// `BASBiomimeticStateSnapshot`。
//
// ## Why this exists (system entropy framing)
//
// chapters 450-455 shipped the primitives in
// isolation:
//   - chapter 450/451: BASMambaSSMState (recurrent
//     memory)
//   - chapter 452:     BASPredictiveCodingProbe
//     (closed-loop prediction adaptation)
//   - chapter 454:     BASPlasticityFold (substrate-
//     level weight learning)
//   - chapter 455:     BASBiomimeticStateSnapshot
//     (cross-turn persistence for all 3)
//
// But hosts wanting BOTH adaptation AND learning AND
// recurrent memory had to:
//   1. Hold 3 independent actor references
//   2. Manually orchestrate per-turn calls into each
//   3. Manually aggregate snapshots into a
//      BASBiomimeticStateSnapshot for persistence
//   4. Manually restore on next session
//
// 3-actor orchestration boilerplate at every call site
// is anti-DRY + violates chapter 二百一一 (single source-
// of-truth pattern)。
//
// chapter 456 ships `BASBiomimeticTurnObserver` actor:
//
//   1. Holds OPTIONAL references to the 3 primitives
//      (not every host wants all 3 — populated count
//      surfaces via accessor)
//   2. `observe(_:)` async method consuming a typed
//      `BASBiomimeticTurnSignal` bundle — dispatches
//      to populated primitives + skips nil ones
//   3. Returns a typed `BASBiomimeticTurnObservation`
//      bundle carrying each primitive's per-call
//      result (or nil for non-populated primitives)
//   4. `exportAggregate()` + `importAggregate(_:)` —
//      single-call aggregate snapshot/restore using
//      chapter 455's value-type
//   5. `turnsObservedCount()` + `reset()` audit /
//      lifecycle methods
//
// Hosts now wire ONE actor into their turn loop and
// get adaptation + learning + recurrent memory + cross-
// turn persistence + audit。 The chapter 455 aggregate
// snapshot becomes the natural checkpoint unit at the
// observer level。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed signal bundle + typed
//     observation bundle;no untyped dicts crossing the
//     observe entry
//   - chapter 二百一一 — ONE turn observer per host;
//     ONE observe() entry routing into 3 primitives
//     under one actor isolation
//   - chapter 三百九二 — replay-determinism (each
//     primitive's observe is deterministic;observer
//     dispatch is deterministic per (signal,populated-
//     primitive-set) pair)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (additive actor;no existing API touched)
//   - 红线 7 — observer outputs are observation-derived
//     hints,not commitment authority
//   - ADR-014 OPT-IN — purely additive
//
// ## Significance — first substrate-level cross-
// ## primitive orchestrator
//
// Before chapter 456:
//   - 3 biomimetic primitives + 1 snapshot aggregate
//     value-type
//   - 0 substrate-level orchestrators bundling them
//   - Hosts paid 3-actor orchestration tax at every
//     turn-loop integration
//
// After chapter 456:
//   - ONE typed observer actor bundles the 3
//     primitives behind a single observe(turn-signal)
//     entry
//   - Optional primitives:host populates only the
//     ones it wants;observer skips nil ones
//   - Aggregate snapshot/restore via chapter 455
//     integration:one call replaces 3 export +
//     1 aggregate-build calls
//   - Reset cascades across all populated primitives
//
// 「不够灵活」 critique progress:~50% → ~58%
// (orchestration boilerplate eliminated → hosts can
// add biomimetic state to their turn loop with one
// actor injection instead of three)。

import Foundation

// MARK: - Typed turn signal bundle

/// Typed input bundle for one `BASBiomimeticTurnObserver
/// .observe(_:)` call。 Each field is optional:nil
/// fields skip the corresponding primitive (allowing
/// hosts to drive only the primitives they populated)。
public struct BASBiomimeticTurnSignal:
    Equatable, Hashable, Sendable
{

    /// Predictive-coding observation vector。 When non-
    /// nil AND the observer's `predictive` primitive
    /// is populated,observer dispatches probe.observe
    /// (_:) with this vector。
    public let predictiveObservation: [Float]?

    /// Plasticity update bundle (pre/post/outcome/
    /// timingDelta)。 When non-nil AND the observer's
    /// `plasticity` primitive is populated,observer
    /// dispatches fold.apply(pre:post:outcome:
    /// timingDelta:)。 outcome defaults to 0 (outcome-
    /// modulated rule freezes learning at 0 → safe
    /// default)。 timingDelta defaults to 0 (STDP
    /// rule produces zero amplitude → safe default
    /// for non-STDP rules ignoring it)。
    public let plasticityPre: [Float]?
    public let plasticityPost: [Float]?
    public let plasticityOutcome: Float

    /// Δt = t_post - t_pre for `.stdpTemporal` plasticity
    /// rule。 Ignored by the other 3 rules。 chapter
    /// 457 / M1205。
    public let plasticityTimingDelta: Float

    /// Mamba selective-scan inputs。 When non-nil AND
    /// the observer's `mamba` primitive is populated,
    /// observer dispatches mamba.selectiveScan(inputs:)。
    public let mambaInputs: BASMambaSSMScanInputs?

    /// Hierarchical predictive coding input vector。
    /// When non-nil AND the observer's `hierarchical`
    /// primitive is populated,observer dispatches
    /// hierarchical.observe(_:)。 chapter 470 / M1257。
    public let hierarchicalObservation: [Float]?

    /// BCM meta-plasticity (pre,post)。 Both vectors
    /// required;when non-nil AND `bcm` primitive
    /// populated,observer dispatches bcm.apply。
    /// chapter 473 / fix #6 of chapter 466 self-audit。
    public let bcmPre: [Float]?
    public let bcmPost: [Float]?

    public init(
        predictiveObservation: [Float]? = nil,
        plasticityPre: [Float]? = nil,
        plasticityPost: [Float]? = nil,
        plasticityOutcome: Float = 0,
        plasticityTimingDelta: Float = 0,
        mambaInputs: BASMambaSSMScanInputs? = nil,
        hierarchicalObservation: [Float]? = nil,
        bcmPre: [Float]? = nil,
        bcmPost: [Float]? = nil
    ) {
        self.predictiveObservation = predictiveObservation
        self.plasticityPre = plasticityPre
        self.plasticityPost = plasticityPost
        self.plasticityOutcome = plasticityOutcome
        self.plasticityTimingDelta = plasticityTimingDelta
        self.mambaInputs = mambaInputs
        self.hierarchicalObservation =
            hierarchicalObservation
        self.bcmPre = bcmPre
        self.bcmPost = bcmPost
    }

    /// Convenience:count of populated (non-nil) drive
    /// fields。 0 means the observe call will be a no-
    /// op for every primitive (still counted as a turn)。
    public var populatedDriveCount: Int {
        var count = 0
        if predictiveObservation != nil { count += 1 }
        if plasticityPre != nil && plasticityPost != nil {
            count += 1
        }
        if mambaInputs != nil { count += 1 }
        if hierarchicalObservation != nil { count += 1 }
        if bcmPre != nil && bcmPost != nil { count += 1 }
        return count
    }
}

// MARK: - Typed observation result bundle

/// Typed output bundle from one observe(_:) call。
/// Each field is optional:nil means the corresponding
/// primitive was either not populated on the observer
/// OR the signal didn't drive it。
public struct BASBiomimeticTurnObservation:
    Equatable, Hashable, Sendable
{

    /// Predictive-coding observation result (if probe
    /// was populated AND signal carried an observation)。
    public let predictive: BASPredictiveCodingObservation?

    /// Plasticity update result (if fold was populated
    /// AND signal carried pre + post vectors)。
    public let plasticity: BASPlasticityUpdate?

    /// Mamba scan outputs (if state was populated AND
    /// signal carried scan inputs)。
    public let mamba: BASMambaSSMScanOutputs?

    /// Hierarchical predictive coding observation
    /// result (if hierarchy was populated AND signal
    /// carried a hierarchical observation)。 chapter
    /// 470 / M1257。
    public let hierarchical: BASHierarchicalObservation?

    /// BCM meta-plasticity update result (if bcm
    /// primitive populated AND signal carried pre +
    /// post)。 chapter 473 / fix #6。
    public let bcm: BASBCMMetaPlasticityUpdate?

    /// 0-based turn index for this observe call
    /// (matches the observer's turnsObservedCount AT
    /// the moment the call was made)。
    public let turnIndex: Int

    public init(
        predictive: BASPredictiveCodingObservation? = nil,
        plasticity: BASPlasticityUpdate? = nil,
        mamba: BASMambaSSMScanOutputs? = nil,
        hierarchical: BASHierarchicalObservation? = nil,
        bcm: BASBCMMetaPlasticityUpdate? = nil,
        turnIndex: Int = 0
    ) {
        self.predictive = predictive
        self.plasticity = plasticity
        self.mamba = mamba
        self.hierarchical = hierarchical
        self.bcm = bcm
        self.turnIndex = max(0, turnIndex)
    }

    /// Convenience:count of primitives that produced a
    /// result this turn。
    public var producedResultCount: Int {
        var count = 0
        if predictive != nil { count += 1 }
        if plasticity != nil { count += 1 }
        if mamba != nil { count += 1 }
        if hierarchical != nil { count += 1 }
        if bcm != nil { count += 1 }
        return count
    }
}

// MARK: - Turn observer actor

/// Substrate-side cross-primitive turn observer。 Holds
/// optional references to the 3 biomimetic primitives +
/// exposes a single `observe(_:)` entry that dispatches
/// to populated primitives + skips nil ones。
public actor BASBiomimeticTurnObserver {

    /// Mamba SSM hidden-state primitive。 nil means
    /// hosts don't use recurrent-memory primitive
    /// here。
    public nonisolated let mamba: BASMambaSSMState?

    /// Predictive-coding probe primitive。 nil means
    /// hosts don't use closed-loop adaptation here。
    public nonisolated let predictive:
        BASPredictiveCodingProbe?

    /// Plasticity fold primitive。 nil means hosts
    /// don't use substrate-level learning here。
    public nonisolated let plasticity: BASPlasticityFold?

    /// Hierarchical predictive coding primitive
    /// (chapter 459)。 nil means hosts don't use
    /// multi-level adaptation here。 chapter 470 /
    /// M1257。
    public nonisolated let hierarchical:
        BASHierarchicalPredictiveCoding?

    /// BCM meta-plasticity primitive (chapter 469)。
    /// nil means hosts don't use the adaptive-threshold
    /// learning rule here。 chapter 473 fix #6 closes
    /// the dead-on-arrival gap surfaced by the chapter
    /// 466 self-audit。
    public nonisolated let bcm: BASBCMMetaPlasticity?

    /// Number of `observe(_:)` calls processed since
    /// last `reset()`。
    private var turnsObserved: Int = 0

    public init(
        mamba: BASMambaSSMState? = nil,
        predictive: BASPredictiveCodingProbe? = nil,
        plasticity: BASPlasticityFold? = nil,
        hierarchical:
            BASHierarchicalPredictiveCoding? = nil,
        bcm: BASBCMMetaPlasticity? = nil
    ) {
        self.mamba = mamba
        self.predictive = predictive
        self.plasticity = plasticity
        self.hierarchical = hierarchical
        self.bcm = bcm
    }

    /// Read-only count of turns observed since last
    /// reset。
    public func turnsObservedCount() -> Int {
        return turnsObserved
    }

    /// Read-only count of populated (non-nil) primitive
    /// slots。 Mirrors chapter 455 aggregate's
    /// populatedPrimitiveCount。 chapter 470 / M1257
    /// extends to 4 slots。
    public nonisolated var populatedPrimitiveCount: Int {
        var count = 0
        if mamba != nil { count += 1 }
        if predictive != nil { count += 1 }
        if plasticity != nil { count += 1 }
        if hierarchical != nil { count += 1 }
        if bcm != nil { count += 1 }
        return count
    }

    /// Observe one turn:dispatch signal to populated
    /// primitives + return aggregated observation
    /// bundle。 Increments turn counter regardless of
    /// how many primitives produce results (a turn
    /// that drove no primitives still counts — useful
    /// for audit + replay)。
    public func observe(
        _ signal: BASBiomimeticTurnSignal
    ) async throws -> BASBiomimeticTurnObservation {
        let currentTurn = turnsObserved
        var predictiveResult:
            BASPredictiveCodingObservation? = nil
        var plasticityResult: BASPlasticityUpdate? = nil
        var mambaResult: BASMambaSSMScanOutputs? = nil
        // Predictive-coding dispatch
        if let probe = predictive,
           let observation = signal.predictiveObservation
        {
            predictiveResult = try await probe
                .observe(observation)
        }
        // Plasticity dispatch — requires both pre + post
        if let fold = plasticity,
           let pre = signal.plasticityPre,
           let post = signal.plasticityPost
        {
            plasticityResult = try await fold.apply(
                pre: pre,
                post: post,
                outcome: signal.plasticityOutcome,
                timingDelta:
                    signal.plasticityTimingDelta)
        }
        // Mamba dispatch
        if let state = mamba,
           let inputs = signal.mambaInputs
        {
            mambaResult = try await state
                .selectiveScan(inputs: inputs)
        }
        // Hierarchical dispatch (chapter 470 / M1257)
        var hierarchicalResult:
            BASHierarchicalObservation? = nil
        if let hier = hierarchical,
           let input = signal.hierarchicalObservation
        {
            hierarchicalResult = try await hier
                .observe(input)
        }
        // BCM dispatch (chapter 473 fix #6)
        var bcmResult:
            BASBCMMetaPlasticityUpdate? = nil
        if let b = bcm,
           let pre = signal.bcmPre,
           let post = signal.bcmPost
        {
            bcmResult = try await b.apply(
                pre: pre, post: post)
        }
        turnsObserved += 1
        return BASBiomimeticTurnObservation(
            predictive: predictiveResult,
            plasticity: plasticityResult,
            mamba: mambaResult,
            hierarchical: hierarchicalResult,
            bcm: bcmResult,
            turnIndex: currentTurn)
    }

    /// Export an aggregate snapshot of all populated
    /// primitives。 Non-populated slots map to nil
    /// fields on the chapter 455 aggregate value-type。
    public func exportAggregate()
        async -> BASBiomimeticStateSnapshot
    {
        let mambaSnap: BASMambaSSMSnapshot? =
            await mamba?.exportSnapshot()
        let predictiveSnap: BASPredictiveCodingSnapshot? =
            await predictive?.exportSnapshot()
        let plasticitySnap: BASPlasticitySnapshot? =
            await plasticity?.exportSnapshot()
        return BASBiomimeticStateSnapshot(
            mamba: mambaSnap,
            predictive: predictiveSnap,
            plasticity: plasticitySnap)
    }

    /// Restore all populated primitives from an
    /// aggregate snapshot。 Throws `shapeMismatch` if
    /// any populated primitive's slot in the snapshot
    /// doesn't match its shape。 Slots present in the
    /// snapshot but with no corresponding populated
    /// primitive on the observer are SILENTLY IGNORED
    /// (host opted out of that primitive on this
    /// observer)。 Populated primitives that DON'T have
    /// a snapshot slot are LEFT UNTOUCHED (their state
    /// continues as-is)。
    public func importAggregate(
        _ snapshot: BASBiomimeticStateSnapshot
    ) async throws {
        if let state = mamba,
           let mambaSnap = snapshot.mamba
        {
            try await state.importSnapshot(mambaSnap)
        }
        if let probe = predictive,
           let probeSnap = snapshot.predictive
        {
            try await probe.importSnapshot(probeSnap)
        }
        if let fold = plasticity,
           let foldSnap = snapshot.plasticity
        {
            try await fold.importSnapshot(foldSnap)
        }
    }

    /// Cascade reset across all populated primitives +
    /// zero the turn counter。 Useful for session
    /// boundaries / clean-slate tests。
    public func reset() async {
        if let state = mamba {
            await state.reset()
        }
        if let probe = predictive {
            await probe.reset()
        }
        if let fold = plasticity {
            await fold.reset()
        }
        if let hier = hierarchical {
            await hier.reset()
        }
        if let b = bcm {
            await b.reset()
        }
        turnsObserved = 0
    }
}
