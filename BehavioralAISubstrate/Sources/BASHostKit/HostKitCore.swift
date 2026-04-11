import CryptoKit
import Foundation

@_exported import BASAdmin
@_exported import BASAppleAdapters
@_exported import BASEvaluation
@_exported import BASMemory
@_exported import BASObservability
@_exported import BASOrchestration
@_exported import BASPolicy
@_exported import BASRuntimeCore

public enum BASHostSessionKind: String, Codable, Sendable, CaseIterable {
    case quick
    case balance
    case mirror
    case reminder
    case reopen
    case watchHandoff
    case widget
    case notification
}

public enum BASHostLifecyclePhase: String, Codable, Sendable, CaseIterable {
    case initialAppearance
    case sceneActive

    var bootstrapPhase: BASAppleLifecycleBootstrapPhase {
        switch self {
        case .initialAppearance:
            .initialAppearance
        case .sceneActive:
            .sceneActive
        }
    }
}

public struct BASHostConsoleConfiguration: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var productionEnabled: Bool
    public var debugEntryPointTitle: String

    public init(
        isEnabled: Bool = true,
        productionEnabled: Bool = false,
        debugEntryPointTitle: String = "Substrate Console"
    ) {
        self.isEnabled = isEnabled
        self.productionEnabled = productionEnabled
        self.debugEntryPointTitle = debugEntryPointTitle
    }
}

public struct BASHostConfiguration: Codable, Equatable, Sendable {
    public var runtimeProfileID: String
    public var policyProfileID: String
    public var prefersPureLocal: Bool
    public var console: BASHostConsoleConfiguration

    public init(
        runtimeProfileID: String = "apple.local-first",
        policyProfileID: String = "private-sdk.fast-evolving",
        prefersPureLocal: Bool = true,
        console: BASHostConsoleConfiguration = BASHostConsoleConfiguration()
    ) {
        self.runtimeProfileID = runtimeProfileID
        self.policyProfileID = policyProfileID
        self.prefersPureLocal = prefersPureLocal
        self.console = console
    }
}

public struct BASHostDependencySet: Codable, Equatable, Sendable {
    public var protectedStorageProviderID: String
    public var handoffProviderID: String
    public var notificationProviderID: String
    public var modelRegistryID: String
    public var persistenceProviderID: String

    public init(
        protectedStorageProviderID: String = "apple.protected-storage",
        handoffProviderID: String = "apple.handoff",
        notificationProviderID: String = "apple.notifications",
        modelRegistryID: String = "behavioral-substrate.registry",
        persistenceProviderID: String = "swiftdata+protected-sidecar"
    ) {
        self.protectedStorageProviderID = protectedStorageProviderID
        self.handoffProviderID = handoffProviderID
        self.notificationProviderID = notificationProviderID
        self.modelRegistryID = modelRegistryID
        self.persistenceProviderID = persistenceProviderID
    }
}

public struct BASHostLifecycleRequest: Codable, Equatable, Sendable {
    public var phase: BASHostLifecyclePhase
    public var preferredMode: BASDecisionMode
    public var sourceSurface: BASInteractionSurface
    public var promptSeed: String
    public var riskLevel: BASRiskLevel

    public init(
        phase: BASHostLifecyclePhase,
        preferredMode: BASDecisionMode = .quick,
        sourceSurface: BASInteractionSurface = .app,
        promptSeed: String = "",
        riskLevel: BASRiskLevel = .low
    ) {
        self.phase = phase
        self.preferredMode = preferredMode
        self.sourceSurface = sourceSurface
        self.promptSeed = promptSeed
        self.riskLevel = riskLevel
    }
}

public struct BASHostSessionRequest: Codable, Equatable, Sendable {
    public var kind: BASHostSessionKind
    public var mode: BASDecisionMode
    public var surface: BASInteractionSurface
    public var prompt: String
    public var title: String?
    public var detail: String?
    public var riskLevel: BASRiskLevel
    public var triggerReason: String?

    public init(
        kind: BASHostSessionKind,
        mode: BASDecisionMode,
        surface: BASInteractionSurface = .app,
        prompt: String,
        title: String? = nil,
        detail: String? = nil,
        riskLevel: BASRiskLevel = .low,
        triggerReason: String? = nil
    ) {
        self.kind = kind
        self.mode = mode
        self.surface = surface
        self.prompt = prompt
        self.title = title
        self.detail = detail
        self.riskLevel = riskLevel
        self.triggerReason = triggerReason
    }
}

public struct BASHostReopenRequest: Codable, Equatable, Sendable {
    public var mode: BASDecisionMode
    public var title: String
    public var detail: String?
    public var promptSeed: String
    public var riskLevel: BASRiskLevel
    public var reopenHint: String?
    public var templateHint: String?
    public var interventionHistorySummary: String?

    public init(
        mode: BASDecisionMode,
        title: String,
        detail: String? = nil,
        promptSeed: String,
        riskLevel: BASRiskLevel = .low,
        reopenHint: String? = nil,
        templateHint: String? = nil,
        interventionHistorySummary: String? = nil
    ) {
        self.mode = mode
        self.title = title
        self.detail = detail
        self.promptSeed = promptSeed
        self.riskLevel = riskLevel
        self.reopenHint = reopenHint
        self.templateHint = templateHint
        self.interventionHistorySummary = interventionHistorySummary
    }
}

public struct BASHostSessionResult: Codable, Equatable, Sendable {
    public var requestKind: BASHostSessionKind
    public var currentBrain: BASCurrentBrainState
    public var projection: BASBrainProjection
    public var activeSessionTitle: String
    public var notices: [String]
    public var followUpActions: [String]
    public var interventionSuggestion: BASApplePredictiveInterventionSuggestion?
    public var consoleSnapshot: BASConsoleSnapshot

    public init(
        requestKind: BASHostSessionKind,
        currentBrain: BASCurrentBrainState,
        projection: BASBrainProjection,
        activeSessionTitle: String,
        notices: [String],
        followUpActions: [String],
        interventionSuggestion: BASApplePredictiveInterventionSuggestion? = nil,
        consoleSnapshot: BASConsoleSnapshot
    ) {
        self.requestKind = requestKind
        self.currentBrain = currentBrain
        self.projection = projection
        self.activeSessionTitle = activeSessionTitle
        self.notices = notices
        self.followUpActions = followUpActions
        self.interventionSuggestion = interventionSuggestion
        self.consoleSnapshot = consoleSnapshot
    }
}

public struct BASHostRuntime: Sendable {
    public let configuration: BASHostConfiguration
    public let dependencies: BASHostDependencySet

    public init(
        configuration: BASHostConfiguration = BASHostConfiguration(),
        dependencies: BASHostDependencySet = BASHostDependencySet()
    ) {
        self.configuration = configuration
        self.dependencies = dependencies
    }

    public func executeLifecyclePhase<Envelope, PendingRequest>(
        _ phase: BASHostLifecyclePhase,
        refreshMemoryProjection: () -> Void,
        refreshCurrentBrain: (String) -> Void,
        presentPendingReflection: () -> Void,
        consumeHandoff: () -> Envelope?,
        handleHandoff: (Envelope) -> Void,
        consumePendingRequest: () -> PendingRequest?,
        handlePendingRequest: (PendingRequest) -> Void,
        restoreActiveWorkspace: () -> Void,
        refreshPredictedIntervention: () -> Void,
        syncWidgetSnapshot: () -> Void = {}
    ) {
        BASAppleAppLifecycleOrchestrationExecutor.execute(
            phase: phase.bootstrapPhase,
            refreshMemoryProjection: refreshMemoryProjection,
            refreshCurrentBrain: refreshCurrentBrain,
            presentPendingReflection: presentPendingReflection,
            consumeHandoff: consumeHandoff,
            handleHandoff: handleHandoff,
            consumePendingRequest: consumePendingRequest,
            handlePendingRequest: handlePendingRequest,
            restoreActiveWorkspace: restoreActiveWorkspace,
            refreshPredictedIntervention: refreshPredictedIntervention,
            syncWidgetSnapshot: syncWidgetSnapshot
        )
    }

    public func consumeLifecycleEntriesIfNeeded<Envelope, PendingRequest>(
        consumeHandoff: () -> Envelope?,
        handleHandoff: (Envelope) -> Void,
        consumePendingRequest: () -> PendingRequest?,
        handlePendingRequest: (PendingRequest) -> Void
    ) {
        BASAppleAppLifecycleOrchestrationExecutor.consumeEntriesIfNeeded(
            consumeHandoff: consumeHandoff,
            handleHandoff: handleHandoff,
            consumePendingRequest: consumePendingRequest,
            handlePendingRequest: handlePendingRequest
        )
    }

    public func bootstrap(
        _ request: BASHostLifecycleRequest,
        now: Date = .now
    ) -> BASHostSessionResult {
        let bootstrapActions = BASAppleLifecycleBootstrapPlanner.actions(for: request.phase.bootstrapPhase)
        let baseRequest = BASHostSessionRequest(
            kind: .quick,
            mode: request.preferredMode,
            surface: request.sourceSurface,
            prompt: request.promptSeed.isEmpty ? "Load the current brain before speaking." : request.promptSeed,
            title: request.phase == .initialAppearance ? "App bootstrap" : "Scene refresh",
            riskLevel: request.riskLevel
        )
        var result = startSession(baseRequest, now: now)
        result.requestKind = .quick
        result.activeSessionTitle = request.phase == .initialAppearance ? "Lifecycle Bootstrap" : "Scene Activation"
        result.notices = bootstrapActions.map(\.hostNotice)
        result.followUpActions = bootstrapActions.compactMap(\.hostFollowUp)
        result.consoleSnapshot = consoleSnapshot(
            requestKind: .quick,
            currentBrain: result.currentBrain,
            notices: result.notices,
            followUpActions: result.followUpActions
        )
        return result
    }

    public func handleEntryIntent(
        _ request: BASHostSessionRequest,
        now: Date = .now
    ) -> BASHostSessionResult {
        startSession(request, now: now)
    }

    public func startSession(
        _ request: BASHostSessionRequest,
        now: Date = .now
    ) -> BASHostSessionResult {
        let projection = makeProjection(
            prompt: request.prompt,
            mode: request.mode,
            riskLevel: request.riskLevel,
            now: now
        )
        let bootstrapped = BASBrainCompiler.bootstrap(
            request: BASBrainBootstrapRequest(
                mode: request.mode,
                prompt: request.prompt,
                source: source(for: request.kind),
                sourceSurface: request.surface,
                riskLevel: request.riskLevel,
                retrievalMode: retrievalMode(for: request.kind),
                goalHints: goalHints(for: request),
                constraintHints: constraintHints(for: request),
                now: now
            ),
            projection: projection
        )
        let currentBrain = BASCurrentBrainState(
            mode: request.mode.rawValue,
            dominantGoals: compactGoals(primary: bootstrapped.dominantGoal, prompt: request.prompt),
            activeConstraints: bootstrapped.activeConstraints,
            reactionWeights: bootstrapped.brainState.reactionWeights,
            activeTemplateIDs: bootstrapped.activeTemplateIDs.map(deterministicUUID(for:)),
            recentFailurePatternIDs: bootstrapped.failureGuardIDs.map(deterministicUUID(for:)),
            retrievalTags: bootstrapped.brainState.retrievalTags,
            verificationSnapshot: verificationSnapshot(
                mode: request.mode,
                prompt: request.prompt,
                riskLevel: request.riskLevel
            )
        )
        let notices = baseNotices(for: request)
        let followUpActions = baseFollowUpActions(for: request)
        let interventionSuggestion = schedulePredictiveIntervention(for: request, now: now)
        return BASHostSessionResult(
            requestKind: request.kind,
            currentBrain: currentBrain,
            projection: projection,
            activeSessionTitle: request.title ?? "\(request.mode.title) session",
            notices: notices,
            followUpActions: followUpActions,
            interventionSuggestion: interventionSuggestion,
            consoleSnapshot: consoleSnapshot(
                requestKind: request.kind,
                currentBrain: currentBrain,
                notices: notices,
                followUpActions: followUpActions
            )
        )
    }

    public func reopen(
        _ request: BASHostReopenRequest,
        now: Date = .now
    ) -> BASHostSessionResult {
        let followUp = BASAppleTomorrowBoxReopenFollowUpBuilder.build(
            riskLevelID: request.riskLevel.rawValue,
            title: request.title,
            detail: request.detail,
            modeID: request.mode.rawValue,
            reopenHint: request.reopenHint,
            templateHint: request.templateHint,
            interventionHistorySummary: request.interventionHistorySummary,
            now: now
        )
        var result = startSession(
            BASHostSessionRequest(
                kind: .reopen,
                mode: request.mode,
                surface: .app,
                prompt: request.promptSeed,
                title: request.title,
                detail: request.detail,
                riskLevel: request.riskLevel,
                triggerReason: request.templateHint
            ),
            now: now
        )
        if let suggestion = followUp.interventionSuggestion {
            result.interventionSuggestion = BASApplePredictiveInterventionSuggestion(
                riskLevelID: suggestion.riskLevelID,
                title: suggestion.title,
                detail: suggestion.detail ?? "A prior hold suggests slowing this down.",
                evidenceSignalCount: suggestion.evidenceSignalCount,
                preferredModeID: suggestion.suggestedModeID,
                reason: suggestion.reason,
                expiresAt: suggestion.expiresAt
            )
            result.notices.append(suggestion.reason)
            result.followUpActions.append("Reopen with \(request.mode.title.lowercased()) structure")
            result.consoleSnapshot = consoleSnapshot(
                requestKind: .reopen,
                currentBrain: result.currentBrain,
                notices: result.notices,
                followUpActions: result.followUpActions
            )
        }
        return result
    }

    public func refreshCurrentBrain(
        for request: BASHostSessionRequest,
        now: Date = .now
    ) -> BASCurrentBrainState {
        startSession(request, now: now).currentBrain
    }

    public func schedulePredictiveIntervention(
        for request: BASHostSessionRequest,
        now: Date = .now
    ) -> BASApplePredictiveInterventionSuggestion? {
        guard request.riskLevel >= .medium else { return nil }
        let title = request.riskLevel == .high ? "Add more friction before acting." : "Pause before you decide."
        let detail = request.kind == .reopen
            ? "This reopen path is carrying risk, so the substrate is asking for more structure."
            : "The substrate detected a context that benefits from one slower step."
        return BASApplePredictiveInterventionSuggestion(
            riskLevelID: request.riskLevel.rawValue,
            title: title,
            detail: detail,
            evidenceSignalCount: request.triggerReason == nil ? 1 : 2,
            preferredModeID: request.mode.rawValue,
            reason: request.triggerReason ?? "Risk-aware policy prefers a slower path here.",
            expiresAt: now.addingTimeInterval(30 * 60)
        )
    }

    private func makeProjection(
        prompt: String,
        mode: BASDecisionMode,
        riskLevel: BASRiskLevel,
        now: Date
    ) -> BASBrainProjection {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            return BASBrainProjection(
                records: [],
                candidates: [],
                recentEvents: [],
                governanceSnapshot: .empty,
                activeTemplateIDs: templateIDs(for: mode),
                failureGuardIDs: failureGuardIDs(for: riskLevel)
            )
        }

        let event = BASEventRecord(
            kind: .situational,
            content: trimmedPrompt,
            timestamp: now,
            tags: hostTags(for: mode, riskLevel: riskLevel),
            entrySourceID: "hostkit"
        )
        let memory = BASGovernedMemory(
            kind: .situational,
            content: trimmedPrompt,
            scope: .session,
            sensitivity: riskLevel == .high ? .high : .medium,
            tier: .hot,
            confidence: riskLevel == .high ? 0.92 : 0.80,
            sourceType: source(for: mode).rawValue,
            lastConfirmedAt: now,
            governanceStatus: .governed,
            provenanceSummary: "hostkit session request"
        )
        return BASBrainProjection(
            records: [memory],
            candidates: [],
            recentEvents: [event],
            embeddingScoresByID: [memory.id.uuidString: 0.9],
            governanceSnapshot: BASMemoryGovernanceState(
                totalRecordCount: 1,
                totalCandidateCount: 0,
                pendingCandidateCount: 0,
                promotedCandidateCount: 1,
                loadedPromotedMemoryCount: 1,
                loadedPendingMemoryCount: 0
            ),
            activeTemplateIDs: templateIDs(for: mode),
            failureGuardIDs: failureGuardIDs(for: riskLevel)
        )
    }

    private func consoleSnapshot(
        requestKind: BASHostSessionKind,
        currentBrain: BASCurrentBrainState,
        notices: [String],
        followUpActions: [String]
    ) -> BASConsoleSnapshot {
        BASFlightDeckBuilder().build(
            from: BASFlightDeckInput(
                overallSummary: "BASHostKit is serving \(requestKind.rawValue) through the private SDK façade.",
                runtimeSummary: configuration.prefersPureLocal
                    ? "Local-first façade using \(dependencies.modelRegistryID)."
                    : "Hybrid-ready façade using \(dependencies.modelRegistryID).",
                brainSummary: "\(currentBrain.mode.capitalized) • \(currentBrain.dominantGoals.prefix(2).joined(separator: " • "))",
                layerMetrics: [
                    BASFlightDeckLayerMetric(kind: .runtime, score: 0.97, summary: "Routing and execution are owned by the substrate façade."),
                    BASFlightDeckLayerMetric(kind: .data, score: 0.95, summary: "Host dependencies resolve through \(dependencies.persistenceProviderID)."),
                    BASFlightDeckLayerMetric(kind: .memory, score: currentBrain.dominantGoals.isEmpty ? 0.82 : 0.94, summary: "Current brain loaded with governed retrieval tags."),
                    BASFlightDeckLayerMetric(kind: .security, score: configuration.prefersPureLocal ? 0.96 : 0.84, summary: "Policy profile \(configuration.policyProfileID) is active."),
                    BASFlightDeckLayerMetric(kind: .orchestration, score: 0.92, summary: followUpActions.isEmpty ? "Session orchestration is ready." : followUpActions.joined(separator: " • ")),
                    BASFlightDeckLayerMetric(kind: .observability, score: 0.90, summary: notices.prefix(2).joined(separator: " • ")),
                    BASFlightDeckLayerMetric(kind: .evaluation, score: 0.88, summary: "Fast-evolving private SDK contract is covered by façade tests."),
                    BASFlightDeckLayerMetric(kind: .delivery, score: configuration.console.isEnabled ? 0.94 : 0.82, summary: "Host kit is ready for private integration.")
                ],
                isPureLocal: configuration.prefersPureLocal
            )
        )
    }

    private func baseNotices(for request: BASHostSessionRequest) -> [String] {
        var notices = [
            "\(request.surface.title) entered \(request.mode.title.lowercased()) through BASHostKit.",
            "Runtime profile \(configuration.runtimeProfileID) is active."
        ]
        if let triggerReason = request.triggerReason, !triggerReason.isEmpty {
            notices.append(triggerReason)
        }
        return notices
    }

    private func baseFollowUpActions(for request: BASHostSessionRequest) -> [String] {
        let baseActions: [String]
        switch request.mode {
        case .quick:
            baseActions = ["Pause once", "Name the next move"]
        case .balance:
            baseActions = ["Compare tradeoffs", "Name the cost of waiting"]
        case .mirror:
            baseActions = ["Slow the narrative", "Pull one honest reflection"]
        }

        if request.riskLevel == .high {
            return baseActions + ["Require stronger confirmation"]
        }
        return baseActions
    }

    private func goalHints(for request: BASHostSessionRequest) -> [String] {
        [request.title, request.prompt]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func constraintHints(for request: BASHostSessionRequest) -> [String] {
        var constraints = ["private-sdk", configuration.policyProfileID]
        if request.riskLevel == .high {
            constraints.append("high-risk-confirmation")
        }
        if request.kind == .notification || request.kind == .watchHandoff {
            constraints.append("low-friction-surface")
        }
        return constraints
    }

    private func templateIDs(for mode: BASDecisionMode) -> [String] {
        switch mode {
        case .quick:
            ["template/night-message-cooling"]
        case .balance:
            ["template/impulse-buy-cooling"]
        case .mirror:
            ["template/self-blame-recovery"]
        }
    }

    private func failureGuardIDs(for riskLevel: BASRiskLevel) -> [String] {
        guard riskLevel >= .medium else { return [] }
        return ["guard/high-risk-delay"]
    }

    private func retrievalMode(for kind: BASHostSessionKind) -> String {
        switch kind {
        case .quick, .watchHandoff, .widget:
            "compact"
        case .balance, .mirror, .reopen:
            "full"
        case .reminder, .notification:
            "guarded"
        }
    }

    private func source(for kind: BASHostSessionKind) -> BASMemorySource {
        switch kind {
        case .quick, .watchHandoff, .widget:
            .pattern
        case .balance:
            .history
        case .mirror:
            .reflection
        case .reminder, .reopen, .notification:
            .reminder
        }
    }

    private func source(for mode: BASDecisionMode) -> BASMemorySource {
        switch mode {
        case .quick:
            .pattern
        case .balance:
            .history
        case .mirror:
            .reflection
        }
    }

    private func compactGoals(primary: String?, prompt: String) -> [String] {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return [primary, trimmedPrompt.isEmpty ? "Stay clear before acting." : trimmedPrompt]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
    }

    private func verificationSnapshot(
        mode: BASDecisionMode,
        prompt: String,
        riskLevel: BASRiskLevel
    ) -> String {
        "hostkit/\(mode.rawValue)/\(riskLevel.rawValue)/\(fingerprint(for: prompt))"
    }

    private func hostTags(
        for mode: BASDecisionMode,
        riskLevel: BASRiskLevel
    ) -> [String] {
        ["mode:\(mode.rawValue)", "risk:\(riskLevel.rawValue)", "source:hostkit"]
    }

    private func deterministicUUID(for value: String) -> UUID {
        let digest = SHA256.hash(data: Data(value.utf8))
        let bytes = Array(digest.prefix(16))
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private func fingerprint(for value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
}

private extension BASAppleLifecycleBootstrapAction {
    var hostNotice: String {
        switch kind {
        case .refreshMemoryProjection:
            "Refresh memory projection"
        case .refreshCurrentBrain:
            "Refresh current brain"
        case .presentPendingReflection:
            "Present pending reflection"
        case .consumePendingLaunchRequest:
            "Consume pending launch request"
        case .restoreActiveWorkspace:
            "Restore active workspace"
        case .refreshPredictedIntervention:
            "Refresh predictive intervention"
        case .syncWidgetSnapshot:
            "Sync widget snapshot"
        }
    }

    var hostFollowUp: String? {
        switch kind {
        case .refreshCurrentBrain:
            "Load the current brain before rendering"
        case .restoreActiveWorkspace:
            "Resume the last structured workspace"
        case .refreshPredictedIntervention:
            "Recompute the guarded intervention state"
        default:
            nil
        }
    }
}
