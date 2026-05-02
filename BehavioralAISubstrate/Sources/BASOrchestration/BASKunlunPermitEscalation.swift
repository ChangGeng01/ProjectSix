// SPDX-License-Identifier: Apache-2.0
// M406 — `BASAxisAlignment.requiresGate` → `BASActionPermit.stackedModes`
// escalation. Closes Plan §L.4.3 second runtime-decision wire for the
// Kunlun doctrine: the axis-alignment schema (M402) is now read by
// the permit synthesis seam and translates into stable, typed
// permit-mode escalations rather than living only in audit metadata.
//
// Doctrine pins:
//
//   - **Single commit mouth (red line v1-#2 + v4 single-mouth)**:
//     this helper never replaces `permit.mode` (which the L11 wind
//     gate has already issued); it only appends to `stackedModes`.
//     The primary commit mouth stays at L11.
//   - **Red line 8 — 不绕人性锚点 (cross-doctrine, originally Cthulhu
//     red line 8 — applies symmetrically here)**: when the paired
//     `BASHumanAnchorSignal.recommendedSurfaceTone == .reserved`, the
//     escalation is *intentionally suppressed* and stable reason
//     codes are emitted. The host-anchor signal wins; axis deviation
//     does not narrow agency on its own.
//   - **Red line 5 (Kunlun §13.7 #5) — 天门不绕过宿主授权**: this
//     escalation issues a `.compare` stack mode for review, never
//     bypasses host authorization; it asks the host to re-look, not
//     to defer.
//   - **Composability with M384**: when both Kunlun axis-deviation
//     AND Cthulhu pressure fire on the same turn, both escalations
//     accumulate on `stackedModes` and `reasonCodes`. Mode (single
//     commit mouth) stays at L11.
//
// Threshold: escalation fires when `alignment.requiresGate == true`
// (per `BASKunlunAxisProtocol.computeAlignment` semantics —
// `centerScore < axis.deviationThreshold` OR any deviation code).

import Foundation
import BASPolicy

// MARK: - BASKunlunPermitEscalationDecision

/// Pure result type carrying the escalated permit, the typed reason
/// codes that motivated the escalation, and the human-anchor lock
/// state. Returned as a value so downstream callers (audit emitter,
/// observability) can introspect the decision without re-computing.
public struct BASKunlunPermitEscalationDecision:
    Sendable, Equatable
{
    /// The permit after escalation. Equal to the input permit (by
    /// value) when no escalation fires.
    public let permit: BASActionPermit
    /// Stable reason codes describing the escalation. Empty when no
    /// escalation fires. Each code is in the form
    /// `"permit.escalated:kunlun:<reason>"` or
    /// `"permit.escalation-skipped:kunlun-axis-anchor-reserved"`.
    public let reasonCodes: [String]
    /// `true` when escalation was suppressed by red line 8
    /// (human-anchor tone == .reserved).
    public let suppressedByHumanAnchor: Bool
    /// `true` when the alignment required a gate (i.e. escalation
    /// path was entered, even if then suppressed).
    public let triggered: Bool

    public init(
        permit: BASActionPermit,
        reasonCodes: [String],
        suppressedByHumanAnchor: Bool,
        triggered: Bool
    ) {
        self.permit = permit
        self.reasonCodes = reasonCodes
        self.suppressedByHumanAnchor = suppressedByHumanAnchor
        self.triggered = triggered
    }
}

// MARK: - BASKunlunPermitEscalation

/// Pure-function helper translating an axis-alignment readout +
/// optional human-anchor signal into a permit escalation.
///
/// All methods are `static` and free of side effects. The helper has
/// no actor state, no I/O, and no upstream substrate-runtime
/// dependency; it composes only `BASActionPermit` (BASPolicy) and
/// the schema types defined in `BASKunlunProtocol.swift`.
public enum BASKunlunPermitEscalation {

    /// Center-score floor below which a *second* stack mode
    /// (`.escalate`) is appended in addition to `.compare`. A
    /// severely-off-axis turn signals to L14 that the host should
    /// review before the surface lands.
    public static let deepDeviationCeiling: Double = 0.3

    /// Decide a permit escalation for one (alignment, human-anchor)
    /// pair. Pure function.
    ///
    /// - Parameters:
    ///   - permit: the current permit issued by L11 (the wind gate),
    ///     possibly already escalated by M384 abyssal-pressure or
    ///     capped by M385 assertion-ceiling. The escalation never
    ///     replaces `permit.mode`; it only appends to
    ///     `stackedModes` and `reasonCodes`.
    ///   - alignment: the M402 axis-alignment readout. May be `nil`
    ///     when the run had no L4 axis derive (early warm-up).
    ///   - humanAnchor: the M304 human-anchor signal. Used solely to
    ///     enforce red line 8 — when `.reserved`, escalation is
    ///     suppressed.
    /// - Returns: a value-typed decision. `decision.permit` is the
    ///   escalated permit (or the input permit unchanged when no
    ///   escalation fires).
    public static func escalate(
        permit: BASActionPermit,
        alignment: BASAxisAlignment?,
        humanAnchor: BASHumanAnchorSignal? = nil
    ) -> BASKunlunPermitEscalationDecision {
        // No alignment → no escalation. Return permit unchanged.
        guard let alignment else {
            return BASKunlunPermitEscalationDecision(
                permit: permit,
                reasonCodes: [],
                suppressedByHumanAnchor: false,
                triggered: false)
        }

        // Centered turn → no escalation.
        guard alignment.requiresGate else {
            return BASKunlunPermitEscalationDecision(
                permit: permit,
                reasonCodes: [],
                suppressedByHumanAnchor: false,
                triggered: false)
        }

        // Red line 8: human-anchor reserved tone suppresses the
        // escalation. The host needs distance; layering more permit
        // modes would feel like thrashing, even though the axis
        // formally requires a gate.
        if humanAnchor?.recommendedSurfaceTone == .reserved {
            var skippedCodes = [
                "permit.escalation-skipped:kunlun-axis-anchor-reserved",
            ]
            for code in alignment.deviationCodes {
                skippedCodes.append(
                    "permit.escalation-suppressed:kunlun:\(code)")
            }
            return BASKunlunPermitEscalationDecision(
                permit: permit,
                reasonCodes: skippedCodes,
                suppressedByHumanAnchor: true,
                triggered: true)
        }

        // Compute the escalated stackedModes (additive — never
        // remove existing entries) and reasonCodes (additive — never
        // overwrite existing codes).
        var stackedModes = permit.stackedModes
        var seen = Set<BASActionPermitMode>(stackedModes)
        seen.insert(permit.mode)
        var addedCodes: [String] = [
            "permit.escalated:kunlun:requires-gate",
        ]

        // Standard escalation: append `.compare` so the surface
        // shows a side-by-side review. Doctrine: 中轴偏离时 host
        // 必须再看一眼 (axis deviation surfaces a comparison).
        if !seen.contains(.compare) {
            stackedModes.append(.compare)
            seen.insert(.compare)
            addedCodes.append("permit.escalated:kunlun:compare")
        }

        // Stable per-deviation trace. Sort to keep output
        // deterministic across runs (reasonCodes ordering matters
        // for cross-build digests).
        for code in alignment.deviationCodes.sorted() {
            addedCodes.append(
                "permit.escalated:kunlun:deviation:\(code)")
        }

        // Deep-deviation ladder: when centerScore is severely off,
        // append `.escalate` so L14 sovereign warrant path is
        // signaled. Doctrine: 严重偏离时升 L14 — single commit
        // mouth still preserved, just one more stack mode.
        if alignment.centerScore < deepDeviationCeiling
            && !seen.contains(.escalate)
        {
            stackedModes.append(.escalate)
            seen.insert(.escalate)
            addedCodes.append(
                "permit.escalated:kunlun:escalate-deep-deviation")
        }

        let escalatedPermit = BASActionPermit(
            schemaVersion: permit.schemaVersion,
            mode: permit.mode,
            stackedModes: stackedModes,
            reasonCodes: permit.reasonCodes + addedCodes,
            allowedDomains: permit.allowedDomains,
            blockedDomains: permit.blockedDomains,
            assertionCeiling: permit.assertionCeiling,
            toolScope: permit.toolScope,
            memoryScope: permit.memoryScope,
            requireMirror: permit.requireMirror,
            requireCompare: permit.requireCompare,
            requireSecondCheck: permit.requireSecondCheck,
            outputLengthCap: permit.outputLengthCap,
            tonePolicy: permit.tonePolicy,
            templatePolicy: permit.templatePolicy,
            delayWindow: permit.delayWindow,
            substituteRequired: permit.substituteRequired,
            escalationHintRef: permit.escalationHintRef)

        return BASKunlunPermitEscalationDecision(
            permit: escalatedPermit,
            reasonCodes: addedCodes,
            suppressedByHumanAnchor: false,
            triggered: true)
    }
}
