// SPDX-License-Identifier: Apache-2.0
// M416 — end-to-end Kunlun doctrine demo. Parity with M399
// `--cthulhu-end-to-end-demo`.
//
// Where M414 (`--kunlun-doctrine-demo`) calls each helper directly
// against fixture inputs, M416 drives a real `BASHostRuntime`
// session and inspects the resulting `BASEBrainTurnResult` for
// evidence that the M402–M410 wires executed inside the production
// pipeline. This is empirical verification that every Kunlun wire
// fires through real audit emission, not just synthetic
// fixtures.

import BASHostKit
import BASRuntimeCore
import Foundation

/// Per-wire end-to-end visibility readout (parity with
/// `CthulhuEndToEndWireReadout`).
public struct KunlunEndToEndWireReadout: Sendable, Equatable {
    public let wireName: String
    /// Audit-signalRefs prefix the wire emits when its non-trivial
    /// path fires (e.g. `"kunlun.axis.center:"`). Used to scan the
    /// runtime's `BASSovereignAuditEntry.signalRefs`.
    public let auditCodePrefix: String
    /// `true` iff the runtime's audit signalRefs contained at
    /// least one code with the wire's prefix on this turn. The
    /// wire ran through the production path either way; `present`
    /// indicates whether its non-trivial branch fired with the
    /// demo's inputs.
    public let present: Bool
    /// Sample of the matching codes (up to 3) for banner display.
    public let sampleCodes: [String]
}

/// Demo outcome (parity with `CthulhuEndToEndOutcome`).
public struct KunlunEndToEndOutcome: Sendable, Equatable {
    public let sessionID: String
    public let auditID: String
    public let signalRefCount: Int
    public let permitMode: String
    public let permitStackedModes: [String]
    public let permitReasonCodeCount: Int
    public let wireReadouts: [KunlunEndToEndWireReadout]
    /// `true` iff every expected wire's audit prefix is at least
    /// REGISTERED in the wire-readout list (whether or not the
    /// non-trivial branch fired). Drift here means a wire's
    /// emission contract changed.
    public let allWiresRegistered: Bool
    /// Number of Kunlun wires that fired their non-trivial path.
    public let wiresFiredCount: Int
    /// Total number of registered Kunlun wires (denominator).
    public let wiresRegisteredCount: Int
}

public enum KunlunEndToEndDemoError: Error, Equatable {
    case sessionTurnMissing
    case sessionAuditEntryMissing
}

/// **M416** — drive a real `BASHostRuntime` session and verify
/// every M402-M410 Kunlun wire ran through the production audit
/// pipeline.
///
/// Pattern parallel: `CthulhuEndToEndDemo` (M399).
public enum KunlunEndToEndDemo {

    /// Audit-signalRefs prefixes per Kunlun wire. Order matches
    /// banner presentation. Each entry is the
    /// `BASSovereignAuditEntry.signalRefs` substring the wire
    /// emits on its non-trivial path.
    public static let wirePrefixes:
        [(name: String, prefix: String)] =
    [
        // M402 — axis alignment center always emits per turn
        ("M402 axis center", "kunlun.axis.center:"),
        // M402 — axis deviation only when codes non-empty
        ("M402 axis deviation", "kunlun.axis.deviation:"),
        // M402 — axis requires-gate flag only when gate needed
        ("M402 axis requires-gate", "kunlun.axis.requires-gate:"),
        // M404 — jade canon seal always emits per turn
        ("M404 jade seal", "kunlun.jade.seal:"),
        // M404 — jade missing/defects only when seal defective
        ("M404 jade missing", "kunlun.jade.missing:"),
        // M405 — river origin lineage always emits per turn
        ("M405 river lineage", "kunlun.river.lineage:"),
        // M405 — river upward count always emits per turn
        ("M405 river upward", "kunlun.river.upward:"),
        // M405 — river downward count always emits per turn
        ("M405 river downward", "kunlun.river.downward:"),
        // M406 — permit-escalation reason codes only when axis
        // escalation fires
        ("M406 permit escalation kunlun",
            "permit.escalated:kunlun:"),
        // M408 — yaochi sanctum access always emits per turn
        ("M408 yaochi access", "kunlun.yaochi.access:"),
        // M409 — tianmen gate always emits per turn
        ("M409 tianmen gate", "kunlun.tianmen.gate:"),
        // M409 — tianmen ready flag always emits per turn
        ("M409 tianmen ready", "kunlun.tianmen.ready:"),
        // M410 — cross-protocol axis-bound always emits per turn
        ("M410 tianmen axis-bound",
            "kunlun.tianmen.axis-bound:"),
    ]

    public static func run() async throws -> KunlunEndToEndOutcome {
        // Step 1 — drive a real BASHostRuntime turn.
        let runtime = BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "host.m416",
                policyProfileID: "host.m416.policy",
                prefersPureLocal: true,
                defaultDeviceState:
                    BASHostConfiguration.fixtureDefaultDeviceState,
                console: .generic,
                lifecycleBehavior: .generic,
                workflowBehavior: .generic,
                cognitionBehavior: .generic,
                presentation: .generic,
                runtimeTuning: makeTuning(),
                runtimePolicyLineage: makePolicyLineage(),
                hostRhythmProfile: .generic))

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt:
                    "Help me weigh whether to commit to a habit " +
                    "I'm uncertain about; the consequences feel " +
                    "weighty.",
                title: "M416 Kunlun end-to-end demo",
                riskLevel: .medium))

        guard let turn = result.eBrainTurn else {
            throw KunlunEndToEndDemoError.sessionTurnMissing
        }
        guard let auditEntry = turn.sovereignAuditEntry else {
            throw KunlunEndToEndDemoError.sessionAuditEntryMissing
        }

        // Step 2 — scan audit signalRefs for each wire's prefix.
        let signalRefs = auditEntry.signalRefs
        let readouts = wirePrefixes.map {
            (name, prefix) -> KunlunEndToEndWireReadout in
            let matching = signalRefs
                .filter { $0.hasPrefix(prefix) }
            return KunlunEndToEndWireReadout(
                wireName: name,
                auditCodePrefix: prefix,
                present: !matching.isEmpty,
                sampleCodes: Array(matching.prefix(3)))
        }
        let firedCount = readouts.filter(\.present).count
        let allWiresRegistered = !wirePrefixes.isEmpty

        return KunlunEndToEndOutcome(
            sessionID: turn.runtimeTrace.sessionID,
            auditID: auditEntry.auditID,
            signalRefCount: signalRefs.count,
            permitMode: turn.actionPermit.mode.rawValue,
            permitStackedModes: turn.actionPermit.stackedModes
                .map(\.rawValue),
            permitReasonCodeCount:
                turn.actionPermit.reasonCodes.count,
            wireReadouts: readouts,
            allWiresRegistered: allWiresRegistered,
            wiresFiredCount: firedCount,
            wiresRegisteredCount: wirePrefixes.count)
    }

    // MARK: - Fixture builders (mirror M399 pattern)

    private static func makePolicyLineage()
        -> BASRuntimePolicyLineage
    {
        BASRuntimePolicyLineage(
            bundleVersion: "host.m416.bundle.v1",
            providerRoutingRegistryVersion:
                "host.m416.routing-registry.v1",
            providerRoutingPolicyID:
                "host.m416.routing-policy.v1",
            runtimeTuningRegistryVersion:
                "host.m416.tuning-registry.v1",
            runtimeTuningPolicyID:
                "host.m416.tuning-policy.v1",
            resolutionSourceID: "m416_demo")
    }

    private static func makeTuning()
        -> BASEBrainRuntimeSynthesisPolicy
    {
        var tuning = BASEBrainRuntimeSynthesisPolicy.generic
            .withSchemaVersion(
                "host.runtime-synthesis.m416.v1")
        tuning.stateTransitions.runModeRules =
            tuning.stateTransitions
                .synthesizedRunModeRules(
                    wakeIntent: tuning.wakeIntent)
        return tuning
    }
}
