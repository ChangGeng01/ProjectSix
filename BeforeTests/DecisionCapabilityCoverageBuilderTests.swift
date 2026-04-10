import Foundation
import SwiftData
import Testing
import BASAdmin
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
