// MARK: - BASRiskCalibrationBundle — chapter 二百六十三 / M746
//
// L11 Risk Calibration typed value — Stage 4 Step 3 of 5.
//
// ## Why this exists
//
// chapter 二百六十一 / M744 shipped ADR-012 ("Hybrid offline-
// pipeline doctrine") which permits a between-deploy mutation
// path for L11 risk gate thresholds. chapter 二百六十二 / M745
// shipped the Mac-side aggregator that produces stratum stats
// from bench JSONL.
//
// chapter 二百六十三 ships the typed bundle the operator authors
// from those stats. The bundle is what the L11 gate consumes at
// deploy time — typed, versioned, signed, immutable once shipped.
//
// **What this is**:
//   - A typed Codable struct with a versioned bundle ID,
//     per-stratum threshold deltas, an L14 sovereign warrant ref,
//     and provenance metadata.
//   - The single source of truth for "what tuning is the L11 gate
//     applying right now".
//   - Inputs come from operator review of `aggregate_risk_stratum.py`
//     output (chapter 二百六十二) — not auto-derived.
//
// **What this is NOT**:
//   - NOT a permit. The bundle stores threshold *deltas*; the
//     L11 gate (chapter 二百六十四) applies them against base
//     thresholds at deploy time. Per-turn permit logic stays
//     deterministic given a fixed bundle.
//   - NOT mutated per-turn. ADR-012 forbids mid-turn replacement.
//   - NOT auto-derived. ADR-012 forbids auto-deploy.
//   - NOT host-specific. ADR-012 forbids per-host tuning.
//
// ## Doctrine pins
//
//   - 不变量 #2 神经不掌权: the bundle is operator-authored +
//     L14-signed; substrate doesn't auto-derive. Substrate's L11
//     gate consumes the bundle as input data.
//   - 不变量 #3 私有经验不进权重: stratum keys are generalized
//     (`tone|stake|confidant`) — never host-IDs. Aggregator
//     (chapter 二百六十二) strips host data; bundle's input is
//     already filtered.
//   - ADR-006 strict: bundle is between-deploy mutation only.
//     Per-turn permit logic doesn't read bench JSONL directly;
//     it reads the bundle's frozen deltas.
//   - ADR-012: bundle is the typed payload of the Hybrid offline
//     pipeline. `bundleVersion` is monotonic; `sovereignWarrantRef`
//     is required (empty refs are invalid).
//   - 红线 7 HINT-ONLY: the bundle's deltas are inputs to the
//     L11 gate's deterministic logic, not hints. But the bundle
//     is only PRODUCED via observation-driven analysis +
//     operator decision; the live observation never directly
//     mutates anything.
//   - chapter 一百十三 anti-magic-number: every default tunable
//     extracted as `static let default*` constant.
//   - chapter 二百十一 single-source-of-truth: bundle schema lives
//     in this one file.

import Foundation
import BASRuntimeCore

// MARK: - One-stratum delta

/// Per-stratum threshold adjustment carried by a calibration
/// bundle. Each delta names a stratum key (e.g.
/// `"tone=angry|stake=high|confidant=public"`) and three
/// threshold offsets — one per L11 risk severity tier.
public struct BASRiskCalibrationStratumDelta:
    BASSchemaVersioned, Sendable, Equatable, Codable, Hashable
{
    public static let currentSchemaVersion = "1.0.0"

    /// Maximum absolute delta any single threshold can carry per
    /// bundle. Defends against bad bundles (e.g. operator typo
    /// proposing +5.0) overshooting the stable range. Per ADR-012:
    /// bundles are deploy-time mutations, but the deploy-time
    /// safety check still applies.
    public static let maximumAbsoluteDelta: Double = 0.25

    public var schemaVersion: String

    /// Stable string describing which stratum the delta applies
    /// to. Format: `"tone=<value>|stake=<value>|confidant=<value>"`
    /// (or whatever stratum-key composition the aggregator + L11
    /// gate agree on). This file does NOT enforce a particular
    /// format — the contract is between the aggregator (chapter
    /// 二百六十二) and the L11 gate (chapter 二百六十四).
    public let stratumKey: String

    /// Threshold delta for `mediumRiskThreshold` in [-0.25, +0.25].
    /// Positive deltas RAISE the threshold (require more signal
    /// to trip medium risk); negative deltas LOWER the threshold
    /// (trip medium risk on weaker signal).
    public let mediumThresholdDelta: Double

    /// Threshold delta for `highRiskThreshold` in [-0.25, +0.25].
    public let highThresholdDelta: Double

    /// Threshold delta for `extremeRiskThreshold` in [-0.25, +0.25].
    public let extremeThresholdDelta: Double

    /// Number of bench rows the stratum was derived from. Used
    /// downstream to weight the delta when multiple bundles are
    /// composed (post-MVP). Negative or zero means "synthesize
    /// only — do not apply" (operator-authored test bundle).
    public let evidenceRowCount: Int

    /// Free-form audit codes explaining WHY this delta exists.
    /// E.g. `["aggregate-rollup:2026-04", "operator-review:claude-prim"]`.
    public let reasonCodes: [String]

    public init(
        schemaVersion: String =
            BASRiskCalibrationStratumDelta.currentSchemaVersion,
        stratumKey: String,
        mediumThresholdDelta: Double = 0,
        highThresholdDelta: Double = 0,
        extremeThresholdDelta: Double = 0,
        evidenceRowCount: Int = 0,
        reasonCodes: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        // Trim+validate stratumKey: empty keys are invalid (the
        // L11 gate would have nothing to look up).
        let trimmedKey = stratumKey.trimmingCharacters(
            in: .whitespacesAndNewlines)
        self.stratumKey = trimmedKey
        // Clamp to [-maximumAbsoluteDelta, +maximumAbsoluteDelta].
        // Defensive: a runaway delta would corrupt the L11 gate's
        // tuning even with operator review (operator typo path).
        let bound = Self.maximumAbsoluteDelta
        self.mediumThresholdDelta = Self.clamp(
            mediumThresholdDelta, lo: -bound, hi: bound)
        self.highThresholdDelta = Self.clamp(
            highThresholdDelta, lo: -bound, hi: bound)
        self.extremeThresholdDelta = Self.clamp(
            extremeThresholdDelta, lo: -bound, hi: bound)
        self.evidenceRowCount = max(0, evidenceRowCount)
        // Trim+filter empty reason codes.
        self.reasonCodes = reasonCodes
            .map { $0.trimmingCharacters(
                in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// True iff this delta makes any threshold change. Useful
    /// for filtering "zero-delta strata" from a bundle's emitted
    /// audit codes.
    public var changesAnyThreshold: Bool {
        mediumThresholdDelta != 0
            || highThresholdDelta != 0
            || extremeThresholdDelta != 0
    }

    fileprivate static func clamp(
        _ value: Double,
        lo: Double,
        hi: Double
    ) -> Double {
        if value.isNaN { return 0 }
        return min(hi, max(lo, value))
    }
}

// MARK: - Bundle

/// Versioned, signed, deploy-time-immutable calibration bundle.
/// The L11 risk gate (chapter 二百六十四) accepts one bundle at
/// a time and applies its strata deltas to base thresholds.
/// chapter 四百五 / M987:adopts `BASBundleProtocol` via
/// synthesized bundleID + producedAt mapping。 14th of 20+
/// concrete bundle conformances。
public struct BASRiskCalibrationBundle:
    BASSchemaVersioned, BASBundleProtocol,
    Sendable, Equatable, Codable, Hashable
{
    public static let currentSchemaVersion = "1.0.0"

    /// chapter 四百五 / M987:`BASBundleProtocol` synthesized
    /// bundleID derived from bundleVersion (the bundle's
    /// natural identity field)。
    public var bundleID: String {
        "risk-calibration-bundle:\(bundleVersion)"
    }

    /// chapter 四百五 / M987:`BASBundleProtocol.recordedAt`
    /// maps to `producedAt`。
    public var recordedAt: Date { producedAt }

    /// Magic version string for the "no calibration" baseline.
    /// L11 gates that have never received a bundle behave as if
    /// they had received this. Substrate code can compare
    /// against this constant rather than checking nil.
    public static let baselineVersion: String = "v0.0.0-baseline"

    public var schemaVersion: String

    /// Monotonic bundle version string. Format `vN.M.P` per
    /// ADR-012. The L11 gate accepts a new bundle only if its
    /// version is strictly greater than the current one (string
    /// compare with `<` is monotonic for `vN.M.P` format with
    /// zero-padding NOT enforced — operators are responsible for
    /// not regressing). Empty string is invalid.
    public let bundleVersion: String

    /// Wall-clock timestamp when the operator authored the
    /// bundle. Recorded for audit forensics — the L11 gate doesn't
    /// use it for any decision.
    public let producedAt: Date

    /// Reference to the aggregate-stats JSON the bundle was
    /// authored from. Format: `"aggregate-rollup:<sha256-of-input-json>"`
    /// (or any operator-defined provenance string). Required —
    /// empty string is invalid. Audit walkers grep for this ref
    /// to reconstruct "what data did this bundle come from".
    public let aggregateProvenanceRef: String

    /// All strata deltas. The L11 gate may receive an empty
    /// array — a "deploy this bundle to RESET to baseline" use
    /// case is supported via empty `strataDeltas`.
    public let strataDeltas: [BASRiskCalibrationStratumDelta]

    /// L14 sovereign warrant authorizing this bundle. Required —
    /// empty string is invalid. The L14 ledger records this ref
    /// when the warrant is signed; downstream verifiers use it
    /// to reconstruct the chain.
    public let sovereignWarrantRef: String

    /// Optional pointer to the bundle this version supersedes.
    /// `nil` means "this is the first bundle this L11 gate has
    /// received". A non-nil value lets audit walkers chain
    /// bundle history.
    public let supersedesBundleVersion: String?

    /// Operator-supplied human-readable summary. NOT machine-
    /// parsed — for audit forensics + operator review only.
    public let summary: String

    public init(
        schemaVersion: String =
            BASRiskCalibrationBundle.currentSchemaVersion,
        bundleVersion: String,
        producedAt: Date = Date(),
        aggregateProvenanceRef: String,
        strataDeltas: [BASRiskCalibrationStratumDelta] = [],
        sovereignWarrantRef: String,
        supersedesBundleVersion: String? = nil,
        summary: String = ""
    ) {
        self.schemaVersion = schemaVersion
        self.bundleVersion = bundleVersion
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.producedAt = producedAt
        self.aggregateProvenanceRef = aggregateProvenanceRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // De-duplicate by stratumKey: if the operator supplied
        // multiple deltas for the same key, last-wins (typical
        // typo recovery). This is permitted because the bundle
        // is operator-authored — bench-derived bundles will not
        // hit this path.
        var seenKeys: Set<String> = []
        var dedup: [BASRiskCalibrationStratumDelta] = []
        for delta in strataDeltas.reversed() {
            if seenKeys.insert(delta.stratumKey).inserted {
                dedup.append(delta)
            }
        }
        self.strataDeltas = dedup.reversed()
        self.sovereignWarrantRef = sovereignWarrantRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.supersedesBundleVersion = supersedesBundleVersion?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.summary = summary
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Validation

    /// True iff every required field is non-empty + the bundle
    /// is structurally well-formed. The L11 gate (chapter 二百六十四)
    /// rejects bundles where this returns false.
    public var isWellFormed: Bool {
        !bundleVersion.isEmpty
            && bundleVersion != Self.baselineVersion
            && !aggregateProvenanceRef.isEmpty
            && !sovereignWarrantRef.isEmpty
    }

    // MARK: - Lookup

    /// Look up a delta by stratum key. Returns nil if absent.
    /// O(N) — bundles are small enough that a dictionary index
    /// isn't worth the memory overhead.
    public func delta(
        forStratumKey key: String
    ) -> BASRiskCalibrationStratumDelta? {
        strataDeltas.first { $0.stratumKey == key }
    }

    /// Total number of bench rows this bundle's strata represent.
    /// Sum of `evidenceRowCount` across all strata. Useful for
    /// observability ("v1.0.0 bundle covers 50K rows of evidence").
    public var totalEvidenceRowCount: Int {
        strataDeltas.reduce(0) {
            $0 + $1.evidenceRowCount
        }
    }

    /// Subset of strata that actually change a threshold. Hosts
    /// emit this as audit codes when applying a bundle so audit
    /// walkers can grep "which strata moved this turn".
    public var changingStrata: [BASRiskCalibrationStratumDelta] {
        strataDeltas.filter { $0.changesAnyThreshold }
    }

    // MARK: - Baseline

    /// The "no calibration applied" sentinel. L11 gates that
    /// have never received a bundle behave as if they had this.
    /// `isWellFormed` is `false` for the baseline — the L11 gate
    /// accepts it as a special case.
    public static let baseline: BASRiskCalibrationBundle =
        BASRiskCalibrationBundle(
            bundleVersion: baselineVersion,
            aggregateProvenanceRef: "_baseline_no_input",
            strataDeltas: [],
            sovereignWarrantRef: "_baseline_no_warrant",
            summary: "Baseline — no operator calibration applied.")
}
