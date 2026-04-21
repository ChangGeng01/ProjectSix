import Foundation
import BASHostKit
import BASOrchestration

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

extension Array where Element == BASOrganPackage {
    func decisionOrganPackageIDs(
        matching predicate: (BASOrganPackage) -> Bool
    ) -> [String] {
        filter(predicate).map(\.packageID)
    }

    var decisionOrganPackageLine: String? {
        guard isEmpty == false else {
            return nil
        }

        let hotCount = decisionOrganPackageIDs { $0.packageID.hasSuffix(".hot") }.count
        let warmCount = decisionOrganPackageIDs { $0.packageID.hasSuffix(".warm") }.count
        let coldCount = decisionOrganPackageIDs { $0.packageID.hasSuffix(".cold") }.count
        let protectedCount = decisionOrganPackageIDs { $0.sovereignClass == "protected_core" }.count
        let recoveryCount = decisionOrganPackageIDs { $0.sovereignClass == "checkpoint_recovery" }.count

        return DecisionEvolutionNarrativeFormattingSupport.joined([
            "Organ packages \(count)",
            "hot \(hotCount)",
            "warm \(warmCount)",
            "cold \(coldCount)",
            protectedCount > 0 ? "protected \(protectedCount)" : nil,
            recoveryCount > 0 ? "recovery \(recoveryCount)" : nil
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

extension BASThermalExchangeFrame {
    var decisionThermalExchangeLine: String {
        let suppressionSummary = suppressedOrgans.isEmpty
            ? nil
            : "suppress \(suppressedOrgans.map(\.rawValue).joined(separator: ", "))"
        let rerouteSummary = rerouteTargets.isEmpty
            ? nil
            : "reroute \(rerouteTargets.map { "\($0.key)->\($0.value)" }.sorted().joined(separator: ", "))"

        return DecisionEvolutionNarrativeFormattingSupport.joined([
            "Thermal exchanger \(exchangeMode)",
            "band \(predictedThermalBand)",
            coolingActions.isEmpty ? nil : "actions \(coolingActions.joined(separator: ", "))",
            suppressionSummary,
            rerouteSummary
        ].compactMap { $0 })
    }
}

extension BASIntegrityWeaveFrame {
    var decisionIntegrityWeaveLine: String {
        let totalChecks = requiredChecks.count
        let completedCount = completedChecks.count
        let contaminationSummary = contaminationRefs.isEmpty
            ? nil
            : "contamination \(contaminationRefs.count)"
        let shortHash = verificationHash.evolutionTrimmedNonEmpty.map { String($0.prefix(12)) }

        return DecisionEvolutionNarrativeFormattingSupport.joined([
            "Integrity weave \(purityState)",
            totalChecks > 0 ? "checks \(completedCount)/\(totalChecks)" : nil,
            contaminationSummary,
            shortHash.map { "hash \($0)" }
        ].compactMap { $0 })
    }
}

extension BASOrganDeltaPlan {
    var decisionOrganDeltaLine: String {
        let activateSummary = activatePackageIDs.isEmpty
            ? nil
            : "activate \(activatePackageIDs.joined(separator: ", "))"
        let preloadSummary = preloadPackageIDs.isEmpty
            ? nil
            : "preload \(preloadPackageIDs.joined(separator: ", "))"
        let evictSummary = evictPackageIDs.isEmpty
            ? nil
            : "evict \(evictPackageIDs.joined(separator: ", "))"
        let retainSummary = rollbackSafeRetainedPackageIDs.isEmpty
            ? nil
            : "rollback-safe \(rollbackSafeRetainedPackageIDs.joined(separator: ", "))"

        return DecisionEvolutionNarrativeFormattingSupport.joined([
            "Organ delta \(deltaMode)",
            activateSummary,
            preloadSummary,
            evictSummary,
            retainSummary,
            triggeredActuationKinds.isEmpty ? nil : "sovereign \(triggeredActuationKinds.map(\.rawValue).joined(separator: ", "))"
        ].compactMap { $0 })
    }
}

struct DecisionFoldedLungSnapshot: Equatable, Sendable {
    let morphGraph: BASMorphGraph
    let hotColdMap: BASHotColdMap
    let precisionProfile: BASPrecisionProfile
    let thermalExchange: BASThermalExchangeFrame
    let breathScheduler: BASBreathSchedulerFrame
    let integrityWeave: BASIntegrityWeaveFrame
    let organPackages: [BASOrganPackage]
    let organDeltaPlan: BASOrganDeltaPlan
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

    var organPackageLine: String? {
        organPackages.decisionOrganPackageLine
    }

    var thermalExchangeLine: String {
        thermalExchange.decisionThermalExchangeLine
    }

    var schedulerLine: String {
        breathScheduler.decisionSchedulerLine
    }

    var integrityWeaveLine: String {
        integrityWeave.decisionIntegrityWeaveLine
    }

    var organDeltaLine: String {
        organDeltaPlan.decisionOrganDeltaLine
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
    let invalidatedPackageIDs: [String]
    let quarantinedFoldRefs: [String]
    let quarantinedPackageIDs: [String]
    let rollbackRetainedPackageIDs: [String]
    let minimalHotPackageIDs: [String]
    let resultingBreathMode: BASBreathMode
    let preservedReadOnlyRecovery: Bool
    let summary: String

    private enum CodingKeys: String, CodingKey {
        case actuationKinds
        case invalidatedResumeFrameIDs
        case invalidatedCacheRefs
        case invalidatedFoldRefs
        case invalidatedPackageIDs
        case quarantinedFoldRefs
        case quarantinedPackageIDs
        case rollbackRetainedPackageIDs
        case minimalHotPackageIDs
        case resultingBreathMode
        case preservedReadOnlyRecovery
        case summary
    }

    init(
        actuationKinds: [BASSovereignActuationKind],
        invalidatedResumeFrameIDs: [String],
        invalidatedCacheRefs: [String],
        invalidatedFoldRefs: [String],
        invalidatedPackageIDs: [String] = [],
        quarantinedFoldRefs: [String],
        quarantinedPackageIDs: [String] = [],
        rollbackRetainedPackageIDs: [String] = [],
        minimalHotPackageIDs: [String] = [],
        resultingBreathMode: BASBreathMode,
        preservedReadOnlyRecovery: Bool,
        summary: String
    ) {
        self.actuationKinds = actuationKinds
        self.invalidatedResumeFrameIDs = invalidatedResumeFrameIDs
        self.invalidatedCacheRefs = invalidatedCacheRefs
        self.invalidatedFoldRefs = invalidatedFoldRefs
        self.invalidatedPackageIDs = invalidatedPackageIDs
        self.quarantinedFoldRefs = quarantinedFoldRefs
        self.quarantinedPackageIDs = quarantinedPackageIDs
        self.rollbackRetainedPackageIDs = rollbackRetainedPackageIDs
        self.minimalHotPackageIDs = minimalHotPackageIDs
        self.resultingBreathMode = resultingBreathMode
        self.preservedReadOnlyRecovery = preservedReadOnlyRecovery
        self.summary = summary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            actuationKinds: try container.decode([BASSovereignActuationKind].self, forKey: .actuationKinds),
            invalidatedResumeFrameIDs: try container.decodeIfPresent([String].self, forKey: .invalidatedResumeFrameIDs) ?? [],
            invalidatedCacheRefs: try container.decodeIfPresent([String].self, forKey: .invalidatedCacheRefs) ?? [],
            invalidatedFoldRefs: try container.decodeIfPresent([String].self, forKey: .invalidatedFoldRefs) ?? [],
            invalidatedPackageIDs: try container.decodeIfPresent([String].self, forKey: .invalidatedPackageIDs) ?? [],
            quarantinedFoldRefs: try container.decodeIfPresent([String].self, forKey: .quarantinedFoldRefs) ?? [],
            quarantinedPackageIDs: try container.decodeIfPresent([String].self, forKey: .quarantinedPackageIDs) ?? [],
            rollbackRetainedPackageIDs: try container.decodeIfPresent([String].self, forKey: .rollbackRetainedPackageIDs) ?? [],
            minimalHotPackageIDs: try container.decodeIfPresent([String].self, forKey: .minimalHotPackageIDs) ?? [],
            resultingBreathMode: try container.decode(BASBreathMode.self, forKey: .resultingBreathMode),
            preservedReadOnlyRecovery: try container.decode(Bool.self, forKey: .preservedReadOnlyRecovery),
            summary: try container.decode(String.self, forKey: .summary)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(actuationKinds, forKey: .actuationKinds)
        try container.encode(invalidatedResumeFrameIDs, forKey: .invalidatedResumeFrameIDs)
        try container.encode(invalidatedCacheRefs, forKey: .invalidatedCacheRefs)
        try container.encode(invalidatedFoldRefs, forKey: .invalidatedFoldRefs)
        try container.encode(invalidatedPackageIDs, forKey: .invalidatedPackageIDs)
        try container.encode(quarantinedFoldRefs, forKey: .quarantinedFoldRefs)
        try container.encode(quarantinedPackageIDs, forKey: .quarantinedPackageIDs)
        try container.encode(rollbackRetainedPackageIDs, forKey: .rollbackRetainedPackageIDs)
        try container.encode(minimalHotPackageIDs, forKey: .minimalHotPackageIDs)
        try container.encode(resultingBreathMode, forKey: .resultingBreathMode)
        try container.encode(preservedReadOnlyRecovery, forKey: .preservedReadOnlyRecovery)
        try container.encode(summary, forKey: .summary)
    }
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
                invalidatedPackageIDs.isEmpty
                    ? nil
                    : "Sovereign invalidated package \(invalidatedPackageIDs.joined(separator: ", "))",
                quarantinedFoldRefs.isEmpty
                    ? nil
                    : "Sovereign quarantined fold \(quarantinedFoldRefs.joined(separator: ", "))",
                quarantinedPackageIDs.isEmpty
                    ? nil
                    : "Sovereign quarantined package \(quarantinedPackageIDs.joined(separator: ", "))",
                rollbackRetainedPackageIDs.isEmpty
                    ? nil
                    : "Sovereign rollback retain \(rollbackRetainedPackageIDs.joined(separator: ", "))",
                minimalHotPackageIDs.isEmpty
                    ? nil
                    : "Sovereign minimal hot \(minimalHotPackageIDs.joined(separator: ", "))",
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

    func enriched(
        organDeltaPlan: BASOrganDeltaPlan
    ) -> DecisionFoldedLungSovereignBridgeResult {
        let packageUniverse = orderedUnique(
            organDeltaPlan.activatePackageIDs
                + organDeltaPlan.preloadPackageIDs
                + organDeltaPlan.evictPackageIDs
                + organDeltaPlan.retainPackageIDs
                + organDeltaPlan.rollbackSafeRetainedPackageIDs
        )
        let toolIntentPackages = packageUniverse.filter { packageID in
            packageID.lowercased().contains(BASNeuralOrgan.toolIntentMesh.rawValue.lowercased())
        }
        let memoryCodecPackages = packageUniverse.filter { packageID in
            packageID.lowercased().contains(BASNeuralOrgan.memoryCodecRidge.rawValue.lowercased())
        }

        var invalidatedPackageIDs = self.invalidatedPackageIDs
        var quarantinedPackageIDs = self.quarantinedPackageIDs
        var rollbackRetainedPackageIDs = self.rollbackRetainedPackageIDs
        var minimalHotPackageIDs = self.minimalHotPackageIDs

        if actuationKinds.contains(.toolCut) {
            invalidatedPackageIDs.append(contentsOf: toolIntentPackages)
        }
        if actuationKinds.contains(.memoryFreeze) {
            invalidatedPackageIDs.append(contentsOf: memoryCodecPackages)
        }
        if actuationKinds.contains(.quarantine) {
            quarantinedPackageIDs.append(contentsOf: organDeltaPlan.evictPackageIDs)
        }
        if actuationKinds.contains(.rollback) {
            rollbackRetainedPackageIDs.append(contentsOf: organDeltaPlan.rollbackSafeRetainedPackageIDs)
        }
        if actuationKinds.contains(.deadStop) {
            minimalHotPackageIDs.append(contentsOf: organDeltaPlan.activatePackageIDs)
        }

        return DecisionFoldedLungSovereignBridgeResult(
            actuationKinds: actuationKinds,
            invalidatedResumeFrameIDs: invalidatedResumeFrameIDs,
            invalidatedCacheRefs: invalidatedCacheRefs,
            invalidatedFoldRefs: invalidatedFoldRefs,
            invalidatedPackageIDs: orderedUnique(invalidatedPackageIDs),
            quarantinedFoldRefs: quarantinedFoldRefs,
            quarantinedPackageIDs: orderedUnique(quarantinedPackageIDs),
            rollbackRetainedPackageIDs: orderedUnique(rollbackRetainedPackageIDs),
            minimalHotPackageIDs: orderedUnique(minimalHotPackageIDs),
            resultingBreathMode: resultingBreathMode,
            preservedReadOnlyRecovery: preservedReadOnlyRecovery,
            summary: summary
        )
    }

    private func orderedUnique(_ values: [String]) -> [String] {
        decisionOrderedUniqueLines(values.compactMap { $0.evolutionTrimmedNonEmpty })
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
        let thermalExchangeID = turn.thoughtFold.thermalExchangeRef?.evolutionTrimmedNonEmpty
            ?? "thermal.\(turn.runtimeTrace.sessionID).\(turn.thoughtFold.foldID)"
        let integrityWeaveID = turn.thoughtFold.integrityWeaveRef?.evolutionTrimmedNonEmpty
            ?? "integrity.\(turn.runtimeTrace.sessionID).\(turn.thoughtFold.foldID)"

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
        let effectiveHotColdMap = hotColdMap(
            breathMode: effectiveLungState.breathMode,
            activeOrgans: activeOrgans
        )
        let integrityWeave = integrityWeave(
            weaveID: integrityWeaveID,
            thoughtFold: turn.thoughtFold,
            rollbackAnchor: rollbackAnchor,
            sovereignBridgeResult: sovereignBridgeResult
        )
        let effectiveThermalExchange = Self.thermalExchange(
            exchangeID: thermalExchangeID,
            breathMode: effectiveLungState.breathMode,
            budgetFrame: turn.budgetFrame,
            deviceState: turn.deviceState,
            activeOrgans: activeOrgans,
            hotColdMap: effectiveHotColdMap,
            precisionProfile: precisionProfile
        )
        let effectiveBreathScheduler = breathScheduler(
            schedulerID: breathSchedulerID,
            breathMode: effectiveLungState.breathMode,
            breathPhase: effectiveLungState.breathPhase,
            budgetFrame: turn.budgetFrame,
            thermalPressure: effectiveLungState.thermalPressure,
            restoreReadiness: effectiveLungState.restoreReadiness,
            loopCount: turn.runtimeTrace.loopCount,
            recoveryKind: turn.recoveryDisposition?.kind.rawValue
        )
        let organPackages = organPackages(
            hotColdMap: effectiveHotColdMap,
            precisionProfile: precisionProfile
        )
        let organDeltaPlan = organDeltaPlan(
            planID: turn.thoughtFold.organDeltaPlanRef?.evolutionTrimmedNonEmpty
                ?? "delta.\(turn.runtimeTrace.sessionID).\(turn.thoughtFold.foldID)",
            breathMode: effectiveLungState.breathMode,
            hotColdMap: effectiveHotColdMap,
            organPackages: organPackages,
            thermalExchange: effectiveThermalExchange,
            sovereignBridgeResult: sovereignBridgeResult
        )
        let effectiveSovereignBridgeResult = sovereignBridgeResult?.enriched(
            organDeltaPlan: organDeltaPlan
        )

        return DecisionFoldedLungSnapshot(
            morphGraph: morphGraph,
            hotColdMap: effectiveHotColdMap,
            precisionProfile: precisionProfile,
            thermalExchange: effectiveThermalExchange,
            breathScheduler: effectiveBreathScheduler,
            integrityWeave: integrityWeave,
            organPackages: organPackages,
            organDeltaPlan: organDeltaPlan,
            resumeFrame: resumeFrame,
            rollbackAnchor: rollbackAnchor,
            lungState: effectiveLungState,
            sovereignBridgeResult: effectiveSovereignBridgeResult
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

        let resolvedHotColdMap = anchor.hotColdMap ?? hotColdMap(
            breathMode: lungState.breathMode,
            activeOrgans: organs
        )
        let resolvedPrecisionProfile = anchor.precisionProfile ?? BASPrecisionProfile(
            organPrecisions: precisionMap,
            lockedPrecisions: organs.filter { $0 == .riskSpine || $0 == .permitKnot || $0 == .stubCore },
            degradationOrder: [.full, .protected, .balanced, .minimal],
            guardSafeFloor: lungState.breathMode == .guard ? .protected : .balanced
        )
        let resolvedThermalExchange = Self.thermalExchange(
            exchangeID: "thermal.\(anchor.sessionID ?? "checkpoint").\(resumeFrame.sourceFoldID)",
            breathMode: lungState.breathMode,
            budgetFrame: BASBudgetFrame.guardedLocal(),
            deviceState: BASDeviceState(
                batteryLevel: 0.82,
                thermalLevel: .warm,
                memoryFreeMB: 2048,
                networkState: .constrained,
                foregroundState: .foreground,
                cpuLoad: 0.24,
                gpuLoad: 0.12,
                npuAvailable: true,
                latencyBudgetMs: 900
            ),
            activeOrgans: organs,
            hotColdMap: resolvedHotColdMap,
            precisionProfile: resolvedPrecisionProfile
        )
        let resolvedBreathScheduler = anchor.breathScheduler ?? breathScheduler(
            schedulerID: "scheduler.\(anchor.sessionID ?? "checkpoint").\(resumeFrame.sourceFoldID)",
            breathMode: lungState.breathMode,
            breathPhase: lungState.breathPhase,
            budgetFrame: BASBudgetFrame.guardedLocal(),
            thermalPressure: lungState.thermalPressure,
            restoreReadiness: lungState.restoreReadiness,
            loopCount: resumeFrame.resumeDepth,
            recoveryKind: "checkpoint_restore"
        )
        let organPackages = anchor.organPackages.isEmpty
            ? organPackages(
                hotColdMap: resolvedHotColdMap,
                precisionProfile: resolvedPrecisionProfile
            )
            : anchor.organPackages
        let organDeltaPlan = anchor.organDeltaPlan ?? organDeltaPlan(
            planID: "delta.\(anchor.sessionID ?? "checkpoint").\(resumeFrame.sourceFoldID)",
            breathMode: lungState.breathMode,
            hotColdMap: resolvedHotColdMap,
            organPackages: organPackages,
            thermalExchange: resolvedThermalExchange,
            sovereignBridgeResult: anchor.sovereignBridgeResult
        )
        let effectiveSovereignBridgeResult = anchor.sovereignBridgeResult?.enriched(
            organDeltaPlan: organDeltaPlan
        )

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
            hotColdMap: resolvedHotColdMap,
            precisionProfile: resolvedPrecisionProfile,
            thermalExchange: resolvedThermalExchange,
            breathScheduler: resolvedBreathScheduler,
            integrityWeave: anchor.integrityWeave ?? integrityWeave(
                weaveID: "integrity.\(anchor.sessionID ?? "checkpoint").\(resumeFrame.sourceFoldID)",
                thoughtFoldChecksum: anchor.thoughtFoldChecksum ?? rollbackAnchor.integrityHash,
                rollbackAnchor: rollbackAnchor,
                sovereignBridgeResult: anchor.sovereignBridgeResult
            ),
            organPackages: organPackages,
            organDeltaPlan: organDeltaPlan,
            resumeFrame: resumeFrame,
            rollbackAnchor: rollbackAnchor,
            lungState: lungState,
            sovereignBridgeResult: effectiveSovereignBridgeResult
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

        if turn.hasProtectiveSurfaceGuidance
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

    private static func organPackages(
        hotColdMap: BASHotColdMap,
        precisionProfile: BASPrecisionProfile
    ) -> [BASOrganPackage] {
        let primaryTiers = Dictionary(uniqueKeysWithValues: precisionProfile.organPrecisions.map { precision in
            (precision.organ, precision.tier)
        })
        let orderedOrgans = orderedUnique(hotColdMap.hotOrgans + hotColdMap.warmOrgans + hotColdMap.coldOrgans)

        return orderedOrgans.map { organ in
            BASOrganPackage(
                packageID: organPackageID(for: organ, hotColdMap: hotColdMap),
                organType: organ,
                sizeMB: organPackageSizeMB(for: organ, hotColdMap: hotColdMap),
                precisionOptions: organPrecisionOptions(
                    for: organ,
                    primaryTier: primaryTiers[organ] ?? .balanced
                ),
                loadTimeMs: organPackageLoadTimeMs(for: organ, hotColdMap: hotColdMap),
                thermalCost: organPackageThermalCost(for: organ, hotColdMap: hotColdMap),
                sovereignClass: organSovereignClass(for: organ)
            )
        }
    }

    private static func organDeltaPlan(
        planID: String,
        breathMode: BASBreathMode,
        hotColdMap: BASHotColdMap,
        organPackages: [BASOrganPackage],
        thermalExchange: BASThermalExchangeFrame,
        sovereignBridgeResult: DecisionFoldedLungSovereignBridgeResult?
    ) -> BASOrganDeltaPlan {
        let packageIDsByOrgan = Dictionary(uniqueKeysWithValues: organPackages.map { ($0.organType, $0.packageID) })
        let activatePackageIDs = hotColdMap.hotOrgans.compactMap { packageIDsByOrgan[$0] }
        let preloadPackageIDs = hotColdMap.warmOrgans.compactMap { packageIDsByOrgan[$0] }
        let rollbackSafeRetainedPackageIDs = orderedUnique(
            organPackages
                .filter { $0.sovereignClass == "protected_core" || $0.sovereignClass == "checkpoint_recovery" }
                .map(\.packageID)
        )
        let evictOrgans = orderedUnique(
            thermalExchange.suppressedOrgans
                + hotColdMap.coldOrgans.filter { organ in
                    organ == .toolIntentMesh && sovereignBridgeResult?.actuationKinds.contains(.toolCut) == true
                }
                + hotColdMap.coldOrgans.filter { organ in
                    organ == .memoryCodecRidge && sovereignBridgeResult?.actuationKinds.contains(.memoryFreeze) == true
                }
        )
        let deltaMode = organDeltaMode(
            breathMode: breathMode,
            thermalExchange: thermalExchange,
            sovereignBridgeResult: sovereignBridgeResult
        )

        return BASOrganDeltaPlan(
            planID: planID,
            deltaMode: deltaMode,
            activatePackageIDs: activatePackageIDs,
            preloadPackageIDs: preloadPackageIDs,
            evictPackageIDs: evictOrgans.compactMap { packageIDsByOrgan[$0] },
            retainPackageIDs: orderedUnique(activatePackageIDs + rollbackSafeRetainedPackageIDs),
            rollbackSafeRetainedPackageIDs: rollbackSafeRetainedPackageIDs,
            triggeredActuationKinds: sovereignBridgeResult?.actuationKinds ?? [],
            reasonCodes: orderedUnique(
                [
                    "mode.\(breathMode.rawValue)",
                    "thermal.\(thermalExchange.predictedThermalBand)",
                    thermalExchange.suppressedOrgans.isEmpty ? nil : "suppressed.\(thermalExchange.suppressedOrgans.count)",
                    sovereignBridgeResult?.actuationKinds.isEmpty == false
                        ? "sovereign.\((sovereignBridgeResult?.actuationKinds ?? []).map(\.rawValue).joined(separator: "+"))"
                        : nil
                ]
                .compactMap { $0 }
            )
        )
    }

    private static func organDeltaMode(
        breathMode: BASBreathMode,
        thermalExchange: BASThermalExchangeFrame,
        sovereignBridgeResult: DecisionFoldedLungSovereignBridgeResult?
    ) -> String {
        if sovereignBridgeResult?.actuationKinds.contains(.deadStop) == true {
            return "minimal_hot_shell"
        }
        if sovereignBridgeResult?.actuationKinds.contains(.rollback) == true {
            return "rollback_retain"
        }
        if sovereignBridgeResult?.actuationKinds.contains(.quarantine) == true {
            return "quarantine_swap"
        }
        if thermalExchange.predictedThermalBand == "critical" || thermalExchange.predictedThermalBand == "hot" {
            return "protective_swap"
        }
        switch breathMode {
        case .deepExchange:
            return "deep_exchange_preload"
        case .guard:
            return "protective_swap"
        default:
            return "steady_retention"
        }
    }

    private static func organPackageID(
        for organ: BASNeuralOrgan,
        hotColdMap: BASHotColdMap
    ) -> String {
        let temperatureClass: String
        if hotColdMap.hotOrgans.contains(organ) {
            temperatureClass = "hot"
        } else if hotColdMap.warmOrgans.contains(organ) {
            temperatureClass = "warm"
        } else {
            temperatureClass = "cold"
        }
        return "package.\(organ.rawValue.lowercased()).\(temperatureClass)"
    }

    private static func organPackageSizeMB(
        for organ: BASNeuralOrgan,
        hotColdMap: BASHotColdMap
    ) -> Int {
        let baseSize: Int = switch organ {
        case .stubCore: 18
        case .riskSpine, .permitKnot: 16
        case .memoryCodecRidge, .hostModulationMesh, .toolIntentMesh: 14
        case .coreCortex, .consistencyLattice: 20
        case .simuRing, .criticBlade: 22
        case .scoutStrip, .tissueRouter: 12
        }
        if hotColdMap.hotOrgans.contains(organ) { return baseSize + 4 }
        if hotColdMap.warmOrgans.contains(organ) { return baseSize + 1 }
        return baseSize
    }

    private static func organPackageLoadTimeMs(
        for organ: BASNeuralOrgan,
        hotColdMap: BASHotColdMap
    ) -> Int {
        let baseTime: Int = switch organ {
        case .stubCore: 10
        case .riskSpine, .permitKnot: 14
        case .memoryCodecRidge, .hostModulationMesh, .toolIntentMesh: 18
        case .coreCortex, .consistencyLattice: 24
        case .simuRing, .criticBlade: 30
        case .scoutStrip, .tissueRouter: 16
        }
        if hotColdMap.hotOrgans.contains(organ) { return max(6, baseTime - 6) }
        if hotColdMap.warmOrgans.contains(organ) { return max(10, baseTime - 2) }
        return baseTime
    }

    private static func organPackageThermalCost(
        for organ: BASNeuralOrgan,
        hotColdMap: BASHotColdMap
    ) -> Int {
        let baseCost: Int = switch organ {
        case .stubCore: 10
        case .riskSpine, .permitKnot: 14
        case .memoryCodecRidge, .hostModulationMesh, .toolIntentMesh: 12
        case .coreCortex, .consistencyLattice: 18
        case .simuRing, .criticBlade: 22
        case .scoutStrip, .tissueRouter: 8
        }
        if hotColdMap.hotOrgans.contains(organ) { return baseCost + 4 }
        if hotColdMap.warmOrgans.contains(organ) { return baseCost + 1 }
        return max(4, baseCost - 2)
    }

    private static func organPrecisionOptions(
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
        return orderedUnique([primaryTier, fallbackTier, .minimal])
    }

    private static func organSovereignClass(
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

    private static func integrityWeave(
        weaveID: String,
        thoughtFold: BASThoughtFold,
        rollbackAnchor: BASRollbackAnchor,
        sovereignBridgeResult: DecisionFoldedLungSovereignBridgeResult?
    ) -> BASIntegrityWeaveFrame {
        integrityWeave(
            weaveID: weaveID,
            thoughtFoldChecksum: thoughtFold.checksum,
            bindingChecksum: thoughtFold.bindingChecksum,
            rollbackAnchor: rollbackAnchor,
            sovereignBridgeResult: sovereignBridgeResult
        )
    }

    private static func integrityWeave(
        weaveID: String,
        thoughtFoldChecksum: String,
        bindingChecksum: String? = nil,
        rollbackAnchor: BASRollbackAnchor,
        sovereignBridgeResult: DecisionFoldedLungSovereignBridgeResult?
    ) -> BASIntegrityWeaveFrame {
        let requiredChecks = orderedUnique([
            "fold_checksum",
            "host_gate",
            "rollback_anchor",
            bindingChecksum?.evolutionTrimmedNonEmpty == nil ? nil : "binding_checksum"
        ].compactMap { $0 })
        let contaminationRefs = orderedUnique(
            (sovereignBridgeResult?.quarantinedFoldRefs ?? [])
            + (sovereignBridgeResult?.invalidatedFoldRefs ?? [])
            + (sovereignBridgeResult?.invalidatedCacheRefs ?? [])
        )
        let failedChecks = sovereignBridgeResult?.quarantinedFoldRefs.isEmpty == false
            ? ["contamination_scan"]
            : []
        let completedChecks = requiredChecks.filter { failedChecks.contains($0) == false }
        let purityState: String
        if sovereignBridgeResult?.quarantinedFoldRefs.isEmpty == false {
            purityState = "quarantined"
        } else if sovereignBridgeResult?.invalidatedFoldRefs.isEmpty == false {
            purityState = "recovered"
        } else if contaminationRefs.isEmpty == false || sovereignBridgeResult?.preservedReadOnlyRecovery == true {
            purityState = "sealed"
        } else {
            purityState = "verified"
        }
        let verificationHash = rollbackAnchor.integrityHash.evolutionTrimmedNonEmpty ?? thoughtFoldChecksum

        return BASIntegrityWeaveFrame(
            weaveID: weaveID,
            foldChecksum: thoughtFoldChecksum,
            rollbackIntegrityHash: rollbackAnchor.integrityHash,
            requiredChecks: requiredChecks,
            completedChecks: completedChecks,
            failedChecks: failedChecks,
            purityState: purityState,
            contaminationRefs: contaminationRefs,
            trustedSnapshotRef: rollbackAnchor.safeSnapshotRef,
            verificationHash: verificationHash
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

    private static func thermalExchange(
        exchangeID: String,
        breathMode: BASBreathMode,
        budgetFrame: BASBudgetFrame,
        deviceState: BASDeviceState,
        activeOrgans: [BASNeuralOrgan],
        hotColdMap: BASHotColdMap,
        precisionProfile: BASPrecisionProfile
    ) -> BASThermalExchangeFrame {
        let predictedBand = predictedThermalBand(
            thermalLevel: deviceState.thermalLevel,
            thermalGuardLevel: budgetFrame.thermalGuardLevel
        )
        let rerouteTargets = thermalRerouteTargets(
            predictedBand: predictedBand,
            activeOrgans: activeOrgans
        )

        return BASThermalExchangeFrame(
            exchangeID: exchangeID,
            exchangeMode: thermalExchangeMode(
                predictedBand: predictedBand,
                breathMode: breathMode
            ),
            predictedThermalBand: predictedBand,
            coolingActions: thermalCoolingActions(
                predictedBand: predictedBand,
                thermalGuardLevel: budgetFrame.thermalGuardLevel
            ),
            suppressedOrgans: suppressedThermalOrgans(
                predictedBand: predictedBand,
                hotColdMap: hotColdMap
            ),
            reroutedOrgans: rerouteTargets.keys.compactMap(BASNeuralOrgan.init(rawValue:)),
            rerouteTargets: rerouteTargets,
            precisionDowngradePlan: thermalPrecisionDowngradePlan(
                predictedBand: predictedBand,
                activeOrgans: activeOrgans,
                hotColdMap: hotColdMap,
                precisionProfile: precisionProfile
            ),
            exchangeReasonCodes: [
                "mode.\(breathMode.rawValue)",
                "thermal.\(deviceState.thermalLevel.rawValue)",
                "guard.\(budgetFrame.thermalGuardLevel.rawValue)",
                "band.\(predictedBand)"
            ]
        )
    }

    private static func thermalExchangeMode(
        predictedBand: String,
        breathMode: BASBreathMode
    ) -> String {
        if breathMode == .quarantine || breathMode == .lockdown {
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
            return breathMode == .deepExchange ? "deep_exchange" : "steady_exchange"
        }
    }

    private static func predictedThermalBand(
        thermalLevel: BASThermalLevel,
        thermalGuardLevel: BASThermalGuardLevel
    ) -> String {
        switch (thermalLevel, thermalGuardLevel) {
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

    private static func thermalCoolingActions(
        predictedBand: String,
        thermalGuardLevel: BASThermalGuardLevel
    ) -> [String] {
        switch predictedBand {
        case "critical":
            return ["delay_cold_organs", "trim_noncritical_precision", "pause_background_maintenance"]
        case "hot":
            return [
                "delay_cold_organs",
                "trim_noncritical_precision"
            ] + (thermalGuardLevel == .throttle ? ["split_execution_graph"] : [])
        case "warm":
            return ["delay_cold_organs"]
        default:
            return ["hold_hot_path"]
        }
    }

    private static func suppressedThermalOrgans(
        predictedBand: String,
        hotColdMap: BASHotColdMap
    ) -> [BASNeuralOrgan] {
        let preferredOrder: [BASNeuralOrgan] = [.criticBlade, .simuRing, .scoutStrip, .toolIntentMesh, .memoryCodecRidge]
        let pool = orderedUniqueOrgans(
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

        return Array(pool.prefix(limit))
    }

    private static func thermalRerouteTargets(
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

    private static func thermalPrecisionDowngradePlan(
        predictedBand: String,
        activeOrgans: [BASNeuralOrgan],
        hotColdMap: BASHotColdMap,
        precisionProfile: BASPrecisionProfile
    ) -> [BASNeuralOrganPrecision] {
        guard predictedBand == "hot" || predictedBand == "critical" else {
            return []
        }

        let protectedOrgans: Set<BASNeuralOrgan> = [.stubCore, .riskSpine, .permitKnot]
        let downgradeTier: BASNeuralPrecisionTier = predictedBand == "critical" ? .minimal : .balanced
        let currentTiers = Dictionary(uniqueKeysWithValues: precisionProfile.organPrecisions.map { ($0.organ, $0.tier) })
        let candidateOrgans = orderedUniqueOrgans(
            activeOrgans
                + hotColdMap.warmOrgans
                + hotColdMap.coldOrgans.filter { $0 == .hostModulationMesh || $0 == .toolIntentMesh }
        )

        return candidateOrgans.compactMap { organ in
            guard protectedOrgans.contains(organ) == false else { return nil }
            guard currentTiers[organ] != downgradeTier else { return nil }
            return BASNeuralOrganPrecision(organ: organ, tier: downgradeTier)
        }
    }

    private static func orderedUniqueOrgans(
        _ organs: [BASNeuralOrgan]
    ) -> [BASNeuralOrgan] {
        organs.reduce(into: [BASNeuralOrgan]()) { uniqueOrgans, organ in
            guard uniqueOrgans.contains(organ) == false else { return }
            uniqueOrgans.append(organ)
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
            || turn.hasProtectiveSurfaceGuidance
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
