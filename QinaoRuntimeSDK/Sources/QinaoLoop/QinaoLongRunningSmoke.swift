// SPDX-License-Identifier: Apache-2.0
// M572 (chapter 一百四十七) — Long-running automation runner for
// AFM + open-model smoke benches (the open-model lane historically ran Gemma 4 E2B;
// charter audit 2026-07-12: the public API is now model-neutral — openModel* — the
// endpoint injected by the host decides which family actually runs). Designed to ship measurable
// empirical data across hours of continuous inference, with crash
// resume + per-iteration JSONL output.
//
// ## Why this exists
//
// chapter 一百四十一 (Appendix R) ran 5 prompts × 2 endpoints = 10
// inference calls, capturing per-prompt output but at a sample size
// too small for statistical claims. User instruction "跑个高成本
// AFM + Gemma 冒烟 pretraining 跑 8 小时" requested:
// 1. Continuous 8-hour run on user hardware
// 2. AFM + Gemma both engaged
// 3. Concrete deliverable (results, not just infrastructure)
// 4. Automation FIRST, then run
//
// "Pretraining" in user's phrasing maps onto our doctrine as
// "training-data-generation pretraining" — substrate-decided audit
// code traces ARE the training signal we're collecting (chapter
// 一百三十八 Q.2.4 doctrine path). Real model weight pretraining is
// not feasible on a Mac laptop in 8 hours; what IS feasible is
// generating thousands of (prompt, audit-trail, AFM-output,
// Gemma-output, judge-score) tuples for downstream offline analysis.
//
// ## What this runner does
//
// 1. Loops indefinitely (or to N seconds) over (persona × scenario)
//    prompt catalog, cycling through repetitions
// 2. For each iteration:
//    a) Drive AFM endpoint (if available) → response text
//    b) Drive Gemma endpoint (if available) → response text
//    c) Capture substrate emission proxy (red-line counter on each)
//    d) Optionally drive user-value judge (LLM-as-judge)
//    e) Append one JSONL line per (iteration, endpoint) tuple
// 3. Every checkpointInterval seconds:
//    a) Write progress.json (current iteration, elapsed, ETA)
//    b) Flush any buffered JSONL
// 4. On graceful shutdown (timer or signal):
//    a) Write final summary.json with aggregates
//    b) Exit cleanly
//
// ## Crash resilience
//
// - JSONL files are append-only; partial writes survive crash
// - progress.json updated atomically (write tmp + rename)
// - Resume reads progress.json on startup, skips already-completed
//   iterations
//
// ## DAG discipline
//
// Imports `Foundation` only. Library target so tests can
// `@testable import QinaoLoop`. Endpoint instances are passed in by
// caller (sample-host wires AFM + Gemma).

import Foundation

// MARK: - Configuration

public struct QinaoLongRunningSmokeConfiguration: Sendable {
    /// Total run duration in seconds. Runner stops gracefully
    /// when elapsed >= maxDurationSeconds.
    public let maxDurationSeconds: Int
    /// Output directory for JSONL + progress + summary files.
    /// Will be created if absent.
    public let outputDirectory: URL
    /// How often (seconds) to checkpoint progress + flush JSONL.
    public let checkpointIntervalSeconds: Int
    /// Whether to run AFM endpoint each iteration. If endpoint
    /// is nil at construction, defaults to false.
    public let runAFM: Bool
    /// Whether to run Gemma endpoint each iteration.
    public let runOpenModel: Bool
    /// Whether to run user-value judge each iteration. Slower
    /// (extra LLM call per iteration); default false for high
    /// iteration throughput.
    public let runUserValueJudge: Bool
    /// Per-iteration timeout in seconds. Endpoints exceeding this
    /// are killed and counted as timeouts.
    public let perEndpointTimeoutSeconds: Int

    public init(
        maxDurationSeconds: Int = 8 * 3600,
        outputDirectory: URL,
        checkpointIntervalSeconds: Int = 60,
        runAFM: Bool = true,
        runOpenModel: Bool = true,
        runUserValueJudge: Bool = false,
        perEndpointTimeoutSeconds: Int = 60
    ) {
        self.maxDurationSeconds = maxDurationSeconds
        self.outputDirectory = outputDirectory
        self.checkpointIntervalSeconds = checkpointIntervalSeconds
        self.runAFM = runAFM
        self.runOpenModel = runOpenModel
        self.runUserValueJudge = runUserValueJudge
        self.perEndpointTimeoutSeconds = perEndpointTimeoutSeconds
    }
}

// MARK: - Per-iteration result row

/// One JSONL line — emitted per (iteration × endpoint) tuple.
public struct QinaoLongRunningSmokeRow: Sendable, Codable, Equatable
{
    public let timestamp: String
    public let iteration: Int
    public let persona: String
    public let scenario: String
    public let prompt: String
    public let endpoint: String  // "afm" / "gemma"
    public let responseLength: Int
    public let responseRedLineCount: Int
    public let durationSeconds: Double
    public let status: String  // "ok" / "timeout" / "error"
    public let errorMessage: String?
    public let userValueScore: Int?  // optional judge score 0-100

    public init(
        timestamp: String,
        iteration: Int,
        persona: String,
        scenario: String,
        prompt: String,
        endpoint: String,
        responseLength: Int,
        responseRedLineCount: Int,
        durationSeconds: Double,
        status: String,
        errorMessage: String?,
        userValueScore: Int?
    ) {
        self.timestamp = timestamp
        self.iteration = iteration
        self.persona = persona
        self.scenario = scenario
        self.prompt = prompt
        self.endpoint = endpoint
        self.responseLength = responseLength
        self.responseRedLineCount = responseRedLineCount
        self.durationSeconds = durationSeconds
        self.status = status
        self.errorMessage = errorMessage
        self.userValueScore = userValueScore
    }
}

// MARK: - Progress checkpoint

public struct QinaoLongRunningSmokeProgress: Sendable, Codable {
    public let runStartTimestamp: String
    public let lastCheckpointTimestamp: String
    public let elapsedSeconds: Double
    public let iterationsCompleted: Int
    public let afmCallsCompleted: Int
    public let openModelCallsCompleted: Int
    public let afmTimeouts: Int
    public let openModelTimeouts: Int
    public let afmErrors: Int
    public let openModelErrors: Int
    public let totalRedLineViolationsAFM: Int
    public let totalRedLineViolationsOpenModel: Int

    public init(
        runStartTimestamp: String,
        lastCheckpointTimestamp: String,
        elapsedSeconds: Double,
        iterationsCompleted: Int,
        afmCallsCompleted: Int,
        openModelCallsCompleted: Int,
        afmTimeouts: Int,
        openModelTimeouts: Int,
        afmErrors: Int,
        openModelErrors: Int,
        totalRedLineViolationsAFM: Int,
        totalRedLineViolationsOpenModel: Int
    ) {
        self.runStartTimestamp = runStartTimestamp
        self.lastCheckpointTimestamp = lastCheckpointTimestamp
        self.elapsedSeconds = elapsedSeconds
        self.iterationsCompleted = iterationsCompleted
        self.afmCallsCompleted = afmCallsCompleted
        self.openModelCallsCompleted = openModelCallsCompleted
        self.afmTimeouts = afmTimeouts
        self.openModelTimeouts = openModelTimeouts
        self.afmErrors = afmErrors
        self.openModelErrors = openModelErrors
        self.totalRedLineViolationsAFM = totalRedLineViolationsAFM
        self.totalRedLineViolationsOpenModel = totalRedLineViolationsOpenModel
    }
}

// MARK: - Final summary

public struct QinaoLongRunningSmokeSummary: Sendable, Codable {
    public let runStartTimestamp: String
    public let runEndTimestamp: String
    public let totalElapsedSeconds: Double
    public let totalIterations: Int
    public let afmCallsCompleted: Int
    public let openModelCallsCompleted: Int
    public let afmTimeouts: Int
    public let openModelTimeouts: Int
    public let afmErrors: Int
    public let openModelErrors: Int
    public let totalRedLineViolationsAFM: Int
    public let totalRedLineViolationsOpenModel: Int
    public let avgAFMDurationSeconds: Double
    public let avgOpenModelDurationSeconds: Double
    public let medianAFMDurationSeconds: Double
    public let medianOpenModelDurationSeconds: Double
    public let perPersonaCounts: [String: Int]

    public init(
        runStartTimestamp: String,
        runEndTimestamp: String,
        totalElapsedSeconds: Double,
        totalIterations: Int,
        afmCallsCompleted: Int,
        openModelCallsCompleted: Int,
        afmTimeouts: Int,
        openModelTimeouts: Int,
        afmErrors: Int,
        openModelErrors: Int,
        totalRedLineViolationsAFM: Int,
        totalRedLineViolationsOpenModel: Int,
        avgAFMDurationSeconds: Double,
        avgOpenModelDurationSeconds: Double,
        medianAFMDurationSeconds: Double,
        medianOpenModelDurationSeconds: Double,
        perPersonaCounts: [String: Int]
    ) {
        self.runStartTimestamp = runStartTimestamp
        self.runEndTimestamp = runEndTimestamp
        self.totalElapsedSeconds = totalElapsedSeconds
        self.totalIterations = totalIterations
        self.afmCallsCompleted = afmCallsCompleted
        self.openModelCallsCompleted = openModelCallsCompleted
        self.afmTimeouts = afmTimeouts
        self.openModelTimeouts = openModelTimeouts
        self.afmErrors = afmErrors
        self.openModelErrors = openModelErrors
        self.totalRedLineViolationsAFM = totalRedLineViolationsAFM
        self.totalRedLineViolationsOpenModel = totalRedLineViolationsOpenModel
        self.avgAFMDurationSeconds = avgAFMDurationSeconds
        self.avgOpenModelDurationSeconds = avgOpenModelDurationSeconds
        self.medianAFMDurationSeconds = medianAFMDurationSeconds
        self.medianOpenModelDurationSeconds = medianOpenModelDurationSeconds
        self.perPersonaCounts = perPersonaCounts
    }
}

// MARK: - Helper utilities (pure functions, easy to unit-test)

public enum QinaoLongRunningSmokeHelpers {
    /// ISO 8601 timestamp string for a Date.
    public static func iso8601(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }

    /// Round-trip Codable encode helper. JSON Codable.
    public static func jsonLine<T: Codable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    /// Median of an array of doubles. Empty → 0.
    public static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        if sorted.count % 2 == 0 {
            let lo = sorted[sorted.count / 2 - 1]
            let hi = sorted[sorted.count / 2]
            return (lo + hi) / 2
        }
        return sorted[sorted.count / 2]
    }

    /// Average of an array of doubles. Empty → 0.
    public static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Build a progress snapshot from current counters + start
    /// time + a "now" Date.
    public static func makeProgress(
        runStart: Date,
        now: Date,
        iterations: Int,
        afmCompleted: Int,
        openModelCompleted: Int,
        afmTimeouts: Int,
        openModelTimeouts: Int,
        afmErrors: Int,
        openModelErrors: Int,
        afmRedLineTotal: Int,
        openModelRedLineTotal: Int
    ) -> QinaoLongRunningSmokeProgress {
        QinaoLongRunningSmokeProgress(
            runStartTimestamp: iso8601(runStart),
            lastCheckpointTimestamp: iso8601(now),
            elapsedSeconds: now.timeIntervalSince(runStart),
            iterationsCompleted: iterations,
            afmCallsCompleted: afmCompleted,
            openModelCallsCompleted: openModelCompleted,
            afmTimeouts: afmTimeouts,
            openModelTimeouts: openModelTimeouts,
            afmErrors: afmErrors,
            openModelErrors: openModelErrors,
            totalRedLineViolationsAFM: afmRedLineTotal,
            totalRedLineViolationsOpenModel: openModelRedLineTotal)
    }

    /// Build per-persona counts map from a sequence of (persona,
    /// count) pairs. Pure function for testability.
    public static func aggregatePerPersonaCounts(
        rows: [(persona: String, count: Int)]
    ) -> [String: Int] {
        var result: [String: Int] = [:]
        for entry in rows {
            result[entry.persona, default: 0] += entry.count
        }
        return result
    }
}

// MARK: - File I/O (for production runner)

public actor QinaoLongRunningSmokeWriter {
    private let outputDirectory: URL
    private var jsonlHandle: FileHandle?

    public init(outputDirectory: URL) {
        self.outputDirectory = outputDirectory
    }

    public func ensureDirectory() throws {
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true)
    }

    public func appendRow(
        _ row: QinaoLongRunningSmokeRow,
        filename: String = "iterations.jsonl"
    ) async throws {
        try ensureDirectory()
        let url = outputDirectory.appendingPathComponent(filename)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(
                atPath: url.path, contents: nil)
        }
        let line = try QinaoLongRunningSmokeHelpers.jsonLine(row) + "\n"
        guard let data = line.data(using: .utf8) else { return }
        if jsonlHandle == nil {
            jsonlHandle = try FileHandle(forWritingTo: url)
            try jsonlHandle?.seekToEnd()
        }
        try jsonlHandle?.write(contentsOf: data)
    }

    public func writeProgress(
        _ progress: QinaoLongRunningSmokeProgress
    ) async throws {
        try ensureDirectory()
        let url = outputDirectory.appendingPathComponent(
            "progress.json")
        let tmp = outputDirectory.appendingPathComponent(
            "progress.json.tmp")
        let line = try QinaoLongRunningSmokeHelpers.jsonLine(progress)
        try line.write(to: tmp, atomically: true, encoding: .utf8)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: tmp, to: url)
    }

    public func writeSummary(
        _ summary: QinaoLongRunningSmokeSummary
    ) async throws {
        try ensureDirectory()
        let url = outputDirectory.appendingPathComponent(
            "summary.json")
        let line = try QinaoLongRunningSmokeHelpers.jsonLine(summary)
        try line.write(to: url, atomically: true, encoding: .utf8)
    }

    public func flush() async throws {
        try jsonlHandle?.synchronize()
    }

    public func close() async throws {
        try jsonlHandle?.close()
        jsonlHandle = nil
    }
}
