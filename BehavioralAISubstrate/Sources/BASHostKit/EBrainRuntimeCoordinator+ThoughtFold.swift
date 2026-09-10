import CryptoKit
import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

// MARK: - M71 split — BASEBrainRuntimeCoordinator — ThoughtFold builder + runtime thought-fold helpers.
// buildThoughtFold / condensed / hostModulationSummary / firstNonEmpty /
// runtimeThoughtFoldBreathMode / HotColdMap / OrganPackageID / HotPriority /
// WarmPriority / PreloadPolicy / EvictionPolicy.
// Extracted from the 6099-line monolith during the M71 cohesion split.

extension BASEBrainRuntimeCoordinator {
    func buildThoughtFold(
        request: BASEBrainTurnRequest,
        hostContext: BASHostProfile,
        hostConstitution: BASHostConstitution?,
        hostConstitutionVault: BASHostConstitutionVault?,
        hostVersionTree: BASHostVersionTree?,
        hostForgetRequest: BASForgetRequest?,
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame,
        thoughtFrame: BASThoughtFrame,
        riskCard: BASRiskCard,
        hostGateValue: Double
    ) -> BASThoughtFold {
        var compactSlots = [
            "task_type": contextFrame.taskType.rawValue,
            "host_version": hostContext.activeVersion,
            "facts": String(decomposeFrame.facts.count),
            "unknowns": String(decomposeFrame.unknowns.count),
            "risk_level": riskCard.riskLevel.rawValue,
            "permit_mode": thoughtFrame.actionPermit?.mode.rawValue ?? riskCard.recommendedMode.rawValue,
            "morph": thoughtFrame.organMap?.morph.rawValue ?? "none",
            "frontier": String(thoughtFrame.candidateFrontier?.frontierWidth ?? 0),
            "critique_bundles": String(thoughtFrame.critiqueBundles?.count ?? 0),
            "bindings": String(thoughtFrame.riskBindings?.count ?? 0),
            "stability": String(format: "%.2f", thoughtFrame.stabilityScore),
            "stop_reason": (thoughtFrame.stopReason ?? .candidateStable).rawValue,
            "gate": String(format: "%.2f", hostGateValue),
            "mirror": condensed(decomposeFrame.mirrorText, limit: 96)
        ]
        if decomposeFrame.claimShards.isEmpty == false {
            compactSlots["l7_claims"] = String(decomposeFrame.claimShards.count)
        }
        if let goalSpineLocal = decomposeFrame.goalSpineLocal {
            compactSlots["l7_goal_spine"] = condensed(
                goalSpineSummary(goalSpineLocal),
                limit: 96
            )
        }
        if decomposeFrame.pressureVectors.isEmpty == false {
            compactSlots["l7_pressures"] = summarizedTokens(
                decomposeFrame.pressureVectors.map { $0.kind.rawValue }
            )
        }
        if decomposeFrame.manipulationPatterns.isEmpty == false {
            compactSlots["l7_manipulation"] = summarizedTokens(
                decomposeFrame.manipulationPatterns.map { $0.kind.rawValue }
            )
        }
        if decomposeFrame.boundaryTouches.isEmpty == false {
            compactSlots["l7_boundaries"] = summarizedTokens(
                decomposeFrame.boundaryTouches.map { "\($0.domain.rawValue):\($0.level.rawValue)" }
            )
        }
        if let mirrorMode = decomposeFrame.mirrorDraft?.mode {
            compactSlots["l7_mirror_mode"] = mirrorMode.rawValue
        }
        if let routeHint = decomposeFrame.canonicalFrame?.routeHint, routeHint.isEmpty == false {
            compactSlots["l7_route_hint"] = routeHint
        }
        if let leadCandidateID = thoughtFrame.candidates.first?.candidateID {
            compactSlots["projection_lead_candidate"] = leadCandidateID
        }
        compactSlots["projection_candidates"] = String(thoughtFrame.candidates.count)
        compactSlots["projection_forecasts"] = String(thoughtFrame.forecasts.count)
        compactSlots["projection_critiques"] = String(thoughtFrame.critiques.count)
        if let toolIntentEnvelope = thoughtFrame.toolIntentEnvelope {
            compactSlots["tool_intent_mode"] = toolIntentEnvelope.permitMode.rawValue
            compactSlots["tool_intent_candidate"] = toolIntentEnvelope.candidateID
        }
        if let hostConstitution {
            compactSlots["constitution_version"] = hostConstitution.activeVersion
            compactSlots["constitution_phase"] = hostConstitution.narrativeLoom.currentPhase
        }
        if let hostModulation = hostModulationSummary(
            hostContext: hostContext,
            hostConstitution: hostConstitution
        ) {
            compactSlots["host_mod"] = condensed(hostModulation, limit: 96)
        }
        if let hostConstitutionVault {
            compactSlots["vault_signature"] = hostConstitutionVault.versionSignature
            compactSlots["vault_sync_revocations"] = String(hostConstitutionVault.syncRevocationLedger.revokedRequestIDs.count)
            compactSlots["vault_consistency_state"] = hostConstitutionVault.deviceConsistencyReport.consistencyState
            compactSlots["vault_out_of_sync_devices"] = String(hostConstitutionVault.deviceConsistencyReport.outOfSyncDeviceIDs.count)
            if !hostConstitutionVault.deviceConsistencyReport.outOfSyncDeviceIDs.isEmpty {
                compactSlots["vault_out_of_sync_list"] = hostConstitutionVault.deviceConsistencyReport.outOfSyncDeviceIDs.joined(separator: ",")
            }
            if let migrationContract = hostConstitutionVault.migrationContract {
                compactSlots["vault_migration_target"] = migrationContract.targetDeviceID
            }
            if let deletionManifest = hostConstitutionVault.deletionManifest {
                compactSlots["vault_deletion_manifest"] = deletionManifest.requestID
            }
        }
        if let hostVersionTree {
            compactSlots["constitution_pending_candidates"] = String(hostVersionTree.pendingCandidateIDs.count)
            compactSlots["constitution_frozen_versions"] = String(hostVersionTree.frozenVersionIDs.count)
        }
        if let hostForgetRequest {
            compactSlots["forget_request_id"] = hostForgetRequest.requestID
            compactSlots["forget_verified"] = String(hostForgetRequest.verified)
            compactSlots["forget_checkpoints_revoked"] = String(
                hostForgetRequest.executedSteps.contains("checkpoint_exports_revoked")
            )
            compactSlots["forget_sync_exports_revoked"] = String(
                hostForgetRequest.executedSteps.contains("sync_exports_revoked")
            )
        }

        let candidateSignatures = thoughtFrame.candidates.map { candidate in
            [
                candidate.candidateID,
                candidate.title,
                String(format: "%.2f", candidate.confidence),
                String(format: "%.2f", candidate.reversibility)
            ].joined(separator: "|")
        }

        let restorePointer = [
            request.hostID,
            hostContext.activeVersion,
            "step:\(thoughtFrame.stepIndex)",
            "risk:\(riskCard.riskLevel.rawValue)",
            "morph:\(thoughtFrame.organMap?.morph.rawValue ?? "none")"
        ].joined(separator: "::")

        let organChecksum = thoughtFrame.organMap.map { organMap in
            fingerprint(
                for: (
                    [organMap.morph.rawValue, organMap.routingPolicy.rawValue, organMap.leaseRef ?? ""]
                    + organMap.activeOrgans.map(\.rawValue)
                    + organMap.precisionMap.map { "\($0.organ.rawValue):\($0.tier.rawValue)" }
                    + organMap.sovereignConstraints
                    + organMap.headGuarantees
                ).joined(separator: "||")
            )
        }
        let frontierChecksum = thoughtFrame.candidateFrontier.map { frontier in
            fingerprint(
                for: (
                    frontier.candidateIDs
                    + frontier.dominanceOrder
                    + frontier.reversiblePaths
                    + frontier.guardPaths
                    + frontier.delayedPaths
                    + [String(frontier.frontierWidth), String(format: "%.2f", frontier.diversityScore)]
                ).joined(separator: "||")
            )
        }
        let bindingChecksum = thoughtFrame.riskBindings.map { bindings in
            fingerprint(
                for: bindings.map { binding in
                    [
                        binding.candidateID,
                        binding.riskLevel.rawValue,
                        binding.permitMode.rawValue,
                        String(format: "%.2f", binding.totalRisk),
                        String(format: "%.2f", binding.gsiScore)
                    ].joined(separator: "|")
                }.joined(separator: "||")
            )
        }

        let checksumSeed = (
            compactSlots.keys.sorted().map { "\($0)=\(compactSlots[$0] ?? "")" }
            + candidateSignatures
            + [restorePointer, organChecksum ?? "", frontierChecksum ?? "", bindingChecksum ?? ""]
        ).joined(separator: "||")
        let activeOrgans = thoughtFrame.organMap?.activeOrgans ?? [.stubCore]
        let currentBreathMode = runtimeThoughtFoldBreathMode(
            contextFrame: contextFrame,
            thoughtFrame: thoughtFrame,
            riskCard: riskCard
        )
        let thoughtFoldHotColdMap = runtimeThoughtFoldHotColdMap(
            currentBreathMode: currentBreathMode,
            activeOrgans: activeOrgans
        )
        let organPackageRefs = activeOrgans.map { organ in
            let packageClass: String
            if thoughtFoldHotColdMap.hotOrgans.contains(organ) {
                packageClass = "hot"
            } else if thoughtFoldHotColdMap.warmOrgans.contains(organ) {
                packageClass = "warm"
            } else {
                packageClass = "cold"
            }
            return "package.\(organ.rawValue.lowercased()).\(packageClass)"
        }
        return BASThoughtFold(
            foldID: "\(request.hostID).\(thoughtFrame.stepIndex)",
            compactSlots: compactSlots,
            candidateSignatures: candidateSignatures,
            riskSnapshot: riskCard,
            hostEffectSummary: hostModulationSummary(
                hostContext: hostContext,
                hostConstitution: hostConstitution
            ).map { condensed($0, limit: 120) } ?? condensed(hostContext.styleConstraints.joined(separator: " • "), limit: 120),
            restorePointer: restorePointer,
            checksum: fingerprint(for: checksumSeed),
            morphID: thoughtFrame.organMap?.morph.rawValue,
            organChecksum: organChecksum,
            frontierChecksum: frontierChecksum,
            bindingChecksum: bindingChecksum,
            degradedReasonCodes: thoughtFrame.neuralLeaseReceipt?.degraded == true
                ? (thoughtFrame.organMap?.morph == .stub ? ["runtime.stub_only"] : [])
                : [],
            tissueSignature: organChecksum,
            snapshotRef: "snapshot.\(request.hostID).\(thoughtFrame.stepIndex)",
            resumeFrameRef: "resume.\(request.hostID).\(thoughtFrame.stepIndex)",
            rollbackAnchorRef: "rollback.\(request.hostID).\(thoughtFrame.stepIndex)",
            morphGraphRef: "morph.\(request.hostID).\(thoughtFrame.stepIndex)",
            hotColdMapRef: "hotcold.\(request.hostID).\(thoughtFrame.stepIndex)",
            precisionProfileRef: "precision.\(request.hostID).\(thoughtFrame.stepIndex)",
            lungStateRef: "lung.\(request.hostID).\(thoughtFrame.stepIndex)",
            breathSchedulerRef: "scheduler.\(request.hostID).\(thoughtFrame.stepIndex)",
            thermalExchangeRef: "thermal.\(request.hostID).\(thoughtFrame.stepIndex)",
            integrityWeaveRef: "integrity.\(request.hostID).\(thoughtFrame.stepIndex)",
            organPackageRefs: organPackageRefs,
            organDeltaPlanRef: "delta.\(request.hostID).\(thoughtFrame.stepIndex)"
        )
    }

    func condensed(_ value: String, limit: Int) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit)) + "..."
    }

    func hostModulationSummary(
        hostContext: BASHostProfile,
        hostConstitution: BASHostConstitution?
    ) -> String? {
        var segments: [String] = []
        if hostContext.tonePreference.isEmpty == false {
            segments.append("tone:\(hostContext.tonePreference)")
        }
        guard let hostConstitution else {
            return segments.isEmpty ? nil : segments.joined(separator: " • ")
        }

        if hostConstitution.narrativeLoom.currentPhase.isEmpty == false {
            segments.append("phase:\(hostConstitution.narrativeLoom.currentPhase)")
        }
        if let primaryGoal = firstNonEmpty(
            hostConstitution.goalSpine.priorityOrder.first,
            hostConstitution.goalSpine.goals.first
        ) {
            segments.append("goal:\(primaryGoal)")
        }
        if let primaryRelation = firstNonEmpty(
            hostConstitution.relationGravity.highConsequenceLinks.first,
            hostConstitution.relationGravity.nodes.first
        ) {
            segments.append("relation:\(primaryRelation)")
        }
        if hostConstitution.consentLattice.memoryPromotionScope.isEmpty == false {
            segments.append("memory:\(hostConstitution.consentLattice.memoryPromotionScope)")
        }
        return segments.isEmpty ? nil : segments.joined(separator: " • ")
    }

    func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            guard let value else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty == false {
                return trimmed
            }
        }
        return nil
    }

    func runtimeThoughtFoldBreathMode(
        contextFrame: BASContextFrame,
        thoughtFrame: BASThoughtFrame,
        riskCard: BASRiskCard
    ) -> String {
        if riskCard.riskLevel == .extreme {
            return "lockdown"
        }
        if riskCard.riskLevel == .high || thoughtFrame.actionPermit?.mode.isProtective == true {
            return "guard"
        }
        if thoughtFrame.candidates.count > 1 || thoughtFrame.stepIndex > 1 {
            return "deepExchange"
        }
        if contextFrame.taskType == .choice
            || contextFrame.taskType == .conflict
            || thoughtFrame.candidateFrontier?.frontierWidth ?? 0 > 0 {
            return "structured"
        }
        return "light"
    }

    func runtimeThoughtFoldHotColdMap(
        currentBreathMode: String,
        activeOrgans: [BASNeuralOrgan]
    ) -> BASHotColdMap {
        let hotPriority = runtimeThoughtFoldHotPriority(for: currentBreathMode)
        let warmPriority = runtimeThoughtFoldWarmPriority(for: currentBreathMode)
        let hotOrgans = (hotPriority.filter { activeOrgans.contains($0) }
            + (activeOrgans.contains(.stubCore) ? [.stubCore] : []))
            .reduce(into: [BASNeuralOrgan]()) { result, organ in
                guard result.contains(organ) == false else { return }
                result.append(organ)
            }
        let normalizedHotOrgans = hotOrgans.isEmpty ? [.stubCore] : hotOrgans
        let warmOrgans = (activeOrgans + warmPriority).reduce(into: [BASNeuralOrgan]()) { result, organ in
            guard normalizedHotOrgans.contains(organ) == false, result.contains(organ) == false else { return }
            result.append(organ)
        }
        let coldOrgans = BASNeuralOrgan.allCases.filter {
            normalizedHotOrgans.contains($0) == false && warmOrgans.contains($0) == false
        }

        return BASHotColdMap(
            hotOrgans: normalizedHotOrgans,
            warmOrgans: warmOrgans,
            coldOrgans: coldOrgans,
            preloadPolicy: runtimeThoughtFoldPreloadPolicy(for: currentBreathMode),
            evictionPolicy: runtimeThoughtFoldEvictionPolicy(for: currentBreathMode)
        )
    }

    func runtimeThoughtFoldOrganPackageID(
        for organ: BASNeuralOrgan,
        hotColdMap: BASHotColdMap
    ) -> String {
        let packageClass: String
        if hotColdMap.hotOrgans.contains(organ) {
            packageClass = "hot"
        } else if hotColdMap.warmOrgans.contains(organ) {
            packageClass = "warm"
        } else {
            packageClass = "cold"
        }
        return "package.\(organ.rawValue.lowercased()).\(packageClass)"
    }

    func runtimeThoughtFoldHotPriority(
        for currentBreathMode: String
    ) -> [BASNeuralOrgan] {
        switch currentBreathMode {
        case "guard":
            return [.stubCore, .riskSpine, .permitKnot, .consistencyLattice]
        case "quarantine":
            return [.stubCore, .riskSpine, .permitKnot, .consistencyLattice, .tissueRouter]
        case "lockdown":
            return [.stubCore, .riskSpine, .permitKnot]
        case "deepExchange":
            return [.stubCore, .coreCortex, .riskSpine, .permitKnot, .simuRing, .criticBlade]
        case "structured":
            return [.stubCore, .coreCortex, .riskSpine, .permitKnot]
        default:
            return [.stubCore, .scoutStrip, .coreCortex]
        }
    }

    func runtimeThoughtFoldWarmPriority(
        for currentBreathMode: String
    ) -> [BASNeuralOrgan] {
        switch currentBreathMode {
        case "guard":
            return [.memoryCodecRidge, .hostModulationMesh, .toolIntentMesh]
        case "quarantine":
            return [.memoryCodecRidge, .hostModulationMesh]
        case "lockdown":
            return [.memoryCodecRidge]
        case "deepExchange":
            return [.consistencyLattice, .memoryCodecRidge, .hostModulationMesh, .toolIntentMesh]
        case "structured":
            return [.simuRing, .criticBlade, .consistencyLattice, .memoryCodecRidge]
        default:
            return [.riskSpine, .permitKnot, .memoryCodecRidge]
        }
    }

    func runtimeThoughtFoldPreloadPolicy(
        for currentBreathMode: String
    ) -> String {
        switch currentBreathMode {
        case "guard":
            return "guard_preload"
        case "quarantine":
            return "quarantine_rehydrate"
        case "lockdown":
            return "lockdown_stub_only"
        case "deepExchange":
            return "deep_exchange_prefetch"
        case "structured":
            return "structured_preload"
        default:
            return "light_preload"
        }
    }

    func runtimeThoughtFoldEvictionPolicy(
        for currentBreathMode: String
    ) -> String {
        switch currentBreathMode {
        case "guard":
            return "protective_retain"
        case "quarantine":
            return "quarantine_protective"
        case "lockdown":
            return "lockdown_evict_all"
        case "deepExchange":
            return "thermal_trim"
        case "structured":
            return "balanced_trim"
        default:
            return "latency_bias"
        }
    }

}
