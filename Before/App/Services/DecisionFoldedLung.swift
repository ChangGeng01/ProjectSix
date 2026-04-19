import Foundation
import BASHostKit

private func decisionOrderedUniqueLines(_ values: [String]) -> [String] {
    values.reduce(into: [String]()) { uniqueValues, value in
        guard !uniqueValues.contains(value) else { return }
        uniqueValues.append(value)
    }
}

extension BASLungState {
    var decisionLungLine: String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            "Breath \(breathMode.rawValue)",
            "Phase \(breathPhase.rawValue)",
            "Restore \(Int((restoreReadiness * 100).rounded()))%"
        ])
    }
}

extension BASResumeFrame {
    var decisionResumeLine: String {
        let requiredOrganLine = requiredOrgans.isEmpty
            ? nil
            : "organs \(requiredOrgans.map { $0.rawValue }.joined(separator: ", "))"

        return DecisionEvolutionNarrativeFormattingSupport.joined([
            "Resume frame \(resumeID)",
            "source \(sourceFoldID)",
            "depth \(resumeDepth)",
            requiredOrganLine
        ].compactMap { $0 })
    }
}

extension BASRollbackAnchor {
    var decisionRollbackLine: String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            "Rollback anchor \(anchorID)",
            "snapshot \(safeSnapshotRef)",
            cacheStateRef.map { "cache \($0)" }
        ].compactMap { $0 })
    }
}

extension BASMorphGraph {
    var decisionMorphLine: String {
        let organSummary = activeOrgans.isEmpty
            ? nil
            : "organs \(activeOrgans.map(\.rawValue).joined(separator: ", "))"
        let primaryRoute = executionOrder.lazy.compactMap { deviceRouteMap[$0]?.evolutionTrimmedNonEmpty }.first
            ?? activeOrgans.lazy.compactMap { deviceRouteMap[$0.rawValue]?.evolutionTrimmedNonEmpty }.first
        let primaryThermal = thermalProfile.first?.evolutionTrimmedNonEmpty

        return DecisionEvolutionNarrativeFormattingSupport.joined([
            "Morph graph \(graphID)",
            organSummary,
            primaryRoute.map { "route \($0)" },
            primaryThermal.map { "thermal \($0)" }
        ].compactMap { $0 })
    }
}

extension BASHotColdMap {
    var decisionHotColdLine: String {
        let hotSummary = hotOrgans.isEmpty
            ? "none"
            : hotOrgans.map(\.rawValue).joined(separator: ", ")
        let warmSummary = warmOrgans.isEmpty
            ? "none"
            : warmOrgans.map(\.rawValue).joined(separator: ", ")

        return DecisionEvolutionNarrativeFormattingSupport.joined([
            "Hot pack \(hotSummary)",
            "Warm \(warmSummary)",
            "Cold \(coldOrgans.count)",
            "preload \(preloadPolicy)",
            "eviction \(evictionPolicy)"
        ])
    }
}

extension BASPrecisionProfile {
    var decisionPrecisionLine: String {
        let degradationSummary = degradationOrder.isEmpty
            ? nil
            : degradationOrder.map(\.rawValue).joined(separator: " -> ")
        let lockedSummary = lockedPrecisions.isEmpty
            ? nil
            : lockedPrecisions.map(\.rawValue).joined(separator: ", ")

        return DecisionEvolutionNarrativeFormattingSupport.joined([
            degradationSummary.map { "Precision profile \($0)" } ?? "Precision profile",
            "floor \(guardSafeFloor.rawValue)",
            lockedSummary.map { "locked \($0)" }
        ].compactMap { $0 })
    }
}

extension BASBreathSchedulerFrame {
    var decisionSchedulerLine: String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            "Breath scheduler \(cadenceTag)",
            "checkpoint \(checkpointCadence)",
            "micro-sleep \(microSleepWindowMs)ms",
            "maintenance \(backgroundMaintenanceWindowMs)ms",
            "resume \(resumeBudgetClass)"
        ])
    }
}

struct DecisionFoldedLungSnapshot: Equatable, Sendable {
    let morphGraph: BASMorphGraph
    let hotColdMap: BASHotColdMap
    let precisionProfile: BASPrecisionProfile
    let breathScheduler: BASBreathSchedulerFrame
    let resumeFrame: BASResumeFrame
    let rollbackAnchor: BASRollbackAnchor
    let lungState: BASLungState
    let sovereignBridgeResult: DecisionFoldedLungSovereignBridgeResult?

    var layerStackLine: String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            "L3 compression runtime",
            "breath \(lungState.breathMode.rawValue)",
            "phase \(lungState.breathPhase.rawValue)",
            "anchor \(rollbackAnchor.anchorID)"
        ])
    }

    var breathLine: String {
        lungState.decisionLungLine
    }

    var lungLine: String {
        breathLine
    }

    var morphLine: String {
        morphGraph.decisionMorphLine
    }

    var hotColdLine: String {
        hotColdMap.decisionHotColdLine
    }

    var precisionLine: String {
        precisionProfile.decisionPrecisionLine
    }

    var schedulerLine: String {
        breathScheduler.decisionSchedulerLine
    }

    var resumeLine: String {
        resumeFrame.decisionResumeLine
    }

    var rollbackLine: String {
        rollbackAnchor.decisionRollbackLine
    }

    var sovereignBridgeLine: String? {
        sovereignBridgeResult?.primaryLine
    }

    var sovereignBridgeDetailLines: [String] {
        sovereignBridgeResult?.detailLines ?? []
    }

    var sovereignBridgeSupplementalLines: [String] {
        sovereignBridgeResult?.supplementalLines ?? []
    }
}

struct DecisionFoldedLungSovereignBridgeResult: Codable, Equatable, Sendable {
    let actuationKinds: [BASSovereignActuationKind]
    let invalidatedResumeFrameIDs: [String]
    let invalidatedCacheRefs: [String]
    let invalidatedFoldRefs: [String]
    let quarantinedFoldRefs: [String]
    let resultingBreathMode: BASBreathMode
    let preservedReadOnlyRecovery: Bool
    let summary: String
}

extension DecisionFoldedLungSovereignBridgeResult {
    var primaryLine: String? {
        summary.evolutionTrimmedNonEmpty
    }

    var detailLines: [String] {
        decisionOrderedUniqueLines(
            [
                primaryLine,
                invalidatedResumeFrameIDs.isEmpty
                    ? nil
                    : "Sovereign invalidated resume \(invalidatedResumeFrameIDs.joined(separator: ", "))",
                invalidatedCacheRefs.isEmpty
                    ? nil
                    : "Sovereign invalidated cache \(invalidatedCacheRefs.joined(separator: ", "))",
                invalidatedFoldRefs.isEmpty
                    ? nil
                    : "Sovereign invalidated fold \(invalidatedFoldRefs.joined(separator: ", "))",
                quarantinedFoldRefs.isEmpty
                    ? nil
                    : "Sovereign quarantined fold \(quarantinedFoldRefs.joined(separator: ", "))",
                preservedReadOnlyRecovery ? "Sovereign readonly recovery" : nil,
                "Sovereign mode \(resultingBreathMode.rawValue)"
            ]
            .compactMap { $0?.evolutionTrimmedNonEmpty }
        )
    }

    var supplementalLines: [String] {
        let primaryLine = primaryLine
        return detailLines.filter { line in
            guard let primaryLine else { return true }
            return line != primaryLine
        }
    }
}

enum DecisionFoldedLungSovereignBridge {
    static func apply(
        commands: [BASSovereignActuationCommand],
        anchor: DecisionSessionCheckpointEBrainAnchor
    ) -> DecisionFoldedLungSovereignBridgeResult {
        let actuationKinds = commands.map(\.kind)
        let currentBreathMode = anchor.lungState?.breathMode
            ?? anchor.resumeFrame.map { _ in BASBreathMode.structured }
            ?? .light

        var invalidatedResumeFrameIDs: [String] = []
        var invalidatedCacheRefs: [String] = []
        var invalidatedFoldRefs: [String] = []
        var quarantinedFoldRefs: [String] = []
        var resultingBreathMode = currentBreathMode
        var preservedReadOnlyRecovery = false
        let resumeFrameID = anchor.resumeFrame?.resumeID.evolutionTrimmedNonEmpty
        let cacheStateRef = anchor.rollbackAnchor?.cacheStateRef?.evolutionTrimmedNonEmpty
        let foldRefs = anchor.rollbackAnchor?.foldRefs ?? []

        for command in commands {
            switch command.kind {
            case .toolCut:
                if let resumeFrameID {
                    invalidatedResumeFrameIDs.append(resumeFrameID)
                }
                if let sessionID = anchor.sessionID?.evolutionTrimmedNonEmpty {
                    invalidatedCacheRefs.append("tool-intent:\(sessionID)")
                }
            case .memoryFreeze:
                preservedReadOnlyRecovery = true
                if let sessionID = anchor.sessionID?.evolutionTrimmedNonEmpty {
                    invalidatedCacheRefs.append("memory-write:\(sessionID)")
                }
            case .quarantine:
                resultingBreathMode = .quarantine
                preservedReadOnlyRecovery = true
                if let resumeFrameID {
                    invalidatedResumeFrameIDs.append(resumeFrameID)
                }
                if let cacheStateRef {
                    invalidatedCacheRefs.append(cacheStateRef)
                }
                quarantinedFoldRefs.append(contentsOf: foldRefs)
            case .rollback:
                preservedReadOnlyRecovery = true
                resultingBreathMode = command.forcedMode.map(DecisionFoldedLungCoordinator.breathMode(from:)) ?? .guard
                if let resumeFrameID {
                    invalidatedResumeFrameIDs.append(resumeFrameID)
                }
                if let cacheStateRef {
                    invalidatedCacheRefs.append(cacheStateRef)
                }
                invalidatedFoldRefs.append(contentsOf: foldRefs)
            case .deadStop:
                preservedReadOnlyRecovery = true
                resultingBreathMode = .lockdown
                if let resumeFrameID {
                    invalidatedResumeFrameIDs.append(resumeFrameID)
                }
                if let cacheStateRef {
                    invalidatedCacheRefs.append(cacheStateRef)
                }
                invalidatedFoldRefs.append(contentsOf: foldRefs)
            case .guardShift:
                resultingBreathMode = .guard
            case .throttle:
                resultingBreathMode = throttledBreathMode(resultingBreathMode)
            case .shadowLock:
                preservedReadOnlyRecovery = true
            }
        }

        invalidatedResumeFrameIDs = orderedUnique(invalidatedResumeFrameIDs)
        // Keep cache invalidation receipts stable across command ordering so folds
        // replay and tests compare the same canonical summary.
        invalidatedCacheRefs = orderedUnique(invalidatedCacheRefs).sorted()
        invalidatedFoldRefs = orderedUnique(invalidatedFoldRefs)
        quarantinedFoldRefs = orderedUnique(quarantinedFoldRefs)

        let summary = DecisionEvolutionNarrativeFormattingSupport.joined([
            "Sovereign bridge",
            actuationKinds.isEmpty ? nil : actuationKinds.map(\.rawValue).joined(separator: ", "),
            invalidatedResumeFrameIDs.isEmpty ? nil : "resume \(invalidatedResumeFrameIDs.joined(separator: ", "))",
            invalidatedCacheRefs.isEmpty ? nil : "cache \(invalidatedCacheRefs.joined(separator: ", "))",
            invalidatedFoldRefs.isEmpty ? nil : "fold \(invalidatedFoldRefs.joined(separator: ", "))",
            quarantinedFoldRefs.isEmpty ? nil : "quarantine \(quarantinedFoldRefs.joined(separator: ", "))",
            preservedReadOnlyRecovery ? "readonly recovery" : nil,
            "mode \(resultingBreathMode.rawValue)"
        ].compactMap { $0 })

        return DecisionFoldedLungSovereignBridgeResult(
            actuationKinds: actuationKinds,
            invalidatedResumeFrameIDs: invalidatedResumeFrameIDs,
            invalidatedCacheRefs: invalidatedCacheRefs,
            invalidatedFoldRefs: invalidatedFoldRefs,
            quarantinedFoldRefs: quarantinedFoldRefs,
            resultingBreathMode: resultingBreathMode,
            preservedReadOnlyRecovery: preservedReadOnlyRecovery,
            summary: summary
        )
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        values.reduce(into: [String]()) { uniqueValues, value in
            guard !uniqueValues.contains(value) else { return }
            uniqueValues.append(value)
        }
    }
}

enum DecisionFoldedLungCoordinator {
    static func snapshot(
        for turn: BASEBrainTurnResult
    ) -> DecisionFoldedLungSnapshot {
        let breathMode = breathMode(for: turn)
        let resumeFrameID = turn.thoughtFold.resumeFrameRef?.evolutionTrimmedNonEmpty
            ?? "resume.\(turn.runtimeTrace.sessionID).\(turn.thoughtFold.foldID)"
        let rollbackAnchorID = turn.thoughtFold.rollbackAnchorRef?.evolutionTrimmedNonEmpty
            ?? "rollback.\(turn.runtimeTrace.sessionID).\(turn.thoughtFold.foldID)"
        let morphGraphID = turn.thoughtFold.morphGraphRef?.evolutionTrimmedNonEmpty
            ?? "morph.\(turn.runtimeTrace.sessionID).\(turn.thoughtFold.foldID)"
        let precisionProfileID = turn.thoughtFold.precisionProfileRef?.evolutionTrimmedNonEmpty
            ?? "precision.\(turn.runtimeTrace.sessionID).\(turn.thoughtFold.foldID)"
        let breathSchedulerID = turn.thoughtFold.breathSchedulerRef?.evolutionTrimmedNonEmpty
            ?? "scheduler.\(turn.runtimeTrace.sessionID).\(turn.thoughtFold.foldID)"

        let organMap = turn.thoughtFrame.organMap
        let activeOrgans = organMap?.activeOrgans ?? [.stubCore]
        let organPrecisionMap = organMap?.precisionMap.isEmpty == false
            ? (organMap?.precisionMap ?? [])
            : fallbackPrecisionMap(
                for: activeOrgans,
                budgetPrecisionProfile: turn.budgetFrame.precisionProfile,
                breathMode: breathMode,
                thermalGuardLevel: turn.budgetFrame.thermalGuardLevel
            )
        let lockedOrgans = orderedUnique(
            organPrecisionMap.compactMap { precision in
                switch precision.organ {
                case .riskSpine, .permitKnot, .stubCore:
                    return precision.organ
                default:
                    return nil
                }
            }
        )

        let morphGraph = BASMorphGraph(
            graphID: morphGraphID,
            activeOrgans: activeOrgans,
            executionOrder: activeOrgans.map(\.rawValue),
            precisionMap: organPrecisionMap,
            deviceRouteMap: Dictionary(uniqueKeysWithValues: activeOrgans.map { ($0.rawValue, turn.budgetFrame.deviceRoute.rawValue) }),
            thermalProfile: [
                "thermal.\(turn.deviceState.thermalLevel.rawValue)",
                "guard.\(turn.budgetFrame.thermalGuardLevel.rawValue)",
                "latency.\(turn.deviceState.latencyBudgetMs)",
                "cache.\(Int((turn.runtimeTrace.cacheHitRate * 100).rounded()))",
                "precision.\(turn.budgetFrame.precisionProfile.rawValue)"
            ],
            sovereignConstraints: organMap?.sovereignConstraints ?? turn.sovereignActuationCommands.map(\.kind.rawValue)
        )

        let precisionProfile = BASPrecisionProfile(
            organPrecisions: organPrecisionMap,
            lockedPrecisions: lockedOrgans,
            degradationOrder: degradationOrder(for: turn.budgetFrame.precisionProfile),
            guardSafeFloor: guardSafeFloor(
                budgetPrecisionProfile: turn.budgetFrame.precisionProfile,
                breathMode: breathMode
            )
        )

        let resumeFrame = BASResumeFrame(
            resumeID: resumeFrameID,
            sourceFoldID: turn.thoughtFold.foldID,
            resumeDepth: max(turn.runtimeTrace.loopCount, turn.budgetFrame.maxLoops > 1 ? 1 : 0),
            requiredOrgans: activeOrgans,
            consistencyChecks: orderedUnique([
                "fold_checksum",
                turn.thoughtFrame.riskBindings?.isEmpty == false ? "risk_permit" : nil,
                "host_gate",
                turn.thoughtFold.bindingChecksum == nil ? nil : "binding_checksum"
            ].compactMap { $0 }),
            fallbackMode: breathMode == .lockdown ? .lockdownShell : .rollbackAnchor
        )

        let rollbackAnchor = BASRollbackAnchor(
            anchorID: rollbackAnchorID,
            safeSnapshotRef: turn.thoughtFold.snapshotRef?.evolutionTrimmedNonEmpty
                ?? "snapshot.\(turn.runtimeTrace.sessionID).\(turn.thoughtFold.foldID)",
            foldRefs: orderedUnique([turn.thoughtFold.foldID]),
            hostVersionRef: turn.hostContext.activeVersion,
            cacheStateRef: "cache.\(turn.runtimeTrace.sessionID).\(precisionProfileID)",
            integrityHash: turn.thoughtFold.checksum
        )

        let lungState = BASLungState(
            breathMode: breathMode,
            breathPhase: breathPhase(for: turn),
            thermalPressure: thermalPressure(for: turn),
            cachePressure: cachePressure(for: turn),
            restoreReadiness: restoreReadiness(for: turn),
            rollbackAnchorRef: rollbackAnchor.anchorID
        )
        let initialHotColdMap = hotColdMap(
            breathMode: lungState.breathMode,
            activeOrgans: activeOrgans
        )
        let initialBreathScheduler = breathScheduler(
            schedulerID: breathSchedulerID,
            breathMode: lungState.breathMode,
            breathPhase: lungState.breathPhase,
            budgetFrame: turn.budgetFrame,
            thermalPressure: lungState.thermalPressure,
            restoreReadiness: lungState.restoreReadiness,
            loopCount: turn.runtimeTrace.loopCount,
            recoveryKind: turn.recoveryDisposition?.kind.rawValue
        )

        let anchor = DecisionSessionCheckpointEBrainAnchor(
            sessionID: turn.runtimeTrace.sessionID,
            thoughtFoldChecksum: String(turn.thoughtFold.checksum.prefix(12)),
            riskLevel: turn.riskCard.riskLevel.rawValue,
            permitMode: turn.actionPermit.mode.rawValue,
            hostGatePercent: Int((turn.hostGateValue * 100).rounded()),
            reviewDirectiveLine: turn.primaryReviewDirectiveLine,
            morphGraph: morphGraph,
            hotColdMap: initialHotColdMap,
            precisionProfile: precisionProfile,
            lungState: lungState,
            breathScheduler: initialBreathScheduler,
            resumeFrame: resumeFrame,
            rollbackAnchor: rollbackAnchor
        )
        let sovereignBridgeResult = turn.sovereignActuationCommands.isEmpty
            ? nil
            : DecisionFoldedLungSovereignBridge.apply(
                commands: turn.sovereignActuationCommands,
                anchor: anchor
            )
        let effectiveLungState = sovereignBridgeResult.map {
            BASLungState(
                breathMode: $0.resultingBreathMode,
                breathPhase: lungState.breathPhase,
                thermalPressure: lungState.thermalPressure,
                cachePressure: lungState.cachePressure,
                restoreReadiness: lungState.restoreReadiness,
                rollbackAnchorRef: lungState.rollbackAnchorRef
            )
        } ?? lungState

        return DecisionFoldedLungSnapshot(
            morphGraph: morphGraph,
            hotColdMap: hotColdMap(
                breathMode: effectiveLungState.breathMode,
                activeOrgans: activeOrgans
            ),
            precisionProfile: precisionProfile,
            breathScheduler: breathScheduler(
                schedulerID: breathSchedulerID,
                breathMode: effectiveLungState.breathMode,
                breathPhase: effectiveLungState.breathPhase,
                budgetFrame: turn.budgetFrame,
                thermalPressure: effectiveLungState.thermalPressure,
                restoreReadiness: effectiveLungState.restoreReadiness,
                loopCount: turn.runtimeTrace.loopCount,
                recoveryKind: turn.recoveryDisposition?.kind.rawValue
            ),
            resumeFrame: resumeFrame,
            rollbackAnchor: rollbackAnchor,
            lungState: effectiveLungState,
            sovereignBridgeResult: sovereignBridgeResult
        )
    }

    static func breathMode(from runMode: BASEBrainRunMode) -> BASBreathMode {
        switch runMode {
        case .dormant, .pulse, .sentinel:
            .light
        case .engage, .reflect:
            .structured
        case .deepLoop, .recovery:
            .deepExchange
        case .guard:
            .guard
        case .quarantine:
            .quarantine
        case .lockdown:
            .lockdown
        }
    }

    static func snapshot(
        from anchor: DecisionSessionCheckpointEBrainAnchor
    ) -> DecisionFoldedLungSnapshot? {
        guard
            let lungState = anchor.lungState,
            let resumeFrame = anchor.resumeFrame,
            let rollbackAnchor = anchor.rollbackAnchor
        else {
            return nil
        }

        let organs = resumeFrame.requiredOrgans.isEmpty ? [.stubCore] : resumeFrame.requiredOrgans
        let precisionMap = anchor.precisionProfile?.organPrecisions ?? organs.map { organ in
            BASNeuralOrganPrecision(
                organ: organ,
                tier: organ == .stubCore ? .full : lungState.breathMode == .guard ? .protected : .balanced
            )
        }

        return DecisionFoldedLungSnapshot(
            morphGraph: anchor.morphGraph ?? BASMorphGraph(
                graphID: "morph.\(anchor.sessionID ?? "checkpoint").\(resumeFrame.sourceFoldID)",
                activeOrgans: organs,
                executionOrder: organs.map(\.rawValue),
                precisionMap: precisionMap,
                deviceRouteMap: Dictionary(uniqueKeysWithValues: organs.map { ($0.rawValue, "checkpoint") }),
                thermalProfile: ["checkpoint-recovery"],
                sovereignConstraints: []
            ),
            hotColdMap: anchor.hotColdMap ?? hotColdMap(
                breathMode: lungState.breathMode,
                activeOrgans: organs
            ),
            precisionProfile: anchor.precisionProfile ?? BASPrecisionProfile(
                organPrecisions: precisionMap,
                lockedPrecisions: organs.filter { $0 == .riskSpine || $0 == .permitKnot || $0 == .stubCore },
                degradationOrder: [.full, .protected, .balanced, .minimal],
                guardSafeFloor: lungState.breathMode == .guard ? .protected : .balanced
            ),
            breathScheduler: anchor.breathScheduler ?? breathScheduler(
                schedulerID: "scheduler.\(anchor.sessionID ?? "checkpoint").\(resumeFrame.sourceFoldID)",
                breathMode: lungState.breathMode,
                breathPhase: lungState.breathPhase,
                budgetFrame: .guardedLocal(),
                thermalPressure: lungState.thermalPressure,
                restoreReadiness: lungState.restoreReadiness,
                loopCount: resumeFrame.resumeDepth,
                recoveryKind: "checkpoint_restore"
            ),
            resumeFrame: resumeFrame,
            rollbackAnchor: rollbackAnchor,
            lungState: lungState,
            sovereignBridgeResult: anchor.sovereignBridgeResult
        )
    }

    private static func breathMode(
        for turn: BASEBrainTurnResult
    ) -> BASBreathMode {
        if turn.sovereignActuationCommands.contains(where: { $0.kind == .deadStop })
            || turn.emergencyBrake.brakeLevel == .lockdown
            || turn.budgetFrame.runMode == .lockdown {
            return .lockdown
        }

        if turn.sovereignActuationCommands.contains(where: { $0.kind == .quarantine })
            || turn.recoveryDisposition?.kind == .quarantine
            || turn.budgetFrame.runMode == .quarantine {
            return .quarantine
        }

        if turn.actionPermit.mode.isProtective
            || turn.budgetFrame.runMode == .guard
            || turn.sovereignActuationCommands.contains(where: { $0.kind == .guardShift }) {
            return .guard
        }

        if turn.budgetFrame.runMode == .deepLoop
            || turn.thoughtFrame.candidates.count > 1
            || turn.runtimeTrace.loopCount > 1 {
            return .deepExchange
        }

        if turn.contextFrame.taskType == .choice
            || turn.contextFrame.taskType == .conflict
            || turn.thoughtFrame.candidateFrontier?.frontierWidth ?? 0 > 0 {
            return .structured
        }

        return .light
    }

    private static func hotColdMap(
        breathMode: BASBreathMode,
        activeOrgans: [BASNeuralOrgan]
    ) -> BASHotColdMap {
        let hotPriority = hotPriority(for: breathMode)
        let warmPriority = warmPriority(for: breathMode)
        let hotOrgans = orderedUnique(
            hotPriority.filter { activeOrgans.contains($0) }
                + (activeOrgans.contains(.stubCore) ? [.stubCore] : [])
        )
        let normalizedHotOrgans = hotOrgans.isEmpty ? [.stubCore] : hotOrgans
        let warmOrgans = orderedUnique(
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
            preloadPolicy: preloadPolicy(for: breathMode),
            evictionPolicy: evictionPolicy(for: breathMode)
        )
    }

    private static func hotPriority(
        for breathMode: BASBreathMode
    ) -> [BASNeuralOrgan] {
        switch breathMode {
        case .guard:
            return [.stubCore, .riskSpine, .permitKnot, .consistencyLattice]
        case .quarantine:
            return [.stubCore, .riskSpine, .permitKnot, .consistencyLattice, .tissueRouter]
        case .lockdown:
            return [.stubCore, .riskSpine, .permitKnot]
        case .deepExchange:
            return [.stubCore, .coreCortex, .riskSpine, .permitKnot, .simuRing, .criticBlade]
        case .structured:
            return [.stubCore, .coreCortex, .riskSpine, .permitKnot]
        case .light:
            return [.stubCore, .scoutStrip, .coreCortex]
        }
    }

    private static func warmPriority(
        for breathMode: BASBreathMode
    ) -> [BASNeuralOrgan] {
        switch breathMode {
        case .guard:
            return [.memoryCodecRidge, .hostModulationMesh, .toolIntentMesh]
        case .quarantine:
            return [.memoryCodecRidge, .hostModulationMesh]
        case .lockdown:
            return [.memoryCodecRidge]
        case .deepExchange:
            return [.consistencyLattice, .memoryCodecRidge, .hostModulationMesh, .toolIntentMesh]
        case .structured:
            return [.simuRing, .criticBlade, .consistencyLattice, .memoryCodecRidge]
        case .light:
            return [.riskSpine, .permitKnot, .memoryCodecRidge]
        }
    }

    private static func preloadPolicy(
        for breathMode: BASBreathMode
    ) -> String {
        switch breathMode {
        case .guard:
            return "guard_preload"
        case .quarantine:
            return "quarantine_rehydrate"
        case .lockdown:
            return "lockdown_stub_only"
        case .deepExchange:
            return "deep_exchange_prefetch"
        case .structured:
            return "structured_preload"
        case .light:
            return "light_preload"
        }
    }

    private static func evictionPolicy(
        for breathMode: BASBreathMode
    ) -> String {
        switch breathMode {
        case .guard:
            return "protective_retain"
        case .quarantine:
            return "quarantine_protective"
        case .lockdown:
            return "lockdown_evict_all"
        case .deepExchange:
            return "thermal_trim"
        case .structured:
            return "balanced_trim"
        case .light:
            return "latency_bias"
        }
    }

    private static func breathPhase(
        for turn: BASEBrainTurnResult
    ) -> BASBreathPhase {
        if turn.sovereignActuationCommands.contains(where: { $0.kind == .rollback })
            || turn.budgetFrame.runMode == .recovery {
            return .resume
        }

        if turn.budgetFrame.runMode == .lockdown
            || turn.sovereignActuationCommands.contains(where: { $0.kind == .deadStop }) {
            return .rest
        }

        if turn.runtimeTrace.loopCount > 0
            || turn.actionPermit.mode.isProtective
            || turn.runtimeTrace.guardrailFindings.isEmpty == false {
            return .exchange
        }

        return .inhale
    }

    private static func thermalPressure(
        for turn: BASEBrainTurnResult
    ) -> Int {
        let thermalBase = switch turn.deviceState.thermalLevel {
        case .nominal: 20
        case .warm: 55
        case .hot: 78
        case .critical: 92
        }
        let loadPressure = Int((max(turn.deviceState.cpuLoad, turn.deviceState.gpuLoad) * 25).rounded())
        return min(100, thermalBase + loadPressure)
    }

    private static func cachePressure(
        for turn: BASEBrainTurnResult
    ) -> Int {
        let cacheRelief = Int((turn.runtimeTrace.cacheHitRate * 100).rounded())
        let ticketPressure = min(turn.updateTickets.count * 8, 24)
        return max(0, min(100, 100 - cacheRelief + ticketPressure))
    }

    private static func restoreReadiness(
        for turn: BASEBrainTurnResult
    ) -> Double {
        let stability = turn.vitalState.stabilityScore
        let continuity = turn.vitalState.continuityScore
        return min(max((stability + continuity) / 2.0, 0), 1)
    }

    private static func fallbackPrecisionMap(
        for activeOrgans: [BASNeuralOrgan],
        budgetPrecisionProfile: BASRuntimePrecisionProfile,
        breathMode: BASBreathMode,
        thermalGuardLevel: BASThermalGuardLevel
    ) -> [BASNeuralOrganPrecision] {
        activeOrgans.map { organ in
            BASNeuralOrganPrecision(
                organ: organ,
                tier: fallbackPrecisionTier(
                    for: organ,
                    budgetPrecisionProfile: budgetPrecisionProfile,
                    breathMode: breathMode,
                    thermalGuardLevel: thermalGuardLevel
                )
            )
        }
    }

    private static func fallbackPrecisionTier(
        for organ: BASNeuralOrgan,
        budgetPrecisionProfile: BASRuntimePrecisionProfile,
        breathMode: BASBreathMode,
        thermalGuardLevel: BASThermalGuardLevel
    ) -> BASNeuralPrecisionTier {
        switch organ {
        case .stubCore:
            return .full
        case .riskSpine, .permitKnot:
            return budgetPrecisionProfile == .full ? .full : .protected
        case .tissueRouter, .consistencyLattice:
            return breathMode == .guard || breathMode == .quarantine || breathMode == .lockdown ? .protected : .balanced
        case .simuRing, .criticBlade:
            return breathMode == .deepExchange ? .protected : .balanced
        case .hostModulationMesh, .memoryCodecRidge:
            return .balanced
        case .toolIntentMesh:
            return breathMode == .deepExchange ? .balanced : .minimal
        case .scoutStrip:
            return .minimal
        case .coreCortex:
            switch thermalGuardLevel {
            case .emergency:
                return .minimal
            case .throttle:
                return budgetPrecisionProfile == .full ? .protected : .balanced
            case .nominal, .watch:
                switch budgetPrecisionProfile {
                case .minimal:
                    return .minimal
                case .balanced:
                    return .balanced
                case .protected:
                    return .protected
                case .full:
                    return .full
                }
            }
        }
    }

    private static func degradationOrder(
        for precisionProfile: BASRuntimePrecisionProfile
    ) -> [BASNeuralPrecisionTier] {
        switch precisionProfile {
        case .minimal:
            return [.minimal, .balanced, .protected, .full]
        case .balanced:
            return [.balanced, .protected, .minimal, .full]
        case .protected:
            return [.protected, .balanced, .minimal, .full]
        case .full:
            return [.full, .protected, .balanced, .minimal]
        }
    }

    private static func guardSafeFloor(
        budgetPrecisionProfile: BASRuntimePrecisionProfile,
        breathMode: BASBreathMode
    ) -> BASNeuralPrecisionTier {
        if breathMode == .guard || breathMode == .quarantine || breathMode == .lockdown {
            return .protected
        }

        switch budgetPrecisionProfile {
        case .minimal:
            return .minimal
        case .balanced:
            return .balanced
        case .protected, .full:
            return .protected
        }
    }

    private static func breathScheduler(
        schedulerID: String,
        breathMode: BASBreathMode,
        breathPhase: BASBreathPhase,
        budgetFrame: BASBudgetFrame,
        thermalPressure: Int,
        restoreReadiness: Double,
        loopCount: Int,
        recoveryKind: String?
    ) -> BASBreathSchedulerFrame {
        let cadenceTag = schedulerCadenceTag(
            for: breathMode,
            breathPhase: breathPhase,
            thermalPressure: thermalPressure
        )
        let checkpointCadence = checkpointCadence(
            for: breathMode,
            breathPhase: breathPhase
        )
        let allowsBackgroundMaintenance = budgetFrame.maintenanceAllowed
            && breathMode != .quarantine
            && breathMode != .lockdown
        let allowsMicroSleep = breathMode != .lockdown
        let microSleepWindowMs = allowsMicroSleep
            ? microSleepWindowMs(
                for: breathMode,
                breathPhase: breathPhase,
                restoreReadiness: restoreReadiness,
                loopCount: loopCount
            )
            : 0
        let backgroundMaintenanceWindowMs = allowsBackgroundMaintenance
            ? maintenanceWindowMs(for: budgetFrame.maintenanceClass, breathMode: breathMode)
            : 0

        return BASBreathSchedulerFrame(
            schedulerID: schedulerID,
            cadenceTag: cadenceTag,
            checkpointCadence: checkpointCadence,
            microSleepWindowMs: microSleepWindowMs,
            backgroundMaintenanceWindowMs: backgroundMaintenanceWindowMs,
            allowsBackgroundMaintenance: allowsBackgroundMaintenance,
            allowsMicroSleep: allowsMicroSleep,
            resumeBudgetClass: resumeBudgetClass(for: breathMode, breathPhase: breathPhase),
            schedulerReasonCodes: orderedUnique([
                "mode.\(breathMode.rawValue)",
                "phase.\(breathPhase.rawValue)",
                "thermal.\(budgetFrame.thermalGuardLevel.rawValue)",
                budgetFrame.maintenanceAllowed ? "maintenance.\(budgetFrame.maintenanceClass.rawValue)" : nil,
                loopCount > 1 ? "loop.multi" : nil,
                recoveryKind?.evolutionTrimmedNonEmpty
            ].compactMap { $0 })
        )
    }

    private static func schedulerCadenceTag(
        for breathMode: BASBreathMode,
        breathPhase: BASBreathPhase,
        thermalPressure: Int
    ) -> String {
        switch breathMode {
        case .guard:
            return breathPhase == .resume ? "guard_resume" : "guard_exchange"
        case .quarantine:
            return "quarantine_hold"
        case .lockdown:
            return "lockdown_shell"
        case .deepExchange:
            return thermalPressure >= 80 ? "deep_exchange_throttled" : "deep_exchange"
        case .structured:
            return breathPhase == .resume ? "structured_resume" : "structured_cycle"
        case .light:
            return "light_pulse"
        }
    }

    private static func checkpointCadence(
        for breathMode: BASBreathMode,
        breathPhase: BASBreathPhase
    ) -> String {
        switch breathMode {
        case .guard:
            return "anchor_each_turn"
        case .quarantine:
            return "anchor_before_resume"
        case .lockdown:
            return "anchor_on_state_change"
        case .deepExchange:
            return breathPhase == .resume ? "anchor_on_restore" : "anchor_before_rest"
        case .structured:
            return "anchor_on_yield"
        case .light:
            return "anchor_on_idle"
        }
    }

    private static func microSleepWindowMs(
        for breathMode: BASBreathMode,
        breathPhase: BASBreathPhase,
        restoreReadiness: Double,
        loopCount: Int
    ) -> Int {
        let readinessBonus = Int((restoreReadiness * 80).rounded())
        let loopPenalty = min(loopCount * 30, 90)

        switch breathMode {
        case .guard:
            return max(120, 160 + readinessBonus - loopPenalty)
        case .quarantine:
            return max(60, 90 + readinessBonus / 2 - loopPenalty)
        case .lockdown:
            return 0
        case .deepExchange:
            return breathPhase == .resume
                ? max(100, 180 + readinessBonus - loopPenalty)
                : max(80, 140 + readinessBonus - loopPenalty)
        case .structured:
            return max(140, 220 + readinessBonus - loopPenalty)
        case .light:
            return max(180, 260 + readinessBonus - loopPenalty)
        }
    }

    private static func maintenanceWindowMs(
        for maintenanceClass: BASMaintenanceClass,
        breathMode: BASBreathMode
    ) -> Int {
        let baseWindow = switch maintenanceClass {
        case .none: 0
        case .light: 80
        case .standard: 160
        case .deferred: 240
        }

        switch breathMode {
        case .guard:
            return min(baseWindow, 60)
        case .quarantine, .lockdown:
            return 0
        case .deepExchange:
            return max(0, baseWindow - 40)
        case .structured:
            return baseWindow
        case .light:
            return baseWindow + 40
        }
    }

    private static func resumeBudgetClass(
        for breathMode: BASBreathMode,
        breathPhase: BASBreathPhase
    ) -> String {
        switch breathMode {
        case .guard:
            return "rollback_hot"
        case .quarantine:
            return "readonly_quarantine"
        case .lockdown:
            return "lockdown_shell"
        case .deepExchange:
            return breathPhase == .resume ? "deep_resume_hot" : "deep_exchange_warm"
        case .structured:
            return "guarded_hot"
        case .light:
            return "light_hot"
        }
    }

    private static func orderedUnique<T: Hashable>(
        _ values: [T]
    ) -> [T] {
        values.reduce(into: [T]()) { uniqueValues, value in
            guard !uniqueValues.contains(value) else { return }
            uniqueValues.append(value)
        }
    }
}

private func maxBreathMode(_ lhs: BASBreathMode, _ rhs: BASBreathMode) -> BASBreathMode {
    let order: [BASBreathMode] = [.light, .structured, .deepExchange, .guard, .quarantine, .lockdown]
    let lhsIndex = order.firstIndex(of: lhs) ?? 0
    let rhsIndex = order.firstIndex(of: rhs) ?? 0
    return lhsIndex >= rhsIndex ? lhs : rhs
}

private func throttledBreathMode(_ current: BASBreathMode) -> BASBreathMode {
    switch current {
    case .deepExchange:
        return .structured
    case .guard, .quarantine, .lockdown:
        return current
    case .light, .structured:
        return current
    }
}
