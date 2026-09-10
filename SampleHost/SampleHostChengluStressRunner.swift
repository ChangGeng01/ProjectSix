// MARK: - SampleHostChengluStressRunner — chapter 三百三九 / M826
//                                       + chapter 三百四九 / M836
//                                       + chapter 三百七五 / M862
//
// iPhone-side sustained stress runner for the附录 X Chenglu mesh
// chain。Mirrors `BASChenglu20MinStressTests` (chapter 三百三八)
// but loads `.mlmodelc` files via Bundle.main instead of env var
// paths,and exposes incremental progress via `@Published` props
// for the SwiftUI panel。
//
// Closes v9 §8 non-promise #4 (production deployment validation)
// for opt-in real-iPhone testing。
//
// **Chapter 三百四九 / M836**: persist final run result as JSON
// to `Documents/chenglu-stress-runs/` so the data survives after
// the in-memory `@Published` state goes away (panel dismiss /
// app background)。Two files written per run:
//   - `latest.json` — overwritten each run for easy retrieval
//   - `run-<ISO timestamp>.json` — append-only history
//
// Retrieval pattern (from a Mac with the device paired):
//   xcrun devicectl device copy from \
//     --device <UDID> \
//     --domain-type appDataContainer \
//     --domain-identifier com.changgeng.samplehost \
//     --source Documents/chenglu-stress-runs/latest.json \
//     --destination /tmp/latest.json
//
// **Chapter 三百七五 / M862**: opt-in cognitive OS integration via
// `SampleHostChengluStressCognitiveOSObserver`。Default
// `.allDisabled` options preserve M826 / M837 behavior pin (zero
// behavior change)。When opted in, observer appends one event log
// entry per iter, folds state every 100 iter, extracts knowledge
// graph every 1000 iter — exercises the full G1/G2/G9 data loop
// in a real iPhone code path。

import CoreML
import Foundation
import BASHostKit
import BASAppleAdapters   // charter T4: MLModel-bound Chenglu types (RegistrationOptions)
import BASAppleEdgeWiring  // charter T4: build(configuration:chengluModels:) overload
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class SampleHostChengluStressRunner: ObservableObject {

    // MARK: - Published state for UI

    enum Status: Equatable {
        case idle
        case loadingModels
        case running
        case finished
        case error(String)
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var iterations: Int = 0
    @Published private(set) var failures: Int = 0
    @Published private(set) var determinismMismatches: Int = 0
    @Published private(set) var elapsedSeconds: Double = 0
    @Published private(set) var throughput: Double = 0
    @Published private(set) var recentAvgMs: Double = 0
    @Published private(set) var p50Ms: Double = 0
    @Published private(set) var p95Ms: Double = 0
    @Published private(set) var p99Ms: Double = 0
    @Published private(set) var statusLine: String = "Idle"
    @Published private(set) var progressLog: [String] = []

    /// Chapter 三百四九 / M836: relative file path under app's
    /// Documents directory where the most recent finished run was
    /// persisted。`nil` until at least one run has finished。
    @Published private(set) var lastSavedRelativePath: String?

    /// Chapter 三百七五 / M862: cognitive OS observer stats。Zero
    /// when observer is disabled (default M826 / M837 behavior pin)。
    @Published private(set) var cognitiveOSEnabled: Bool = false
    @Published private(set) var cognitiveOSEventCount: Int = 0
    @Published private(set) var cognitiveOSStateCount: Int = 0
    @Published private(set) var cognitiveOSGraphNodeCount: Int = 0
    @Published private(set) var cognitiveOSGraphEdgeCount: Int = 0

    /// Chapter 三百九九 / M905:thermal-aware cadence telemetry。
    /// Surfaces policy + counters to the panel so the user can
    /// SEE during a 1h+ run that thermal pressure is being
    /// throttled。Pre-M905 panels never showed thermal effect。
    /// Empty string (instead of nil) when observer is disabled,
    /// matching the @Published-default-value pattern of the
    /// other cognitiveOS* fields above。
    @Published private(set) var
        cognitiveOSThermalSensitivity: String = ""
    @Published private(set) var
        cognitiveOSThermalSkippedExtracts: Int = 0
    @Published private(set) var
        cognitiveOSThermalSlowedExtracts: Int = 0

    private var stressTask: Task<Void, Never>?

    // MARK: - Doctrine constants

    private enum Constants {
        /// Default duration in seconds (20 min)。User-overridable
        /// via UI for shorter smoke runs。
        static let defaultDurationSeconds: Double = 1200

        /// Log progress every N iterations。
        static let progressLogInterval: Int = 100

        /// Re-verify determinism baseline every N iterations。
        static let determinismCheckInterval: Int = 1000

        /// Chapter 三百九九 / M909:duration threshold (seconds)
        /// above which the runner auto-selects `.slowOnHot` for
        /// the cognitive OS observer。Pre-M909 this was hardcoded
        /// at 3600 (1h),which excluded 30-45 min runs that
        /// experience the same thermal envelope。Post-M909 the
        /// threshold is the same as `defaultDurationSeconds`(1200,
        /// 20 min)— iPhone 17e thermal envelope onset is
        /// typically 10-15 min,so any run >= the default
        /// duration benefits from `.slowOnHot`。Hosts that want
        /// a different threshold can fork this constant。
        static let thermalAutoSensitivityThresholdSec: Double =
            1200

        /// Chapter 三百五〇 / M837: persist a checkpoint every
        /// N seconds wall-clock during a run so a crash mid-8h
        /// doesn't lose all data。
        static let checkpointPersistIntervalSec: Double = 60

        /// Chapter 三百五〇 / M837: capture per-minute throughput
        /// + p99 sample for drift detection over long runs。
        static let timeSeriesIntervalSec: Double = 60

        /// Chapter 三百五〇 / M837: ring buffer size for
        /// `recentAvgMs` window。
        static let recentLatencyWindow: Int = 100
    }

    // MARK: - Public API

    /// Start a stress run。
    ///
    /// - Parameters:
    ///   - durationSeconds: total run length。Default 1200s (20 min)。
    ///   - cognitiveOSOptions: chapter 三百七五 / M862 opt-in。
    ///     Default `.allDisabled` preserves M826 / M837 behavior
    ///     (zero observer overhead, zero stat surfacing)。Pass
    ///     non-default options to wire event log + state store +
    ///     knowledge graph observation alongside the stress loop。
    func start(
        durationSeconds: Double =
            Constants.defaultDurationSeconds,
        cognitiveOSOptions: BASCognitiveOSBundleOptions =
            .allDisabled
    ) {
        guard stressTask == nil else { return }
        status = .loadingModels
        progressLog.removeAll()
        cognitiveOSEnabled =
            cognitiveOSOptions != .allDisabled
        cognitiveOSEventCount = 0
        cognitiveOSStateCount = 0
        cognitiveOSGraphNodeCount = 0
        cognitiveOSGraphEdgeCount = 0
        // M905:reset thermal-aware cadence telemetry for the
        // new run (so a previous run's counters don't leak)
        cognitiveOSThermalSensitivity = ""
        cognitiveOSThermalSkippedExtracts = 0
        cognitiveOSThermalSlowedExtracts = 0
        appendLog("🚀 Starting Chenglu mesh stress run " +
            "(\(Int(durationSeconds))s)" +
            (cognitiveOSEnabled
                ? " + cognitive OS observer"
                : ""))
        // Chapter 三百四六 / M833 fix: `[weak self]` matches the
        // SampleHost convention for long-running tasks (mirrors
        // SampleHostHybridBenchEntry.swift:163 / SampleHostAFM
        // BenchEntry.swift:68 / SampleHostLLMHelpers.swift:85)。
        // Without weak capture, a 20-min stress run would keep
        // the runner alive 20 min after the SwiftUI panel
        // dismisses → memory + battery cost。Weak capture lets
        // the runner deallocate cleanly when the parent
        // @StateObject goes out of scope。
        stressTask = Task { [weak self] in
            guard let self else { return }
            await self.runStress(
                durationSeconds: durationSeconds,
                cognitiveOSOptions: cognitiveOSOptions)
            self.stressTask = nil
        }
    }

    func cancel() {
        stressTask?.cancel()
        appendLog("🛑 Cancelled by user")
    }

    var isRunning: Bool { stressTask != nil }

    // MARK: - Internal stress loop

    private func runStress(
        durationSeconds: Double,
        cognitiveOSOptions: BASCognitiveOSBundleOptions =
            .allDisabled
    ) async {
        // Chapter 三百七五 / M862: build the cognitive OS observer
        // first。Default `.allDisabled` produces a no-op observer
        // (zero behavior change pin)。If construction throws
        // (SQLite open failure),fall through to disabled — the
        // stress run itself is unaffected。
        //
        // Chapter 三百九九 / M905:auto-select thermal sensitivity
        // based on requested run duration。
        // M909 hardening:threshold lowered from 3600s (1h) to
        // 1200s (20 min,= defaultDurationSeconds)。iPhone 17e
        // thermal envelope onset is typically 10-15 min,so
        // shorter runs at the default duration also benefit
        // from `.slowOnHot`。Threshold extracted as named
        // constant `thermalAutoSensitivityThresholdSec` (chapter
        // 一百八十五 anti-magic-number)。
        let thermalSensitivity:
            BASCognitiveOSThermalSensitivity =
            (durationSeconds >=
                Constants.thermalAutoSensitivityThresholdSec)
                ? .slowOnHot
                : .ignoreThermal
        let observer:
            SampleHostChengluStressCognitiveOSObserver
        do {
            observer =
                try SampleHostChengluStressCognitiveOSObserver(
                    options: cognitiveOSOptions,
                    thermalSensitivity: thermalSensitivity)
            if observer.isEnabled {
                appendLog(
                    "🧠 Cognitive OS observer wired " +
                    "(event log + state + graph as configured;" +
                    " thermal=\(thermalSensitivity.rawValue))")
            }
        } catch {
            appendLog(
                "⚠️ Cognitive OS observer disabled " +
                "(construction error: \(error))")
            observer = SampleHostChengluStressCognitiveOSObserver
                .disabled()
        }

        // Steps 1+2 run off main actor to avoid Sendable
        // crossings with MLModel refs (Swift 6 strict
        // concurrency)。Bundle is Sendable so it can return
        // to MainActor。
        let bundleResult: Result<
            BASChengluHostRuntimeBundle, Error
        > = await Self.loadAndBuildOffActor()

        let bundle: BASChengluHostRuntimeBundle
        switch bundleResult {
        case .success(let b):
            bundle = b
            guard bundle.registrationReport.isComplete else {
                status = .error(
                    "Registration incomplete: " +
                    "\(bundle.registrationReport.missingMLModels)")
                appendLog(
                    "❌ Registration incomplete: " +
                    "\(bundle.registrationReport.missingMLModels)")
                return
            }
            appendLog("✓ Loaded 5 .mlmodelc + mesh built — " +
                "8 canonical slots")
        case .failure(let error):
            status = .error(
                "Setup failed: \(error)")
            appendLog("❌ Setup failed: \(error)")
            return
        }

        // Step 3: establish determinism baseline
        let referenceInput: BASHostMeshLayerInput
        let baselineSignature: String
        do {
            referenceInput = try makeReferenceInput()
            let baseline = try await bundle.runtime
                .runChengluCanonicalSweep(
                    input: referenceInput)
            baselineSignature = sweepSignature(baseline)
            appendLog(
                "✓ Baseline: \(baselineSignature)")
        } catch {
            status = .error("Baseline failed: \(error)")
            appendLog("❌ Baseline failed: \(error)")
            return
        }

        // Step 4: sustained loop
        status = .running

        // Chapter 三百五〇 / M837: keep screen on during run。
        // Without this,iOS auto-locks → screen black → app
        // suspends after a few seconds → ANE inference stalls。
        // Restored in defer block at end-of-run。
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = true
        defer {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        #endif

        var localIter: Int = 0
        var localFail: Int = 0
        var localMismatch: Int = 0

        // Chapter 三百五〇 / M837: replace `[Double]` (138MB at
        // 17M samples for 8h run) with histogram + ring buffer。
        //   - histogram: ~15KB,O(1) per record,O(K) for percentile
        //   - ring buffer: 100 doubles for recentAvgMs window
        var histogram = LatencyHistogram()
        var recentRing = RecentLatencyRing(
            capacity: Constants.recentLatencyWindow)

        let clock = ContinuousClock()
        let runStart = clock.now
        let runDeadline = runStart.advanced(by:
            .seconds(Int(durationSeconds)))

        // Chapter 三百四七 / M834 fix: aggregate failures by
        // error description for end-of-run summary。Previous
        // version logged first 5 then silently counted —
        // 20-min stress with deterministic failure mode would
        // hide the failure pattern entirely。
        var failureBreakdown: [String: Int] = [:]

        // Chapter 三百五〇 / M837: per-minute time series for
        // drift detection over long runs。8h × 60min = 480 pts。
        var perMinuteThroughput: [Double] = []
        var perMinuteP99Ms: [Double] = []
        var nextMinuteMarkSec: Double =
            Constants.timeSeriesIntervalSec
        var iterAtLastMark: Int = 0

        // Chapter 三百九九 / M901: per-minute time series of
        // cognitive OS counters + thermal risk band。Captured at
        // the same minute mark cadence。10h iPhone run drove this:
        // pre-M901 the JSON only had final snapshot,no way to
        // plot graph growth or thermal pressure timeline。Arrays
        // are appended in lock-step with `perMinuteThroughput`
        // so consumers can correlate by index。
        var perMinuteCognitiveEventCount: [Int] = []
        var perMinuteCognitiveStateCount: [Int] = []
        var perMinuteCognitiveGraphNodeCount: [Int] = []
        var perMinuteCognitiveGraphEdgeCount: [Int] = []
        var perMinuteCognitiveThermalRiskBand: [String] = []

        // Chapter 三百五〇 / M837: periodic checkpoint persistence。
        var nextCheckpointSec: Double =
            Constants.checkpointPersistIntervalSec

        while clock.now < runDeadline {
            if Task.isCancelled { break }
            let iterStart = clock.now
            var iterSucceeded = true
            do {
                let input: BASHostMeshLayerInput
                if localIter
                    % Constants.determinismCheckInterval == 0
                    && localIter > 0
                {
                    input = referenceInput
                    let sweep = try await bundle.runtime
                        .runChengluCanonicalSweep(
                            input: input)
                    let sig = sweepSignature(sweep)
                    if sig != baselineSignature {
                        localMismatch += 1
                        appendLog(
                            "⚠️ determinism drift @ \(localIter): " +
                            "\(sig)")
                    }
                } else {
                    input = try makeCyclingInput(
                        iteration: localIter)
                    _ = try await bundle.runtime
                        .runChengluCanonicalSweep(
                            input: input)
                }
            } catch {
                localFail += 1
                iterSucceeded = false
                let errKey = "\(error)"
                failureBreakdown[errKey, default: 0] += 1
                if localFail <= 3
                    || localFail % 1000 == 0
                {
                    appendLog(
                        "❌ failure #\(localFail) @ iter " +
                        "\(localIter): \(error)")
                }
            }
            let dur = iterStart.duration(to: clock.now)
            let iterMs = Double(dur.components.seconds) * 1000
                + Double(dur.components.attoseconds) / 1e15
            histogram.record(iterMs)
            recentRing.record(iterMs)

            // Chapter 三百七五 / M862: feed the cognitive OS
            // observer。No-op when observer disabled (default)。
            // Observer never throws — failures count silently
            // against its own counters。
            if observer.isEnabled {
                await observer.observeIteration(
                    index: localIter,
                    latencyMs: iterMs,
                    succeeded: iterSucceeded)
            }

            localIter += 1

            // Per-100-iteration UI update
            if localIter
                % Constants.progressLogInterval == 0
            {
                let elapsedDur =
                    runStart.duration(to: clock.now)
                let elapsedSec =
                    Double(elapsedDur.components.seconds)
                    + Double(elapsedDur.components.attoseconds)
                    / 1e18
                self.iterations = localIter
                self.failures = localFail
                self.determinismMismatches = localMismatch
                self.elapsedSeconds = elapsedSec
                self.throughput =
                    Double(localIter) / elapsedSec
                self.recentAvgMs = recentRing.avg
                self.statusLine = String(
                    format: "iter %d / %.1fs / %.1f i/s / " +
                        "avg %.2fms",
                    localIter, elapsedSec, throughput,
                    recentRing.avg)

                // Chapter 三百七五 / M862: surface cognitive OS
                // stats to UI on the same per-100-iter cadence。
                // Chapter 三百九九 / M905: also surface thermal
                // policy + counters so the user can WATCH the
                // policy fire during a 1h+ run。
                if observer.isEnabled {
                    self.cognitiveOSEventCount =
                        observer.eventCount
                    self.cognitiveOSStateCount =
                        observer.stateCount
                    self.cognitiveOSGraphNodeCount =
                        observer.graphNodeCount
                    self.cognitiveOSGraphEdgeCount =
                        observer.graphEdgeCount
                    self.cognitiveOSThermalSensitivity =
                        thermalSensitivity.rawValue
                    self.cognitiveOSThermalSkippedExtracts =
                        observer.thermalSkippedExtracts
                    self.cognitiveOSThermalSlowedExtracts =
                        observer.thermalSlowedExtracts
                }

                // Per-minute time series capture
                if elapsedSec >= nextMinuteMarkSec {
                    let minuteIters =
                        localIter - iterAtLastMark
                    let minuteThroughput =
                        Double(minuteIters)
                        / Constants.timeSeriesIntervalSec
                    perMinuteThroughput.append(
                        minuteThroughput)
                    perMinuteP99Ms.append(
                        histogram.percentile(0.99))
                    iterAtLastMark = localIter
                    nextMinuteMarkSec +=
                        Constants.timeSeriesIntervalSec

                    // M901: capture cognitive OS counters +
                    // thermal risk band on the SAME minute mark
                    // so consumers can correlate by array index。
                    // No-op silently when observer disabled —
                    // arrays grow from index 0 only when wired,
                    // preserving M826/M837 contract for hosts
                    // that don't enable the cognitive OS。
                    if observer.isEnabled {
                        perMinuteCognitiveEventCount.append(
                            observer.eventCount)
                        perMinuteCognitiveStateCount.append(
                            observer.stateCount)
                        perMinuteCognitiveGraphNodeCount.append(
                            observer.graphNodeCount)
                        perMinuteCognitiveGraphEdgeCount.append(
                            observer.graphEdgeCount)
                        perMinuteCognitiveThermalRiskBand.append(
                            observer.currentThermalRiskBand
                                .rawValue)
                    }
                }

                // Periodic checkpoint persistence
                if elapsedSec >= nextCheckpointSec {
                    let checkpoint = StressRunResult(
                        schemaVersion: StressRunResult
                            .currentSchemaVersion,
                        buildChapter: "M905",
                        phase: .checkpoint,
                        timestamp: Date(),
                        requestedDurationSeconds:
                            durationSeconds,
                        elapsedSeconds: elapsedSec,
                        iterations: localIter,
                        failures: localFail,
                        determinismMismatches: localMismatch,
                        throughput: throughput,
                        p50Ms: histogram.percentile(0.50),
                        p95Ms: histogram.percentile(0.95),
                        p99Ms: histogram.percentile(0.99),
                        recentAvgMs: recentRing.avg,
                        baselineSignature: baselineSignature,
                        registrationComplete: bundle
                            .registrationReport.isComplete,
                        missingMLModels: bundle
                            .registrationReport
                            .missingMLModels,
                        failureBreakdown: failureBreakdown,
                        progressLog: progressLog,
                        perMinuteThroughput:
                            perMinuteThroughput,
                        perMinuteP99Ms: perMinuteP99Ms,
                        device: StressRunResult.DeviceInfo
                            .current(),
                        cancelled: false,
                        cognitiveOS:
                            self.cognitiveOSEnabled
                            ? StressRunResult
                                .CognitiveOSSummary(
                                eventCount: observer
                                    .eventCount,
                                stateCount: observer
                                    .stateCount,
                                graphNodeCount: observer
                                    .graphNodeCount,
                                graphEdgeCount: observer
                                    .graphEdgeCount,
                                // M901:include the per-minute
                                // time series accumulated so far
                                timeSeries: StressRunResult
                                    .CognitiveOSTimeSeries(
                                    eventCount:
                                        perMinuteCognitiveEventCount,
                                    stateCount:
                                        perMinuteCognitiveStateCount,
                                    graphNodeCount:
                                        perMinuteCognitiveGraphNodeCount,
                                    graphEdgeCount:
                                        perMinuteCognitiveGraphEdgeCount,
                                    thermalRiskBand:
                                        perMinuteCognitiveThermalRiskBand),
                                // M905:thermal-aware cadence
                                // policy + counters。Snapshot at
                                // checkpoint time so analysis
                                // tools can plot the policy
                                // effect over the run。
                                thermalSensitivity:
                                    thermalSensitivity.rawValue,
                                thermalSkippedExtracts:
                                    observer.thermalSkippedExtracts,
                                thermalSlowedExtracts:
                                    observer.thermalSlowedExtracts)
                            : nil)
                    _ = try? Self.persistResult(checkpoint)
                    nextCheckpointSec +=
                        Constants.checkpointPersistIntervalSec
                }
            }
        }

        // Final stats
        let totalDur = runStart.duration(to: clock.now)
        let totalSec = Double(totalDur.components.seconds)
            + Double(totalDur.components.attoseconds) / 1e18
        let throughputFinal = Double(localIter) / totalSec
        let p50 = histogram.percentile(0.50)
        let p95 = histogram.percentile(0.95)
        let p99 = histogram.percentile(0.99)

        self.iterations = localIter
        self.failures = localFail
        self.determinismMismatches = localMismatch
        self.elapsedSeconds = totalSec
        self.throughput = throughputFinal
        self.p50Ms = p50
        self.p95Ms = p95
        self.p99Ms = p99
        self.statusLine = String(
            format: "DONE %d iter / %.1fs / %.1f i/s / " +
                "p50 %.2fms p95 %.2fms p99 %.2fms / " +
                "fail %d / drift %d",
            localIter, totalSec, throughputFinal,
            p50, p95, p99, localFail, localMismatch)
        appendLog(self.statusLine)
        // Chapter 三百四七 / M834: emit failure breakdown by
        // error type at end-of-run for diagnostic context that
        // first-3 + every-1000th sampling cannot capture。
        if !failureBreakdown.isEmpty {
            let sortedBreakdown = failureBreakdown.sorted {
                $0.value > $1.value
            }
            for (errKey, count) in sortedBreakdown.prefix(10) {
                appendLog(
                    "  [breakdown] \(count)× \(errKey)")
            }
            if sortedBreakdown.count > 10 {
                let remaining = sortedBreakdown
                    .dropFirst(10)
                    .reduce(0) { $0 + $1.value }
                appendLog(
                    "  [breakdown] +\(remaining) other " +
                    "(in \(sortedBreakdown.count - 10) types)")
            }
        }

        // Chapter 三百七五 / M862: final cognitive OS stat refresh
        // + summary log line。Storage actor walks may have lagged
        // the local counters during the stress loop — refreshStats
        // pulls authoritative counts。
        // Chapter 三百九九 / M905:final stats also include thermal
        // counters so the post-run JSON + UI agree。
        if observer.isEnabled {
            await observer.refreshStats()
            self.cognitiveOSEventCount = observer.eventCount
            self.cognitiveOSStateCount = observer.stateCount
            self.cognitiveOSGraphNodeCount =
                observer.graphNodeCount
            self.cognitiveOSGraphEdgeCount =
                observer.graphEdgeCount
            self.cognitiveOSThermalSensitivity =
                thermalSensitivity.rawValue
            self.cognitiveOSThermalSkippedExtracts =
                observer.thermalSkippedExtracts
            self.cognitiveOSThermalSlowedExtracts =
                observer.thermalSlowedExtracts
            appendLog(
                "🧠 cognitive OS: " +
                "\(observer.eventCount) events / " +
                "\(observer.stateCount) states / " +
                "\(observer.graphNodeCount) graph nodes / " +
                "\(observer.graphEdgeCount) graph edges")
            appendLog(
                "🌡️ thermal policy: " +
                "\(thermalSensitivity.rawValue) / " +
                "skipped=\(observer.thermalSkippedExtracts) / " +
                "slowed=\(observer.thermalSlowedExtracts)")
        }

        // Chapter 三百四九 / M836 + 三百五〇 / M837: persist final
        // run result as JSON。Once the panel dismisses,
        // @Published state vanishes and run data is unrecoverable。
        // Persistence keeps it for retrieval via
        // `xcrun devicectl device copy from`。
        let cancelled = Task.isCancelled
        let result = StressRunResult(
            schemaVersion: StressRunResult.currentSchemaVersion,
            buildChapter: "M905",
            phase: cancelled ? .cancelled : .final,
            timestamp: Date(),
            requestedDurationSeconds: durationSeconds,
            elapsedSeconds: totalSec,
            iterations: localIter,
            failures: localFail,
            determinismMismatches: localMismatch,
            throughput: throughputFinal,
            p50Ms: p50,
            p95Ms: p95,
            p99Ms: p99,
            recentAvgMs: self.recentAvgMs,
            baselineSignature: baselineSignature,
            registrationComplete:
                bundle.registrationReport.isComplete,
            missingMLModels: bundle.registrationReport
                .missingMLModels,
            failureBreakdown: failureBreakdown,
            progressLog: progressLog,
            perMinuteThroughput: perMinuteThroughput,
            perMinuteP99Ms: perMinuteP99Ms,
            device: StressRunResult.DeviceInfo.current(),
            cancelled: cancelled,
            // M876: typed cognitive OS summary on every save
            // when observer was wired (final + checkpoint paths
            // share the same construction)。M901:final path
            // also writes the full per-minute time series。
            // M905:final path also writes thermal policy +
            // counters。
            cognitiveOS: self.cognitiveOSEnabled
                ? StressRunResult.CognitiveOSSummary(
                    eventCount: observer.eventCount,
                    stateCount: observer.stateCount,
                    graphNodeCount: observer.graphNodeCount,
                    graphEdgeCount: observer.graphEdgeCount,
                    timeSeries: StressRunResult
                        .CognitiveOSTimeSeries(
                        eventCount:
                            perMinuteCognitiveEventCount,
                        stateCount:
                            perMinuteCognitiveStateCount,
                        graphNodeCount:
                            perMinuteCognitiveGraphNodeCount,
                        graphEdgeCount:
                            perMinuteCognitiveGraphEdgeCount,
                        thermalRiskBand:
                            perMinuteCognitiveThermalRiskBand),
                    thermalSensitivity:
                        thermalSensitivity.rawValue,
                    thermalSkippedExtracts:
                        observer.thermalSkippedExtracts,
                    thermalSlowedExtracts:
                        observer.thermalSlowedExtracts)
                : nil)
        do {
            let saved = try Self.persistResult(result)
            self.lastSavedRelativePath = saved.relativePath
            appendLog(
                "💾 saved → " +
                "Documents/\(saved.relativePath)")
        } catch {
            appendLog("⚠️ persist failed: \(error)")
        }

        status = .finished
    }

    // MARK: - Helpers (nonisolated — off main actor)

    /// Loads all 5 bundled `.mlmodelc` + builds the附录 X
    /// mesh bundle off main actor。Returns a Sendable
    /// `BASChengluHostRuntimeBundle` (or error) that can
    /// safely cross back to MainActor。
    nonisolated static func loadAndBuildOffActor() async
        -> Result<BASChengluHostRuntimeBundle, Error>
    {
        do {
            let chengluModels =
                try Self.loadAllBundledModels()
            let bundle = try await
                BASChengluHostRuntimeBuilder.build(
                    configuration: BASHostConfiguration
                        .fixtureGeneric,
                    chengluModels: chengluModels)
            return .success(bundle)
        } catch {
            return .failure(error)
        }
    }

    nonisolated static func loadAllBundledModels() throws ->
        BASChengluMeshRegistration.RegistrationOptions
    {
        let preflight = try loadBundledModel(
            "ChengluPreflight_v0")
        let multiHead = try loadBundledModel(
            "ChengluMultiHead_v0")
        let permit = try loadBundledModel(
            "ChengluPermitPredict_v0")
        let length = try loadBundledModel(
            "ChengluLengthHead_v0")
        let latency = try loadBundledModel(
            "ChengluLatencyHead_v0")
        return BASChengluMeshRegistration.RegistrationOptions(
            preflightModel: preflight,
            multiHeadModel: multiHead,
            permitPredictModel: permit,
            lengthHeadModel: length,
            latencyHeadModel: latency)
    }

    nonisolated static func loadBundledModel(
        _ resourceName: String
    ) throws -> MLModel {
        guard let url = Bundle.main.url(
            forResource: resourceName,
            withExtension: "mlmodelc")
        else {
            throw ChengluStressError.bundledModelMissing(
                resourceName)
        }
        let config = MLModelConfiguration()
        config.computeUnits = .all
        return try MLModel(
            contentsOf: url, configuration: config)
    }

    private func makeCyclingInput(
        iteration: Int
    ) throws -> BASHostMeshLayerInput {
        let tones = BASChengluFeatureEncoder.tones
        let domains = BASChengluFeatureEncoder.domains
        let stakes = BASChengluFeatureEncoder.stakes
        let timeframes = BASChengluFeatureEncoder.timeframes
        let confidants = BASChengluFeatureEncoder.confidants
        let askShapes = BASChengluFeatureEncoder.askShapes
        let ref = try BASChengluFeatureRefBuilder.build(
            tone: tones[iteration % tones.count],
            domain: domains[
                (iteration / 7) % domains.count],
            stake: stakes[
                (iteration / 13) % stakes.count],
            timeframe: timeframes[
                (iteration / 17) % timeframes.count],
            confidant: confidants[
                (iteration / 19) % confidants.count],
            askShape: askShapes[
                (iteration / 23) % askShapes.count],
            mutationSeed: iteration % 5)
        return BASHostMeshLayerInput(
            layerID: .l1,
            featureRef: ref,
            confidenceFloor: .high)
    }

    private func makeReferenceInput() throws
        -> BASHostMeshLayerInput
    {
        let ref = try BASChengluFeatureRefBuilder.build(
            tone: "anxious", domain: "medical",
            stake: "critical", timeframe: "today",
            confidant: "trusted-ai", askShape: "question",
            mutationSeed: 2)
        return BASHostMeshLayerInput(
            layerID: .l1,
            featureRef: ref,
            confidenceFloor: .high)
    }

    private func sweepSignature(
        _ sweep: BASHostMeshSweepResult
    ) -> String {
        let hints = BASChengluSweepInterpreter.interpret(sweep)
        guard let pf = hints.preflight else {
            return "no-preflight"
        }
        return "\(pf.route.rawValue):" +
            "\(pf.confidence.rawValue):" +
            String(format: "%.6f", pf.probability)
    }

    private func appendLog(_ line: String) {
        progressLog.append(line)
        if progressLog.count > 200 {
            progressLog.removeFirst(
                progressLog.count - 200)
        }
    }

    // MARK: - Persistence (chapter 三百四九 / M836)

    /// Persist a finished run result to two locations:
    ///   - `Documents/chenglu-stress-runs/latest.json`
    ///     (overwritten each run — easy retrieval point)
    ///   - `Documents/chenglu-stress-runs/run-<iso>.json`
    ///     (append-only history)
    ///
    /// Returns the relative path (under Documents) of the
    /// timestamped history file。Caller surfaces it via UI for
    /// `xcrun devicectl device copy from` retrieval。
    nonisolated static func persistResult(
        _ result: StressRunResult
    ) throws -> (
        latestPath: URL,
        historyPath: URL,
        relativePath: String
    ) {
        let docs = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true)
        let dir = docs.appendingPathComponent(
            "chenglu-stress-runs", isDirectory: true)
        if !FileManager.default.fileExists(
            atPath: dir.path)
        {
            try FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted, .sortedKeys
        ]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(result)

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [
            .withInternetDateTime,
            .withDashSeparatorInDate,
            .withColonSeparatorInTime
        ]
        let stamp = isoFormatter
            .string(from: result.timestamp)
            .replacingOccurrences(of: ":", with: "-")
        let historyName = "run-\(stamp).json"
        let history = dir.appendingPathComponent(
            historyName)
        let latest = dir.appendingPathComponent(
            "latest.json")
        try data.write(to: history, options: .atomic)
        try data.write(to: latest, options: .atomic)
        return (
            latestPath: latest,
            historyPath: history,
            relativePath:
                "chenglu-stress-runs/\(historyName)")
    }
}

// MARK: - StressRunResult (Codable, persisted to disk)

/// Codable record of a stress run (checkpoint or final)。
/// Schema-versioned for forward-compat。Schema 1.1.0 (chapter
/// 三百五〇 / M837) added `phase`, `perMinuteThroughput`,
/// `perMinuteP99Ms` for 8h drift detection + checkpoint support。
/// Schema 1.2.0 (chapter 三百八七 / M876) added cognitiveOS field
/// for typed cognitive OS observer metrics — pre-M876 these were
/// only in the human-readable progressLog text。Field is nil
/// when observer was disabled or not yet wired (M826/M837 hosts)。
/// Schema 1.3.0 (chapter 三百九九 / M901)added per-minute cognitive
/// OS time-series + thermal-risk-band history,driven by 10h
/// iPhone observation that spent 98.13% of events in `.serious`
/// thermal — pre-M901 the JSON only had final snapshot,no way
/// to plot graph-growth or thermal pressure over time。Optional
/// for back-compat:pre-M901 records decode with timeSeries=nil。
/// Schema 1.4.0 (chapter 三百九九 / M905)added thermal sensitivity
/// policy name + skipped/slowed extract counters captured at
/// run-end so the next 10h run validates that `.slowOnHot`
/// actually fires under thermal pressure (instead of the silent
/// 0-edge gap the 10h run produced)。Optional for back-compat:
/// pre-M905 records decode with all 3 thermal fields nil。
struct StressRunResult: Codable, Equatable, Sendable {
    static let currentSchemaVersion: String = "1.4.0"

    /// Lifecycle phase at the moment this record was persisted。
    /// `checkpoint` = mid-run periodic save (every 60s wall-clock)。
    /// `final` = end-of-run normal completion。
    /// `cancelled` = user-cancelled mid-run。
    enum Phase: String, Codable, Sendable {
        case checkpoint
        case final
        case cancelled
    }

    let schemaVersion: String
    /// Chapter / M-number tag of the build that produced this
    /// run。Helps cross-reference results against commit SHAs。
    let buildChapter: String
    let phase: Phase

    let timestamp: Date
    let requestedDurationSeconds: Double
    let elapsedSeconds: Double

    let iterations: Int
    let failures: Int
    let determinismMismatches: Int
    let throughput: Double

    let p50Ms: Double
    let p95Ms: Double
    let p99Ms: Double
    let recentAvgMs: Double

    let baselineSignature: String
    let registrationComplete: Bool
    let missingMLModels: [String]

    let failureBreakdown: [String: Int]
    let progressLog: [String]

    /// Chapter 三百五〇 / M837: per-minute throughput sample
    /// captured every `timeSeriesIntervalSec` wall-clock seconds。
    /// 8h run yields up to 480 entries。Empty for runs shorter
    /// than the first sample interval。
    let perMinuteThroughput: [Double]

    /// Chapter 三百五〇 / M837: per-minute p99 latency sample
    /// (cumulative-up-to-this-minute,not a sliding window)。
    /// Tracks drift in upper-tail latency over time。
    let perMinuteP99Ms: [Double]

    let device: DeviceInfo
    let cancelled: Bool

    /// Chapter 三百八七 / M876: typed cognitive OS observer
    /// metrics。Nil when observer disabled or wasn't wired
    /// (preserves backward-compat with pre-M876 stress runs)。
    let cognitiveOS: CognitiveOSSummary?

    /// M876 typed snapshot of cognitive OS observer state at
    /// end-of-run。Mirrors the runner's @Published cognitive OS
    /// fields but is Codable for persistence。
    /// Chapter 三百九九 / M901:extended with optional `timeSeries`
    /// holding per-minute samples of the same counters,plus
    /// thermal-risk-band history。Optional for back-compat:
    /// pre-M901 records decode with timeSeries=nil。
    /// Chapter 三百九九 / M905:extended with optional thermal
    /// telemetry counters (`thermalSkippedExtracts` /
    /// `thermalSlowedExtracts`)。Captures policy-effect counts
    /// from M905 thermal-aware cadence so the next 10h run can
    /// validate the policy actually fires under thermal load。
    /// Optional for back-compat:pre-M905 records decode with
    /// nil for both counters。
    struct CognitiveOSSummary: Codable, Equatable, Sendable {
        let eventCount: Int
        let stateCount: Int
        let graphNodeCount: Int
        let graphEdgeCount: Int
        /// M901 per-minute time series of cognitive OS counters
        /// + thermal risk band。Captured at the same minute
        /// mark cadence as `perMinuteThroughput`(every
        /// `Constants.timeSeriesIntervalSec` wall-clock seconds)。
        /// Nil for runs that pre-date M901 schema 1.3.0 OR for
        /// runs where the observer was disabled。
        let timeSeries: CognitiveOSTimeSeries?

        /// M905 thermal sensitivity policy that was active for
        /// this run。Raw enum case name string;values are
        /// `"ignoreThermal"` / `"slowOnHot"` / `"skipOnCritical"`。
        /// Nil for pre-M905 runs。
        let thermalSensitivity: String?

        /// M905 count of graph extracts SKIPPED because the
        /// thermal-sensitivity policy gated them out。Nil for
        /// pre-M905 runs;0 for post-M905 runs where policy
        /// never fired (cool device or `.ignoreThermal`)。
        let thermalSkippedExtracts: Int?

        /// M905 count of graph extracts that fired on the
        /// SLOWED cadence (interval × multiplier) when
        /// `.slowOnHot` was active and thermal was hot。Nil for
        /// pre-M905 runs;0 for runs where the slowed-cadence
        /// path never fired。
        let thermalSlowedExtracts: Int?

        /// M901 / M905 back-compat init — every new optional
        /// defaults to nil so pre-existing call sites keep
        /// working without modification。
        init(
            eventCount: Int,
            stateCount: Int,
            graphNodeCount: Int,
            graphEdgeCount: Int,
            timeSeries: CognitiveOSTimeSeries? = nil,
            thermalSensitivity: String? = nil,
            thermalSkippedExtracts: Int? = nil,
            thermalSlowedExtracts: Int? = nil
        ) {
            self.eventCount = eventCount
            self.stateCount = stateCount
            self.graphNodeCount = graphNodeCount
            self.graphEdgeCount = graphEdgeCount
            self.timeSeries = timeSeries
            self.thermalSensitivity = thermalSensitivity
            self.thermalSkippedExtracts =
                thermalSkippedExtracts
            self.thermalSlowedExtracts = thermalSlowedExtracts
        }
    }

    /// M901 typed per-minute time-series of cognitive OS counters。
    /// Each array has the SAME length as `perMinuteThroughput`
    /// (one entry per minute mark — index i is minute i+1)。
    /// Counts are CUMULATIVE (count at end of minute i),so callers
    /// derive per-minute rate by diffing adjacent entries。
    struct CognitiveOSTimeSeries: Codable, Equatable, Sendable {
        /// Cumulative event-log append count at the minute mark。
        let eventCount: [Int]
        /// Cumulative state reducer fold count at the minute mark。
        let stateCount: [Int]
        /// Cumulative knowledge-graph node count at the minute
        /// mark (cap at most-recent extract pass)。
        let graphNodeCount: [Int]
        /// Cumulative knowledge-graph edge count at the minute
        /// mark (cap at most-recent extract pass)。
        let graphEdgeCount: [Int]
        /// `BASEventLogRiskBand.rawValue` at the minute mark。
        /// Mirrors M887 cached thermal risk band。Values are
        /// `"low"` / `"medium"` / `"high"` / `"unknown"`。
        let thermalRiskBand: [String]
    }

    struct DeviceInfo: Codable, Equatable, Sendable {
        let model: String
        let systemName: String
        let systemVersion: String
        /// gaps-reconciliation x-sovereignty #7 (2026-07-11): this used to persist
        /// UIDevice.identifierForVendor — a PERSISTENT device identifier — into the local run
        /// JSON, an artifact that gets shared/committed (sovereignty doctrine: no device
        /// identifiers in shareable artifacts). Now a per-RUN random UUID: run reports stay
        /// distinguishable within a sweep, but nothing correlates across runs or to the device.
        /// Field kept Optional for decode-compat with historical run JSONs.
        let identifierForVendor: String?

        @MainActor
        static func current() -> DeviceInfo {
            #if canImport(UIKit)
            let device = UIDevice.current
            return DeviceInfo(
                model: device.model,
                systemName: device.systemName,
                systemVersion: device.systemVersion,
                identifierForVendor: "run-" + UUID().uuidString)
            #else
            return DeviceInfo(
                model: "unknown",
                systemName: "unknown",
                systemVersion: "unknown",
                identifierForVendor: nil)
            #endif
        }
    }
}

// MARK: - LatencyHistogram (chapter 三百五〇 / M837)

/// O(1)-record / O(K)-percentile histogram for sustained-run
/// latency tracking。Replaces the prior `[Double]` array which
/// would consume ~138MB at 17M samples (8h × 600 i/s)。
///
/// **Bucket scheme**:
///   - 0..999 = bucket [i*0.1, (i+1)*0.1) ms — 0.1ms resolution
///     covering 0-100ms (typical Chenglu mesh sweep range)
///   - 1000 = overflow ≥ 100ms (thermal throttle / GC pause /
///     anomaly bucket — exact ms lost above 100ms)
///
/// **Memory**: 1001 × 8 bytes Int = 8KB total, regardless of
/// sample count。
struct LatencyHistogram: Sendable, Equatable {
    /// Public for testability。`buckets[1000]` is the overflow
    /// counter for ≥ 100ms samples。
    private(set) var buckets: [Int]
    private(set) var totalCount: Int = 0
    private(set) var sumMs: Double = 0

    static let bucketCount: Int = 1001
    static let bucketWidthMs: Double = 0.1
    static let maxResolvedMs: Double = 100.0

    init() {
        self.buckets = Array(
            repeating: 0, count: Self.bucketCount)
    }

    mutating func record(_ ms: Double) {
        let bucketIdx: Int
        if ms < 0 {
            bucketIdx = 0
        } else if ms >= Self.maxResolvedMs {
            bucketIdx = Self.bucketCount - 1
        } else {
            bucketIdx = Int(ms / Self.bucketWidthMs)
        }
        buckets[bucketIdx] += 1
        totalCount += 1
        sumMs += max(ms, 0)
    }

    var avgMs: Double {
        totalCount > 0
            ? sumMs / Double(totalCount)
            : 0
    }

    /// Compute the percentile from cumulative bucket counts。
    /// Returns the LOWER edge of the bucket containing the
    /// percentile cutoff (consistent with sorted-array indexing
    /// `sorted[Int(count * p)]`)。Overflow bucket returns
    /// `maxResolvedMs` (e.g. 100.0) as the lower bound — caller
    /// reads this as ">= 100ms"。
    func percentile(_ p: Double) -> Double {
        guard totalCount > 0 else { return 0 }
        let target = Int(Double(totalCount) * p)
        var cumulative = 0
        for (idx, count) in buckets.enumerated() {
            cumulative += count
            if cumulative > target {
                if idx == Self.bucketCount - 1 {
                    return Self.maxResolvedMs
                }
                return Double(idx) * Self.bucketWidthMs
            }
        }
        return Self.maxResolvedMs
    }
}

// MARK: - RecentLatencyRing (chapter 三百五〇 / M837)

/// Fixed-capacity ring buffer for the `recentAvgMs` window。
/// Replaces `array.suffix(N).reduce(0,+)` which required keeping
/// the full latency history in an Array。
struct RecentLatencyRing: Sendable {
    private var buffer: [Double]
    private var head: Int = 0
    private(set) var count: Int = 0

    init(capacity: Int) {
        precondition(capacity > 0,
            "RecentLatencyRing capacity must be > 0")
        self.buffer = Array(
            repeating: 0, count: capacity)
    }

    mutating func record(_ ms: Double) {
        buffer[head] = ms
        head = (head + 1) % buffer.count
        if count < buffer.count { count += 1 }
    }

    var avg: Double {
        guard count > 0 else { return 0 }
        let sum = buffer.prefix(count)
            .reduce(0.0, +)
        return sum / Double(count)
    }
}

enum ChengluStressError: Error,
    CustomStringConvertible
{
    case bundledModelMissing(String)
    var description: String {
        switch self {
        case .bundledModelMissing(let name):
            return
                "bundled \(name).mlmodelc missing from Bundle.main"
        }
    }
}
