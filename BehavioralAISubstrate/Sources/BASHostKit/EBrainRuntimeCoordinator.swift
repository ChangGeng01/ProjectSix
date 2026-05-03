import CryptoKit
import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore
// M320 — `BASUnknownReserve.derive(...)` lives in BASWorldPrior
// and is invoked from `runTurn` to project per-turn unknowns.
import BASWorldPrior

// MARK: - M71 split — BASEBrainRuntimeCoordinator now lives in its own file.
// Types (BASEBrainTurnRequest / BASEBrainTurnResult), evolution summary/
// precision-hotcold/breath-bridge helpers, and shared internal utilities
// (EvolutionSovereignBridgeProjection, String.trimmedNonEmpty, etc.) moved to
// sibling files in BASHostKit during the M71 cohesion split.  The coordinator
// itself is next on the list to be split by cohesion; this commit only removes
// the duplicated pre-struct content.

public struct BASEBrainRuntimeCoordinator {
    public var powerClockService: any BASPowerClockServicing
    public var hostProfileService: any BASHostProfileServicing
    public var contextService: any BASContextServicing
    public var decomposeService: any BASDecomposeServicing
    public var memoryService: any BASMemoryServicing
    public var neuralCoreService: (any BASNeuralCoreServicing)?
    public var loopService: any BASLoopServicing
    public var triSelfService: any BASTriSelfServicing
    public var riskService: any BASRiskServicing
    public var actionService: any BASActionServicing
    public var evolutionService: any BASEvolutionServicing
    public var policyLineage: BASRuntimePolicyLineage?
    public var hostRhythmProfile: BASHostRhythmProfile
    public var hostConstitution: BASHostConstitution?
    public var hostConstitutionVault: BASHostConstitutionVault?
    public var hostVersionTree: BASHostVersionTree?
    public var hostForgetRequest: BASForgetRequest?

    // MARK: - M420 hot-path string constants (chapter 一百)
    //
    // Chapter 一百 deep-bench optimization: invariant string arrays
    // used by the M402 / M405 Kunlun-doctrine derive seams are
    // hoisted to `static let` so each `runTurn` invocation reuses
    // the same Array<String> reference instead of allocating fresh
    // copies. Same string array reference shared between the
    // upstream "for-gate" derive (line ~466) and downstream
    // "for-audit" derive (line ~964).
    //
    // Prior state: each `runTurn` allocated 2× 14-element arrays
    // (activeLayerRefs) + 1× 5-element array (transformationSteps)
    // + 2× 3-element arrays (centerlineRules). Each allocation
    // touches the heap and dirties the stack; replacing with
    // shared static references avoids ~38 string-array allocations
    // and ~18 string-interpolation calls per turn.
    //
    // Doctrine pin: zero behavior change. The arrays' contents
    // are byte-identical to the inline literals they replace.
    // Verified by full BAS + Qinao test suite (2461 + 1375 + 0
    // failures).

    /// 14-layer ref list used by the M402 axis derive (both
    /// upstream gate-side and downstream audit-side).
    fileprivate static let kunlunActiveLayerRefs: [String] = [
        "L1", "L2", "L3", "L4", "L5", "L6",
        "L7", "L8", "L9", "L10", "L11", "L12",
        "L13", "L14",
    ]

    /// 5-step pipeline transformation list used by the M405
    /// River-Origin trace derive.
    fileprivate static let riverOriginTransformationSteps: [String] = [
        "risk.bind", "permit.synthesize", "neural.materialize",
        "tribunal.merge", "audit.emit",
    ]

    /// Pre-computed centerline-rules array per
    /// `BASActionPermitMode`. Avoids per-turn string interpolation
    /// + 3-element array allocation in M402 axis derive.
    /// Computed once at first access (Swift static-let lazy init).
    fileprivate static let kunlunCenterlineRulesByMode:
        [BASActionPermitMode: [String]] =
    {
        var result: [BASActionPermitMode: [String]] = [:]
        for mode in BASActionPermitMode.allCases {
            result[mode] = [
                "respects-host-boundary",
                "honors-world-anchor",
                "permit-mode-\(mode.rawValue)",
            ]
        }
        return result
    }()

    /// 2-condition reveal-conditions list used by the M408 Yaochi
    /// audit-projection derive (audit-only, fixed conditions).
    fileprivate static let yaochiAuditRevealConditions: [String] = [
        "host-explicit-recall",
        "anchor-tone-warm",
    ]

    public init(
        powerClockService: any BASPowerClockServicing,
        hostProfileService: any BASHostProfileServicing,
        contextService: any BASContextServicing,
        decomposeService: any BASDecomposeServicing,
        memoryService: any BASMemoryServicing,
        neuralCoreService: (any BASNeuralCoreServicing)? = nil,
        loopService: any BASLoopServicing,
        triSelfService: any BASTriSelfServicing,
        riskService: any BASRiskServicing,
        actionService: any BASActionServicing,
        evolutionService: any BASEvolutionServicing,
        policyLineage: BASRuntimePolicyLineage? = nil,
        hostRhythmProfile: BASHostRhythmProfile = .generic,
        hostConstitution: BASHostConstitution? = nil,
        hostConstitutionVault: BASHostConstitutionVault? = nil,
        hostVersionTree: BASHostVersionTree? = nil,
        hostForgetRequest: BASForgetRequest? = nil
    ) {
        self.powerClockService = powerClockService
        self.hostProfileService = hostProfileService
        self.contextService = contextService
        self.decomposeService = decomposeService
        self.memoryService = memoryService
        self.neuralCoreService = neuralCoreService
        self.loopService = loopService
        self.triSelfService = triSelfService
        self.riskService = riskService
        self.actionService = actionService
        self.evolutionService = evolutionService
        self.policyLineage = policyLineage
        self.hostRhythmProfile = hostRhythmProfile
        self.hostConstitution = hostConstitution
        self.hostConstitutionVault = hostConstitutionVault
        self.hostVersionTree = hostVersionTree
        self.hostForgetRequest = hostForgetRequest
    }

    public func runTurn(
        _ request: BASEBrainTurnRequest
    ) -> BASEBrainTurnResult {
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

        let routedBudget = BASBudgetFrame(
            schemaVersion: plannedBudget.schemaVersion,
            runMode: plannedBudget.runMode,
            maxLoops: plannedBudget.maxLoops,
            maxCandidates: plannedBudget.maxCandidates,
            maxDecodeTokens: plannedBudget.maxDecodeTokens,
            retrievalDepth: plannedBudget.retrievalDepth,
            precisionProfile: plannedBudget.precisionProfile,
            deviceRoute: powerClockService.routeDevice(
                deviceState: request.deviceState,
                budget: plannedBudget
            ),
            thermalGuardLevel: plannedBudget.thermalGuardLevel,
            maintenanceAllowed: powerClockService.scheduleMaintenance(
                deviceState: request.deviceState,
                budget: plannedBudget
            ),
            leaseID: plannedBudget.leaseID,
            leaseExpiresAt: plannedBudget.leaseExpiresAt,
            maintenanceClass: plannedBudget.maintenanceClass,
            wakeIntentID: plannedBudget.wakeIntentID,
            allowedHeads: plannedBudget.allowedHeads,
            policyBundleVersion: plannedBudget.policyBundleVersion,
            policyDecisionIDs: plannedBudget.policyDecisionIDs
        )

        let hostContext = hostProfileService.resolveHost(
            hostID: request.hostID,
            contextFrame: nil,
            riskCard: nil
        )
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
        let derivedSessionID = [
            request.hostID,
            rawContextFrame.taskType.rawValue,
            routedBudget.runMode.rawValue
        ].joined(separator: "|")
        let derivedTurnID =
            "\(derivedSessionID)#\(request.recordedAt.timeIntervalSinceReferenceDate)"
        let contextFrame = rawContextFrame
            .withDerivedPresenceObservationBundle(
                turnID: derivedTurnID,
                sessionID: derivedSessionID,
                emittedAt: request.recordedAt)

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
                turnID: derivedTurnID,
                sessionID: derivedSessionID,
                emittedAt: request.recordedAt)

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

        var thoughtFrame = loopService.iterate(
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle,
            budget: routedBudget
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
        let (normalizedThoughtFrame, loopFindings) = normalizeThoughtFrame(
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
                turnID: derivedTurnID,
                sessionID: derivedSessionID,
                emittedAt: request.recordedAt)

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
                turnID: derivedTurnID,
                sessionID: derivedSessionID,
                emittedAt: request.recordedAt)

        let riskService = self.riskService
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
        let boundRiskCard = primaryBinding?.riskCard ?? riskCard
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
        let abyssalPressureForGate = BASAbyssalPressureBudget
            .derive(
                turnID: derivedSessionID,
                riskLevel: boundRiskCard.riskLevel,
                uncertaintyLedger:
                    thoughtFrame.uncertaintyLedger,
                evidenceDebtCount:
                    thoughtFrame.evidenceDebts?.count ?? 0)
        let humanAnchorSignalForGate = BASHumanAnchorProtocol
            .derive(
                anchorID: "human-anchor-\(derivedSessionID)",
                hostSummaryRef: hostContext.hostID,
                riskLevel: boundRiskCard.riskLevel,
                permitMode: boundActionPermit.mode,
                candidateCount: thoughtFrame.candidates.count)
        let abyssalEscalation = BASAbyssalPermitEscalation
            .escalate(
                permit: boundActionPermit,
                pressure: abyssalPressureForGate,
                humanAnchor: humanAnchorSignalForGate)
        boundActionPermit = abyssalEscalation.permit
        let unknownReserveForGate = BASUnknownReserve.derive(
            reserveID:
                "unknown-reserve-\(derivedSessionID)",
            confidenceFloor: thoughtFrame.uncertaintyLedger?
                .confidenceFloor ?? 1.0)
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
        let kunlunAxisForGate = BASKunlunAxis(
            axisID: "axis-\(derivedSessionID)",
            hostRef: hostContext.hostID,
            sovereignRef: "sovereign-\(derivedSessionID)",
            worldAnchorRef:
                "world-anchor-\(derivedSessionID)",
            activeLayerRefs:
                Self.kunlunActiveLayerRefs,
            agentSeatRefs: [],
            centerlineRules:
                Self.kunlunCenterlineRulesByMode[
                    boundActionPermit.mode] ?? [],
            deviationThreshold: 0.7,
            lastAlignmentCheck: "")
        let kunlunMatchedForGate: Int = {
            switch boundRiskCard.riskLevel {
            case .low: return 3
            case .medium: return 2
            case .high: return 1
            case .extreme: return 0
            }
        }()
        let kunlunDeviationCodesForGate: [String] = {
            switch boundRiskCard.riskLevel {
            case .low: return []
            case .medium: return ["risk-medium-needs-attention"]
            case .high: return ["risk-high-narrows-axis"]
            case .extreme: return [
                "risk-extreme-axis-overreach",
            ]
            }
        }()
        let kunlunAxisAlignmentForGate = BASKunlunAxisProtocol
            .computeAlignment(
                alignmentID:
                    "axis-align-\(derivedSessionID)",
                axis: kunlunAxisForGate,
                targetRef: thoughtFrame.candidates.first?
                    .candidateID ?? "no-candidate",
                matchedRules: kunlunMatchedForGate,
                deviationCodes: kunlunDeviationCodesForGate,
                correctionHint: "")
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
        // M56 — L11 risk climate now surfaces per-dimension
        // observations on the main-chain thought frame. Reuses M53's
        // derived (sessionID, turnID) so L6 / L7 / L10 / L11 bundles
        // on this turn share strictly equal coordinates — the L14
        // audit surface joins them by that key.
        thoughtFrame = thoughtFrame
            .withDerivedRiskObservationBundle(
                turnID: derivedTurnID,
                sessionID: derivedSessionID,
                emittedAt: request.recordedAt)

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
                turnID: derivedTurnID,
                sessionID: derivedSessionID,
                emittedAt: request.recordedAt)
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
                turnID: derivedTurnID,
                sessionID: derivedSessionID,
                emittedAt: request.recordedAt)

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
                turnID: derivedTurnID,
                sessionID: derivedSessionID,
                emittedAt: request.recordedAt)

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
                turnID: derivedTurnID,
                sessionID: derivedSessionID,
                emittedAt: request.recordedAt)

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
                turnID: derivedTurnID,
                sessionID: derivedSessionID,
                emittedAt: request.recordedAt)

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
                turnID: derivedTurnID,
                sessionID: derivedSessionID,
                emittedAt: request.recordedAt)

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
                turnID: derivedTurnID,
                sessionID: derivedSessionID,
                emittedAt: request.recordedAt)

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
        let abyssalPressureForAudit = BASAbyssalPressureBudget
            .derive(
                turnID: runtimeTrace.sessionID,
                riskLevel: boundRiskCard.riskLevel,
                uncertaintyLedger:
                    thoughtFrame.uncertaintyLedger,
                evidenceDebtCount:
                    thoughtFrame.evidenceDebts?.count ?? 0)
        // M304 — derive human-anchor signal from final risk +
        // permit + candidate count. White-paper §5.3 / red line
        // 7: hint, not verdict.
        let humanAnchorSignalForAudit = BASHumanAnchorProtocol
            .derive(
                anchorID: "human-anchor-\(runtimeTrace.sessionID)",
                hostSummaryRef: hostContext.hostID,
                riskLevel: boundRiskCard.riskLevel,
                permitMode: boundActionPermit.mode,
                candidateCount: thoughtFrame.candidates.count)
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
        let synthesizedSealsForAudit = quarantineRecords.map { record in
            BASSealEnvelope(
                sealID: "seal.\(record.quarantineID)",
                targetRefs: [record.sourceRef],
                sealReason: record.reasonCodes
                    .joined(separator: ","),
                accessPolicy: .sovereignOnly,
                revealConditions: [],
                lineageCutRefs: [],
                auditRef: record.quarantineID)
        }
        let sealAggregateForAudit = BASOldSealSealingProtocol
            .aggregate(synthesizedSealsForAudit)
        // M305 — synthesize an L13 lifecycle session per fresh
        // UpdateTicket on this turn. All start at `.proposed`
        // (the typed entry point of the 8-stage state machine);
        // cross-turn promotion / retraction is the L13 actor
        // primitives' job, not this projection. The aggregate
        // is nil for turns that produced zero tickets, so the
        // audit-entry builder elides the lifecycle.* codes.
        let lifecycleSessionsForAudit = updateTickets.map {
            ticket in
            BASEvolutionLifecycleSession(
                candidateID: ticket.ticketID,
                currentStage: .proposed,
                history: [])
        }
        let lifecycleAggregateForAudit =
            BASEvolutionLifecycleSession.aggregate(
                lifecycleSessionsForAudit)
        // M316 — derive narrative distortion projection from
        // final risk + permit. Stays at zero on most axes
        // (M316.derive only populates forcedClosure +
        // urgencyMask) so the audit-entry consumer elides the
        // narrative codes unless the turn shows real
        // distortion shape.
        let narrativeDistortionForAudit = BASNarrativeDistortion
            .derive(
                distortionID:
                    "narrative-\(runtimeTrace.sessionID)",
                riskLevel: boundRiskCard.riskLevel,
                permitMode: boundActionPermit.mode)
        // M317 — derive anomaly trace from the M316 distortion.
        // Returns nil when no axis crosses the emit threshold;
        // audit-entry consumer elides the codes when nil.
        let anomalyTraceForAudit = BASAnomalyTrace.deriveOrNil(
            traceID: "anomaly-\(runtimeTrace.sessionID)",
            distortion: narrativeDistortionForAudit,
            relationShift: "",
            sourceRefs: [runtimeTrace.sessionID],
            pressureVector: abyssalPressureForAudit)
        // M318 — derive L9 abyssal-branch annotations from
        // candidate IDs + the M303 abyssal pressure reading.
        // Returns empty array when below the abyssal threshold;
        // audit-entry consumer elides all branch codes when
        // empty.
        let abyssalBranchesForAudit = BASAbyssalBranch.deriveAll(
            candidateIDs: thoughtFrame.candidates
                .map(\.candidateID),
            pressure: abyssalPressureForAudit)
        // M320 — derive `BASUnknownReserve` projection from L9
        // uncertainty ledger's confidence floor. When the floor
        // is high (≥0.8) the reserve resolves to `.unrestricted`
        // and the audit consumer elides the codes; otherwise
        // emits ceiling tier + ref count.
        let unknownReserveForAudit = BASUnknownReserve.derive(
            reserveID:
                "unknown-reserve-\(runtimeTrace.sessionID)",
            confidenceFloor: thoughtFrame.uncertaintyLedger?
                .confidenceFloor ?? 1.0)
        // M385 cap now fires upstream (M392 — see the gating block
        // right after `thoughtFrame.actionPermit = boundActionPermit`
        // at line ~380). `unknownReserveForAudit` here is the
        // audit-emission-side derive; the gate-side derive
        // (`unknownReserveForGate`) lives upstream. They produce
        // identical values from identical inputs.
        // M321 — derive `BASForbiddenKnowledgeCandidate`
        // aggregate from the turn's quarantine records. Empty
        // collection (no quarantines this turn) yields nil
        // aggregate → audit consumer elides all `forbidden.*`
        // codes.
        let forbiddenCandidatesForAudit = quarantineRecords.map {
            BASForbiddenKnowledgeCandidate.derive(from: $0)
        }
        let forbiddenAggregateForAudit =
            BASForbiddenKnowledgeCandidate.aggregate(
                forbiddenCandidatesForAudit)
        // M402 — Kunlun axis + alignment audit projection.
        // Builds a synthetic axis from the host context + permit
        // mode + risk level, computes alignment for the turn's
        // primary candidate. This is audit-only emission; M406
        // (chapter 九十三) will hook the alignment into L11 permit
        // synthesis. Doctrine: kunlun.axis.* codes are
        // observability-only at this milestone — no decision
        // influence yet (parity with M303 / M304 audit-only
        // pre-M384 phase for Cthulhu).
        let kunlunAxisForAudit = BASKunlunAxis(
            axisID: "axis-\(runtimeTrace.sessionID)",
            hostRef: hostContext.hostID,
            sovereignRef: "sovereign-\(runtimeTrace.sessionID)",
            worldAnchorRef:
                "world-anchor-\(runtimeTrace.sessionID)",
            activeLayerRefs:
                Self.kunlunActiveLayerRefs,
            agentSeatRefs: [],
            centerlineRules:
                Self.kunlunCenterlineRulesByMode[
                    boundActionPermit.mode] ?? [],
            deviationThreshold: 0.7,
            lastAlignmentCheck: "")
        // Synthesize a deviation count from the risk level —
        // higher risk = more rule-mismatches signaled. This is
        // a placeholder projection until M406 wires real L4
        // rule evaluation.
        let kunlunMatched: Int = {
            switch boundRiskCard.riskLevel {
            case .low: return 3
            case .medium: return 2
            case .high: return 1
            case .extreme: return 0
            }
        }()
        let kunlunDeviationCodes: [String] = {
            switch boundRiskCard.riskLevel {
            case .low: return []
            case .medium: return ["risk-medium-needs-attention"]
            case .high: return ["risk-high-narrows-axis"]
            case .extreme: return [
                "risk-extreme-axis-overreach",
            ]
            }
        }()
        let kunlunAxisAlignmentForAudit = BASKunlunAxisProtocol
            .computeAlignment(
                alignmentID:
                    "axis-align-\(runtimeTrace.sessionID)",
                axis: kunlunAxisForAudit,
                targetRef:
                    thoughtFrame.candidates.first?.candidateID
                    ?? "no-candidate",
                matchedRules: kunlunMatched,
                deviationCodes: kunlunDeviationCodes,
                correctionHint: "")
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
        let kunlunJadeSealForAudit = BASJadeCanonSeal(
            sealID: "jade-permit-\(runtimeTrace.sessionID)",
            targetRef:
                "permit-\(boundActionPermit.mode.rawValue)",
            objectClass: .actionPermit,
            targetSchemaVersion:
                BASActionPermit.currentSchemaVersion,
            provenanceRefs: {
                var refs: [String] = []
                refs.append(
                    "verdict-\(sovereignVerdict.verdictID)")
                refs.append(contentsOf:
                    sovereignWarrants.map(\.warrantID))
                if !thoughtFold.foldID.isEmpty {
                    refs.append("fold-\(thoughtFold.foldID)")
                }
                return refs
            }(),
            integrityHash: thoughtFold.checksum,
            signatureRef: sovereignVerdict.verdictID,
            replayRequired: boundActionPermit.requireMirror
                || boundActionPermit.requireCompare
                || boundActionPermit.requireSecondCheck,
            revocationPath:
                "rollback-\(runtimeTrace.sessionID)",
            sourceRiverRef:
                "river-\(runtimeTrace.sessionID)")
        let kunlunJadeVerificationForAudit =
            BASKunlunJadeCanonProtocol.verifySeal(
                kunlunJadeSealForAudit)
        // M405 — River-Origin lineage audit projection. Doctrine
        // §4.5: 没有源流就没有可信成长. Synthesize a per-turn
        // trace from existing turn metadata: roots from session
        // ref + verdict ref; tributaries from candidate IDs;
        // derived objects from the bound permit + warrants;
        // transformations from the pipeline stages we observably
        // ran; consents from quarantine + warrant witnesses;
        // permits from the bound permit; audit refs from the
        // about-to-be-emitted audit entry's stable prefix.
        // Audit-only emission — analyze produces orphan / cascade
        // warnings that surface in signalRefs.
        let kunlunRiverTraceForAudit = BASRiverOriginTrace(
            traceID: "river-\(runtimeTrace.sessionID)",
            rootSourceRefs: [
                "session-\(runtimeTrace.sessionID)",
                "verdict-\(sovereignVerdict.verdictID)",
            ],
            tributaryRefs: thoughtFrame.candidates
                .map(\.candidateID),
            derivedObjectRefs: {
                var refs: [String] = []
                refs.append(
                    "permit-\(boundActionPermit.mode.rawValue)")
                refs.append(contentsOf:
                    sovereignWarrants.map(\.warrantID))
                return refs
            }(),
            transformationSteps:
                Self.riverOriginTransformationSteps,
            consentRefs: quarantineRecords
                .map(\.quarantineID),
            permitRefs: [
                "permit-\(boundActionPermit.mode.rawValue)",
            ],
            auditRefs: [
                "audit.\(runtimeTrace.sessionID)." +
                "\(sovereignVerdict.verdictLevel.rawValue)",
            ],
            deletionDependents: [],
            lineageCutRefs: [])
        let kunlunRiverLineageForAudit =
            BASKunlunRiverOriginProtocol.analyze(
                kunlunRiverTraceForAudit)
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
        let kunlunYaochiSanctumForAudit: BASYaochiSanctumEntry = {
            let sanctumClass: BASYaochiSanctumClass =
                quarantineRecords.isEmpty
                    ? .boundary
                    : .sensitive
            return BASYaochiSanctumEntry(
                entryID:
                    "yaochi-\(runtimeTrace.sessionID)",
                memoryRef: thoughtFrame.candidates.first?
                    .candidateID ?? "no-memory",
                hostRef: hostContext.hostID,
                sanctumClass: sanctumClass,
                accessPolicy: .conditional,
                revealConditions:
                    Self.yaochiAuditRevealConditions,
                coolingPeriod: 60,
                humanAnchorRequired: true,
                lastRevealedAt: "")
        }()
        let kunlunYaochiAccessForAudit = BASKunlunYaochiProtocol
            .evaluateAccess(
                entry: kunlunYaochiSanctumForAudit,
                hostAnchorPresent:
                    humanAnchorSignalForAudit
                        .recommendedSurfaceTone != .reserved,
                matchedRevealConditions: {
                    // Match a single reveal condition
                    // representing whether the bound permit's
                    // mode allows recall (not in delay/block).
                    switch boundActionPermit.mode {
                    case .answer, .mirror, .compare:
                        return ["host-explicit-recall"]
                    default:
                        return []
                    }
                }(),
                secondsSinceLastReveal: 86400)
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
        let kunlunHeavenGateForAudit: BASHeavenGatePermit = {
            let gateClass: BASKunlunGateClass = {
                switch boundActionPermit.mode {
                case .answer, .mirror:
                    return .public
                case .compare, .draftOnly:
                    return .cognitive
                case .delay, .replace, .localOnly:
                    return .cognitive
                case .escalate, .block:
                    return .host
                }
            }()
            let passState: BASKunlunGateState
            switch sovereignVerdict.verdictLevel {
            case .pass:
                passState = .passed
            case .throttle, .shadowLock:
                passState = .pending
            case .toolCut, .memoryFreeze, .quarantine:
                passState = .remanded
            case .rollback, .deadStop:
                passState = .denied
            }
            return BASHeavenGatePermit(
                gateID: "tianmen-\(runtimeTrace.sessionID)",
                sourceRef: thoughtFrame.candidates.first?
                    .candidateID ?? "no-candidate",
                targetDomain:
                    "domain-\(boundActionPermit.mode.rawValue)",
                gateClass: gateClass,
                requiredSeals: sovereignWarrants
                    .map { "seal-\($0.warrantID)" },
                actionPermitRef:
                    "permit-\(boundActionPermit.mode.rawValue)",
                sovereignWarrantRef: sovereignWarrants.first?
                    .warrantID ?? "",
                secondCheckRequired:
                    boundActionPermit.requireSecondCheck,
                passState: passState,
                returnPathRef:
                    "rollback-\(runtimeTrace.sessionID)")
        }()
        let kunlunHeavenGateReadinessForAudit =
            BASKunlunHeavenGateProtocol.evaluateReadiness(
                kunlunHeavenGateForAudit)
        let sovereignAuditEntry = buildSovereignAuditEntry(
            sovereignVerdict: sovereignVerdict,
            sovereignCommitTokens: sovereignCommitTokens,
            sovereignWarrants: sovereignWarrants,
            quarantineRecords: quarantineRecords,
            runtimeTrace: runtimeTrace,
            thoughtFold: thoughtFold,
            riskCard: boundRiskCard,
            actionPermit: boundActionPermit,
            // M299 — feed the materialization's candidate bundle
            // so frontier status codes land in audit signalRefs.
            candidateObservationBundle: thoughtArtifacts
                .candidateObservationBundle,
            // M300 — feed tribunal observation bundle (already
            // attached to `thoughtFrame` via M55 derive seam) so
            // tribunal coverage codes land in audit signalRefs.
            tribunalObservationBundle: thoughtFrame
                .tribunalObservationBundle,
            // M303 — feed the Abyssal pressure projection so the
            // 3 abyssal.* codes land in audit signalRefs.
            abyssalPressure: abyssalPressureForAudit,
            // M304 — feed human-anchor signal + seal aggregate
            // so 2-4 humanAnchor.* / seal.* codes land in audit
            // signalRefs.
            humanAnchorSignal: humanAnchorSignalForAudit,
            sealAggregate: sealAggregateForAudit,
            // M305 — feed L13 lifecycle aggregate so
            // lifecycle.tickets / .terminal / .promoted /
            // .stages codes land in audit signalRefs when the
            // turn produces UpdateTickets.
            lifecycleAggregate: lifecycleAggregateForAudit,
            // M316 — feed narrative-distortion projection so
            // narrative.* codes land in audit signalRefs when
            // any of the 5 axes is non-trivial.
            narrativeDistortion: narrativeDistortionForAudit,
            // M317 — feed anomaly-trace (nil when distortion
            // has no axis above the threshold; codes elided).
            anomalyTrace: anomalyTraceForAudit,
            // M318 — feed L9 abyssal-branch annotations (empty
            // when below abyssal threshold; codes elided).
            abyssalBranches: abyssalBranchesForAudit,
            // M320 — feed L4 unknown-reserve projection (codes
            // elided when ceiling resolves to `.unrestricted`).
            unknownReserve: unknownReserveForAudit,
            // M321 — feed L13 forbidden-knowledge aggregate (nil
            // when no quarantines this turn; codes elided).
            forbiddenAggregate: forbiddenAggregateForAudit,
            // M402 — feed Kunlun axis-alignment projection so
            // kunlun.axis.center / kunlun.axis.deviation /
            // kunlun.axis.requires-gate codes land in audit
            // signalRefs.
            kunlunAxisAlignment: kunlunAxisAlignmentForAudit,
            // M404 — feed Jade Canon seal verification readout so
            // kunlun.jade.seal:<class>:<status> +
            // kunlun.jade.missing:<count> codes land in audit
            // signalRefs. Doctrine §4.2 (玉律不能成黑箱).
            jadeCanonVerification: kunlunJadeVerificationForAudit,
            jadeCanonObjectClass: .actionPermit,
            // M405 — feed River-Origin lineage analysis so
            // kunlun.river.lineage / .upward / .downward /
            // .warnings codes land in audit signalRefs. Doctrine
            // §4.5 (没有源流就没有可信成长).
            riverOriginLineage: kunlunRiverLineageForAudit,
            // M408 — feed Yaochi sanctum access decision so
            // kunlun.yaochi.access:<class>:<decision> + reason
            // codes land in audit signalRefs. Doctrine §4.4
            // (默认不参与普通检索) + 红线 #3 (sanctum 不能被系统占
            // 有). Audit-only emission at this milestone.
            yaochiAccess: kunlunYaochiAccessForAudit,
            yaochiSanctumClass:
                kunlunYaochiSanctumForAudit.sanctumClass,
            // M409 — feed Heaven Gate readiness so
            // kunlun.tianmen.gate:<domain>:<state> + readiness
            // reason codes land in audit signalRefs. Doctrine
            // §4.3 (七 transition gates).
            tianmenReadiness: kunlunHeavenGateReadinessForAudit,
            tianmenGateClass:
                kunlunHeavenGateForAudit.gateClass,
            tianmenPassState:
                kunlunHeavenGateForAudit.passState,
            // M417 — feed escalation suppression reason codes
            // (M384 + M406) so red-line #8 (cross-doctrine
            // anchor-wins) honoring is observable in the audit
            // ledger. Empty array elides codes when no
            // suppression fired this turn.
            escalationSuppressionCodes: escalationSuppressionCodes
        )
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

        return BASEBrainTurnResult(
            deviceState: request.deviceState,
            budgetFrame: finalizedBudgetFrame,
            wakeIntent: wakeIntent,
            vitalState: vitalState,
            runLease: runLease,
            emergencyBrake: emergencyBrake,
            sovereignVerdict: finalSovereignVerdict,
            sovereignCommitTokens: sovereignCommitTokens,
            sovereignWarrants: sovereignWarrants,
            sovereignLock: sovereignLock,
            quarantineRecords: quarantineRecords,
            sovereignAuditEntry: sovereignAuditEntry,
            sovereignActuationCommands: sovereignActuationCommands,
            sovereignExecutionReceipts: sovereignExecutionReceipts,
            policyLineage: policyLineage,
            recoveryDisposition: recoveryDisposition,
            hostConstitution: hostConstitution,
            hostConstitutionVault: hostConstitutionVault,
            hostVersionTree: hostVersionTree,
            hostForgetRequest: hostForgetRequest,
            hostContext: hostContext,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle,
            thoughtFrame: thoughtFrame,
            thoughtFold: thoughtFold,
            triScores: triScores,
            mergedChoice: mergedChoice,
            riskCard: boundRiskCard,
            actionPermit: boundActionPermit,
            riskDecisionPackage: normalizedRiskDecisionPackage,
            hostGateValue: hostGateValue,
            renderedOutput: renderedOutput,
            updateTickets: updateTickets,
            experienceCandidates: evolutionGovernance.experienceCandidates,
            workflowCandidates: evolutionGovernance.workflowCandidates,
            guardTemplateCandidates: evolutionGovernance.guardTemplateCandidates,
            biasRecords: evolutionGovernance.biasRecords,
            riskPatternCandidates: evolutionGovernance.riskPatternCandidates,
            learningExportBundles: evolutionGovernance.learningExportBundles,
            shadowTrialRecords: evolutionGovernance.shadowTrialRecords,
            versionDeltas: evolutionGovernance.versionDeltas,
            retractionOrders: evolutionGovernance.retractionOrders,
            evolutionSeals: evolutionGovernance.evolutionSeals,
            runtimeTrace: finalizedRuntimeTrace
        )
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
