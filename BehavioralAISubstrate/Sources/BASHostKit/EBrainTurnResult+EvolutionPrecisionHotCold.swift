import Foundation
import BASMemory
import BASOrchestration
import BASPolicy
import BASRuntimeCore

// MARK: - M71 split — BASEBrainTurnResult precision / hotcold / breath scheduler /
// thermal exchange / priority / integrity helpers.  Previously file-scope private
// inside the 6099-line EBrainRuntimeCoordinator.swift, now internal (default access)
// so sibling extension files in BASHostKit can share them.  None of these methods
// are part of the Qinao public surface; the BAS module continues to own them.

extension BASEBrainTurnResult {
    func evolutionPrecisionRecord(
        for precision: BASNeuralOrganPrecision
    ) -> BASEvolutionFoldedLungSummary.PrecisionRecord {
        let tier = precision.tier
        return BASEvolutionFoldedLungSummary.PrecisionRecord(
            organID: precision.organ.rawValue,
            tierID: tier.rawValue
        )
    }

    func evolutionPrecisionOptions(
        for organ: BASNeuralOrgan,
        primaryTier: BASNeuralPrecisionTier
    ) -> [BASNeuralPrecisionTier] {
        let fallbackTier: BASNeuralPrecisionTier = switch organ {
        case .stubCore, .riskSpine, .permitKnot:
            .protected
        case .memoryCodecRidge, .hostModulationMesh, .toolIntentMesh:
            .balanced
        default:
            .minimal
        }
        return evolutionOrderedUnique([primaryTier, fallbackTier, .minimal])
    }

    func evolutionOrganSovereignClass(
        for organ: BASNeuralOrgan
    ) -> String {
        switch organ {
        case .stubCore, .riskSpine, .permitKnot:
            return "protected_core"
        case .memoryCodecRidge, .consistencyLattice:
            return "checkpoint_recovery"
        case .hostModulationMesh:
            return "host_modulation"
        case .toolIntentMesh:
            return "tool_intent"
        default:
            return "general"
        }
    }

    func evolutionPrecisionMap(
        for activeOrgans: [BASNeuralOrgan]
    ) -> [BASNeuralOrganPrecision] {
        activeOrgans.map { organ in
            BASNeuralOrganPrecision(
                organ: organ,
                tier: evolutionPrecisionTier(for: organ)
            )
        }
    }

    func evolutionHotColdMap(
        currentBreathMode: String,
        activeOrgans: [BASNeuralOrgan]
    ) -> BASHotColdMap {
        let hotPriority = evolutionHotPriority(for: currentBreathMode)
        let warmPriority = evolutionWarmPriority(for: currentBreathMode)
        let hotOrgans = evolutionOrderedUniqueOrgans(
            hotPriority.filter { activeOrgans.contains($0) }
                + (activeOrgans.contains(.stubCore) ? [.stubCore] : [])
        )
        let normalizedHotOrgans = hotOrgans.isEmpty
            ? [.stubCore]
            : hotOrgans
        let warmOrgans = evolutionOrderedUniqueOrgans(
            activeOrgans.filter { normalizedHotOrgans.contains($0) == false }
                + warmPriority.filter { normalizedHotOrgans.contains($0) == false }
        )
        let coldOrgans = BASNeuralOrgan.allCases.filter {
            normalizedHotOrgans.contains($0) == false && warmOrgans.contains($0) == false
        }

        return BASHotColdMap(
            schemaVersion: BASHotColdMap.currentSchemaVersion,
            hotOrgans: normalizedHotOrgans,
            warmOrgans: warmOrgans,
            coldOrgans: coldOrgans,
            preloadPolicy: evolutionHotColdPreloadPolicy(for: currentBreathMode),
            evictionPolicy: evolutionHotColdEvictionPolicy(for: currentBreathMode)
        )
    }

    func evolutionBreathScheduler(
        schedulerID: String,
        currentBreathMode: String,
        currentBreathPhase: String,
        restoreReadinessPercent: Int
    ) -> BASBreathSchedulerFrame {
        let allowsBackgroundMaintenance = budgetFrame.maintenanceAllowed
            && currentBreathMode != "quarantine"
            && currentBreathMode != "lockdown"
        let allowsMicroSleep = currentBreathMode != "lockdown"

        return BASBreathSchedulerFrame(
            schedulerID: schedulerID,
            cadenceTag: evolutionSchedulerCadenceTag(
                for: currentBreathMode,
                currentBreathPhase: currentBreathPhase
            ),
            checkpointCadence: evolutionSchedulerCheckpointCadence(
                for: currentBreathMode,
                currentBreathPhase: currentBreathPhase
            ),
            microSleepWindowMs: allowsMicroSleep
                ? evolutionSchedulerMicroSleepWindowMs(
                    for: currentBreathMode,
                    currentBreathPhase: currentBreathPhase,
                    restoreReadinessPercent: restoreReadinessPercent
                )
                : 0,
            backgroundMaintenanceWindowMs: allowsBackgroundMaintenance
                ? evolutionSchedulerMaintenanceWindowMs()
                : 0,
            allowsBackgroundMaintenance: allowsBackgroundMaintenance,
            allowsMicroSleep: allowsMicroSleep,
            resumeBudgetClass: evolutionSchedulerResumeBudgetClass(
                for: currentBreathMode,
                currentBreathPhase: currentBreathPhase
            ),
            schedulerReasonCodes: evolutionOrderedUnique([
                "mode.\(currentBreathMode)",
                "phase.\(currentBreathPhase)",
                "thermal.\(budgetFrame.thermalGuardLevel.rawValue)",
                budgetFrame.maintenanceAllowed ? "maintenance.\(budgetFrame.maintenanceClass.rawValue)" : nil,
                runtimeTrace.loopCount > 1 ? "loop.multi" : nil,
                recoveryDisposition?.kind.rawValue
            ].compactMap { $0 })
        )
    }

    func evolutionThermalExchangeFrame(
        exchangeID: String,
        currentBreathMode: String,
        activeOrgans: [BASNeuralOrgan],
        hotColdMap: BASHotColdMap,
        precisionMap: [BASNeuralOrganPrecision]
    ) -> BASThermalExchangeFrame {
        let predictedBand = evolutionPredictedThermalBand()
        let coolingActions = evolutionThermalCoolingActions(
            predictedBand: predictedBand,
            currentBreathMode: currentBreathMode
        )
        let suppressedOrgans = evolutionSuppressedThermalOrgans(
            predictedBand: predictedBand,
            hotColdMap: hotColdMap
        )
        let rerouteTargets = evolutionThermalRerouteTargets(
            predictedBand: predictedBand,
            activeOrgans: activeOrgans
        )
        let reroutedOrgans = evolutionOrderedUniqueOrgans(
            rerouteTargets.keys.compactMap(BASNeuralOrgan.init(rawValue:))
        )
        let precisionDowngradePlan = evolutionThermalPrecisionDowngradePlan(
            predictedBand: predictedBand,
            activeOrgans: activeOrgans,
            hotColdMap: hotColdMap,
            precisionMap: precisionMap
        )

        return BASThermalExchangeFrame(
            exchangeID: exchangeID,
            exchangeMode: evolutionThermalExchangeMode(
                predictedBand: predictedBand,
                currentBreathMode: currentBreathMode
            ),
            predictedThermalBand: predictedBand,
            coolingActions: coolingActions,
            suppressedOrgans: suppressedOrgans,
            reroutedOrgans: reroutedOrgans,
            rerouteTargets: rerouteTargets,
            precisionDowngradePlan: precisionDowngradePlan,
            exchangeReasonCodes: evolutionOrderedUnique(
                [
                    "mode.\(currentBreathMode)",
                    "thermal.\(deviceState.thermalLevel.rawValue)",
                    "guard.\(budgetFrame.thermalGuardLevel.rawValue)",
                    "band.\(predictedBand)",
                    hotColdMap.hotOrgans.count > 2 ? "hot_pack.\(hotColdMap.hotOrgans.count)" : nil
                ]
                .compactMap { $0 }
            )
        )
    }

    func evolutionThermalExchangeMode(
        predictedBand: String,
        currentBreathMode: String
    ) -> String {
        if currentBreathMode == "lockdown" || currentBreathMode == "quarantine" {
            return "containment_exchange"
        }

        switch predictedBand {
        case "critical":
            return "emergency_exchange"
        case "hot":
            return "protective_exchange"
        case "warm":
            return "balanced_exchange"
        default:
            return currentBreathMode == "deepExchange"
                ? "deep_exchange"
                : "steady_exchange"
        }
    }

    func evolutionPredictedThermalBand() -> String {
        switch (deviceState.thermalLevel, budgetFrame.thermalGuardLevel) {
        case (.critical, _), (_, .emergency):
            return "critical"
        case (.hot, _), (_, .throttle):
            return "hot"
        case (.warm, _), (_, .watch):
            return "warm"
        default:
            return "nominal"
        }
    }

    func evolutionThermalCoolingActions(
        predictedBand: String,
        currentBreathMode: String
    ) -> [String] {
        switch predictedBand {
        case "critical":
            var criticalActions = [
                "delay_cold_organs",
                "trim_noncritical_precision",
                "pause_background_maintenance"
            ]
            criticalActions.append(
                currentBreathMode == "lockdown" ? "preserve_stub_shell" : "force_guard_shell"
            )
            return evolutionOrderedUnique(criticalActions)
        case "hot":
            var hotActions = [
                "delay_cold_organs",
                "trim_noncritical_precision"
            ]
            if budgetFrame.thermalGuardLevel == .throttle {
                hotActions.append("split_execution_graph")
            }
            return evolutionOrderedUnique(hotActions)
        case "warm":
            return ["delay_cold_organs"]
        default:
            return currentBreathMode == "deepExchange"
                ? ["preheat_hot_path"]
                : ["hold_hot_path"]
        }
    }

    func evolutionSuppressedThermalOrgans(
        predictedBand: String,
        hotColdMap: BASHotColdMap
    ) -> [BASNeuralOrgan] {
        let preferredOrder: [BASNeuralOrgan] = [
            .criticBlade,
            .simuRing,
            .scoutStrip,
            .toolIntentMesh,
            .memoryCodecRidge
        ]
        let suppressionPool = evolutionOrderedUniqueOrgans(
            preferredOrder.filter { hotColdMap.coldOrgans.contains($0) || hotColdMap.warmOrgans.contains($0) }
                + hotColdMap.coldOrgans
        )

        let limit: Int = switch predictedBand {
        case "critical":
            3
        case "hot":
            2
        case "warm":
            1
        default:
            0
        }

        return Array(suppressionPool.prefix(limit))
    }

    func evolutionThermalRerouteTargets(
        predictedBand: String,
        activeOrgans: [BASNeuralOrgan]
    ) -> [String: String] {
        guard predictedBand == "hot" || predictedBand == "critical" else {
            return [:]
        }

        let targetRoute = predictedBand == "critical" ? BASDeviceRoute.hybridLocal.rawValue : BASDeviceRoute.scoutCPU.rawValue
        var targets: [String: String] = [:]

        if activeOrgans.contains(.permitKnot) {
            targets[BASNeuralOrgan.permitKnot.rawValue] = targetRoute
        }
        if activeOrgans.contains(.memoryCodecRidge) {
            targets[BASNeuralOrgan.memoryCodecRidge.rawValue] = targetRoute
        }

        return targets
    }

    func evolutionThermalPrecisionDowngradePlan(
        predictedBand: String,
        activeOrgans: [BASNeuralOrgan],
        hotColdMap: BASHotColdMap,
        precisionMap: [BASNeuralOrganPrecision]
    ) -> [BASNeuralOrganPrecision] {
        guard predictedBand == "hot" || predictedBand == "critical" else {
            return []
        }

        let protectedOrgans: Set<BASNeuralOrgan> = [.stubCore, .riskSpine, .permitKnot]
        let candidateOrgans = evolutionOrderedUniqueOrgans(
            activeOrgans
                + hotColdMap.warmOrgans
                + hotColdMap.coldOrgans.filter { $0 == .hostModulationMesh || $0 == .toolIntentMesh }
        )
        let downgradeTier: BASNeuralPrecisionTier = predictedBand == "critical" ? .minimal : .balanced
        // audit H17: uniquing-guard — was Dictionary(uniqueKeysWithValues:), traps on duplicate key
        let currentTiers = Dictionary(precisionMap.map { ($0.organ, $0.tier) }, uniquingKeysWith: { first, _ in first })

        return candidateOrgans.compactMap { organ in
            guard protectedOrgans.contains(organ) == false else { return nil }
            let currentTier = currentTiers[organ]
            guard currentTier != downgradeTier else { return nil }
            return BASNeuralOrganPrecision(organ: organ, tier: downgradeTier)
        }
    }

    func evolutionSchedulerCadenceTag(
        for currentBreathMode: String,
        currentBreathPhase: String
    ) -> String {
        switch currentBreathMode {
        case "guard":
            return currentBreathPhase == "resume" ? "guard_resume" : "guard_exchange"
        case "quarantine":
            return "quarantine_hold"
        case "lockdown":
            return "lockdown_shell"
        case "deepExchange":
            return budgetFrame.thermalGuardLevel == .throttle ? "deep_exchange_throttled" : "deep_exchange"
        case "structured":
            return currentBreathPhase == "resume" ? "structured_resume" : "structured_cycle"
        default:
            return "light_pulse"
        }
    }

    func evolutionSchedulerCheckpointCadence(
        for currentBreathMode: String,
        currentBreathPhase: String
    ) -> String {
        switch currentBreathMode {
        case "guard":
            return "anchor_each_turn"
        case "quarantine":
            return "anchor_before_resume"
        case "lockdown":
            return "anchor_on_state_change"
        case "deepExchange":
            return currentBreathPhase == "resume" ? "anchor_on_restore" : "anchor_before_rest"
        case "structured":
            return "anchor_on_yield"
        default:
            return "anchor_on_idle"
        }
    }

    func evolutionSchedulerMicroSleepWindowMs(
        for currentBreathMode: String,
        currentBreathPhase: String,
        restoreReadinessPercent: Int
    ) -> Int {
        let readinessBonus = restoreReadinessPercent / 2
        let loopPenalty = min(runtimeTrace.loopCount * 30, 90)

        switch currentBreathMode {
        case "guard":
            return max(120, 160 + readinessBonus - loopPenalty)
        case "quarantine":
            return max(60, 90 + (readinessBonus / 2) - loopPenalty)
        case "lockdown":
            return 0
        case "deepExchange":
            return currentBreathPhase == "resume"
                ? max(100, 180 + readinessBonus - loopPenalty)
                : max(80, 140 + readinessBonus - loopPenalty)
        case "structured":
            return max(140, 220 + readinessBonus - loopPenalty)
        default:
            return max(180, 260 + readinessBonus - loopPenalty)
        }
    }

    func evolutionSchedulerMaintenanceWindowMs() -> Int {
        let baseWindow = switch budgetFrame.maintenanceClass {
        case .none: 0
        case .light: 80
        case .standard: 160
        case .deferred: 240
        }

        switch evolutionBreathMode {
        case "guard":
            return min(baseWindow, 60)
        case "quarantine", "lockdown":
            return 0
        case "deepExchange":
            return max(0, baseWindow - 40)
        case "structured":
            return baseWindow
        default:
            return baseWindow + 40
        }
    }

    func evolutionSchedulerResumeBudgetClass(
        for currentBreathMode: String,
        currentBreathPhase: String
    ) -> String {
        switch currentBreathMode {
        case "guard":
            return "rollback_hot"
        case "quarantine":
            return "readonly_quarantine"
        case "lockdown":
            return "lockdown_shell"
        case "deepExchange":
            return currentBreathPhase == "resume" ? "deep_resume_hot" : "deep_exchange_warm"
        case "structured":
            return "guarded_hot"
        default:
            return "light_hot"
        }
    }

    func evolutionHotPriority(
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

    func evolutionWarmPriority(
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

    func evolutionHotColdPreloadPolicy(
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

    func evolutionHotColdEvictionPolicy(
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

    func evolutionOrderedUniqueOrgans(
        _ organs: [BASNeuralOrgan]
    ) -> [BASNeuralOrgan] {
        organs.reduce(into: [BASNeuralOrgan]()) { uniqueOrgans, organ in
            guard uniqueOrgans.contains(organ) == false else { return }
            uniqueOrgans.append(organ)
        }
    }

    func evolutionPrecisionTier(
        for organ: BASNeuralOrgan
    ) -> BASNeuralPrecisionTier {
        switch organ {
        case .stubCore:
            return BASNeuralPrecisionTier.full
        case .riskSpine, .permitKnot:
            return budgetFrame.precisionProfile == .full
                ? BASNeuralPrecisionTier.full
                : BASNeuralPrecisionTier.protected
        case .tissueRouter, .consistencyLattice:
            return budgetFrame.runMode == .guard || budgetFrame.runMode == .quarantine || budgetFrame.runMode == .lockdown
                ? BASNeuralPrecisionTier.protected
                : BASNeuralPrecisionTier.balanced
        case .simuRing, .criticBlade:
            return budgetFrame.runMode == .deepLoop
                ? BASNeuralPrecisionTier.protected
                : BASNeuralPrecisionTier.balanced
        case .hostModulationMesh, .memoryCodecRidge:
            return BASNeuralPrecisionTier.balanced
        case .toolIntentMesh:
            return budgetFrame.runMode == .deepLoop
                ? BASNeuralPrecisionTier.balanced
                : BASNeuralPrecisionTier.minimal
        case .scoutStrip:
            return BASNeuralPrecisionTier.minimal
        case .coreCortex:
            switch budgetFrame.precisionProfile {
            case .minimal:
                return BASNeuralPrecisionTier.minimal
            case .balanced:
                return BASNeuralPrecisionTier.balanced
            case .protected:
                return BASNeuralPrecisionTier.protected
            case .full:
                return BASNeuralPrecisionTier.full
            }
        }
    }

    func evolutionPrecisionDegradationOrder() -> [String] {
        let tiers: [BASNeuralPrecisionTier] = [
            BASNeuralPrecisionTier.full,
            BASNeuralPrecisionTier.protected,
            BASNeuralPrecisionTier.balanced,
            BASNeuralPrecisionTier.minimal
        ]
        return tiers.map(\.rawValue)
    }

    func evolutionPrecisionGuardSafeFloorID(
        currentBreathMode: String
    ) -> String {
        switch currentBreathMode {
        case "guard", "quarantine", "lockdown":
            return BASNeuralPrecisionTier.protected.rawValue
        default:
            switch budgetFrame.precisionProfile {
            case .minimal:
                return BASNeuralPrecisionTier.minimal.rawValue
            case .balanced:
                return BASNeuralPrecisionTier.balanced.rawValue
            case .protected, .full:
                return BASNeuralPrecisionTier.protected.rawValue
            }
        }
    }

    func evolutionIntegrityRequiredChecks(
        hasRiskBindings: Bool,
        hasBindingChecksum: Bool
    ) -> [String] {
        evolutionOrderedUnique([
            "fold_checksum",
            hasRiskBindings ? "risk_permit" : nil,
            "host_gate",
            "rollback_anchor",
            hasBindingChecksum ? "binding_checksum" : nil
        ].compactMap { $0 })
    }

    func evolutionIntegrityFailedChecks(
        sovereignBridge: EvolutionSovereignBridgeProjection
    ) -> [String] {
        var failedChecks: [String] = []
        if sovereignBridge.quarantinedFoldRefs.isEmpty == false {
            failedChecks.append("contamination_scan")
        }
        return evolutionOrderedUnique(failedChecks)
    }

    func evolutionIntegrityCompletedChecks(
        requiredChecks: [String],
        failedChecks: [String]
    ) -> [String] {
        evolutionOrderedUnique(requiredChecks.filter { failedChecks.contains($0) == false })
    }

    func evolutionIntegrityContaminationRefs(
        sovereignBridge: EvolutionSovereignBridgeProjection
    ) -> [String] {
        evolutionOrderedUnique(
            sovereignBridge.quarantinedFoldRefs
            + sovereignBridge.invalidatedFoldRefs
            + sovereignBridge.invalidatedCacheRefs
        )
    }

    func evolutionIntegrityPurityState(
        sovereignBridge: EvolutionSovereignBridgeProjection,
        contaminationRefs: [String]
    ) -> String {
        if sovereignBridge.quarantinedFoldRefs.isEmpty == false {
            return "quarantined"
        }
        if sovereignBridge.invalidatedFoldRefs.isEmpty == false {
            return "recovered"
        }
        if contaminationRefs.isEmpty == false || sovereignBridge.preservedReadOnlyRecovery == true {
            return "sealed"
        }
        return "verified"
    }
}
