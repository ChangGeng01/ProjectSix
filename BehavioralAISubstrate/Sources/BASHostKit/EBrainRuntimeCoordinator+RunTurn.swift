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

        let hostContext = hostProfileService.resolveHost(
            hostID: request.hostID,
            contextFrame: nil,
            riskCard: nil
        )
        markStage("l1_budget")
        let rawContextFrame = contextService.analyzeContext(
            userInput: request.userInput,
            hostContext: hostContext,
            budget: routedBudget
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
            routedBudget: routedBudget)
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
        let rawMemoryBundle = memoryService.retrieve(
            decomposeFrame: decomposeFrame,
            hostContext: hostContext,
            budget: routedBudget
        )
        let (memoryBundle, memoryFindings) = normalizeMemoryBundle(
            rawMemoryBundle,
            budget: routedBudget
        )
        let baseNeuralCore = neuralCoreService?.synthesize(
            budgetFrame: routedBudget,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle,
            hostProfile: hostContext,
            activeKillSwitches: request.activeKillSwitches
        ) ?? defaultNeuralCoreFrame(
            budgetFrame: routedBudget,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle,
            hostProfile: hostContext,
            activeKillSwitches: request.activeKillSwitches
        )

        // ch 1039 / ADR-018 P1 — one deliberation pass:
        // iterate → backfill → normalize → materialize. Extracted as
        // a local function so the loop below can run it repeatedly.
        // `priorCandidateIDs` is empty on the first pass (byte-equal
        // with the pre-P1 single pass) and carries the prior pass's
        // candidate IDs on subsequent passes.
        func runDeliberationPass(
            _ priorCandidateIDs: [String]
        ) -> (BASThoughtFrame, [BASRuntimeAuditFinding], BASNeuralThoughtMaterialization) {
            var thoughtFrame = loopService.iterate(
                decomposeFrame: decomposeFrame,
                memoryBundle: memoryBundle,
                budget: routedBudget,
                priorCandidateIDs: priorCandidateIDs
            )
            if thoughtFrame.candidates.isEmpty {
                thoughtFrame.candidates = loopService.proposePaths(
                    decomposeFrame: decomposeFrame,
                    memoryBundle: memoryBundle,
                    budget: routedBudget
                )
            }
            if thoughtFrame.forecasts.isEmpty {
                thoughtFrame.forecasts = loopService.forecast(
                    candidates: thoughtFrame.candidates,
                    decomposeFrame: decomposeFrame,
                    memoryBundle: memoryBundle
                )
            }
            if thoughtFrame.critiques.isEmpty {
                thoughtFrame.critiques = loopService.critique(
                    candidates: thoughtFrame.candidates,
                    forecasts: thoughtFrame.forecasts,
                    hostContext: hostContext
                )
            }
            let (normalizedThoughtFrame, passFindings) = normalizeThoughtFrame(
                thoughtFrame,
                budget: routedBudget
            )
            thoughtFrame = normalizedThoughtFrame
            thoughtFrame.organMap = baseNeuralCore.organMap
            let thoughtArtifacts = neuralCoreService?.materializeThoughtArtifacts(
                budgetFrame: routedBudget,
                contextFrame: contextFrame,
                decomposeFrame: decomposeFrame,
                memoryBundle: memoryBundle,
                hostProfile: hostContext,
                thoughtFrame: thoughtFrame
            ) ?? BASNeuralMaterializationCompiler.materializeThoughtArtifacts(
                thoughtFrame: thoughtFrame
            )
            thoughtFrame.candidateFrontier = thoughtArtifacts.candidateFrontier
            thoughtFrame.counterfactualBundles = thoughtArtifacts.counterfactualBundles
            thoughtFrame.critiqueBundles = thoughtArtifacts.critiqueBundles
            thoughtFrame.uncertaintyLedger = thoughtArtifacts.uncertaintyLedger
            thoughtFrame.evidenceDebts = thoughtArtifacts.evidenceDebts
            thoughtFrame.convergenceCertificate = thoughtArtifacts.convergenceCertificate
            thoughtFrame.loopLeaseReceipt = thoughtArtifacts.loopLeaseReceipt
            thoughtFrame.sovereignBreakpointHints = thoughtArtifacts.sovereignBreakpointHints
            return (thoughtFrame, passFindings, thoughtArtifacts)
        }

        // First deliberation pass — empty prior set → byte-equal with
        // the pre-P1 single pass (红线 7 identity).
        var (thoughtFrame, loopFindings, thoughtArtifacts) = runDeliberationPass([])

        // T3.2 — capture the ACTUAL deliberation pass budget for the (flag-gated, observation-only)
        // SSM neuromodulation suggestion record below. 1 when the loop is disabled (the single pass
        // above); the loop's own `targetPasses` when enabled. The first pass's `thoughtFrame.stepIndex`
        // feeds `targetPasses` but later passes REASSIGN `thoughtFrame`, so the value must be threaded
        // from here as a local — it cannot be recomputed at the SSM seam. Local capture ONLY: it feeds
        // no value path, and the suggestion composer that reads it is nested behind the default-off
        // `ssmNeuromodulationSuggestionsEnabled` flag (red line 7 / ADR-014 byte-equal + zero cost).
        var ssmActualTargetPasses = 1

        // ch 1039 / ADR-018 P1 — unified deliberation loop. OPT-IN,
        // default OFF: when `deliberationLoopEnabled` is false the
        // body never runs → byte-equal everywhere. When enabled, run
        // up to the service-requested budget (min(maxLoops,
        // stepIndex)) of refinement passes, each biased by the prior
        // pass's surviving candidate IDs, halting early on a terminal
        // stop. `targetPasses` reads the service's own stepIndex
        // (already = min(maxLoops, desiredLoopCount)), so the loop
        // never exceeds what the service requested or the budget.
        if deliberationLoopEnabled {
            var deliberationPassIndex = 1
            // ADR-018 P3 Commit 2 — thermal floor. On .hot/.critical the
            // device must not spend extra deliberation passes, so the routed
            // maxLoops is floored to at most 1 BEFORE the stepIndex min/max.
            // On .nominal/.warm this is a passthrough (byte-equal with prior
            // behaviour). It reads the SAME request.deviceState.thermalLevel
            // the power clock already used to compute routedBudget, so the
            // floor is consistent (no double-counting). Whole block is gated
            // by deliberationLoopEnabled → flag-off is byte-equal.
            let thermallyFlooredMaxLoops =
                BASDeliberationThermalFloor.flooredMaxLoops(
                    routedBudget.maxLoops,
                    thermalLevel: request.deviceState.thermalLevel)
            // OPT-IN surprise-gated EFFORT floor (mirrors the thermal floor above): a low effort tier spends
            // FEWER refinement passes (avoided compute), composing by `min` with the thermal floor — effort can
            // only TIGHTEN, never raise the routed pass budget. `request.effortPlan == nil` ⇒ passthrough,
            // byte-equal with the pre-effort pipeline (and `max(1, …)` below keeps ≥ 1 base pass).
            let effortFlooredMaxLoops =
                BASEffortBudgetConsumer.flooredMaxLoops(
                    thermallyFlooredMaxLoops,
                    effortPlan: request.effortPlan)
            let targetPasses = max(1, min(
                effortFlooredMaxLoops, thoughtFrame.stepIndex))
            // T3.2 — thread the actual pass budget to the SSM suggestion seam (local-only, see above).
            ssmActualTargetPasses = targetPasses
            while deliberationPassIndex < targetPasses,
                  !isTerminalDeliberationStop(thoughtFrame.stopReason) {
                deliberationPassIndex += 1
                let priorCandidateIDs = thoughtFrame.candidates
                    .map(\.candidateID)
                (thoughtFrame, loopFindings, thoughtArtifacts) = runDeliberationPass(
                    priorCandidateIDs)
            }
        }
        let publicProjection = neuralCoreService?.materializePublicProjection(
            budgetFrame: routedBudget,
            contextFrame: contextFrame,
            hostProfile: hostContext,
            thoughtFrame: thoughtFrame
        ) ?? BASNeuralMaterializationCompiler.materializePublicProjection(
            thoughtFrame: thoughtFrame
        )
        if let projectedCandidates = publicProjection.candidates {
            thoughtFrame.candidates = projectedCandidates
        }
        if let projectedForecasts = publicProjection.forecasts {
            thoughtFrame.forecasts = projectedForecasts
        }
        if let projectedCritiques = publicProjection.critiques {
            thoughtFrame.critiques = projectedCritiques
        }

        // M59 — L4 world-prior main-chain wiring. Derive the
        // per-candidate / per-signal world-prior bundle at the seam
        // where `materializeThoughtArtifacts` has populated
        // counterfactualBundles / critiqueBundles / uncertaintyLedger
        // and `publicProjection` has merged candidate/forecast/critique
        // lists — before tri-self tribunal runs so L10 can see L4
        // signals on the same turn. Reuses M53's derived (sessionID,
        // turnID) so L4 / L6 / L7 / L10 / L11 / L12 / L13 bundles on
        // this turn share strictly equal coordinates — the L14 audit
        // surface joins them by that key.
        thoughtFrame = thoughtFrame
            .withDerivedWorldPriorObservationBundle(
                frameContext: frameContext)

        var (triScores, mergedChoice) = triSelfService.mergeChoice(
            thoughtFrame: thoughtFrame,
            hostContext: hostContext
        )
        thoughtFrame.triScores = triScores
        thoughtFrame.vetoMarks = mergedChoice.vetoMarks
        thoughtFrame.tradeoffLedgers = mergedChoice.tradeoffLedgers
        thoughtFrame.agencyReservation = mergedChoice.agencyReservation
        thoughtFrame.remandOrders = mergedChoice.remandOrders
        thoughtFrame.courtDecisionDraft = mergedChoice.courtDecisionDraft
        let reconciledThoughtFrame = reconcileDreamLoopConvergence(
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice
        )
        if reconciledThoughtFrame.stopReason != thoughtFrame.stopReason {
            thoughtFrame = reconciledThoughtFrame
            (triScores, mergedChoice) = triSelfService.mergeChoice(
                thoughtFrame: thoughtFrame,
                hostContext: hostContext
            )
            thoughtFrame.triScores = triScores
            thoughtFrame.vetoMarks = mergedChoice.vetoMarks
            thoughtFrame.tradeoffLedgers = mergedChoice.tradeoffLedgers
            thoughtFrame.agencyReservation = mergedChoice.agencyReservation
            thoughtFrame.remandOrders = mergedChoice.remandOrders
            thoughtFrame.courtDecisionDraft = mergedChoice.courtDecisionDraft
        }

        // M55 — L10 tri-self tribunal main-chain wiring. Derive the
        // per-voice tribunal bundle at the seam where the tribunal
        // has settled — after `triSelfService.mergeChoice` (and any
        // reconciliation rerun) has filled in triScores / vetoMarks
        // / tradeoffLedgers / remandOrders / courtDecisionDraft —
        // reusing the same sessionID / turnID that the M53 L6 bundle,
        // M54 L7 bundle, and `buildRuntimeTrace` downstream use. This
        // keeps L10 observations coherent-by-construction with the
        // L14 audit record and with L6 / L7 / L9 on the same turn.
        thoughtFrame = thoughtFrame
            .withDerivedTribunalObservationBundle(
                frameContext: frameContext)

        let riskService = self.riskService
        markStage("l8_to_l10")
        let rawRiskDecisionPackage = riskService.buildRiskDecisionPackage(
            contextFrame: contextFrame,
            thoughtFrame: thoughtFrame,
            triScores: triScores,
            budget: routedBudget
        )
        let rawRiskCard = rawRiskDecisionPackage.riskCard
        let rawActionPermit = rawRiskDecisionPackage.actionPermit
        let (riskCard, actionPermit, riskFindings) = normalizeRiskDecision(
            riskCard: rawRiskCard,
            actionPermit: rawActionPermit,
            budget: routedBudget,
            activeKillSwitches: request.activeKillSwitches
        )
        var normalizedRiskDecisionPackage = projectedRiskDecisionPackage(
            from: rawRiskDecisionPackage,
            riskCard: riskCard,
            actionPermit: actionPermit
        )
        let resolvedRiskService = riskService
        let bindings = neuralCoreService?.materializeRiskBindings(
            budgetFrame: routedBudget,
            contextFrame: contextFrame,
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice,
            riskCard: riskCard,
            actionPermit: actionPermit
        ) ?? BASNeuralMaterializationCompiler.materializeRiskBindings(
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice,
            riskCard: riskCard,
            actionPermit: actionPermit,
            riskLevelResolver: { score in
                resolvedRiskService.riskLevel(for: score)
            }
        )
        let primaryBinding = BASNeuralMaterializationCompiler.selectedRiskBinding(
            from: bindings,
            mergedChoice: mergedChoice,
            thoughtFrame: thoughtFrame
        )
        var boundRiskCard = primaryBinding?.riskCard ?? riskCard
        // ADR-019 P1.5a — opt-in deliberation caution, injected on the
        // FINAL bound card (post-binding) so it is NOT halved by the
        // binding's ×0.5 re-derivation nor offset by the loop's own
        // bias (ADR-019 §10). When the opt-in deliberation loop ran on a
        // genuinely-uncertain matter, raise caution enough to cross a
        // risk band. Caution-INCREASING only (cannot lower the band) →
        // no sovereign gate. Flag-off → no injection → byte-equal
        // (红线 7); this is the ONLY seam that consumes the flag here.
        //
        // ch1042 ADR-020 Step 4 — the added caution is now FLOORED by
        // genuine evidence resolution. Instead of always adding the full
        // `uncertainDeliberationRiskIncrement`, add
        // `withheldIncrement = max(0, increment − credit)`, where the
        // credit is the fraction of the turn's TYPED unknowns
        // (`decomposeFrame.unknownRecords`) that the opt-in
        // `evidenceLedger` resolves by EXACT key. So the loop can WITHHOLD
        // its OWN added caution (down to 0) when stored evidence resolves
        // the uncertainty. The loop's contribution stays in [0, increment]
        // — it never subtracts MORE than it added (the §14-safe shape). NOTE
        // (ADR-020 §9 correction): the floor is "withholds ≤ its own added
        // increment, vs the SAME-SELECTION on_stuck baseline" — NOT "≥ the
        // loop-off baseline". On a turn where the ch1041 reversibility-tilt
        // also fires, the safer (more-reversible) selected candidate has a
        // slightly-lower binding, so the resolved total can land marginally
        // BELOW the loop-off scalar even though caution-withholding alone
        // never goes negative. `evidenceLedger` nil (default everywhere) →
        // credit 0 → withheld = full increment → byte-equal with the
        // pre-Step-4 P1.5a behavior (红线 7).
        if deliberationLoopEnabled,
           BASDeliberationCaution.isGenuinelyUncertain(
               confidenceFloor: thoughtFrame.uncertaintyLedger?.confidenceFloor,
               maxEvidenceDebt: thoughtFrame.evidenceDebts?
                   .map(\.debtWeight).max(),
               leaseEnded: thoughtFrame.convergenceCertificate?
                   .stoppingMode == .leaseEnd) {
            let requiredKeys =
                BASDeliberationResolutionCredit.requiredEvidenceKeys(
                    unknownRecords: decomposeFrame.unknownRecords)
            let withheld =
                BASDeliberationResolutionCredit.withheldIncrement(
                    requiredKeys: requiredKeys,
                    ledger: evidenceLedger,
                    increment: BASDeliberationCaution
                        .uncertainDeliberationRiskIncrement)
            let raised = min(1, boundRiskCard.totalRisk + withheld)
            let raisedLevel = resolvedRiskService.riskLevel(for: raised)
            boundRiskCard.totalRisk = raised
            boundRiskCard.riskLevel = raisedLevel
            boundRiskCard.assertionCeiling =
                raisedLevel >= .high ? "guarded" : "standard"
            if boundRiskCard.sovereignHintLevel == nil, raisedLevel >= .high {
                boundRiskCard.sovereignHintLevel = "medium"
            }
            boundRiskCard.factors =
                boundRiskCard.factors + ["deliberation_uncertain_caution"]
            // ch1042 ADR-020 Step 4 write-back / audit — emit the evidence
            // atoms that resolved this turn's unknowns (drove the
            // withholding) for host persistence + auditability。
            // OBSERVATION-ONLY side-channel (feeds no render/seal/verdict/
            // hash)。 Nil sink OR nil ledger (defaults) → no emission →
            // byte-equal (红线 7)。
            if let resolvedEvidenceSink, let evidenceLedger {
                let resolvedKeys = BASEvidenceMatcher.resolvedKeys(
                    requiredKeys: requiredKeys, in: evidenceLedger)
                if !resolvedKeys.isEmpty {
                    resolvedEvidenceSink(
                        evidenceLedger.atoms.filter {
                            resolvedKeys.contains($0.evidenceKey)
                        })
                }
            }
        }
        // chapter 一百八十六 / ADR-019 §15 — SSM caution operator
        // (Mamba/SSM as an AUTHORITATIVE, raise-caution-only L11 INPUT).
        // Mirrors the P1.5a deliberation-caution seam ABOVE exactly — on
        // the SAME post-binding `boundRiskCard`, with the SAME genuine-
        // uncertainty predicate — but driven by the CPU-deterministic
        // `ssmCaution` over this turn's THREE live sources (L7 affect-
        // layers + cross-turn `request.turnHistory` + L9 candidates).
        //
        // SAFE BY CONSTRUCTION:
        //   • RAISE-ONLY — `raisedTotalRisk(c,s) ≥ c` (== c at s=0, ≤ 1);
        //     a pre-render caution REDUCTION is architecturally impossible
        //     (verdict-after-render, ADR-019 §14 — the not-built reduction), so this can only RAISE.
        //     The `assertionCeiling` write only ever sets "guarded" (the
        //     high-risk ceiling) and otherwise LEAVES THE EXISTING VALUE —
        //     so when both this and the P1.5a block fire it never resets a
        //     "guarded" ceiling back to "standard" (raise-only on the
        //     ceiling too, stricter than P1.5a's unconditional write).
        //   • 不变量 #2 神经不掌权 — writes ONLY `boundRiskCard`, an INPUT the
        //     sovereign verdict GATES downstream; never a verdict / permit /
        //     commit token, and it can never DOWNGRADE.
        //   • 红线 7 / ADR-014 — `ssmCautionOperatorEnabled` is the FIRST
        //     condition, so when OFF (default) the scan is never even run →
        //     byte-equal + zero cost. `observation(...)` is nil when all
        //     three sources are empty → clean per-turn no-op. The
        //     observation side-channel feeds no render / seal / verdict /
        //     hash (nil sink → no emission → byte-equal).
        //   • ch883 — `BASSSMCautionInput.observation` runs the SYNC pure-
        //     Swift CPU scan (`BASSSMScanCPUReference`); no GPU / async /
        //     CoreML on the value path, so `runTurn` stays sync + byte-det.
        // chapter 一百八十九 — EVERY-TURN temporal state-tracking. The operator (scan + cross-turn
        // state) runs on EVERY flag-on turn with non-empty sources, so the recurrence evolves
        // continuously (no gaps on calm turns — standard SSM/Mamba semantics: the state always tracks
        // the input). The authoritative RAISE stays gated by genuine uncertainty (the condition is
        // UNCHANGED), so on a non-uncertain turn `boundRiskCard` is untouched ⇒ the RESULT is byte-equal
        // to the pre-every-turn seam; only the observation cadence broadens. The observation (carrying
        // the new ssmStateOut) is emitted every flag-on turn so the host carries the state forward —
        // observation-only side-channel, never on the value path.
        if ssmCautionOperatorEnabled,
           let ssmObservation = BASSSMCautionInput.observation(
               sessionID: derivedSessionID,
               turnID: derivedTurnID,
               // Affect is MATERIALIZED from the authoritative runtime frame's typed
               // pressure vectors (typed affect is not on the value path otherwise —
               // it lives only on the audit-shape dissection frame). This projection
               // runs ONLY here, inside the flag-gated block, so flag-off is byte-equal.
               affectLayers: BASAffectLayerProjection.project(from: decomposeFrame),
               turnHistory: request.turnHistory,
               candidates: thoughtFrame.candidates,
               // chapter 一百八十八 — carry the prior turn's SSM hidden state (the host folds the
               // prior observation's `ssmStateOut` into `request.priorSSMState`) so the operator is
               // TEMPORAL: caution reflects sustained-pressure trajectory. nil ⇒ fresh recurrence
               // ⇒ byte-equal with the stateless operator. The emitted observation carries the new
               // `ssmStateOut` out via the (opt-in) sink — never on the value path.
               priorState: request.priorSSMState) {
            // RAISE only on a genuinely-uncertain turn — the AUTHORITATIVE condition, UNCHANGED from the
            // pre-every-turn seam (so the result is byte-equal on non-uncertain turns; the state-tracking
            // scan above is observation-only).
            if BASDeliberationCaution.isGenuinelyUncertain(
                   confidenceFloor: thoughtFrame.uncertaintyLedger?.confidenceFloor,
                   maxEvidenceDebt: thoughtFrame.evidenceDebts?
                       .map(\.debtWeight).max(),
                   leaseEnded: thoughtFrame.convergenceCertificate?
                       .stoppingMode == .leaseEnd) {
                let raised = BASSSMCautionInput.raisedTotalRisk(
                    boundRiskCard.totalRisk, ssmCaution: ssmObservation.ssmCaution)
                let raisedLevel = resolvedRiskService.riskLevel(for: raised)
                boundRiskCard.totalRisk = raised
                boundRiskCard.riskLevel = raisedLevel
                // RAISE-ONLY on the ceiling: set "guarded" at high, else leave
                // the existing value untouched (never downgrade to "standard").
                if raisedLevel >= .high {
                    boundRiskCard.assertionCeiling = "guarded"
                }
                if boundRiskCard.sovereignHintLevel == nil, raisedLevel >= .high {
                    boundRiskCard.sovereignHintLevel = "medium"
                }
                boundRiskCard.factors =
                    boundRiskCard.factors + ["ssm_temporal_caution"]
            }
            // OBSERVATION-ONLY side-channel — emitted EVERY flag-on turn (continuous state-tracking).
            // Nil sink (default) → no emission → byte-equal (红线 7). Feeds no render/seal/verdict/hash.
            //
            // T3.2 — SSM neuromodulation suggestion RECORD (NESTED OPT-IN, default OFF). When
            // `ssmNeuromodulationSuggestionsEnabled` AND the sink is set, attach the pure
            // raise-only/conserve-only suggestion (`BASSSMNeuromodulationField`) to the EMITTED COPY of
            // the observation only — NEVER to `boundRiskCard` / `thoughtFrame` / the returned result, so
            // the replay-digest preimage is untouched by construction (zero SSM fields in
            // `BASEBrainTurnResult`). The suggestion is a RECORD forever (gates never auto-promote);
            // nothing here or downstream applies it. `flooredMaxLoops` is the SAME pure thermal-floor
            // bound the deliberation loop computes from the SAME inputs, so the suggested band matches
            // the live loop's own normalization band. Flag-off (default) takes the `else` branch — the
            // emission is byte-identical to the pre-T3.2 seam and the suggestion is never computed
            // (红线 7 / ADR-014: byte-equal + zero cost).
            if ssmNeuromodulationSuggestionsEnabled,
               let suggestionSink = ssmCautionObservationSink {
                let suggestionBandCeiling =
                    BASDeliberationThermalFloor.flooredMaxLoops(
                        routedBudget.maxLoops,
                        thermalLevel: request.deviceState.thermalLevel)
                suggestionSink(ssmObservation.attaching(
                    neuromodulationSuggestion:
                        BASSSMNeuromodulationField.suggestion(
                            ssmCaution: ssmObservation.ssmCaution,
                            actualTargetPasses: ssmActualTargetPasses,
                            thermallyFlooredMaxLoops: suggestionBandCeiling,
                            thermalLevel: request.deviceState.thermalLevel,
                            npuAvailable: request.deviceState.npuAvailable)))
            } else {
                ssmCautionObservationSink?(ssmObservation)
            }
        }
        // ADR-039 Phase 4 — OPT-IN Metal SSM reasoning emission (independent of the CPU caution operator
        // above). Emits the per-turn DETERMINISTIC scan input (the SAME pure builder the CPU path is built
        // from) to the default-nil reasoning sink; the HOST runs the Metal SSMScan on it OFF this sync turn
        // thread, so a Metal wedge can NEVER block the deterministic path (ADR-038/§2 boundary rule). The
        // Metal result is a NON-governance side-channel — it feeds NO verdict/permit/commit/render/seal/
        // replay (never enters the returned BASEBrainTurnResult, the replay-digest preimage) and NEVER folds
        // into `request.priorSSMState` (the CPU `ssmStateOut` owns the deterministic recurrence). Flag-off /
        // nil sink ⇒ no emission ⇒ byte-equal (红线 7). Mutates nothing on the value path.
        if ssmMetalReasoningEnabled, let reasoningSink = ssmReasoningInputSink,
           let reasoningScan = BASMambaTurnSignalBuilder.scanInput(
               affectLayers: BASAffectLayerProjection.project(from: decomposeFrame),
               turnHistory: request.turnHistory,
               candidates: thoughtFrame.candidates) {
            reasoningSink(BASSSMReasoningTurnInput(
                sessionID: derivedSessionID, turnID: derivedTurnID, scanInput: reasoningScan))
        }
        // ADR-039 Phase 5 — OPT-IN Metal attention reasoning emission (the FIRST live consumer of the
        // Phase-3 dispatch router). Emits the per-turn DETERMINISTIC attention input (affect → Q,
        // candidates → K=V) to the default-nil sink; the HOST runs Metal attention OFF this sync turn
        // thread (Phase-3 routed: thermal-critical ⇒ CPU), so a Metal wedge can NEVER block the
        // deterministic path. NON-governance: the salience signal feeds NO verdict/permit/commit/render/
        // seal/replay (never enters BASEBrainTurnResult). Flag-off / nil sink ⇒ no emission ⇒ byte-equal.
        if attentionMetalReasoningEnabled, let attentionSink = attentionReasoningInputSink,
           let attentionInput = BASAttentionTurnSignalBuilder.signal(
               affectLayers: BASAffectLayerProjection.project(from: decomposeFrame),
               candidates: thoughtFrame.candidates) {
            attentionSink(BASAttentionReasoningTurnInput(
                sessionID: derivedSessionID, turnID: derivedTurnID, input: attentionInput))
        }
        // M392 — `boundActionPermit` is rebound by the Cthulhu
        // doctrine gate block below (M303/M304/M384/M320/M385).
        // The block runs BEFORE `applySovereignNeuralContract`,
        // `materializeToolIntent`, `actionService.render`, and
        // `projectedRenderedOutput`, so the escalation /
        // assertion-ceiling cap is visible to every downstream
        // consumer (not just audit emission). M399's
        // `--cthulhu-end-to-end-demo` empirically verifies the
        // post-gate permit reaches surface render (e.g. the demo
        // run on 2026-05-02 produced `permit.mode = .delay,
        // stackedModes = [.draftOnly], assertionCeiling =
        // "meta-only"` after the gate fired, all reflected
        // verbatim in `result.actionPermit`).
        var boundActionPermit = primaryBinding?.actionPermit ?? actionPermit
        normalizedRiskDecisionPackage = projectedRiskDecisionPackage(
            from: normalizedRiskDecisionPackage,
            riskCard: boundRiskCard,
            actionPermit: boundActionPermit,
            binding: primaryBinding
        )
        thoughtFrame.riskBindings = bindings.isEmpty ? nil : bindings
        thoughtFrame.riskCard = boundRiskCard
        thoughtFrame.actionPermit = boundActionPermit
        thoughtFrame.riskDecisionPackage = normalizedRiskDecisionPackage

        // M392 — Cthulhu doctrine pressure / anchor / unknown-reserve
        // derives + permit gating wires moved UP to here (was at the
        // audit-projection seam, line 681+). The wires now fire
        // BEFORE `actionService.render(...)` and
        // `projectedRenderedOutput(...)`, so the rendered surface
        // reflects the escalated stackedModes (M384) and the capped
        // assertionCeiling (M385). Pre-M392 the wires were
        // audit-visible only because the surface had already been
        // sealed against the un-escalated permit; post-M392 the
        // surface stays consistent with the persisted permit.
        //
        // The audit-projection block at line 681+ continues to
        // derive its own copies of `abyssalPressureForAudit`,
        // `humanAnchorSignalForAudit`, and `unknownReserveForAudit`
        // — those derives are pure functions of the same inputs and
        // produce identical outputs for audit emission. This is
        // intentional: the upstream derives feed the gating wires;
        // the downstream derives feed audit emission. Same values
        // by construction; separate locals for separation of
        // concerns.
        // chapter 五百六 / M1403 — gate-side derive trio fold。
        // 3 ForGate derives consolidated via shadow-rebinding。
        // V1 byte-equality preserved by factory's identical
        // compute order (chapter 三百九二 replay contract)。
        let gateSideDeriveTrioForGate =
            BASTurnAuditProjectionsGateSideDeriveTrio
                .compute(
                    sessionID: derivedSessionID,
                    hostID: hostContext.hostID,
                    riskLevel: boundRiskCard.riskLevel,
                    permitMode: boundActionPermit.mode,
                    candidateCount:
                        thoughtFrame.candidates.count,
                    uncertaintyLedger:
                        thoughtFrame.uncertaintyLedger,
                    evidenceDebtCount:
                        thoughtFrame.evidenceDebts?
                            .count ?? 0,
                    defaultConfidenceFloorWhenNoUncertaintyLedger:
                        Self
                        .defaultConfidenceFloorWhenNoUncertaintyLedger)
        let abyssalPressureForGate =
            gateSideDeriveTrioForGate.abyssalPressure
        let humanAnchorSignalForGate =
            gateSideDeriveTrioForGate.humanAnchorSignal
        let abyssalEscalation = BASAbyssalPermitEscalation
            .escalate(
                permit: boundActionPermit,
                pressure: abyssalPressureForGate,
                humanAnchor: humanAnchorSignalForGate)
        boundActionPermit = abyssalEscalation.permit
        let unknownReserveForGate =
            gateSideDeriveTrioForGate.unknownReserve
        let assertionCeilingDecisionForGate = BASAssertionCeilingGate
            .cap(
                permit: boundActionPermit,
                reserve: unknownReserveForGate)
        boundActionPermit = assertionCeilingDecisionForGate.permit
        // M406 — Kunlun axis-alignment escalation. Run AFTER the
        // M384 abyssal escalation + M385 assertion-ceiling cap so
        // axis deviations compose with Cthulhu pressure on the
        // same `boundActionPermit`. Doctrine: when both fire on
        // the same turn, both reason codes accumulate; mode
        // (single commit mouth) stays at L11.
        //
        // The "for-gate" alignment derive mirrors the audit-side
        // derive in the audit-projection seam below (line ~960).
        // Same inputs (host context + risk level + permit mode +
        // candidate count) → same output by construction. The
        // separation of locals follows the M392 pattern: upstream
        // values feed the gate; downstream values feed audit
        // emission.
        // chapter 四百九十四 / M1355 — Gate-side Kunlun axis fold。
        // The SAME inline-construction block (~89 LOC) that lived
        // at audit-side (lines ~1865-1953 pre-fold, folded by
        // chapter 493 M1348-M1349) ALSO lived at gate-side here。
        // M595 chapter 一百六十六 cross-site drift fix established
        // both sites must share predicate semantics — chapter 494
        // now shares the FACTORY (not just the semantics)。
        //
        // Gate-side passes `quarantineRecordsIsEmpty: true` to
        // skip the audit-side quarantine check (quarantineRecords
        // is computed AFTER this seam — the substrate's permit
        // synthesis already factors quarantine state into
        // permit.mode at this point per M595)。
        let kunlunAxisProtocolForGate =
            BASTurnAuditProjectionsKunlunAxisProtocol.compute(
                sessionID: derivedSessionID,
                hostID: hostContext.hostID,
                permitMode: boundActionPermit.mode,
                riskLevel: boundRiskCard.riskLevel,
                quarantineRecordsIsEmpty: true,
                humanAnchorRecommendedSurfaceTone:
                    humanAnchorSignalForGate
                        .recommendedSurfaceTone,
                sovereignEscalationHint:
                    abyssalPressureForGate
                        .sovereignEscalationHint,
                primaryCandidateID:
                    thoughtFrame.candidates.first?
                        .candidateID ?? "no-candidate",
                kunlunActiveLayerRefs:
                    Self.kunlunActiveLayerRefs,
                centerlineRules:
                    Self.kunlunCenterlineRules(
                        for: boundActionPermit.mode),
                kunlunAxisDeviationThreshold: Self
                    .kunlunAxisDeviationThreshold)
        let kunlunAxisForGate = kunlunAxisProtocolForGate.axis
        let kunlunAxisAlignmentForGate =
            kunlunAxisProtocolForGate.alignment
        let kunlunEscalation = BASKunlunPermitEscalation
            .escalate(
                permit: boundActionPermit,
                alignment: kunlunAxisAlignmentForGate,
                humanAnchor: humanAnchorSignalForGate)
        boundActionPermit = kunlunEscalation.permit
        thoughtFrame.actionPermit = boundActionPermit
        // M417 fix-pin (chapter 九十七 deep-review H1): capture
        // escalation-decision reason codes for audit emission.
        // When red line #8 fires (humanAnchor.tone == .reserved),
        // both M384 abyssal and M406 kunlun escalations return
        // the original permit unchanged with suppression codes
        // attached to the *decision*, not the permit. Pre-fix
        // these codes were discarded; the audit walker had no
        // way to tell "no axis deviation this turn" apart from
        // "axis deviation suppressed by anchor-reserved." We
        // now harvest both decisions' reason codes and feed them
        // into the audit entry's signalRefs so red line #8
        // honoring is observable.
        let escalationSuppressionCodes: [String] = {
            var codes: [String] = []
            if abyssalEscalation.suppressedByHumanAnchor {
                codes.append(contentsOf:
                    abyssalEscalation.reasonCodes)
            }
            if kunlunEscalation.suppressedByHumanAnchor {
                codes.append(contentsOf:
                    kunlunEscalation.reasonCodes)
            }
            return codes
        }()
        // M448-M450 (chapter 一百十八) — production wires for
        // chapter 一百十七 Cthulhu helpers. Each call composes
        // safely with the M384 / M385 / M406 chain above:
        //
        //  - M448 (was M444 helper): derive watcher-hint
        //    projections from existing turn state. Pure function;
        //    no permit / verdict mutation.
        //  - M449 (was M445 helper): compose fog with M385
        //    BASUnknownReserve via assertion-ceiling cap. Permit
        //    narrowing only.
        //  - M450 (was M446 helper): derive
        //    `BASCosmicColdCounterweight` from risk + abyssal
        //    pressure + human-anchor signals; pass into
        //    `BASCthulhuPermitEscalation.escalate` to compose with
        //    M384 / M406 stackedModes.
        //
        // Doctrine: pure derive; no verdict escalation; single
        // commit mouth preserved (only narrows assertionCeiling
        // and appends to stackedModes).
        // chapter 五百六 / M1402 — abyssal+thermal trio fold。
        // 3 ForAudit declarations + their inline derive calls
        // collapsed into a single typed factory call。 Shadow
        // re-bindings below preserve all downstream reader
        // sites unchanged。 V1 byte-equality preserved by
        // factory's identical compute order。
        let abyssalThermalTrioForAudit =
            BASTurnAuditProjectionsAbyssalThermalTrio
                .compute(
                    routedBudget: routedBudget,
                    turnID: derivedTurnID)
        // chapter 五百三十四 / M1513 — dead-code purge:
        // abyssalRunModeForAudit + abyssBudgetForAudit
        // shadow re-bindings (chapter 506 M1402) never
        // read downstream。 Deleted。
        // M456 (chapter 一百二十) — L8 memory thermal layer
        // projection from runMode at audit-projection time.
        // Now consumed via the typed trio factory above。
        let memoryTemperatureLayerForAudit =
            abyssalThermalTrioForAudit
                .memoryTemperatureLayer
        // M480-M485 (chapter 一百二十五) — Kunlun production
        // wires for chapter-一百二十二/三 schemas. Each derive
        // is a pure function from existing turn state; never
        // mutates permit / verdict / lifecycle state.
        // chapter 四百七十八 / M1289 — V1 fold PILOT replaces
        // 3 separate `let *ForAudit = ...` declarations with
        // one typed factory call。 Byte-equal by construction
        // (factory dispatches the same 3 derive calls in the
        // same order)。 Shadow re-bindings preserve all
        // downstream reader sites unchanged。 BASStressSweep
        // Harness dual mode (M1290) is the regression guard。
        let kunlunTrioForAudit = BASTurnAuditProjectionsKunlunTrio
            .compute(
                routedBudget: routedBudget,
                riskLevel: boundRiskCard.riskLevel,
                permit: boundActionPermit,
                turnID: derivedTurnID,
                sessionID: derivedSessionID,
                kunlunAxisID: kunlunAxisForGate.axisID)
        // chapter 五百三十四 / M1513 — dead-code purge:
        // ascentLeaseForAudit + axisDeviationForAudit +
        // gatePressureForAudit shadow re-bindings
        // (chapter 478 M1289) never read downstream。
        // Deleted。 Trio is now consumed via input blocks。
        // chapter 四百八十五 / M1317 — V1 fold cluster A
        // continuation。 6 declarations folded via hexa factory。
        let kunlunHexaForAudit = BASTurnAuditProjectionsKunlunHexa
            .compute(
                runMode: routedBudget.runMode,
                riskLevel: boundRiskCard.riskLevel,
                permit: boundActionPermit,
                candidates: thoughtFrame.candidates,
                turnID: derivedTurnID)
        // chapter 五百三十四 / M1513 — dead-code purge:
        // 6 hexa shadow re-bindings (yaochiMemoryLayer +
        // tianhengProfile + jadePermitGrade +
        // ascentBranches + restSteps + returnPaths) never
        // read downstream。 Deleted。 Hexa is now consumed
        // via input blocks。
        // chapter 四百八十五 / M1318 — V1 fold trio #2
        let kunlunTrioTwoForAudit = BASTurnAuditProjectionsKunlunTrioTwo
            .compute(
                runMode: routedBudget.runMode,
                riskLevel: boundRiskCard.riskLevel,
                candidates: thoughtFrame.candidates,
                organRefMorph:
                    thoughtFrame.organMap?.morph.rawValue
                    ?? "unknown",
                turnID: derivedTurnID,
                sessionID: derivedSessionID)
        // chapter 五百三十四 / M1513 — dead-code purge:
        // 3 trio-two shadow re-bindings (jadeCasket +
        // jadeRefinementTickets + jadeFidelityMap) never
        // read downstream。 Deleted。
        // chapter 四百八十六 / M1320 — V1 cluster A FINAL 6 fold
        let kunlunHexaTwoForAudit =
            BASTurnAuditProjectionsKunlunHexaTwo.compute(
                hostID: hostContext.hostID,
                sessionID: derivedSessionID,
                turnID: derivedTurnID,
                unknownRefs: unknownReserveForGate.unknownRefs,
                assertionCeiling: unknownReserveForGate
                    .assertionCeiling,
                riskLevel: boundRiskCard.riskLevel,
                candidates: thoughtFrame.candidates)
        // chapter 五百三十四 / M1513 — dead-code purge:
        // 6 hexa-two shadow re-bindings (hostJadeRegister
        // + jadeMirrorDraft + kunlunUnnamableSet +
        // returnPathRefs + kunlunAscentView +
        // kunlunFarWestReserve) never read downstream。
        // Deleted。
        // chapter 四百八十六 / M1322 — V1 cluster B start
        let cthulhuPentaForAudit =
            BASTurnAuditProjectionsCthulhuPenta.compute(
                routedBudget: routedBudget,
                runMode: routedBudget.runMode,
                hostID: hostContext.hostID,
                riskLevel: boundRiskCard.riskLevel,
                memoryTemperatureLayer:
                    memoryTemperatureLayerForAudit,
                candidates: thoughtFrame.candidates,
                unknownRefs: unknownReserveForGate.unknownRefs,
                assertionCeilingRaw: unknownReserveForGate
                    .assertionCeiling.rawValue,
                turnID: derivedTurnID)
        // chapter 五百三十四 / M1513 — dead-code purge:
        // 4 cthulhu-penta shadow re-bindings
        // (abyssalOrganAlias + humanAnchorProfile +
        // sealedMemory + cosmicScaleView) never read
        // downstream。 Deleted。 ontologyFogForAudit
        // remains as it IS consumed below。
        // chapter 六百八十七 / M2119 第二刀 — Phase O
        // WIRE-IN: the 3 *Two/*Penta cluster locals now
        // also flow through BASTurnAuditProjectionsLate
        // ClusterFinalBundle (chapter 686 / M2114) as
        // typed groundwork for the chapter 688 V1-only
        // helper deletion。 The 3 original locals (kunlun
        // TrioTwoForAudit + kunlunHexaTwoForAudit +
        // cthulhuPentaForAudit) remain unchanged — only
        // the ontologyFog DERIVED local now reads from
        // the bundle's typed accessor。 V1 byte-equality
        // preserved (bundle.ontologyFog ==
        // cthulhuPentaForAudit.ontologyFog by construction)。
        let lateClusterFinalBundleForAudit =
            BASTurnAuditProjectionsLateClusterFinalBundle(
                kunlunTrioTwo: kunlunTrioTwoForAudit,
                kunlunHexaTwo: kunlunHexaTwoForAudit,
                cthulhuPenta: cthulhuPentaForAudit)
        let ontologyFogForAudit =
            lateClusterFinalBundleForAudit.ontologyFog
        // M452 (chapter 一百十九) — derive L9 retention loop from
        // unknown reserve. Closes the chapter 一百十八 nil
        // placeholder for `retentionLoop:` in M449. Returns nil
        // when reserve.assertionCeiling == .unrestricted (no
        // retention needed for wide-open trust).
        let unknownRetentionLoopForGate = BASUnknownRetentionLoop
            .derive(
                from: unknownReserveForGate,
                turnID: derivedTurnID)
        // M449 — fog assertion-ceiling cap (composes with M385).
        // Chapter 一百十九 M454: retention loop now non-nil when
        // unknown reserve is below `.unrestricted` ceiling.
        let cthulhuAssertionDecision = BASCthulhuAssertionCeilingGate
            .cap(
                permit: boundActionPermit,
                ontologyFog: ontologyFogForAudit,
                retentionLoop: unknownRetentionLoopForGate)
        boundActionPermit = cthulhuAssertionDecision.permit
        thoughtFrame.actionPermit = boundActionPermit
        // M450 — derive cosmic-cold counterweight from risk
        // signals + L10 anti-paternalism heuristics; pass into
        // M446 escalation. Counterweight axes:
        //  - dignityBias high when risk is extreme + permit
        //    narrows agency (i.e. mode != .answer)
        //  - agencyFloor high when candidate count is low (≤1)
        //  - antiFatalism high when risk level is high or extreme
        //    (reject "this is just how it is" framing)
        //  - antiPaternalism high when permit narrows below
        //    .answer mode (avoid deciding for the host)
        // chapter 五百十 / M1417-M1418 — counterweight fold。
        // 13-line inline construction collapses to typed
        // factory call。 The 4 Self.* helpers stay file
        // private;factory takes precomputed values to
        // keep helper visibility unchanged。
        let counterweightForGate =
            BASTurnAuditProjectionsCounterweightFactory
                .compute(
                    sessionID: derivedSessionID,
                    dignityBias:
                        Self.dignityBiasFromRisk(
                            boundRiskCard.riskLevel,
                            permitMode:
                                boundActionPermit.mode),
                    agencyFloor:
                        Self.agencyFloorFromCandidates(
                            thoughtFrame.candidates
                                .count),
                    antiFatalism:
                        Self.antiFatalismFromRisk(
                            boundRiskCard.riskLevel),
                    antiPaternalism:
                        Self.antiPaternalismFromPermit(
                            boundActionPermit.mode))
        // M453 (chapter 一百十九) — derive [BASNonEuclideanCandidate]
        // from low-confidence candidates. Closes the chapter 一百十八
        // empty-array placeholder for `nonEuclideanCandidates:` in
        // M450. Returns empty array when no candidate has
        // confidence below `nonEuclideanConfidenceThreshold`.
        let nonEuclideanCandidatesForGate = BASNonEuclideanCandidate
            .deriveAll(
                from: thoughtFrame.candidates,
                turnID: derivedTurnID)
        let cthulhuEscalation = BASCthulhuPermitEscalation
            .escalate(
                permit: boundActionPermit,
                nonEuclideanCandidates:
                    nonEuclideanCandidatesForGate,
                cosmicColdCounterweight: counterweightForGate)
        boundActionPermit = cthulhuEscalation.permit
        thoughtFrame.actionPermit = boundActionPermit
        // M448 — L7 ontology shift mark requires the post-
        // verdict narrative-distortion projection (later in the
        // turn). For the gate-side path, we capture only the
        // L1/L4 projections derived above; ontology-shift-mark
        // is populated at audit-projection time below where
        // narrativeDistortion is already in scope.
        // M56 — L11 risk climate now surfaces per-dimension
        // observations on the main-chain thought frame. Reuses M53's
        // derived (sessionID, turnID) so L6 / L7 / L10 / L11 bundles
        // on this turn share strictly equal coordinates — the L14
        // audit surface joins them by that key.
        thoughtFrame = thoughtFrame
            .withDerivedRiskObservationBundle(
                frameContext: frameContext)

        // ch1042 / ADR-020 Arc-3 Phase C — pre-render provisional sovereign
        // verdict。 OBSERVATION-ONLY:forecast the post-render verdict LEVEL
        // from the now-settled pre-render inputs — boundRiskCard /
        // boundActionPermit / routedBudget / activeKillSwitches, the SAME
        // inputs `buildSovereignVerdict` consumes at ~:1052 (so the provisional
        // brake equals the authoritative one and the forecast is high-fidelity).
        // The ONLY effect is the sink call; it mutates nothing the render /
        // seals / verdict / hash read。 The caution-REDUCTION such a forecast
        // could gate is excluded as architecturally unsafe (ADR-020 §1 / §14)。
        // Flag-off OR nil sink (both default everywhere) → skipped → byte-equal
        // (红线 7); the sink is in no canonical-bytes / seal / hash path.
        if deliberationLoopEnabled, let provisionalVerdictSink {
            let provisionalBrake = buildEmergencyBrake(
                budgetFrame: routedBudget,
                riskCard: boundRiskCard,
                actionPermit: boundActionPermit,
                activeKillSwitches: request.activeKillSwitches)
            let provisionalVerdict = Self.buildProvisionalVerdict(
                policyLineagePresent: policyLineage != nil,
                budgetFrame: routedBudget,
                riskCard: boundRiskCard,
                actionPermit: boundActionPermit,
                emergencyBrake: provisionalBrake,
                activeKillSwitches: request.activeKillSwitches,
                confidenceFloor: thoughtFrame.uncertaintyLedger?.confidenceFloor,
                maxEvidenceDebt: thoughtFrame.evidenceDebts?
                    .map(\.debtWeight).max(),
                leaseEnded: thoughtFrame.convergenceCertificate?
                    .stoppingMode == .leaseEnd)
            provisionalVerdictSink(provisionalVerdict)
        }

        let hostGateValue = hostProfileService.applyHostGate(
            profile: hostContext,
            taskType: contextFrame.taskType,
            riskCard: boundRiskCard,
            confidence: triScores.map(\.mergedScore).max() ?? 0
        )

        let (finalOrganMap, neuralDegradedReasonCodes) = applySovereignNeuralContract(
            to: thoughtFrame.organMap ?? baseNeuralCore.organMap,
            budgetFrame: routedBudget,
            riskCard: boundRiskCard,
            actionPermit: boundActionPermit,
            activeKillSwitches: request.activeKillSwitches,
            inheritedReasonCodes: baseNeuralCore.degradedReasonCodes
        )
        thoughtFrame.organMap = finalOrganMap
        thoughtFrame.toolIntentEnvelope = neuralCoreService?.materializeToolIntent(
            budgetFrame: routedBudget,
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice,
            actionPermit: boundActionPermit
        ) ?? BASNeuralMaterializationCompiler.materializeToolIntent(
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice,
            actionPermit: boundActionPermit
        )
        thoughtFrame.neuralLeaseReceipt = buildNeuralLeaseReceipt(
            budgetFrame: routedBudget,
            thoughtFrame: thoughtFrame,
            degradedReasonCodes: neuralDegradedReasonCodes
        )

        markStage("l11_risk")
        let baseRenderedOutput = actionService.render(
            choice: mergedChoice,
            riskCard: boundRiskCard,
            permit: boundActionPermit,
            hostContext: hostContext
        )
        let renderedOutput = self.projectedRenderedOutput(
            from: baseRenderedOutput,
            mergedChoice: mergedChoice,
            riskCard: boundRiskCard,
            actionPermit: boundActionPermit,
            riskDecisionPackage: normalizedRiskDecisionPackage
        )
        // M57 — L12 gentle hand now surfaces per-subject render
        // observations on the main-chain thought frame. Reuses M53's
        // derived (sessionID, turnID) so L6 / L7 / L10 / L11 / L12
        // bundles on this turn share strictly equal coordinates — the
        // L14 audit surface joins them by that key. Must run AFTER
        // renderedOutput is sealed and BEFORE evolutionService sees
        // the frame, so UpdateTicket derivation can read the bundle.
        thoughtFrame = thoughtFrame
            .withDerivedSoftHandObservationBundle(
                renderedOutput: renderedOutput,
                frameContext: frameContext)
        let rawTickets = evolutionService.buildTickets(
            thoughtFrame: thoughtFrame,
            output: renderedOutput,
            feedbackEvent: request.feedbackEvent
        )
        let (normalizedTickets, evolutionFindings) = normalizeUpdateTickets(
            rawTickets,
            riskCard: boundRiskCard,
            activeKillSwitches: request.activeKillSwitches
        )
        let evolutionGovernance = buildEvolutionGovernanceArtifacts(
            request: request,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            thoughtFrame: thoughtFrame,
            output: renderedOutput,
            riskCard: boundRiskCard,
            updateTickets: normalizedTickets
        )
        let updateTickets = evolutionGovernance.updateTickets
        // M58 — L13 evolution surface now emits per-ticket update
        // observations on the main-chain thought frame. Reuses M53's
        // derived (sessionID, turnID) so L6 / L7 / L10 / L11 / L12 /
        // L13 bundles on this turn share strictly equal coordinates —
        // the L14 audit surface joins them by that key. Must run AFTER
        // the governed ticket list is sealed and BEFORE buildThoughtFold
        // / buildRuntimeTrace read the frame, so the bundle propagates
        // into the fold + trace and then onto the sovereign verdict.
        thoughtFrame = thoughtFrame
            .withDerivedUpdateTicketObservationBundle(
                updateTickets: updateTickets,
                frameContext: frameContext)

        // M60 — L1 灯芯层 main-chain wiring. Derive the per-turn
        // kernel observation bundle from `routedBudget` (the single
        // source of truth for run mode / thermal guard / maintenance
        // / device route). Reuses M53's derived (sessionID, turnID)
        // so the L1 bundle joins the L4 / L6 / L7 / L10 / L11 / L12
        // / L13 bundles under the same coordinates — the L14 audit
        // surface reconciles them by that key. Placed here (after
        // the evolution ticket observation so the frame's other
        // fields are all sealed) and BEFORE buildThoughtFold /
        // buildRuntimeTrace, so the bundle propagates into the fold
        // + trace and then onto the sovereign verdict on the same
        // turn.
        thoughtFrame = thoughtFrame
            .withDerivedLeaseLifeObservationBundle(
                budgetFrame: routedBudget,
                frameContext: frameContext)

        // M61 — L5 宿纹层 main-chain wiring. Derive the per-turn
        // host-constitution governance observation bundle from the
        // coordinator's `hostConstitution` / `hostVersionTree` /
        // `hostForgetRequest` fields (the single source of truth for
        // active version / committed tree / frozen IDs / pending
        // candidates / forget request on this turn). Reuses M53's
        // derived (sessionID, turnID) so the L5 bundle joins the L1 /
        // L4 / L6 / L7 / L10 / L11 / L12 / L13 bundles under the same
        // coordinates. Placed after the M60 L1 seam so every other
        // main-chain bundle on the frame is sealed before L5 emits.
        thoughtFrame = thoughtFrame
            .withDerivedHostConstitutionObservationBundle(
                constitution: hostConstitution,
                versionTree: hostVersionTree,
                forgetRequest: hostForgetRequest,
                frameContext: frameContext)

        let auditFindings = budgetFindings + memoryFindings + loopFindings + riskFindings + evolutionFindings
        let killSwitches = recommendedKillSwitches(for: auditFindings)
        let thoughtFold = buildThoughtFold(
            request: request,
            hostContext: hostContext,
            hostConstitution: hostConstitution,
            hostConstitutionVault: hostConstitutionVault,
            hostVersionTree: hostVersionTree,
            hostForgetRequest: hostForgetRequest,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            thoughtFrame: thoughtFrame,
            riskCard: boundRiskCard,
            hostGateValue: hostGateValue
        )

        // M62 — L3 思纹层 main-chain wiring. Derive the per-turn
        // fold observation bundle from the freshly built
        // `thoughtFold` (single source of truth for foldID +
        // checksum + ark refs + organ packages + degradation
        // reasons). Reuses M53's derived (sessionID, turnID) so the
        // L3 bundle joins the L1 / L4 / L5 / L6 / L7 / L10 / L11 /
        // L12 / L13 bundles under the same coordinates — the L14
        // audit surface reconciles them by that key. Placed between
        // `buildThoughtFold` and `buildRuntimeTrace` so the updated
        // frame propagates into the trace and then onto the
        // sovereign verdict on the same turn.
        thoughtFrame = thoughtFrame
            .withDerivedThoughtFoldObservationBundle(
                fold: thoughtFold,
                frameContext: frameContext)

        // M63 — L8 海马层 main-chain wiring. Derive the per-turn
        // hippocampal memory observation bundle from the normalized
        // `memoryBundle` (single source of truth for retrieved atoms
        // + top-level conflict refs + temporal field subsurfaces
        // like quarantine records and forget cascades). Reuses M53's
        // derived (sessionID, turnID) so the L8 bundle joins the
        // L1 / L3 / L4 / L5 / L6 / L7 / L10 / L11 / L12 / L13
        // bundles under the same coordinates — the L14 audit
        // surface reconciles them by that key. Placed right after
        // the M62 L3 seam and before `buildRuntimeTrace` so the
        // updated frame propagates into the trace and then onto the
        // sovereign verdict on the same turn.
        thoughtFrame = thoughtFrame
            .withDerivedHippocampalMemoryObservationBundle(
                memoryBundle: memoryBundle,
                frameContext: frameContext)

        // M64 — L2 神经器官层 main-chain wiring. Derive the per-turn
        // neural-organ-registry observation bundle from the
        // coordinator's finalized `thoughtFrame.organMap` (post
        // early seal + `applySovereignNeuralContract` — the single
        // source of truth for morph / active organs / precision
        // tiers / routing policy / sovereign constraints / head
        // guarantees on this turn). Reuses M53's derived
        // (sessionID, turnID) so the L2 bundle joins the L1 / L3 /
        // L4 / L5 / L6 / L7 / L8 / L10 / L11 / L12 / L13 bundles
        // under the same coordinates — the L14 audit surface
        // reconciles them by that key. Placed right after the M63
        // L8 seam and before `buildRuntimeTrace` so the updated
        // frame propagates into the trace and then onto the
        // sovereign verdict on the same turn.
        thoughtFrame = thoughtFrame
            .withDerivedNeuralOrganObservationBundle(
                frameContext: frameContext)

        let runtimeTrace = buildRuntimeTrace(
            request: request,
            budgetFrame: routedBudget,
            hostContext: hostContext,
            hostConstitution: hostConstitution,
            hostConstitutionVault: hostConstitutionVault,
            hostVersionTree: hostVersionTree,
            hostForgetRequest: hostForgetRequest,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle,
            thoughtFrame: thoughtFrame,
            thoughtFold: thoughtFold,
            mergedChoice: mergedChoice,
            riskCard: boundRiskCard,
            actionPermit: boundActionPermit,
            renderedOutput: renderedOutput,
            updateTickets: updateTickets,
            activeKillSwitches: request.activeKillSwitches,
            auditFindings: auditFindings,
            killSwitches: killSwitches
        )
        // ②-observe (opt-in, 红线 7) — emit THIS turn's model-honesty observation (flattery / hedging /
        // overclaim scored on the realized body; pure + deterministic). Guarded on the optional sink so a host
        // that did NOT opt in takes the exact pre-existing code path (byte-equal, mirrors `provisionalVerdictSink`).
        // Side-emission only: it never touches `renderedOutput`, the sovereign verdict, or the result, so the
        // canonical turn output is unchanged. Closes the "sycophancy is structurally invisible" gap.
        if let modelHonestyObservationSink {
            modelHonestyObservationSink(BASModelHonestyObservationRecord(
                eventID: "\(derivedSessionID)#\(derivedTurnID)#model-honesty",
                sessionID: derivedSessionID,
                turnID: derivedTurnID,
                axes: BASModelHonestySignal.axes(renderedOutput.headline + "\n" + renderedOutput.body),
                observedAtMs: Int64((runtimeTrace.recordedAt.timeIntervalSince1970 * 1000).rounded())))
        }
        let wakeIntent = buildWakeIntent(
            request: request,
            budgetFrame: routedBudget
        )
        let runLease = buildRunLease(
            request: request,
            runtimeTrace: runtimeTrace,
            budgetFrame: routedBudget,
            actionPermit: boundActionPermit
        )
        let emergencyBrake = buildEmergencyBrake(
            budgetFrame: routedBudget,
            riskCard: boundRiskCard,
            actionPermit: boundActionPermit,
            activeKillSwitches: request.activeKillSwitches
        )
        let sovereignVerdict = buildSovereignVerdict(
            request: request,
            runtimeTrace: runtimeTrace,
            budgetFrame: routedBudget,
            thoughtFold: thoughtFold,
            riskCard: boundRiskCard,
            actionPermit: boundActionPermit,
            emergencyBrake: emergencyBrake,
            updateTickets: updateTickets
        )
        let sovereignCommitTokens = buildSovereignCommitTokens(
            sovereignVerdict: sovereignVerdict,
            runtimeTrace: runtimeTrace,
            thoughtFold: thoughtFold,
            actionPermit: boundActionPermit,
            updateTickets: updateTickets,
            renderedOutput: renderedOutput
        )
        let sovereignWarrants = buildSovereignWarrants(
            sovereignCommitTokens: sovereignCommitTokens,
            sovereignVerdict: sovereignVerdict,
            runtimeTrace: runtimeTrace
        )
        let sovereignLock = buildSovereignLock(
            sovereignVerdict: sovereignVerdict,
            runtimeTrace: runtimeTrace
        )
        let quarantineRecords = buildQuarantineRecords(
            sovereignVerdict: sovereignVerdict,
            runtimeTrace: runtimeTrace,
            thoughtFold: thoughtFold
        )
        // M303 — derive Cthulhu/Abyssal pressure from existing
        // turn state right before the audit-entry build so the
        // projection sees the final risk card + uncertainty
        // ledger + evidence debts that L11 / L9 already settled.
        // Pure projection; no verdict escalation; signalRefs
        // additive only.
        // chapter 四百八十七 / M1325 — V1 cluster B trio fold
        let lateClusterBForAudit =
            BASTurnAuditProjectionsLateClusterB.compute(
                turnID: runtimeTrace.sessionID,
                hostID: hostContext.hostID,
                riskLevel: boundRiskCard.riskLevel,
                permit: boundActionPermit,
                uncertaintyLedger:
                    thoughtFrame.uncertaintyLedger,
                evidenceDebtCount:
                    thoughtFrame.evidenceDebts?.count ?? 0,
                candidateCount:
                    thoughtFrame.candidates.count)
        let abyssalPressureForAudit = lateClusterBForAudit
            .abyssalPressure
        // M304 — derive human-anchor signal from final risk +
        // permit + candidate count. White-paper §5.3 / red line
        // 7: hint, not verdict.
        let humanAnchorSignalForAudit = lateClusterBForAudit
            .humanAnchorSignal
        // M384 escalation now fires upstream (M392 — see the
        // gating block right after `thoughtFrame.actionPermit =
        // boundActionPermit` at line ~380). The audit emission
        // below reads the escalated permit via `boundActionPermit`,
        // and the per-turn audit-projection derives below
        // (`abyssalPressureForAudit` / `humanAnchorSignalForAudit`)
        // produce identical values to the upstream gate-side
        // derives — they exist as separate locals for separation
        // of concerns (gate-side vs audit-side reads).
        // M304 — synthesize seal envelopes from the turn's
        // quarantine records. Each quarantine becomes a
        // sovereign-only seal (the strictest tier short of
        // forbidden) targeting the quarantine source. Aggregate
        // returns nil when there are no quarantines this turn,
        // and the audit-entry builder elides both seal codes.
        // chapter 四百八十八 / M1329 — lifecycle quartet fold
        let lifecycleQuartetForAudit =
            BASTurnAuditProjectionsLifecycleQuartet.compute(
                quarantineRecords: quarantineRecords,
                updateTickets: updateTickets)
        // chapter 五百三十四 / M1513 — dead-code purge:
        // synthesizedSealsForAudit + lifecycleSessionsForAudit
        // shadow re-bindings never read downstream。 Only the
        // aggregates (sealAggregateForAudit +
        // lifecycleAggregateForAudit) are consumed。
        let sealAggregateForAudit = lifecycleQuartetForAudit
            .sealAggregate
        let lifecycleAggregateForAudit = lifecycleQuartetForAudit
            .lifecycleAggregate
        // M316 — derive narrative distortion projection from
        // final risk + permit. Stays at zero on most axes
        // (M316.derive only populates forcedClosure +
        // urgencyMask) so the audit-entry consumer elides the
        // narrative codes unless the turn shows real
        // distortion shape.
        let narrativeDistortionForAudit = lateClusterBForAudit
            .narrativeDistortion
        // M317 — derive anomaly trace from the M316 distortion.
        // Returns nil when no axis crosses the emit threshold;
        // audit-entry consumer elides the codes when nil.
        // chapter 四百八十九 / M1333 — V1 cluster B sextet fold
        let lateClusterCForAudit =
            BASTurnAuditProjectionsLateClusterC.compute(
                sessionID: runtimeTrace.sessionID,
                turnID: derivedTurnID,
                narrativeDistortion:
                    narrativeDistortionForAudit,
                abyssalPressure:
                    abyssalPressureForAudit,
                humanAnchorSignal:
                    humanAnchorSignalForAudit,
                candidates: thoughtFrame.candidates)
        let anomalyTraceForAudit = lateClusterCForAudit
            .anomalyTrace
        let abyssalBranchesForAudit = lateClusterCForAudit
            .abyssalBranches
        let ontologyShiftMarkForAudit = lateClusterCForAudit
            .ontologyShiftMark
        let narrativeDistortionMapForAudit = lateClusterCForAudit
            .narrativeDistortionMap
        // chapter 五百三十四 / M1513 — dead-code purge:
        // hostFragilityForAudit shadow re-binding never read
        // downstream。 abyssalPressureWithFragility remains
        // as it IS consumed below。
        let abyssalPressureWithFragility = lateClusterCForAudit
            .abyssalPressureWithFragility
        // M320 — derive `BASUnknownReserve` projection from L9
        // uncertainty ledger's confidence floor. When the floor
        // is high (≥0.8) the reserve resolves to `.unrestricted`
        // and the audit consumer elides the codes; otherwise
        // emits ceiling tier + ref count.
        // chapter 四百九十一 / M1340 — V1 cluster B trio fold
        let lateClusterDForAudit =
            BASTurnAuditProjectionsLateClusterD.compute(
                sessionID: runtimeTrace.sessionID,
                confidenceFloor:
                    thoughtFrame.uncertaintyLedger?
                        .confidenceFloor
                    ?? Self
                    .defaultConfidenceFloorWhenNoUncertaintyLedger,
                quarantineRecords: quarantineRecords)
        let unknownReserveForAudit = lateClusterDForAudit
            .unknownReserve
        // chapter 五百三十四 / M1513 — dead-code purge:
        // forbiddenCandidatesForAudit shadow re-binding
        // never read downstream。 forbiddenAggregateForAudit
        // remains as it IS consumed below。
        let forbiddenAggregateForAudit = lateClusterDForAudit
            .forbiddenAggregate
        // M402 — Kunlun axis + alignment audit projection.
        // Builds a synthetic axis from the host context + permit
        // mode + risk level, computes alignment for the turn's
        // primary candidate. This is audit-only emission; M406
        // (chapter 九十三) will hook the alignment into L11 permit
        // synthesis. Doctrine: kunlun.axis.* codes are
        // observability-only at this milestone — no decision
        // influence yet (parity with M303 / M304 audit-only
        // pre-M384 phase for Cthulhu).
        // chapter 四百九十三 / M1348-M1349 — Kunlun axis + alignment
        // fold。 4 ForAudit declarations + heavy predicate logic
        // collapsed into a single typed factory call。 M583 (chapter
        // 一百五十七) per-turn-predicate semantics preserved 1:1
        // inside the factory;V1 byte-equality maintained per the
        // stress-sweep dual-mode regression guard。
        let kunlunAxisProtocolForAudit =
            BASTurnAuditProjectionsKunlunAxisProtocol.compute(
                sessionID: runtimeTrace.sessionID,
                hostID: hostContext.hostID,
                permitMode: boundActionPermit.mode,
                riskLevel: boundRiskCard.riskLevel,
                quarantineRecordsIsEmpty:
                    quarantineRecords.isEmpty,
                humanAnchorRecommendedSurfaceTone:
                    humanAnchorSignalForAudit
                        .recommendedSurfaceTone,
                sovereignEscalationHint:
                    abyssalPressureForAudit
                        .sovereignEscalationHint,
                primaryCandidateID:
                    thoughtFrame.candidates.first?.candidateID
                    ?? "no-candidate",
                kunlunActiveLayerRefs:
                    Self.kunlunActiveLayerRefs,
                centerlineRules:
                    Self.kunlunCenterlineRules(
                        for: boundActionPermit.mode),
                kunlunAxisDeviationThreshold: Self
                    .kunlunAxisDeviationThreshold)
        let kunlunAxisForAudit = kunlunAxisProtocolForAudit.axis
        // chapter 五百三十四 / M1513 — dead-code purge:
        // kunlunMatched shadow re-binding never read
        // downstream。 Deleted。
        let kunlunDeviationCodes = kunlunAxisProtocolForAudit
            .deviationCodes
        let kunlunAxisAlignmentForAudit = kunlunAxisProtocolForAudit
            .alignment
        // M404 — Jade Canon seal verification audit projection.
        // Doctrine §4.2: 无来源不成玉 / 无签名不进门 / 无回放不
        // 升格 / 无撤销路径不得长期生效. Synthesize a per-turn
        // seal for the bound action permit (always class
        // `.actionPermit` since the permit IS the high-integrity
        // object being sealed at L11). Source provenance comes
        // from the verdict + sovereign warrants; signature ref
        // from verdict ID; integrity hash from thoughtFold
        // checksum; revocation path from session-keyed rollback
        // anchor ref. Audit-only emission — actual seal-driven
        // gating is M413+ composability work (chapter 九十五).
        // chapter 四百九十三 / M1350-M1351 — Kunlun seal + river
        // origin fold。 4 ForAudit declarations + 2 inline struct
        // constructions collapsed into a single typed factory call。
        // M404 (jade canon §4.2) + M405 (river origin §4.5)
        // semantics preserved 1:1;V1 byte-equality required。
        let kunlunSealRiverForAudit =
            BASTurnAuditProjectionsKunlunSealRiver.compute(
                sessionID: runtimeTrace.sessionID,
                permitMode: boundActionPermit.mode,
                requireMirror: boundActionPermit
                    .requireMirror,
                requireCompare: boundActionPermit
                    .requireCompare,
                requireSecondCheck: boundActionPermit
                    .requireSecondCheck,
                verdictID: sovereignVerdict.verdictID,
                verdictLevel: sovereignVerdict
                    .verdictLevel.rawValue,
                warrantIDs: sovereignWarrants
                    .map(\.warrantID),
                candidateIDs: thoughtFrame.candidates
                    .map(\.candidateID),
                quarantineIDs: quarantineRecords
                    .map(\.quarantineID),
                thoughtFoldID: thoughtFold.foldID,
                thoughtFoldChecksum: thoughtFold.checksum,
                riverOriginTransformationSteps:
                    Self.riverOriginTransformationSteps)
        let kunlunJadeSealForAudit = kunlunSealRiverForAudit.seal
        let kunlunJadeVerificationForAudit =
            kunlunSealRiverForAudit.verification
        let kunlunRiverTraceForAudit =
            kunlunSealRiverForAudit.trace
        let kunlunRiverLineageForAudit =
            kunlunSealRiverForAudit.lineage
        // M408 — Yaochi Sanctum access audit projection. Doctrine
        // §4.4 (line 556-560): 可以存在但默认不参与普通检索 / 可以
        // 被保护但不能被系统操控 / 可以被召回但必须有上下文授权与
        // 承接表面. Synthesize a per-turn sample sanctum entry
        // representing the highest-sensitivity memory class touched
        // by this turn (when quarantine records exist, treat them
        // as `.sensitive` proxy; otherwise mint a `.boundary` proxy
        // representing the host's general protective posture).
        // Run `BASKunlunYaochiProtocol.evaluateAccess` against
        // current request context (host anchor present iff
        // humanAnchorSignal is .reserved tone signaling distance;
        // otherwise present); audit-only emission — actual L8
        // hippocampal gating is M413+ work (chapter 九十五).
        // M425 (chapter 一百一) — extracted to
        // `deriveYaochiAuditProjection`; see file top.
        let yaochiProjection =
            Self.deriveYaochiAuditProjection(
                sessionID: runtimeTrace.sessionID,
                candidateID: thoughtFrame.candidates.first?
                    .candidateID ?? "no-memory",
                hostID: hostContext.hostID,
                hasQuarantines:
                    !quarantineRecords.isEmpty,
                humanAnchorTone:
                    humanAnchorSignalForAudit
                        .recommendedSurfaceTone,
                permitMode: boundActionPermit.mode)
        let kunlunYaochiSanctumForAudit =
            yaochiProjection.entry
        let kunlunYaochiAccessForAudit =
            yaochiProjection.access
        // M409 — Heaven Gate Permit readiness audit projection.
        // Doctrine §4.3: 不是有路径就能进现实 / 不是有候选就能进
        // 宿主层 / 不是有经验就能进成长层 / 不是有工具意图就能工具
        // 写. Synthesize a per-turn permit representing the
        // highest gate class implied by the turn's bound permit
        // mode (`.tool` for tool-emitting permits, `.public` for
        // answer/mirror, `.cognitive` otherwise). Required seals:
        // synthesize one per warrant. Sovereign warrant ref
        // sourced from the first sovereign warrant when present.
        // Pass state derived from verdict level (passed when
        // verdict is `.advisory`/`.unrestricted`, otherwise
        // pending/remanded). Audit-only emission — actual gate
        // enforcement is M410 follow-up.
        // M425 (chapter 一百一) — extracted to
        // `deriveHeavenGateAuditProjection`; see file top.
        let heavenGateProjection =
            Self.deriveHeavenGateAuditProjection(
                sessionID: runtimeTrace.sessionID,
                candidateID: thoughtFrame.candidates.first?
                    .candidateID ?? "no-candidate",
                permitMode: boundActionPermit.mode,
                warrantIDs: sovereignWarrants
                    .map(\.warrantID),
                verdictLevel: sovereignVerdict.verdictLevel,
                requireSecondCheck:
                    boundActionPermit.requireSecondCheck)
        let kunlunHeavenGateForAudit =
            heavenGateProjection.permit
        let kunlunHeavenGateReadinessForAudit =
            heavenGateProjection.readiness
        // M424 (chapter 一百一) — wire chapter 九十九 typed schemas
        // into runtime so they're not just "typed-surface-only".
        // Each schema is derived from existing audit-projection
        // state (zero new substrate dependencies) and emits a
        // status code into signalRefs so audit walkers can verify
        // the schema fired on each turn.
        //
        // Three schemas wired here:
        //
        // 1. BASKunlunAxisView (§5.4) — derived from existing
        //    kunlunAxisForAudit + deviation codes; emits
        //    `kunlun.axis.view:wellformed|partial`.
        // 2. BASKunlunTianmenWarrant (§5.14) — derived from
        //    existing kunlunHeavenGateForAudit + verdict ref +
        //    seal ref; emits `kunlun.warrant.authorized:true|false`.
        // 3. BASKunlunGateDenialWrit (§5.14) — derived from
        //    readiness when not ready; emits `kunlun.denial.well-
        //    formed:true` when present (denial is doctrine-
        //    correct per 该断时断 — denials must always carry
        //    typed reason codes + return path + denied domain).
        //
        // Two schemas (BASKunlunAscentView, BASKunlunFarWestReserve)
        // are intentionally NOT wired here — they need synthetic
        // ascent/distance data that the substrate doesn't yet
        // expose. Wiring them without real data would emit
        // misleading audit codes. Deferred with criteria: wire
        // when a per-turn ascent context or unknown-distance
        // projection is added upstream.
        // chapter 四百九十四 / M1353-M1354 — Tianmen trio fold。
        // 3 ForAudit declarations + ~56 LOC of inline construction
        // logic (axisView + tianmenWarrant + gateDenialWrit
        // mutual-exclusion guards) collapsed into a single typed
        // factory call。 M424 chapter 一百一 mutual-exclusivity
        // invariant preserved (该断时断 — denials carry typed
        // reason codes)。 V1 byte-equality required。
        let kunlunTianmenTrioForAudit =
            BASTurnAuditProjectionsKunlunTianmenTrio.compute(
                sessionID: runtimeTrace.sessionID,
                permitMode: boundActionPermit.mode,
                primaryCandidateID:
                    thoughtFrame.candidates.first?
                        .candidateID ?? "no-candidate",
                worldAnchorRef:
                    kunlunAxisForAudit.worldAnchorRef,
                centerlineRules:
                    kunlunAxisForAudit.centerlineRules,
                deviationCodes: kunlunDeviationCodes,
                heavenGateID:
                    kunlunHeavenGateForAudit.gateID,
                heavenGateIsReady:
                    kunlunHeavenGateReadinessForAudit
                        .isReady,
                heavenGateReasonCodes:
                    kunlunHeavenGateReadinessForAudit
                        .reasonCodes,
                firstSovereignWarrantID: sovereignWarrants
                    .first?.warrantID,
                jadeCanonSealRef:
                    kunlunJadeSealForAudit.sealID,
                riverOriginRef:
                    kunlunRiverTraceForAudit.traceID)
        let kunlunAxisViewForAudit = kunlunTianmenTrioForAudit
            .axisView
        let kunlunTianmenWarrantForAudit =
            kunlunTianmenTrioForAudit.tianmenWarrant
        let kunlunGateDenialWritForAudit =
            kunlunTianmenTrioForAudit.gateDenialWrit
        // M436 (chapter 一百四) — derive the per-turn 14-layer
        // reconciliation report + verdict from all 13 cognitive
        // bundles in scope (L1..L13). Pre-fix this engine
        // existed as a library but was never invoked from
        // production; the audit ledger therefore had ZERO
        // visibility into "did all expected layers participate
        // this turn." Now the verdict's findings (missing layer
        // / partial coverage / budget overspend) emit
        // `reconciliation.*` codes into `signalRefs` below, and
        // the report's `summaries` give audit walkers the full
        // observed-layer list. Doctrine pin: pure derive, no
        // verdict escalation, no permit mutation, no decision
        // influence — purely additive metadata.
        let layerReconciliation = Self
            .deriveLayerReconciliationReport(
                thoughtFrame: thoughtFrame,
                presenceBundle:
                    contextFrame.presenceObservationBundle,
                decompositionBundle:
                    decomposeFrame.decompositionObservationBundle,
                candidateBundle: thoughtArtifacts
                    .candidateObservationBundle,
                // Canonical key formula matching the rest of
                // the substrate: derivedTurnID + derivedSessionID
                // are what the M53 / M54 / M55 / M62 / M63 /
                // M64 derive helpers feed into every per-layer
                // bundle. Using the same pair here lets
                // `BASObservationReconciliationReport.appending`
                // accept every bundle's summary instead of
                // dropping ones whose keys don't match.
                turnID: derivedTurnID,
                sessionID: derivedSessionID,
                emittedAt: runtimeTrace.recordedAt)
        // M502-M510 (chapter 一百二十八) — L12 doctrine surface
        // aliases. Pure translation tables from final permit
        // mode → BASSurfaceMode → doctrine-specific aliases.
        // nil when permit mode has no L12 surface (e.g. .answer
        // / .escalate proceed without surface rendering).
        // chapter 四百九十二 / M1345 — surface trio fold
        let surfaceTrioForAudit =
            BASTurnAuditProjectionsSurfaceTrio.compute(
                permitMode: boundActionPermit.mode)
        // chapter 五百三十四 / M1513 — dead-code purge:
        // surfaceModeForAudit shadow re-binding never
        // read downstream。 Deleted。
        let cthulhuSurfaceAliasForAudit = surfaceTrioForAudit
            .cthulhuSurfaceAlias
        let kunlunSurfaceAliasForAudit = surfaceTrioForAudit
            .kunlunSurfaceAlias
        // M436.4 (chapter 一百七 parameter-bundle refactor) —
        // populate the typed audit-observation bundle once and
        // pass to the bundle-form `buildSovereignAuditEntry`.
        // Pre-M436.4 the call site spelled 24+ named parameters
        // chapter 五百十五 / M1437 — V1 monolith projections
        // construction FOLD using the unified 3-block init
        // (M1435)。
        // chapter 五百十六 / M1443 — extended to 4-block
        // init (M1442),packaging 9 more Kunlun protocol
        // fields into the new kunlunProtocolBlock。
        // chapter 五百十七 / M1447 — extended to 5-block
        // init (M1446),packaging 7 more L1-L7 Cthulhu
        // aggregate fields into the new
        // cthulhuAggregatesBlock。
        //
        // Byte-equality with the pre-fold path GUARANTEED
        // by M1435 + M1442 + M1446 PROOF tests + stress-
        // sweep canonical60 × 3 repeat runs 0-divergence。
        //
        // The 4 Kunlun trios + Cthulhu trio + Penta + 11
        // cognitive bundles + 9 Kunlun protocol fields + 7
        // Cthulhu aggregate fields now flow into 5 typed
        // input surfaces (53 of 56 projection fields,
        // ~95% packaging coverage)。
        let kunlunInputsForAudit =
            BASAuditObservationProjectionsKunlunInputs(
                trio: kunlunTrioForAudit,
                hexa: kunlunHexaForAudit,
                trioTwo: kunlunTrioTwoForAudit,
                hexaTwo: kunlunHexaTwoForAudit)
        let cthulhuInputsForAudit =
            BASAuditObservationProjectionsCthulhuInputs(
                abyssalThermalTrio:
                    abyssalThermalTrioForAudit,
                cthulhuPenta: cthulhuPentaForAudit)
        let observationBundlesForAudit =
            BASAuditObservationProjectionsObservationBundlesBlock(
                presence:
                    contextFrame.presenceObservationBundle,
                decomposition: decomposeFrame
                    .decompositionObservationBundle,
                softHand: thoughtFrame
                    .softHandObservationBundle,
                leaseLife: thoughtFrame
                    .leaseLifeObservationBundle,
                hostConstitution: thoughtFrame
                    .hostConstitutionObservationBundle,
                thoughtFold: thoughtFrame
                    .thoughtFoldObservationBundle,
                neuralOrgan: thoughtFrame
                    .neuralOrganObservationBundle,
                hippocampalMemory: thoughtFrame
                    .hippocampalMemoryObservationBundle,
                worldPrior: thoughtFrame
                    .worldPriorObservationBundle,
                risk: thoughtFrame
                    .riskObservationBundle,
                updateTicket: thoughtFrame
                    .updateTicketObservationBundle)
        let kunlunProtocolBlockForAudit =
            BASAuditObservationProjectionsKunlunProtocolBlock(
                kunlunAxisAlignment:
                    kunlunAxisAlignmentForAudit,
                jadeCanonVerification:
                    kunlunJadeVerificationForAudit,
                jadeCanonObjectClass: .actionPermit,
                riverOriginLineage:
                    kunlunRiverLineageForAudit,
                yaochiAccess:
                    kunlunYaochiAccessForAudit,
                yaochiSanctumClass:
                    kunlunYaochiSanctumForAudit
                        .sanctumClass,
                tianmenReadiness:
                    kunlunHeavenGateReadinessForAudit,
                tianmenGateClass:
                    kunlunHeavenGateForAudit.gateClass,
                tianmenPassState:
                    kunlunHeavenGateForAudit.passState)
        let cthulhuAggregatesBlockForAudit =
            BASAuditObservationProjectionsCthulhuAggregatesBlock(
                abyssalPressure:
                    abyssalPressureWithFragility,
                humanAnchorSignal:
                    humanAnchorSignalForAudit,
                sealAggregate: sealAggregateForAudit,
                lifecycleAggregate:
                    lifecycleAggregateForAudit,
                narrativeDistortion:
                    narrativeDistortionForAudit,
                anomalyTrace: anomalyTraceForAudit,
                abyssalBranches:
                    abyssalBranchesForAudit)
        // chapter 五百十八 / M1451 — 6th block extension
        let closureBlockForAudit =
            BASAuditObservationProjectionsClosureBlock(
                candidateObservationBundle:
                    thoughtArtifacts
                        .candidateObservationBundle,
                tribunalObservationBundle:
                    thoughtFrame
                        .tribunalObservationBundle,
                unknownReserve: unknownReserveForAudit,
                forbiddenAggregate:
                    forbiddenAggregateForAudit,
                layerReconciliationVerdict:
                    layerReconciliation.verdict,
                layerReconciliationReport:
                    layerReconciliation.report,
                escalationSuppressionCodes:
                    escalationSuppressionCodes)
        // chapter 五百二十一 / M1463 — 7th block extension
        let kunlunAuditSchemasBlockForAudit =
            BASAuditObservationProjectionsKunlunAuditSchemasBlock(
                kunlunAxisView: kunlunAxisViewForAudit,
                kunlunTianmenWarrant:
                    kunlunTianmenWarrantForAudit,
                kunlunGateDenialWrit:
                    kunlunGateDenialWritForAudit)
        // chapter 五百二十二 / M1467 — 8th + FINAL block
        // extension。 100% V1 call-site packaging coverage
        // milestone:every audit-projection field now
        // flows through a typed input surface。
        let cthulhuLeftoversBlockForAudit =
            BASAuditObservationProjectionsCthulhuLeftoversBlock(
                ontologyShiftMark:
                    ontologyShiftMarkForAudit,
                narrativeDistortionMap:
                    narrativeDistortionMapForAudit,
                cthulhuAssertionCeilingReasonCodes:
                    cthulhuAssertionDecision
                        .reasonCodes,
                cthulhuPermitEscalationReasonCodes:
                    cthulhuEscalation.reasonCodes,
                cthulhuSurfaceAlias:
                    cthulhuSurfaceAliasForAudit,
                kunlunSurfaceAlias:
                    kunlunSurfaceAliasForAudit)
        let projections = BASAuditObservationProjections(
            kunlunInputs: kunlunInputsForAudit,
            cthulhuInputs: cthulhuInputsForAudit,
            observationBundles:
                observationBundlesForAudit,
            kunlunProtocolBlock:
                kunlunProtocolBlockForAudit,
            cthulhuAggregatesBlock:
                cthulhuAggregatesBlockForAudit,
            closureBlock: closureBlockForAudit,
            kunlunAuditSchemasBlock:
                kunlunAuditSchemasBlockForAudit,
            cthulhuLeftoversBlock:
                cthulhuLeftoversBlockForAudit)
        // chapter 五百十九 / M1454 — FIRST PRODUCTION
        // WIRE-IN of the M1426 projection-block emission
        // pattern。 When the host wired
        // `projectionBlockEmissionHandler` at coordinator
        // construction time,we fire it now with the
        // typed observation record。 Default nil = handler
        // not set = behavior identical to pre-M1454。
        //
        // V1 byte-equality preserved:the handler runs
        // AFTER projections construction,does not mutate
        // any audit state,and its return value is
        // discarded。 Stress-sweep regression guard
        // catches drift。
        if let handler = projectionBlockEmissionHandler {
            let observation =
                BASAuditObservationProjectionsBundleEmitter
                    .makeObservation(
                        turnID: derivedTurnID,
                        sessionID: derivedSessionID,
                        emittedAt: Date(),
                        kunlunInputs:
                            kunlunInputsForAudit,
                        cthulhuInputs:
                            cthulhuInputsForAudit)
            handler(observation)
        }
        let sovereignAuditEntry = buildSovereignAuditEntry(
            sovereignVerdict: sovereignVerdict,
            sovereignCommitTokens: sovereignCommitTokens,
            sovereignWarrants: sovereignWarrants,
            quarantineRecords: quarantineRecords,
            runtimeTrace: runtimeTrace,
            thoughtFold: thoughtFold,
            riskCard: boundRiskCard,
            actionPermit: boundActionPermit,
            projections: projections)
        let finalSovereignVerdict: BASSovereignVerdict? = {
            var verdict = sovereignVerdict
            verdict.auditRef = sovereignAuditEntry.auditID
            return verdict
        }()
        let vitalState = buildVitalState(
            deviceState: request.deviceState,
            budgetFrame: routedBudget,
            runtimeTrace: runtimeTrace,
            emergencyBrake: emergencyBrake
        )
        let sovereignActuationCommands = buildSovereignActuationCommands(
            sovereignVerdict: finalSovereignVerdict,
            runtimeTrace: runtimeTrace,
            budgetFrame: routedBudget,
            riskCard: boundRiskCard,
            actionPermit: boundActionPermit
        )
        let sovereignExecutionReceipts = buildSovereignExecutionReceipts(
            sovereignActuationCommands: sovereignActuationCommands,
            runtimeTrace: runtimeTrace
        )
        let finalizedRuntimeTrace = appendingSovereignTraceEvent(
            to: runtimeTrace,
            commands: sovereignActuationCommands,
            receipts: sovereignExecutionReceipts,
            thoughtFrame: thoughtFrame
        )
        let recoveryDisposition = buildRecoveryDisposition(
            budgetFrame: routedBudget,
            emergencyBrake: emergencyBrake,
            sovereignVerdict: finalSovereignVerdict
        )
        let finalizedBudgetFrame = buildFinalizedBudgetFrame(
            routedBudget,
            wakeIntent: wakeIntent,
            runLease: runLease,
            actionPermit: boundActionPermit
        )

        if let runLease {
            thoughtFrame.organMap?.leaseRef = runLease.leaseID
            thoughtFrame.neuralLeaseReceipt?.leaseID = runLease.leaseID
        }

        markStage("l12_render")   // covers render → verdict/audit/trace assembly up to here
        var turnResult = BASEBrainTurnResult(
            // chapter 五百三十一 / M1503 — V1 splice:
            // 6 device/lifecycle args collapse to 1 typed
            // deviceLifecycleBundle (deviceState +
            // budgetFrame + wakeIntent + vitalState +
            // runLease + emergencyBrake)。 Byte-equality
            // preserved by M1502 PROOF (bundle accessors
            // pass through verbatim)。
            deviceLifecycleBundle:
                BASEBrainTurnResultDeviceLifecycleBundle(
                    deviceState: request.deviceState,
                    budgetFrame: finalizedBudgetFrame,
                    wakeIntent: wakeIntent,
                    vitalState: vitalState,
                    runLease: runLease,
                    emergencyBrake: emergencyBrake),
            // chapter 五百二十五 / M1479 — V1 splice:
            // 8 sovereign-cluster args collapse to 1
            // typed sovereignBundle。 Byte-equality
            // preserved by M1478 PROOF (bundle accessors
            // pass through verbatim)。
            sovereignBundle:
                BASEBrainTurnResultSovereignBundle(
                    sovereignVerdict:
                        finalSovereignVerdict,
                    sovereignCommitTokens:
                        sovereignCommitTokens,
                    sovereignWarrants:
                        sovereignWarrants,
                    sovereignLock: sovereignLock,
                    quarantineRecords:
                        quarantineRecords,
                    sovereignAuditEntry:
                        sovereignAuditEntry,
                    sovereignActuationCommands:
                        sovereignActuationCommands,
                    sovereignExecutionReceipts:
                        sovereignExecutionReceipts),
            // chapter 五百三十二 / M1507 — V1 splice:
            // 3 forensic metadata args collapse to 1
            // typed forensicMetadataBundle (policyLineage
            // + recoveryDisposition + runtimeTrace)。
            // Byte-equality preserved by M1506 PROOF
            // (bundle accessors pass through verbatim)。
            // 100% arg packaging coverage achieved at
            // this V1 call site。
            forensicMetadataBundle:
                BASEBrainTurnResultForensicMetadataBundle(
                    policyLineage: policyLineage,
                    recoveryDisposition:
                        recoveryDisposition,
                    runtimeTrace:
                        finalizedRuntimeTrace),
            // chapter 五百二十六 / M1483 — V1 splice:
            // 5 host-cluster args collapse to 1 typed
            // hostBundle。 Byte-equality preserved by
            // M1482 PROOF (bundle accessors pass through
            // verbatim)。
            hostBundle:
                BASEBrainTurnResultHostBundle(
                    hostConstitution: hostConstitution,
                    hostConstitutionVault:
                        hostConstitutionVault,
                    hostVersionTree: hostVersionTree,
                    hostForgetRequest:
                        hostForgetRequest,
                    hostContext: hostContext),
            // chapter 五百二十八 / M1491 — V1 splice:
            // 5 cognitive-frame args collapse to 1 typed
            // cognitiveFramesBundle。 Byte-equality
            // preserved by M1490 PROOF。
            cognitiveFramesBundle:
                BASEBrainTurnResultCognitiveFramesBundle(
                    contextFrame: contextFrame,
                    decomposeFrame: decomposeFrame,
                    memoryBundle: memoryBundle,
                    thoughtFrame: thoughtFrame,
                    thoughtFold: thoughtFold),
            // chapter 五百二十九 / M1495 — V1 splice:
            // 4 risk/choice args collapse to 1 typed
            // riskChoiceBundle。 Byte-equality preserved
            // by M1494 PROOF。
            riskChoiceBundle:
                BASEBrainTurnResultRiskChoiceBundle(
                    triScores: triScores,
                    mergedChoice: mergedChoice,
                    riskCard: boundRiskCard,
                    actionPermit: boundActionPermit),
            // chapter 五百三十 / M1499 — V1 splice:
            // 4 misc args collapse to 1 typed miscBundle。
            // Byte-equality preserved by M1498 PROOF。
            miscBundle:
                BASEBrainTurnResultMiscBundle(
                    riskDecisionPackage:
                        normalizedRiskDecisionPackage,
                    hostGateValue: hostGateValue,
                    renderedOutput: renderedOutput,
                    updateTickets: updateTickets),
            // chapter 五百二十四 / M1475 — V1 splice:
            // 10 evolution-cluster args collapse to 1
            // typed evolutionBundle。 Byte-equality
            // preserved by M1474 PROOF (bundle accessors
            // pass through verbatim)。
            evolutionBundle:
                BASEBrainTurnResultEvolutionBundle(
                    experienceCandidates:
                        evolutionGovernance
                            .experienceCandidates,
                    workflowCandidates:
                        evolutionGovernance
                            .workflowCandidates,
                    guardTemplateCandidates:
                        evolutionGovernance
                            .guardTemplateCandidates,
                    biasRecords:
                        evolutionGovernance
                            .biasRecords,
                    riskPatternCandidates:
                        evolutionGovernance
                            .riskPatternCandidates,
                    learningExportBundles:
                        evolutionGovernance
                            .learningExportBundles,
                    shadowTrialRecords:
                        evolutionGovernance
                            .shadowTrialRecords,
                    versionDeltas:
                        evolutionGovernance
                            .versionDeltas,
                    retractionOrders:
                        evolutionGovernance
                            .retractionOrders,
                    evolutionSeals:
                        evolutionGovernance
                            .evolutionSeals),
            // chapter 五百二十六 / M1483 — V1 splice:
            // 7 audit-projection-forwarded args collapse
            // to 1 typed auditProjectionForwardBundle。
            // Bundle accessors pass through verbatim:
            //   - M578 (chapter 一百五十三) 4 fields
            //     from projections (kunlunAxisAlignment +
            //     humanAnchorSignal + abyssalPressure +
            //     unknownReserve)
            //   - M581 (chapter 一百五十六) 3 fields from
            //     runTurn-scope locals (heavenGate +
            //     riverTrace + yaochiSanctum)
            // Byte-equality preserved via 3-bundle init
            // delegation (M1482)。
            auditProjectionForwardBundle:
                BASEBrainTurnResultAuditProjectionForwardBundle(
                    kunlunAxisAlignment:
                        projections.kunlunAxisAlignment,
                    humanAnchorSignal:
                        projections.humanAnchorSignal,
                    abyssalPressure:
                        projections.abyssalPressure,
                    unknownReserve:
                        projections.unknownReserve,
                    kunlunHeavenGatePermit:
                        kunlunHeavenGateForAudit,
                    kunlunRiverOriginTrace:
                        kunlunRiverTraceForAudit,
                    yaochiSanctumEntry:
                        kunlunYaochiSanctumForAudit)
        )
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
    private func isTerminalDeliberationStop(
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
