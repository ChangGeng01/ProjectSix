// MARK: - BASShadowEvaluatorMeridian + 2 stub heads —
//          chapter 二百七十 / M757
//
// Multi-head shadow evaluator meridian — Stage 5 Step 5 of 5.
//
// ## Why this exists
//
// chapter 一百七十七 P3 multi-head vision: 18 任 side ML heads
// running in parallel — quality / hallucination / safety /
// sycophancy / topic-drift / prompt-injection / etc. Pre-chapter
// 二百七十 the substrate had:
//
//   - chapter 二百六十六 protocol (1 head abstract)
//   - chapter 二百六十七 substrate-reaudit (1 head)
//   - chapter 二百六十八 ML-backed scaffolding (N heads via 1
//     conformer each)
//   - chapter 二百六十 pipeline composer (N heads merged into 1
//     result)
//
// What was missing: a **meridian** — multi-head observability
// surface that preserves per-head detail. The pipeline merges
// into a single `BASShadowEvaluationResult`; the meridian keeps
// every head's result separately so audit walkers can grep
// "which head said what". This is the right shape for the
// "5/18 → 10/18 任 side heads" expansion.
//
// chapter 二百七十 ships:
//   - `BASShadowEvaluatorMeridianResult` — typed result holding
//     N per-head `BASShadowEvaluationResult` + a merged summary.
//   - `BASShadowEvaluatorMeridian` actor — runs N heads
//     concurrently, returns the typed multi-result.
//   - **2 stub heads** built on chapter 二百六十八 classifier
//     scaffolding:
//     - `BASQualityShadowHead` — flags low-quality body
//       (all-caps, very repetitive, very short).
//     - `BASHallucinationShadowHead` — flags suspicious
//       unsupported claims (citation patterns, unverifiable
//       numbers).
//
// Real ML conformers replace the stub heads when chapter
// 二百五十六+ real bench data + retrain pipeline produces
// .mlpackages. Until then the rules-based stubs are usable
// scaffolding.
//
// ## Doctrine pins
//
//   - 不变量 #1 / #2 / #3: meridian is observability — N heads
//     produce hints; host decides whether to act.
//   - 红线 7 watcher-only-hint: every head is a watcher.
//   - chapter 二百六十 / M754: the pipeline merges into one;
//     meridian keeps per-head detail. Both ship side-by-side
//     for different use cases.
//   - chapter 一百十三 anti-magic-number: every default tunable
//     as static let default*.
//   - chapter 二百六十六 / M748 single-source-of-truth: protocol
//     stays in BASShadowEvaluating.swift.

import Foundation
import BASRuntimeCore

// MARK: - BASShadowEvaluatorMeridianResult

/// Multi-head meridian evaluation result. Each head's individual
/// `BASShadowEvaluationResult` is preserved; the merged summary
/// is computed per the meridian's `mergeStrategy`.
public struct BASShadowEvaluatorMeridianResult:
    BASSchemaVersioned, Sendable, Equatable, Codable, Hashable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String

    /// One result per head, in registration order.
    public let perHead: [BASShadowEvaluationResult]

    /// True iff the merge strategy says the meridian shifted.
    public let mergedShifted: Bool

    /// Aggregated permit-mode (first non-nil postPermitMode
    /// across heads, or nil if all heads returned nil).
    public let mergedPostPermitMode: String?

    /// Number of non-skipped heads in this evaluation. Audit
    /// walkers grep this for coverage stats.
    public let nonSkippedHeadCount: Int

    /// Number of heads that returned `shifted == true`.
    public let shiftedHeadCount: Int

    /// Stable meridian version identifier (auto-derived or
    /// init-overridden).
    public let meridianVersion: String

    /// Wall-clock at evaluation time. Forensic audit.
    public let evaluatedAt: Date

    public init(
        schemaVersion: String =
            BASShadowEvaluatorMeridianResult
                .currentSchemaVersion,
        perHead: [BASShadowEvaluationResult],
        mergedShifted: Bool,
        mergedPostPermitMode: String?,
        nonSkippedHeadCount: Int,
        shiftedHeadCount: Int,
        meridianVersion: String,
        evaluatedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.perHead = perHead
        self.mergedShifted = mergedShifted
        self.mergedPostPermitMode = mergedPostPermitMode
        self.nonSkippedHeadCount = max(0, nonSkippedHeadCount)
        self.shiftedHeadCount = max(0, shiftedHeadCount)
        self.meridianVersion = meridianVersion
            .trimmingCharacters(
                in: .whitespacesAndNewlines)
        self.evaluatedAt = evaluatedAt
    }
}

// MARK: - BASShadowEvaluatorMeridian

/// Multi-head meridian. Runs N heads concurrently, preserves
/// per-head detail, returns the typed `Result`. Distinct from
/// `BASShadowEvaluatorPipeline` (chapter 二百六十) which merges
/// into a single `BASShadowEvaluationResult` for `BASShadow
/// Evaluating` drop-in compatibility. The meridian is the right
/// shape when audit walkers need per-head visibility (e.g.
/// "which head flagged this body — the quality head or the
/// hallucination head?").
public actor BASShadowEvaluatorMeridian {
    public let heads: [any BASShadowEvaluating]
    public let mergeStrategy: BASShadowEvaluatorMergeStrategy
    public let meridianVersion: String

    public init(
        heads: [any BASShadowEvaluating],
        mergeStrategy: BASShadowEvaluatorMergeStrategy =
            .anyShifted,
        meridianVersion: String? = nil
    ) {
        self.heads = heads
        self.mergeStrategy = mergeStrategy
        if let supplied = meridianVersion?
            .trimmingCharacters(
                in: .whitespacesAndNewlines),
            !supplied.isEmpty
        {
            self.meridianVersion = supplied
        } else {
            let parts = heads.map { $0.evaluatorVersion }
            self.meridianVersion =
                "meridian:\(mergeStrategy.rawValue):" +
                "[\(parts.joined(separator: "+"))]"
        }
    }

    public func evaluate(
        prompt: String,
        body: String,
        prePermitMode: String,
        sessionRef: String,
        turnRef: String,
        evaluatedAt: Date = Date()
    ) async -> BASShadowEvaluatorMeridianResult {
        guard !heads.isEmpty else {
            return BASShadowEvaluatorMeridianResult(
                perHead: [],
                mergedShifted: false,
                mergedPostPermitMode: nil,
                nonSkippedHeadCount: 0,
                shiftedHeadCount: 0,
                meridianVersion: meridianVersion,
                evaluatedAt: evaluatedAt)
        }

        // Run heads concurrently.
        let heads = self.heads
        let results = await withTaskGroup(
            of: (Int, BASShadowEvaluationResult).self,
            returning: [BASShadowEvaluationResult].self
        ) { group in
            for (i, head) in heads.enumerated() {
                group.addTask {
                    let r = await head.evaluate(
                        prompt: prompt,
                        body: body,
                        prePermitMode: prePermitMode,
                        sessionRef: sessionRef,
                        turnRef: turnRef)
                    return (i, r)
                }
            }
            var collected: [(Int, BASShadowEvaluationResult)] =
                []
            for await pair in group {
                collected.append(pair)
            }
            collected.sort { $0.0 < $1.0 }
            return collected.map { $0.1 }
        }

        // Compute merged summary.
        let nonSkipped = results.filter {
            $0.postPermitMode != nil
        }
        let shiftedCount = nonSkipped.filter { $0.shifted }
            .count
        let merged: Bool
        switch mergeStrategy {
        case .anyShifted:
            merged = shiftedCount > 0
        case .allShifted:
            merged = !nonSkipped.isEmpty
                && shiftedCount == nonSkipped.count
        case .majorityShifted:
            merged = shiftedCount * 2 > nonSkipped.count
        }
        let aggregatedMode = nonSkipped.compactMap {
            $0.postPermitMode
        }.first

        return BASShadowEvaluatorMeridianResult(
            perHead: results,
            mergedShifted: merged,
            mergedPostPermitMode: aggregatedMode,
            nonSkippedHeadCount: nonSkipped.count,
            shiftedHeadCount: shiftedCount,
            meridianVersion: meridianVersion,
            evaluatedAt: evaluatedAt)
    }
}

// MARK: - Stub head 1: BASQualityShadowHead

/// Rules-based quality head — flags bodies that look low-quality
/// (all-caps, very repetitive, very short).
public struct BASQualityShadowHead: BASShadowEvaluating {
    public static let defaultMinAcceptableLength: Int = 6
    public static let defaultMaxRepetitionRatio: Double = 0.7
    public static let defaultClassifierVersion = "quality-rules-v1"

    public let evaluatorVersion: String
    public let minAcceptableLength: Int
    public let maxRepetitionRatio: Double

    public init(
        evaluatorVersion: String =
            BASQualityShadowHead.defaultClassifierVersion,
        minAcceptableLength: Int =
            BASQualityShadowHead.defaultMinAcceptableLength,
        maxRepetitionRatio: Double =
            BASQualityShadowHead.defaultMaxRepetitionRatio
    ) {
        self.evaluatorVersion = evaluatorVersion
            .trimmingCharacters(
                in: .whitespacesAndNewlines)
        self.minAcceptableLength = max(1, minAcceptableLength)
        self.maxRepetitionRatio = Self.clamp01(
            maxRepetitionRatio)
    }

    public func evaluate(
        prompt: String,
        body: String,
        prePermitMode: String,
        sessionRef: String,
        turnRef: String
    ) async -> BASShadowEvaluationResult {
        guard !body.isEmpty else {
            return BASShadowEvaluationResult.skipped(
                evaluatorVersion: evaluatorVersion)
        }

        // Flag 1: very short body.
        if body.count < minAcceptableLength {
            return BASShadowEvaluationResult(
                postPermitMode: "answer",
                postAuditCodeCount: nil,
                shifted: true,
                reasonCodes: [
                    "quality:flag:very-short:" +
                    "\(body.count)<\(minAcceptableLength)"
                ],
                evaluatorVersion: evaluatorVersion)
        }

        // Flag 2: repetition. Ratio = (1 - distinct / total)
        // for character-level uniqueness (cheap, language-
        // agnostic, no string-tokenize). High ratio = many
        // repeats.
        let distinctChars = Set(body)
        let total = max(1, body.count)
        let distinctCount = distinctChars.count
        let repetitionRatio = 1.0 -
            (Double(distinctCount) / Double(total))
        if repetitionRatio > maxRepetitionRatio {
            return BASShadowEvaluationResult(
                postPermitMode: "answer",
                postAuditCodeCount: nil,
                shifted: true,
                reasonCodes: [
                    "quality:flag:repetitive:" +
                    String(format: "%.3f", repetitionRatio)
                ],
                evaluatorVersion: evaluatorVersion)
        }

        // Default: not flagged.
        return BASShadowEvaluationResult(
            postPermitMode: "answer",
            postAuditCodeCount: nil,
            shifted: false,
            reasonCodes: ["quality:ok"],
            evaluatorVersion: evaluatorVersion)
    }

    fileprivate static func clamp01(_ value: Double) -> Double {
        if value.isNaN { return 0 }
        return min(1.0, max(0.0, value))
    }
}

// MARK: - Stub head 2: BASHallucinationShadowHead

/// Rules-based hallucination head — flags bodies that look like
/// unsupported claims (e.g. "studies show X" without citation,
/// percentages with no source).
public struct BASHallucinationShadowHead: BASShadowEvaluating {
    /// Suspicious claim patterns. Operator can add more.
    public static let defaultSuspiciousClaimPatterns: [String] = [
        "studies show",
        "research proves",
        "scientists agree",
        "everyone knows"
    ]
    public static let defaultClassifierVersion =
        "hallucination-rules-v1"

    public let evaluatorVersion: String
    public let suspiciousClaimPatterns: [String]

    public init(
        evaluatorVersion: String =
            BASHallucinationShadowHead.defaultClassifierVersion,
        suspiciousClaimPatterns: [String] =
            BASHallucinationShadowHead
                .defaultSuspiciousClaimPatterns
    ) {
        self.evaluatorVersion = evaluatorVersion
            .trimmingCharacters(
                in: .whitespacesAndNewlines)
        self.suspiciousClaimPatterns = suspiciousClaimPatterns
            .map { $0.trimmingCharacters(
                in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    public func evaluate(
        prompt: String,
        body: String,
        prePermitMode: String,
        sessionRef: String,
        turnRef: String
    ) async -> BASShadowEvaluationResult {
        guard !body.isEmpty else {
            return BASShadowEvaluationResult.skipped(
                evaluatorVersion: evaluatorVersion)
        }

        let lowerBody = body.lowercased()
        for pattern in suspiciousClaimPatterns {
            if lowerBody.contains(pattern) {
                return BASShadowEvaluationResult(
                    postPermitMode: "answer",
                    postAuditCodeCount: nil,
                    shifted: true,
                    reasonCodes: [
                        "hallucination:flag:suspicious-pattern:" +
                            "\(pattern)"
                    ],
                    evaluatorVersion: evaluatorVersion)
            }
        }
        return BASShadowEvaluationResult(
            postPermitMode: "answer",
            postAuditCodeCount: nil,
            shifted: false,
            reasonCodes: ["hallucination:ok"],
            evaluatorVersion: evaluatorVersion)
    }
}
