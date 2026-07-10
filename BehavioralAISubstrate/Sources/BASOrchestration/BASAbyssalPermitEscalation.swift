// SPDX-License-Identifier: Apache-2.0
// M384 — `BASAbyssalPressure.recommendedModes` → `BASActionPermit.stackedModes`
// escalation. Closes附录 K.2.1 first runtime-decision wire for the
// Cthulhu doctrine: the abyssal pressure schema (M303) is now read by
// the permit synthesis seam and translates into stable, typed
// permit-mode escalations rather than living only in audit metadata.
//
// Doctrine pins:
//
//   - **Single commit mouth (red line v1-#2 + v4 single-mouth)**:
//     this helper never replaces `permit.mode` (which the L11 wind
//     gate has already issued); it only appends to `stackedModes`.
//     The primary commit mouth stays at L11.
//   - **Red line 8 — 深渊压强不绕过人性锚点**: when the paired
//     `BASHumanAnchorSignal.recommendedSurfaceTone == .reserved`, the
//     escalation is *intentionally suppressed* and a stable reason
//     code `permit.escalation-skipped:human-anchor-reserved` is
//     emitted. The host-anchor signal wins; pressure does not narrow
//     agency on its own.
//   - **Red line 10 — 主品牌不默认恐怖化**: this helper emits typed
//     reason codes inside the audit substrate. No public Qinao
//     surface vocabulary changes; no UI changes. The
//     `check_sovereign_redaction.sh` allowlist is consulted in the
//     accompanying tests to ensure we never leak forbidden tokens.
//
// Threshold (audit blindspot-② HIGH — corrected): pressure escalation fires
// when the producer recommended at least one mode (`pressure.recommendedModes`
// is non-empty), i.e. some dimension crossed its per-dimension threshold. The
// old gate used the MEAN (`aggregateMagnitude >= triggerFloor`), which the
// sole live producer could never cross (it pins 3 of 6 dims to 0 ⇒ max mean
// 0.5 < 0.6), so the escalation was loaded but never fired. Gating on the
// recommendation set is consistent with what the escalation actually applies.

import Foundation
import BASPolicy

// MARK: - BASAbyssalPermitEscalationDecision

/// Pure result type carrying the escalated permit, the typed reason
/// codes that motivated the escalation, and the human-anchor lock
/// state. Returned as a value so downstream callers (audit emitter,
/// observability) can introspect the decision without re-computing.
public struct BASAbyssalPermitEscalationDecision:
    Codable, Sendable, Equatable
{
    /// The permit after escalation. Equal to the input permit (by
    /// value) when no escalation fires.
    public let permit: BASActionPermit
    /// Stable reason codes describing the escalation. Empty when no
    /// escalation fires. Each code is in the form
    /// `"permit.escalated:abyssal:<mode>"` or
    /// `"permit.escalation-skipped:<reason>"`.
    public let reasonCodes: [String]
    /// `true` when escalation was suppressed by red line 8
    /// (human-anchor tone == .reserved).
    public let suppressedByHumanAnchor: Bool
    /// `true` when the escalation fired (the producer recommended >=1 mode).
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

// MARK: - BASAbyssalPermitEscalation

/// Pure-function helper translating an abyssal-pressure reading +
/// optional human-anchor signal into a permit escalation.
///
/// All methods are `static` and free of side effects. The helper has
/// no actor state, no I/O, and no upstream substrate-runtime
/// dependency; it composes only `BASActionPermit` (BASPolicy) and the
/// schema types defined in `BASAbyssalProtocol.swift`.
public enum BASAbyssalPermitEscalation {

    /// Default trigger floor on `BASAbyssalPressure.aggregateMagnitude`.
    /// Below this, recommendedModes do not become permit escalations
    /// (they remain in the audit metadata only).
    public static let defaultTriggerFloor: Double = 0.6

    /// Pure, total translation table from `BASAbyssalPressureMode`
    /// to a `BASActionPermitMode`. Returns `nil` for modes whose
    /// semantics do not have a single-mode permit equivalent — those
    /// modes still surface as reason codes via `escalate(...)` so
    /// downstream consumers see the recommendation, but the permit
    /// `stackedModes` array is not polluted with imprecise mappings.
    ///
    /// Mapping rationale (white paper §5.1 + `EBrainRiskPlaneCore`
    /// permit-mode semantics):
    ///
    ///  - `.compare` → `.compare` (1:1)
    ///  - `.delay` → `.delay` (1:1)
    ///  - `.sovereignEscalate` → `.escalate` (semantic match —
    ///    elevate to L14 review)
    ///  - `.localDraft` → `.localOnly` (host-local only render)
    ///  - `.guardianBranch` → `nil` (guardian is a flow primitive,
    ///    not a permit-mode; emitted as reason code only)
    ///  - `.humanAnchorCheck` → `nil` (anchor check is a protocol
    ///    invocation, not a permit-mode; emitted as reason code)
    public static func translate(
        _ mode: BASAbyssalPressureMode
    ) -> BASActionPermitMode? {
        switch mode {
        case .compare:
            return .compare
        case .delay:
            return .delay
        case .sovereignEscalate:
            return .escalate
        case .localDraft:
            return .localOnly
        case .guardianBranch:
            return nil
        case .humanAnchorCheck:
            return nil
        }
    }

    /// Decide a permit escalation for one (pressure, human-anchor)
    /// pair. Pure function.
    ///
    /// - Parameters:
    ///   - permit: the current permit issued by L11 (the wind gate).
    ///     The escalation never replaces `permit.mode`; it only
    ///     appends to `stackedModes` and `reasonCodes`.
    ///   - pressure: the M303 abyssal-pressure reading. May be `nil`
    ///     when the run had no L4-L11 pressure path.
    ///   - humanAnchor: the M304 human-anchor signal. Used solely to
    ///     enforce red line 8 — when `.reserved`, escalation is
    ///     suppressed.
    ///   - triggerFloor: aggregate-magnitude threshold (default
    ///     0.6).
    /// - Returns: a value-typed decision. `decision.permit` is the
    ///   escalated permit (or the input permit unchanged when no
    ///   escalation fires).
    public static func escalate(
        permit: BASActionPermit,
        pressure: BASAbyssalPressure?,
        humanAnchor: BASHumanAnchorSignal?,
        triggerFloor: Double = BASAbyssalPermitEscalation.defaultTriggerFloor
    ) -> BASAbyssalPermitEscalationDecision {
        // No pressure → no escalation. Return permit unchanged.
        guard let pressure else {
            return BASAbyssalPermitEscalationDecision(
                permit: permit,
                reasonCodes: [],
                suppressedByHumanAnchor: false,
                triggered: false)
        }

        // audit blindspot-② HIGH: trigger iff the producer recommended at least one mode to apply —
        // the SAME `pressure.recommendedModes` the application below iterates. The old gate was
        // `aggregateMagnitude >= triggerFloor` (a MEAN of 6 dims), but the sole live producer
        // (BASAbyssalPressureBudget.derive) hardcodes 3 of the 6 dims to 0, so the max attainable mean
        // is (1+1+1)/6 = 0.5 < 0.6 → this escalation was LOADED BUT NEVER FIRED (the per-dimension
        // recommendedModes were computed and then silently discarded by the mean gate), and a single
        // maxed axis was structurally suppressed by averaging. Gating on the recommendation set makes
        // the gate consistent with the application, un-deadlocks the live wire, and is toward-caution
        // (a safety escalation that can never escalate is the dangerous state). `triggerFloor` is
        // retained for API/signature stability; the mean threshold it drove proved unreachable.
        let triggered = !pressure.recommendedModes.isEmpty
        guard triggered else {
            return BASAbyssalPermitEscalationDecision(
                permit: permit,
                reasonCodes: [],
                suppressedByHumanAnchor: false,
                triggered: false)
        }

        // Red line 8: human-anchor reserved tone suppresses the
        // escalation. The host needs distance; layering more permit
        // modes would feel like thrashing.
        if humanAnchor?.recommendedSurfaceTone == .reserved {
            var skippedCodes = ["permit.escalation-skipped:human-anchor-reserved"]
            // Stable per-mode trace of what we *would* have escalated
            // to. Useful for post-hoc audit without re-running the
            // computation.
            for mode in pressure.recommendedModes {
                skippedCodes.append(
                    "permit.escalation-suppressed:abyssal:\(mode.rawValue)")
            }
            return BASAbyssalPermitEscalationDecision(
                permit: permit,
                reasonCodes: skippedCodes,
                suppressedByHumanAnchor: true,
                triggered: true)
        }

        // Compute the escalated stackedModes (additive — never
        // remove existing entries) and reasonCodes (additive — never
        // overwrite existing codes).
        var stackedModes = permit.stackedModes
        var addedCodes: [String] = []
        var seen = Set<BASActionPermitMode>(stackedModes)
        seen.insert(permit.mode)

        for mode in pressure.recommendedModes {
            // Always emit a reason code documenting the abyssal
            // recommendation, even when the mode has no single-permit
            // translation.
            addedCodes.append(
                "permit.escalated:abyssal:\(mode.rawValue)")

            // When a translation exists and the target mode is not
            // already in the stack (or the primary mode), append.
            if let target = translate(mode), !seen.contains(target) {
                stackedModes.append(target)
                seen.insert(target)
            }
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

        return BASAbyssalPermitEscalationDecision(
            permit: escalatedPermit,
            reasonCodes: addedCodes,
            suppressedByHumanAnchor: false,
            triggered: true)
    }
}
