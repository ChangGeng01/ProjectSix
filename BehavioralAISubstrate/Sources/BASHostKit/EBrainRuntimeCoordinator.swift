import CryptoKit
import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

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
        let sovereignAuditEntry = buildSovereignAuditEntry(
            sovereignVerdict: sovereignVerdict,
            sovereignCommitTokens: sovereignCommitTokens,
            sovereignWarrants: sovereignWarrants,
            quarantineRecords: quarantineRecords,
            runtimeTrace: runtimeTrace,
            thoughtFold: thoughtFold,
            riskCard: boundRiskCard,
            actionPermit: boundActionPermit
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

}
