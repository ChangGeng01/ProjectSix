// MARK: - BASEvalRun — chapter 三百七四 / M861
//
// C2 Auto eval harness primitive #2: Codable bundle that records
// the metrics scored by ONE eval run。Hosts persist these across
// builds + feed pairs into `BASEvalRegressionDetector` to detect
// improvement / regression / no-change per metric。
//
// ## What this ships
//
//   - `BASEvalRun` — Codable, Sendable, Equatable typed bundle:
//     runID / timestamp / metrics: [BASEvalMetric: Double] /
//     buildChapter / hostFingerprint / sampleCount
//   - Convenience initializers + queries
//
// ## Doctrine pins
//
// - 不变量 #1 / #2 / #3 全保 — eval run is observation only,
//   never mutates permits / verdicts / commit token
// - 红线 7 hint-only — runs feed regression detector;the
//   detector's verdict is HINT only,L11 gate decides
// - chapter 一百八十五 — sample-count-zero default,no magic
//   numbers in metric values (host always supplies)
// - chapter 二百一一 — ONE bundle type for all eval runs
// - ADR-014 OPT-IN → PROD — primitive only,host populates
// - DAG — BASRuntimeCore leaf,Foundation only

import Foundation

// MARK: - BASEvalRun

/// Codable bundle holding the metrics scored by ONE eval run。
/// Hosts construct one per build + persist (e.g. JSON to disk or
/// to the audit ledger),then feed pairs into
/// `BASEvalRegressionDetector` for regression hints。
///
/// All fields are typed:
///   - `runID` is caller-supplied (e.g. UUID + build chapter)
///   - `timestampMs` is epoch milliseconds (matches event log
///     idiom from M841)
///   - `metrics` is keyed by `BASEvalMetric` (typed enum,not
///     free-form string)
///   - `buildChapter` is the chapter manifest (e.g. "M861")
///   - `hostFingerprint` is host-supplied opaque tag
///     (device model + OS version + thermal class)
///   - `sampleCount` is the eval set size at run time
public struct BASEvalRun: Sendable, Equatable, Codable, Hashable {

    /// Caller-supplied stable identifier。Conventionally
    /// `UUID().uuidString` but any host-stable string works。
    public let runID: String

    /// Epoch milliseconds when the run completed。Matches M841
    /// event log timestamp idiom for cross-correlation。
    public let timestampMs: Int64

    /// Metric dimensions scored by this run。Keyed by typed
    /// `BASEvalMetric`;value semantics defined by the enum case
    /// (e.g. `.accuracy` is 0…1, `.latencyP95` is milliseconds)。
    ///
    /// **Encoding note**: Swift dictionaries with non-string keys
    /// encode as JSON arrays。To preserve human-readability,this
    /// type uses a custom Codable that encodes `metrics` as a
    /// keyed JSON object using each metric's `rawValue`。
    public let metrics: [BASEvalMetric: Double]

    /// Chapter / commit manifest that produced this build
    /// (e.g. "M861" or "chapter-三百七四")。Free-form but
    /// host-stable for cross-run correlation。
    public let buildChapter: String

    /// Opaque host fingerprint (typically device model + OS
    /// version + thermal class)。Used by future eval harness to
    /// segment runs by environment。
    public let hostFingerprint: String

    /// Number of eval samples this run scored。Zero is permitted
    /// (empty run sentinel) — the regression detector treats
    /// zero-sample runs as `noChange` to avoid false signals。
    public let sampleCount: Int

    public init(
        runID: String,
        timestampMs: Int64,
        metrics: [BASEvalMetric: Double],
        buildChapter: String,
        hostFingerprint: String,
        sampleCount: Int
    ) {
        self.runID = runID
        self.timestampMs = timestampMs
        self.metrics = metrics
        self.buildChapter = buildChapter
        self.hostFingerprint = hostFingerprint
        self.sampleCount = sampleCount
    }

    /// Empty run sentinel: zero sample count,no metrics。Used as
    /// baseline when no prior run exists (regression detector
    /// returns `noChange` against it)。
    public static func empty(
        runID: String = "empty",
        buildChapter: String = "none",
        hostFingerprint: String = "none"
    ) -> BASEvalRun {
        BASEvalRun(
            runID: runID,
            timestampMs: 0,
            metrics: [:],
            buildChapter: buildChapter,
            hostFingerprint: hostFingerprint,
            sampleCount: 0)
    }

    /// Convenience: was this run effectively empty?
    public var isEmpty: Bool {
        sampleCount == 0 || metrics.isEmpty
    }

    /// Convenience: lookup a metric value with explicit
    /// "missing" handling (returns nil rather than throwing)。
    public func value(
        for metric: BASEvalMetric
    ) -> Double? {
        metrics[metric]
    }

    // MARK: - Codable

    /// Custom Codable preserves human-readability:
    /// metrics encode as a JSON object keyed by
    /// `BASEvalMetric.rawValue`。
    private enum CodingKeys: String, CodingKey {
        case runID
        case timestampMs
        case metrics
        case buildChapter
        case hostFingerprint
        case sampleCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self)
        self.runID = try container.decode(
            String.self, forKey: .runID)
        self.timestampMs = try container.decode(
            Int64.self, forKey: .timestampMs)
        self.buildChapter = try container.decode(
            String.self, forKey: .buildChapter)
        self.hostFingerprint = try container.decode(
            String.self, forKey: .hostFingerprint)
        self.sampleCount = try container.decode(
            Int.self, forKey: .sampleCount)

        // Decode metrics as [String: Double], remap to typed key
        let stringKeyed = try container.decode(
            [String: Double].self, forKey: .metrics)
        var typed: [BASEvalMetric: Double] = [:]
        for (key, value) in stringKeyed {
            // Unknown metric raw values are silently dropped — a
            // forward-compat pin: if a future host adds a metric,
            // older readers don't crash on the unknown raw value
            if let metric = BASEvalMetric(rawValue: key) {
                typed[metric] = value
            }
        }
        self.metrics = typed
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(
            keyedBy: CodingKeys.self)
        try container.encode(runID, forKey: .runID)
        try container.encode(
            timestampMs, forKey: .timestampMs)
        try container.encode(
            buildChapter, forKey: .buildChapter)
        try container.encode(
            hostFingerprint, forKey: .hostFingerprint)
        try container.encode(
            sampleCount, forKey: .sampleCount)

        // Re-key dictionary to [String: Double]
        var stringKeyed: [String: Double] = [:]
        for (metric, value) in metrics {
            stringKeyed[metric.rawValue] = value
        }
        try container.encode(stringKeyed, forKey: .metrics)
    }
}
