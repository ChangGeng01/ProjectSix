// SPDX-License-Identifier: Apache-2.0
// M385 — `BASUnknownReserve.assertionCeiling` → `BASActionPermit
// .assertionCeiling` cap. Closes附录 K.2.2 second runtime-decision
// wire for the Cthulhu doctrine: when an active unknown reserve is
// present, the permit's free-form `assertionCeiling` string field is
// capped to the strict ceiling implied by the reserve. The L11 wind
// gate already exposes the field; downstream tone / template
// enforcement reads it. The cap is decision-influencing — it
// constrains how confidently the system can assert downstream of
// this turn.
//
// Doctrine pins:
//
//   - **Single commit mouth** (red line v1-#2 + v4 single-mouth):
//     this helper never replaces `permit.mode`; it only narrows the
//     `assertionCeiling` field and appends typed reason codes. The
//     primary commit mouth stays at L11.
//   - **No silent cap**: every cap appends a stable reason code
//     `permit.assertion-ceiling:capped-from:<from>:to:<to>` so the
//     audit trail records the change.
//   - **Monotonic narrowing**: the cap NEVER widens an existing
//     ceiling. If the permit already has a stricter ceiling than the
//     reserve recommends, the existing value is preserved.
//
// Why a string field on permit and an enum on reserve:
// `BASActionPermit.assertionCeiling: String` is the L11 free-form
// policy expression; `BASUnknownReserve.assertionCeiling:
// BASUnknownAssertionCeiling` is a typed five-level reserve readout.
// This helper translates between them via the canonical raw values
// of the enum, which are stable cross-module strings.

import Foundation
import BASPolicy
import BASWorldPrior

// MARK: - BASAssertionCeilingDecision

/// Pure result type carrying the (possibly-capped) permit, the typed
/// reason codes that motivated the cap, and the trigger state.
public struct BASAssertionCeilingDecision: Sendable, Equatable {
    /// The permit after capping. Equal to the input permit (by
    /// value) when no cap fires.
    public let permit: BASActionPermit
    /// Stable reason codes describing the cap. Empty when no cap
    /// fires. Format:
    /// `"permit.assertion-ceiling:capped-from:<from>:to:<to>"`.
    public let reasonCodes: [String]
    /// `true` when an active reserve was supplied AND the resulting
    /// ceiling differs from the input permit's ceiling.
    public let capped: Bool

    public init(
        permit: BASActionPermit,
        reasonCodes: [String],
        capped: Bool
    ) {
        self.permit = permit
        self.reasonCodes = reasonCodes
        self.capped = capped
    }
}

// MARK: - BASAssertionCeilingGate

/// Pure-function helper translating an unknown-reserve readout into
/// a permit assertion-ceiling cap.
///
/// All methods are `static` and free of side effects.
public enum BASAssertionCeilingGate {

    /// Map the typed reserve ceiling enum to the canonical permit
    /// ceiling string. Stable contract (every enum case returns its
    /// raw value as the string) so downstream tone / template
    /// enforcement can string-compare without importing the world
    /// prior module.
    public static func canonicalString(
        for ceiling: BASUnknownAssertionCeiling
    ) -> String {
        ceiling.rawValue
    }

    /// Strictness ranking. Lower number is *less* strict (more
    /// permissive); higher number is *more* strict (more
    /// conservative). Used to decide whether to overwrite an
    /// existing permit ceiling.
    ///
    /// `unrestricted` (0) < `provisional` (1) < `qualified` (2)
    ///   < `metaOnly` (3) < `none` (4).
    public static func strictnessRank(
        for ceiling: BASUnknownAssertionCeiling
    ) -> Int {
        switch ceiling {
        case .unrestricted:
            return 0
        case .provisional:
            return 1
        case .qualified:
            return 2
        case .metaOnly:
            return 3
        case .none:
            return 4
        }
    }

    /// Strictness ranking for permit ceiling strings. Mapping
    /// honors BAS-canonical permit strings ("minimal", "guarded",
    /// "standard", "default") and the reserve enum raw values
    /// ("unrestricted", "provisional", "qualified", "metaOnly",
    /// "none") on a single ordering so cross-vocabulary comparison
    /// is sound.
    ///
    /// Doctrine: a permit ceiling that is at least as strict as the
    /// reserve's recommendation is preserved. Only caps strictly
    /// more permissive than the reserve recommendation are
    /// narrowed.
    ///
    /// Mapping (least → most strict):
    ///
    ///  - `"default"` / `"unrestricted"` → 0
    ///  - `"standard"` / `"provisional"` → 1
    ///  - `"guarded"` / `"qualified"` → 2
    ///  - `"metaOnly"` → 3
    ///  - `"minimal"` / `"none"` → 4
    ///
    /// Unrecognised strings return -1 (less strict than any
    /// recognised value) so a reserve cap can still narrow them.
    /// Hosts shipping non-canonical permit strings should adopt the
    /// canonical vocabulary to participate in the typed cap.
    public static func strictnessRank(
        forPermitString permit: String
    ) -> Int {
        switch permit {
        case "default", BASUnknownAssertionCeiling.unrestricted.rawValue:
            return 0
        case "standard", BASUnknownAssertionCeiling.provisional.rawValue:
            return 1
        case "guarded", BASUnknownAssertionCeiling.qualified.rawValue:
            return 2
        case BASUnknownAssertionCeiling.metaOnly.rawValue:
            return 3
        case "minimal", BASUnknownAssertionCeiling.none.rawValue:
            return 4
        default:
            return -1
        }
    }

    /// Decide a permit cap for one (permit, reserve) pair. Pure
    /// function.
    ///
    /// - Parameters:
    ///   - permit: the current permit issued by L11.
    ///   - reserve: the M320 unknown reserve readout. May be `nil`
    ///     when the run had no active world-prior reserve.
    /// - Returns: a value-typed decision. `decision.permit` is the
    ///   capped permit (or the input permit unchanged when no cap
    ///   fires).
    public static func cap(
        permit: BASActionPermit,
        reserve: BASUnknownReserve?
    ) -> BASAssertionCeilingDecision {
        // No reserve → no cap.
        guard let reserve else {
            return BASAssertionCeilingDecision(
                permit: permit,
                reasonCodes: [],
                capped: false)
        }

        // Inactive reserve (no unknownRefs OR ceiling already
        // unrestricted) → no cap.
        guard reserve.isOpen else {
            return BASAssertionCeilingDecision(
                permit: permit,
                reasonCodes: [],
                capped: false)
        }

        // Compare strictness. Only narrow.
        let reserveRank = strictnessRank(for: reserve.assertionCeiling)
        let permitRank = strictnessRank(
            forPermitString: permit.assertionCeiling)
        guard reserveRank > permitRank else {
            // Permit already at least as strict as the reserve
            // recommends. No cap, no reason code (silent — the
            // permit was already correct).
            return BASAssertionCeilingDecision(
                permit: permit,
                reasonCodes: [],
                capped: false)
        }

        // Cap the permit.
        let from = permit.assertionCeiling
        let to = canonicalString(for: reserve.assertionCeiling)
        let reasonCode = "permit.assertion-ceiling:capped-from:\(from):to:\(to)"
        let cappedPermit = BASActionPermit(
            schemaVersion: permit.schemaVersion,
            mode: permit.mode,
            stackedModes: permit.stackedModes,
            reasonCodes: permit.reasonCodes + [reasonCode],
            allowedDomains: permit.allowedDomains,
            blockedDomains: permit.blockedDomains,
            assertionCeiling: to,
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
        return BASAssertionCeilingDecision(
            permit: cappedPermit,
            reasonCodes: [reasonCode],
            capped: true)
    }
}
