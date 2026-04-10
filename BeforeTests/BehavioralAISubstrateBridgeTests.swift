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
