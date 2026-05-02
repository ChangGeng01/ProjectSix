import XCTest
import BASHostKit
import BASMemory
import BASObservability
import BASRuntimeCore

/// M399 — pin the contract that the sample-host
/// `--cthulhu-end-to-end-demo` mode relies on. Same pattern as
/// M333/M334/M335 (sample-host demo tests pin BAS substrate
/// contracts, not the executable's symbols which aren't visible
/// to test targets). This file exercises the SAME composition the
/// demo composes:
///
///   1. `BASHostRuntime.startSession(...)` produces a turn with
///      a non-nil `actionPermit` + `sovereignAuditEntry`.
///   2. The audit entry's `signalRefs` contain the always-on
///      Cthulhu-wire prefixes (M303 abyssal magnitude, M304
///      anchor tone, M305 lifecycle tickets).
///   3. The turn's `actionPermit.assertionCeiling` is one of the
///      canonical strictness-ranking values the M385 cap can
///      produce — proving the cap path is plumbed through the
///      production pipeline.
///   4. `BASUpdateTicketLifecycleCoordinator
///      .submitWithForbiddenGate(_:forbidden:)` against the
///      runtime's first ticket paired with a sovereign-rejected
///      forbidden candidate yields `.rejected` with the typed
///      gate reason code — proves the M391 wire is callable from
///      a real production caller using a real production-path
///      ticket.
final class QinaoSampleHostCthulhuEndToEndDemoTests: XCTestCase {

    private func makeRuntime() -> BASHostRuntime {
        BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "host.m399.tests",
                policyProfileID: "host.m399.tests.policy",
                prefersPureLocal: true,
                defaultDeviceState:
                    BASHostConfiguration
                        .fixtureDefaultDeviceState,
                console: .generic,
                lifecycleBehavior: .generic,
                workflowBehavior: .generic,
                cognitionBehavior: .generic,
                presentation: .generic,
                runtimeTuning:
                    BASEBrainRuntimeSynthesisPolicy.generic
                        .withSchemaVersion(
                            "host.runtime-synthesis.m399.tests.v1"),
                runtimePolicyLineage:
                    BASRuntimePolicyLineage(
                        bundleVersion: "host.m399.tests.bundle.v1",
                        providerRoutingRegistryVersion:
                            "host.m399.tests.routing-registry.v1",
                        providerRoutingPolicyID:
                            "host.m399.tests.routing-policy.v1",
                        runtimeTuningRegistryVersion:
                            "host.m399.tests.tuning-registry.v1",
                        runtimeTuningPolicyID:
                            "host.m399.tests.tuning-policy.v1",
                        resolutionSourceID: "m399_tests"),
                hostRhythmProfile: .generic))
    }

    private func driveOneTurn() throws -> BASEBrainTurnResult {
        let runtime = makeRuntime()
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt:
                    "Help me weigh whether to commit to a habit " +
                    "I'm uncertain about.",
                title: "M399 end-to-end test",
                riskLevel: .medium))
        return try XCTUnwrap(result.eBrainTurn)
    }

    // MARK: - 1. Runtime turn shape — actionPermit + auditEntry

    func testRuntimeTurnHasPermitAndAuditEntry() throws {
        let turn = try driveOneTurn()
        XCTAssertNotNil(turn.sovereignAuditEntry)
        // permit.mode is one of the canonical BASActionPermitMode
        // raw values regardless of escalation outcome.
        let canonicalModes: Set<String> = [
            "answer", "mirror", "compare", "delay",
            "draft_only", "local_only", "block",
            "replace", "escalate",
        ]
        XCTAssertTrue(
            canonicalModes.contains(turn.actionPermit.mode.rawValue))
    }

    // MARK: - 2. Always-on Cthulhu wires emit codes

    func testAlwaysOnWiresEmitAuditCodes() throws {
        let turn = try driveOneTurn()
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)
        let signalRefs = auditEntry.signalRefs
        // M303 abyssal magnitude — always emits.
        XCTAssertTrue(
            signalRefs.contains { $0.hasPrefix("abyssal.magnitude:") },
            "M303 abyssal-magnitude code missing from audit signalRefs")
        // M304 human anchor tone — always emits.
        XCTAssertTrue(
            signalRefs.contains { $0.hasPrefix("humanAnchor.tone:") },
            "M304 human-anchor-tone code missing from audit signalRefs")
        // M305 lifecycle.tickets — emits when ≥ 1 ticket; the
        // fixture produces ≥ 1 deterministically.
        XCTAssertGreaterThanOrEqual(turn.updateTickets.count, 1)
        XCTAssertTrue(
            signalRefs.contains { $0.hasPrefix("lifecycle.tickets:") },
            "M305 lifecycle-tickets code missing from audit signalRefs")
    }

    // MARK: - 3. Permit assertionCeiling is canonical

    func testPermitAssertionCeilingIsCanonical() throws {
        let turn = try driveOneTurn()
        // Post-M392 the M385 cap fires before render; the
        // resulting permit's assertionCeiling must be one of
        // the canonical strictness vocab values (substrate
        // canonical strings + reserve enum raw values).
        let canonical: Set<String> = [
            "default", "standard", "guarded", "minimal",
            "unrestricted", "provisional", "qualified",
            "meta-only", "none",
        ]
        XCTAssertTrue(
            canonical.contains(turn.actionPermit.assertionCeiling),
            "permit.assertionCeiling = " +
            "\(turn.actionPermit.assertionCeiling) is not canonical")
    }

    // MARK: - 4. M391 production caller refuses paired ticket

    func testM391ProductionCallerRefusesRejectedTicket() async throws {
        let turn = try driveOneTurn()
        let firstTicket = try XCTUnwrap(turn.updateTickets.first)

        let coordinator = BASUpdateTicketLifecycleCoordinator(
            clock: { Date(timeIntervalSince1970: 1_700_000_000) })
        let rejectedCandidate = BASForbiddenKnowledgeCandidate(
            candidateID: "fk-\(firstTicket.ticketID)",
            sourceRefs: [firstTicket.ticketID],
            riskReasons: ["m399-test-rejected"],
            contaminationRefs: [],
            coolingPeriod: 0,
            shadowTrialPolicy: .standard,
            sovereignReviewState: .rejected)

        let state = try await coordinator.submitWithForbiddenGate(
            firstTicket,
            forbidden: rejectedCandidate)
        XCTAssertEqual(state, .rejected)

        let entry = await coordinator.entry(
            ticketID: firstTicket.ticketID)
        XCTAssertEqual(entry?.state, .rejected)
        let lastReasons = entry?.history.last?.reasonCodes ?? []
        XCTAssertTrue(lastReasons.contains(
            "lifecycle.gated:forbidden:sovereign-rejected"))
    }
}
