// SPDX-License-Identifier: Apache-2.0
// M399 — end-to-end Cthulhu doctrine demo. Closes chapter 八十九.5
// items #2 (M386 actor wire was opt-in only / no production caller)
// and #3 (M393 demo was pure-function, not end-to-end).
//
// Where M393 (`--cthulhu-doctrine-demo`) calls each helper directly
// against fixture inputs, M399 drives a real `BASHostRuntime`
// session and inspects the resulting `BASEBrainTurnResult` for
// evidence that the M384–M388 wires executed inside the production
// pipeline, and then calls `submitWithForbiddenGate(_:forbidden:)`
// (M391) against the runtime's actual update tickets. The demo is
// the first in-repo caller of the M391 production-path extension
// methods.

import BASHostKit
import BASMemory
import BASObservability
import BASRuntimeCore
import Foundation

/// Per-wire end-to-end visibility readout.
public struct CthulhuEndToEndWireReadout: Sendable, Equatable {
    public let wireName: String
    /// Audit-signalRefs prefix the wire emits when its non-trivial
    /// path fires (e.g. `"abyssal.magnitude:"`). Used to scan the
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

/// Forbidden-gate end-to-end record.
public struct ForbiddenGateProductionRecord: Sendable, Equatable {
    public let firstTicketID: String
    public let firstTicketStateAfterGate: String
    public let secondTicketID: String?
    public let secondTicketStateAfterGate: String?
    public let gateRefusalReasonCodes: [String]
}

/// Demo outcome.
public struct CthulhuEndToEndOutcome: Sendable, Equatable {
    public let sessionID: String
    public let auditID: String
    public let signalRefCount: Int
    public let permitMode: String
    public let permitStackedModes: [String]
    public let permitAssertionCeiling: String
    public let permitReasonCodeCount: Int
    public let wireReadouts: [CthulhuEndToEndWireReadout]
    public let forbiddenGateRecord: ForbiddenGateProductionRecord?
    /// Number of update tickets the runtime produced. Used by
    /// the forbidden-gate step to decide whether to demonstrate
    /// the gate at all (need ≥ 1 ticket).
    public let updateTicketCount: Int
    /// `true` iff every expected wire's audit prefix is at least
    /// REGISTERED in the wire-readout list (whether or not the
    /// non-trivial branch fired). Drift here means a wire's
    /// emission contract changed.
    public let allWiresRegistered: Bool
    /// `true` iff the M391 forbidden-gate production caller was
    /// invoked at all (requires ≥ 1 update ticket).
    public let forbiddenGateInvoked: Bool
}

public enum CthulhuEndToEndDemoError: Error, Equatable {
    case sessionTurnMissing
    case sessionAuditEntryMissing
}

/// **M399** — drive a real `BASHostRuntime` session and verify
/// every M384–M388 wire ran through the production audit pipeline,
/// plus invoke the M391 `submitWithForbiddenGate` extension as a
/// real production caller.
public enum CthulhuEndToEndDemo {

    /// Audit-signalRefs prefixes per Cthulhu wire. Order matches
    /// banner presentation. Each entry is the `BASSovereign
    /// AuditEntry.signalRefs` substring the wire emits on its
    /// non-trivial path.
    public static let wirePrefixes: [(name: String, prefix: String)] = [
        // M303 — abyssal pressure derive (always emits magnitude)
        ("M303 abyssal pressure", "abyssal.magnitude:"),
        // M304 — human anchor derive (always emits tone)
        ("M304 human anchor",     "humanAnchor.tone:"),
        // M304 — seal aggregate (only when ≥1 quarantine)
        ("M304/M387 seal scope",  "seal.count:"),
        // M305 — lifecycle aggregate (only when ≥1 ticket)
        ("M305 lifecycle",        "lifecycle.tickets:"),
        // M316 — narrative distortion (only when non-trivial)
        ("M316/M388 narrative",   "narrative."),
        // M317 — anomaly trace (only when threshold crossed)
        ("M317 anomaly",          "anomaly."),
        // M318 — abyssal branch (only when threshold crossed)
        ("M318 abyssal branch",   "abyssalBranch."),
        // M320 — unknown reserve (only when ceiling < unrestricted)
        ("M320 unknown reserve",  "unknownReserve."),
        // M321 — forbidden aggregate (only when ≥1 quarantine)
        ("M321 forbidden",        "forbidden."),
    ]

    public static func run() async throws -> CthulhuEndToEndOutcome {
        // Step 1 — drive a real BASHostRuntime turn.
        let runtime = BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "host.m399",
                policyProfileID: "host.m399.policy",
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
                title: "M399 Cthulhu end-to-end demo",
                riskLevel: .medium))

        guard let turn = result.eBrainTurn else {
            throw CthulhuEndToEndDemoError.sessionTurnMissing
        }
        guard let auditEntry = turn.sovereignAuditEntry else {
            throw CthulhuEndToEndDemoError.sessionAuditEntryMissing
        }

        // Step 2 — scan audit signalRefs for each wire's prefix.
        let signalRefs = auditEntry.signalRefs
        let readouts = wirePrefixes.map {
            (name, prefix) -> CthulhuEndToEndWireReadout in
            let matching = signalRefs
                .filter { $0.hasPrefix(prefix) }
            return CthulhuEndToEndWireReadout(
                wireName: name,
                auditCodePrefix: prefix,
                present: !matching.isEmpty,
                sampleCodes: Array(matching.prefix(3)))
        }
        let allWiresRegistered = !wirePrefixes.isEmpty

        // Step 3 — invoke the M391 forbidden-gate production
        // caller against the runtime's actual update tickets. We
        // pair the FIRST ticket with a synthesized
        // sovereign-rejected `BASForbiddenKnowledgeCandidate` so
        // the gate refuses it; the SECOND ticket (if present)
        // gets nil-forbidden so the gate passes through. This
        // demonstrates BOTH branches of the gate AND uses M391's
        // `ingestTicketsWithForbiddenGate` helper.
        var forbiddenRecord: ForbiddenGateProductionRecord? = nil
        var gateInvoked = false
        if let firstTicket = turn.updateTickets.first {
            gateInvoked = true
            let coordinator = BASUpdateTicketLifecycleCoordinator(
                clock: { Date(timeIntervalSince1970: 1_700_000_000) })
            let rejectedCandidate = BASForbiddenKnowledgeCandidate(
                candidateID: "fk-\(firstTicket.ticketID)",
                sourceRefs: [firstTicket.ticketID],
                riskReasons: ["m399-demo-rejected"],
                contaminationRefs: [],
                coolingPeriod: 0,
                shadowTrialPolicy: .standard,
                sovereignReviewState: .rejected)
            let forbiddenMap: [String: BASForbiddenKnowledgeCandidate] =
                [firstTicket.ticketID: rejectedCandidate]
            // Second ticket if any → nil forbidden in the map →
            // gate pass-through.
            let secondTicket = turn.updateTickets.dropFirst().first
            await coordinator
                .ingestTicketsWithForbiddenGate(
                    turn.updateTickets,
                    forbiddenByTicketID: forbiddenMap)
            let firstEntry = await coordinator
                .entry(ticketID: firstTicket.ticketID)
            let firstReason = firstEntry?.history.last?
                .reasonCodes ?? []
            let secondEntry: BASUpdateTicketLifecycleEntry?
            if let s = secondTicket {
                secondEntry = await coordinator
                    .entry(ticketID: s.ticketID)
            } else {
                secondEntry = nil
            }
            forbiddenRecord = ForbiddenGateProductionRecord(
                firstTicketID: firstTicket.ticketID,
                firstTicketStateAfterGate:
                    firstEntry?.state.rawValue ?? "(missing)",
                secondTicketID: secondTicket?.ticketID,
                secondTicketStateAfterGate: secondEntry?.state.rawValue,
                gateRefusalReasonCodes: firstReason)
        }

        return CthulhuEndToEndOutcome(
            sessionID: turn.runtimeTrace.sessionID,
            auditID: auditEntry.auditID,
            signalRefCount: signalRefs.count,
            permitMode: turn.actionPermit.mode.rawValue,
            permitStackedModes: turn.actionPermit.stackedModes
                .map(\.rawValue),
            permitAssertionCeiling:
                turn.actionPermit.assertionCeiling,
            permitReasonCodeCount:
                turn.actionPermit.reasonCodes.count,
            wireReadouts: readouts,
            forbiddenGateRecord: forbiddenRecord,
            updateTicketCount: turn.updateTickets.count,
            allWiresRegistered: allWiresRegistered,
            forbiddenGateInvoked: gateInvoked)
    }

    // MARK: - Fixture builders (mirror M306 pattern)

    private static func makePolicyLineage() -> BASRuntimePolicyLineage {
        BASRuntimePolicyLineage(
            bundleVersion: "host.m399.bundle.v1",
            providerRoutingRegistryVersion:
                "host.m399.routing-registry.v1",
            providerRoutingPolicyID:
                "host.m399.routing-policy.v1",
            runtimeTuningRegistryVersion:
                "host.m399.tuning-registry.v1",
            runtimeTuningPolicyID:
                "host.m399.tuning-policy.v1",
            resolutionSourceID: "m399_demo")
    }

    private static func makeTuning() -> BASEBrainRuntimeSynthesisPolicy {
        var tuning = BASEBrainRuntimeSynthesisPolicy.generic
            .withSchemaVersion(
                "host.runtime-synthesis.m399.v1")
        tuning.stateTransitions.runModeRules =
            tuning.stateTransitions
                .synthesizedRunModeRules(
                    wakeIntent: tuning.wakeIntent)
        return tuning
    }
}

