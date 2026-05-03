import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASObservability
@testable import BASOrchestration

/// M457 (chapter 一百二十) — pin the integration contract that
/// `BASForbiddenCandidateZoneGate` (chapter 一百十七 M447) is
/// now load-bearing in the `BASUpdateTicketLifecycleCoordinator`
/// actor path. Mirrors the M391 test pattern for the chapter
/// 一百十七 zone gate.
///
/// What this file pins:
///
///   1. `submitWithForbiddenZoneGate` accepts when zone is nil →
///      entry persists in `.proposed`.
///   2. `submitWithForbiddenZoneGate` accepts when candidate not
///      in zone → entry persists in `.proposed`.
///   3. `submitWithForbiddenZoneGate` accepts even when candidate
///      IS in zone (per chapter 一百十七 doctrine —
///      `.registerCandidate` always allowed) — registration
///      carries no trust.
///   4. `startTrialWithForbiddenZoneGate` accepts when no zone.
///   5. `startTrialWithForbiddenZoneGate` accepts when candidate
///      not in zone.
///   6. `startTrialWithForbiddenZoneGate` rejects when candidate
///      IS in zone AND release conditions not satisfied.
///   7. `startTrialWithForbiddenZoneGate` accepts when candidate
///      IS in zone AND ALL release conditions satisfied.
///   8. `ingestTicketsWithForbiddenZoneGate` accepts all tickets
///      with the zone (registration always allowed).
final class M457ForbiddenZoneGateLifecycleIntegrationTests: XCTestCase {

    // MARK: - Fixture helpers

    private func makeTicket(id: String = "tk-1") -> BASUpdateTicket {
        BASUpdateTicket(
            ticketID: id,
            sessionRef: "sess-zone-test",
            summary: "zone test ticket",
            confidence: 0.5)
    }

    private func makeZone(
        quarantinedRefs: [String],
        releaseConditions: [String]
    ) -> BASForbiddenCandidateZone {
        BASForbiddenCandidateZone(
            zoneID: "zone-test",
            quarantinedCandidateRefs: quarantinedRefs,
            quarantineReasonCodes:
                Array(repeating: "test-reason",
                      count: quarantinedRefs.count),
            releaseConditions: releaseConditions,
            auditRef: "audit-zone-test")
    }

    private func makeCoordinator() -> BASUpdateTicketLifecycleCoordinator {
        BASUpdateTicketLifecycleCoordinator(
            clock: { Date(timeIntervalSince1970: 1_700_000_000) })
    }

    // MARK: - 1. nil zone accepts

    func testSubmitWithNilZoneAccepts() async throws {
        let coord = makeCoordinator()
        let state = try await coord.submitWithForbiddenZoneGate(
            makeTicket(),
            zone: nil,
            satisfiedReleaseConditions: [])
        XCTAssertEqual(state, .proposed)
    }

    // MARK: - 2. Candidate not in zone accepts

    func testSubmitWithCandidateNotInZoneAccepts() async throws {
        let coord = makeCoordinator()
        let zone = makeZone(
            quarantinedRefs: ["other-cand"],
            releaseConditions: ["sovereign-warrant"])
        let state = try await coord.submitWithForbiddenZoneGate(
            makeTicket(),
            zone: zone,
            satisfiedReleaseConditions: [])
        XCTAssertEqual(state, .proposed)
    }

    // MARK: - 3. Quarantined candidate still accepts at submit
    //           (per chapter 一百十七 doctrine)

    func testSubmitWithQuarantinedCandidateStillAccepts() async throws {
        // Per M447 doctrine, .registerCandidate always allowed
        // even when candidate is in zone. Submit is the
        // registration phase; trust hasn't been granted yet.
        let coord = makeCoordinator()
        let zone = makeZone(
            quarantinedRefs: ["tk-1"],
            releaseConditions: ["sovereign-warrant"])
        let state = try await coord.submitWithForbiddenZoneGate(
            makeTicket(),
            zone: zone,
            satisfiedReleaseConditions: [])
        XCTAssertEqual(state, .proposed,
                       "registerCandidate always allowed per " +
                       "chapter 一百十七 M447 doctrine")
    }

    // MARK: - 4. startTrial with no zone accepts

    func testStartTrialWithNoZoneAccepts() async throws {
        let coord = makeCoordinator()
        _ = try await coord.submit(makeTicket())
        try await coord.startTrialWithForbiddenZoneGate(
            ticketID: "tk-1",
            trialRecordRef: "trial-1",
            candidateRef: "tk-1",
            zone: nil,
            satisfiedReleaseConditions: [])
        let entry = await coord.entry(ticketID: "tk-1")
        XCTAssertEqual(entry?.state, .trialing)
    }

    // MARK: - 5. startTrial with candidate not in zone accepts

    func testStartTrialWithCandidateNotInZoneAccepts() async throws {
        let coord = makeCoordinator()
        _ = try await coord.submit(makeTicket())
        let zone = makeZone(
            quarantinedRefs: ["other-cand"],
            releaseConditions: ["sovereign-warrant"])
        try await coord.startTrialWithForbiddenZoneGate(
            ticketID: "tk-1",
            trialRecordRef: "trial-1",
            candidateRef: "tk-1",
            zone: zone,
            satisfiedReleaseConditions: [])
        let entry = await coord.entry(ticketID: "tk-1")
        XCTAssertEqual(entry?.state, .trialing)
    }

    // MARK: - 6. startTrial with quarantined candidate + unmet
    //           conditions REJECTS

    func testStartTrialWithQuarantinedAndUnmetConditionsRejects() async throws {
        let coord = makeCoordinator()
        _ = try await coord.submit(makeTicket())
        let zone = makeZone(
            quarantinedRefs: ["tk-1"],
            releaseConditions: ["sovereign-warrant", "host-recall"])
        try await coord.startTrialWithForbiddenZoneGate(
            ticketID: "tk-1",
            trialRecordRef: "trial-1",
            candidateRef: "tk-1",
            zone: zone,
            satisfiedReleaseConditions: ["sovereign-warrant"])  // partial
        let entry = await coord.entry(ticketID: "tk-1")
        XCTAssertEqual(entry?.state, .rejected)
        let lastHistory = entry?.history.last
        XCTAssertNotNil(lastHistory)
        XCTAssertTrue(
            lastHistory?.reasonCodes.contains(where: {
                $0.contains("lifecycle.zoneGate:denied:") &&
                $0.contains("startShadowTrial")
            }) ?? false,
            "rejection must carry zone gate denial reason code")
        XCTAssertTrue(
            lastHistory?.reasonCodes.contains(
                "trial-record-ref:trial-1") ?? false,
            "trial-record-ref preserved in rejection")
    }

    // MARK: - 7. startTrial with all conditions met UNBLOCKS

    func testStartTrialWithAllReleaseConditionsMetAccepts() async throws {
        let coord = makeCoordinator()
        _ = try await coord.submit(makeTicket())
        let zone = makeZone(
            quarantinedRefs: ["tk-1"],
            releaseConditions: ["sovereign-warrant"])
        try await coord.startTrialWithForbiddenZoneGate(
            ticketID: "tk-1",
            trialRecordRef: "trial-1",
            candidateRef: "tk-1",
            zone: zone,
            satisfiedReleaseConditions: ["sovereign-warrant"])
        let entry = await coord.entry(ticketID: "tk-1")
        XCTAssertEqual(entry?.state, .trialing,
                       "ALL release conditions met → unblocked")
    }

    // MARK: - 8. Batch ingest accepts all (registration always
    //           allowed)

    func testBatchIngestAcceptsAllRegistrations() async throws {
        let coord = makeCoordinator()
        let zone = makeZone(
            quarantinedRefs: ["tk-1", "tk-2"],
            releaseConditions: ["sovereign-warrant"])
        let count = await coord.ingestTicketsWithForbiddenZoneGate(
            [makeTicket(id: "tk-1"), makeTicket(id: "tk-2"),
             makeTicket(id: "tk-3")],
            zone: zone,
            candidateRefByTicketID: [:],
            satisfiedReleaseConditions: [])
        XCTAssertEqual(count, 3,
                       "all 3 tickets register; quarantine kicks " +
                       "in only at trial / promote")
    }
}

// MARK: - M456 — L8 thermal layer audit emission tests

/// M456 (chapter 一百二十) — pin that
/// `BASMemoryTemperatureLayer` is now derived per turn and
/// emitted as `cthulhu.memory.thermal:<rawValue>` in the
/// sovereign audit entry.
final class M456MemoryThermalLayerWiringTests: XCTestCase {

    private func makeRuntimePolicyLineage() -> BASRuntimePolicyLineage {
        BASRuntimePolicyLineage(
            bundleVersion: "test.m456.bundle.v1",
            providerRoutingRegistryVersion:
                "test.m456.routing-registry.v1",
            providerRoutingPolicyID:
                "test.m456.routing-policy.v1",
            runtimeTuningRegistryVersion:
                "test.m456.tuning-registry.v1",
            runtimeTuningPolicyID:
                "test.m456.tuning-policy.v1",
            resolutionSourceID: "test_bundle"
        )
    }

    private func makeTuning() -> BASEBrainRuntimeSynthesisPolicy {
        var tuning = BASEBrainRuntimeSynthesisPolicy.generic
            .withSchemaVersion(
                "host.runtime-synthesis.m456.v1")
        tuning.stateTransitions.runModeRules =
            tuning.stateTransitions
                .synthesizedRunModeRules(
                    wakeIntent: tuning.wakeIntent)
        return tuning
    }

    private func makeRuntime() -> BASHostRuntime {
        BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "host.m456",
                policyProfileID: "host.m456.policy",
                prefersPureLocal: true,
                defaultDeviceState:
                    BASHostConfiguration.fixtureDefaultDeviceState,
                console: .generic,
                lifecycleBehavior: .generic,
                workflowBehavior: .generic,
                cognitionBehavior: .generic,
                presentation: .generic,
                runtimeTuning: makeTuning(),
                runtimePolicyLineage:
                    makeRuntimePolicyLineage(),
                hostRhythmProfile: .generic
            )
        )
    }

    /// Pin: every turn produces a memory thermal layer code in
    /// audit signalRefs. Layer must be one of the 5 valid
    /// `BASMemoryTemperatureLayer` raw values.
    func testMemoryThermalLayerAlwaysAppearsInSignalRefs() throws {
        let runtime = makeRuntime()
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: "test prompt for thermal layer",
                title: "M456 thermal",
                riskLevel: .medium))
        let turn = try XCTUnwrap(result.eBrainTurn)
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)
        let codes = auditEntry.signalRefs.filter {
            $0.hasPrefix("cthulhu.memory.thermal:")
        }
        XCTAssertEqual(codes.count, 1,
                       "exactly one cthulhu.memory.thermal code per turn")
        let suffix = codes[0]
            .replacingOccurrences(
                of: "cthulhu.memory.thermal:", with: "")
        let validRawValues: Set<String> = Set(
            BASMemoryTemperatureLayer.allCases.map(\.rawValue))
        XCTAssertTrue(
            validRawValues.contains(suffix),
            "thermal layer suffix must be a valid " +
            "BASMemoryTemperatureLayer rawValue (got \"\(suffix)\")")
    }
}
