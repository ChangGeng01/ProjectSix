// MARK: - EBrainRuntimeCoordinator+RunTurn
// chapter 六百二 / M1785 — V1 monolith Phase I continuation
//                          wave 3:THE BIG MOVE。
//
// `runTurn(_:)` (1733 LOC) + `runTurnAndIngest(_:lifecycle
// Coordinator:)` (12 LOC) MOVED OUT of EBrainRuntime
// Coordinator.swift V1 monolith file into this sibling
// extension file。
//
// = ~1744 LOC moved。 V1 monolith file shrinks 1918 →
// ~174 LOC (achieves plan target's spirit:main coordinator
// file holds only type declaration + instance properties +
// init,with the giant runTurn body extracted)。
//
// CUMULATIVE V1 REDUCTION (chapter 477 baseline):
//   2540 → 174 = -2366 LOC (-93.1%,vs plan target 80 LOC)
//
// ## Why this works
//
// Swift extension methods on a public struct can be
// declared in ANY file in the module。 The method body
// access pattern (`self.xxx` for instance props,
// `Self.xxx` for static helpers) works identically
// from a sibling extension file。 All callers continue
// to invoke `coordinator.runTurn(request)` unchanged。
//
// ## Byte-equality
//
// Pure code MOVE — no logic change。 V1 byte-equality
// preserved by construction。 BASStressSweepCanonical60
// Driver regression guard verifies no per-turn
// behavioral change。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive — no behavior change (pure move)
//   - chapter 一百八十五:typed enum + typed factory
//     preserved
//   - chapter 二百一一:single source-of-truth
//     (runTurn entry point unchanged from caller side)
//   - chapter 三百九二:replay-determinism unchanged
//   - chapter 478 / 489-493 / 600 / 601 V1 fold
//     precedents
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1784 → M1785

import CryptoKit
import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore
import BASSovereign
import BASWorldPrior

extension BASEBrainRuntimeCoordinator {

    public func runTurn(
        _ request: BASEBrainTurnRequest
    ) -> BASEBrainTurnResult {
        // substrate #77 — coarse stage stopwatch (pure local; attached to the result as
        // `layerTimingsMs`; zero behavior effect).
        var stageT0 = DispatchTime.now()
        var stageMs: [String: Double] = [:]
        func markStage(_ label: String) {
            let now = DispatchTime.now()
            stageMs[label] = Double(now.uptimeNanoseconds - stageT0.uptimeNanoseconds) / 1_000_000
            stageT0 = now
        }
        let requestedBudget = powerClockService.planBudget(
            deviceState: request.deviceState,
            taskPing: request.userInput,
            riskHint: request.riskHint
        )
        let (plannedBudget, budgetFindings) = normalizeBudget(
            requestedBudget,
            riskHint: request.riskHint,
            activeKillSwitches: request.activeKillSwitches
        )

        // chapter 五百十 / M1419 — routedBudget fold。
        // 25-line inline BASBudgetFrame construction
        // collapses to typed factory call + 2 power
        // ClockService callbacks at the call site。
        let routedBudget = BASRoutedBudgetFactory
            .routedBudget(
                plannedBudget: plannedBudget,
                deviceRoute: powerClockService
                    .routeDevice(
                        deviceState: request.deviceState,
                        budget: plannedBudget),
                maintenanceAllowed: powerClockService
                    .scheduleMaintenance(
                        deviceState: request.deviceState,
                        budget: plannedBudget))
        // context-IR step 3 — the turn-level context compiler: ONE admission pass;
        // everything downstream consumes the plan (raw routedBudget use below this
        // line is linted RED — see BASTurnContextCompiler for scope + parity notes).
        let contextPlan = BASTurnContextCompiler.compile(routedBudget: routedBudget)

        let hostContext = hostProfileService.resolveHost(
            hostID: request.hostID,
            contextFrame: nil,
            riskCard: nil
        )
        markStage("l1_budget")
        let rawContextFrame = contextService.analyzeContext(
            userInput: request.userInput,
            hostContext: hostContext,
            budget: contextPlan.routedBudget
        )

        // M53 — L6 presence-eye main-chain wiring. Derive the
        // per-channel observation bundle at the same seam where the
        // coordinator obtains the context frame, using the same
        // `sessionID` / `turnID` formula that `buildRuntimeTrace`
        // emits downstream. This keeps L6 observations
        // coherent-by-construction with the L14 audit record.
        // M956 chapter 四百三 系统熵 第四刀:replace inline derivation
        // with the M954 BASFrameContext factory。Single-source pin
        // is now compile-time enforced — the formula lives in
        // `BASFrameContext.init(hostID:taskTypeRaw:runModeRaw:
        // recordedAt:)` (chapter 二百一一)。Byte-equal output per
        // M954's verbatim-pin test。
        let frameContext = request.makeFrameContext(
            rawContextFrame: rawContextFrame,
            routedBudget: contextPlan.routedBudget)
        let derivedSessionID = frameContext.sessionID
        let derivedTurnID = frameContext.turnID
        let contextFrame = rawContextFrame
            .withDerivedPresenceObservationBundle(
                frameContext: frameContext)

        // chapter 一千零四十三 / ADR-018 P2 — evaluate the PRIOR turn's
        // pending trials (N→N+1 closure). Placed at TURN-START (right
        // after the turn IDs derive, BEFORE this turn's own trials are
        // built in buildEvolutionGovernanceArtifacts below) so the
        // carrier can only ever hold turn N−1's trials — this is what
        // guarantees NEVER-EFFECTIVE-SAME-TURN
        // (BASEvolutionShadowSeat doctrine).
        //
        // OPT-IN: flag-off OR nil carrier OR nil sink → skipped →
        // byte-equal (红线 7). OBSERVATION-ONLY (mirrors
        // provisionalVerdictSink): feeds resolvedTrialSink ONLY — gates
        // nothing; NOT in any render / seal / verdict / governance /
        // canonical-bytes / hash path.
        if shadowTrialFeedbackEnabled,
           let pendingLedger = pendingTrialLedgerIn,
           let resolvedTrialSink,
           !pendingLedger.pendingTrials.isEmpty {
            let evaluated = pendingLedger.pendingTrials.map {
                BASShadowTrialFeedbackLedger.evaluate($0)
            }
            resolvedTrialSink(evaluated)
        }

        markStage("l0_context")
        var decomposeFrame = decomposeService.decompose(
            contextFrame: contextFrame,
            memoryHints: []
        )
        decomposeFrame.mirrorText = decomposeService.mirror(
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame
        )
        if decomposeFrame.contradictions.isEmpty {
            decomposeFrame.contradictions = decomposeService.checkContradiction(
                contextFrame: contextFrame,
                decomposeFrame: decomposeFrame
            )
        }

        // M54 — L7 mirror-blade main-chain wiring. Derive the
        // per-signal decomposition bundle at the seam where
        // `decomposeFrame` has been fully populated (facts / mirror
        // text / contradictions), reusing the same sessionID / turnID
        // that the M53 L6 bundle and `buildRuntimeTrace` downstream
        // use. This keeps L7 observations coherent-by-construction
        // with the L14 audit record and with L6 on the same turn.
        decomposeFrame = decomposeFrame
            .withDerivedDecompositionObservationBundle(
                frameContext: frameContext)

        markStage("l2_7_decompose")
        let memoryDeliberateCtx = memoryDeliberateStage(
            request: request,
            contextPlan: contextPlan,
            frameContext: frameContext,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            hostContext: hostContext)
        markStage("l8_to_l10")
        let riskBindCtx = riskStageA(
            request: request,
            contextPlan: contextPlan,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            hostContext: hostContext,
            derivedSessionID: derivedSessionID,
            derivedTurnID: derivedTurnID,
            memoryDeliberate: memoryDeliberateCtx)
        let riskEscalateCtx = riskStageB(
            request: request,
            contextPlan: contextPlan,
            contextFrame: contextFrame,
            frameContext: frameContext,
            hostContext: hostContext,
            derivedSessionID: derivedSessionID,
            derivedTurnID: derivedTurnID,
            memoryDeliberate: memoryDeliberateCtx,
            riskBind: riskBindCtx)
        markStage("l11_risk")
        let renderVerdictCtx = renderStageA(
            request: request,
            contextPlan: contextPlan,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            frameContext: frameContext,
            hostContext: hostContext,
            derivedSessionID: derivedSessionID,
            derivedTurnID: derivedTurnID,
            budgetFindings: budgetFindings,
            memoryDeliberate: memoryDeliberateCtx,
            riskBind: riskBindCtx,
            riskEscalate: riskEscalateCtx)
        let auditProjectionCtx = renderStageB(
            request: request,
            contextPlan: contextPlan,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            hostContext: hostContext,
            derivedSessionID: derivedSessionID,
            derivedTurnID: derivedTurnID,
            memoryDeliberate: memoryDeliberateCtx,
            riskEscalate: riskEscalateCtx,
            renderVerdict: renderVerdictCtx)
        markStage("l12_render")   // covers render → verdict/audit/trace assembly up to here
        var turnResult = assembleStage(
            request: request,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            hostContext: hostContext,
            memoryDeliberate: memoryDeliberateCtx,
            riskBind: riskBindCtx,
            riskEscalate: riskEscalateCtx,
            renderVerdict: renderVerdictCtx,
            auditProjection: auditProjectionCtx)
        markStage("tail")
        turnResult.layerTimingsMs = stageMs   // substrate #77 — observability-only attach
        return turnResult
    }

    /// A terminal stop ends the deliberation loop immediately; a non-terminal
    /// stop (the common converged case) lets it keep refining up to the
    /// requested budget. Exhaustive switch so a new stop reason forces an
    /// explicit terminal/non-terminal decision. (ch1040: lifted out of
    /// runTurn's deliberation loop — a zero-capture pure predicate, so the
    /// in-loop call site resolves to this method unchanged; byte-equal.)
    // internal: called by the stage methods (context-IR step 4 hoist)
    func isTerminalDeliberationStop(
        _ stopReason: BASThoughtStopReason?
    ) -> Bool {
        switch stopReason {
        case .blocked, .replaced, .maxLoopsReached, .guardTakeover:
            return true
        case .none, .candidateStable, .riskConverged,
             .uncertaintyBelowThreshold:
            return false
        }
    }

    /// M275 — async wrapper that runs a turn AND auto-flows
    /// every emitted ticket into the supplied lifecycle
    /// coordinator. Equivalent to:
    ///
    /// ```swift
    /// let turn = coord.runTurn(request)
    /// await lifecycleCoord.ingestTurnResult(turn)
    /// return turn
    /// ```
    ///
    /// Hosts that already had a lifecycle coordinator wired
    /// previously had to call those two lines manually after
    /// every turn. This wrapper makes that the one-line
    /// pattern. Pass-through behavior matches `runTurn(_:)`
    /// exactly when `lifecycleCoordinator` is nil — no auto-
    /// flow happens. Backward-compatible: existing callers
    /// keep using `runTurn(_:)` unchanged.
    ///
    /// - Parameters:
    ///   - request: same shape as `runTurn(_:)`
    ///   - lifecycleCoordinator: optional. When non-nil, every
    ///     ticket from the result auto-submits via
    ///     `BASUpdateTicketLifecycleCoordinator
    ///       .ingestTurnResult(_:)` (M267).
    public func runTurnAndIngest(
        _ request: BASEBrainTurnRequest,
        lifecycleCoordinator:
            BASUpdateTicketLifecycleCoordinator?
    ) async -> BASEBrainTurnResult {
        let turn = runTurn(request)
        if let coord = lifecycleCoordinator {
            _ = await coord.ingestTurnResult(turn)
        }
        return turn
    }
}
