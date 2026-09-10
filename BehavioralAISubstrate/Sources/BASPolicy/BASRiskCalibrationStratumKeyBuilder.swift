// MARK: - BASRiskCalibrationStratumKeyBuilder — chapter 二百七十二 / M759
//
// Stratum-key construction primitive — closes Stage 4 production-
// wire gap.
//
// ## Why this exists
//
// chapter 二百六十三 / M746 shipped `BASRiskCalibrationStratumDelta`
// with a `stratumKey: String` field whose canonical format is
// `"tone=angry|stake=high|confidant=public"` per chapter 二百六十二
// aggregator output. The bundle author + the L11 host runtime
// MUST produce byte-equal stratum-key strings or the gate's
// `delta(forStratumKey:)` lookup misses.
//
// chapter 二百六十三/二百六十四 shipped the bundle + gate but no
// canonical key-construction primitive. Hosts had to roll their
// own string concatenation, and any drift between operator-side
// (Python `aggregate_risk_stratum.py`) and substrate-side (Swift
// L11 lookup) silently breaks the lookup — gate returns base
// threshold even when a delta is configured.
//
// chapter 二百七十二 ships:
//   - `BASRiskCalibrationStratumKeyBuilder` — typed key
//     constructor. Same canonical format as the Python
//     aggregator (`scripts/aggregate_risk_stratum.py`):
//     `"<key1>=<value1>|<key2>=<value2>|..."` with keys sorted
//     alphabetically.
//   - The Swift-side aggregator output format pin via test:
//     same input → byte-equal key as Python aggregator emits.
//
// This is the **production-wire** gap I named in self-assessment:
// without it, the gate's typed primitives shipped with no
// guaranteed-correct consumer-side construction. With it, hosts
// have one canonical key-builder both sides reference.
//
// ## Doctrine pins
//
//   - 不变量 #2 神经不掌权: builder is pure value-type computation;
//     no permit gate, no decision.
//   - 不变量 #3 私有经验不进权重: builder operates on stratum
//     dimensions (tone / stake / confidant) — generalized signal
//     keys, never host-specific identifiers. The aggregator
//     (chapter 二百六十二) is responsible for filtering host data
//     out of the input dimensions; the builder just formats.
//   - chapter 二百六十二 / M745 cross-language schema parity: the
//     Python aggregator + this Swift builder produce byte-equal
//     stratum keys for the same input. Tested explicitly.
//   - chapter 一百十三 anti-magic-number: separator + assignment
//     characters extracted as static constants.

import Foundation

/// Pure value-type stratum-key constructor. Hosts call
/// `BASRiskCalibrationStratumKeyBuilder.key(from:)` to produce
/// the canonical string used as input to
/// `BASRiskCalibrationGate.effective<Tier>Threshold(forStratumKey:base:)`.
public enum BASRiskCalibrationStratumKeyBuilder {
    /// Separator between dimension assignments. Matches Python
    /// aggregator output format.
    public static let dimensionSeparator: Character = "|"

    /// Character separating key from value within one dimension
    /// assignment.
    public static let assignmentCharacter: Character = "="

    /// Sentinel for missing dimension values. Matches Python
    /// aggregator's `_unknown` placeholder so cross-language
    /// keys collide on missing data (operators see the
    /// "_unknown" stratum aggregated rather than per-row leak).
    public static let missingValueSentinel: String = "_unknown"

    /// Build a canonical stratum key from a `(dimension → value)`
    /// dictionary. Keys are sorted alphabetically for
    /// determinism — identical input always produces identical
    /// output regardless of dictionary insertion order.
    ///
    /// Format: `"<key1>=<value1>|<key2>=<value2>|..."`
    ///
    /// Empty / absent dimension values resolve to
    /// `missingValueSentinel` (`"_unknown"`), matching the Python
    /// aggregator's behaviour. Whitespace-only values also
    /// resolve to the sentinel.
    ///
    /// - Parameter dimensions: dimension-name → value dict.
    ///   Operators choose the dimension set (default per chapter
    ///   二百六十二: `["tone", "stake", "confidant"]`).
    public static func key(
        from dimensions: [String: String]
    ) -> String {
        let separator = String(dimensionSeparator)
        let assignment = String(assignmentCharacter)
        return dimensions.keys.sorted().map { keyName in
            let raw = dimensions[keyName] ?? ""
            let trimmed = raw.trimmingCharacters(
                in: .whitespacesAndNewlines)
            let value = trimmed.isEmpty
                ? missingValueSentinel
                : trimmed
            return "\(keyName)\(assignment)\(value)"
        }.joined(separator: separator)
    }

    /// Convenience for the canonical 3-dim default
    /// `(tone, stake, confidant)`. Matches
    /// `aggregate_risk_stratum.py --stratum-keys tone stake confidant`
    /// (chapter 二百六十二 default).
    public static func canonicalThreeDimensionKey(
        tone: String,
        stake: String,
        confidant: String
    ) -> String {
        key(from: [
            "tone": tone,
            "stake": stake,
            "confidant": confidant
        ])
    }
}
