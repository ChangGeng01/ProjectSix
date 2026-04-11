import Foundation
import SwiftData
import Testing
import BASAdmin
import BASAppleAdapters
import BASMemory
import BASOrchestration
import BASRuntimeCore
@testable import Before

@MainActor
struct BehavioralAISubstrateBridgeTests {
    @Test
    func consoleSnapshotPackagesRuntimeFlightDeckAndBrainState() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHistory(into: context)
        try context.save()

        let bootstrapAt = date("2026-04-10T21:15:00Z")
        let projection = DecisionMemorySystem.refreshProjection(in: context, now: bootstrapAt)
        let brainState = CurrentBrainStateLoader.bootstrapCurrentBrainState(
            mode: .quick,
            prompt: "Should I send this tonight?",
            source: .launch,
            taskGraph: nil,
            context: context,
            projection: projection,
            retrievalMode: .filtered,
            now: bootstrapAt
        )

        let export = await DecisionTestingInterface.runtimeExport(
            quick: DecisionMemorySystem.fetchCheckEvents(in: context),
            balance: DecisionMemorySystem.fetchBalanceRecords(in: context),
            mirror: DecisionMemorySystem.fetchMirrorRecords(in: context),
            preferences: .default
        )

        let snapshot = BehavioralAISubstrateBridge.consoleSnapshot(
            from: export,
            currentBrainState: brainState
        )

        #expect(snapshot.reports.count == DecisionSystemLayer.allCases.count)
        #expect(snapshot.isPureLocal == true)
        #expect(snapshot.runtimeSummary?.contains(export.summary.activeProvider.title) == true)
        #expect(snapshot.brainSummary?.contains(brainState.identityProfile.role.title) == true)
        #expect(snapshot.overallSummary.contains("Behavioral substrate score"))
        #expect(snapshot.capabilityCoverage != nil)
        #expect(snapshot.capabilityCoverage?.sections.contains(where: { $0.domain == .context }) == true)
        #expect(snapshot.capabilityCoverage?.sections
            .first(where: { $0.domain == .context })?
            .items
            .contains(where: { $0.id == "context.compaction" }) == true)
        #expect(snapshot.capabilityCoverage?.sections
            .first(where: { $0.domain == .orchestration })?
            .items
            .contains(where: { $0.id == "orchestration.watch_handoff" }) == true)

        let runtimeContext = BehavioralAISubstrateBridge.runtimeContext(from: export)
        #expect(runtimeContext.taskKind == BASTaskKind.chat)

        let roleProfile = BehavioralAISubstrateBridge.roleProfile(from: brainState)
        #expect(roleProfile?.name == brainState.identityProfile.role.title)

        let substrateBrain = BehavioralAISubstrateBridge.brainSnapshot(from: brainState)
        #expect(substrateBrain?.verificationSnapshot == brainState.verificationSnapshot.fingerprint)
        #expect(substrateBrain?.activeConstraints == brainState.activeConstraints)

        let intentEnvelope = BehavioralAISubstrateBridge.entryIntentEnvelope(
            from: DecisionIntentEnvelope(
                kind: .quickCapture,
                sourceSurface: .watch,
                entrySource: .watch,
                preferredMode: .quick,
                promptSeed: "Hold this until morning.",
                riskLevel: .medium,
                triggerReason: "watch_capture"
            )
        )
        #expect(intentEnvelope.kind == .quickCapture)
        #expect(intentEnvelope.surface == .watch)
        #expect(intentEnvelope.taskKind == BASTaskKind.chat)
        #expect(intentEnvelope.riskLevel == .medium)

        let intentSummary = BehavioralAISubstrateBridge.entryIntentSummary(
            from: DecisionIntentEnvelope(
                kind: .resumeCurrentDecision,
                sourceSurface: .notification,
                entrySource: .app,
                preferredMode: .balance,
                promptSeed: "Resume the hard decision.",
                riskLevel: .high,
                triggerReason: "prediction"
            )
        )
        #expect(intentSummary.requiresResume)
        #expect(intentSummary.headline.contains("Notification"))

        let handoffSummary = BehavioralAISubstrateBridge.handoffSummary(
            from: DecisionIntentEnvelope(
                kind: .quickCapture,
                sourceSurface: .watch,
                entrySource: .watch,
                preferredMode: .quick,
                promptSeed: "Save this for tomorrow morning.",
                riskLevel: .medium
            )
        )
        #expect(handoffSummary.surface == .watch)
        #expect(handoffSummary.taskKind == .chat)
        #expect(handoffSummary.requiresResume)
    }

    @Test
    func bridgeBootstrapCurrentBrainStateCommitsAndMaterializesHostState() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHistory(into: context)
        try context.save()

        let now = date("2026-04-10T21:45:00Z")
        let projection = DecisionMemorySystem.refreshProjection(in: context, now: now)

        let current = BehavioralAISubstrateBridge.bootstrapCurrentBrainState(
            mode: .quick,
            prompt: "Should I send this tonight?",
            source: .launch,
            envelope: DecisionIntentEnvelope(
                kind: .resumeCurrentDecision,
                sourceSurface: .notification,
                entrySource: .app,
                preferredMode: .quick,
                promptSeed: "Should I send this tonight?",
                riskLevel: .high,
                triggerReason: "prediction"
            ),
            taskGraph: nil,
            context: context,
            projection: projection,
            retrievalMode: .filtered,
            now: now
        )

        let updates = try context.fetch(FetchDescriptor<BrainStateUpdate>())
        let checkpoints = try context.fetch(FetchDescriptor<DecisionEvolutionCheckpoint>())
        let templates = try context.fetch(FetchDescriptor<InterventionTemplateRecord>())

        #expect(current.sourceSurface == .notification)
        #expect(current.riskLevel == .high)
        #expect(!templates.isEmpty)
        #expect(checkpoints.count == 1)
        #expect(updates.count == 1)
        #expect(updates.first?.fingerprint == current.verificationSnapshot.fingerprint)
        #expect(current.identityProfile.role == .predictiveSentinel)
        #expect(current.boundaryPolicy.riskLevel == .high)
    }

    @Test
    func bridgePrimeCurrentBrainStateCompactsSessionFragmentsIntoCommittedBrain() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHistory(into: context)
        try context.save()

        let now = date("2026-04-10T22:00:00Z")
        let projection = DecisionMemorySystem.refreshProjection(in: context, now: now)

        let current = BehavioralAISubstrateBridge.primeCurrentBrainState(
            mode: .quick,
            promptFragments: ["  should ", "I", "wait until morning?  "],
            context: context,
            projection: projection,
            retrievalMode: .filtered,
            now: now
        )

        let updates = try context.fetch(FetchDescriptor<BrainStateUpdate>())

        #expect(current.source == .sessionPrime)
        #expect(current.mode == .quick)
        #expect(current.sourceSurface == .app)
        #expect(current.activeTemplateIDs.isEmpty == false)
        #expect(updates.last?.source == .sessionPrime)
    }

    @Test
    func bridgeRefreshCurrentBrainStateUsesTaskGraphFallbackWhenSessionsAreEmpty() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHistory(into: context)
        try context.save()

        let now = date("2026-04-10T22:30:00Z")
        let projection = DecisionMemorySystem.refreshProjection(in: context, now: now)
        let taskGraph = DecisionTaskGraphSnapshot(
            mode: .mirror,
            promptSeed: "resume the hard reflection",
            nextActionHint: "Return to the unresolved reflection",
            continuityFingerprint: "mirror|resume",
            tasks: [
                DecisionTaskNode(
                    kind: .evaluate,
                    title: "Re-open the reflection",
                    detail: "Return to the unresolved reflection with a slower lens.",
                    status: .inProgress
                )
            ],
            updatedAt: now
        )

        let current = BehavioralAISubstrateBridge.refreshCurrentBrainState(
            quickPromptFragments: nil,
            balancePromptFragments: nil,
            mirrorPromptFragments: nil,
            taskGraph: taskGraph,
            context: context,
            projection: projection,
            retrievalModesByModeID: [DecisionMode.mirror.rawValue: DecisionRetrievalMode.filtered.rawValue],
            source: .sceneActive,
            now: now
        )

        #expect(current.source == .sceneActive)
        #expect(current.mode == .mirror)
        #expect(current.taskGraph?.promptSeed == "resume the hard reflection")
        #expect(current.verificationSnapshot.fingerprint.isEmpty == false)
    }

    @Test
    func bridgeRefreshCurrentBrainStatePrefersActiveSessionOverTaskGraphFallback() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHistory(into: context)
        try context.save()

        let now = date("2026-04-10T22:45:00Z")
        let projection = DecisionMemorySystem.refreshProjection(in: context, now: now)
        let quick = QuickCheckSession(entrySource: .app, initialNote: " Wait until morning ")
        quick.scenario = .other
        quick.motivation = .avoiding

        let taskGraph = DecisionTaskGraphSnapshot(
            mode: .mirror,
            promptSeed: "resume the hard reflection",
            nextActionHint: "Return to the unresolved reflection",
            continuityFingerprint: "mirror|resume",
            tasks: [
                DecisionTaskNode(
                    kind: .evaluate,
                    title: "Re-open the reflection",
                    detail: "Return to the unresolved reflection with a slower lens.",
                    status: .inProgress
                )
            ],
            updatedAt: now
        )

        let current = BehavioralAISubstrateBridge.refreshCurrentBrainState(
            activeQuickSession: quick,
            activeBalanceSession: nil,
            activeMirrorSession: nil,
            taskGraph: taskGraph,
            preferences: .default,
            context: context,
            projection: projection,
            source: .sceneActive,
            now: now
        )

        #expect(current.mode == .quick)
        #expect(current.source == .sceneActive)
        #expect(current.taskGraph?.mode == .mirror)
        #expect(current.verificationSnapshot.fingerprint.isEmpty == false)
    }

    @Test
    func bridgeConsumeDecisionIntentEnvelopeRoutesOpenModeAndRefreshesBrain() {
        let envelope = DecisionIntentEnvelope(
            kind: .reopenTomorrowItem,
            sourceSurface: .notification,
            entrySource: .app,
            preferredMode: .balance,
            promptSeed: "Resume with more space.",
            riskLevel: .medium,
            triggerReason: "prediction"
        )

        var openedMode: DecisionMode?
        var selectedBoxTab = false
        var refreshedSource: BrainStateUpdateSource?

        BehavioralAISubstrateBridge.consumeDecisionIntentEnvelope(
            envelope,
            performQuickCapture: { _, _, _ in
                Issue.record("Expected open-mode path, not quick capture")
            },
            performOpenMode: { _, mode, shouldSelectBoxTab, prompt in
                openedMode = mode
                selectedBoxTab = shouldSelectBoxTab
                #expect(prompt == "Resume with more space.")
            },
            performPredictiveIntervention: { _ in
                Issue.record("Expected open-mode path, not predictive intervention")
            },
            performRestoreWorkspace: {
                Issue.record("Expected open-mode path, not workspace restore")
            },
            refreshCurrentBrain: { source in
                refreshedSource = source
            }
        )

        #expect(openedMode == .balance)
        #expect(selectedBoxTab)
        #expect(refreshedSource == .explicitRefresh)
    }

    @Test
    func bridgeResolveMemoryProjectionUsesCachedProjectionWhenClean() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHistory(into: context)
        try context.save()

        let now = date("2026-04-10T23:00:00Z")
        let cached = DecisionMemorySystem.refreshProjection(in: context, now: now)

        let outcome = BehavioralAISubstrateBridge.resolveMemoryProjection(
            force: false,
            cachedProjection: cached,
            isDirty: false,
            context: context,
            now: now
        )

        #expect(outcome.refreshed == false)
        #expect(outcome.projection.diagnostics.recordCount == cached.diagnostics.recordCount)
        #expect(outcome.projection.governanceSnapshot.totalRecordCount == cached.governanceSnapshot.totalRecordCount)
    }

    @Test
    func bridgeSchedulePredictiveInterventionCancelsExpiredCandidate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let candidate = InterventionPredictionCandidate(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            riskLevel: .high,
            title: "Pause tonight",
            detail: "This likely needs a slower lens.",
            evidenceSignalCount: 3,
            suggestedMode: .mirror,
            reason: "Recent regret pattern",
            createdAt: date("2026-04-10T20:00:00Z"),
            expiresAt: date("2026-04-10T20:05:00Z")
        )

        var upserts: [(UUID, Bool)] = []
        var cancelled: [UUID] = []
        var scheduled: [UUID] = []

        BehavioralAISubstrateBridge.schedulePredictiveInterventionIfNeeded(
            candidate: candidate,
            preferences: .default,
            currentBrainState: nil,
            context: context,
            now: date("2026-04-10T21:00:00Z"),
            calendar: Calendar(identifier: .gregorian),
            upsertTrigger: { candidate, wasDelivered in
                upserts.append((candidate.id, wasDelivered))
            },
            cancelNotification: { cancelled.append($0) },
            scheduleNotification: { scheduled.append($0.id) }
        )

        #expect(upserts.count == 1)
        #expect(upserts.first?.0 == candidate.id)
        #expect(upserts.first?.1 == false)
        #expect(cancelled == [candidate.id])
        #expect(scheduled.isEmpty)
    }

    @MainActor
    @Test
    func bridgeRefreshActiveTaskGraphSnapshotPrefersQuickSnapshotAndPersistsIt() {
        let quick = QuickCheckSession(entrySource: .app, initialNote: "Wait until morning")
        quick.scenario = .other

        var savedSnapshot: DecisionTaskGraphSnapshot?
        var cleared = false

        let snapshot = BehavioralAISubstrateBridge.refreshActiveTaskGraphSnapshot(
            activeQuickSession: quick,
            activeBalanceSession: nil,
            activeMirrorSession: nil,
            saveSnapshot: { savedSnapshot = $0 },
            clearSnapshot: { cleared = true }
        )

        #expect(snapshot?.mode == .quick)
        #expect(savedSnapshot?.mode == .quick)
        #expect(cleared == false)
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: CheckEvent.self,
            DecisionMemoryRecord.self,
            DecisionMemoryCandidateRecord.self,
            BalanceDecisionRecord.self,
            MirrorDecisionRecord.self,
            BrainStateUpdate.self,
            DecisionEvolutionCheckpoint.self,
            InterventionTemplateRecord.self,
            FailurePatternRecord.self,
            InterventionTrigger.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @MainActor
    private func seedHistory(into context: ModelContext) {
        context.insert(
            CheckEvent(
                createdAt: date("2026-04-10T08:00:00Z"),
                scenario: .other,
                motivation: .genuineNeed,
                expectedOutcome: .satisfied,
                controlLevel: .maybe,
                note: "I want to reply fast.",
                currentPerspective: "You want a fast relief hit.",
                afterPerspective: "Waiting tends to clean this up.",
                verdict: .pause,
                finalAction: .decideTomorrow,
                reflectionOutcome: .betterThanExpected,
                entrySource: .app
            )
        )
    }

    private func date(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? Date(timeIntervalSince1970: 0)
    }
}
