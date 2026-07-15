import CryptoKit
import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore
import BASSovereign
import BASWorldPrior

// Context-IR step 4 — runTurn stage methods with DECLARED read surfaces (see
// EBrainRuntimeCoordinator+RunTurnStagesMemoryRisk.swift header for the doctrine).

extension BASEBrainRuntimeCoordinator {

    func riskStageB(
        request: BASEBrainTurnRequest,
        contextPlan: BASTurnContextPlan,
        contextFrame: BASContextFrame,
        frameContext: BASFrameContext,
        hostContext: BASHostProfile,
        derivedSessionID: String,
        derivedTurnID: String,
        memoryDeliberate: BASMemoryDeliberateStageContext,
        riskBind: BASRiskBindStageContext
    ) -> BASRiskEscalateStageContext {
        let baseNeuralCore = memoryDeliberate.baseNeuralCore
        let mergedChoice = memoryDeliberate.mergedChoice
        let triScores = memoryDeliberate.triScores
        var thoughtFrame = riskBind.thoughtFrame
        var boundActionPermit = riskBind.boundActionPermit
        let boundRiskCard = riskBind.boundRiskCard
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
                routedBudget: contextPlan.routedBudget,
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
            routedBudget: contextPlan.routedBudget,
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
            runMode: contextPlan.risk.runMode,
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
            runMode: contextPlan.risk.runMode,
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
            routedBudget: contextPlan.routedBudget,
            runMode: contextPlan.risk.runMode,
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
            budgetFrame: contextPlan.routedBudget,
            riskCard: boundRiskCard,
            actionPermit: boundActionPermit,
            activeKillSwitches: request.activeKillSwitches)
        let provisionalVerdict = Self.buildProvisionalVerdict(
            policyLineagePresent: policyLineage != nil,
            budgetFrame: contextPlan.routedBudget,
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
        budgetFrame: contextPlan.routedBudget,
        riskCard: boundRiskCard,
        actionPermit: boundActionPermit,
        activeKillSwitches: request.activeKillSwitches,
        inheritedReasonCodes: baseNeuralCore.degradedReasonCodes
    )
    thoughtFrame.organMap = finalOrganMap
    thoughtFrame.toolIntentEnvelope = neuralCoreService?.materializeToolIntent(
        budgetFrame: contextPlan.routedBudget,
        thoughtFrame: thoughtFrame,
        mergedChoice: mergedChoice,
        actionPermit: boundActionPermit
    ) ?? BASNeuralMaterializationCompiler.materializeToolIntent(
        thoughtFrame: thoughtFrame,
        mergedChoice: mergedChoice,
        actionPermit: boundActionPermit
    )
    thoughtFrame.neuralLeaseReceipt = buildNeuralLeaseReceipt(
        budgetFrame: contextPlan.routedBudget,
        thoughtFrame: thoughtFrame,
        degradedReasonCodes: neuralDegradedReasonCodes
    )

        return BASRiskEscalateStageContext(
            boundActionPermit: boundActionPermit,
            boundRiskCard: boundRiskCard,
            thoughtFrame: thoughtFrame,
            abyssalThermalTrioForAudit: abyssalThermalTrioForAudit,
            cthulhuAssertionDecision: cthulhuAssertionDecision,
            cthulhuEscalation: cthulhuEscalation,
            cthulhuPentaForAudit: cthulhuPentaForAudit,
            escalationSuppressionCodes: escalationSuppressionCodes,
            hostGateValue: hostGateValue,
            kunlunHexaForAudit: kunlunHexaForAudit,
            kunlunHexaTwoForAudit: kunlunHexaTwoForAudit,
            kunlunTrioForAudit: kunlunTrioForAudit,
            kunlunTrioTwoForAudit: kunlunTrioTwoForAudit)
    }

    // stage-frame isolation (frame lint): render-stage locals+temps die with this closure frame
    // stage-frame isolation: a NAMED local function is a real separate frame at -Onone
    // (an immediately-applied closure literal gets SILGen-inlined — measured, no win).
    func renderStageA(
        request: BASEBrainTurnRequest,
        contextPlan: BASTurnContextPlan,
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame,
        frameContext: BASFrameContext,
        hostContext: BASHostProfile,
        derivedSessionID: String,
        derivedTurnID: String,
        budgetFindings: [BASRuntimeAuditFinding],
        memoryDeliberate: BASMemoryDeliberateStageContext,
        riskBind: BASRiskBindStageContext,
        riskEscalate: BASRiskEscalateStageContext
    ) -> BASRenderVerdictStageContext {
        let memoryBundle = memoryDeliberate.memoryBundle
        let mergedChoice = memoryDeliberate.mergedChoice
        var thoughtFrame = riskEscalate.thoughtFrame   // post-escalation version
        let normalizedRiskDecisionPackage = riskBind.normalizedRiskDecisionPackage
        let memoryFindings = memoryDeliberate.memoryFindings
        let loopFindings = memoryDeliberate.loopFindings
        let riskFindings = riskBind.riskFindings
        let boundActionPermit = riskEscalate.boundActionPermit
        let boundRiskCard = riskEscalate.boundRiskCard
        let hostGateValue = riskEscalate.hostGateValue
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
            budgetFrame: contextPlan.routedBudget,
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
        budgetFrame: contextPlan.routedBudget,
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
        let scored = renderedOutput.headline + "\n" + renderedOutput.body
        modelHonestyObservationSink(BASModelHonestyObservationRecord(
            eventID: "\(derivedSessionID)#\(derivedTurnID)#model-honesty",
            sessionID: derivedSessionID,
            turnID: derivedTurnID,
            axes: BASModelHonestySignal.axes(scored),
            observedAtMs: Int64((runtimeTrace.recordedAt.timeIntervalSince1970 * 1000).rounded()),
            // 触发器①: CJK-dominant bodies are unreadable by the English lexicons — flag it
            // so every consumer renders n/a(zh) instead of a false-green "ok".
            lexiconApplicable: BASModelHonestySignal.lexiconApplicable(to: scored)))
    }
    let wakeIntent = buildWakeIntent(
        request: request,
        budgetFrame: contextPlan.routedBudget
    )
    let runLease = buildRunLease(
        request: request,
        runtimeTrace: runtimeTrace,
        budgetFrame: contextPlan.routedBudget,
        actionPermit: boundActionPermit
    )
    let emergencyBrake = buildEmergencyBrake(
        budgetFrame: contextPlan.routedBudget,
        riskCard: boundRiskCard,
        actionPermit: boundActionPermit,
        activeKillSwitches: request.activeKillSwitches
    )
    let sovereignVerdict = buildSovereignVerdict(
        request: request,
        runtimeTrace: runtimeTrace,
        budgetFrame: contextPlan.routedBudget,
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
        return BASRenderVerdictStageContext(
            thoughtFrame: thoughtFrame,
            abyssalPressureForAudit: abyssalPressureForAudit,
            humanAnchorSignalForAudit: humanAnchorSignalForAudit,
            lateClusterBForAudit: lateClusterBForAudit,
            runtimeTrace: runtimeTrace,
            sovereignVerdict: sovereignVerdict,
            emergencyBrake: emergencyBrake,
            evolutionGovernance: evolutionGovernance,
            quarantineRecords: quarantineRecords,
            renderedOutput: renderedOutput,
            runLease: runLease,
            sovereignCommitTokens: sovereignCommitTokens,
            sovereignLock: sovereignLock,
            sovereignWarrants: sovereignWarrants,
            thoughtFold: thoughtFold,
            updateTickets: updateTickets,
            wakeIntent: wakeIntent)
    }
}
