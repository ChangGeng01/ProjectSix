import Foundation
import Testing
import BASHostKit
@testable import Before

@MainActor
struct DecisionEvolutionKillSwitchStoreTests {
    @Test
    func storePersistsAndClearsActiveKillSwitches() {
        let defaults = UserDefaults(suiteName: "DecisionEvolutionKillSwitchStoreTests.store")!
        defaults.removePersistentDomain(forName: "DecisionEvolutionKillSwitchStoreTests.store")

        #expect(DecisionEvolutionKillSwitchStore.load(defaults: defaults).isEmpty)

        let enabled = DecisionEvolutionKillSwitchStore.setEnabled(
            .forceGuardMode,
            enabled: true,
            defaults: defaults,
            now: Date(timeIntervalSince1970: 10)
        )

        #expect(enabled == [.forceGuardMode])
        #expect(DecisionEvolutionKillSwitchStore.load(defaults: defaults) == [.forceGuardMode])

        let merged = DecisionEvolutionKillSwitchStore.setEnabled(
            .requireReviewedWrites,
            enabled: true,
            defaults: defaults,
            now: Date(timeIntervalSince1970: 20)
        )

        #expect(Set(merged) == Set([.forceGuardMode, .requireReviewedWrites]))

        _ = DecisionEvolutionKillSwitchStore.setEnabled(
            .forceGuardMode,
            enabled: false,
            defaults: defaults,
            now: Date(timeIntervalSince1970: 30)
        )

        #expect(DecisionEvolutionKillSwitchStore.load(defaults: defaults) == [.requireReviewedWrites])

        DecisionEvolutionKillSwitchStore.clear(
            defaults: defaults,
            now: Date(timeIntervalSince1970: 40)
        )
        #expect(DecisionEvolutionKillSwitchStore.load(defaults: defaults).isEmpty)
    }

    @Test
    func legacyKillSwitchPolicyIDsResolveIntoExecutableRuntimePolicy() throws {
        let defaults = UserDefaults(suiteName: "DecisionEvolutionKillSwitchStoreTests.legacy")!
        defaults.removePersistentDomain(forName: "DecisionEvolutionKillSwitchStoreTests.legacy")

        let legacyPolicy = DecisionEvolutionKillSwitchPolicy(
            activeKillSwitchIDs: ["disableHighRiskAutoAction", "host-write", "external-tools"],
            updatedAt: Date(timeIntervalSince1970: 50)
        )
        let data = try JSONEncoder().encode(legacyPolicy)
        defaults.set(data, forKey: "before.evolutionKillSwitchPolicy")

        #expect(
            DecisionEvolutionKillSwitchStore.load(defaults: defaults) == [
                .forceProtectedPermit,
                .requireReviewedWrites
            ]
        )
    }

    @Test
    func killSwitchPolicyPersistsCurrentSchemaVersionByDefault() throws {
        let policy = DecisionEvolutionKillSwitchPolicy(
            activeKillSwitchIDs: ["force_guard_mode"],
            updatedAt: Date(timeIntervalSince1970: 60)
        )

        let data = try JSONEncoder().encode(policy)
        let decoded = try JSONDecoder().decode(DecisionEvolutionKillSwitchPolicy.self, from: data)

        #expect(decoded.schemaVersion == DecisionEvolutionKillSwitchPolicy.currentSchemaVersion)
        #expect(decoded.activeKillSwitchIDs == ["force_guard_mode"])
        #expect(decoded.updatedAt == Date(timeIntervalSince1970: 60))
    }

    @Test
    func killSwitchPolicyLoadsActiveIDsAcrossSchemaVersionStrings() throws {
        let defaults = UserDefaults(suiteName: "DecisionEvolutionKillSwitchStoreTests.versioned")!
        defaults.removePersistentDomain(forName: "DecisionEvolutionKillSwitchStoreTests.versioned")

        let policy = DecisionEvolutionKillSwitchPolicy(
            schemaVersion: "9.9.9",
            activeKillSwitchIDs: [BASKillSwitchID.disableFastPath.rawValue, "host-write"],
            updatedAt: Date(timeIntervalSince1970: 70)
        )
        let data = try JSONEncoder().encode(policy)
        defaults.set(data, forKey: "before.evolutionKillSwitchPolicy")

        #expect(
            DecisionEvolutionKillSwitchStore.load(defaults: defaults) == [
                .disableFastPath,
                .requireReviewedWrites
            ]
        )
    }

    @Test
    func runtimeExportFlightDeckBlocksWhenHostKillSwitchPolicyIsActive() async {
        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            activeKillSwitches: [BASKillSwitchID.forceGuardMode.rawValue, BASKillSwitchID.forceProtectedPermit.rawValue]
        )

        let flightDeck = export.flightDeck

        #expect(flightDeck.releaseControlSummary.state == .blocked)
        #expect(flightDeck.releaseControlSummary.killSwitches.contains(BASKillSwitchID.forceGuardMode.rawValue))
        #expect(flightDeck.releaseControlSummary.killSwitches.contains(BASKillSwitchID.forceProtectedPermit.rawValue))
        #expect(flightDeck.releaseControlSummary.activeKillSwitches.count == 2)
    }

    @Test
    func runtimeExportSeparatesActiveAndRecommendedKillSwitchFacts() async {
        let lineageSummary = BASEvolutionLineageSummary(
            recordedAt: Date(timeIntervalSince1970: 10),
            sessionID: "killswitch-separation",
            taskType: "conflict",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 88,
            thoughtFoldChecksum: "fold-kill-switch",
            updateTicketSummaries: ["checkpoint pending review"],
            activeKillSwitches: ["require_reviewed_writes"],
            guardrailFindings: ["review queue warning"],
            recommendedKillSwitches: ["external-tools"]
        )
        let lineage = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-killswitch",
            createdAt: Date(timeIntervalSince1970: 20),
            mode: .quick,
            approvalState: .automatic,
            rollbackReady: true,
            diffSummary: ["Recovered checkpoint"],
            eBrain: DeveloperDecisionReplayEBrainSummary(lineageSummary: lineageSummary)
        )

        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            activeKillSwitches: [BASKillSwitchID.forceGuardMode.rawValue],
            persistedCheckpointLineages: [lineage]
        )

        let releaseSummary = export.flightDeck.releaseControlSummary

        #expect(releaseSummary.activeKillSwitches.contains(BASKillSwitchID.forceGuardMode.rawValue))
        #expect(releaseSummary.activeKillSwitches.contains("require_reviewed_writes"))
        #expect(releaseSummary.recommendedKillSwitches == ["external-tools"])
        #expect(releaseSummary.killSwitches == [
            BASKillSwitchID.forceGuardMode.rawValue,
            "require_reviewed_writes",
            "external-tools"
        ])
    }
}
