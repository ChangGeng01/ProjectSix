import XCTest
import BASHostKit
import BASRuntimeCore

/// M416 — pin the contract that the sample-host
/// `--kunlun-end-to-end-demo` mode relies on. Same pattern as
/// M399 Cthulhu e2e tests / M333/M334/M335: tests pin BAS
/// substrate contracts, not the executable's symbols which
/// aren't visible to test targets. This file exercises the SAME
/// composition the demo composes:
///
///   1. `BASHostRuntime.startSession(...)` produces a turn with
///      a non-nil `actionPermit` + `sovereignAuditEntry`.
///   2. The audit entry's `signalRefs` contain the always-on
///      Kunlun-wire prefixes (M402 axis center, M404 jade seal,
///      M405 river lineage/upward/downward, M408 yaochi access,
///      M409 tianmen gate/ready, M410 axis-bound).
///   3. ≥ 12/13 Kunlun wire prefixes from the demo's
///      `KunlunEndToEndDemo.wirePrefixes` table are present in
///      the audit emission. The single silent wire is M404
///      `kunlun.jade.missing:` — only emits when seal is
///      defective; canonical seals correctly elide it.
///   4. The bound permit's stackedModes contain `.compare` from
///      M406 escalation when the axis requires gate.
///   5. M410 cross-protocol bind code references the session ID.
///   6. The empirical claim is deterministic across runs.
final class QinaoSampleHostKunlunEndToEndDemoTests: XCTestCase {

    // MARK: - Fixture

    private func makeRuntime(profile: String)
        -> BASHostRuntime
    {
        BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "host.\(profile)",
                policyProfileID: "host.\(profile).policy",
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
                            "host.runtime-synthesis.\(profile).v1"),
                runtimePolicyLineage:
                    BASRuntimePolicyLineage(
                        bundleVersion:
                            "host.\(profile).bundle.v1",
                        providerRoutingRegistryVersion:
                            "host.\(profile).routing-registry.v1",
                        providerRoutingPolicyID:
                            "host.\(profile).routing-policy.v1",
                        runtimeTuningRegistryVersion:
                            "host.\(profile).tuning-registry.v1",
                        runtimeTuningPolicyID:
                            "host.\(profile).tuning-policy.v1",
                        resolutionSourceID: profile),
                hostRhythmProfile: .generic))
    }

    /// Drive the same session the M416 demo drives (same prompt
    /// + risk level + workflow profile). Returns the audit
    /// entry's signalRefs and the turn's bound action permit.
    private func driveDemoSession(profile: String) throws
        -> (signalRefs: [String],
            permitMode: String,
            permitStackedModes: [String],
            sessionID: String)
    {
        let runtime = makeRuntime(profile: profile)
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt:
                    "Help me weigh whether to commit to a habit " +
                    "I'm uncertain about; the consequences feel " +
                    "weighty.",
                title: "M416 e2e test",
                riskLevel: .medium))
        let turn = try XCTUnwrap(result.eBrainTurn)
        let audit = try XCTUnwrap(turn.sovereignAuditEntry)
        return (
            signalRefs: audit.signalRefs,
            permitMode: turn.actionPermit.mode.rawValue,
            permitStackedModes: turn.actionPermit.stackedModes
                .map(\.rawValue),
            sessionID: turn.runtimeTrace.sessionID)
    }

    // MARK: - 1. Demo composition smoke test

    func testDemoSessionProducesAuditEntry() throws {
        let r = try driveDemoSession(profile: "m416-smoke")
        XCTAssertGreaterThan(r.signalRefs.count, 0)
        XCTAssertFalse(r.sessionID.isEmpty)
    }

    // MARK: - 2. Always-firing Kunlun wires fire

    func testAllAlwaysFiringKunlunWiresFire() throws {
        let r = try driveDemoSession(profile: "m416-always")
        // Per the demo's wirePrefixes table — these are
        // always-emitting on a medium-risk turn (the demo's
        // canonical input).
        let alwaysFiringPrefixes: [String] = [
            "kunlun.axis.center:",
            "kunlun.axis.deviation:",
            "kunlun.axis.requires-gate:",
            "kunlun.jade.seal:",
            "kunlun.river.lineage:",
            "kunlun.river.upward:",
            "kunlun.river.downward:",
            "kunlun.yaochi.access:",
            "kunlun.tianmen.gate:",
            "kunlun.tianmen.ready:",
            "kunlun.tianmen.axis-bound:",
        ]
        for prefix in alwaysFiringPrefixes {
            let count = r.signalRefs
                .filter { $0.hasPrefix(prefix) }
                .count
            XCTAssertGreaterThanOrEqual(count, 1,
                "wire prefix '\(prefix)' must fire on demo input")
        }
    }

    // MARK: - 3. ≥ 12/13 Kunlun wires fire

    func testHighProductionPathCoverage() throws {
        let r = try driveDemoSession(profile: "m416-coverage")
        // The full 13-wire prefix list per the demo's table.
        // 12 are always-firing on the canonical input; the 1
        // silent wire is `kunlun.jade.missing:` — only emits
        // when seal is defective; canonical seals correctly
        // elide it.
        let allDemoPrefixes: [String] = [
            "kunlun.axis.center:",
            "kunlun.axis.deviation:",
            "kunlun.axis.requires-gate:",
            "kunlun.jade.seal:",
            "kunlun.jade.missing:",
            "kunlun.river.lineage:",
            "kunlun.river.upward:",
            "kunlun.river.downward:",
            "permit.escalated:kunlun:",
            "kunlun.yaochi.access:",
            "kunlun.tianmen.gate:",
            "kunlun.tianmen.ready:",
            "kunlun.tianmen.axis-bound:",
        ]
        let firedPrefixes = allDemoPrefixes.filter { prefix in
            r.signalRefs.contains { $0.hasPrefix(prefix) }
        }
        // Empirical: ≥ 12 of 13 fire on canonical input. (Only
        // `kunlun.jade.missing:` is silent for canonical seals.)
        XCTAssertGreaterThanOrEqual(firedPrefixes.count, 12,
            "≥ 12/13 demo wire prefixes must fire on canonical input")
    }

    // MARK: - 4. M406 escalation reflected in permit

    func testM406EscalationReflectedInBoundPermit() throws {
        let r = try driveDemoSession(profile: "m416-m406")
        // Medium-risk turn with synthesized overreaching axis →
        // M406 escalates `.compare` to stackedModes.
        XCTAssertTrue(
            r.permitStackedModes.contains("compare"),
            "permit.stackedModes must contain .compare from M406")
    }

    // MARK: - 5. M410 cross-protocol bind references session

    func testM410AxisBoundReferencesSessionID() throws {
        let r = try driveDemoSession(profile: "m416-m410")
        let bindCodes = r.signalRefs.filter {
            $0.hasPrefix("kunlun.tianmen.axis-bound:")
        }
        XCTAssertEqual(bindCodes.count, 1,
            "exactly 1 axis-bound code per turn")
        let code = bindCodes[0]
        XCTAssertTrue(code.contains("session-"),
            "axis-bound code must reference session: \(code)")
        XCTAssertTrue(code.contains(r.sessionID),
            "axis-bound code must contain session ID")
    }

    // MARK: - 6. Empirical claim is deterministic

    func testKunlunWireFireCountIsDeterministic() throws {
        let r1 = try driveDemoSession(profile: "m416-det-1")
        let r2 = try driveDemoSession(profile: "m416-det-2")
        // The set of fired Kunlun-prefix codes (set semantics)
        // must be identical across runs with the same canonical
        // input.
        let allDemoPrefixes: [String] = [
            "kunlun.axis.center:",
            "kunlun.axis.deviation:",
            "kunlun.axis.requires-gate:",
            "kunlun.jade.seal:",
            "kunlun.jade.missing:",
            "kunlun.river.lineage:",
            "kunlun.river.upward:",
            "kunlun.river.downward:",
            "permit.escalated:kunlun:",
            "kunlun.yaochi.access:",
            "kunlun.tianmen.gate:",
            "kunlun.tianmen.ready:",
            "kunlun.tianmen.axis-bound:",
        ]
        let fired1: Set<String> = Set(allDemoPrefixes.filter { p in
            r1.signalRefs.contains { $0.hasPrefix(p) }
        })
        let fired2: Set<String> = Set(allDemoPrefixes.filter { p in
            r2.signalRefs.contains { $0.hasPrefix(p) }
        })
        XCTAssertEqual(fired1, fired2,
            "set of fired Kunlun wires must be deterministic")
    }
}
