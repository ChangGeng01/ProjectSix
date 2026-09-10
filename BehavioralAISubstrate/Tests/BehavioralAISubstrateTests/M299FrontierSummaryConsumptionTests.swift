import XCTest
@testable import BASAdmin
@testable import BASHostKit
import BASOrchestration
import BASRuntimeCore

/// M299 — pin that `BASCandidateFrontierSummary.summarize()`
/// (M284, schema-only since 2026-04-30) is consumed by the
/// L14 sovereign audit entry on every turn that completes the
/// neural materialization seam.
///
/// Pre-M299 the summary was a pure value-type derive helper
/// reachable only via `BASCandidateObservationBundle.summarize()`,
/// referenced exclusively from its own unit tests. After M299
/// `EBrainRuntimeCoordinator.runTurn` plumbs the bundle into
/// `buildSovereignAuditEntry`, which appends three additive
/// signal codes to `signalRefs`:
///
///   - `frontier.status:<statusCode>` — `dominant-clear` /
///     `guardian-held` / `diversity-only` / `empty`
///   - `frontier.candidates:<N>` — distinct candidate count
///   - `frontier.diversity:emitted` (only when diversity signal
///     fired, i.e. frontier had ≥2 candidates)
///
/// The codes flow through `signalRefs` (additive metadata that
/// digests into the entry signature deterministically). The
/// hash chain semantics from M91/M283/M271 are preserved —
/// signature simply digests a longer ordered list.
final class M299FrontierSummaryConsumptionTests: XCTestCase {

    // MARK: - Configuration helpers

    private func makeRuntimePolicyLineage() -> BASRuntimePolicyLineage {
        BASRuntimePolicyLineage(
            bundleVersion: "test.m299.bundle.v1",
            providerRoutingRegistryVersion:
                "test.m299.routing-registry.v1",
            providerRoutingPolicyID:
                "test.m299.routing-policy.v1",
            runtimeTuningRegistryVersion:
                "test.m299.tuning-registry.v1",
            runtimeTuningPolicyID:
                "test.m299.tuning-policy.v1",
            resolutionSourceID: "test_bundle"
        )
    }

    private func makeTuning() -> BASEBrainRuntimeSynthesisPolicy {
        var tuning = BASEBrainRuntimeSynthesisPolicy.generic
            .withSchemaVersion(
                "host.runtime-synthesis.m299.v1")
        tuning.stateTransitions.runModeRules =
            tuning.stateTransitions
                .synthesizedRunModeRules(
                    wakeIntent: tuning.wakeIntent)
        return tuning
    }

    private func makeRuntime() -> BASHostRuntime {
        BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "host.m299",
                policyProfileID: "host.m299.policy",
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

    private func runTurn(
        prompt: String = "Help me think through a small task.",
        title: String = "M299 frontier coverage",
        riskLevel: BASHostRiskLevel = .medium
    ) throws -> BASEBrainTurnResult {
        let runtime = makeRuntime()
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: prompt,
                title: title,
                riskLevel: riskLevel
            )
        )
        return try XCTUnwrap(result.eBrainTurn)
    }

    // MARK: - 1. Frontier status code lands in signalRefs

    /// A normal interactive turn produces a candidate frontier;
    /// M299 must surface its statusCode (one of the four canonical
    /// values) in `auditEntry.signalRefs`.
    func testFrontierStatusCodeIsEmittedInSignalRefs() throws {
        let turn = try runTurn()
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)

        let frontierStatusCodes = auditEntry.signalRefs.filter {
            $0.hasPrefix("frontier.status:")
        }
        XCTAssertEqual(
            frontierStatusCodes.count, 1,
            "exactly one frontier status code per turn")
        let canonicalSuffixes: Set<String> = [
            "dominant-clear",
            "guardian-held",
            "diversity-only",
            "empty"
        ]
        let suffix = frontierStatusCodes[0]
            .replacingOccurrences(
                of: "frontier.status:", with: "")
        XCTAssertTrue(
            canonicalSuffixes.contains(suffix),
            "statusCode must be one of the four canonical " +
            "values defined in BASCandidateFrontierSummary " +
            "(was \"\(suffix)\")")
    }

    // MARK: - 2. Candidate count lands as additive metadata

    /// `frontier.candidates:N` always appears alongside the
    /// status code so audit consumers can grep "did this turn
    /// produce candidates" without parsing the trace.
    func testFrontierCandidateCountIsEmitted() throws {
        let turn = try runTurn()
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)

        let countCodes = auditEntry.signalRefs.filter {
            $0.hasPrefix("frontier.candidates:")
        }
        XCTAssertEqual(
            countCodes.count, 1,
            "exactly one candidate count code per turn")
        let suffix = countCodes[0]
            .replacingOccurrences(
                of: "frontier.candidates:", with: "")
        XCTAssertNotNil(
            Int(suffix),
            "frontier.candidates suffix must be parseable " +
            "as an integer (was \"\(suffix)\")")
    }

    // MARK: - 3. signalRefs deterministic ordering preserves
    //           backward-compat — codes coexist with risk /
    //           permit / fold codes already in M298 entries.

    /// Pre-M299 entries had `risk:* / permit:* / fold:*` codes;
    /// post-M299 these still appear, with frontier codes added.
    /// Pin the coexistence so a future PR doesn't accidentally
    /// drop existing codes.
    func testLegacyCodesStillPresentAlongsideFrontierCodes()
        throws
    {
        let turn = try runTurn()
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)
        let signal = auditEntry.signalRefs

        XCTAssertTrue(
            signal.contains(where: { $0.hasPrefix("risk:") }),
            "risk: prefix must remain in signalRefs")
        XCTAssertTrue(
            signal.contains(where: { $0.hasPrefix("permit:") }),
            "permit: prefix must remain in signalRefs")
        XCTAssertTrue(
            signal.contains(where: { $0.hasPrefix("fold:") }),
            "fold: prefix must remain in signalRefs")
        XCTAssertTrue(
            signal.contains(where: {
                $0.hasPrefix("frontier.status:")
            }),
            "frontier.status: must be added by M299")
    }

    // MARK: - 4. Codes are deterministic across two identical
    //           turns (modulo session/audit IDs that include
    //           timestamps).

    /// Drive two identical configurations through the runtime;
    /// the frontier status code must agree (deterministic for
    /// the same inputs).
    func testFrontierStatusIsDeterministicAcrossRuns() throws {
        let turn1 = try runTurn(
            prompt: "Identical M299 prompt.",
            title: "Identical M299 title")
        let turn2 = try runTurn(
            prompt: "Identical M299 prompt.",
            title: "Identical M299 title")
        let entry1 = try XCTUnwrap(turn1.sovereignAuditEntry)
        let entry2 = try XCTUnwrap(turn2.sovereignAuditEntry)

        let status1 = entry1.signalRefs.first {
            $0.hasPrefix("frontier.status:")
        }
        let status2 = entry2.signalRefs.first {
            $0.hasPrefix("frontier.status:")
        }
        XCTAssertNotNil(status1)
        XCTAssertNotNil(status2)
        XCTAssertEqual(
            status1, status2,
            "identical turns must produce the same frontier " +
            "status code")
    }
}
