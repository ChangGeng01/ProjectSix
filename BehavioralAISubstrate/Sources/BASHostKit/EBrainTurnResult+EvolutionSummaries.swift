import CryptoKit
import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore
// chapter 七百二 native-port — Rust SHA256 primitive。 Legacy
// CryptoKit body preserved as `/* ... */` per 全comment 不要删除。
import BASRustCoreBridge

// MARK: - M71 split — BASEBrainTurnResult evolution summary computations.
// Formerly part of the 6099-line EBrainRuntimeCoordinator.swift; split by cohesion
// into three sibling extension files (+Summaries, +PrecisionHotCold, +BreathBridge).
// Methods that were file-scope `private` in the monolith are now module-scope
// `internal` (default access) so sibling extensions can call each other across
// the split.  They stay inside the BAS module and never surface through the
// Qinao SDK.

public extension BASEBrainTurnResult {
    var evolutionLineageSummary: BASEvolutionLineageSummary {
        let hostChangeCandidates = updateTickets.compactMap(\.resolvedHostChangeCandidate)
        let candidateTypeCounts = experienceCandidates.reduce(into: [String: Int]()) { counts, candidate in
            counts[candidate.candidateType.rawValue, default: 0] += 1
        }
        let passedShadowTrialCount = shadowTrialRecords.filter(\.isPassed).count
        let failedShadowTrialCount = shadowTrialRecords.filter(\.isFailed).count
        let pendingShadowTrialCount = shadowTrialRecords.filter(\.isPending).count
        let deniedSealCount = evolutionSeals.filter(\.isDenied).count
        let pendingSealCount = evolutionSeals.filter(\.isPending).count
        let pendingRetractionCount = retractionOrders.filter {
            $0.executionState != "completed" && $0.executionState != "cleared"
        }.count
        let versionDeltaHighlights = Array(versionDeltas.prefix(2)).map { delta in
            let targetRef = delta.afterRef
            return [
                "\(delta.targetType) \(targetRef)",
                delta.rollbackRef.map { "rollback \($0)" }
            ]
            .compactMap { $0 }
            .joined(separator: " • ")
        }
        let retractionOrderHighlights = Array(retractionOrders.prefix(2)).map { order in
            let status = order.executionState.replacingOccurrences(of: "_", with: " ")
            let targetRef = order.targetRefs.first ?? order.cascadeRefs.first ?? order.orderID
            return [
                "\(status) \(targetRef)",
                order.reasonCodes.first.map { "reason \($0)" }
            ]
            .compactMap { $0 }
            .joined(separator: " • ")
        }
        let pendingNurseryCandidateCount =
            workflowCandidates.filter { $0.shadowTrialState == "pending" }.count
            + guardTemplateCandidates.count
            + biasRecords.count
            + riskPatternCandidates.filter { $0.shadowTrialState == "pending" }.count
        var blockedPromotionReasonCodes: [String] = []
        if failedShadowTrialCount > 0 {
            blockedPromotionReasonCodes.append("evolution.shadow_trial_failed")
        }
        if pendingShadowTrialCount > 0 {
            blockedPromotionReasonCodes.append("evolution.shadow_trial_pending")
        }
        if deniedSealCount > 0 {
            blockedPromotionReasonCodes.append("evolution.seal_denied")
        }
        if pendingSealCount > 0 {
            blockedPromotionReasonCodes.append("evolution.seal_pending")
        }
        if pendingRetractionCount > 0 {
            blockedPromotionReasonCodes.append("evolution.retraction_pending")
        }
        let dreamLoopSignalRefs = updateTickets
            .flatMap(\.governanceRefs)
            .filter { $0.hasPrefix("dream_loop:") }
            .runtimeOrderedUniqueStrings()
        let dreamLoopRemandTargets = (thoughtFrame.remandOrders ?? [])
            .map(\.targetLayer)
            .runtimeOrderedUniqueStrings()
        let dreamLoopStoppingMode = thoughtFrame.convergenceCertificate?.stoppingMode.rawValue
        let dreamLoopReservationMode = thoughtFrame.agencyReservation?.mode.rawValue
        let dreamLoopMaxEvidenceDebtPercent = thoughtFrame.evidenceDebts?.map(\.debtWeight).max().map {
            Int(($0 * 100).rounded())
        }
        return BASEvolutionLineageSummary(
            recordedAt: runtimeTrace.recordedAt,
            sessionID: runtimeTrace.sessionID,
            runMode: budgetFrame.runMode,
            taskType: contextFrame.taskType.rawValue,
            riskLevel: riskCard.riskLevel.rawValue,
            permitMode: actionPermit.mode.rawValue,
            hostGatePercent: Int((hostGateValue * 100).rounded()),
            thoughtFoldChecksum: thoughtFold.checksum,
            updateTicketSummaries: Array(updateTickets.map(\.summary).prefix(3)),
            reviewDirectiveLine: updateTickets.lazy.compactMap(\.reviewDirectiveLine).first,
            hostChangeCandidateIDs: hostChangeCandidates.map(\.candidateID),
            hostChangeTypes: hostChangeCandidates.map(\.changeType),
            activeKillSwitches: Array(runtimeTrace.activeKillSwitches.map(\.rawValue).prefix(4)),
            guardrailFindings: Array(runtimeTrace.guardrailFindings.map(\.summary).prefix(3)),
            recommendedKillSwitches: Array(runtimeTrace.recommendedKillSwitches.map(\.rawValue).prefix(3)),
            stackedModes: Array((riskDecisionPackage?.actionModeDecision.stackedModes ?? actionPermit.stackedModes).map(\.rawValue).prefix(4)),
            assertionCeiling: riskDecisionPackage?.actionPermit.assertionCeiling ?? actionPermit.assertionCeiling,
            allowedDomains: Array((riskDecisionPackage?.actionPermit.allowedDomains ?? actionPermit.allowedDomains).prefix(6)),
            blockedDomains: Array((riskDecisionPackage?.actionPermit.blockedDomains ?? actionPermit.blockedDomains).prefix(6)),
            delayType: riskDecisionPackage?.delayReservation?.delayType ?? actionPermit.delayWindow ?? riskCard.delayType,
            substituteType: riskDecisionPackage?.protectiveSubstitute?.substituteType ?? riskCard.substituteType,
            sovereignHintLevel: riskDecisionPackage?.sovereignEscalationHint?.urgency ?? actionPermit.escalationHintRef ?? riskCard.sovereignHintLevel,
            wakeIntent: wakeIntent,
            vitalState: vitalState,
            runLease: runLease,
            emergencyBrake: emergencyBrake,
            sovereignVerdict: sovereignVerdict,
            sovereignCommitTokens: sovereignCommitTokens,
            sovereignWarrants: sovereignWarrants,
            sovereignLock: sovereignLock,
            quarantineRecords: quarantineRecords,
            sovereignAuditEntry: sovereignAuditEntry,
            sovereignActuationCommands: sovereignActuationCommands,
            sovereignExecutionReceipts: sovereignExecutionReceipts,
            policyLineage: policyLineage,
            recoveryDisposition: recoveryDisposition,
            neuralMorphID: thoughtFrame.organMap?.morph.rawValue,
            activeOrganIDs: thoughtFrame.organMap?.activeOrgans.map(\.rawValue) ?? [],
            headGuarantees: thoughtFrame.organMap?.headGuarantees ?? [],
            frontierWidth: thoughtFrame.candidateFrontier?.frontierWidth,
            bindingCount: thoughtFrame.riskBindings?.count ?? 0,
            projectionLeadCandidateID: thoughtFrame.candidates.first?.candidateID,
            projectionCandidateCount: thoughtFrame.candidates.count,
            projectionForecastCount: thoughtFrame.forecasts.count,
            projectionCritiqueCount: thoughtFrame.critiques.count,
            degradedReasonCodes: thoughtFold.degradedReasonCodes,
            contextSummary: BASEvolutionLineageSummary.ContextSummary(
                emotionalLoadPercent: Int((contextFrame.emotionalLoad * 100).rounded()),
                timePressurePercent: Int((contextFrame.timePressure * 100).rounded()),
                relationPattern: contextFrame.relationPattern,
                ambiguityPercent: Int((contextFrame.ambiguityScore * 100).rounded()),
                consequencePercent: Int((contextFrame.consequenceLevel * 100).rounded()),
                manipulationHintCount: contextFrame.manipulationHints.count,
                sceneType: contextFrame.sceneType.rawValue,
                roleRelationClass: contextFrame.roleGeometry?.relationClass,
                powerDirection: contextFrame.powerGradient?.direction,
                powerStrengthPercent: contextFrame.powerGradient.map { Int(($0.strength * 100).rounded()) },
                urgencyPercent: contextFrame.urgencyTruth.map { Int(($0.statedUrgency * 100).rounded()) },
                routeMode: contextFrame.routeHint?.preferredMode,
                guardRequired: contextFrame.routeHint?.needGuard,
                continuityArc: contextFrame.continuityAnchor?.sceneArc
            ),
            cognitionSummary: BASEvolutionLineageSummary.CognitionSummary(
                factCount: decomposeFrame.facts.count,
                goalCount: decomposeFrame.goals.count,
                claimCount: decomposeFrame.claimShards.isEmpty ? nil : decomposeFrame.claimShards.count,
                unknownCount: decomposeFrame.unknowns.count,
                contradictionCount: decomposeFrame.contradictions.count,
                pressureSummary: decomposeFrame.pressureVectors.isEmpty
                    ? nil
                    : lineageSummaryTokens(decomposeFrame.pressureVectors.map { $0.kind.rawValue }),
                manipulationSummary: decomposeFrame.manipulationPatterns.isEmpty
                    ? nil
                    : lineageSummaryTokens(decomposeFrame.manipulationPatterns.map { $0.kind.rawValue }),
                boundarySummary: decomposeFrame.boundaryTouches.isEmpty
                    ? nil
                    : lineageSummaryTokens(
                        decomposeFrame.boundaryTouches.map { "\($0.domain.rawValue):\($0.level.rawValue)" }
                    ),
                mirrorModeID: decomposeFrame.mirrorDraft?.mode.rawValue,
                routeHint: decomposeFrame.canonicalFrame?.routeHint,
                memoryAtomCount: memoryBundle.atoms.count,
                candidateCount: thoughtFrame.candidates.count,
                forecastCount: thoughtFrame.forecasts.count,
                critiqueCount: thoughtFrame.critiques.count,
                stopReasonID: thoughtFrame.stopReason?.rawValue,
                mirrorCalibrationPointCount: decomposeFrame.mirrorDraft?.calibrationPoints.isEmpty == false
                    ? decomposeFrame.mirrorDraft?.calibrationPoints.count
                    : nil,
                mirrorOmittedSpeculationCount: decomposeFrame.mirrorDraft?.omittedSpeculations.isEmpty == false
                    ? decomposeFrame.mirrorDraft?.omittedSpeculations.count
                    : nil,
                mirrorToneGuard: decomposeFrame.mirrorDraft?.toneGuard
            ),
            adjudicationSummary: BASEvolutionLineageSummary.AdjudicationSummary(
                triScoreCount: triScores.count,
                vetoCount: triScores.filter(\.veto).count,
                gsiPercent: Int((riskCard.gsiScore * 100).rounded()),
                alternativeActionCount: renderedOutput.alternativeActions.count,
                emergencyBrakeLevelID: emergencyBrake.brakeLevel == .none ? nil : emergencyBrake.brakeLevel.rawValue
            ),
            foldedLungSummary: evolutionFoldedLungSummary,
            governanceSummary: BASEvolutionLineageSummary.GovernanceSummary(
                experienceCandidateCount: experienceCandidates.count,
                experienceCandidateTypeCounts: candidateTypeCounts,
                workflowCandidateCount: workflowCandidates.count,
                guardTemplateCandidateCount: guardTemplateCandidates.count,
                biasRecordCount: biasRecords.count,
                riskPatternCandidateCount: riskPatternCandidates.count,
                learningExportBundleCount: learningExportBundles.count,
                pendingNurseryCandidateCount: pendingNurseryCandidateCount,
                passedShadowTrialCount: passedShadowTrialCount,
                failedShadowTrialCount: failedShadowTrialCount,
                shadowTrialCount: shadowTrialRecords.count,
                pendingShadowTrialCount: pendingShadowTrialCount,
                sealCount: evolutionSeals.count,
                deniedSealCount: deniedSealCount,
                pendingSealCount: pendingSealCount,
                versionDeltaCount: versionDeltas.count,
                versionDeltaHighlights: versionDeltaHighlights,
                retractionOrderCount: retractionOrders.count,
                retractionOrderHighlights: retractionOrderHighlights,
                pendingRetractionCount: pendingRetractionCount,
                blockedPromotionReasonCodes: blockedPromotionReasonCodes,
                dreamLoopStoppingMode: dreamLoopStoppingMode,
                dreamLoopSignalRefs: dreamLoopSignalRefs,
                dreamLoopRemandTargets: dreamLoopRemandTargets,
                dreamLoopReservationMode: dreamLoopReservationMode,
                dreamLoopMaxEvidenceDebtPercent: dreamLoopMaxEvidenceDebtPercent
            )
        )
    }
}

extension BASEBrainTurnResult {
    func lineageSummaryTokens(
        _ values: [String],
        limit: Int = 4
    ) -> String {
        var seen = Set<String>()
        let uniqueValues = values.filter { !$0.isEmpty && seen.insert($0).inserted }
        guard uniqueValues.isEmpty == false else { return "no signals" }

        let head = Array(uniqueValues.prefix(limit))
        let remainingCount = uniqueValues.count - head.count
        if remainingCount > 0 {
            return head.joined(separator: ", ") + ", +\(remainingCount) more"
        }
        return head.joined(separator: ", ")
    }

    /// chapter 七百二 native-port — Rust-sourced fingerprint;
    /// legacy CryptoKit body preserved per 全comment 不要删除。
    func fingerprint(for value: String) -> String {
        let data = Data(value.utf8)
        if let rust = try? BASRustLedgerCore.sha256(data) {
            return rust.compactMap {
                String(format: "%02x", $0)
            }.joined()
        }
        // LEGACY CryptoKit BODY — preserved per 全comment 不要删除。
        /*
         * Pre-chapter-702 Swift implementation:
         *     SHA256.hash(data: Data(value.utf8))
         *         .compactMap { String(format: "%02x", $0) }
         *         .joined()
         */
        return SHA256.hash(data: data)
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }

    func summarizedTokens(
        _ values: [String],
        limit: Int = 4
    ) -> String {
        var seen = Set<String>()
        let uniqueValues = values.filter { !$0.isEmpty && seen.insert($0).inserted }
        guard uniqueValues.isEmpty == false else { return "no signals" }

        let head = Array(uniqueValues.prefix(limit))
        let remainingCount = uniqueValues.count - head.count
        if remainingCount > 0 {
            return head.joined(separator: ", ") + ", +\(remainingCount) more"
        }
        return head.joined(separator: ", ")
    }

    var evolutionFoldedLungSummary: BASEvolutionFoldedLungSummary {
        let breathMode = evolutionBreathMode
        let breathPhase = evolutionBreathPhase
        let resumeID = thoughtFold.resumeFrameRef?.trimmedNonEmpty
            ?? "resume.\(runtimeTrace.sessionID).\(thoughtFold.foldID)"
        let rollbackAnchorID = thoughtFold.rollbackAnchorRef?.trimmedNonEmpty
            ?? "rollback.\(runtimeTrace.sessionID).\(thoughtFold.foldID)"
        let morphGraphID = thoughtFold.morphGraphRef?.trimmedNonEmpty
            ?? "morph.\(runtimeTrace.sessionID).\(thoughtFold.foldID)"
        let hotColdMapID = thoughtFold.hotColdMapRef?.trimmedNonEmpty
            ?? "hotcold.\(runtimeTrace.sessionID).\(thoughtFold.foldID)"
        let precisionProfileID = thoughtFold.precisionProfileRef?.trimmedNonEmpty
            ?? "precision.\(runtimeTrace.sessionID).\(thoughtFold.foldID)"
        let lungStateRef = thoughtFold.lungStateRef?.trimmedNonEmpty
            ?? "lung.\(runtimeTrace.sessionID).\(thoughtFold.foldID)"
        let breathSchedulerID = thoughtFold.breathSchedulerRef?.trimmedNonEmpty
            ?? "scheduler.\(runtimeTrace.sessionID).\(thoughtFold.foldID)"
        let thermalExchangeID = thoughtFold.thermalExchangeRef?.trimmedNonEmpty
            ?? "thermal.\(runtimeTrace.sessionID).\(thoughtFold.foldID)"
        let integrityWeaveID = thoughtFold.integrityWeaveRef?.trimmedNonEmpty
            ?? "integrity.\(runtimeTrace.sessionID).\(thoughtFold.foldID)"
        let activeOrgans = thoughtFrame.organMap?.activeOrgans ?? [.stubCore]
        let requiredOrganIDs = activeOrgans.map(\.rawValue)
        let executionOrder = activeOrgans.map(\.rawValue)
        let precisionMap = thoughtFrame.organMap?.precisionMap ?? evolutionPrecisionMap(for: activeOrgans)
        let precisionRecords = precisionMap.map(evolutionPrecisionRecord(for:))
        let fallbackMode = breathMode == "lockdown" ? "lockdownShell" : "rollbackAnchor"
        let cacheStateRef = "cache.\(runtimeTrace.sessionID).\(precisionProfileID)"
        let rollbackFoldRefs = evolutionOrderedUnique([thoughtFold.foldID])
        let safeSnapshotRef = thoughtFold.snapshotRef?.trimmedNonEmpty
            ?? "snapshot.\(runtimeTrace.sessionID).\(thoughtFold.foldID)"
        let lockedPrecisionOrganIDs = evolutionOrderedUnique(
            precisionMap.compactMap { precision in
                switch precision.organ {
                case .riskSpine, .permitKnot, .stubCore:
                    return precision.organ.rawValue
                default:
                    return nil
                }
            }
        )
        let sovereignBridge = evolutionSovereignBridge(
            currentBreathMode: breathMode,
            resumeID: resumeID,
            cacheStateRef: cacheStateRef,
            rollbackFoldRefs: rollbackFoldRefs
        )
        let hotColdMap = evolutionHotColdMap(
            currentBreathMode: sovereignBridge.resultingBreathMode ?? breathMode,
            activeOrgans: activeOrgans
        )
        let breathScheduler = evolutionBreathScheduler(
            schedulerID: breathSchedulerID,
            currentBreathMode: sovereignBridge.resultingBreathMode ?? breathMode,
            currentBreathPhase: breathPhase,
            restoreReadinessPercent: evolutionRestoreReadinessPercent
        )
        let thermalExchange = evolutionThermalExchangeFrame(
            exchangeID: thermalExchangeID,
            currentBreathMode: sovereignBridge.resultingBreathMode ?? breathMode,
            activeOrgans: activeOrgans,
            hotColdMap: hotColdMap,
            precisionMap: precisionMap
        )
        let integrityRequiredChecks = evolutionIntegrityRequiredChecks(
            hasRiskBindings: thoughtFrame.riskBindings?.isEmpty == false,
            hasBindingChecksum: thoughtFold.bindingChecksum != nil
        )
        let integrityFailedChecks = evolutionIntegrityFailedChecks(
            sovereignBridge: sovereignBridge
        )
        let integrityCompletedChecks = evolutionIntegrityCompletedChecks(
            requiredChecks: integrityRequiredChecks,
            failedChecks: integrityFailedChecks
        )
        let integrityContaminationRefs = evolutionIntegrityContaminationRefs(
            sovereignBridge: sovereignBridge
        )
        let integrityPurityState = evolutionIntegrityPurityState(
            sovereignBridge: sovereignBridge,
            contaminationRefs: integrityContaminationRefs
        )
        let integrityVerificationSeed = (
            [
                integrityWeaveID,
                thoughtFold.checksum,
                rollbackAnchorID,
                safeSnapshotRef,
                integrityPurityState
            ]
            + integrityRequiredChecks
            + integrityCompletedChecks
            + integrityFailedChecks
            + integrityContaminationRefs
        ).joined(separator: "||")
        // chapter 七百二 native-port — Rust-sourced integrity-
        // verification hash;legacy CryptoKit body preserved。
        let integrityVerificationSeedData = Data(
            integrityVerificationSeed.utf8)
        let integrityVerificationHash: String
        if let rust = try? BASRustLedgerCore.sha256(
            integrityVerificationSeedData)
        {
            integrityVerificationHash = rust.compactMap {
                String(format: "%02x", $0)
            }.joined()
        } else {
            // LEGACY CryptoKit BODY — preserved per 全comment 不要删除。
            /*
             * Pre-chapter-702 Swift implementation:
             *     let integrityVerificationHash =
             *         SHA256.hash(data: Data(integrityVerificationSeed.utf8))
             *             .compactMap { String(format: "%02x", $0) }
             *             .joined()
             */
            integrityVerificationHash = SHA256.hash(
                data: integrityVerificationSeedData)
                .compactMap { String(format: "%02x", $0) }
                .joined()
        }
        return BASEvolutionFoldedLungSummary(
            morphGraphID: morphGraphID,
            hotColdMapID: hotColdMapID,
            precisionProfileID: precisionProfileID,
            lungStateRef: lungStateRef,
            breathSchedulerID: breathSchedulerID,
            thermalExchangeID: thermalExchange.exchangeID,
            integrityWeaveID: integrityWeaveID,
            breathMode: sovereignBridge.resultingBreathMode ?? breathMode,
            breathPhase: breathPhase,
            thermalPressure: evolutionThermalPressure,
            cachePressure: evolutionCachePressure,
            restoreReadinessPercent: evolutionRestoreReadinessPercent,
            resumeID: resumeID,
            sourceFoldID: thoughtFold.foldID,
            resumeDepth: max(runtimeTrace.loopCount, budgetFrame.maxLoops > 1 ? 1 : 0),
            requiredOrganIDs: requiredOrganIDs,
            consistencyChecks: evolutionOrderedUnique([
                "fold_checksum",
                thoughtFrame.riskBindings?.isEmpty == false ? "risk_permit" : nil,
                "host_gate",
                thoughtFold.bindingChecksum == nil ? nil : "binding_checksum"
            ].compactMap { $0 }),
            fallbackMode: fallbackMode,
            rollbackAnchorID: rollbackAnchorID,
            safeSnapshotRef: safeSnapshotRef,
            foldRefs: rollbackFoldRefs,
            hostVersionRef: hostContext.activeVersion,
            cacheStateRef: cacheStateRef,
            integrityHash: thoughtFold.checksum,
            sovereignActuationKinds: sovereignBridge.actuationKinds,
            invalidatedResumeFrameIDs: sovereignBridge.invalidatedResumeFrameIDs,
            invalidatedCacheRefs: sovereignBridge.invalidatedCacheRefs,
            invalidatedFoldRefs: sovereignBridge.invalidatedFoldRefs,
            quarantinedFoldRefs: sovereignBridge.quarantinedFoldRefs,
            resultingBreathMode: sovereignBridge.resultingBreathMode,
            preservedReadOnlyRecovery: sovereignBridge.preservedReadOnlyRecovery,
            sovereignBridgeSummary: sovereignBridge.summary,
            morphActiveOrganIDs: requiredOrganIDs,
            morphExecutionOrder: executionOrder,
            morphPrecisionRecords: precisionRecords,
            morphDeviceRouteMap: Dictionary(uniqueKeysWithValues: activeOrgans.map { ($0.rawValue, budgetFrame.deviceRoute.rawValue) }),
            morphThermalProfile: [
                "thermal.\(deviceState.thermalLevel.rawValue)",
                "guard.\(budgetFrame.thermalGuardLevel.rawValue)",
                "latency.\(deviceState.latencyBudgetMs)",
                "cache.\(Int((runtimeTrace.cacheHitRate * 100).rounded()))"
            ],
            morphSovereignConstraints: thoughtFrame.organMap?.sovereignConstraints ?? sovereignActuationCommands.map(\.kind.rawValue),
            hotOrganIDs: hotColdMap.hotOrgans.map(\.rawValue),
            warmOrganIDs: hotColdMap.warmOrgans.map(\.rawValue),
            coldOrganIDs: hotColdMap.coldOrgans.map(\.rawValue),
            hotColdPreloadPolicy: hotColdMap.preloadPolicy,
            hotColdEvictionPolicy: hotColdMap.evictionPolicy,
            schedulerCadenceTag: breathScheduler.cadenceTag,
            schedulerCheckpointCadence: breathScheduler.checkpointCadence,
            schedulerMicroSleepWindowMs: breathScheduler.microSleepWindowMs,
            schedulerBackgroundMaintenanceWindowMs: breathScheduler.backgroundMaintenanceWindowMs,
            schedulerAllowsBackgroundMaintenance: breathScheduler.allowsBackgroundMaintenance,
            schedulerAllowsMicroSleep: breathScheduler.allowsMicroSleep,
            schedulerResumeBudgetClass: breathScheduler.resumeBudgetClass,
            schedulerReasonCodes: breathScheduler.schedulerReasonCodes,
            thermalExchangeMode: thermalExchange.exchangeMode,
            thermalPredictedBand: thermalExchange.predictedThermalBand,
            thermalCoolingActions: thermalExchange.coolingActions,
            thermalSuppressedOrganIDs: thermalExchange.suppressedOrgans.map(\.rawValue),
            thermalReroutedOrganIDs: thermalExchange.reroutedOrgans.map(\.rawValue),
            thermalRerouteTargets: thermalExchange.rerouteTargets,
            thermalPrecisionDowngradeRecords: thermalExchange.precisionDowngradePlan.map(evolutionPrecisionRecord(for:)),
            thermalExchangeReasonCodes: thermalExchange.exchangeReasonCodes,
            integrityRequiredChecks: integrityRequiredChecks,
            integrityCompletedChecks: integrityCompletedChecks,
            integrityFailedChecks: integrityFailedChecks,
            integrityPurityState: integrityPurityState,
            integrityContaminationRefs: integrityContaminationRefs,
            integrityTrustedSnapshotRef: safeSnapshotRef,
            integrityVerificationHash: integrityVerificationHash,
            precisionOrganPrecisionRecords: precisionRecords,
            precisionLockedOrganIDs: lockedPrecisionOrganIDs,
            precisionDegradationOrder: evolutionPrecisionDegradationOrder(),
            precisionGuardSafeFloorID: evolutionPrecisionGuardSafeFloorID(currentBreathMode: sovereignBridge.resultingBreathMode ?? breathMode)
        )
    }
}
