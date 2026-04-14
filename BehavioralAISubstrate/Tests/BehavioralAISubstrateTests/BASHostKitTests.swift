import XCTest
@testable import BASAdmin
@testable import BASHostKit

final class BASHostKitTests: XCTestCase {
    private func makeGenericRuntime() -> BASHostRuntime {
        BASHostRuntime(configuration: .generic)
    }

    private func makeConfiguration(
        runtimeProfileID: String = "host.default-runtime",
        policyProfileID: String = "host.default-policy",
        prefersPureLocal: Bool = true,
        console: BASHostConsoleConfiguration = .generic,
        lifecycleBehavior: BASHostLifecycleBehaviorConfiguration = .generic,
        workflowBehavior: BASHostWorkflowBehaviorConfiguration = .generic,
        cognitionBehavior: BASHostCognitionBehaviorConfiguration = .generic,
        presentation: BASHostPresentationConfiguration = .generic
    ) -> BASHostConfiguration {
        BASHostConfiguration(
            runtimeProfileID: runtimeProfileID,
            policyProfileID: policyProfileID,
            prefersPureLocal: prefersPureLocal,
            console: console,
            lifecycleBehavior: lifecycleBehavior,
            workflowBehavior: workflowBehavior,
            cognitionBehavior: cognitionBehavior,
            presentation: presentation
        )
    }

    func testStartSessionBuildsCurrentBrainAndConsoleSnapshot() throws {
        let runtime = makeGenericRuntime()

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: "I need to slow down before I send this message.",
                title: "Reflect on this decision",
                riskLevel: .medium
            )
        )

        XCTAssertEqual(result.requestKind, .interactive)
        XCTAssertEqual(result.workflowProfile, .reflective)
        XCTAssertEqual(result.currentBrain.workflowProfile, .reflective)
        XCTAssertEqual(result.currentBrain.workflowTitle, "Reflective")
        XCTAssertFalse(result.currentBrain.roleID.isEmpty)
        XCTAssertFalse(result.currentBrain.relationshipBoundary.isEmpty)
        XCTAssertFalse(result.currentBrain.boundaryHeadline.isEmpty)
        XCTAssertGreaterThan(result.currentBrain.confidenceCeiling, 0)
        XCTAssertFalse(result.currentBrain.dominantGoals.isEmpty)
        XCTAssertFalse(result.currentBrain.boundaryConstraints.isEmpty)
        XCTAssertFalse(result.consoleSnapshot.reports.isEmpty)
        XCTAssertEqual(result.consoleSnapshot.reports.count, BASLayerKind.allCases.count)
        XCTAssertNotNil(result.consoleSnapshot.programExecutionBlueprint)
        XCTAssertEqual(result.consoleSnapshot.currentProgramExecutionBlueprint.governedSchemas.count, BASEBrainSchemaGovernanceRegistry.governedSchemas.count)
        XCTAssertNotNil(result.consoleSnapshot.inspectionBundle)
        XCTAssertTrue(result.consoleSnapshot.runtimeSummary?.contains("permit") == true)
        XCTAssertTrue(result.consoleSnapshot.brainSummary?.contains("Host") == true)
        XCTAssertNotNil(result.eBrainTurn)
        XCTAssertEqual(result.eBrainTurn?.budgetFrame.runMode, .engage)
        XCTAssertEqual(result.eBrainTurn?.contextFrame.taskType, .chat)
        XCTAssertEqual(result.eBrainTurn?.updateTickets.count, 1)
        XCTAssertFalse(result.eBrainTurn?.thoughtFold.checksum.isEmpty ?? true)
        XCTAssertEqual(result.eBrainTurn?.thoughtFold.compactSlots["task_type"], BASContextTaskType.chat.rawValue)
        XCTAssertEqual(result.eBrainTurn?.runtimeTrace.modelRoute, BASDeviceRoute.coreNPU.rawValue)
        XCTAssertGreaterThan(result.eBrainTurn?.runtimeTrace.loopCount ?? 0, 0)
        XCTAssertTrue(result.eBrainTurn?.runtimeTrace.layerEvents.contains(where: { $0.layerID == "L3" }) ?? false)
        XCTAssertEqual(result.eBrainTurn?.evolutionLineageSummary.sessionID, result.eBrainTurn?.runtimeTrace.sessionID)
        XCTAssertEqual(result.eBrainTurn?.evolutionLineageSummary.permitMode, result.eBrainTurn?.actionPermit.mode.rawValue)
        XCTAssertEqual(result.eBrainTurn?.evolutionLineageSummary.riskLevel, result.eBrainTurn?.riskCard.riskLevel.rawValue)
        XCTAssertTrue(result.consoleSnapshot.blockerSummary.contains(where: { $0.contains("review") || $0.contains("delay") || $0.contains("risk") }) || result.consoleSnapshot.blockerSummary.isEmpty)
        XCTAssertNotNil(result.interventionSuggestion)
    }

    func testBootstrapUsesLifecyclePlannerNotices() throws {
        let runtime = makeGenericRuntime()

        let result = try runtime.bootstrap(
            BASHostLifecycleRequest(
                phase: .initialAppearance,
                sessionKind: .ambient,
                preferredProfile: .primary,
                sourceSurface: .application,
                promptSeed: "Load the substrate before the UI asks for help.",
                riskLevel: .low
            )
        )

        XCTAssertEqual(result.activeSessionTitle, "Initial Appearance")
        XCTAssertEqual(result.requestKind, .ambient)
        XCTAssertTrue(result.notices.contains("Refresh substrate projection"))
        XCTAssertTrue(result.followUpActions.contains("Load current state for presentation"))
    }

    func testCustomLifecycleBehaviorBelongsToHost() throws {
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(
                lifecycleBehavior: BASHostLifecycleBehaviorConfiguration(
                    bootstrapBehavior: BASAppleLifecycleBootstrapBehavior(
                        actionsByPhaseID: [
                            BASAppleLifecycleBootstrapPhase.initialAppearance.rawValue: [
                                BASAppleLifecycleBootstrapAction(kind: .refreshCurrentBrain, bootstrapTriggerID: "hostLaunch"),
                                BASAppleLifecycleBootstrapAction(kind: .restoreActiveWorkspace)
                            ]
                        ]
                    )
                ),
                presentation: BASHostPresentationConfiguration(
                    lifecycle: BASHostLifecyclePresentation(
                        refreshCurrentBrainNotice: "Host refresh brain",
                        restoreActiveWorkspaceNotice: "Host restore workspace",
                        loadCurrentBrainFollowUp: "Host loads first",
                        resumeStructuredWorkspaceFollowUp: "Host resumes workspace"
                    )
                )
            )
        )

        let result = try runtime.bootstrap(
            BASHostLifecycleRequest(
                phase: .initialAppearance,
                sessionKind: .ambient,
                preferredProfile: .primary,
                sourceSurface: .application,
                promptSeed: "Host bootstrap",
                riskLevel: .low
            )
        )

        XCTAssertEqual(result.notices, ["Host refresh brain", "Host restore workspace"])
        XCTAssertEqual(result.followUpActions, ["Host loads first", "Host resumes workspace"])
    }

    func testWorkflowBehaviorUsesGenericProviderObservationKeys() {
        let workflowBehavior = BASHostWorkflowBehaviorConfiguration(
            providerObservationNarrativesByKindID: [
                BASDecisionMode.primaryID: BASAppleProviderObservationNarrative(
                    templatePinnedDetail: "Host owns the rapid pass copy.",
                    admissionSkippedDetailPrefix: "Host skipped the rapid pass.",
                    deterministicFallbackBase: "Host kept the rapid draft.",
                    cachedConsistencySource: "cached rapid pass",
                    providerConsistencySource: "provider rapid pass"
                )
            ]
        )

        XCTAssertEqual(
            workflowBehavior.providerObservationNarrative(forKindID: BASDecisionMode.primaryID)?.cachedConsistencySource,
            "cached rapid pass"
        )
        XCTAssertNil(workflowBehavior.providerObservationNarrative(forKindID: "legacy-primary"))
    }

    func testReopenHighRiskProducesFollowUpSuggestion() throws {
        let runtime = makeGenericRuntime()

        let result = try runtime.reopen(
            BASHostReopenRequest(
                workflowProfile: .comparative,
                title: "Reopen this choice",
                detail: "There is enough risk here that we want more structure.",
                promptSeed: "Look at the cost of acting tonight.",
                riskLevel: .high,
                templateHint: "Use the cooling template.",
                interventionHistorySummary: "Night-time messages go worse without delay."
            )
        )

        XCTAssertEqual(result.requestKind, .reopen)
        XCTAssertEqual(result.workflowProfile, .comparative)
        XCTAssertEqual(result.currentBrain.workflowProfile, .comparative)
        XCTAssertEqual(result.currentBrain.failureGuardCount, 0)
        XCTAssertNotNil(result.interventionSuggestion)
        XCTAssertTrue(result.followUpActions.contains("Require confirmation"))
    }

    func testHostWorkflowProfilesUseGenericIdentifiers() throws {
        XCTAssertEqual(BASHostWorkflowProfile.primary.rawValue, "primary")
        XCTAssertEqual(BASHostWorkflowProfile.comparative.rawValue, "comparative")
        XCTAssertEqual(try JSONDecoder().decode(BASHostWorkflowProfile.self, from: Data(#""primary""#.utf8)), .primary)
        XCTAssertEqual(try JSONDecoder().decode(BASHostWorkflowProfile.self, from: Data(#""comparative""#.utf8)), .comparative)
    }

    func testCustomPresentationLetsHostOwnWorkflowLanguage() throws {
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(
                runtimeProfileID: "atlas.field-runtime",
                presentation: BASHostPresentationConfiguration(
                    workflowTitles: BASHostWorkflowTitles(
                        primary: "Scan Lane",
                        comparative: "Fork Lane",
                        reflective: "Archive Lane"
                    ),
                    surfaceTitles: BASHostSurfaceTitles(
                        application: "App",
                        wearable: "Watch",
                        widget: "Widget",
                        shortcut: "Shortcut",
                        voiceAssistant: "Siri",
                        notification: "Notification",
                        system: "System"
                    ),
                    sessionTitles: BASHostSessionTitles(
                        primary: "Scan Lane",
                        comparative: "Fork Lane",
                        reflective: "Archive Lane",
                        initialAppearance: "Atlas Bootstrap",
                        sceneActive: "Atlas Refresh"
                    ),
                    followUpActions: BASHostFollowUpActions(
                        primary: ["Scan the active pressure", "Pick one bounded next move"],
                        comparative: ["Fork the active trade-off", "Name one constraint and one opening"],
                        reflective: ["Archive the pattern", "Keep one anchor visible"],
                        highRiskEscalation: ["Require stronger confirmation"]
                    ),
                    lifecycle: BASHostLifecyclePresentation(
                        refreshMemoryProjectionNotice: "Refresh Atlas projection",
                        refreshCurrentBrainNotice: "Refresh Atlas state",
                        presentPendingReflectionNotice: "Present the deferred archive step",
                        consumePendingLaunchRequestNotice: "Consume the deferred Atlas launch",
                        restoreActiveWorkspaceNotice: "Restore the Atlas workspace",
                        refreshPredictedInterventionNotice: "Refresh the guarded Atlas suggestion",
                        syncWidgetSnapshotNotice: "Sync the Atlas widget snapshot",
                        loadCurrentBrainFollowUp: "Load Atlas state before rendering",
                        resumeStructuredWorkspaceFollowUp: "Resume the Atlas workspace",
                        recomputeGuardedInterventionFollowUp: "Recompute the guarded Atlas suggestion"
                    ),
                    notices: BASHostNoticeTemplates(
                        enteredWorkflow: "{surface} entered {workflow} through Atlas.",
                        runtimeProfile: "Atlas runtime profile {runtimeProfile} is active.",
                        reopenFollowUpAction: "Reopen through {workflow}",
                        emptyPromptGoalFallback: "Atlas keeps the lane narrow first."
                    ),
                    predictiveIntervention: BASHostPredictiveInterventionPresentation(
                        mediumRiskTitle: "Atlas suggests a slower scan.",
                        mediumRiskDetail: "Atlas sees a context that benefits from one lower-pressure pass.",
                        highRiskTitle: "Atlas wants a stronger checkpoint.",
                        highRiskDetail: "Atlas sees elevated risk and wants stronger confirmation before the next move.",
                        reopenRiskDetail: "This reopen path is carrying risk, so Atlas is asking for more structure.",
                        fallbackReopenSuggestionDetail: "A prior Atlas hold suggests slowing this down.",
                        defaultReason: "Atlas prefers a lower-pressure path here."
                    )
                )
            )
        )

        let session = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "I want to move fast.",
                riskLevel: .low
            )
        )
        let bootstrap = try runtime.bootstrap(
            BASHostLifecycleRequest(
                phase: .initialAppearance,
                sessionKind: .ambient,
                preferredProfile: .primary,
                sourceSurface: .application,
                promptSeed: "Load the current brain before speaking.",
                riskLevel: .low
            )
        )

        XCTAssertEqual(session.activeSessionTitle, "Scan Lane")
        XCTAssertTrue(
            session.notices.contains { notice in
                notice.contains("Atlas runtime profile") && notice.contains("atlas.field-runtime")
            }
        )
        XCTAssertEqual(session.followUpActions, ["Scan the active pressure", "Pick one bounded next move"])
        XCTAssertEqual(bootstrap.activeSessionTitle, "Atlas Bootstrap")
        XCTAssertTrue(bootstrap.notices.contains("Refresh Atlas projection"))
        XCTAssertTrue(bootstrap.followUpActions.contains("Load Atlas state before rendering"))
    }

    func testCustomPredictiveInterventionCopyBelongsToHost() throws {
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(
                lifecycleBehavior: BASHostLifecycleBehaviorConfiguration(
                    predictiveInterventionBehavior: BASApplePredictiveInterventionBehavior(
                        lowRisk: BASApplePredictiveInterventionRiskBehavior(
                            title: "Host says soften it.",
                            detail: "Host wants a lighter pass.",
                            preferredModeID: BASDecisionMode.primary.identifier
                        ),
                        mediumRisk: BASApplePredictiveInterventionRiskBehavior(
                            title: "Host says pause.",
                            detail: "Host wants one slower pass.",
                            preferredModeID: BASDecisionMode.comparative.identifier
                        ),
                        highRisk: BASApplePredictiveInterventionRiskBehavior(
                            title: "Host wants another checkpoint.",
                            detail: "Host sees elevated risk and wants stronger confirmation.",
                            preferredModeID: BASDecisionMode.reflective.identifier
                        ),
                        defaultReason: "Host policy prefers a slower workflow."
                    )
                ),
                presentation: BASHostPresentationConfiguration(
                    predictiveIntervention: BASHostPredictiveInterventionPresentation(
                        reopenRiskDetail: "Host sees risk in this reopen path and wants structure.",
                        fallbackReopenSuggestionDetail: "Host says slow this reopen down."
                    )
                )
            )
        )

        let session = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .comparative,
                surface: .application,
                prompt: "I need to compare these options carefully.",
                riskLevel: .medium
            )
        )
        let reopen = try runtime.reopen(
            BASHostReopenRequest(
                workflowProfile: .comparative,
                title: "Reopen this choice",
                promptSeed: "Look at the cost of acting tonight.",
                riskLevel: .high,
                templateHint: "Use the cooling template."
            )
        )

        XCTAssertEqual(session.interventionSuggestion?.title, "Host says pause.")
        XCTAssertEqual(session.interventionSuggestion?.detail, "Host wants one slower pass.")
        XCTAssertEqual(session.interventionSuggestion?.reason, "Host policy prefers a slower workflow.")
        XCTAssertEqual(session.interventionSuggestion?.preferredWorkflowProfile, .comparative)
        XCTAssertEqual(reopen.interventionSuggestion?.detail, "Host says slow this reopen down.")
    }

    func testPreferredPredictiveWorkflowUsesHostModeMapping() throws {
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(
                lifecycleBehavior: BASHostLifecycleBehaviorConfiguration(
                    predictiveInterventionBehavior: BASApplePredictiveInterventionBehavior(
                        mediumRisk: BASApplePredictiveInterventionRiskBehavior(
                            title: "Use more structure",
                            detail: "The host wants the comparative workflow next.",
                            preferredModeID: BASDecisionMode.comparativeID
                        )
                    )
                ),
                workflowBehavior: BASHostWorkflowBehaviorConfiguration(
                    modeIDsByProfileID: [
                        BASHostWorkflowProfile.primary.rawValue: BASDecisionMode.reflectiveID,
                        BASHostWorkflowProfile.comparative.rawValue: BASDecisionMode.primaryID,
                        BASHostWorkflowProfile.reflective.rawValue: BASDecisionMode.comparativeID
                    ]
                )
            )
        )

        let session = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Slow this down for one more pass.",
                riskLevel: .medium
            )
        )

        XCTAssertEqual(session.interventionSuggestion?.preferredWorkflowProfile, .reflective)
    }

    func testHostKitSupportsForeignHostVocabularyWithoutLegacyCopy() throws {
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(
                runtimeProfileID: "atlas.field-runtime",
                workflowBehavior: BASHostWorkflowBehaviorConfiguration(
                    modeIDsByProfileID: [
                        BASHostWorkflowProfile.primary.rawValue: BASDecisionMode.primaryID,
                        BASHostWorkflowProfile.comparative.rawValue: BASDecisionMode.comparativeID,
                        BASHostWorkflowProfile.reflective.rawValue: BASDecisionMode.reflectiveID
                    ],
                    providerObservationNarrativesByKindID: [
                        BASDecisionMode.primaryID: BASAppleProviderObservationNarrative(
                            templatePinnedDetail: "Atlas pinned the Scan Lane draft.",
                            admissionSkippedDetailPrefix: "Atlas skipped the Scan Lane pass.",
                            deterministicFallbackBase: "Atlas kept the deterministic Scan Lane draft.",
                            cachedConsistencySource: "cached Scan Lane",
                            providerConsistencySource: "provider Scan Lane"
                        )
                    ],
                    hostNamespace: "atlas"
                ),
                presentation: BASHostPresentationConfiguration(
                    workflowTitles: BASHostWorkflowTitles(
                        primary: "Scan Lane",
                        comparative: "Fork Lane",
                        reflective: "Archive Lane"
                    ),
                    sessionTitles: BASHostSessionTitles(
                        primary: "Scan Lane",
                        comparative: "Fork Lane",
                        reflective: "Archive Lane",
                        initialAppearance: "Atlas Bootstrap",
                        sceneActive: "Atlas Refresh"
                    ),
                    notices: BASHostNoticeTemplates(
                        enteredWorkflow: "{surface} entered {workflow} through Atlas.",
                        runtimeProfile: "Atlas runtime profile {runtimeProfile} is active.",
                        reopenFollowUpAction: "Reopen through {workflow}",
                        emptyPromptGoalFallback: "Atlas keeps the lane narrow first."
                    )
                )
            )
        )

        let session = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Atlas wants a first-pass scan.",
                riskLevel: .low
            )
        )

        XCTAssertEqual(session.activeSessionTitle, "Scan Lane")
        XCTAssertTrue(
            session.notices.contains { notice in
                notice.contains("Atlas") && notice.localizedCaseInsensitiveContains("Scan Lane")
            }
        )
        XCTAssertTrue(session.notices.contains("Atlas runtime profile atlas.field-runtime is active."))
        XCTAssertEqual(
            runtime.configuration.workflowBehavior.providerObservationNarrative(forKindID: BASDecisionMode.primaryID)?.providerConsistencySource,
            "provider Scan Lane"
        )
    }

    func testLifecycleBehaviorCarriesHostOwnedProjectionLimits() {
        let configuration = makeConfiguration(
            lifecycleBehavior: BASHostLifecycleBehaviorConfiguration(
                projectionRefreshLimits: BASAppleMemoryProjectionRefreshLimits(
                    recordLimit: 48,
                    candidateLimit: 20,
                    checkEventLimit: 64,
                    comparativeRecordLimit: 20,
                    reflectiveRecordLimit: 20
                )
            )
        )

        XCTAssertEqual(configuration.lifecycleBehavior.projectionRefreshLimits.recordLimit, 48)
        XCTAssertEqual(configuration.lifecycleBehavior.projectionRefreshLimits.candidateLimit, 20)
        XCTAssertEqual(configuration.lifecycleBehavior.projectionRefreshLimits.checkEventLimit, 64)
        XCTAssertEqual(configuration.lifecycleBehavior.projectionRefreshLimits.comparativeRecordLimit, 20)
        XCTAssertEqual(configuration.lifecycleBehavior.projectionRefreshLimits.reflectiveRecordLimit, 20)
    }

    func testWorkflowBehaviorCanOwnSessionKindDefaults() {
        let configuration = BASHostWorkflowBehaviorConfiguration(
            memorySourceIDsBySessionKindID: [
                BASHostSessionKind.notification.rawValue: BASMemorySource.reflection.rawValue
            ],
            retrievalModeIDsBySessionKindID: [
                BASHostSessionKind.widget.rawValue: "host-widget-compact"
            ]
        )

        XCTAssertEqual(configuration.memorySource(for: .notification), .reflection)
        XCTAssertNil(configuration.memorySource(for: .interactive))
        XCTAssertEqual(configuration.retrievalMode(for: .widget), "host-widget-compact")
        XCTAssertNil(configuration.retrievalMode(for: .interactive))
    }

    func testWorkflowBehaviorOwnsModeMappingAndUsesExplicitGenericDefaults() throws {
        let configuration = BASHostWorkflowBehaviorConfiguration(
            modeIDsByProfileID: [
                BASHostWorkflowProfile.primary.rawValue: BASDecisionMode.reflectiveID,
                BASHostWorkflowProfile.comparative.rawValue: BASDecisionMode.primaryID,
                BASHostWorkflowProfile.reflective.rawValue: BASDecisionMode.comparativeID
            ]
        )
        let genericConfiguration = BASHostWorkflowBehaviorConfiguration.generic

        XCTAssertEqual(try configuration.mode(for: .primary), .reflective)
        XCTAssertEqual(try configuration.mode(for: .comparative), .primary)
        XCTAssertEqual(configuration.workflowProfile(forModeID: BASDecisionMode.comparativeID), .reflective)
        XCTAssertEqual(try configuration.interactiveRetrievalMode(for: .primary), BASRetrievalMode.adaptive.rawValue)
        XCTAssertNil(configuration.defaultMemorySource(for: .reopen))
        XCTAssertNil(configuration.defaultRetrievalMode(for: .reopen))
        XCTAssertEqual(genericConfiguration.defaultMemorySource(for: .reopen), .archive)
        XCTAssertEqual(genericConfiguration.defaultRetrievalMode(for: .reopen), BASRetrievalMode.adaptive.rawValue)
    }

    func testCustomWorkflowBehaviorBelongsToHost() throws {
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(
                workflowBehavior: BASHostWorkflowBehaviorConfiguration(
                    templateIDsByProfileID: [
                        BASHostWorkflowProfile.primary.rawValue: ["atlas.template.scan-lane"]
                    ],
                    memorySourceIDsByProfileID: [
                        BASHostWorkflowProfile.primary.rawValue: BASMemorySource.archive.rawValue
                    ],
                    interactiveRetrievalModeByProfileID: [
                        BASHostWorkflowProfile.primary.rawValue: "balanced"
                    ],
                    hostNamespace: "atlas-sdk"
                )
            )
        )

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "I need one cleaner pass before I act.",
                riskLevel: .low
            )
        )

        XCTAssertEqual(result.projection.activeTemplateIDs, ["atlas.template.scan-lane"])
        XCTAssertEqual(result.currentBrain.verificationSummary.split(separator: "/").first, "atlas-sdk")
    }

    func testGenericWorkflowDefaultsStayNeutralUntilHostInjectsProductSemantics() throws {
        let runtime = makeGenericRuntime()

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Hold the state steady for one more pass.",
                riskLevel: .low
            )
        )

        XCTAssertTrue(result.projection.activeTemplateIDs.isEmpty)
        XCTAssertEqual(result.currentBrain.activeTemplateCount, 0)
        XCTAssertTrue(result.currentBrain.verificationSummary.hasPrefix("host/"))
        XCTAssertEqual(result.currentBrain.workflowTitle, "Primary")
        XCTAssertEqual(result.activeSessionTitle, "Primary")
    }

    func testWorkflowBehaviorLetsHostOwnFailureGuardIdentifiers() throws {
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(
                workflowBehavior: BASHostWorkflowBehaviorConfiguration(
                    failureGuardIDsByRiskLevelID: [
                        BASHostRiskLevel.high.rawValue: ["samplehost.guard/elevated-risk"]
                    ],
                    hostNamespace: "samplehost"
                )
            )
        )

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .comparative,
                surface: .application,
                prompt: "This needs another checkpoint before I commit.",
                riskLevel: .high
            )
        )

        XCTAssertEqual(result.currentBrain.failureGuardCount, 1)
    }

    func testDefaultHighRiskGuardStaysEmptyUntilHostInjectsPolicy() throws {
        let runtime = makeGenericRuntime()

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .comparative,
                surface: .application,
                prompt: "This needs another checkpoint before I commit.",
                riskLevel: .high
            )
        )

        XCTAssertEqual(result.currentBrain.failureGuardCount, 0)
        XCTAssertTrue(result.currentBrain.verificationSummary.hasPrefix("host/"))
    }

    func testExecuteLifecyclePhaseDelegatesEntryConsumptionAndRefreshOrder() {
        let runtime = makeGenericRuntime()
        var actions: [String] = []

        runtime.executeLifecyclePhase(
            .initialAppearance,
            refreshMemoryProjection: { actions.append("projection") },
            refreshCurrentBrain: { actions.append("brain:\($0)") },
            presentPendingReflection: { actions.append("reflection") },
            consumeHandoff: { "handoff" },
            handleHandoff: { envelope in actions.append("handoff:\(envelope)") },
            consumePendingRequest: { nil as String? },
            handlePendingRequest: { request in actions.append("pending:\(request)") },
            restoreActiveWorkspace: { actions.append("restore") },
            refreshPredictedIntervention: { actions.append("prediction") },
            syncWidgetSnapshot: { actions.append("widget") }
        )

        XCTAssertEqual(
            actions,
            [
                "projection",
                "brain:launch",
                "handoff:handoff"
            ]
        )
    }

    func testCommitProjectionRefreshPublishesProjectionAndNotice() {
        let runtime = makeGenericRuntime()
        var committedProjection: String?
        var dirtyFlag = true
        var publishedNotice: String?

        runtime.commitProjectionRefresh(
            outcome: BASAppleProjectionRefreshResult(
                projection: "projection",
                refreshed: true,
                notice: "refresh notice"
            ),
            commitProjection: { committedProjection = $0 },
            setProjectionDirty: { dirtyFlag = $0 },
            publishNotice: { publishedNotice = $0 }
        )

        XCTAssertEqual(committedProjection, "projection")
        XCTAssertFalse(dirtyFlag)
        XCTAssertEqual(publishedNotice, "refresh notice")
    }

    func testResolveProjectionRefreshUsesResolverAndCommitsState() {
        let runtime = makeGenericRuntime()
        var committedProjection: String?
        var dirtyFlag = true
        var publishedNotice: String?

        runtime.resolveProjectionRefresh(
            using: {
                BASAppleProjectionRefreshResult(
                    projection: "resolved-projection",
                    refreshed: true,
                    notice: "resolved notice"
                )
            },
            commitProjection: { committedProjection = $0 },
            setProjectionDirty: { dirtyFlag = $0 },
            publishNotice: { publishedNotice = $0 }
        )

        XCTAssertEqual(committedProjection, "resolved-projection")
        XCTAssertFalse(dirtyFlag)
        XCTAssertEqual(publishedNotice, "resolved notice")
    }

    func testActivateSessionCommitsProjectionBrainAndSession() {
        let runtime = makeGenericRuntime()
        var loadedSession: [String] = []
        var committedProjection: String?
        var dirtyFlag = true
        var publishedNotice: String?
        var committedBrain: String?
        var committedSession: String?

        runtime.activateSession(
            session: "session",
            outcome: BASAppleCurrentBrainProjectionRuntimeResult(
                currentBrain: "brain",
                projection: "projection",
                refreshedProjection: true,
                notice: "activation notice"
            ),
            loadBrainState: { session, currentBrain in
                loadedSession = [session, currentBrain]
            },
            commitProjection: { committedProjection = $0 },
            setProjectionDirty: { dirtyFlag = $0 },
            publishNotice: { publishedNotice = $0 },
            commitCurrentBrain: { committedBrain = $0 },
            commitSession: { committedSession = $0 }
        )

        XCTAssertEqual(loadedSession, ["session", "brain"])
        XCTAssertEqual(committedProjection, "projection")
        XCTAssertFalse(dirtyFlag)
        XCTAssertEqual(publishedNotice, "activation notice")
        XCTAssertEqual(committedBrain, "brain")
        XCTAssertEqual(committedSession, "session")
    }

    func testResolveCurrentBrainProjectionUsesResolverAndCommitsBrain() {
        let runtime = makeGenericRuntime()
        var committedProjection: String?
        var dirtyFlag = true
        var publishedNotice: String?
        var committedBrain: String?

        runtime.resolveCurrentBrainProjection(
            using: {
                BASAppleCurrentBrainProjectionRuntimeResult(
                    currentBrain: "resolved-brain",
                    projection: "resolved-projection",
                    refreshedProjection: true,
                    notice: "resolved current brain"
                )
            },
            commitProjection: { committedProjection = $0 },
            setProjectionDirty: { dirtyFlag = $0 },
            publishNotice: { publishedNotice = $0 },
            commitCurrentBrain: { committedBrain = $0 }
        )

        XCTAssertEqual(committedProjection, "resolved-projection")
        XCTAssertFalse(dirtyFlag)
        XCTAssertEqual(publishedNotice, "resolved current brain")
        XCTAssertEqual(committedBrain, "resolved-brain")
    }

    func testResolveAndActivateSessionUsesResolverAndCommitsSession() {
        let runtime = makeGenericRuntime()
        var loadedSession: [String] = []
        var committedProjection: String?
        var dirtyFlag = true
        var publishedNotice: String?
        var committedBrain: String?
        var committedSession: String?

        runtime.resolveAndActivateSession(
            session: "session",
            using: {
                BASAppleCurrentBrainProjectionRuntimeResult(
                    currentBrain: "brain",
                    projection: "projection",
                    refreshedProjection: true,
                    notice: "resolved activation"
                )
            },
            loadBrainState: { session, currentBrain in
                loadedSession = [session, currentBrain]
            },
            commitProjection: { committedProjection = $0 },
            setProjectionDirty: { dirtyFlag = $0 },
            publishNotice: { publishedNotice = $0 },
            commitCurrentBrain: { committedBrain = $0 },
            commitSession: { committedSession = $0 }
        )

        XCTAssertEqual(loadedSession, ["session", "brain"])
        XCTAssertEqual(committedProjection, "projection")
        XCTAssertFalse(dirtyFlag)
        XCTAssertEqual(publishedNotice, "resolved activation")
        XCTAssertEqual(committedBrain, "brain")
        XCTAssertEqual(committedSession, "session")
    }

    func testReopenHeldItemAppliesFollowUpSuggestion() {
        let runtime = makeGenericRuntime()
        var actions: [String] = []
        var suggestion: BASAppleReopenInterventionSuggestion?

        runtime.reopenHeldItem(
            modeID: BASDecisionMode.comparative.rawValue,
            promptSeed: "Slow this choice down.",
            hasDraft: false,
            title: "Reopen carefully",
            detail: "High-risk reopen",
            riskLevelID: BASRiskLevel.high.rawValue,
            reopenHint: "Use more structure",
            templateHint: "Cooling template",
            interventionHistorySummary: "Past nighttime choices went worse.",
            clearActiveDecisionFlows: { actions.append("clear") },
            activatePrimaryFromDraft: { actions.append("draft-primary") },
            activateComparativeFromDraft: { actions.append("draft-comparative") },
            activateReflectiveFromDraft: { actions.append("draft-reflective") },
            startPrimary: { _ in actions.append("start-primary") },
            startComparative: { _ in actions.append("start-comparative") },
            startReflective: { _ in actions.append("start-reflective") },
            removeItem: { actions.append("remove") },
            applyInterventionSuggestion: { suggestion = $0; actions.append("suggest") },
            refreshPredictedIntervention: { actions.append("refresh") },
            selectHomeTab: { actions.append("home") },
            persistActiveWorkspaceState: { actions.append("persist") },
            now: .distantPast
        )

        XCTAssertEqual(actions, ["clear", "start-comparative", "remove", "suggest", "home", "persist"])
        XCTAssertEqual(suggestion?.title, "Use more structure")
        XCTAssertEqual(suggestion?.suggestedModeID, BASDecisionMode.comparative.rawValue)
    }

    func testRestoreActiveWorkspaceIfNeededRestoresMatchingMode() {
        let runtime = makeGenericRuntime()
        var actions: [String] = []

        runtime.restoreActiveWorkspaceIfNeeded(
            restoreEnabled: true,
            hasActivePrimaryWorkflow: false,
            hasActiveComparativeWorkflow: false,
            hasActiveReflectiveWorkflow: false,
            hasReflectionContext: false,
            loadState: { BASDecisionMode.reflectiveID },
            modeID: { $0 },
            restorePrimary: { _ in actions.append("primary") },
            restoreComparative: { _ in actions.append("comparative") },
            restoreReflective: { _ in actions.append("reflective") },
            selectHomeTab: { actions.append("home") },
            afterRestore: { actions.append("after") }
        )

        XCTAssertEqual(actions, ["reflective", "home", "after"])
    }

    func testRefreshActiveTaskGraphChoosesFirstAvailableSnapshot() {
        let runtime = makeGenericRuntime()
        var savedSnapshot: String?
        var cleared = false
        let snapshotLoaders: [() -> String?] = [
            { nil },
            { "comparative-snapshot" },
            { "reflective-snapshot" }
        ]

        let snapshot = runtime.refreshActiveTaskGraph(
            snapshotsInPriorityOrder: snapshotLoaders,
            saveSnapshot: { savedSnapshot = $0 },
            clearSnapshot: { cleared = true }
        )

        XCTAssertEqual(snapshot, "comparative-snapshot")
        XCTAssertEqual(savedSnapshot, "comparative-snapshot")
        XCTAssertFalse(cleared)
    }

    func testReconcilePredictiveInterventionKeepsExistingPresentationStable() {
        let runtime = makeGenericRuntime()
        let existing = BASApplePredictiveInterventionCandidateSummary(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            riskLevelID: BASRiskLevel.medium.rawValue,
            title: "Pause",
            detail: "Slow down",
            evidenceSignalCount: 2,
            preferredModeID: BASDecisionMode.reflective.rawValue,
            reason: "Recent signals say pause.",
            createdAt: .distantPast,
            expiresAt: .distantFuture
        )
        let next = BASApplePredictiveInterventionCandidateSummary(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            riskLevelID: BASRiskLevel.medium.rawValue,
            title: "Pause",
            detail: "Slow down",
            evidenceSignalCount: 2,
            preferredModeID: BASDecisionMode.reflective.rawValue,
            reason: "Recent signals say pause.",
            createdAt: .now,
            expiresAt: .distantFuture
        )

        let reconciled = runtime.reconcilePredictiveIntervention(
            existing: existing,
            next: next
        )

        XCTAssertEqual(reconciled?.id, existing.id)
    }

    func testExecutePredictiveInterventionDeliverySchedulesAllowedCandidate() {
        let runtime = makeGenericRuntime()
        let candidate = BASApplePredictiveInterventionCandidateSummary(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            riskLevelID: BASRiskLevel.high.rawValue,
            title: "Pause",
            detail: "Slow down",
            evidenceSignalCount: 3,
            preferredModeID: BASDecisionMode.reflective.rawValue,
            reason: "High-risk context",
            createdAt: .now,
            expiresAt: .distantFuture
        )
        var upserts: [(UUID, Bool)] = []
        var cancelled: [UUID] = []
        var scheduled: [UUID] = []

        runtime.executePredictiveInterventionDelivery(
            candidate: candidate,
            predictiveInterventionsEnabled: true,
            policyAllowed: true,
            upsertTrigger: { summary, wasDelivered in
                upserts.append((summary.id, wasDelivered))
            },
            cancelNotification: { cancelled.append($0) },
            scheduleNotification: { scheduled.append($0.id) }
        )

        XCTAssertEqual(upserts.count, 1)
        XCTAssertEqual(upserts.first?.0, candidate.id)
        XCTAssertEqual(upserts.first?.1, true)
        XCTAssertTrue(cancelled.isEmpty)
        XCTAssertEqual(scheduled, [candidate.id])
    }

    func testCustomCognitionBehaviorBelongsToHost() throws {
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(
                cognitionBehavior: BASHostCognitionBehaviorConfiguration(
                    reactionWeightsByProfileID: [
                        BASHostWorkflowProfile.primary.rawValue: BASReactionWeights(
                            briefLanguage: 0.71,
                            warmDirectTone: 0.41,
                            lowCognitiveLoad: 0.68,
                            interruptiveActionBias: 0.63,
                            boundaryNamingBias: 0.22,
                            tradeoffClarityBias: 0.31
                        )
                    ],
                    identityProfilesByProfileID: [
                        BASHostWorkflowProfile.primary.rawValue: BASIdentityProfile(
                            role: .tradeoffGuide,
                            posture: .coaching,
                            initiative: .guided,
                            confidenceCeiling: 0.67,
                            canAdvise: true,
                            canExecuteActions: false,
                            canEscalateToCloud: false,
                            relationshipBoundary: "Host rapid role."
                        )
                    ],
                    substrateBehavior: BASCognitionBehavior(
                        surfaceIdentityOverlaysBySurfaceID: [
                            BASInteractionSurface.notification.rawValue: BASIdentityProfileOverlay(
                                role: .boundedGuide,
                                posture: .coaching,
                                initiative: .passive,
                                confidenceCeiling: 0.5,
                                relationshipBoundary: "Host notification relationship."
                            )
                        ],
                        highRiskIdentityOverlay: BASIdentityProfileOverlay(
                            posture: .protective,
                            initiative: .guided,
                            confidenceCeiling: 0.52,
                            relationshipBoundary: "Host high-risk relationship."
                        ),
                        highRiskInitiativeByRoleID: [:],
                        boundary: BASBoundaryEvaluationBehavior(
                            defaultAllowedActionClasses: ["host_render"],
                            defaultBlockedActionClasses: ["host_cloud"],
                            defaultConstraints: [.lockSensitiveMemory],
                            allowedActionClassesBySurfaceID: [
                                BASInteractionSurface.notification.rawValue: ["host_notification_lane"]
                            ],
                            blockedActionClassesBySurfaceID: [
                                BASInteractionSurface.notification.rawValue: ["host_notification_spam"]
                            ],
                            constraintsBySurfaceID: [
                                BASInteractionSurface.notification.rawValue: [.notificationRequiresEvidence]
                            ],
                            highRiskRequiredConfirmations: ["host_confirm"],
                            highRiskBlockedActionClasses: ["host_fast_commit"],
                            reflectiveModeIDs: [],
                            advisoryHeadline: "Host advisory.",
                            reflectiveHeadline: "Host reflective.",
                            protectiveHeadline: "Host protective."
                        )
                    )
                )
            )
        )

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .notification,
                workflowProfile: .primary,
                surface: .notification,
                prompt: "Host wants a slower notification path.",
                riskLevel: .high
            )
        )

        XCTAssertEqual(result.currentBrain.workflowProfile, .primary)
        XCTAssertEqual(result.currentBrain.roleID, BASIdentityRole.boundedGuide.rawValue)
        XCTAssertEqual(result.currentBrain.identityPosture, .protective)
        XCTAssertEqual(result.currentBrain.identityInitiative, .guided)
        XCTAssertEqual(result.currentBrain.confidenceCeiling, 0.52, accuracy: 0.0001)
        XCTAssertEqual(result.currentBrain.relationshipBoundary, "Host high-risk relationship.")
        XCTAssertEqual(result.currentBrain.boundaryHeadline, "Host protective.")
        XCTAssertEqual(result.currentBrain.boundaryMode, .localOnlyProtective)
        XCTAssertTrue(result.currentBrain.boundaryConstraints.contains(.notificationRequiresEvidence))
        XCTAssertTrue(result.currentBrain.calibrationAlerts.isEmpty || result.currentBrain.calibrationStatus != .stable || !result.currentBrain.riskFlags.isEmpty)
        XCTAssertTrue([.replace, .block].contains(result.eBrainTurn?.actionPermit.mode))
        XCTAssertEqual(result.eBrainTurn?.thoughtFold.compactSlots["host_version"], "host.v1")
        XCTAssertNotNil(result.interventionSuggestion)
    }

    func testBootstrapThrowsTypedErrorWhenHostOmitsSessionDefaults() {
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(
                workflowBehavior: BASHostWorkflowBehaviorConfiguration(
                    defaultMemorySourceIDsBySessionKindID: [:],
                    defaultRetrievalModeIDsBySessionKindID: [:]
                )
            )
        )

        XCTAssertThrowsError(
            try runtime.bootstrap(
                BASHostLifecycleRequest(
                    phase: .initialAppearance,
                    sessionKind: .ambient,
                    preferredProfile: .primary,
                    sourceSurface: .application,
                    promptSeed: "Host omitted ambient routing.",
                    riskLevel: .low
                )
            )
        ) { error in
            XCTAssertEqual(
                error as? BASHostIntegrationError,
                .missingSessionKindMemorySource(kindID: BASHostSessionKind.ambient.rawValue)
            )
        }
    }
}
