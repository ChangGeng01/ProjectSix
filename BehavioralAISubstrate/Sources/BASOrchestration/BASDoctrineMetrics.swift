// SPDX-License-Identifier: Apache-2.0
// M576 (chapter 一百五十一) — 6 typed doctrine metric value types
// per master plan v1.0 §13.2 "新增 doctrine 指标".
//
// ## Why this exists
//
// User pasted master plan v1.0 (《宿基双生·主权第二大脑平台》) which
// section 13.2 enumerates 6 new doctrine metrics:
//   - Axis Stability Score
//   - Gate Fidelity Score
//   - Origin Trace Completeness
//   - Sanctum Leak Rate
//   - Doctrine Harmony Score
//   - Human Anchor Retention
//
// Repo audit (chapter 一百五十一) found `grep AxisStability|GateFidelity|
// OriginTraceCompleteness|SanctumLeak|DoctrineHarmony|HumanAnchorRetention`
// returns 0 hits across BAS+Qinao sources. **All 6 metrics missing.**
//
// However all SOURCE TYPES the metrics consume are already shipped:
//   - BASAxisAlignment (BASKunlunProtocol.swift:189)        → Axis Stability
//   - BASHeavenGatePermit (BASKunlunProtocol.swift:401)      → Gate Fidelity
//   - BASRiverOriginTrace (BASKunlunProtocol.swift:588)      → Origin Completeness
//   - BASYaochiSanctumEntry (BASKunlunProtocol.swift:516)    → Sanctum Leak
//   - BASAbyssalDoctrineRedLine + BASKunlunDoctrineRedLine   → Doctrine Harmony
//   - BASHumanAnchorSignal (BASAbyssalProtocol.swift:326)    → Anchor Retention
//
// This file ships the 6 typed metric value types + 6 pure-function compute
// helpers that consume the source types. Pure value-type schemas + pure
// functions — zero substrate runtime change. Anti-magic-number doctrine
// applied: all numeric thresholds are named static constants; ratios
// computed not hardcoded; clamping to [0, 1] in init.
//
// ## DAG discipline
//
// Imports `Foundation` only. Conforms to `BASSchemaVersioned` for
// governance registry registration (chapter 一百十四 anti-drift 3-site
// pattern: registry + 2 test files synced same chapter).

import Foundation
import BASRuntimeCore

// MARK: - Anti-magic-number named thresholds

public enum BASDoctrineMetricsThreshold {
    /// Stability index lower bound when no readings exist. Empty-input
    /// edge case — represents "no measurement available" not "perfect
    /// stability".
    public static let emptyInputScore: Double = 0.0

    /// Sanctum leak rate when no entries observed. Empty observation
    /// → 0.0 leak rate (cannot leak what doesn't exist).
    public static let emptySanctumLeakRate: Double = 0.0

    /// Origin trace completeness when no traces observed. Empty
    /// observation → 0.0 completeness (no traces measured).
    public static let emptyOriginCompletenessRatio: Double = 0.0

    /// Schema version pinned across all 6 metric types.
    public static let schemaVersion: String = "1.0.0"
}

// MARK: - 1. Axis Stability Score

/// Plan §13.2 #1 — Axis Stability Score. Measures how aligned target
/// objects (candidates, drafts, tool intents, rule candidates) are with
/// the active Kunlun axis centerline rules across a sample of
/// alignments.
public struct BASAxisStabilityScore:
    BASSchemaVersioned, Sendable, Equatable, Codable
{
    public static let currentSchemaVersion =
        BASDoctrineMetricsThreshold.schemaVersion

    public var schemaVersion: String
    /// Stable identifier for this metric record.
    public var metricID: String
    /// Stable refs to the alignment records this score aggregates.
    public var alignmentRefs: [String]
    /// Total alignment readings in this aggregate.
    public var alignmentReadings: Int
    /// Mean center score in `[0, 1]`. Higher = more aligned.
    public var centerScoreMean: Double
    /// 25th percentile center score in `[0, 1]`.
    public var centerScoreP25: Double
    /// 75th percentile center score in `[0, 1]`.
    public var centerScoreP75: Double
    /// Count of alignments with non-empty `deviationCodes`.
    public var deviationCount: Int
    /// Stability index in `[0, 1]`. Plan §13.2 doesn't specify formula;
    /// we compute `1 - normalizedSpread` where `normalizedSpread =
    /// (p75 - p25)` (clamped). Higher = more consistent.
    public var stabilityIndex: Double

    public init(
        schemaVersion: String =
            BASAxisStabilityScore.currentSchemaVersion,
        metricID: String,
        alignmentRefs: [String],
        alignmentReadings: Int,
        centerScoreMean: Double,
        centerScoreP25: Double,
        centerScoreP75: Double,
        deviationCount: Int,
        stabilityIndex: Double
    ) {
        self.schemaVersion = schemaVersion
        self.metricID = metricID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.alignmentRefs = alignmentRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.alignmentReadings = max(0, alignmentReadings)
        self.centerScoreMean = min(1, max(0, centerScoreMean))
        self.centerScoreP25 = min(1, max(0, centerScoreP25))
        self.centerScoreP75 = min(1, max(0, centerScoreP75))
        self.deviationCount = max(0, deviationCount)
        self.stabilityIndex = min(1, max(0, stabilityIndex))
    }
}

// MARK: - 2. Gate Fidelity Score

/// Plan §13.2 #2 — Gate Fidelity Score. Measures how reliably Kunlun
/// gates (`BASHeavenGatePermit`) pass when axis-aligned and deny when
/// axis-misaligned across a sample of gate transitions.
public struct BASGateFidelityScore:
    BASSchemaVersioned, Sendable, Equatable, Codable
{
    public static let currentSchemaVersion =
        BASDoctrineMetricsThreshold.schemaVersion

    public var schemaVersion: String
    public var metricID: String
    /// Stable refs to gate-permit records this score aggregates.
    public var gateRefs: [String]
    /// Total gate transitions observed.
    public var totalGateRequests: Int
    /// Gates with `passState == .passed`.
    public var gatePassed: Int
    /// Gates with `passState == .denied`.
    public var gateDenied: Int
    /// Gates with `passState == .remanded` (remanded for second check).
    public var gateRemandedForSecondCheck: Int
    /// Fidelity ratio in `[0, 1]`. Computed as fraction of gates whose
    /// `passState ∈ {.passed, .denied}` (decisively resolved) over
    /// total. Higher = more decisive routing.
    public var fidelityRatio: Double

    public init(
        schemaVersion: String =
            BASGateFidelityScore.currentSchemaVersion,
        metricID: String,
        gateRefs: [String],
        totalGateRequests: Int,
        gatePassed: Int,
        gateDenied: Int,
        gateRemandedForSecondCheck: Int,
        fidelityRatio: Double
    ) {
        self.schemaVersion = schemaVersion
        self.metricID = metricID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.gateRefs = gateRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.totalGateRequests = max(0, totalGateRequests)
        self.gatePassed = max(0, gatePassed)
        self.gateDenied = max(0, gateDenied)
        self.gateRemandedForSecondCheck =
            max(0, gateRemandedForSecondCheck)
        self.fidelityRatio = min(1, max(0, fidelityRatio))
    }
}

// MARK: - 3. Origin Trace Completeness

/// Plan §13.2 #3 — Origin Trace Completeness. Measures what fraction of
/// derived objects have full provenance chain (root sources + all
/// transformations + audit refs intact).
public struct BASOriginTraceCompleteness:
    BASSchemaVersioned, Sendable, Equatable, Codable
{
    public static let currentSchemaVersion =
        BASDoctrineMetricsThreshold.schemaVersion

    public var schemaVersion: String
    public var metricID: String
    /// Stable refs to traces this score aggregates.
    public var traceRefs: [String]
    /// Total derived objects observed.
    public var derivedObjectCount: Int
    /// Traces with non-empty `rootSourceRefs` AND non-empty
    /// `auditRefs` AND `transformationSteps.count > 0`.
    public var tracesWithFullProvenance: Int
    /// Traces with empty `rootSourceRefs` (origin missing).
    public var tracesWithMissingRoots: Int
    /// Completeness ratio in `[0, 1]` =
    /// `tracesWithFullProvenance / derivedObjectCount`.
    public var completenessRatio: Double

    public init(
        schemaVersion: String =
            BASOriginTraceCompleteness.currentSchemaVersion,
        metricID: String,
        traceRefs: [String],
        derivedObjectCount: Int,
        tracesWithFullProvenance: Int,
        tracesWithMissingRoots: Int,
        completenessRatio: Double
    ) {
        self.schemaVersion = schemaVersion
        self.metricID = metricID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.traceRefs = traceRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.derivedObjectCount = max(0, derivedObjectCount)
        self.tracesWithFullProvenance =
            max(0, tracesWithFullProvenance)
        self.tracesWithMissingRoots = max(0, tracesWithMissingRoots)
        self.completenessRatio = min(1, max(0, completenessRatio))
    }
}

// MARK: - 4. Sanctum Leak Rate

/// Plan §13.2 #4 — Sanctum Leak Rate. Measures fraction of unauthorized
/// retrieval attempts on Yaochi sanctum entries that succeeded
/// (regardless of subsequent block).
public struct BASSanctumLeakRate:
    BASSchemaVersioned, Sendable, Equatable, Codable
{
    public static let currentSchemaVersion =
        BASDoctrineMetricsThreshold.schemaVersion

    public var schemaVersion: String
    public var metricID: String
    /// Stable refs to sanctum entries this score aggregates.
    public var sanctumRefs: [String]
    /// Total sanctum entries observed.
    public var sanctumEntriesObserved: Int
    /// Total unauthorized retrieval attempts on these entries.
    public var unauthorizedRetrievalAttempts: Int
    /// Of those, count blocked by access policy / human anchor.
    public var unauthorizedRetrievalsBlocked: Int
    /// Leak rate in `[0, 1]` =
    /// `(attempts - blocked) / max(attempts, 1)`. Higher = more leaks.
    /// Empty input → 0.0 (cannot leak what doesn't exist).
    public var leakRate: Double

    public init(
        schemaVersion: String =
            BASSanctumLeakRate.currentSchemaVersion,
        metricID: String,
        sanctumRefs: [String],
        sanctumEntriesObserved: Int,
        unauthorizedRetrievalAttempts: Int,
        unauthorizedRetrievalsBlocked: Int,
        leakRate: Double
    ) {
        self.schemaVersion = schemaVersion
        self.metricID = metricID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.sanctumRefs = sanctumRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.sanctumEntriesObserved =
            max(0, sanctumEntriesObserved)
        self.unauthorizedRetrievalAttempts =
            max(0, unauthorizedRetrievalAttempts)
        self.unauthorizedRetrievalsBlocked =
            max(0, unauthorizedRetrievalsBlocked)
        self.leakRate = min(1, max(0, leakRate))
    }
}

// MARK: - 5. Doctrine Harmony Score

/// Plan §13.2 #5 — Doctrine Harmony Score. Composite metric measuring
/// how well Cthulhu and Kunlun doctrines coexist in observed runtime
/// behavior. Lower red-line hits + zero cross-doctrine conflicts =
/// higher harmony.
public struct BASDoctrineHarmonyScore:
    BASSchemaVersioned, Sendable, Equatable, Codable
{
    public static let currentSchemaVersion =
        BASDoctrineMetricsThreshold.schemaVersion

    public var schemaVersion: String
    public var metricID: String
    /// Cthulhu (深渊) doctrine red-line hit count across sample.
    public var cthulhuRedLineHits: Int
    /// Kunlun (昆仑) doctrine red-line hit count across sample.
    public var kunlunRedLineHits: Int
    /// Conflicts where the two doctrines produced contradictory
    /// rulings on the same target (e.g. Cthulhu RL7 hint vs Kunlun
    /// gate decision disagreement).
    public var crossDoctrineConflicts: Int
    /// Sample size — total observations the score aggregates.
    public var sampleCount: Int
    /// Harmony score in `[0, 1]`. Composite formula:
    /// `1 - ((cthulhu_hits + kunlun_hits + conflicts) / max(sample, 1))`
    /// clamped to [0, 1]. Higher = doctrines coexist cleanly.
    public var harmonyScore: Double

    public init(
        schemaVersion: String =
            BASDoctrineHarmonyScore.currentSchemaVersion,
        metricID: String,
        cthulhuRedLineHits: Int,
        kunlunRedLineHits: Int,
        crossDoctrineConflicts: Int,
        sampleCount: Int,
        harmonyScore: Double
    ) {
        self.schemaVersion = schemaVersion
        self.metricID = metricID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.cthulhuRedLineHits = max(0, cthulhuRedLineHits)
        self.kunlunRedLineHits = max(0, kunlunRedLineHits)
        self.crossDoctrineConflicts =
            max(0, crossDoctrineConflicts)
        self.sampleCount = max(0, sampleCount)
        self.harmonyScore = min(1, max(0, harmonyScore))
    }
}

// MARK: - 6. Human Anchor Retention

/// Plan §13.2 #6 — Human Anchor Retention. Measures fraction of
/// human-anchor signals that preserve host agency across turn
/// boundaries (vs anchor erosion through agency narrowing /
/// alienation / dignity-undermining surfaces).
public struct BASHumanAnchorRetention:
    BASSchemaVersioned, Sendable, Equatable, Codable
{
    public static let currentSchemaVersion =
        BASDoctrineMetricsThreshold.schemaVersion

    public var schemaVersion: String
    public var metricID: String
    /// Stable refs to anchor signals this score aggregates.
    public var anchorRefs: [String]
    /// Total anchor signals observed.
    public var anchorSignalsObserved: Int
    /// Anchors with sustained host agency (all 4 risks
    /// `agencyRisk + alienationRisk + dignityRisk + overwhelmRisk`
    /// stayed below the erosion threshold).
    public var anchorPreservedAcrossTurns: Int
    /// Anchors that crossed the erosion threshold on any axis.
    public var anchorErodedCount: Int
    /// Retention ratio in `[0, 1]` =
    /// `anchorPreservedAcrossTurns / anchorSignalsObserved`.
    public var retentionRatio: Double

    public init(
        schemaVersion: String =
            BASHumanAnchorRetention.currentSchemaVersion,
        metricID: String,
        anchorRefs: [String],
        anchorSignalsObserved: Int,
        anchorPreservedAcrossTurns: Int,
        anchorErodedCount: Int,
        retentionRatio: Double
    ) {
        self.schemaVersion = schemaVersion
        self.metricID = metricID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.anchorRefs = anchorRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.anchorSignalsObserved =
            max(0, anchorSignalsObserved)
        self.anchorPreservedAcrossTurns =
            max(0, anchorPreservedAcrossTurns)
        self.anchorErodedCount = max(0, anchorErodedCount)
        self.retentionRatio = min(1, max(0, retentionRatio))
    }
}

// MARK: - Doctrine red-line detector (M580 chapter 一百五十五)

/// Pure-function detector for Cthulhu / Kunlun doctrine red-line
/// hits in substrate audit signal codes. Replaces chapter 152's
/// naive `contains("forbid:" / ":violation" / "redline:")` detector
/// which matched 0 real substrate signal patterns.
///
/// **Empirical pattern catalog** derived by grep over substrate
/// emission code (`EBrainRuntimeCoordinator+SovereignCommit.swift`):
/// substrate emits typed concern indicators with format
/// `<scope>.<dim>:<value>`. These are doctrine-relevant when the
/// value indicates the concern fired.
public enum BASDoctrineRedLineDetector {

    /// Cthulhu (向下 / 深渊) doctrine RED-LINE markers — substrate
    /// emissions that indicate Cthulhu doctrine red lines actually
    /// triggered (vs routine observability). Empirically calibrated
    /// M580 chapter 一百五十五 + M582 chapter 一百五十七 (defect #20:
    /// pattern mismatch with substrate emission strings).
    ///
    /// Calibration history:
    /// - M580: filtered out `narrative.urgencyMask:` /
    ///   `anomaly.confidence:` / `cthulhu.shift.confidence:` (routine
    ///   substrate observability) AND `forbidden.allHeld:true`
    ///   (normal sovereign-zone state, fires 200/200 sessions).
    /// - M582: corrected `cthulhu.cosmic.dilution:true` →
    ///   `cthulhu.cosmic.dilution:warning` (substrate's actual emit
    ///   string at `EBrainRuntimeCoordinator+SovereignCommit:1319`
    ///   is the constant `:warning`, not `:true`).
    public static let cthulhuConcernPatterns: [String] = [
        "humanAnchor.tone:reserved",           // anchor under stress
        "cthulhu.cosmic.dilution:warning",     // M582 fix — actual emit
        "cthulhu.distortionMap.dominant:true", // dominant distortion
        "abyssal.escalation:",                 // abyssal escalation triggered
        "abyssalBranch.escalation:",           // branch escalation triggered
    ]

    /// Kunlun (向上 / 昆仑) doctrine RED-LINE markers — substrate
    /// emissions that indicate Kunlun doctrine red lines actually
    /// triggered. Empirically calibrated M580 + M582 + M588:
    /// - M580: filtered out `kunlun.axis.deviation:` /
    ///   `kunlun.gate.urgency:` (routine axis observability),
    ///   AND `kunlun.axis.requires-gate:true` (normal axis flow
    ///   signaling, fires 200/200 sessions).
    /// - M582: corrected `kunlun.return.dignityHonored:false` →
    ///   `kunlun.return.dignityHonored:0` (substrate emits the
    ///   COUNT of dignity-honored returns at line 1433, not a
    ///   bool; red-line concern is count = 0, meaning NO return
    ///   step honored dignity).
    /// - M588 (chapter 一百六十): added 3 patterns deep-review
    ///   iteration 2 found in substrate but missing from detector
    ///   (Issue B):
    ///     - `kunlun.tianmen.warrant-missing:high-stakes` (line
    ///       1002 of EBrainRuntimeCoordinator+SovereignCommit;
    ///       red-line: 无授权不进门, high-stakes gate fired without
    ///       sovereign warrant binding)
    ///     - `kunlun.river.lineage:partial` (lines 897-901;
    ///       red-line: 无来源不成玉, lineage analyzer reports not-
    ///       well-formed)
    ///     - `kunlun.river.warnings:` (lines 906-911; lineage
    ///       analyzer surfaces non-empty warning codes)
    public static let kunlunConcernPatterns: [String] = [
        "kunlun.ascent.dignity-violation:",        // ascent dignity violation
        "kunlun.return.dignityHonored:0",          // M582 fix — count=0
        "kunlun.river.cut:true",                   // lineage cut triggered
        "kunlun.jade.defects:",                    // jade defects
        "kunlun.tianmen.denial-well-formed:false", // malformed denial
        "kunlun.tianmen.warrant-missing:",         // M588 — high-stakes gate sans warrant
        "kunlun.river.lineage:partial",            // M588 — lineage not well-formed
        "kunlun.river.warnings:",                  // M588 — lineage warning codes
    ]

    /// Count Cthulhu doctrine red-line hits in a sequence of audit
    /// signalRefs.
    public static func cthulhuHits(
        in signalRefs: [String]
    ) -> Int {
        var count = 0
        for ref in signalRefs {
            for pattern in cthulhuConcernPatterns {
                if ref.hasPrefix(pattern) {
                    count += 1
                    break  // count each ref once across patterns
                }
            }
        }
        return count
    }

    /// Count Kunlun doctrine red-line hits in a sequence of audit
    /// signalRefs.
    public static func kunlunHits(
        in signalRefs: [String]
    ) -> Int {
        var count = 0
        for ref in signalRefs {
            for pattern in kunlunConcernPatterns {
                if ref.hasPrefix(pattern) {
                    count += 1
                    break  // count each ref once across patterns
                }
            }
        }
        return count
    }

    /// Detect cross-doctrine conflicts: Cthulhu hint says "anchor
    /// under stress" (.tone:reserved) but Kunlun gate decision says
    /// no gate needed (.requires-gate:false). Counts ref pairs that
    /// disagree.
    public static func crossDoctrineConflicts(
        in signalRefs: [String]
    ) -> Int {
        let hasAnchorReserved = signalRefs.contains {
            $0.hasPrefix("humanAnchor.tone:reserved")
        }
        let hasGateNotRequired = signalRefs.contains {
            $0.hasPrefix("kunlun.axis.requires-gate:false")
        }
        return (hasAnchorReserved && hasGateNotRequired) ? 1 : 0
    }
}

// MARK: - Pure-function compute helpers

/// Pure-function compute helpers that derive the 6 typed metrics from
/// the BAS source types they observe. Anti-recursion (chapter 一百三十一)
/// — all helpers are iterative arithmetic, no recursion. Empty input
/// → 0.0 score per `emptyInputScore` constant.
public enum BASDoctrineMetricsCompute {

    /// Compute Axis Stability Score from a sample of axis alignment
    /// readings.
    public static func axisStability(
        metricID: String,
        from alignments: [BASAxisAlignment]
    ) -> BASAxisStabilityScore {
        guard !alignments.isEmpty else {
            return BASAxisStabilityScore(
                metricID: metricID,
                alignmentRefs: [],
                alignmentReadings: 0,
                centerScoreMean: 0,
                centerScoreP25: 0,
                centerScoreP75: 0,
                deviationCount: 0,
                stabilityIndex: BASDoctrineMetricsThreshold
                    .emptyInputScore)
        }
        let scores = alignments
            .map(\.centerScore)
            .sorted()
        let n = scores.count
        let mean = scores.reduce(0, +) / Double(n)
        // M590 chapter 一百六十二 — Issue F (deep review iter 5):
        // pre-fix `scores[n / 4]` for n=200 gives index 50 (= 51st
        // element 0-indexed), but the 25th percentile in a sorted
        // sample of 200 is at index Int((n-1) * 0.25) = 49 by the
        // standard nearest-rank percentile formula. Off-by-one.
        // Post-fix: use `Int((n-1) * fraction)` rounding-down which
        // matches the percentile-by-floor convention (also
        // chapter 一百七十九 M179 perf stats convention).
        let p25Index = Int(Double(n - 1) * 0.25)
        let p75Index = Int(Double(n - 1) * 0.75)
        let p25 = scores[max(0, p25Index)]
        let p75 = scores[min(n - 1, p75Index)]
        // M584 (chapter 一百五十七) — defect #21 fix: pre-fix
        // formula was `stability = 1 - (p75 - p25)` (IQR-based).
        // IQR collapses to 0 whenever >50% of scores cluster at
        // one value, even when 23% of turns visit a different
        // centerScore. Empirical: 154/46 split produced mean 0.59
        // (showing variation) but stabilityIndex = 1.0 (false-
        // ceiling). Post-fix: standard-deviation-based formula
        // catches all variation. Std for [0,1]-bounded score is
        // ≤ 0.5 (max at Bernoulli 50/50); 2*std ∈ [0,1] gives a
        // natural [0,1] inverted-stability score.
        let variance = scores.map {
            pow($0 - mean, 2)
        }.reduce(0, +) / Double(n)
        let std = variance.squareRoot()
        let stability = max(0, min(1, 1 - 2 * std))
        let deviationCount = alignments
            .filter { !$0.deviationCodes.isEmpty }
            .count
        return BASAxisStabilityScore(
            metricID: metricID,
            alignmentRefs: alignments.map(\.alignmentID),
            alignmentReadings: n,
            centerScoreMean: mean,
            centerScoreP25: p25,
            centerScoreP75: p75,
            deviationCount: deviationCount,
            stabilityIndex: stability)
    }

    /// Compute Gate Fidelity Score from a sample of Heaven Gate
    /// permit transitions.
    public static func gateFidelity(
        metricID: String,
        from gates: [BASHeavenGatePermit]
    ) -> BASGateFidelityScore {
        let total = gates.count
        guard total > 0 else {
            return BASGateFidelityScore(
                metricID: metricID,
                gateRefs: [],
                totalGateRequests: 0,
                gatePassed: 0,
                gateDenied: 0,
                gateRemandedForSecondCheck: 0,
                fidelityRatio: BASDoctrineMetricsThreshold
                    .emptyInputScore)
        }
        var passed = 0
        var denied = 0
        var remanded = 0
        for g in gates {
            switch g.passState {
            case .passed: passed += 1
            case .denied: denied += 1
            case .remanded: remanded += 1
            case .pending: break
            }
        }
        // M581 chapter 一百五十六 — defect #18 fix:
        // `.remanded` (sovereign-level second-check required) IS a
        // doctrine-correct gate decision per Kunlun §4.3 / RL5
        // ("不能让天门许可绕过宿主授权"). The gate is faithful to its
        // function — it resolved with "needs sovereign confirmation"
        // rather than auto-pass/deny. Pre-M581 formula counted only
        // (passed + denied) → bench saw 0/200 fidelity on real
        // substrate that emitted 200/200 `.remanded` (false-floor).
        // Post-M581: fidelity = resolved / total where resolved
        // includes remanded; only `.pending` (no decision yet)
        // counts as un-faithful.
        let resolved = passed + denied + remanded
        let fidelity = Double(resolved) / Double(total)
        return BASGateFidelityScore(
            metricID: metricID,
            gateRefs: gates.map(\.gateID),
            totalGateRequests: total,
            gatePassed: passed,
            gateDenied: denied,
            gateRemandedForSecondCheck: remanded,
            fidelityRatio: fidelity)
    }

    /// Compute Origin Trace Completeness from a sample of river-origin
    /// traces.
    public static func originTraceCompleteness(
        metricID: String,
        from traces: [BASRiverOriginTrace]
    ) -> BASOriginTraceCompleteness {
        let n = traces.count
        guard n > 0 else {
            return BASOriginTraceCompleteness(
                metricID: metricID,
                traceRefs: [],
                derivedObjectCount: 0,
                tracesWithFullProvenance: 0,
                tracesWithMissingRoots: 0,
                completenessRatio: BASDoctrineMetricsThreshold
                    .emptyOriginCompletenessRatio)
        }
        var full = 0
        var missingRoots = 0
        for t in traces {
            let hasRoots = !t.rootSourceRefs.isEmpty
            let hasAudit = !t.auditRefs.isEmpty
            let hasSteps = !t.transformationSteps.isEmpty
            if hasRoots && hasAudit && hasSteps {
                full += 1
            }
            if !hasRoots {
                missingRoots += 1
            }
            // M587 chapter 一百五十九 — Issue 3 (deep review LOW)
            // disclosure: traces with `hasRoots && (!hasAudit ||
            // !hasSteps)` (partial provenance) are NEITHER counted
            // as full NOR as missingRoots. They contribute to `n`
            // (the divisor) but not to either bucket. Reader
            // invariant `full + missingRoots == n` does NOT hold
            // when partial-provenance traces exist. completenessRatio
            // = full / n correctly downgrades partial traces (they
            // bring the ratio down) but the breakdown fields don't
            // surface them. Future schema bump may add
            // `tracesWithPartialProvenance` to close this gap.
        }
        let ratio = Double(full) / Double(n)
        return BASOriginTraceCompleteness(
            metricID: metricID,
            traceRefs: traces.map(\.traceID),
            derivedObjectCount: n,
            tracesWithFullProvenance: full,
            tracesWithMissingRoots: missingRoots,
            completenessRatio: ratio)
    }

    /// Compute Sanctum Leak Rate from sanctum entries + observed
    /// unauthorized retrieval attempt counts.
    public static func sanctumLeakRate(
        metricID: String,
        from entries: [BASYaochiSanctumEntry],
        unauthorizedAttempts: Int,
        unauthorizedBlocked: Int
    ) -> BASSanctumLeakRate {
        let attempts = max(0, unauthorizedAttempts)
        let blocked = max(0, min(unauthorizedBlocked, attempts))
        let leaked = attempts - blocked
        let observed = entries.count
        let rate: Double
        if observed == 0 || attempts == 0 {
            rate = BASDoctrineMetricsThreshold
                .emptySanctumLeakRate
        } else {
            rate = Double(leaked) / Double(attempts)
        }
        return BASSanctumLeakRate(
            metricID: metricID,
            sanctumRefs: entries.map(\.entryID),
            sanctumEntriesObserved: observed,
            unauthorizedRetrievalAttempts: attempts,
            unauthorizedRetrievalsBlocked: blocked,
            leakRate: rate)
    }

    /// Compute Doctrine Harmony Score from observed Cthulhu + Kunlun
    /// red-line hit counts and cross-doctrine conflict count.
    ///
    /// **M587 chapter 一百五十九 — Issue 2 (deep review MEDIUM) fix**:
    /// pre-fix formula was `1 - (cth + kun + conflicts) / sample`.
    /// Cross-conflict double-counted Cthulhu hits because the same
    /// `humanAnchor.tone:reserved` ref triggers BOTH a Cthulhu hit
    /// (it's in `cthulhuConcernPatterns`) AND contributes to
    /// `crossDoctrineConflicts` if `kunlun.axis.requires-gate:false`
    /// is also present. One observed pattern was penalized twice in
    /// the harmony arithmetic.
    ///
    /// **Post-fix**: harmony numerator is just `cth + kun`. Cross-
    /// conflict is reported separately as additive metadata
    /// (`crossDoctrineConflicts` field) but does NOT double-deduct.
    /// Doctrine intent: harmony measures fraction-of-turns-without-
    /// red-lines. Cross-conflict is a derived diagnostic of doctrine
    /// inconsistency, but the underlying hits are already accounted.
    public static func doctrineHarmony(
        metricID: String,
        cthulhuHits: Int,
        kunlunHits: Int,
        crossConflicts: Int,
        sampleCount: Int
    ) -> BASDoctrineHarmonyScore {
        let cth = max(0, cthulhuHits)
        let kun = max(0, kunlunHits)
        let conflicts = max(0, crossConflicts)
        let sample = max(0, sampleCount)
        let score: Double
        if sample == 0 {
            score = BASDoctrineMetricsThreshold.emptyInputScore
        } else {
            // M587: cross-conflict is reported separately, not
            // included in harmony numerator (avoids double-deduct
            // for same observed pattern).
            let totalHits = Double(cth + kun)
            score = max(0, min(1, 1 - totalHits / Double(sample)))
        }
        return BASDoctrineHarmonyScore(
            metricID: metricID,
            cthulhuRedLineHits: cth,
            kunlunRedLineHits: kun,
            crossDoctrineConflicts: conflicts,
            sampleCount: sample,
            harmonyScore: score)
    }

    /// **M590 chapter 一百六十二 — Concern 2 (deep review iter 5)**:
    /// per-turn doctrine harmony. Pre-fix `doctrineHarmony(...)`
    /// counts hits per-emission: a turn with both cthulhu AND
    /// kunlun red-line emissions deducts 2 from harmony. Doctrine
    /// intent ("fraction of turns without red lines") is per-turn,
    /// not per-emission. Empirical: chapter 160 saw 48 turns each
    /// emit cthulhu.distortionMap.dominant + kunlun.tianmen.warrant-
    /// missing = 96 deductions / 200 = 0.52 harmony. Per-turn
    /// reading: 48 turns with any red line / 200 = 0.24 → harmony
    /// 0.76. Both readings defensible, but per-turn is more
    /// semantically aligned with doctrine intent.
    ///
    /// This helper takes the count of TURNS that had ANY red-line
    /// emission (regardless of pattern class) and the total
    /// turn count. Bench computes the per-turn aggregate by
    /// tracking which turns had at least one detector hit.
    public static func doctrineHarmonyPerTurn(
        metricID: String,
        turnsWithAnyRedLine: Int,
        sampleCount: Int
    ) -> BASDoctrineHarmonyScore {
        let withRedLine = max(0, turnsWithAnyRedLine)
        let sample = max(0, sampleCount)
        let score: Double
        if sample == 0 {
            score = BASDoctrineMetricsThreshold.emptyInputScore
        } else {
            score = max(0, min(1, 1 - Double(withRedLine)
                / Double(sample)))
        }
        // Use cthulhuRedLineHits to carry the per-turn count
        // (back-compat with existing schema). kunlunRedLineHits
        // = 0 indicates per-turn computation mode.
        return BASDoctrineHarmonyScore(
            metricID: metricID,
            cthulhuRedLineHits: withRedLine,
            kunlunRedLineHits: 0,
            crossDoctrineConflicts: 0,
            sampleCount: sample,
            harmonyScore: score)
    }

    /// Default risk-erosion threshold for human anchor retention.
    /// Sum of 4 risk axes (agency / alienation / dignity / overwhelm)
    /// above this value = anchor eroded.
    ///
    /// **Threshold 1.5** = empirically calibrated from chapter 一百
    /// 五十四 real-substrate doctrine bench. Each axis is `[0, 1]`
    /// so sum ∈ `[0, 4]`. Threshold 1.5 (= 37.5% of max) places
    /// the erosion line BETWEEN substrate's two typical
    /// emission-class clusters:
    ///
    /// **Empirical sum distribution from chapter 154 bench (200 sessions)**:
    ///
    /// ```
    /// permit class      typical-sum  classification at 1.5
    /// .delay path       1.050        preserved (substrate cools, host agency intact)
    /// .block path       1.850        eroded (substrate intervened hard)
    /// ```
    ///
    /// **Defect #13 (chapter 一百五十四)**: pre-fix default 1.0 was
    /// too low — chapter 一百五十三 real-substrate run showed all
    /// 200 anchors classified eroded (sum ≥ 1.05 always). First
    /// attempt fixed to 2.0 but that swung to opposite ceiling
    /// (substrate's max in this prompt class is 1.85, never reaches
    /// 2.0).  Empirical calibration via per-iteration sum
    /// distribution capture identified 1.5 as the cleanest
    /// discriminator: 154 delay turns < 1.5 (preserved) and 46
    /// block turns ≥ 1.5 (eroded). Matches doctrine intuition —
    /// "delay preserves agency, block intervenes hard enough to
    /// register as anchor strain".
    public static let humanAnchorErosionThreshold: Double = 1.5

    /// Compute Human Anchor Retention from a sample of anchor signals.
    public static func humanAnchorRetention(
        metricID: String,
        from signals: [BASHumanAnchorSignal],
        erosionThreshold: Double = humanAnchorErosionThreshold
    ) -> BASHumanAnchorRetention {
        let n = signals.count
        guard n > 0 else {
            return BASHumanAnchorRetention(
                metricID: metricID,
                anchorRefs: [],
                anchorSignalsObserved: 0,
                anchorPreservedAcrossTurns: 0,
                anchorErodedCount: 0,
                retentionRatio: BASDoctrineMetricsThreshold
                    .emptyInputScore)
        }
        var preserved = 0
        var eroded = 0
        for s in signals {
            let totalRisk = s.agencyRisk
                + s.alienationRisk
                + s.dignityRisk
                + s.overwhelmRisk
            // Chapter 一百五十四 defect #13b fix: changed `>` to
            // `>=` so substrate's exact-threshold emissions (e.g.
            // block+high+0-overwhelm = sum exactly 2.0 with threshold
            // 2.0) classify as eroded. With strict `>`, those edge
            // cases were incorrectly classified preserved despite
            // max-stress on agency/alienation/dignity axes.
            if totalRisk >= erosionThreshold {
                eroded += 1
            } else {
                preserved += 1
            }
        }
        let ratio = Double(preserved) / Double(n)
        return BASHumanAnchorRetention(
            metricID: metricID,
            anchorRefs: signals.map(\.anchorID),
            anchorSignalsObserved: n,
            anchorPreservedAcrossTurns: preserved,
            anchorErodedCount: eroded,
            retentionRatio: ratio)
    }
}

// MARK: - Percentile summary (M591 chapter 一百六十三)

/// Typed percentile summary for a sample of doubles. Pure value-
/// type produced by `BASDoctrinePercentileSummary.compute(_:)`.
/// Empty input → all percentiles 0.0 + thresholdCounts all 0.
///
/// **M591 chapter 一百六十三**: extracted from main.swift bench
/// (`formatAnchorDistribution` helper) into substrate library so
/// percentile math is unit-testable. Pre-extraction the helper
/// lived in executable target with no `@testable` reach.
public struct BASDoctrinePercentileSummary:
    Sendable, Equatable, Codable
{
    public let sampleCount: Int
    public let min: Double
    public let p25: Double
    public let median: Double
    public let p75: Double
    public let p99: Double
    public let max: Double
    /// Number of samples ≥ each threshold (in order, 1:1 with
    /// `thresholds` input to compute).
    public let thresholdCounts: [Int]
    public init(
        sampleCount: Int, min: Double, p25: Double,
        median: Double, p75: Double, p99: Double,
        max: Double, thresholdCounts: [Int]
    ) {
        self.sampleCount = Swift.max(0, sampleCount)
        self.min = min
        self.p25 = p25
        self.median = median
        self.p75 = p75
        self.p99 = p99
        self.max = max
        self.thresholdCounts = thresholdCounts
    }

    /// Compute typed percentile summary from a sample. Uses
    /// nearest-rank percentile via `Int((n-1) * fraction)` (parity
    /// with M590 chapter 一百六十二 axisStability formula fix).
    /// Empty input → all-zero summary (safe; no crash).
    public static func compute(
        _ samples: [Double],
        thresholds: [Double] = [1.0, 1.5, 2.0]
    ) -> BASDoctrinePercentileSummary {
        guard !samples.isEmpty else {
            return BASDoctrinePercentileSummary(
                sampleCount: 0,
                min: 0, p25: 0, median: 0,
                p75: 0, p99: 0, max: 0,
                thresholdCounts: Array(
                    repeating: 0, count: thresholds.count))
        }
        let sorted = samples.sorted()
        let n = sorted.count
        let safeIdx = { (frac: Double) -> Int in
            Swift.min(n - 1,
                Swift.max(0, Int(Double(n - 1) * frac)))
        }
        let counts = thresholds.map { t in
            samples.filter { $0 >= t }.count
        }
        return BASDoctrinePercentileSummary(
            sampleCount: n,
            min: sorted[0],
            p25: sorted[safeIdx(0.25)],
            median: sorted[safeIdx(0.50)],
            p75: sorted[safeIdx(0.75)],
            p99: sorted[safeIdx(0.99)],
            max: sorted[n - 1],
            thresholdCounts: counts)
    }
}
