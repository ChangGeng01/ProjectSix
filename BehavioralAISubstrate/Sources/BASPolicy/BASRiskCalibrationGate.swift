// MARK: - BASRiskCalibrationGate — chapter 二百六十四 / M747
//
// L11 Risk Calibration deploy-time gate — Stage 4 Step 4 of 5.
//
// ## Why this exists
//
// chapter 二百六十三 / M746 shipped `BASRiskCalibrationBundle` —
// the typed payload. What was missing: the substrate-side primitive
// that **holds** a bundle, **accepts replacements** under explicit
// validation, and **provides effective thresholds** to L11 callers
// that want to apply per-stratum deltas.
//
// chapter 二百六十四 ships `BASRiskCalibrationGate`:
//
//   - Actor (one per L11 deployment) holding the **current**
//     bundle. Reads concurrent; replacements serialized.
//   - `replace(_:)` validates `isWellFormed` + monotonic version
//     + supersedes-chain consistency. Rejected bundles throw a
//     typed `ReplaceError`; the gate's bundle does NOT change.
//   - `effective<Tier>Threshold(forStratumKey:base:)` getters
//     apply the active bundle's per-stratum delta to the caller-
//     supplied base threshold. If no delta exists for the stratum
//     key, returns the base threshold unchanged.
//   - Replacement emits typed audit reason codes the host runtime
//     can pipe into `BASSovereignAuditLedger`. One bundle
//     replacement → one audit entry per ADR-012.
//
// ## Doctrine pins
//
//   - 不变量 #2 神经不掌权: bundle replacement is operator-driven
//     + L14-signed (the gate validates `sovereignWarrantRef` is
//     non-empty via `isWellFormed`). Substrate doesn't auto-derive.
//   - 不变量 #3 私有经验不进权重: stratum keys are the only
//     identifier — never host-IDs. Bundle's input was pre-
//     filtered by the aggregator (chapter 二百六十二).
//   - ADR-006 strict: gate accepts replacements **between** turns,
//     never mid-turn. Two consecutive turns with the same bundle
//     produce identical decisions.
//   - ADR-012: bundle is the typed payload of the Hybrid pipeline.
//     Monotonic version enforcement defends against accidental
//     replay-replacement.
//   - 红线 7 HINT-ONLY: the gate's deltas are inputs to
//     deterministic L11 logic, not hints — but the bundle is only
//     PRODUCED via observation-driven analysis + operator
//     decision; the per-turn loop never sees observation
//     directly mutating anything.
//   - chapter 二百十一 single-source-of-truth: gate + replace
//     primitives live in this file; bundle schema stays in
//     `BASRiskCalibrationBundle.swift`.
//
// ## API contract
//
// Hosts construct one gate per L11 deployment. The gate's
// initial bundle is `BASRiskCalibrationBundle.baseline`; first
// successful `replace(_:)` mutates state. Per-turn risk-
// calibration code reads `effective<Tier>Threshold(...)` to
// compute final thresholds.

import Foundation
import BASRuntimeCore

// MARK: - Replace outcome

/// Result of one successful `replace(_:)` call. Hosts pipe
/// `auditReasonCodes` into the sovereign audit ledger so the
/// trail records "bundle vN.M.P replaced bundle vM.M.P at time T,
/// with K strata changing thresholds".
public struct BASRiskCalibrationGateReplaceOutcome:
    Sendable, Equatable, Codable, Hashable
{
    public let priorBundleVersion: String
    public let newBundleVersion: String
    public let strataChanged: Int
    public let totalEvidenceRowCount: Int
    public let auditReasonCodes: [String]
    public let appliedAt: Date

    public init(
        priorBundleVersion: String,
        newBundleVersion: String,
        strataChanged: Int,
        totalEvidenceRowCount: Int,
        auditReasonCodes: [String],
        appliedAt: Date = Date()
    ) {
        self.priorBundleVersion = priorBundleVersion
        self.newBundleVersion = newBundleVersion
        self.strataChanged = strataChanged
        self.totalEvidenceRowCount = totalEvidenceRowCount
        self.auditReasonCodes = auditReasonCodes
        self.appliedAt = appliedAt
    }
}

// MARK: - Gate

/// L11 deploy-time bundle holder. One per L11 deployment.
public actor BASRiskCalibrationGate {

    public enum ReplaceError: Error, Equatable, Sendable {
        case malformedBundle(reason: String)
        case nonMonotonicVersion(
            current: String, proposed: String)
        case supersedesMismatch(
            currentVersion: String,
            proposedSupersedes: String)
    }

    /// The currently-applied bundle. `BASRiskCalibrationBundle.baseline`
    /// at construction; mutated only by `replace(_:)`.
    private var bundle: BASRiskCalibrationBundle

    public init(
        initial: BASRiskCalibrationBundle = .baseline
    ) {
        self.bundle = initial
    }

    // MARK: - Read

    /// The current bundle. Read-only externally; replacements
    /// go through `replace(_:)`.
    public var currentBundle: BASRiskCalibrationBundle {
        bundle
    }

    public var currentBundleVersion: String {
        bundle.bundleVersion
    }

    // MARK: - Replace

    /// Replace the gate's current bundle. Throws a typed
    /// `ReplaceError` on validation failure; the gate's bundle
    /// is unchanged in that case.
    ///
    /// Validation rules:
    ///   - `proposed.isWellFormed` must be true (otherwise
    ///     `.malformedBundle(reason:)` with the failing field).
    ///   - `proposed.bundleVersion` must be strictly greater than
    ///     the current version. The gate's monotonicity defense
    ///     against replay-replacement (without it, an attacker
    ///     could re-deploy an older bundle to revert tuning).
    ///     The "strictly greater" comparison is string-compare;
    ///     operators are responsible for using `vN.M.P` format
    ///     with consistent zero-padding.
    ///   - If `proposed.supersedesBundleVersion` is non-nil, it
    ///     must match `currentBundleVersion`. If it's nil, the
    ///     current bundle must be `.baseline`. Defends against
    ///     a bundle authored against an older audit chain being
    ///     deployed onto a more recent gate.
    @discardableResult
    public func replace(
        _ proposed: BASRiskCalibrationBundle
    ) throws -> BASRiskCalibrationGateReplaceOutcome {
        guard proposed.isWellFormed else {
            throw ReplaceError.malformedBundle(
                reason:
                    "bundle isWellFormed=false; check version, " +
                    "provenanceRef, and warrantRef")
        }
        // Monotonic version check (numeric-aware — audit policy-obs-misc LOW-1: raw String `>`
        // rejected a legitimate v9→v10 upgrade). Baseline counts as "lower than any non-baseline".
        let currentVersion = bundle.bundleVersion
        let proposedVersion = proposed.bundleVersion
        if currentVersion != BASRiskCalibrationBundle.baselineVersion {
            guard BASCalibrationVersionOrder.compare(proposedVersion, currentVersion) == .orderedDescending else {
                throw ReplaceError.nonMonotonicVersion(
                    current: currentVersion,
                    proposed: proposedVersion)
            }
        }
        // Supersedes-chain consistency.
        if let supersedes = proposed.supersedesBundleVersion {
            guard supersedes == currentVersion else {
                throw ReplaceError.supersedesMismatch(
                    currentVersion: currentVersion,
                    proposedSupersedes: supersedes)
            }
        } else {
            // If proposed.supersedes is nil, current must be the
            // baseline (otherwise the new bundle is silently
            // dropping audit history).
            guard
                currentVersion ==
                    BASRiskCalibrationBundle.baselineVersion
            else {
                throw ReplaceError.supersedesMismatch(
                    currentVersion: currentVersion,
                    proposedSupersedes: "(nil)")
            }
        }

        let priorVersion = currentVersion
        let strataChanged = proposed.changingStrata.count
        let totalEvidence = proposed.totalEvidenceRowCount

        // Build typed audit reason codes per ADR-012.
        var codes: [String] = [
            "risk-calibration:bundle-replaced:" +
                "from-\(priorVersion):to-\(proposedVersion)"
        ]
        codes.append(
            "risk-calibration:strata-changed:" +
                "\(strataChanged)")
        codes.append(
            "risk-calibration:evidence-rows:\(totalEvidence)")
        codes.append(
            "risk-calibration:warrant:\(proposed.sovereignWarrantRef)")
        codes.append(
            "risk-calibration:provenance:\(proposed.aggregateProvenanceRef)")

        // Mutate state under actor isolation (this is the only
        // place that writes to `bundle`).
        self.bundle = proposed

        return BASRiskCalibrationGateReplaceOutcome(
            priorBundleVersion: priorVersion,
            newBundleVersion: proposedVersion,
            strataChanged: strataChanged,
            totalEvidenceRowCount: totalEvidence,
            auditReasonCodes: codes)
    }

    // MARK: - Effective threshold lookups

    /// Apply the active bundle's per-stratum medium-threshold
    /// delta to `base`. Returns `base + delta` clamped to [0, 1]
    /// (since L11 thresholds are normalized risk scores). If no
    /// delta exists for `stratumKey`, returns `base` unchanged.
    public func effectiveMediumThreshold(
        forStratumKey stratumKey: String,
        base: Double
    ) -> Double {
        guard
            let delta = bundle.delta(forStratumKey: stratumKey)
        else { return Self.clamp01(base) }
        return Self.clamp01(base + delta.mediumThresholdDelta)
    }

    /// Apply the active bundle's per-stratum high-threshold delta.
    public func effectiveHighThreshold(
        forStratumKey stratumKey: String,
        base: Double
    ) -> Double {
        guard
            let delta = bundle.delta(forStratumKey: stratumKey)
        else { return Self.clamp01(base) }
        return Self.clamp01(base + delta.highThresholdDelta)
    }

    /// Apply the active bundle's per-stratum extreme-threshold delta.
    public func effectiveExtremeThreshold(
        forStratumKey stratumKey: String,
        base: Double
    ) -> Double {
        guard
            let delta = bundle.delta(forStratumKey: stratumKey)
        else { return Self.clamp01(base) }
        return Self.clamp01(base + delta.extremeThresholdDelta)
    }

    /// True iff a delta exists for `stratumKey` in the active
    /// bundle. Useful for hosts that want to emit "this turn
    /// used calibration delta" audit codes only when there's
    /// a delta to emit.
    public func hasDelta(forStratumKey stratumKey: String) -> Bool {
        bundle.delta(forStratumKey: stratumKey) != nil
    }

    fileprivate static func clamp01(_ value: Double) -> Double {
        if value.isNaN { return 0 }
        return min(1.0, max(0.0, value))
    }
}
