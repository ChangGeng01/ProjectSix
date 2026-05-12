// SPDX-License-Identifier: Apache-2.0
// M445 (chapter 一百十七) — assertion-ceiling gating for the
// chapter 一百十四 L4 ontology fog + L9 unknown retention loop
// schemas. Extends the M385 `BASAssertionCeilingGate` pattern
// (BASUnknownReserve → permit ceiling cap) with two new
// upstream sources, both wired through the same M385 strictness
// rank ordering for sound cross-source comparison.
//
// ## Why this exists
//
// `BASOntologyFog` (chapter 一百十四 L4) carries
// `partialGraspQuality` ∈ {partialGrasp, provisionalNaming,
// unnameable}. When the fog is at the strictest level
// (unnameable), the substrate has explicitly admitted "this
// subject resists naming" — verdict assertions about the
// subject MUST be capped to the strictest ceiling so downstream
// tone / template enforcement does not over-claim.
//
// `BASUnknownRetentionLoop` (chapter 一百十四 L9) carries
// `safeAssertionCeiling: Double` ∈ [0, 1]. When the loop is
// active (preserved unknowns + cooling period), the safe
// ceiling translates into a permit cap: lower numeric ceiling
// → more strict assertion ceiling.
//
// Both sources can fire simultaneously. The decision merges
// them by **monotonic narrowing**: the strictest applicable
// cap wins; less strict caps are ignored. Reason codes record
// every source that contributed.
//
// ## Doctrine pins
//
// - **Single commit mouth** (red line v1-#2 + v4 single-mouth):
//   this helper never replaces `permit.mode`; only narrows
//   `assertionCeiling`. Primary commit mouth stays at L11.
// - **Monotonic narrowing**: the cap NEVER widens an existing
//   ceiling. If permit already has a stricter ceiling than
//   either source recommends, the existing value is preserved.
// - **No silent cap**: every cap appends a stable typed reason
//   code so the audit trail records every source contribution.
// - **Composability with M385**: this helper is INDEPENDENT
//   of `BASAssertionCeilingGate` (M385 reads from
//   `BASUnknownReserve`). Run M385 first, then run this
//   helper on the M385-output permit; both helpers honor the
//   same strictness ordering, so order doesn't change the
//   final cap.
//
// ## DAG discipline
//
// Imports `Foundation` + `BASRuntimeCore` + `BASPolicy` +
// `BASWorldPrior`. No upstream BAS package back-edge.

import Foundation
import BASPolicy
import BASRuntimeCore
import BASWorldPrior

// MARK: - BASCthulhuAssertionCeilingDecision

/// Pure result type carrying the (possibly-capped) permit, the
/// typed reason codes that motivated the cap, the trigger
/// state, and per-source fired flags so callers can branch.
public struct BASCthulhuAssertionCeilingDecision:
    Codable, Sendable, Equatable
{
    /// The permit after capping. Equal (by value) to input
    /// permit when no cap fires.
    public let permit: BASActionPermit
    /// Stable reason codes describing the cap. Empty when no
    /// cap fires. Format:
    /// `"permit.assertion-ceiling:cthulhu-fog:capped-from:<from>:to:<to>"`
    /// `"permit.assertion-ceiling:cthulhu-retention:capped-from:<from>:to:<to>"`
    public let reasonCodes: [String]
    /// `true` when the resulting ceiling differs from the input
    /// permit's ceiling.
    public let capped: Bool
    /// `true` when fog source contributed a strictness rank
    /// above the input permit (regardless of which source won
    /// the merge).
    public let firedFog: Bool
    /// `true` when retention-loop source contributed a
    /// strictness rank above the input permit.
    public let firedRetentionLoop: Bool

    public init(
        permit: BASActionPermit,
        reasonCodes: [String],
        capped: Bool,
        firedFog: Bool,
        firedRetentionLoop: Bool
    ) {
        self.permit = permit
        self.reasonCodes = reasonCodes
        self.capped = capped
        self.firedFog = firedFog
        self.firedRetentionLoop = firedRetentionLoop
    }
}

// MARK: - BASCthulhuAssertionCeilingGate

public enum BASCthulhuAssertionCeilingGate {

    // MARK: Named constants (anti-magic-number doctrine)

    /// Threshold at which retention-loop safe ceiling triggers
    /// strictest cap (`none` rank 4). Below this, retention is
    /// at minimum trust.
    public static let retentionLoopNoneThreshold: Double = 0.25

    /// Threshold at which retention-loop safe ceiling triggers
    /// `metaOnly` cap (rank 3).
    public static let retentionLoopMetaOnlyThreshold: Double = 0.5

    /// Threshold at which retention-loop safe ceiling triggers
    /// `qualified` cap (rank 2).
    public static let retentionLoopQualifiedThreshold: Double = 0.75

    // MARK: Decision

    /// Compute the composite cap on a permit given fog +
    /// retention-loop sources. Pure function.
    ///
    /// - Parameters:
    ///   - permit: the current permit issued by L11 (may
    ///     already be capped by M385 BASAssertionCeilingGate).
    ///   - ontologyFog: M444-derived L4 fog readout. May be
    ///     `nil` when the run had no L4 unknown.
    ///   - retentionLoop: chapter 一百十四 L9 retention loop.
    ///     May be `nil` when no preserved unknowns.
    /// - Returns: composite cap decision.
    public static func cap(
        permit: BASActionPermit,
        ontologyFog: BASOntologyFog?,
        retentionLoop: BASUnknownRetentionLoop?
    ) -> BASCthulhuAssertionCeilingDecision {
        let permitRank = BASAssertionCeilingGate
            .strictnessRank(forPermitString: permit.assertionCeiling)
        var reasonCodes: [String] = []
        var firedFog = false
        var firedRetentionLoop = false
        var bestRank = permitRank
        var bestCeilingString = permit.assertionCeiling

        // Source 1: fog
        if let fog = ontologyFog {
            let fogCap = fogQualityToCeiling(fog.partialGraspQuality)
            let fogRank = BASAssertionCeilingGate
                .strictnessRank(for: fogCap)
            if fogRank > permitRank {
                firedFog = true
                if fogRank > bestRank {
                    reasonCodes.append(
                        "permit.assertion-ceiling:cthulhu-fog:" +
                        "capped-from:\(permit.assertionCeiling):" +
                        "to:\(fogCap.rawValue)")
                    bestRank = fogRank
                    bestCeilingString = fogCap.rawValue
                }
            }
        }

        // Source 2: retention loop
        if let loop = retentionLoop, !loop.preservedUnknownRefs.isEmpty {
            let loopCap = retentionLoopToCeiling(
                loop.safeAssertionCeiling)
            let loopRank = BASAssertionCeilingGate
                .strictnessRank(for: loopCap)
            if loopRank > permitRank {
                firedRetentionLoop = true
                if loopRank > bestRank {
                    reasonCodes.append(
                        "permit.assertion-ceiling:cthulhu-retention:" +
                        "capped-from:\(permit.assertionCeiling):" +
                        "to:\(loopCap.rawValue)")
                    bestRank = loopRank
                    bestCeilingString = loopCap.rawValue
                }
            }
        }

        let capped = bestRank > permitRank
        let outputPermit: BASActionPermit
        if capped {
            outputPermit = permit.withAssertionCeiling(bestCeilingString)
        } else {
            outputPermit = permit
        }
        return BASCthulhuAssertionCeilingDecision(
            permit: outputPermit,
            reasonCodes: reasonCodes,
            capped: capped,
            firedFog: firedFog,
            firedRetentionLoop: firedRetentionLoop)
    }

    // MARK: - Mapping helpers

    /// Map fog quality enum to permit assertion ceiling enum.
    /// Total function.
    public static func fogQualityToCeiling(
        _ quality: BASOntologyFogQuality
    ) -> BASUnknownAssertionCeiling {
        switch quality {
        case .partialGrasp: return .provisional
        case .provisionalNaming: return .qualified
        case .unnameable: return .none
        }
    }

    /// Map a `[0, 1]` retention-loop safe ceiling onto the
    /// permit ceiling enum.
    public static func retentionLoopToCeiling(
        _ safeCeiling: Double
    ) -> BASUnknownAssertionCeiling {
        if safeCeiling <= retentionLoopNoneThreshold {
            return .none
        }
        if safeCeiling <= retentionLoopMetaOnlyThreshold {
            return .metaOnly
        }
        if safeCeiling <= retentionLoopQualifiedThreshold {
            return .qualified
        }
        return .provisional
    }
}

// MARK: - BASActionPermit narrow helper

private extension BASActionPermit {
    /// Return a copy with `assertionCeiling` replaced. All
    /// other fields stay byte-equal so callers can compare
    /// before/after for cap-detection.
    func withAssertionCeiling(_ ceiling: String) -> BASActionPermit {
        BASActionPermit(
            schemaVersion: schemaVersion,
            mode: mode,
            stackedModes: stackedModes,
            reasonCodes: reasonCodes,
            allowedDomains: allowedDomains,
            blockedDomains: blockedDomains,
            assertionCeiling: ceiling,
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
