import CryptoKit
import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore
import BASSovereign
import BASWorldPrior

// Context-IR step 4 — runTurn stage methods with DECLARED read surfaces.
// A method cannot lexically capture runTurn locals: every read is a parameter (the
// compiler-censused surface), every mutation flows back through the named output context.
// Coordinator services/config are ambient via self (capabilities, not turn context).
// Pinned by BASRunTurnFrameBudgetTests.testStageReadsAreDeclaredParameters.

extension BASEBrainRuntimeCoordinator {

    // stage-frame isolation (see renderStage note below)
    func memoryDeliberateStage(
        request: BASEBrainTurnRequest,
        contextPlan: BASTurnContextPlan,
        frameContext: BASFrameContext,
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame,
        hostContext: BASHostProfile
    ) -> BASMemoryDeliberateStageContext {
    let rawMemoryBundle = memoryService.retrieve(
        decomposeFrame: decomposeFrame,
        hostContext: hostContext,
        budget: contextPlan.routedBudget
    )
    let (memoryBundle, memoryFindings) = normalizeMemoryBundle(
        rawMemoryBundle,
        budget: contextPlan.routedBudget
    )
    let baseNeuralCore = neuralCoreService?.synthesize(
        budgetFrame: contextPlan.routedBudget,
        contextFrame: contextFrame,
        decomposeFrame: decomposeFrame,
        memoryBundle: memoryBundle,
        hostProfile: hostContext,
        activeKillSwitches: request.activeKillSwitches
    ) ?? defaultNeuralCoreFrame(
        budgetFrame: contextPlan.routedBudget,
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
            budget: contextPlan.routedBudget,
            priorCandidateIDs: priorCandidateIDs
        )
        if thoughtFrame.candidates.isEmpty {
            thoughtFrame.candidates = loopService.proposePaths(
                decomposeFrame: decomposeFrame,
                memoryBundle: memoryBundle,
                budget: contextPlan.routedBudget
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
            budget: contextPlan.routedBudget
        )
        thoughtFrame = normalizedThoughtFrame
        thoughtFrame.organMap = baseNeuralCore.organMap
        let thoughtArtifacts = neuralCoreService?.materializeThoughtArtifacts(
            budgetFrame: contextPlan.routedBudget,
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
                contextPlan.deliberate.maxLoops,
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
        budgetFrame: contextPlan.routedBudget,
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

        return BASMemoryDeliberateStageContext(
            baseNeuralCore: baseNeuralCore,
            loopFindings: loopFindings,
            memoryBundle: memoryBundle,
            memoryFindings: memoryFindings,
            mergedChoice: mergedChoice,
            ssmActualTargetPasses: ssmActualTargetPasses,
            thoughtArtifacts: thoughtArtifacts,
            thoughtFrame: thoughtFrame,
            triScores: triScores)
    }

    // stage-frame isolation (see renderStage note below)
    func riskStageA(
        request: BASEBrainTurnRequest,
        contextPlan: BASTurnContextPlan,
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame,
        hostContext: BASHostProfile,
        derivedSessionID: String,
        derivedTurnID: String,
        memoryDeliberate: BASMemoryDeliberateStageContext
    ) -> BASRiskBindStageContext {
        var thoughtFrame = memoryDeliberate.thoughtFrame
        let triScores = memoryDeliberate.triScores
        let mergedChoice = memoryDeliberate.mergedChoice
        let ssmActualTargetPasses = memoryDeliberate.ssmActualTargetPasses
    let rawRiskDecisionPackage = riskService.buildRiskDecisionPackage(
        contextFrame: contextFrame,
        thoughtFrame: thoughtFrame,
        triScores: triScores,
        budget: contextPlan.routedBudget
    )
    let rawRiskCard = rawRiskDecisionPackage.riskCard
    let rawActionPermit = rawRiskDecisionPackage.actionPermit
    let (riskCard, actionPermit, riskFindings) = normalizeRiskDecision(
        riskCard: rawRiskCard,
        actionPermit: rawActionPermit,
        budget: contextPlan.routedBudget,
        activeKillSwitches: request.activeKillSwitches
    )
    var normalizedRiskDecisionPackage = projectedRiskDecisionPackage(
        from: rawRiskDecisionPackage,
        riskCard: riskCard,
        actionPermit: actionPermit
    )
    let resolvedRiskService = riskService
    let bindings = neuralCoreService?.materializeRiskBindings(
        budgetFrame: contextPlan.routedBudget,
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
                    contextPlan.risk.maxLoops,
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
    let boundActionPermit = primaryBinding?.actionPermit ?? actionPermit
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

        return BASRiskBindStageContext(
            boundActionPermit: boundActionPermit,
            boundRiskCard: boundRiskCard,
            normalizedRiskDecisionPackage: normalizedRiskDecisionPackage,
            riskFindings: riskFindings,
            thoughtFrame: thoughtFrame)
    }
}
