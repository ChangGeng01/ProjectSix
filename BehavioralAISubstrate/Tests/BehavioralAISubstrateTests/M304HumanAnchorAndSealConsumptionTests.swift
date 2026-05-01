import XCTest
@testable import BASAdmin
@testable import BASHostKit
import BASMemory
import BASOrchestration
import BASPolicy
import BASRuntimeCore

/// M304 — pin that `BASHumanAnchorProtocol.derive(...)` and
/// `BASOldSealSealingProtocol.aggregate(...)` (M287 Cthulhu
/// schemas, schema-only since 2026-04-30) are consumed by the
/// L14 sovereign audit entry on every turn.
///
/// Pre-M304 these helpers existed but had zero runtime callers
/// outside their own unit tests. After M304:
///
///   - `runTurn` derives a `BASHumanAnchorSignal` from final
///     risk + permit + candidate state and emits
///     `humanAnchor.tone:<tone>` + `humanAnchor.maxRisk:<3-decimal>`
///     into audit `signalRefs`.
///   - `runTurn` synthesizes one `BASSealEnvelope` per
///     quarantine record (sovereign-only access policy),
///     aggregates them, and emits `seal.count:<N>` +
///     `seal.strictest:<policy>` only when the aggregate is
///     non-nil (no quarantines → both codes elided).
///
/// Doctrine red line 7 ("watcher hint, never verdict") is
/// upheld — both codes are advisory metadata; verdict level
/// not escalated; hash chain remains deterministic (signature
/// digests a longer ordered signalRefs list).
final class M304HumanAnchorAndSealConsumptionTests: XCTestCase {

    // MARK: - Configuration helpers

    private func makeRuntimePolicyLineage() -> BASRuntimePolicyLineage {
        BASRuntimePolicyLineage(
            bundleVersion: "test.m304.bundle.v1",
            providerRoutingRegistryVersion:
                "test.m304.routing-registry.v1",
            providerRoutingPolicyID:
                "test.m304.routing-policy.v1",
            runtimeTuningRegistryVersion:
                "test.m304.tuning-registry.v1",
            runtimeTuningPolicyID:
                "test.m304.tuning-policy.v1",
            resolutionSourceID: "test_bundle"
        )
    }

    private func makeTuning() -> BASEBrainRuntimeSynthesisPolicy {
        var tuning = BASEBrainRuntimeSynthesisPolicy.generic
            .withSchemaVersion(
                "host.runtime-synthesis.m304.v1")
        tuning.stateTransitions.runModeRules =
            tuning.stateTransitions
                .synthesizedRunModeRules(
                    wakeIntent: tuning.wakeIntent)
        return tuning
    }

    private func makeRuntime() -> BASHostRuntime {
        BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "host.m304",
                policyProfileID: "host.m304.policy",
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
            "Help me weigh whether this is a safe step.",
        title: String = "M304 human anchor",
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

    // MARK: - 1. humanAnchor.tone always emitted

    /// Every turn emits one tone code drawn from the four
    /// canonical tones (plain / warm / steady / reserved).
    func testHumanAnchorToneAlwaysAppearsInSignalRefs() throws {
        let turn = try runTurn()
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)

        let toneCodes = auditEntry.signalRefs.filter {
            $0.hasPrefix("humanAnchor.tone:")
        }
        XCTAssertEqual(toneCodes.count, 1)
        let suffix = toneCodes[0]
            .replacingOccurrences(
                of: "humanAnchor.tone:", with: "")
        let canonical = Set(
            BASHumanAnchorTone.allCases.map(\.rawValue))
        XCTAssertTrue(
            canonical.contains(suffix),
            "humanAnchor tone must be one of the four " +
            "canonical tones (was \"\(suffix)\")")
    }

    // MARK: - 2. humanAnchor.maxRisk parses + bounded

    /// `humanAnchor.maxRisk` is the max of 4 dimensions, each
    /// clamped to [0, 1]. Pin format + range.
    func testHumanAnchorMaxRiskParsesAndIsBounded() throws {
        let turn = try runTurn()
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)

        let riskCodes = auditEntry.signalRefs.filter {
            $0.hasPrefix("humanAnchor.maxRisk:")
        }
        XCTAssertEqual(riskCodes.count, 1)
        let suffix = riskCodes[0]
            .replacingOccurrences(
                of: "humanAnchor.maxRisk:", with: "")
        guard let value = Double(suffix) else {
            XCTFail(
                "humanAnchor.maxRisk must parse as Double " +
                "(was \"\(suffix)\")")
            return
        }
        XCTAssertGreaterThanOrEqual(value, 0)
        XCTAssertLessThanOrEqual(value, 1)
    }

    // MARK: - 3. derive() unit test — block permit elevates
    //           agencyRisk

    /// Block-mode permit → agencyRisk ≥ 0.5. Non-block → < 0.5.
    func testBlockPermitElevatesAgencyRisk() {
        let blockSignal = BASHumanAnchorProtocol.derive(
            anchorID: "u-1",
            hostSummaryRef: "host-test",
            riskLevel: .medium,
            permitMode: .block,
            candidateCount: 2)
        XCTAssertGreaterThanOrEqual(
            blockSignal.agencyRisk, 0.5)

        let answerSignal = BASHumanAnchorProtocol.derive(
            anchorID: "u-2",
            hostSummaryRef: "host-test",
            riskLevel: .medium,
            permitMode: .answer,
            candidateCount: 2)
        XCTAssertLessThan(answerSignal.agencyRisk, 0.5)
    }

    // MARK: - 4. derive() unit test — overwhelm scales with
    //           candidates

    /// 0 candidates → 0; 6+ candidates → 1.0; midpoint linear.
    func testOverwhelmRiskScalesWithCandidateCount() {
        let zero = BASHumanAnchorProtocol.derive(
            anchorID: "z",
            hostSummaryRef: "host",
            riskLevel: .medium,
            permitMode: .answer,
            candidateCount: 0)
        XCTAssertEqual(zero.overwhelmRisk, 0, accuracy: 0.0001)

        let saturated = BASHumanAnchorProtocol.derive(
            anchorID: "s",
            hostSummaryRef: "host",
            riskLevel: .medium,
            permitMode: .answer,
            candidateCount: 6)
        XCTAssertEqual(
            saturated.overwhelmRisk, 1.0, accuracy: 0.0001)

        let overshoot = BASHumanAnchorProtocol.derive(
            anchorID: "o",
            hostSummaryRef: "host",
            riskLevel: .medium,
            permitMode: .answer,
            candidateCount: 12)
        XCTAssertEqual(
            overshoot.overwhelmRisk, 1.0, accuracy: 0.0001,
            "overwhelm clamps at 1.0 (BASHumanAnchorSignal " +
            "init clamp)")
    }

    // MARK: - 5. Seal aggregate — empty → nil

    /// Empty seal collection returns nil so the audit entry can
    /// elide both seal.* codes.
    func testEmptySealCollectionAggregateIsNil() {
        let aggregate = BASOldSealSealingProtocol.aggregate([])
        XCTAssertNil(aggregate)
    }

    // MARK: - 6. Seal aggregate — strictness ordering

    /// Forbidden ≻ sovereignOnly ≻ hostExplicit ≻ auditedAccess
    /// ≻ passive. Aggregate must pick the strictest level.
    func testSealAggregatePicksStrictestPolicy() {
        let mixed: [BASSealEnvelope] = [
            BASSealEnvelope(
                sealID: "s1", targetRefs: ["t1"],
                sealReason: "r1",
                accessPolicy: .auditedAccess,
                revealConditions: [], lineageCutRefs: [],
                auditRef: "audit-s1"),
            BASSealEnvelope(
                sealID: "s2", targetRefs: ["t2"],
                sealReason: "r2",
                accessPolicy: .forbidden,
                revealConditions: [], lineageCutRefs: [],
                auditRef: "audit-s2"),
            BASSealEnvelope(
                sealID: "s3", targetRefs: ["t3"],
                sealReason: "r3",
                accessPolicy: .passive,
                revealConditions: [], lineageCutRefs: [],
                auditRef: "audit-s3")
        ]
        let aggregate = BASOldSealSealingProtocol.aggregate(mixed)
        XCTAssertEqual(aggregate?.count, 3)
        XCTAssertEqual(aggregate?.strictestPolicy, .forbidden)
    }

    // MARK: - 7. Backward-compat: M298-M303 codes still coexist
    //           with M304 codes.

    /// Pin that all the M-series codes appear together.
    func testAllMSeriesCodesCoexistOnSingleTurn() throws {
        let turn = try runTurn()
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)
        let signal = auditEntry.signalRefs

        XCTAssertTrue(signal.contains {
            $0.hasPrefix("frontier.status:")
        }, "M299 frontier code missing")
        XCTAssertTrue(signal.contains {
            $0.hasPrefix("tribunal.status:")
        }, "M300 tribunal code missing")
        XCTAssertTrue(signal.contains {
            $0.hasPrefix("abyssal.magnitude:")
        }, "M303 abyssal code missing")
        XCTAssertTrue(signal.contains {
            $0.hasPrefix("humanAnchor.tone:")
        }, "M304 humanAnchor tone code missing")
        XCTAssertTrue(signal.contains {
            $0.hasPrefix("humanAnchor.maxRisk:")
        }, "M304 humanAnchor maxRisk code missing")
    }

    // MARK: - 8. derive() determinism

    func testHumanAnchorDeriveDeterminism() {
        let s1 = BASHumanAnchorProtocol.derive(
            anchorID: "anchor-1",
            hostSummaryRef: "host-1",
            riskLevel: .medium,
            permitMode: .answer,
            candidateCount: 3)
        let s2 = BASHumanAnchorProtocol.derive(
            anchorID: "anchor-1",
            hostSummaryRef: "host-1",
            riskLevel: .medium,
            permitMode: .answer,
            candidateCount: 3)
        XCTAssertEqual(s1, s2)
    }
}
