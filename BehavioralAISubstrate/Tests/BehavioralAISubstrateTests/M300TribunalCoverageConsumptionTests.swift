import XCTest
@testable import BASAdmin
@testable import BASHostKit
import BASOrchestration
import BASRuntimeCore

/// M300 — pin that `BASTribunalCoverageCheck.report(for:)`
/// (M285, schema-only since 2026-04-30) is consumed by the
/// L14 sovereign audit entry on every turn that runs the
/// tri-self tribunal seam (M55).
///
/// Pre-M300 the coverage report was a pure value-type derive
/// helper reachable only via `BASTribunalCoverageCheck.report(...)`,
/// referenced exclusively from its own unit tests. After M300
/// `EBrainRuntimeCoordinator.runTurn` plumbs `thoughtFrame
/// .tribunalObservationBundle` into `buildSovereignAuditEntry`,
/// which appends two additive signal codes to `signalRefs`:
///
///   - `tribunal.status:<statusCode>` — `full-body-converged`
///     / `full-body-dissent` / `full-body-incomplete`
///     / `partial-N-voices` / `empty`
///   - `tribunal.voices:<N>` — count of voices that emitted
///     at least one observation (0..3)
///
/// Hash chain semantics from M91/M283/M271 are preserved —
/// signature simply digests a longer ordered list. The
/// invariant #2 ("神经不掌权") is unchanged: tribunal coverage
/// is metadata, not a verdict-escalation signal.
final class M300TribunalCoverageConsumptionTests: XCTestCase {

    // MARK: - Configuration helpers

    private func makeRuntimePolicyLineage() -> BASRuntimePolicyLineage {
        BASRuntimePolicyLineage(
            bundleVersion: "test.m300.bundle.v1",
            providerRoutingRegistryVersion:
                "test.m300.routing-registry.v1",
            providerRoutingPolicyID:
                "test.m300.routing-policy.v1",
            runtimeTuningRegistryVersion:
                "test.m300.tuning-registry.v1",
            runtimeTuningPolicyID:
                "test.m300.tuning-policy.v1",
            resolutionSourceID: "test_bundle"
        )
    }

    private func makeTuning() -> BASEBrainRuntimeSynthesisPolicy {
        var tuning = BASEBrainRuntimeSynthesisPolicy.generic
            .withSchemaVersion(
                "host.runtime-synthesis.m300.v1")
        tuning.stateTransitions.runModeRules =
            tuning.stateTransitions
                .synthesizedRunModeRules(
                    wakeIntent: tuning.wakeIntent)
        return tuning
    }

    private func makeRuntime() -> BASHostRuntime {
        BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "host.m300",
                policyProfileID: "host.m300.policy",
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
        prompt: String =
            "Help me weigh several different choices.",
        title: String = "M300 tribunal coverage",
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

    // MARK: - 1. Tribunal status code lands in signalRefs

    /// A reflective turn drives the L10 tri-self tribunal so
    /// the bundle attaches via M55's `withDerivedTribunal
    /// ObservationBundle`. M300 must surface its statusCode
    /// (one of the five canonical values) in
    /// `auditEntry.signalRefs`.
    func testTribunalStatusCodeIsEmittedInSignalRefs() throws {
        let turn = try runTurn()
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)

        let tribunalStatusCodes = auditEntry.signalRefs.filter {
            $0.hasPrefix("tribunal.status:")
        }
        XCTAssertEqual(
            tribunalStatusCodes.count, 1,
            "exactly one tribunal status code per turn that " +
            "ran the tribunal seam")
        let canonicalPrefixes: [String] = [
            "full-body-converged",
            "full-body-dissent",
            "full-body-incomplete",
            "partial-",      // partial-1-voices, partial-2-voices
            "empty"
        ]
        let suffix = tribunalStatusCodes[0]
            .replacingOccurrences(
                of: "tribunal.status:", with: "")
        XCTAssertTrue(
            canonicalPrefixes.contains { suffix.hasPrefix($0) },
            "statusCode must be one of the canonical values " +
            "defined in BASTribunalCoverageReport.statusCode " +
            "(was \"\(suffix)\")")
    }

    // MARK: - 2. Voice count lands as additive metadata

    /// `tribunal.voices:N` (0..3) always appears alongside the
    /// status code so audit consumers can detect silent voices
    /// without parsing the bundle observations themselves.
    func testTribunalVoiceCountIsEmitted() throws {
        let turn = try runTurn()
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)

        let voiceCodes = auditEntry.signalRefs.filter {
            $0.hasPrefix("tribunal.voices:")
        }
        XCTAssertEqual(
            voiceCodes.count, 1,
            "exactly one voice count code per turn that ran " +
            "the tribunal seam")
        let suffix = voiceCodes[0]
            .replacingOccurrences(
                of: "tribunal.voices:", with: "")
        guard let count = Int(suffix) else {
            XCTFail(
                "tribunal.voices suffix must be parseable " +
                "as an integer (was \"\(suffix)\")")
            return
        }
        XCTAssertGreaterThanOrEqual(
            count, 0, "voice count cannot be negative")
        XCTAssertLessThanOrEqual(
            count, 3,
            "tribunal has at most 3 voices " +
            "(baseSelf / ruleSelf / aspireSelf)")
    }

    // MARK: - 3. Hash chain remains consistent — signature
    //           digests the new codes deterministically.

    /// Two identical turns must produce the same tribunal
    /// status code (deterministic for the same inputs). This
    /// pins the M300 wire as a pure derive — no random IDs in
    /// the status path.
    func testTribunalStatusIsDeterministicAcrossRuns() throws {
        let turn1 = try runTurn(
            prompt: "Identical M300 prompt.",
            title: "Identical M300 title")
        let turn2 = try runTurn(
            prompt: "Identical M300 prompt.",
            title: "Identical M300 title")
        let entry1 = try XCTUnwrap(turn1.sovereignAuditEntry)
        let entry2 = try XCTUnwrap(turn2.sovereignAuditEntry)

        let status1 = entry1.signalRefs.first {
            $0.hasPrefix("tribunal.status:")
        }
        let status2 = entry2.signalRefs.first {
            $0.hasPrefix("tribunal.status:")
        }
        XCTAssertNotNil(status1)
        XCTAssertNotNil(status2)
        XCTAssertEqual(
            status1, status2,
            "identical turns must produce the same tribunal " +
            "status code")
    }

    // MARK: - 4. M299 + M300 codes coexist on the same turn.

    /// A reflective turn populates BOTH the candidate
    /// observation bundle (M299) and the tribunal observation
    /// bundle (M300). Pin that signalRefs carries codes from
    /// both projections — they're orthogonal additive surfaces.
    func testFrontierAndTribunalCodesCoexistOnSameTurn() throws
    {
        let turn = try runTurn()
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)
        let signal = auditEntry.signalRefs

        XCTAssertTrue(
            signal.contains {
                $0.hasPrefix("frontier.status:")
            },
            "M299 frontier code must appear")
        XCTAssertTrue(
            signal.contains {
                $0.hasPrefix("tribunal.status:")
            },
            "M300 tribunal code must appear")
    }

    // MARK: - 5. Backward-compat: legacy codes still present.

    /// Pre-M300 audit entries had risk/permit/fold codes;
    /// M300 must add to the surface, not replace it.
    func testLegacyCodesStillPresentAlongsideTribunalCodes()
        throws
    {
        let turn = try runTurn()
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)
        let signal = auditEntry.signalRefs

        XCTAssertTrue(
            signal.contains(where: { $0.hasPrefix("risk:") }))
        XCTAssertTrue(
            signal.contains(where: { $0.hasPrefix("permit:") }))
        XCTAssertTrue(
            signal.contains(where: { $0.hasPrefix("fold:") }))
        XCTAssertTrue(
            signal.contains(where: {
                $0.hasPrefix("tribunal.status:")
            }))
    }
}
