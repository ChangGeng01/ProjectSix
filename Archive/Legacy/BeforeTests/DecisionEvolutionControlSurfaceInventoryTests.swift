import Foundation
import Testing
import BASHostKit
@testable import Before

struct DecisionEvolutionControlSurfaceInventoryTests {
    @Test
    func inventoryPrefersContextMatchedAutomaticLineage() {
        let quickOlder = makeLineage(
            checkpointID: "quick-older",
            createdAt: Date(timeIntervalSince1970: 10),
            mode: .quick,
            approvalState: .automatic,
            source: .persistedCheckpoint
        )
        let balanceCloser = makeLineage(
            checkpointID: "balance-closer",
            createdAt: Date(timeIntervalSince1970: 20),
            mode: .balance,
            approvalState: .automatic,
            source: .liveRuntime
        )
        let inventory = DecisionEvolutionControlSurfaceInventory(
            pendingReviewQueue: [],
            persistedLineages: [quickOlder, balanceCloser],
            activeCheckpoint: nil,
            restorableCheckpointIDs: []
        )
        let context = DecisionTestingCheckpointSelectionContext(
            mode: .balance,
            source: .liveRuntime,
            referenceDate: Date(timeIntervalSince1970: 21)
        )

        #expect(
            inventory.latestAutomaticLineage(matching: context)?.checkpointID == "balance-closer"
        )
        #expect(
            inventory.buildControlSurface(
                preferredCheckpointSelectionContext: context
            ).latestPersistedLineage?.checkpointID == "balance-closer"
        )
    }

    @Test
    func inventoryPrefersExplicitCheckpointAnchorOverCloserTimestamp() {
        let target = makeLineage(
            checkpointID: "anchor-target",
            createdAt: Date(timeIntervalSince1970: 10),
            mode: .quick,
            approvalState: .automatic,
            source: .persistedCheckpoint
        )
        let closer = makeLineage(
            checkpointID: "anchor-closer",
            createdAt: Date(timeIntervalSince1970: 20),
            mode: .quick,
            approvalState: .automatic,
            source: .persistedCheckpoint
        )
        let inventory = DecisionEvolutionControlSurfaceInventory(
            pendingReviewQueue: [],
            persistedLineages: [target, closer],
            activeCheckpoint: nil,
            restorableCheckpointIDs: []
        )
        let context = DecisionTestingCheckpointSelectionContext(
            mode: .quick,
            source: .liveRuntime,
            referenceDate: Date(timeIntervalSince1970: 21),
            explicitCheckpointID: "anchor-target"
        )

        #expect(
            inventory.latestPersistedLineage(matching: context)?.checkpointID == "anchor-target"
        )
    }

    @Test
    func inventoryPrefersThoughtFoldAnchorOverSharedSessionAndCloserTimestamp() {
        let checksumTarget = makeLineage(
            checkpointID: "fold-target",
            createdAt: Date(timeIntervalSince1970: 10),
            mode: .quick,
            approvalState: .automatic,
            source: .persistedCheckpoint,
            sessionID: "session-shared",
            thoughtFoldChecksum: "fold-anchor-target"
        )
        let closerButWrongFold = makeLineage(
            checkpointID: "fold-closer",
            createdAt: Date(timeIntervalSince1970: 20),
            mode: .quick,
            approvalState: .automatic,
            source: .persistedCheckpoint,
            sessionID: "session-shared",
            thoughtFoldChecksum: "fold-other"
        )
        let inventory = DecisionEvolutionControlSurfaceInventory(
            pendingReviewQueue: [],
            persistedLineages: [checksumTarget, closerButWrongFold],
            activeCheckpoint: nil,
            restorableCheckpointIDs: []
        )
        let context = DecisionTestingCheckpointSelectionContext(
            mode: .quick,
            source: .liveRuntime,
            referenceDate: Date(timeIntervalSince1970: 21),
            thoughtFoldChecksum: "fold-anchor-target",
            sessionID: "session-shared"
        )

        #expect(
            inventory.latestPersistedLineage(matching: context)?.checkpointID == "fold-target"
        )
    }

    @Test
    func inventoryPrefersStructuredAnchorMetadataOverCloserTimestampWhenFoldAndSessionTie() {
        let target = makeLineage(
            checkpointID: "metadata-target",
            createdAt: Date(timeIntervalSince1970: 10),
            mode: .quick,
            approvalState: .automatic,
            source: .persistedCheckpoint,
            sessionID: "session-shared",
            thoughtFoldChecksum: "fold-shared",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 77,
            reviewDirectiveLine: "Review memory write: Keep the parser-only correction local."
        )
        let closerButWrongMetadata = makeLineage(
            checkpointID: "metadata-closer",
            createdAt: Date(timeIntervalSince1970: 20),
            mode: .quick,
            approvalState: .automatic,
            source: .persistedCheckpoint,
            sessionID: "session-shared",
            thoughtFoldChecksum: "fold-shared",
            riskLevel: "medium",
            permitMode: "compare",
            hostGatePercent: 61,
            reviewDirectiveLine: "Review reflection draft: broaden the guidance."
        )
        let inventory = DecisionEvolutionControlSurfaceInventory(
            pendingReviewQueue: [],
            persistedLineages: [target, closerButWrongMetadata],
            activeCheckpoint: nil,
            restorableCheckpointIDs: []
        )
        let context = DecisionTestingCheckpointSelectionContext(
            mode: .quick,
            source: nil,
            referenceDate: Date(timeIntervalSince1970: 21),
            thoughtFoldChecksum: "fold-shared",
            sessionID: "session-shared",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 77,
            reviewDirectiveLine: "Review memory write: Keep the parser-only correction local."
        )

        #expect(
            inventory.latestPersistedLineage(matching: context)?.checkpointID == "metadata-target"
        )
    }

    @Test
    func inventorySurfaceBuildPreservesPendingQueueAndRollbackFacts() {
        let review = DecisionReviewCheckpointSnapshot(
            checkpointID: "review-1",
            previousCheckpointID: "approved-1",
            createdAt: Date(timeIntervalSince1970: 50),
            mode: .mirror,
            approvalState: .reviewSuggested,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["review queue item"],
            eBrain: makeReplaySummary(
                checkpointID: "review-1",
                recordedAt: Date(timeIntervalSince1970: 50),
                source: .persistedCheckpoint
            ),
            fallbackRiskLevel: "watch",
            fallbackPermitMode: "delay"
        )
        let active = DecisionReviewCheckpointSnapshot(
            checkpointID: "approved-1",
            previousCheckpointID: "approved-0",
            createdAt: Date(timeIntervalSince1970: 40),
            mode: .quick,
            approvalState: .automatic,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["approved active"],
            eBrain: makeReplaySummary(
                checkpointID: "approved-1",
                recordedAt: Date(timeIntervalSince1970: 40),
                source: .liveRuntime
            ),
            fallbackRiskLevel: "stable",
            fallbackPermitMode: "answer"
        )

        let inventory = DecisionEvolutionControlSurfaceInventory(
            pendingReviewQueue: [review],
            persistedLineages: [],
            activeCheckpoint: active,
            restorableCheckpointIDs: ["approved-0", "approved-1"]
        )

        let surface = inventory.buildControlSurface()

        #expect(surface.activeCheckpoint?.checkpointID == "approved-1")
        #expect(surface.reviewCheckpoint?.checkpointID == "review-1")
        #expect(surface.pendingReviewCount == 1)
        #expect(surface.activeRollbackCheckpointID == "approved-0")
    }

    @Test
    func inventoryPrefersNewestAutomaticSnapshotOverOlderPersistedLineage() {
        let latestAutomatic = DecisionReviewCheckpointSnapshot(
            checkpointID: "automatic-live",
            previousCheckpointID: "automatic-persisted",
            createdAt: Date(timeIntervalSince1970: 90),
            mode: .quick,
            approvalState: .automatic,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["latest automatic snapshot"],
            eBrain: nil,
            fallbackRiskLevel: "stable",
            fallbackPermitMode: "answer"
        )
        let review = DecisionReviewCheckpointSnapshot(
            checkpointID: "review-automatic-followup",
            previousCheckpointID: nil,
            createdAt: Date(timeIntervalSince1970: 80),
            mode: .mirror,
            approvalState: .reviewSuggested,
            rollbackReady: true,
            hasBrainStateSnapshot: false,
            diffSummary: ["review queue item"],
            eBrain: makeReplaySummary(
                checkpointID: "review-automatic-followup",
                recordedAt: Date(timeIntervalSince1970: 80),
                source: .persistedCheckpoint
            ),
            fallbackRiskLevel: "watch",
            fallbackPermitMode: "delay"
        )
        let olderPersistedAutomatic = makeLineage(
            checkpointID: "automatic-persisted",
            createdAt: Date(timeIntervalSince1970: 40),
            mode: .quick,
            approvalState: .automatic,
            source: .persistedCheckpoint
        )

        let inventory = DecisionEvolutionControlSurfaceInventory(
            pendingReviewQueue: [review],
            persistedLineages: [olderPersistedAutomatic],
            activeCheckpoint: nil,
            restorableCheckpointIDs: ["automatic-live", "automatic-persisted"]
        )

        let surface = DecisionEvolutionControlSurfaceFactory.build(
            activeCheckpointHint: latestAutomatic,
            latestAutomaticLineage: inventory.latestAutomaticLineage(),
            pendingReviewCheckpoints: inventory.pendingReviewQueue,
            latestPersistedLineage: inventory.latestPersistedLineage(),
            restorableCheckpointIDs: inventory.restorableCheckpointIDs
        )

        #expect(surface.activeCheckpoint?.checkpointID == "automatic-live")
        #expect(surface.latestPersistedLineage?.checkpointID == "automatic-persisted")
    }

    @Test
    func controlSurfaceFactoryPrefersPinnedActiveCheckpointOverAutomaticFallback() {
        let pinnedActive = DecisionReviewCheckpointSnapshot(
            checkpointID: "pinned-active",
            previousCheckpointID: "automatic-persisted",
            createdAt: Date(timeIntervalSince1970: 140),
            mode: .balance,
            approvalState: .automatic,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["Pinned active must remain the release head."],
            eBrain: makeReplaySummary(
                checkpointID: "pinned-active",
                recordedAt: Date(timeIntervalSince1970: 140),
                source: .liveRuntime
            ),
            fallbackRiskLevel: "medium",
            fallbackPermitMode: "compare"
        )
        let automaticFallback = makeLineage(
            checkpointID: "automatic-persisted",
            createdAt: Date(timeIntervalSince1970: 120),
            mode: .quick,
            approvalState: .automatic,
            source: .persistedCheckpoint
        )
        let reviewHead = DecisionReviewCheckpointSnapshot(
            checkpointID: "review-head",
            previousCheckpointID: "pinned-active",
            createdAt: Date(timeIntervalSince1970: 145),
            mode: .mirror,
            approvalState: .reviewSuggested,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["Review head should remain distinct from active."],
            eBrain: makeReplaySummary(
                checkpointID: "review-head",
                recordedAt: Date(timeIntervalSince1970: 145),
                source: .persistedCheckpoint
            ),
            fallbackRiskLevel: "high",
            fallbackPermitMode: "delay"
        )

        let surface = DecisionEvolutionControlSurfaceFactory.build(
            activeCheckpointHint: pinnedActive,
            latestAutomaticLineage: automaticFallback,
            pendingReviewCheckpoints: [reviewHead],
            latestPersistedLineage: automaticFallback,
            restorableCheckpointIDs: ["pinned-active", "automatic-persisted"]
        )

        #expect(surface.activeCheckpoint?.checkpointID == "pinned-active")
        #expect(surface.activeCheckpointSource == .pinnedHint)
        #expect(surface.reviewCheckpoint?.checkpointID == "review-head")
        #expect(surface.distinctReviewPresentation?.checkpointID == "review-head")
    }

    @Test
    func controlSurfaceCoverageFactsFallbackToLatestPersistedLineageWhenNoActiveCheckpointExists() {
        let reviewOnly = makeLineage(
            checkpointID: "review-only",
            createdAt: Date(timeIntervalSince1970: 120),
            mode: .mirror,
            approvalState: .reviewSuggested,
            source: .persistedCheckpoint
        )

        let inventory = DecisionEvolutionControlSurfaceInventory(
            pendingReviewQueue: [DecisionReviewCheckpointSnapshot(lineage: reviewOnly)],
            persistedLineages: [reviewOnly],
            activeCheckpoint: nil,
            restorableCheckpointIDs: []
        )

        let surface = inventory.buildControlSurface()
        let facts = surface.coverageFacts(
            latestPersistedLineage: inventory.latestPersistedLineage()
        )

        #expect(facts.recoveredCheckpoint == nil)
        #expect(facts.latestPersistedLineage?.checkpointID == "review-only")
        #expect(facts.recoveredEBrainAvailable == true)
        #expect(facts.recoveredAuditFindingCount == reviewOnly.eBrain.guardrailFindings.count)
        #expect(facts.recoveredTicketCount == reviewOnly.eBrain.updateTicketSummaries.count)
    }

    @Test
    func checkpointPresentationExposesSharedDetailLinesAndRollbackCopy() {
        let snapshot = DecisionReviewCheckpointSnapshot(
            checkpointID: "checkpoint-detail",
            previousCheckpointID: "checkpoint-prev",
            createdAt: Date(timeIntervalSince1970: 60),
            mode: .mirror,
            approvalState: .reviewSuggested,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["Queued for guarded review"],
            eBrain: DeveloperDecisionReplayEBrainSummary(lineageSummary: BASEvolutionLineageSummary(
                recordedAt: Date(timeIntervalSince1970: 60),
                sessionID: "session-checkpoint-detail",
                taskType: "decision-review",
                riskLevel: "high",
                permitMode: "delay",
                hostGatePercent: 88,
                thoughtFoldChecksum: "fold-checkpoint-detail",
                updateTicketSummaries: ["ticket-checkpoint-detail"],
                guardrailFindings: ["guardrail-checkpoint-detail"],
                recommendedKillSwitches: ["kill-checkpoint-detail"],
                contextSummary: BASEvolutionLineageSummary.ContextSummary(
                    emotionalLoadPercent: 81,
                    timePressurePercent: 84,
                    relationPattern: "manager-host",
                    ambiguityPercent: 22,
                    consequencePercent: 87,
                    manipulationHintCount: 2,
                    sceneType: "highPressureConflict",
                    roleRelationClass: "manager",
                    powerDirection: "external over host",
                    powerStrengthPercent: 82,
                    urgencyPercent: 84,
                    routeMode: "guarded",
                    guardRequired: true,
                    continuityArc: "highPressureConflict:manager"
                ),
                foldedLungSummary: BASEvolutionFoldedLungSummary(
                    morphGraphID: "morph-checkpoint-detail",
                    hotColdMapID: "hotcold-checkpoint-detail",
                    precisionProfileID: "precision-checkpoint-detail",
                    lungStateRef: "lung-checkpoint-detail",
                    integrityWeaveID: "integrity-checkpoint-detail",
                    breathMode: "guard",
                    breathPhase: "exchange",
                    thermalPressure: 63,
                    cachePressure: 48,
                    restoreReadinessPercent: 84,
                    resumeID: "resume-checkpoint-detail",
                    sourceFoldID: "fold-checkpoint-detail",
                    resumeDepth: 1,
                    fallbackMode: "rollbackAnchor",
                    rollbackAnchorID: "rollback-checkpoint-detail",
                    safeSnapshotRef: "snapshot-checkpoint-detail",
                    foldRefs: ["fold-checkpoint-detail"],
                    integrityHash: "abc123def456",
                    morphActiveOrganIDs: ["riskSpine", "stubCore"],
                    morphExecutionOrder: ["riskSpine", "stubCore"],
                    morphDeviceRouteMap: ["riskSpine": "ane"],
                    morphThermalProfile: ["guarded"],
                    hotOrganIDs: ["stubCore"],
                    warmOrganIDs: ["riskSpine"],
                    coldOrganIDs: ["simuRing"],
                    thermalExchangeMode: "predictive_guard",
                    thermalPredictedBand: "warm",
                    thermalCoolingActions: ["trim_batch"],
                    integrityRequiredChecks: ["fold_checksum"],
                    integrityCompletedChecks: ["fold_checksum"],
                    integrityPurityState: "verified",
                    integrityVerificationHash: "abc123def456",
                    precisionDegradationOrder: ["fp16", "int8"],
                    precisionGuardSafeFloorID: "int8"
                ),
                governanceSummary: BASEvolutionLineageSummary.GovernanceSummary(
                    experienceCandidateCount: 0,
                    shadowTrialCount: 0,
                    pendingShadowTrialCount: 0,
                    sealCount: 0,
                    pendingSealCount: 0,
                    versionDeltaCount: 0,
                    retractionOrderCount: 0,
                    pendingRetractionCount: 0,
                    dreamLoopRemandTargets: ["L9", "L14"],
                    dreamLoopReservationMode: "delayRight"
                )
            )),
            fallbackRiskLevel: "high",
            fallbackPermitMode: "delay"
        )

        let presentation = DecisionEvolutionCheckpointPresentation(snapshot: snapshot)
        let selectedAction = presentation.selectionActionPresentation(isSelected: true)
        let unselectedAction = presentation.selectionActionPresentation(isSelected: false)
        let summaryBadges = presentation.summaryBadgePresentations(
            activeSource: DecisionEvolutionActiveCheckpointSource.automaticFallback
        )

        #expect(presentation.approvalStateTitle == "Review suggested")
        #expect(presentation.rollbackStateTitle == "Rollback ready")
        #expect(presentation.rollbackBadgeTitle == "ROLLBACK READY")
        #expect(DecisionEvolutionCheckpointLexiconSupport.activeCheckpointRoleTitle == "Active checkpoint")
        #expect(DecisionEvolutionCheckpointLexiconSupport.reviewHeadRoleTitle == "Review head")
        #expect(DecisionEvolutionCheckpointLexiconSupport.activeRuntimeRoleTitle == "Active")
        #expect(DecisionEvolutionCheckpointLexiconSupport.rollbackStateTitle(rollbackReady: true) == "Rollback ready")
        #expect(DecisionEvolutionCheckpointLexiconSupport.rollbackBadgeTitle(rollbackReady: false) == "ROLLBACK WATCH")
        #expect(DecisionEvolutionCheckpointLexiconSupport.rollbackReadyCountBadgeTitle(2) == "2 ROLLBACK READY")
        #expect(
            DecisionEvolutionCheckpointDetailPresentationSupport.lineagePendingSummaryText
                == "Lineage pending • review details stay available, but recovered risk facts are not attached yet."
        )
        #expect(presentation.ticketsLine == "Tickets: ticket-checkpoint-detail")
        #expect(presentation.courtSummaryLine == "Court: agency delay right • remand L9, L14")
        #expect(presentation.auditLine == "Audit: guardrail-checkpoint-detail")
        #expect(presentation.killSwitchesLine == "Kill switches: kill-checkpoint-detail")
        #expect(presentation.presenceTitle == "Presence field")
        #expect(
            presentation.presenceLines
                == [
                    "Presence scene high pressure conflict • role manager • power external over host 82% • urgency 84% • route guarded • guard on • continuity highPressureConflict:manager"
                ]
        )
        #expect(presentation.foldedLungTitle == "Folded lung")
        #expect(
            presentation.foldedLungLines
                == [
                    "L3 compression runtime • breath guard • phase exchange • anchor rollback-checkpoint-detail",
                    "Breath guard • Phase exchange • Restore 84%",
                    "Morph graph morph-checkpoint-detail • organs riskSpine, stubCore • route ane • thermal guarded",
                    "Integrity weave verified • checks 1/1 • hash abc123def456",
                    "Rollback anchor rollback-checkpoint-detail • snapshot snapshot-checkpoint-detail"
                ]
        )
        #expect(presentation.diffLine == "Diff: Queued for guarded review")
        #expect(presentation.diffBulletLines == ["• Queued for guarded review"])
        #expect(presentation.recordedLine.contains("Recorded "))
        #expect(presentation.recordedLine.contains("checkpoint-detail"))
        #expect(selectedAction.title == "Selected")
        #expect(selectedAction.usesPrimaryStyle == true)
        #expect(unselectedAction.title == "Select")
        #expect(unselectedAction.usesPrimaryStyle == false)
        #expect(summaryBadges.count == 4)
        #expect(summaryBadges[0] == DecisionEvolutionSummaryBadgePresentation(title: "HIGH", tone: .ember))
        #expect(summaryBadges[1] == DecisionEvolutionSummaryBadgePresentation(title: "DELAY", tone: .moss))
        #expect(summaryBadges[2] == DecisionEvolutionSummaryBadgePresentation(title: "RECOVERED", tone: .blue))
        #expect(summaryBadges[3] == DecisionEvolutionSummaryBadgePresentation(title: "ROLLBACK READY", tone: .moss))
        #expect(
            DecisionEvolutionCheckpointDetailPresentationSupport.emptyLineageMessage
                == "No persisted checkpoint lineage is available yet."
        )
    }

    @Test
    func checkpointPresentationUsesSharedLineagePendingFallbackSummary() {
        let snapshot = DecisionReviewCheckpointSnapshot(
            checkpointID: "checkpoint-pending-lineage",
            previousCheckpointID: nil,
            createdAt: Date(timeIntervalSince1970: 75),
            mode: .mirror,
            approvalState: .reviewSuggested,
            rollbackReady: false,
            hasBrainStateSnapshot: false,
            diffSummary: ["Pending lineage"],
            eBrain: nil,
            fallbackRiskLevel: nil,
            fallbackPermitMode: nil
        )

        let presentation = DecisionEvolutionCheckpointPresentation(snapshot: snapshot)

        #expect(
            presentation.summaryText
                == DecisionEvolutionCheckpointDetailPresentationSupport.lineagePendingSummaryText
        )
        #expect(presentation.usesSecondarySummaryTone == true)
        #expect(presentation.presenceTitle == nil)
        #expect(presentation.presenceLines.isEmpty)
        #expect(presentation.foldedLungTitle == nil)
        #expect(presentation.foldedLungLines.isEmpty)
    }

    @Test
    func controlSurfaceSummarySectionsExposeSharedRoleAndBadgeContracts() {
        let active = DecisionReviewCheckpointSnapshot(
            checkpointID: "active-summary",
            previousCheckpointID: "active-prev",
            createdAt: Date(timeIntervalSince1970: 80),
            mode: .quick,
            approvalState: .automatic,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["active summary"],
            eBrain: makeReplaySummary(
                checkpointID: "active-summary",
                recordedAt: Date(timeIntervalSince1970: 80),
                source: .liveRuntime
            ),
            fallbackRiskLevel: "stable",
            fallbackPermitMode: "answer"
        )
        let review = DecisionReviewCheckpointSnapshot(
            checkpointID: "review-summary",
            previousCheckpointID: "active-summary",
            createdAt: Date(timeIntervalSince1970: 90),
            mode: .mirror,
            approvalState: .reviewSuggested,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["review summary"],
            eBrain: makeReplaySummary(
                checkpointID: "review-summary",
                recordedAt: Date(timeIntervalSince1970: 90),
                source: .persistedCheckpoint
            ),
            fallbackRiskLevel: "high",
            fallbackPermitMode: "delay"
        )

        let surface = DecisionEvolutionControlSurface(
            activeCheckpoint: active,
            activeCheckpointSource: .automaticFallback,
            reviewCheckpoint: review,
            pendingReviewQueue: [review],
            latestPersistedLineage: nil,
            restorableCheckpointIDs: ["active-prev", "active-summary"]
        )

        let sections = surface.summarySectionPresentations

        #expect(sections.map(\.title) == ["Active checkpoint", "Review head"])
        #expect(sections.map(\.presentation.checkpointID) == ["active-summary", "review-summary"])
        #expect(
            sections[0] == DecisionEvolutionControlSurfaceSummaryPresentationSupport.sectionPresentation(
                role: .active,
                presentation: sections[0].presentation,
                activeSource: .automaticFallback
            )
        )
        #expect(
            sections[1] == DecisionEvolutionControlSurfaceSummaryPresentationSupport.sectionPresentation(
                role: .reviewHead,
                presentation: sections[1].presentation
            )
        )
        #expect(
            sections[0].summaryBadges.contains(
                DecisionEvolutionSummaryBadgePresentation(title: "RECOVERED", tone: .blue)
            )
        )
        #expect(
            sections[1].summaryBadges.contains(
                DecisionEvolutionSummaryBadgePresentation(title: "RECOVERED", tone: .blue)
            ) == false
        )
    }

    private func makeLineage(
        checkpointID: String,
        createdAt: Date,
        mode: DecisionMode,
        approvalState: DecisionEvolutionApprovalState,
        source: DeveloperDecisionReplayEBrainSource,
        sessionID: String? = nil,
        thoughtFoldChecksum: String? = nil,
        riskLevel: String = "high",
        permitMode: String = "delay",
        hostGatePercent: Int = 75,
        reviewDirectiveLine: String? = nil
    ) -> DecisionEvolutionLineageSnapshot {
        DecisionEvolutionLineageSnapshot(
            checkpointID: checkpointID,
            previousCheckpointID: nil,
            createdAt: createdAt,
            mode: mode,
            approvalState: approvalState,
            rollbackReady: false,
            hasBrainStateSnapshot: false,
            diffSummary: [checkpointID],
            eBrain: makeReplaySummary(
                checkpointID: checkpointID,
                recordedAt: createdAt,
                source: source,
                sessionID: sessionID,
                thoughtFoldChecksum: thoughtFoldChecksum,
                riskLevel: riskLevel,
                permitMode: permitMode,
                hostGatePercent: hostGatePercent,
                reviewDirectiveLine: reviewDirectiveLine
            )
        )
    }

    private func makeReplaySummary(
        checkpointID: String,
        recordedAt: Date,
        source: DeveloperDecisionReplayEBrainSource,
        sessionID: String? = nil,
        thoughtFoldChecksum: String? = nil,
        riskLevel: String = "high",
        permitMode: String = "delay",
        hostGatePercent: Int = 75,
        reviewDirectiveLine: String? = nil,
        governanceSummary: BASEvolutionLineageSummary.GovernanceSummary? = nil
    ) -> DeveloperDecisionReplayEBrainSummary {
        DeveloperDecisionReplayEBrainSummary(lineageSummary: BASEvolutionLineageSummary(
            recordedAt: recordedAt,
            sessionID: sessionID ?? "session-\(checkpointID)",
            taskType: source == .liveRuntime ? "decision-live" : "decision-persisted",
            riskLevel: riskLevel,
            permitMode: permitMode,
            hostGatePercent: hostGatePercent,
            thoughtFoldChecksum: thoughtFoldChecksum ?? "fold-\(checkpointID)",
            updateTicketSummaries: ["ticket-\(checkpointID)"],
            reviewDirectiveLine: reviewDirectiveLine,
            guardrailFindings: [],
            recommendedKillSwitches: [],
            governanceSummary: governanceSummary
        ))
    }
}
