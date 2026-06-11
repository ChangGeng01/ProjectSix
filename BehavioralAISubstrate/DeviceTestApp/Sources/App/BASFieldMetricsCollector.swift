// MARK: - BASFieldMetricsCollector — iOS 27 A3 + P7 (IOS27_PERF_ADOPTION_PLAN)
//
// The OS-attested field-evidence stack:MetricKit's iOS-27 Swift
// `MetricManager` delivers daily-aggregated metric/diagnostic reports
// as AsyncSequences — replacing self-reported sampled-max probes with
// the OS's own ground truth for the numbers the program's gates run on:
//
//   - PeakMemoryMetric / SuspendedMemoryMetric — OS high-water marks
//     vs the 3000MB fit budget derived from the measured 3376MB
//     per-process jetsam cap (validate or FALSIFY the budget)。
//   - Background/ForegroundTerminationMetric — ground-truth jetsam
//     counts in the field (memoryPressureExitCount 等)。
//   - MemoryExceptionDiagnostic — per-kill diagnostics。
//
// P7 rides along: `StateReporter` phase transitions (mlx-decode /
// cooldown / consolidation) let MetricKit attribute metrics
// `byStateReportingDomain` — which turn phase drives thermal/memory
// cost on real devices。
//
// PLACEMENT: DeviceTestApp ONLY — `MetricManager`/`StateReporting`
// symbols exist solely in the iOS 27 SDK;the SPM package builds
// under the stable toolchain and must not reference them。
// Observation-only:JSONL to Documents;feeds gate evidence;never
// the spine;gates never auto-promote。

import Foundation
import os
#if canImport(MetricKit)
import MetricKit
#endif
#if canImport(StateReporting)
import StateReporting
#endif

enum BASFieldMetricsCollector {

    private static let log = Logger(
        subsystem: "com.bas.devicetest", category: "field-metrics")

    /// P7 — turn-phase state domain。 Reported transitions show up
    /// in MetricKit reports keyed by this domain。
    static let phaseDomain = "bas.turn.phase"

    #if canImport(StateReporting)
    /// `StateReporter.reporter(for:)` factory with Never metadata
    /// (swiftinterface: Never conforms to ReportableMetadata;both
    /// metadata type params default to Never.self)。
    @available(iOS 27.0, *)
    private static let phaseReporter: StateReporter<Never, Never> =
        .reporter(for: phaseDomain)

    /// Report a turn-phase transition (observation-only)。
    @available(iOS 27.0, *)
    static func reportPhase(_ phase: String) {
        phaseReporter.reportTransition(to: phase)
    }
    #endif

    /// Convenience phase hook callable without availability checks
    /// at call sites (no-ops below iOS 27)。
    static func phase(_ name: String) {
        #if canImport(StateReporting)
        if #available(iOS 27.0, *) { reportPhase(name) }
        #endif
    }

    /// Serialized JSONL writer — audit fix (batch-audit HIGH,
    /// verified): two detached consumers previously raced fresh
    /// per-row FileHandles + an atomic-replace fallback that could
    /// DESTROY the evidence file。 One lock,ONE handle opened once,
    /// append-only。
    private final class JSONLWriter: @unchecked Sendable {
        private let lock = NSLock()
        private let handle: FileHandle?
        init(url: URL) {
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(
                    atPath: url.path, contents: nil)
            }
            handle = try? FileHandle(forWritingTo: url)
            _ = try? handle?.seekToEnd()
        }
        func append(_ row: [String: String]) {
            guard let data = try? JSONSerialization.data(
                withJSONObject: row, options: [.sortedKeys]),
                let line = String(data: data, encoding: .utf8)
            else { return }
            lock.lock(); defer { lock.unlock() }
            try? handle?.write(contentsOf: Data((line + "\n").utf8))
        }
    }

    /// Process-lifetime once guard — audit fix (batch-audit MEDIUM):
    /// start() is called from every run-start tap;without the guard
    /// each tap spawned two MORE never-cancelled consumers ⇒
    /// duplicate JSONL evidence rows。 Lock-guarded box (strict
    /// concurrency forbids bare static var)。
    private final class OnceFlag: @unchecked Sendable {
        private let lock = NSLock()
        private var fired = false
        /// true exactly once (the first caller)。
        func tryFire() -> Bool {
            lock.lock(); defer { lock.unlock() }
            if fired { return false }
            fired = true
            return true
        }
    }
    private static let startOnce = OnceFlag()

    /// Start the AsyncSequence consumers exactly ONCE per process。
    /// Returns immediately;the spawned tasks live for the process。
    /// JSONL lands beside the endurance logs in Documents。
    static func start() {
        #if canImport(MetricKit)
        guard #available(iOS 27.0, *) else {
            log.info("field-metrics: below iOS 27 — collector idle")
            return
        }
        guard startOnce.tryFire() else {
            log.info("field-metrics: already armed — start() is once-per-process")
            return
        }
        let docs = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask).first!
        let writer = JSONLWriter(
            url: docs.appendingPathComponent("field-metrics.jsonl"))
        let manager = MetricManager(
            enabledStateReportingDomains: [
                .init(rawValue: phaseDomain)])
        Task.detached(priority: .utility) {
            for await report in manager.metricReports {
                writer.append(describeMetricReport(report))
            }
        }
        Task.detached(priority: .utility) {
            for await diagnostic in manager.diagnosticReports {
                writer.append(
                    ["kind": "diagnostic",
                     "at": ISO8601DateFormatter().string(from: Date()),
                     "payload": String(describing: diagnostic)])
            }
        }
        log.info("field-metrics: collectors armed → field-metrics.jsonl")
        #endif
    }

    #if canImport(MetricKit)
    /// `MetricReport` is Codable — persist the FULL report (zero
    /// loss, sortedKeys) and surface the gate-relevant headline
    /// fields by pattern-matching `MetricResult` cases。
    @available(iOS 27.0, *)
    private static func describeMetricReport(
        _ report: MetricReport
    ) -> [String: String] {
        var row: [String: String] = [
            "kind": "metrics",
            "at": ISO8601DateFormatter().string(from: Date()),
        ]
        let allValues = report.stateEntries.flatMap(\.values)
            + report.intervalEntries.flatMap(\.values)
        for value in allValues {
            switch value {
            case .peakMemory(let m):
                row["peak_memory"] = String(describing: m.value)
            case .suspendedMemory(let m):
                row["suspended_memory"] = String(describing: m)
            case .backgroundTermination(let m):
                row["bg_termination"] = String(describing: m)
            case .foregroundTermination(let m):
                row["fg_termination"] = String(describing: m)
            default:
                continue
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(report) {
            row["full"] = String(decoding: data, as: UTF8.self)
        }
        return row
    }
    #endif

}
