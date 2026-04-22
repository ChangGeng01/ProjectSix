import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

// MARK: - M72 split — BASHostRuntimeEBrainContextService extracted from the 5039-line
// EBrainHostRuntimeSynthesis.swift.  Previously file-scope `private`, now
// default-internal so sibling files in BASHostKit (the reduced main
// `makeEBrainTurn` orchestrator and any cross-struct helpers) can reference
// it.  None of these members surface through the Qinao public API.

struct BASHostRuntimeEBrainContextService: BASContextServicing {
    let request: BASHostSessionRequest
    let currentBrain: BASHostCurrentBrain
    let tuning: BASEBrainRuntimeSynthesisPolicy
    let hostConstitution: BASHostConstitution?

    func analyzeContext(
        userInput: String,
        hostContext: BASHostProfile,
        budget: BASBudgetFrame
    ) -> BASContextFrame {
        let manipulationHints = BASHostRuntimeEBrainPromptAnalyzer.manipulationHints(in: userInput)
        let contextTuning = tuning.context
        let trustInstability = currentBrain.hasTrustDriftSignals ? contextTuning.trustInstabilityIncrement : 0
        let guardedPressure = currentBrain.hasProtectiveBoundary ? contextTuning.guardedPressureIncrement : 0
        let taskType = taskType(for: userInput, manipulationHints: manipulationHints)
        let emotionalLoad = min(
            1,
            (request.riskLevel == .high
                ? contextTuning.emotionalLoadHighRisk
                : (request.workflowProfile == .reflective
                    ? contextTuning.emotionalLoadReflective
                    : contextTuning.emotionalLoadDefault))
                + (currentBrain.calibrationStatus == .drifting ? contextTuning.emotionalLoadDriftingIncrement : 0)
        )
        let timePressure = min(
            1,
            (request.kind == .reopen
                ? contextTuning.timePressureReopen
                : (tuning.wakeIntent.containsUrgency(userInput)
                    ? contextTuning.timePressureUrgent
                    : contextTuning.timePressureDefault))
                + guardedPressure
        )
        let relationPattern = resolvedRelationPattern()
        let ambiguityScore = min(
            1,
            (request.workflowProfile == .comparative
                ? contextTuning.ambiguityComparative
                : contextTuning.ambiguityDefault)
                + trustInstability
        )
        let consequenceLevel = min(
            1,
            (request.riskLevel == .high
                ? contextTuning.consequenceHigh
                : (request.riskLevel == .medium
                    ? contextTuning.consequenceMedium
                    : contextTuning.consequenceLow))
                + guardedPressure
        )
        let roleGeometry = buildRoleGeometry(
            userInput: userInput,
            relationPattern: relationPattern
        )
        let enrichedManipulationHints = orderedUnique(
            manipulationHints
                + ((roleGeometry.map { isAuthorityRelation($0.relationClass) } ?? false) ? ["authority_pressure"] : [])
        )
        let hostRelevance = min(
            1.0,
            max(
                0.4,
                Double(hostContext.longTermGoals.count) * 0.2
                    + constitutionGoalRelevanceIncrement()
                    + constitutionRelationRelevanceIncrement()
                    + presenceRelationRelevanceIncrement(for: roleGeometry?.relationClass)
            )
        )
        let sceneType = resolvedSceneType(
            userInput: userInput,
            taskType: taskType,
            manipulationHints: enrichedManipulationHints,
            consequenceLevel: consequenceLevel
        )
        let powerGradient = buildPowerGradient(
            roleGeometry: roleGeometry,
            manipulationHints: enrichedManipulationHints,
            consequenceLevel: consequenceLevel
        )
        let emotionalWeather = buildEmotionalWeather(
            userInput: userInput,
            emotionalLoad: emotionalLoad,
            timePressure: timePressure
        )
        let urgencyTruth = buildUrgencyTruth(
            userInput: userInput,
            timePressure: timePressure,
            consequenceLevel: consequenceLevel
        )
        let consequenceHorizon = buildConsequenceHorizon(
            relationClass: roleGeometry?.relationClass,
            consequenceLevel: consequenceLevel,
            hostRelevance: hostRelevance
        )
        let manipulationTrace = buildManipulationTrace(
            userInput: userInput,
            manipulationHints: enrichedManipulationHints,
            roleGeometry: roleGeometry,
            urgencyTruth: urgencyTruth
        )
        let hostResonance = buildHostResonance(
            hostContext: hostContext,
            relationClass: roleGeometry?.relationClass,
            hostRelevance: hostRelevance
        )
        let continuityAnchor = buildContinuityAnchor(
            relationClass: roleGeometry?.relationClass,
            sceneType: sceneType
        )
        let routeHint = buildRouteHint(
            budget: budget,
            taskType: taskType,
            consequenceLevel: consequenceLevel,
            manipulationTrace: manipulationTrace,
            urgencyTruth: urgencyTruth,
            powerGradient: powerGradient,
            hostRelevance: hostRelevance
        )
        let confidenceBand = buildConfidenceBand(
            roleGeometry: roleGeometry,
            urgencyTruth: urgencyTruth,
            ambiguityScore: ambiguityScore,
            manipulationHints: enrichedManipulationHints
        )
        return BASContextFrame(
            utterance: userInput,
            taskType: taskType,
            sceneType: sceneType,
            emotionalLoad: emotionalLoad,
            timePressure: timePressure,
            relationPattern: relationPattern,
            ambiguityScore: ambiguityScore,
            consequenceLevel: consequenceLevel,
            manipulationHints: orderedUnique(enrichedManipulationHints + currentBrain.riskFlags.map(\.rawValue)),
            hostRelevance: hostRelevance,
            roleGeometry: roleGeometry,
            powerGradient: powerGradient,
            emotionalWeather: emotionalWeather,
            urgencyTruth: urgencyTruth,
            consequenceHorizon: consequenceHorizon,
            manipulationTrace: manipulationTrace,
            hostResonance: hostResonance,
            continuityAnchor: continuityAnchor,
            routeHint: routeHint,
            confidenceBand: confidenceBand
        )
    }

    private func taskType(for userInput: String, manipulationHints: [String]) -> BASContextTaskType {
        if !manipulationHints.isEmpty || currentBrain.hasTrustDriftSignals {
            return .manipulationRisk
        }
        if request.riskLevel == .high {
            return request.kind == .reopen ? .highPressure : .highConsequence
        }
        switch request.workflowProfile {
        case .primary:
            return .task
        case .comparative:
            return .choice
        case .reflective:
            return .chat
        }
    }

    private func resolvedSceneType(
        userInput: String,
        taskType: BASContextTaskType,
        manipulationHints: [String],
        consequenceLevel: Double
    ) -> BASContextSceneType {
        if request.riskLevel == .high && consequenceLevel > 0.7 &&
            (tuning.wakeIntent.containsUrgency(userInput) || request.kind == .reopen) {
            return .highPressureConflict
        }
        if manipulationHints.isEmpty == false {
            return .manipulationRisk
        }
        return BASContextSceneType.defaultValue(for: taskType)
    }

    private func buildRoleGeometry(
        userInput: String,
        relationPattern: String
    ) -> BASRoleGeometry? {
        let relationClass = detectedRelationClass(in: userInput, relationPattern: relationPattern)
        guard relationClass.isEmpty == false else {
            return nil
        }

        var asymmetryFlags: [String] = []
        if highConsequenceRelations.contains(relationClass) {
            asymmetryFlags.append("high_consequence_relation")
        }
        if isAuthorityRelation(relationClass) {
            asymmetryFlags.append("authority_relation")
        }
        if request.riskLevel == .high {
            asymmetryFlags.append("high_risk_context")
        }

        return BASRoleGeometry(
            actors: orderedUnique(["host", relationClass]),
            roleTypes: orderedUnique(["host", roleType(for: relationClass)]),
            relationClass: relationClass,
            asymmetryFlags: asymmetryFlags,
            intimacyDistance: intimacyDistance(for: relationClass)
        )
    }

    private func buildPowerGradient(
        roleGeometry: BASRoleGeometry?,
        manipulationHints: [String],
        consequenceLevel: Double
    ) -> BASPowerGradient? {
        guard let roleGeometry else {
            return nil
        }

        let authorityPressure = manipulationHints.contains("authority_pressure") || isAuthorityRelation(roleGeometry.relationClass)
        let highConsequence = roleGeometry.asymmetryFlags.contains("high_consequence_relation")
        let baseStrength = (highConsequence ? 0.58 : 0.28)
            + (authorityPressure ? 0.14 : 0)
            + (request.riskLevel == .high ? 0.10 : 0)
            + min(0.12, consequenceLevel * 0.12)

        return BASPowerGradient(
            direction: authorityPressure || highConsequence ? "external_over_host" : "balanced",
            strength: min(1, baseStrength),
            sources: orderedUnique(
                ["request_context"]
                    + (highConsequence ? ["relationship_gravity"] : [])
                    + (authorityPressure ? ["authority"] : [])
            ),
            confidence: authorityPressure || highConsequence ? 0.82 : 0.56
        )
    }

    private func buildEmotionalWeather(
        userInput: String,
        emotionalLoad: Double,
        timePressure: Double
    ) -> BASEmotionalWeather {
        var dominantTones: [String] = []
        if timePressure > 0.7 {
            dominantTones.append("pressured")
        }
        if userInput.lowercased().contains("explain yourself") {
            dominantTones.append("defensive")
        }
        if dominantTones.isEmpty {
            dominantTones.append(request.workflowProfile == .reflective ? "reflective" : "focused")
        }

        return BASEmotionalWeather(
            dominantTones: dominantTones,
            intensity: emotionalLoad,
            volatility: min(1, emotionalLoad * 0.7 + timePressure * 0.2),
            pressureCoupling: min(1, (emotionalLoad + timePressure) / 2),
            judgmentDistortionRisk: min(1, emotionalLoad * 0.55 + timePressure * 0.35)
        )
    }

    private func buildUrgencyTruth(
        userInput: String,
        timePressure: Double,
        consequenceLevel: Double
    ) -> BASUrgencyTruth {
        let normalized = userInput.lowercased()
        let explicitUrgencyMarkers = ["now", "right now", "immediately", "urgent", "asap"]
        let statedUrgency = explicitUrgencyMarkers.contains(where: normalized.contains) ? max(0.82, timePressure) : timePressure
        let inferredUrgency = min(
            1,
            max(
                statedUrgency,
                consequenceLevel * 0.62 + (request.kind == .reopen ? 0.20 : 0)
            )
        )
        let authenticityScore = request.riskLevel == .high ? 0.82 : min(0.74, inferredUrgency)
        let canDelay = !(request.kind == .reopen || (statedUrgency > 0.75 && inferredUrgency > 0.70))

        return BASUrgencyTruth(
            statedUrgency: statedUrgency,
            inferredUrgency: inferredUrgency,
            authenticityScore: authenticityScore,
            canDelay: canDelay,
            windowDecay: min(1, inferredUrgency * 0.88)
        )
    }

    private func buildConsequenceHorizon(
        relationClass: String?,
        consequenceLevel: Double,
        hostRelevance: Double
    ) -> BASConsequenceHorizon {
        let impactScope = relationClass.map { "relationship:\($0)" } ?? "local"
        let reversibility = max(0.08, 1 - consequenceLevel)
        return BASConsequenceHorizon(
            impactScope: impactScope,
            reversibility: reversibility,
            publicPrivateDomain: request.surface == .application ? "private" : "mixed",
            shortTermRisk: consequenceLevel,
            longTermTrace: min(1, consequenceLevel * 0.72 + hostRelevance * 0.18)
        )
    }

    private func buildManipulationTrace(
        userInput: String,
        manipulationHints: [String],
        roleGeometry: BASRoleGeometry?,
        urgencyTruth: BASUrgencyTruth
    ) -> BASManipulationTrace? {
        let normalized = userInput.lowercased()
        let highLeverageRelation = roleGeometry.flatMap { geometry in
            let relation = geometry.relationClass
            return highConsequenceRelations.contains(where: { $0 == relation }) ? relation : nil
        }
        let shamePressure = normalized.contains("explain yourself") ? 0.54 : 0
        let confidence = min(
            1,
            Double(manipulationHints.count) * 0.22
                + (highLeverageRelation == nil ? 0 : 0.18)
                + (urgencyTruth.statedUrgency > 0.75 ? 0.18 : 0)
        )

        guard manipulationHints.isEmpty == false || shamePressure > 0 || highLeverageRelation != nil else {
            return nil
        }

        return BASManipulationTrace(
            traceID: "trace.\(request.kind.rawValue).\(request.workflowProfile.rawValue)",
            signals: orderedUnique(manipulationHints + (shamePressure > 0 ? ["shame_pressure"] : [])),
            gaslightPrecursor: manipulationHints.contains("history_rewrite"),
            shamePressure: shamePressure,
            authorityMask: roleGeometry.map { isAuthorityRelation($0.relationClass) } ?? false,
            timeCoercion: urgencyTruth.statedUrgency,
            relationalLeverage: highLeverageRelation.map { [$0] } ?? [],
            confidence: max(0.32, confidence)
        )
    }

    private func buildHostResonance(
        hostContext: BASHostProfile,
        relationClass: String?,
        hostRelevance: Double
    ) -> BASHostResonance {
        let relatedGoals = orderedUnique(
            hostContext.longTermGoals
                + (hostConstitution?.goalSpine.priorityOrder ?? [])
                + (hostConstitution?.goalSpine.goals ?? [])
        )
        let touchedBoundaries = orderedUnique(
            currentBrain.boundaryConstraints.map(\.rawValue)
                + hostContext.noGoZones
                + [currentBrain.boundaryHeadline]
        )
        let relationRefs = orderedUnique(
            hostConstitution?.relationGravity.highConsequenceLinks ?? []
                + hostContext.relationshipRefs
                + (relationClass.map { [$0] } ?? [])
        )
        let vulnerabilityFlags = orderedUnique(
            currentBrain.activeConstraints
                + currentBrain.riskFlags.map(\.rawValue)
        )

        return BASHostResonance(
            relatedGoals: relatedGoals,
            touchedBoundaries: touchedBoundaries,
            highConsequenceRelationRefs: relationRefs,
            rhythmStateRef: hostConstitution?.narrativeLoom.currentPhase ?? request.workflowProfile.rawValue,
            vulnerabilityGuardFlags: vulnerabilityFlags,
            intensity: hostRelevance
        )
    }

    private func buildContinuityAnchor(
        relationClass: String?,
        sceneType: BASContextSceneType
    ) -> BASContinuityAnchor {
        let relationArc = relationClass ?? currentBrain.relationshipBoundary
        return BASContinuityAnchor(
            anchorID: "l6.\(request.kind.rawValue).\(relationArc)",
            linkedTurns: orderedUnique(
                [request.kind.rawValue, request.workflowProfile.rawValue]
                    + (hostConstitution?.narrativeLoom.continuityLinks ?? [])
            ),
            sceneArc: "\(sceneType.rawValue):\(relationArc)",
            escalationPattern: request.kind == .reopen ? "reopen_escalation" : nil,
            unresolvedThreads: hostConstitution?.narrativeLoom.unresolvedTensions ?? []
        )
    }

    private func buildRouteHint(
        budget: BASBudgetFrame,
        taskType: BASContextTaskType,
        consequenceLevel: Double,
        manipulationTrace: BASManipulationTrace?,
        urgencyTruth: BASUrgencyTruth,
        powerGradient: BASPowerGradient?,
        hostRelevance: Double
    ) -> BASContextRouteHint {
        let manipulationConfidence = manipulationTrace?.confidence ?? 0
        let needGuard = request.riskLevel == .high
            || manipulationConfidence > 0.55
            || (powerGradient?.strength ?? 0) > 0.65
            || (urgencyTruth.canDelay == false && consequenceLevel > 0.7)
        let needDoublePath = taskType == .choice || consequenceLevel > 0.72
        let needMirror = request.workflowProfile == .reflective || (manipulationTrace?.confidence ?? 0) > 0.45
        let needMemory = request.kind == .reopen || hostRelevance > 0.62
        let preferredMode: String = if needGuard {
            "guarded"
        } else if needDoublePath {
            "comparative"
        } else if needMirror || budget.runMode == .reflect {
            "mirrored"
        } else {
            "direct"
        }

        return BASContextRouteHint(
            preferredMode: preferredMode,
            needMemory: needMemory,
            needMirror: needMirror,
            needDoublePath: needDoublePath,
            needGuard: needGuard,
            sovereignHintLevel: needGuard && consequenceLevel > 0.72 ? "elevated" : "normal"
        )
    }

    private func buildConfidenceBand(
        roleGeometry: BASRoleGeometry?,
        urgencyTruth: BASUrgencyTruth,
        ambiguityScore: Double,
        manipulationHints: [String]
    ) -> Double {
        let roleConfidence = roleGeometry == nil ? 0.06 : 0.18
        let urgencyConfidence = urgencyTruth.statedUrgency > 0.7 ? 0.12 : 0.05
        let manipulationConfidence = manipulationHints.isEmpty ? 0.04 : 0.10
        return min(
            0.92,
            max(
                0.24,
                0.40 + roleConfidence + urgencyConfidence + manipulationConfidence - (ambiguityScore * 0.14)
            )
        )
    }

    private func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private func resolvedRelationPattern() -> String {
        guard let hostConstitution else {
            return currentBrain.relationshipBoundary
        }

        let relationMarkers = hostConstitution.relationGravity.highConsequenceLinks.map {
            "high_consequence:\($0)"
        }
        let parts = orderedUnique([currentBrain.relationshipBoundary] + relationMarkers)
        return parts.joined(separator: "|")
    }

    private func constitutionGoalRelevanceIncrement() -> Double {
        guard let hostConstitution else { return 0 }

        let goalCount = hostConstitution.goalSpine.priorityOrder.count + hostConstitution.goalSpine.goals.count
        return min(0.24, Double(goalCount) * 0.04)
    }

    private func constitutionRelationRelevanceIncrement() -> Double {
        guard let hostConstitution else { return 0 }
        return hostConstitution.relationGravity.highConsequenceLinks.isEmpty ? 0 : 0.14
    }

    private func presenceRelationRelevanceIncrement(for relationClass: String?) -> Double {
        guard let relationClass else { return 0 }
        if highConsequenceRelations.contains(where: { $0 == relationClass }) {
            return 0.18
        }
        return isAuthorityRelation(relationClass) ? 0.10 : 0
    }

    private var highConsequenceRelations: [String] {
        orderedUnique(
            (hostConstitution?.relationGravity.highConsequenceLinks ?? [])
                + (hostConstitution?.relationGravity.nodes ?? [])
        )
    }

    private func detectedRelationClass(
        in userInput: String,
        relationPattern: String
    ) -> String {
        let tokens = Set(BASHostRuntimeEBrainPromptAnalyzer.tokenized(userInput))
        if let matchedRelation = highConsequenceRelations.first(where: { tokens.contains($0.lowercased()) }) {
            return matchedRelation
        }
        if let explicitAuthority = ["manager", "boss", "lead", "director", "client", "partner"].first(where: {
            tokens.contains($0)
        }) {
            return explicitAuthority
        }
        if let leadRelation = highConsequenceRelations.first {
            return leadRelation
        }
        if relationPattern.isEmpty == false {
            return relationPattern.components(separatedBy: "|").first ?? currentBrain.relationshipBoundary
        }
        return currentBrain.relationshipBoundary
    }

    private func roleType(for relationClass: String) -> String {
        isAuthorityRelation(relationClass) ? "authority_peer" : "relationship_peer"
    }

    private func isAuthorityRelation(_ relationClass: String) -> Bool {
        ["manager", "boss", "lead", "director", "teacher", "parent", "client"].contains(relationClass.lowercased())
    }

    private func intimacyDistance(for relationClass: String) -> Double {
        switch relationClass.lowercased() {
        case "partner", "parent":
            0.18
        case "manager", "boss", "lead", "director", "client":
            0.56
        default:
            0.42
        }
    }
}
