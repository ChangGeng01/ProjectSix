// MARK: - SampleHostChengluStressRunner — chapter 三百三九 / M826
//
// iPhone-side sustained stress runner for the附录 X Chenglu mesh
// chain。Mirrors `BASChenglu20MinStressTests` (chapter 三百三八)
// but loads `.mlmodelc` files via Bundle.main instead of env var
// paths,and exposes incremental progress via `@Published` props
// for the SwiftUI panel。
//
// Closes v9 §8 non-promise #4 (production deployment validation)
// for opt-in real-iPhone testing。

import CoreML
import Foundation
import BASHostKit

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
    }

    // MARK: - Public API

    func start(durationSeconds: Double =
        Constants.defaultDurationSeconds)
    {
        guard stressTask == nil else { return }
        status = .loadingModels
        progressLog.removeAll()
        appendLog("🚀 Starting Chenglu mesh stress run " +
            "(\(Int(durationSeconds))s)")
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
                durationSeconds: durationSeconds)
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
        durationSeconds: Double
    ) async {
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
        var localIter: Int = 0
        var localFail: Int = 0
        var localMismatch: Int = 0
        var latenciesMs: [Double] = []
        latenciesMs.reserveCapacity(2_000_000)

        let clock = ContinuousClock()
        let runStart = clock.now
        let runDeadline = runStart.advanced(by:
            .seconds(Int(durationSeconds)))

        while clock.now < runDeadline {
            if Task.isCancelled { break }
            let iterStart = clock.now
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
                if localFail < 5 {
                    appendLog(
                        "❌ failure @ \(localIter): \(error)")
                }
            }
            let dur = iterStart.duration(to: clock.now)
            let iterMs = Double(dur.components.seconds) * 1000
                + Double(dur.components.attoseconds) / 1e15
            latenciesMs.append(iterMs)
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
                let recentLat = latenciesMs.suffix(
                    Constants.progressLogInterval)
                let recentAvg = recentLat.reduce(0, +)
                    / Double(recentLat.count)
                self.iterations = localIter
                self.failures = localFail
                self.determinismMismatches = localMismatch
                self.elapsedSeconds = elapsedSec
                self.throughput =
                    Double(localIter) / elapsedSec
                self.recentAvgMs = recentAvg
                self.statusLine = String(
                    format: "iter %d / %.1fs / %.1f i/s / " +
                        "avg %.2fms",
                    localIter, elapsedSec, throughput,
                    recentAvg)
            }
        }

        // Final stats
        let totalDur = runStart.duration(to: clock.now)
        let totalSec = Double(totalDur.components.seconds)
            + Double(totalDur.components.attoseconds) / 1e18
        let throughputFinal = Double(localIter) / totalSec
        let sortedLat = latenciesMs.sorted()
        let p50 = sortedLat.isEmpty ? 0
            : sortedLat[sortedLat.count / 2]
        let p95 = sortedLat.isEmpty ? 0
            : sortedLat[Int(Double(sortedLat.count) * 0.95)]
        let p99 = sortedLat.isEmpty ? 0
            : sortedLat[Int(Double(sortedLat.count) * 0.99)]

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
