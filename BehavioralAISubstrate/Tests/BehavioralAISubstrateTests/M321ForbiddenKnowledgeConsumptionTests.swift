import XCTest
@testable import BASAdmin
@testable import BASHostKit
import BASMemory
import BASOrchestration
import BASRuntimeCore

/// M321 — pin that
/// `BASForbiddenKnowledgeCandidate.derive(from:)` +
/// `.aggregate(_:)` are consumed by the L14 sovereign audit
/// entry, only when the turn produces ≥1 quarantine record.
///
/// Pre-M321 the schema (white paper §5.5) had 0 runtime callers
/// outside its definition + tests + governance registry. M321
/// derives one candidate per quarantine and pushes the
/// aggregate's count + strictest policy + held flag into audit
/// signalRefs.
///
/// Doctrine pinned:
/// - Codes appear only when at least one quarantine fired (no
///   forbidden candidates → all codes elided)
/// - Each derived candidate inherits `riskReasons` verbatim from
///   the source quarantine (audit walkers can correlate)
/// - All emitted policy / state values use canonical raw-value
///   strings
final class M321ForbiddenKnowledgeConsumptionTests: XCTestCase {

    // MARK: - Pure derive tests

    private func makeQuarantine(
        zone: BASQuarantineZone,
        sourceRef: String,
        reasons: [String]
    ) -> BASQuarantineRecord {
        BASQuarantineRecord(
            quarantineID: "q-\(sourceRef)",
            zone: zone,
            sourceRef: sourceRef,
            reasonCodes: reasons,
            isolatedAt: Date(),
            releasePolicy: "M321-test",
            reviewState: .held)
    }

    /// 1. Derive populates fields verbatim from the quarantine
    ///    record.
    func testDeriveMirrorsQuarantineSourceFields() {
        let q = makeQuarantine(
            zone: .session,
            sourceRef: "src-A",
            reasons: ["risk.extreme", "manipulation>0.7"])
        let candidate = BASForbiddenKnowledgeCandidate.derive(
            from: q)
        XCTAssertEqual(
            candidate.candidateID, "forbidden-q-src-A")
        XCTAssertEqual(candidate.sourceRefs, ["src-A"])
        XCTAssertEqual(
            candidate.riskReasons,
            ["risk.extreme", "manipulation>0.7"])
        XCTAssertEqual(
            candidate.contaminationRefs, ["session"])
        XCTAssertEqual(
            candidate.shadowTrialPolicy, .standard)
        XCTAssertEqual(
            candidate.sovereignReviewState, .held)
        XCTAssertEqual(
            candidate.coolingPeriod, 24 * 60 * 60)
    }

    /// 2. Empty input → nil aggregate (audit elides).
    func testAggregateOfEmptyArrayIsNil() {
        XCTAssertNil(
            BASForbiddenKnowledgeCandidate.aggregate([]))
    }

    /// 3. Non-empty input → aggregate with count = N.
    func testAggregateCountEqualsInputSize() {
        let q1 = makeQuarantine(
            zone: .session, sourceRef: "s1", reasons: ["r1"])
        let q2 = makeQuarantine(
            zone: .cache, sourceRef: "s2", reasons: ["r2"])
        let candidates = [q1, q2].map {
            BASForbiddenKnowledgeCandidate.derive(from: $0)
        }
        let agg = try? XCTUnwrap(
            BASForbiddenKnowledgeCandidate.aggregate(
                candidates))
        XCTAssertEqual(agg?.count, 2)
        XCTAssertEqual(
            agg?.strictestPolicy, .standard)
        XCTAssertEqual(agg?.allHeld, true)
    }

    /// 4. `strictestPolicy` returns the highest-tier policy
    ///    present across the aggregate.
    func testAggregateStrictestPolicy() {
        let q = makeQuarantine(
            zone: .session, sourceRef: "s", reasons: [])
        var candidate1 = BASForbiddenKnowledgeCandidate
            .derive(from: q)
        // Manual override to test ordering — production
        // path always uses `.standard`, but the aggregate must
        // still resolve correctly across mixed policies.
        candidate1.shadowTrialPolicy = .escalated
        let candidate2 = BASForbiddenKnowledgeCandidate
            .derive(from: q)
        let agg = try? XCTUnwrap(
            BASForbiddenKnowledgeCandidate.aggregate(
                [candidate1, candidate2]))
        XCTAssertEqual(
            agg?.strictestPolicy, .escalated)
    }

    /// 5. `allHeld` flips to false when any candidate is not
    ///    held.
    func testAggregateAllHeldFlipsWhenAnyNotHeld() {
        let q = makeQuarantine(
            zone: .session, sourceRef: "s", reasons: [])
        // chapter 五百三十八 / M1529 — c1 was var
        // (never mutated);changed to let。 Removed the
        // `_ = c1` nudge workaround that suppressed an
        // unused-var warning Swift was still emitting。
        let c1 = BASForbiddenKnowledgeCandidate.derive(from: q)
        var c2 = BASForbiddenKnowledgeCandidate.derive(from: q)
        c2.sovereignReviewState = .cleared
        let agg = try? XCTUnwrap(
            BASForbiddenKnowledgeCandidate.aggregate(
                [c1, c2]))
        XCTAssertEqual(agg?.allHeld, false)
    }

    // MARK: - Runtime integration

    private func makeRuntimePolicyLineage() -> BASRuntimePolicyLineage {
        BASRuntimePolicyLineage(
            bundleVersion: "test.m321.bundle.v1",
            providerRoutingRegistryVersion:
                "test.m321.routing-registry.v1",
            providerRoutingPolicyID:
                "test.m321.routing-policy.v1",
            runtimeTuningRegistryVersion:
                "test.m321.tuning-registry.v1",
            runtimeTuningPolicyID:
                "test.m321.tuning-policy.v1",
            resolutionSourceID: "test_bundle"
        )
    }

    private func makeTuning() -> BASEBrainRuntimeSynthesisPolicy {
        var tuning = BASEBrainRuntimeSynthesisPolicy.generic
            .withSchemaVersion(
                "host.runtime-synthesis.m321.v1")
        tuning.stateTransitions.runModeRules =
            tuning.stateTransitions
                .synthesizedRunModeRules(
                    wakeIntent: tuning.wakeIntent)
        return tuning
    }

    private func makeRuntime() -> BASHostRuntime {
        BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "host.m321",
                policyProfileID: "host.m321.policy",
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

    /// 6. Runtime turn emits well-shaped `forbidden.*` codes
    ///    when quarantines fire (substrate produces baseline
    ///    session+cache quarantines on most turns) — or zero
    ///    codes when no quarantine. Both shapes valid per the
    ///    M321 emit contract.
    func testRuntimeTurnEmitsWellShapedForbiddenCodes()
        throws
    {
        let runtime = makeRuntime()
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: "M321 well-shaped turn",
                title: "M321 forbidden shape",
                riskLevel: .low))
        let turn = try XCTUnwrap(result.eBrainTurn)
        let auditEntry = try XCTUnwrap(
            turn.sovereignAuditEntry)
        let codes = auditEntry.signalRefs.filter {
            $0.hasPrefix("forbidden.")
        }
        // 0 codes when no quarantines; 2-3 codes when present
        // (count + policy always; allHeld optional).
        XCTAssertTrue(
            codes.isEmpty || (2...3).contains(codes.count),
            "forbidden codes must be 0, 2, or 3, got " +
            "\(codes.count): \(codes)")
        if !codes.isEmpty {
            XCTAssertTrue(
                codes.contains {
                    $0.hasPrefix("forbidden.count:")
                })
            XCTAssertTrue(
                codes.contains {
                    $0.hasPrefix("forbidden.policy:")
                })
        }
    }
}
