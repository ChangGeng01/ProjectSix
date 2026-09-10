import Foundation
import BASMemory
import BASOrchestration
import BASPolicy
import BASRuntimeCore

// MARK: - M71 split — BASEBrainTurnResult breath/thermal/cache computed vars and
// the sovereign actuation → breath-mode bridge.  Previously file-scope private
// inside the 6099-line EBrainRuntimeCoordinator.swift; moved to internal default
// access so sibling extension files in BASHostKit can share these derivations.
// None of these members surface through the Qinao public API.

extension BASEBrainTurnResult {
    var evolutionBreathMode: String {
        if sovereignActuationCommands.contains(where: { $0.kind == .deadStop })
            || emergencyBrake.brakeLevel == .lockdown
            || budgetFrame.runMode == .lockdown {
            return "lockdown"
        }

        if sovereignActuationCommands.contains(where: { $0.kind == .quarantine })
            || recoveryDisposition?.kind == .quarantine
            || budgetFrame.runMode == .quarantine {
            return "quarantine"
        }

        if actionPermit.mode.isProtective
            || budgetFrame.runMode == .guard
            || sovereignActuationCommands.contains(where: { $0.kind == .guardShift }) {
            return "guard"
        }

        if budgetFrame.runMode == .deepLoop
            || thoughtFrame.candidates.count > 1
            || runtimeTrace.loopCount > 1 {
            return "deepExchange"
        }

        if contextFrame.taskType == .choice
            || contextFrame.taskType == .conflict
            || thoughtFrame.candidateFrontier?.frontierWidth ?? 0 > 0 {
            return "structured"
        }

        return "light"
    }

    var evolutionBreathPhase: String {
        if sovereignActuationCommands.contains(where: { $0.kind == .rollback })
            || budgetFrame.runMode == .recovery {
            return "resume"
        }

        if budgetFrame.runMode == .lockdown
            || sovereignActuationCommands.contains(where: { $0.kind == .deadStop }) {
            return "rest"
        }

        if runtimeTrace.loopCount > 0
            || actionPermit.mode.isProtective
            || runtimeTrace.guardrailFindings.isEmpty == false {
            return "exchange"
        }

        return "inhale"
    }

    var evolutionThermalPressure: Int {
        let thermalBase = switch deviceState.thermalLevel {
        case .nominal: 20
        case .warm: 55
        case .hot: 78
        case .critical: 92
        }
        let loadPressure = Int((max(deviceState.cpuLoad, deviceState.gpuLoad) * 25).rounded())
        return min(100, thermalBase + loadPressure)
    }

    var evolutionCachePressure: Int {
        let cacheRelief = Int((runtimeTrace.cacheHitRate * 100).rounded())
        let ticketPressure = min(updateTickets.count * 8, 24)
        return max(0, min(100, 100 - cacheRelief + ticketPressure))
    }

    var evolutionRestoreReadinessPercent: Int {
        let readiness = min(max((vitalState.stabilityScore + vitalState.continuityScore) / 2.0, 0), 1)
        return Int((readiness * 100).rounded())
    }

    func evolutionSovereignBridge(
        currentBreathMode: String,
        resumeID: String,
        cacheStateRef: String,
        rollbackFoldRefs: [String]
    ) -> EvolutionSovereignBridgeProjection {
        guard sovereignActuationCommands.isEmpty == false else {
            return EvolutionSovereignBridgeProjection(
                actuationKinds: [],
                invalidatedResumeFrameIDs: [],
                invalidatedCacheRefs: [],
                invalidatedFoldRefs: [],
                quarantinedFoldRefs: [],
                resultingBreathMode: nil,
                preservedReadOnlyRecovery: nil,
                summary: nil
            )
        }

        var invalidatedResumeFrameIDs: [String] = []
        var invalidatedCacheRefs: [String] = []
        var invalidatedFoldRefs: [String] = []
        var quarantinedFoldRefs: [String] = []
        var resultingBreathMode = currentBreathMode
        var preservedReadOnlyRecovery = false

        for command in sovereignActuationCommands {
            switch command.kind {
            case .toolCut:
                invalidatedResumeFrameIDs.append(resumeID)
                invalidatedCacheRefs.append("tool-intent:\(runtimeTrace.sessionID)")
            case .memoryFreeze:
                preservedReadOnlyRecovery = true
                invalidatedCacheRefs.append("memory-write:\(runtimeTrace.sessionID)")
            case .quarantine:
                preservedReadOnlyRecovery = true
                resultingBreathMode = "quarantine"
                invalidatedResumeFrameIDs.append(resumeID)
                invalidatedCacheRefs.append(cacheStateRef)
                quarantinedFoldRefs.append(contentsOf: rollbackFoldRefs)
            case .rollback:
                preservedReadOnlyRecovery = true
                resultingBreathMode = command.forcedMode.map(Self.breathMode(from:)) ?? "guard"
                invalidatedResumeFrameIDs.append(resumeID)
                invalidatedCacheRefs.append(cacheStateRef)
                invalidatedFoldRefs.append(contentsOf: rollbackFoldRefs)
            case .deadStop:
                preservedReadOnlyRecovery = true
                resultingBreathMode = "lockdown"
                invalidatedResumeFrameIDs.append(resumeID)
                invalidatedCacheRefs.append(cacheStateRef)
                invalidatedFoldRefs.append(contentsOf: rollbackFoldRefs)
            case .guardShift:
                resultingBreathMode = "guard"
            case .throttle:
                resultingBreathMode = Self.throttledBreathMode(resultingBreathMode)
            case .shadowLock:
                preservedReadOnlyRecovery = true
            }
        }

        invalidatedResumeFrameIDs = evolutionOrderedUnique(invalidatedResumeFrameIDs)
        invalidatedCacheRefs = evolutionOrderedUnique(invalidatedCacheRefs).sorted()
        invalidatedFoldRefs = evolutionOrderedUnique(invalidatedFoldRefs)
        quarantinedFoldRefs = evolutionOrderedUnique(quarantinedFoldRefs)

        return EvolutionSovereignBridgeProjection(
            actuationKinds: sovereignActuationCommands.map(\.kind),
            invalidatedResumeFrameIDs: invalidatedResumeFrameIDs,
            invalidatedCacheRefs: invalidatedCacheRefs,
            invalidatedFoldRefs: invalidatedFoldRefs,
            quarantinedFoldRefs: quarantinedFoldRefs,
            resultingBreathMode: resultingBreathMode,
            preservedReadOnlyRecovery: preservedReadOnlyRecovery,
            summary: evolutionJoined([
                "Sovereign bridge",
                sovereignActuationCommands.map(\.kind.rawValue).joined(separator: ", "),
                invalidatedResumeFrameIDs.isEmpty ? nil : "resume \(invalidatedResumeFrameIDs.joined(separator: ", "))",
                invalidatedCacheRefs.isEmpty ? nil : "cache \(invalidatedCacheRefs.joined(separator: ", "))",
                invalidatedFoldRefs.isEmpty ? nil : "fold \(invalidatedFoldRefs.joined(separator: ", "))",
                quarantinedFoldRefs.isEmpty ? nil : "quarantine \(quarantinedFoldRefs.joined(separator: ", "))",
                preservedReadOnlyRecovery ? "readonly recovery" : nil,
                "mode \(resultingBreathMode)"
            ])
        )
    }

    func evolutionOrderedUnique<T: Hashable>(_ values: [T]) -> [T] {
        values.reduce(into: [T]()) { uniqueValues, value in
            guard !uniqueValues.contains(value) else { return }
            uniqueValues.append(value)
        }
    }

    static func breathMode(from runMode: BASEBrainRunMode) -> String {
        switch runMode {
        case .dormant, .pulse, .sentinel:
            return "light"
        case .engage, .reflect:
            return "structured"
        case .deepLoop, .recovery:
            return "deepExchange"
        case .guard:
            return "guard"
        case .quarantine:
            return "quarantine"
        case .lockdown:
            return "lockdown"
        }
    }

    static func throttledBreathMode(_ breathMode: String) -> String {
        switch breathMode {
        case "deepExchange":
            return "structured"
        case "guard", "quarantine", "lockdown":
            return breathMode
        default:
            return breathMode == "light" ? "light" : "structured"
        }
    }
}
