import Foundation
import BASMemory
import BASOrchestration

// chapter 一千零四十二 / ADR-020 Step 4 — Arc-2 PURE resolution-credit
// helper。
//
// `BASDeliberationResolutionCredit` maps a decompose frame's TYPED
// unknown records (`BASUnknownRecord` / `BASUnknownKind`,
// BASOrchestration) to evidence keys (`BASEvidenceMatcher`,
// BASMemory) and computes how much of the deliberation loop's own
// added caution a turn's stored evidence lets the loop WITHHOLD —
// floored to never go below the loop-off baseline (ADR-020 §3 Arc-2:
// "withholds the loop's own added caution, never subtracts baseline
// caution")。
//
// Commit 1 ships this DORMANT — it is referenced ONLY by its own
// tests; no `runTurn` path calls it (red-line 7: byte-equal until
// Commit 2 wires the floored caution-withholding into the seam)。
//
// PURE: no instance state, no Date/Random, deterministic — every
// function is a `static func` of its inputs。 The caution magnitude
// is a caller-supplied `increment` param (no magic numbers;
// production callers pass
// `BASDeliberationCaution.uncertainDeliberationRiskIncrement`)。
public enum BASDeliberationResolutionCredit {
    /// Map a typed unknown `kind` to the evidence content type whose
    /// stored atoms can resolve it。 EXHAUSTIVE switch。 `.ambiguity`
    /// has no typed evidence family (it is prose-shaped, not a
    /// missing fact/role/constraint/permission) → returns nil so it
    /// NEVER contributes a key (anti-"theater": ambiguity cannot be
    /// resolved by exact-key match)。 PURE。
    public static func contentType(
        for kind: BASUnknownKind
    ) -> BASEvidenceContentType? {
        switch kind {
        case .missingFact:
            return .fact
        case .missingConstraint:
            return .constraint
        case .missingRole:
            return .role
        case .unresolvedPermission:
            return .permission
        case .ambiguity:
            return nil
        }
    }

    /// Derive the EXACT, typed evidence keys a turn's unknown records
    /// require。 For each record whose `kind` maps to a content type,
    /// the key is `BASEvidenceMatcher.evidenceKey(contentType:
    /// content: record.summary)`。 `.ambiguity` records are dropped
    /// (no content type)。 The result is DE-DUPLICATED preserving
    /// first-seen order (replay-deterministic; two records that
    /// normalize to the same typed key collapse to one)。 PURE。
    public static func requiredEvidenceKeys(
        unknownRecords: [BASUnknownRecord]
    ) -> [String] {
        var seen: Set<String> = []
        var ordered: [String] = []
        for record in unknownRecords {
            guard let type = contentType(for: record.kind) else {
                continue
            }
            let key = BASEvidenceMatcher.evidenceKey(
                contentType: type,
                content: record.summary)
            if seen.insert(key).inserted {
                ordered.append(key)
            }
        }
        return ordered
    }

    /// The floored caution CREDIT a turn earns: the fraction of its
    /// `requiredKeys` resolved by `ledger`, scaled by `increment`。
    ///
    /// Returns 0 when there is nothing to resolve (`requiredKeys`
    /// empty) OR there is no ledger to resolve against (`ledger` nil)
    /// — both mean "no resolution, withhold nothing"。 Otherwise the
    /// resolved set comes from `BASEvidenceMatcher.resolvedKeys(...)`,
    /// which always returns a SUBSET of `requiredKeys`, so
    /// `fraction ∈ [0, 1]` and the credit ∈ [0, increment]。 PURE。
    public static func resolutionCredit(
        requiredKeys: [String],
        ledger: BASEvidenceLedger?,
        increment: Double
    ) -> Double {
        guard !requiredKeys.isEmpty, let ledger else { return 0 }
        let resolved = BASEvidenceMatcher.resolvedKeys(
            requiredKeys: requiredKeys,
            in: ledger,
            relevanceFloor: BASEvidenceMatcher.defaultRelevanceFloor)
        let fraction =
            Double(resolved.count) / Double(requiredKeys.count)
        return fraction * increment
    }

    /// The floored caution the seam will ADD for the turn:
    /// `increment` minus the earned `resolutionCredit`, clamped at 0。
    ///
    /// This is the [0, increment] value (ADR-020 §3 Arc-2): genuine
    /// resolution withholds a fraction of the loop's added caution
    /// without ever going below the loop-off baseline。 Full
    /// resolution → 0 added; no resolution → the full `increment`
    /// added (byte-equal to the pre-Step-4 behavior)。 PURE。
    public static func withheldIncrement(
        requiredKeys: [String],
        ledger: BASEvidenceLedger?,
        increment: Double
    ) -> Double {
        let credit = resolutionCredit(
            requiredKeys: requiredKeys,
            ledger: ledger,
            increment: increment)
        return max(0, increment - credit)
    }
}
