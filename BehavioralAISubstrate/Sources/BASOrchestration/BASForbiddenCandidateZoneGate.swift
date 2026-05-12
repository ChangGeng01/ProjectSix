// SPDX-License-Identifier: Apache-2.0
// M447 (chapter 一百十七) — lifecycle-gate for the chapter
// 一百十五 `BASForbiddenCandidateZone` schema. Extends the M386
// `BASForbiddenLifecycleGate` pattern with a NEW upstream
// source: when a candidate is currently isolated in a forbidden
// zone (i.e. `quarantinedCandidateRefs` contains the candidate
// ref AND the candidate has not met any `releaseConditions`),
// downstream lifecycle actions on that candidate are denied
// until L14 sovereign reveal.
//
// ## Why this exists
//
// `BASForbiddenCandidateZone` (chapter 一百十五 L13) is an
// isolation zone, NOT a retention loop — candidates inside it
// CANNOT re-enter normal selection without explicit release.
// Phase 1 verification (chapter 一百十六) confirmed the schema
// has 0 runtime callers. This helper closes that gap by
// gating any `BASEvolutionLifecycleAction` invocation on
// quarantined candidates.
//
// Decisions:
//
//  - `.startShadowTrial` / `.finalizeTrial` / `.promote` on a
//    quarantined candidate → DENIED until release condition
//    met
//  - `.retract` / `.fail` / `.withdraw` → ALLOWED (these are
//    decommissioning actions; quarantine doesn't block them)
//  - `.registerCandidate` for a NEW candidate → ALLOWED
//    (registration is the proposed→candidateRegistered
//    transition, which doesn't grant the candidate any trust;
//    quarantine kicks in only when the candidate enters trial)
//
// Release conditions (per chapter 一百十五 schema field) are
// expressed as free-form strings (e.g. `"sovereign-warrant"`,
// `"host-explicit-recall"`, `"contamination-cleared"`). The
// gate consults a caller-supplied `Set<String>` of currently-
// satisfied release conditions; ALL listed conditions must be
// satisfied to lift the gate.
//
// ## Doctrine pins
//
// - **Single commit mouth** (red line v1-#2): this gate
//   never modifies the lifecycle session itself; it only
//   returns a typed `Decision` whose consumer (the lifecycle
//   coordinator) decides whether to apply the action.
// - **No silent gate**: every gate-fire emits a stable typed
//   reason code recording which release conditions are
//   pending.
// - **Composability with M386 `BASForbiddenLifecycleGate`**:
//   M386 reads from `BASForbiddenKnowledgeCandidate`; this
//   reads from `BASForbiddenCandidateZone`. Both helpers can
//   fire on the same candidate; the lifecycle coordinator
//   should run BOTH gates and deny the action if EITHER
//   fires (logical OR for safety).
// - **Anti-magic-number** (chapter 一百十三): no inline
//   string literals; all pattern strings routed through
//   named static constants.
//
// ## DAG discipline
//
// Imports `Foundation` + `BASRuntimeCore` + `BASMemory` (for
// `BASEvolutionLifecycleAction`). Lives in `BASOrchestration`
// because `BASForbiddenCandidateZone` is defined here (chapter
// 一百十五 `BASAbyssalLayerNaming.swift`).

import Foundation
import BASMemory
import BASRuntimeCore

// MARK: - BASForbiddenCandidateZoneGateDecision

/// Pure result type carrying the gate verdict, reason codes,
/// and per-source state.
public struct BASForbiddenCandidateZoneGateDecision:
    Codable, Sendable, Equatable
{
    /// `true` when the action is denied. Caller must NOT apply
    /// the requested lifecycle action.
    public let denied: Bool
    /// Stable reason codes describing the gate fire. Format:
    /// `"lifecycle.zoneGate:denied:<action>:pending:<conditions>"`
    /// `"lifecycle.zoneGate:allowed:<action>"`
    public let reasonCodes: [String]
    /// `true` when the candidate ref WAS in the zone (regardless
    /// of whether release conditions met).
    public let wasQuarantined: Bool
    /// `true` when ALL listed release conditions were satisfied
    /// (so even a quarantined candidate is released).
    public let releaseConditionsMet: Bool

    public init(
        denied: Bool,
        reasonCodes: [String],
        wasQuarantined: Bool,
        releaseConditionsMet: Bool
    ) {
        self.denied = denied
        self.reasonCodes = reasonCodes
        self.wasQuarantined = wasQuarantined
        self.releaseConditionsMet = releaseConditionsMet
    }
}

// MARK: - BASForbiddenCandidateZoneGate

public enum BASForbiddenCandidateZoneGate {

    // MARK: Named constants (anti-magic-number doctrine)

    /// Lifecycle actions that are **gateable** by zone
    /// quarantine. Other actions (retract / fail / withdraw /
    /// registerCandidate) are always allowed because they
    /// either decommission the candidate or do not grant
    /// trust.
    public static let gateableActions: Set<BASEvolutionLifecycleAction> = [
        .startShadowTrial,
        .finalizeTrial,
        .promote,
    ]

    // MARK: Decision

    /// Decide whether `action` on `candidateRef` is allowed
    /// given the zone's quarantine state.
    ///
    /// - Parameters:
    ///   - action: the requested lifecycle action.
    ///   - candidateRef: the candidate the action targets.
    ///   - zone: the chapter 一百十五 forbidden zone snapshot.
    ///     May be `nil` when no zone exists for the session.
    ///   - satisfiedReleaseConditions: set of currently-
    ///     satisfied release condition tokens (e.g.
    ///     `["sovereign-warrant"]`). Empty set = no
    ///     conditions met.
    /// - Returns: typed gate decision.
    public static func gate(
        action: BASEvolutionLifecycleAction,
        candidateRef: String,
        zone: BASForbiddenCandidateZone?,
        satisfiedReleaseConditions: Set<String>
    ) -> BASForbiddenCandidateZoneGateDecision {
        // No zone → action allowed.
        guard let zone else {
            return BASForbiddenCandidateZoneGateDecision(
                denied: false,
                reasonCodes: [
                    "lifecycle.zoneGate:allowed:\(action.rawValue):no-zone",
                ],
                wasQuarantined: false,
                releaseConditionsMet: false)
        }

        // Candidate not quarantined → allowed.
        let trimmedRef = candidateRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard zone.quarantinedCandidateRefs.contains(trimmedRef) else {
            return BASForbiddenCandidateZoneGateDecision(
                denied: false,
                reasonCodes: [
                    "lifecycle.zoneGate:allowed:\(action.rawValue):not-quarantined",
                ],
                wasQuarantined: false,
                releaseConditionsMet: false)
        }

        // Action not gateable → allowed even when quarantined
        // (e.g. retract / fail / withdraw a quarantined
        // candidate is fine — those actions DECOMMISSION the
        // candidate, which is the right outcome).
        guard gateableActions.contains(action) else {
            return BASForbiddenCandidateZoneGateDecision(
                denied: false,
                reasonCodes: [
                    "lifecycle.zoneGate:allowed:\(action.rawValue):" +
                    "decommission-action",
                ],
                wasQuarantined: true,
                releaseConditionsMet: false)
        }

        // Candidate IS quarantined AND action IS gateable.
        // Check release conditions.
        let requiredConditions = Set(zone.releaseConditions)
        let allMet = requiredConditions.isSubset(of:
            satisfiedReleaseConditions)
        if allMet {
            return BASForbiddenCandidateZoneGateDecision(
                denied: false,
                reasonCodes: [
                    "lifecycle.zoneGate:allowed:\(action.rawValue):" +
                    "release-conditions-met",
                ],
                wasQuarantined: true,
                releaseConditionsMet: true)
        }

        // Otherwise: DENIED. List pending conditions.
        let pendingConditions = requiredConditions
            .subtracting(satisfiedReleaseConditions)
            .sorted()
        let pendingJoined = pendingConditions.joined(separator: ",")
        return BASForbiddenCandidateZoneGateDecision(
            denied: true,
            reasonCodes: [
                "lifecycle.zoneGate:denied:\(action.rawValue):pending:" +
                pendingJoined,
            ],
            wasQuarantined: true,
            releaseConditionsMet: false)
    }
}
