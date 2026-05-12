// SPDX-License-Identifier: Apache-2.0
// M446 (chapter 一百十七) — permit-escalation gating for the
// chapter 一百十四 L9 non-Euclidean candidate + L10 cosmic-cold
// counterweight schemas. Extends the M384 `BASAbyssalPermit
// Escalation` pattern with two new upstream sources, both wired
// through `permit.stackedModes` (single-commit-mouth doctrine
// preserved).
//
// ## Why this exists
//
// `BASNonEuclideanCandidate` (chapter 一百十四 L9) carries
// `failureModeWhenGrasped: BASNonEuclideanFailureMode`. When a
// candidate's failure mode is `.collapsedOnGrasp` (i.e. the
// candidate dissolves when described in single-frame natural-
// language form), the substrate MUST route the candidate through
// a compare-panel surface — the host needs to see the candidate
// as one option among several, never as the verdict in disguise.
// This translates to a permit escalation that adds `.compare` to
// `stackedModes`.
//
// `BASCosmicColdCounterweight` (chapter 一百十四 L10) carries
// 4 axes (`dignityBias`, `agencyFloor`, `antiFatalism`,
// `antiPaternalism`) ∈ `[0, 1]`. When the L10 tribunal
// observation surfaces a counterweight with any axis above
// threshold, the substrate is signaling "the verdict carries
// cosmic-cold risk — do not let the universe-is-big framing
// dilute the host's concern". The escalation adds `.mirror`
// (force a host-facing reflection step) when antiFatalism or
// antiPaternalism is high, OR `.compare` (force comparison)
// when dignityBias or agencyFloor is high.
//
// Both sources can fire simultaneously. The escalation merges
// them by **uniqueing** stackedModes — no duplicate entries.
// Reason codes record every contributing source.
//
// ## Doctrine pins
//
// - **Single commit mouth** (red line v1-#2 + v4 single-mouth):
//   never replaces `permit.mode`; only appends to `stackedModes`.
// - **Composability with M384 + M406**: this helper composes
//   safely with the abyssal pressure escalation (M384) and the
//   Kunlun permit escalation (M406). All three append to
//   `stackedModes`; final ordering is deterministic via the
//   uniqueing rule in `BASActionPermit`'s init.
// - **Red line 10 — 主品牌不默认恐怖化**: every reason code is
//   inside the audit substrate (typed `permit.escalated:cthulhu-*`
//   prefix). No public Qinao surface vocabulary changes.
// - **Cosmic-cold doctrine pin (red line 5 — 不把宇宙冷感做成
//   宿主冷处理)**: the L10 counterweight escalation explicitly
//   counters "cosmic-cold" tone — when fields are high, the
//   substrate IS WARMING UP the response surface, not freezing
//   it.
//
// ## DAG discipline
//
// Imports `Foundation` + `BASRuntimeCore` + `BASPolicy`.

import Foundation
import BASPolicy
import BASRuntimeCore

// MARK: - BASCthulhuPermitEscalationDecision

/// Pure result type carrying the (possibly-escalated) permit,
/// typed reason codes, and per-source fired flags.
public struct BASCthulhuPermitEscalationDecision:
    Codable, Sendable, Equatable
{
    /// Permit after escalation. Equal (by value) to input
    /// permit when no escalation fires.
    public let permit: BASActionPermit
    /// Stable reason codes describing the escalation. Format:
    /// `"permit.escalated:cthulhu-noneuclidean:<failureMode>"`
    /// `"permit.escalated:cthulhu-cosmic-cold:<axis>:<value>"`
    public let reasonCodes: [String]
    /// `true` when non-Euclidean source contributed.
    public let firedNonEuclidean: Bool
    /// `true` when cosmic-cold counterweight source contributed.
    public let firedCosmicCold: Bool

    public init(
        permit: BASActionPermit,
        reasonCodes: [String],
        firedNonEuclidean: Bool,
        firedCosmicCold: Bool
    ) {
        self.permit = permit
        self.reasonCodes = reasonCodes
        self.firedNonEuclidean = firedNonEuclidean
        self.firedCosmicCold = firedCosmicCold
    }
}

// MARK: - BASCthulhuPermitEscalation

public enum BASCthulhuPermitEscalation {

    // MARK: Named constants (anti-magic-number doctrine)

    /// Threshold above which a counterweight axis triggers
    /// permit escalation. 0.5 is the L10 tribunal default
    /// (per chapter 一百十四 schema field doctrine).
    public static let cosmicColdAxisThreshold: Double = 0.5

    // MARK: Decision

    /// Compute the composite escalation. Pure function.
    ///
    /// - Parameters:
    ///   - permit: the current permit issued by L11.
    ///   - nonEuclideanCandidates: zero or more L9 candidates.
    ///     Empty when no L9 dream-loop produced non-Euclidean
    ///     output.
    ///   - cosmicColdCounterweight: the L10 tribunal counter-
    ///     weight readout. May be `nil`.
    /// - Returns: composite escalation decision.
    public static func escalate(
        permit: BASActionPermit,
        nonEuclideanCandidates: [BASNonEuclideanCandidate],
        cosmicColdCounterweight: BASCosmicColdCounterweight?
    ) -> BASCthulhuPermitEscalationDecision {
        var stackedModes = permit.stackedModes
        var reasonCodes: [String] = []
        var firedNonEuclidean = false
        var firedCosmicCold = false

        // Source 1: non-Euclidean candidates → force .compare
        for candidate in nonEuclideanCandidates {
            if candidate.failureModeWhenGrasped == .collapsedOnGrasp
                || candidate.failureModeWhenGrasped == .topologyDistortion
            {
                if !stackedModes.contains(.compare) {
                    stackedModes.append(.compare)
                }
                firedNonEuclidean = true
                reasonCodes.append(
                    "permit.escalated:cthulhu-noneuclidean:" +
                    candidate.failureModeWhenGrasped.rawValue)
            }
        }

        // Source 2: cosmic-cold counterweight → force .mirror
        // and/or .compare based on which axes are high
        if let counterweight = cosmicColdCounterweight {
            // Anti-fatalism / anti-paternalism high → force
            // mirror (force a host-facing reflection step
            // before the substrate commits the response).
            if counterweight.antiFatalism > cosmicColdAxisThreshold
                || counterweight.antiPaternalism > cosmicColdAxisThreshold
            {
                if !stackedModes.contains(.mirror) {
                    stackedModes.append(.mirror)
                }
                firedCosmicCold = true
                if counterweight.antiFatalism > cosmicColdAxisThreshold {
                    reasonCodes.append(
                        "permit.escalated:cthulhu-cosmic-cold:" +
                        "antiFatalism:\(round1000(counterweight.antiFatalism))")
                }
                if counterweight.antiPaternalism > cosmicColdAxisThreshold {
                    reasonCodes.append(
                        "permit.escalated:cthulhu-cosmic-cold:" +
                        "antiPaternalism:" +
                        "\(round1000(counterweight.antiPaternalism))")
                }
            }
            // Dignity-bias / agency-floor high → force compare
            // (the L10 watcher is asking for "show the host
            // multiple paths" because the verdict surface
            // could narrow agency).
            if counterweight.dignityBias > cosmicColdAxisThreshold
                || counterweight.agencyFloor > cosmicColdAxisThreshold
            {
                if !stackedModes.contains(.compare) {
                    stackedModes.append(.compare)
                }
                firedCosmicCold = true
                if counterweight.dignityBias > cosmicColdAxisThreshold {
                    reasonCodes.append(
                        "permit.escalated:cthulhu-cosmic-cold:" +
                        "dignityBias:\(round1000(counterweight.dignityBias))")
                }
                if counterweight.agencyFloor > cosmicColdAxisThreshold {
                    reasonCodes.append(
                        "permit.escalated:cthulhu-cosmic-cold:" +
                        "agencyFloor:\(round1000(counterweight.agencyFloor))")
                }
            }
        }

        let outputPermit: BASActionPermit
        if !reasonCodes.isEmpty {
            outputPermit = permit.withStackedModes(stackedModes)
        } else {
            outputPermit = permit
        }
        return BASCthulhuPermitEscalationDecision(
            permit: outputPermit,
            reasonCodes: reasonCodes,
            firedNonEuclidean: firedNonEuclidean,
            firedCosmicCold: firedCosmicCold)
    }

    /// Round to 3 decimal places for stable reason-code
    /// formatting. Anti-magic-number: factor named.
    private static let reasonCodeRoundingFactor: Double = 1000.0

    private static func round1000(_ value: Double) -> Double {
        (value * reasonCodeRoundingFactor)
            .rounded() / reasonCodeRoundingFactor
    }
}

// MARK: - BASActionPermit narrow helper

private extension BASActionPermit {
    /// Return a copy with `stackedModes` replaced. All other
    /// fields stay byte-equal.
    func withStackedModes(_ modes: [BASActionPermitMode]) -> BASActionPermit {
        BASActionPermit(
            schemaVersion: schemaVersion,
            mode: mode,
            stackedModes: modes,
            reasonCodes: reasonCodes,
            allowedDomains: allowedDomains,
            blockedDomains: blockedDomains,
            assertionCeiling: assertionCeiling,
            toolScope: toolScope,
            memoryScope: memoryScope,
            requireMirror: requireMirror,
            requireCompare: requireCompare,
            requireSecondCheck: requireSecondCheck,
            outputLengthCap: outputLengthCap,
            tonePolicy: tonePolicy,
            templatePolicy: templatePolicy,
            delayWindow: delayWindow,
            substituteRequired: substituteRequired,
            escalationHintRef: escalationHintRef)
    }
}
