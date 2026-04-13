import Foundation
import SwiftData
import Testing
import BASHostKit
@testable import Before

@MainActor
struct DecisionCapabilityCoverageBuilderTests {
    @Test
    func buildProducesStableSectionOrderAndBridgeParity() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHistory(into: context)
        try context.save()

        let now = date("2026-04-10T21:15:00Z")
        let projection = DecisionMemorySystem.refreshProjection(in: context, now: now)
        let brainState = CurrentBrainStateLoader.bootstrapCurrentBrainState(
            mode: .quick,
            prompt: "Should I send this tonight?",
            source: .launch,
            taskGraph: nil,
            context: context,
            projection: projection,
            retrievalMode: .filtered,
            now: now
        )

        let export = await DecisionTestingInterface.runtimeExport(
            quick: DecisionMemorySystem.fetchCheckEvents(in: context),
            balance: DecisionMemorySystem.fetchBalanceRecords(in: context),
            mirror: DecisionMemorySystem.fetchMirrorRecords(in: context),
            preferences: .default
        )

        let report = DecisionCapabilityCoverageBuilder.build(
            from: export,
            currentBrainState: brainState
        )
        let bridgeSnapshot = BehavioralAISubstrateBridge.consoleSnapshot(
            from: export,
            currentBrainState: brainState
        )

        #expect(report.sections.map(\.domain) == BASCapabilityDomain.allCases)
        #expect(report.sections.count == 8)
        #expect(report.sections.first(where: { $0.domain == .runtime })?.items.contains(where: { $0.id == "runtime.first_presentable" }) == true)
        #expect(report.sections.first(where: { $0.domain == .context })?.items.contains(where: { $0.id == "context.compaction" }) == true)
        #expect(report.sections.first(where: { $0.domain == .memory })?.items.contains(where: { $0.id == "memory.brain_bootstrap" }) == true)
        #expect(report.sections.first(where: { $0.domain == .orchestration })?.items.contains(where: { $0.id == "orchestration.watch_handoff" }) == true)
        #expect(report.sections.first(where: { $0.domain == .evaluation })?.items.contains(where: { $0.id == "evaluation.safe_evolution" }) == true)
        #expect(report.sections.first(where: { $0.domain == .delivery })?.items.contains(where: { $0.id == "delivery.self_portrait" }) == true)
        #expect(report.overallScore > 0)
        #expect(bridgeSnapshot.capabilityCoverage == report)
    }

    @Test
    func buildDegradesGracefullyWithoutBrainState() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHistory(into: context)
        try context.save()

        let export = await DecisionTestingInterface.runtimeExport(
            quick: DecisionMemorySystem.fetchCheckEvents(in: context),
            balance: DecisionMemorySystem.fetchBalanceRecords(in: context),
            mirror: DecisionMemorySystem.fetchMirrorRecords(in: context),
            preferences: .default
        )

        let report = DecisionCapabilityCoverageBuilder.build(
            from: export,
            currentBrainState: nil
        )

        #expect(report.sections.first(where: { $0.domain == .context })?.items.first(where: { $0.id == "context.summary_layer" })?.status == .partial)
        #expect(report.sections.first(where: { $0.domain == .memory })?.items.first(where: { $0.id == "memory.templates_failures" })?.status == .partial)
        #expect(report.sections.first(where: { $0.domain == .delivery })?.items.first(where: { $0.id == "delivery.self_portrait" })?.status == .partial)
        #expect(report.missingSummary.contains("Context: Structured summary layer"))
        #expect(report.missingSummary.contains("Delivery: Explainable self-portrait"))
    }

    @Test
    func buildUsesRecoveredCheckpointLineageWhenLiveBrainStateIsMissing() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHistory(into: context)
        try context.save()

        let lineageSummary = BASEvolutionLineageSummary(
            recordedAt: date("2026-04-10T21:15:00.000Z"),
            sessionID: "before.quick.lineage",
            taskType: "conflict",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 82,
            thoughtFoldChecksum: "fold-checkpoint",
            updateTicketSummaries: ["review after cooldown"],
            guardrailFindings: ["Checkpoint guardrail matched"],
            recommendedKillSwitches: ["host-write"]
        )
        let persistedLineage = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-1",
            createdAt: date("2026-04-10T21:16:00.000Z"),
            mode: .quick,
            approvalState: .automatic,
            rollbackReady: true,
            diffSummary: ["Checkpoint recovery pending review"],
            eBrain: DeveloperDecisionReplayEBrainSummary(lineageSummary: lineageSummary)
        )

        let export = await DecisionTestingInterface.runtimeExport(
            quick: DecisionMemorySystem.fetchCheckEvents(in: context),
            balance: [],
            mirror: [],
            preferences: .default,
            persistedCheckpointLineages: [persistedLineage],
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        let report = DecisionCapabilityCoverageBuilder.build(
            from: export,
            currentBrainState: nil
        )

        #expect(report.sections.first(where: { $0.domain == .context })?.items.first(where: { $0.id == "context.summary_layer" })?.status == .ready)
        #expect(report.sections.first(where: { $0.domain == .policy })?.items.first(where: { $0.id == "policy.consistency_state" })?.status == .ready)
        #expect(report.sections.first(where: { $0.domain == .orchestration })?.items.first(where: { $0.id == "orchestration.checkpoint_replay" })?.status == .ready)
        #expect(report.sections.first(where: { $0.domain == .observability })?.items.first(where: { $0.id == "observability.self_inspection" })?.status == .ready)
        #expect(report.sections.first(where: { $0.domain == .evaluation })?.items.first(where: { $0.id == "evaluation.safe_evolution" })?.status == .ready)
        #expect(report.sections.first(where: { $0.domain == .delivery })?.items.first(where: { $0.id == "delivery.self_portrait" })?.status == .ready)
    }

    @Test
    func evolutionFactsPreferActiveCheckpointWhenReviewQueueIsEmpty() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHistory(into: context)
        try context.save()

        let lineageSummary = BASEvolutionLineageSummary(
            recordedAt: date("2026-04-10T21:15:00.000Z"),
            sessionID: "before.quick.active-lineage",
            taskType: "reflection",
            riskLevel: "medium",
            permitMode: "compare",
            hostGatePercent: 74,
            thoughtFoldChecksum: "fold-active",
            updateTicketSummaries: ["capture active checkpoint"],
            guardrailFindings: ["Recovered active checkpoint"],
            recommendedKillSwitches: ["lineage-review"]
        )
        let persistedLineage = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-active",
            createdAt: date("2026-04-10T21:16:00.000Z"),
            mode: .quick,
            approvalState: .automatic,
            rollbackReady: true,
            diffSummary: ["Automatic checkpoint"],
            eBrain: DeveloperDecisionReplayEBrainSummary(lineageSummary: lineageSummary)
        )

        let export = await DecisionTestingInterface.runtimeExport(
            quick: DecisionMemorySystem.fetchCheckEvents(in: context),
            balance: [],
            mirror: [],
            preferences: .default,
            persistedCheckpointLineages: [persistedLineage],
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        let facts = DecisionCapabilityCoverageBuilder.evolutionFacts(
            from: export,
            currentBrainState: nil
        )

        #expect(export.evolutionControlSurface.activeCheckpoint?.checkpointID == "checkpoint-active")
        #expect(export.evolutionControlSurface.reviewCheckpoint == nil)
        #expect(facts.recoveredCheckpoint?.checkpointID == "checkpoint-active")
        #expect(facts.recoveredAuditFindingCount == 1)
        #expect(facts.recoveredTicketCount == 1)
    }

    @Test
    func evolutionFactsDoNotTreatReviewHeadAsRecoveredCheckpointWithoutActivePath() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHistory(into: context)
        try context.save()

        let reviewLineage = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-review-only",
            createdAt: date("2026-04-10T21:16:00.000Z"),
            mode: .mirror,
            approvalState: .reviewSuggested,
            rollbackReady: true,
            diffSummary: ["Review-only checkpoint should stay off the recovered active path."],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-10T21:15:00.000Z"),
                    sessionID: "before.mirror.review-only",
                    taskType: "reflection",
                    riskLevel: "high",
                    permitMode: "delay",
                    hostGatePercent: 79,
                    thoughtFoldChecksum: "fold-review-only",
                    updateTicketSummaries: ["review-only ticket"],
                    guardrailFindings: ["Review-only guardrail"],
                    recommendedKillSwitches: ["host-write"]
                )
            )
        )

        let export = await DecisionTestingInterface.runtimeExport(
            quick: DecisionMemorySystem.fetchCheckEvents(in: context),
            balance: [],
            mirror: [],
            preferences: .default,
            persistedCheckpointLineages: [reviewLineage],
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        let facts = DecisionCapabilityCoverageBuilder.evolutionFacts(
            from: export,
            currentBrainState: nil
        )

        #expect(export.evolutionControlSurface.activeCheckpoint == nil)
        #expect(export.evolutionControlSurface.reviewCheckpoint?.checkpointID == "checkpoint-review-only")
        #expect(facts.recoveredCheckpoint == nil)
        #expect(facts.latestPersistedLineage?.checkpointID == "checkpoint-review-only")
        #expect(facts.recoveredEBrainAvailable == true)
    }

    @Test
    func buildUsesExplicitEvolutionFactsWithoutRecomputingRecoverySignals() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHistory(into: context)
        try context.save()

        let export = await DecisionTestingInterface.runtimeExport(
            quick: DecisionMemorySystem.fetchCheckEvents(in: context),
            balance: DecisionMemorySystem.fetchBalanceRecords(in: context),
            mirror: DecisionMemorySystem.fetchMirrorRecords(in: context),
            preferences: .default,
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        let lineageSummary = BASEvolutionLineageSummary(
            recordedAt: date("2026-04-10T21:15:00.000Z"),
            sessionID: "before.quick.lineage",
            taskType: "conflict",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 82,
            thoughtFoldChecksum: "fold-checkpoint",
            updateTicketSummaries: ["review after cooldown"],
            guardrailFindings: ["Checkpoint guardrail matched"],
            recommendedKillSwitches: ["host-write"]
        )
        let recoveredCheckpoint = DecisionReviewCheckpointSnapshot(
            checkpointID: "checkpoint-control",
            createdAt: date("2026-04-10T21:16:00.000Z"),
            mode: .quick,
            approvalState: .reviewSuggested,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["Control-surface checkpoint"],
            eBrain: DeveloperDecisionReplayEBrainSummary(lineageSummary: lineageSummary)
        )
        let controlFacts = DecisionEvolutionCoverageFacts(
            recoveredCheckpoint: recoveredCheckpoint,
            latestPersistedLineage: DecisionEvolutionLineageSnapshot(
                checkpointID: "checkpoint-control",
                createdAt: date("2026-04-10T21:16:00.000Z"),
                mode: .quick,
                approvalState: .reviewSuggested,
                rollbackReady: true,
                diffSummary: ["Control-surface checkpoint"],
                eBrain: DeveloperDecisionReplayEBrainSummary(lineageSummary: lineageSummary)
            ),
            recoveredEBrainAvailable: true,
            recoveredAuditFindingCount: recoveredCheckpoint.auditFindings.count,
            recoveredTicketCount: recoveredCheckpoint.updateTicketSummaries.count
        )

        let report = DecisionCapabilityCoverageBuilder.build(
            from: export,
            currentBrainState: nil,
            evolutionFacts: controlFacts
        )

        #expect(report.sections.first(where: { $0.domain == .context })?.items.first(where: { $0.id == "context.summary_layer" })?.status == .ready)
        #expect(report.sections.first(where: { $0.domain == .policy })?.items.first(where: { $0.id == "policy.consistency_state" })?.status == .ready)
        #expect(report.sections.first(where: { $0.domain == .orchestration })?.items.first(where: { $0.id == "orchestration.checkpoint_replay" })?.status == .ready)
        #expect(report.sections.first(where: { $0.domain == .observability })?.items.first(where: { $0.id == "observability.self_inspection" })?.status == .ready)
        #expect(report.sections.first(where: { $0.domain == .evaluation })?.items.first(where: { $0.id == "evaluation.safe_evolution" })?.status == .ready)
        #expect(report.sections.first(where: { $0.domain == .delivery })?.items.first(where: { $0.id == "delivery.self_portrait" })?.status == .ready)
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
