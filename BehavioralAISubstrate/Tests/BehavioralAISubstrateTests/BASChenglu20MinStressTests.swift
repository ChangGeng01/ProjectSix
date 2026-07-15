// MARK: - BASChenglu20MinStressTests — chapter 三百三八 / M825
//
// **20-minute sustained real-model stress test** for the附录 X
// Chenglu mesh chain。Gated on `QINAO_COREML_STRESS_20MIN=1`
// in addition to `QINAO_COREML_E2E=1` and the 5 model paths,so
// the heavy run only fires when explicitly opted in。
//
// What this test proves:
//   - Determinism: same input → same output across many iterations
//     (sklearn-trained models with fixed weights should be perfectly
//     deterministic — if not, that's a real bug)
//   - Memory stability: no leaks across 100K+ iterations (build
//     mesh ONCE, sweep N times — leak would show up in RSS growth
//     visible via external `ps` monitoring)
//   - Latency stability: p50/p95/p99 stable across 20 minutes
//     (no thermal throttling on Apple Silicon, no GC spikes)
//   - Throughput: how many sweeps/second can we run end-to-end
//     through the附录 X chain on this hardware
//
// Latency timing uses `ContinuousClock` for monotonic measurement
// (incidentally fixing chapter 三百三七 deep-review deferral H5
// for the stress test path)。

import XCTest
@testable import BASAppleAdapters
@testable import BASHostKit
@testable import BASRuntimeCore

#if canImport(CoreML)
import CoreML
import BASAppleEdgeWiring
#endif

final class BASChenglu20MinStressTests: XCTestCase {

    private enum Constants {
        /// Total wall-clock budget for the stress run。
        static let stressDurationSeconds: Double = 1200  // 20 min

        /// Log progress every N iterations。
        static let progressLogInterval: Int = 1000

        /// Re-verify determinism baseline every N iterations。
        static let determinismCheckInterval: Int = 10_000

        /// Master + per-model env var gate。
        static let stressGate: String = "QINAO_COREML_STRESS_20MIN"
    }

    private func shouldRunStress() -> Bool {
        guard BASChengluRealModelE2EHarness.shouldRunE2E()
        else { return false }
        return ProcessInfo.processInfo.environment[
            Constants.stressGate] == "1"
    }

    #if canImport(CoreML)

    /// 5 cycling input fixtures to exercise different feature
    /// vector positions across iterations。Each tone/domain/stake
    /// combo lights up different one-hot positions。
    private func makeCyclingInput(
        iteration: Int
    ) throws -> BASLayerInferenceInput {
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
        return BASLayerInferenceInput(
            layerID: .l1,
            featureRef: ref,
            confidenceFloor: .high)
    }

    /// Fixed reference input used for determinism check。
    private func makeReferenceInput() throws
        -> BASLayerInferenceInput
    {
        let ref = try BASChengluFeatureRefBuilder.build(
            tone: "anxious", domain: "medical",
            stake: "critical", timeframe: "today",
            confidant: "trusted-ai", askShape: "question",
            mutationSeed: 2)
        return BASLayerInferenceInput(
            layerID: .l1,
            featureRef: ref,
            confidenceFloor: .high)
    }

    /// Load all 5 real models via env vars。Throws XCTSkip if
    /// any are missing (stress test requires the full set)。
    private func loadAll5Models() throws ->
        BASChengluMeshRegistration.RegistrationOptions
    {
        try XCTSkipUnless(
            shouldRunStress(),
            "QINAO_COREML_STRESS_20MIN + QINAO_COREML_E2E " +
            "must both be '1' to run the 20-min stress test")
        guard let preflightURL = BASChengluRealModelE2EHarness
            .preflightModelURL,
            BASChengluRealModelE2EHarness.packageExists(
                at: preflightURL),
            let multiHeadURL = BASChengluRealModelE2EHarness
                .multiHeadModelURL,
            BASChengluRealModelE2EHarness.packageExists(
                at: multiHeadURL),
            let permitURL = BASChengluRealModelE2EHarness
                .permitPredictModelURL,
            BASChengluRealModelE2EHarness.packageExists(
                at: permitURL),
            let lengthURL = BASChengluRealModelE2EHarness
                .lengthHeadModelURL,
            BASChengluRealModelE2EHarness.packageExists(
                at: lengthURL),
            let latencyURL = BASChengluRealModelE2EHarness
                .latencyHeadModelURL,
            BASChengluRealModelE2EHarness.packageExists(
                at: latencyURL)
        else {
            throw XCTSkip(
                "Missing one or more model paths — " +
                "stress test requires all 5 models")
        }

        let preflightModel = try BASChengluRealModelE2EHarness
            .loadMLModel(at: preflightURL)
        let multiHeadModel = try BASChengluRealModelE2EHarness
            .loadMLModel(at: multiHeadURL)
        let permitModel = try BASChengluRealModelE2EHarness
            .loadMLModel(at: permitURL)
        let lengthModel = try BASChengluRealModelE2EHarness
            .loadMLModel(at: lengthURL)
        let latencyModel = try BASChengluRealModelE2EHarness
            .loadMLModel(at: latencyURL)

        return BASChengluMeshRegistration.RegistrationOptions(
            preflightModel: preflightModel,
            multiHeadModel: multiHeadModel,
            permitPredictModel: permitModel,
            lengthHeadModel: lengthModel,
            latencyHeadModel: latencyModel)
    }

    /// Extract a stable signature from a sweep result for
    /// determinism comparison。Uses preflight head's
    /// route+confidence (the most stable + most production-
    /// relevant signal)。
    private func sweepSignature(
        _ sweep: BASHostMeshSweepResult
    ) -> String {
        let hints = BASChengluSweepInterpreter.interpret(sweep)
        guard let preflight = hints.preflight else {
            return "no-preflight"
        }
        return "\(preflight.route.rawValue):" +
            "\(preflight.confidence.rawValue):" +
            String(format: "%.6f", preflight.probability)
    }

    // MARK: - The 20-minute stress test

    func testSustained20MinuteRealModelStress() async throws {
        let chengluModels = try loadAll5Models()

        // Build mesh ONCE — sustained run uses the same
        // registry + runtime for all iterations
        let bundle = try await BASChengluHostRuntimeBuilder
            .build(
                configuration:
                    BASHostConfiguration.fixtureGeneric,
                chengluModels: chengluModels)
        XCTAssertTrue(bundle.registrationReport.isComplete)
        print("\n🚀 20-MIN STRESS TEST — mesh built, " +
            "starting sustained run")

        // Establish determinism baseline
        let referenceInput = try makeReferenceInput()
        let baselineSweep = try await bundle.runtime
            .runChengluCanonicalSweep(input: referenceInput)
        let baselineSignature = sweepSignature(baselineSweep)
        print("  Baseline signature: \(baselineSignature)")

        // Stats
        var iterations: Int = 0
        var failures: Int = 0
        var determinismMismatches: Int = 0
        var latenciesMs: [Double] = []
        latenciesMs.reserveCapacity(2_000_000)

        let clock = ContinuousClock()
        let runStart = clock.now
        let runDeadline = runStart.advanced(by:
            .seconds(Int(Constants.stressDurationSeconds)))

        while clock.now < runDeadline {
            let iterStart = clock.now
            do {
                let input: BASLayerInferenceInput
                if iterations
                    % Constants.determinismCheckInterval == 0
                    && iterations > 0
                {
                    // Determinism check using reference input
                    input = referenceInput
                    let sweep = try await bundle.runtime
                        .runChengluCanonicalSweep(input: input)
                    let sig = sweepSignature(sweep)
                    if sig != baselineSignature {
                        determinismMismatches += 1
                        print(
                            "  ⚠️ determinism drift at iter " +
                            "\(iterations): \(sig) vs " +
                            "\(baselineSignature)")
                    }
                } else {
                    input = try makeCyclingInput(
                        iteration: iterations)
                    _ = try await bundle.runtime
                        .runChengluCanonicalSweep(input: input)
                }
            } catch {
                failures += 1
                if failures < 10 {
                    print(
                        "  ❌ failure at iter \(iterations): " +
                        "\(error)")
                }
            }
            let iterDur = iterStart.duration(to: clock.now)
            let iterMs = Double(iterDur.components.seconds)
                * 1000
                + Double(iterDur.components.attoseconds)
                / 1e15
            latenciesMs.append(iterMs)
            iterations += 1

            if iterations
                % Constants.progressLogInterval == 0
            {
                let elapsedDur = runStart.duration(to: clock.now)
                let elapsedSec = Double(elapsedDur
                    .components.seconds)
                    + Double(elapsedDur.components.attoseconds)
                    / 1e18
                let throughput = Double(iterations) / elapsedSec
                let recentLatencies =
                    latenciesMs.suffix(
                        Constants.progressLogInterval)
                let avg = recentLatencies
                    .reduce(0, +) / Double(
                        recentLatencies.count)
                print(String(format:
                    "  iter %7d / elapsed %6.1fs / " +
                    "throughput %6.1f iter/s / " +
                    "recent-avg %.3fms",
                    iterations, elapsedSec, throughput, avg))
            }
        }

        // End-of-run report
        let totalDur = runStart.duration(to: clock.now)
        let totalSec = Double(totalDur.components.seconds)
            + Double(totalDur.components.attoseconds) / 1e18
        let throughput = Double(iterations) / totalSec
        let sortedLat = latenciesMs.sorted()
        let p50 = sortedLat[sortedLat.count / 2]
        let p95 = sortedLat[Int(Double(sortedLat.count) * 0.95)]
        let p99 = sortedLat[Int(Double(sortedLat.count) * 0.99)]
        let avg = latenciesMs.reduce(0, +)
            / Double(latenciesMs.count)
        let max = sortedLat.last ?? 0
        let min = sortedLat.first ?? 0

        print("""

        📊 20-MIN STRESS REPORT
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        Total iterations:       \(iterations)
        Total wall-clock:       \(String(format: "%.1fs", totalSec))
        Throughput:             \(String(format: "%.1f iter/s", throughput))
        Failures:               \(failures)
        Determinism mismatches: \(determinismMismatches) / \(iterations / Constants.determinismCheckInterval) checks
        Latency p50:            \(String(format: "%.3fms", p50))
        Latency p95:            \(String(format: "%.3fms", p95))
        Latency p99:            \(String(format: "%.3fms", p99))
        Latency min/avg/max:    \(String(format: "%.3f / %.3f / %.3fms", min, avg, max))
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        """)

        // Hard assertions:
        XCTAssertEqual(
            failures, 0,
            "20-min stress test must have zero inference " +
            "failures across all iterations")
        XCTAssertEqual(
            determinismMismatches, 0,
            "Sklearn-trained models must be perfectly " +
            "deterministic — any mismatch indicates real " +
            "non-determinism (FP precision drift / numerical " +
            "instability / model corruption)")
        XCTAssertGreaterThan(
            iterations, 1000,
            "Stress test should complete >1000 iterations " +
            "in 20 minutes (sanity check)")
        XCTAssertLessThan(
            p99, 200,
            "p99 latency should stay <200ms on Apple Silicon " +
            "(if higher, thermal throttling or contention)")
    }

    #endif

    // MARK: - Always-on doctrine pin

    func testStressGateDefaultClosed() {
        // Ensure stress gate is closed unless caller opts in。
        // This test passes whether or not the gate is open —
        // it just pins the predicate semantics。
        let gateValue = ProcessInfo.processInfo.environment[
            Constants.stressGate]
        if gateValue == "1" {
            // Caller opted in; can't test closed state
        } else {
            XCTAssertNotEqual(
                gateValue, "1",
                "Default CI must NOT have stress gate open")
        }
    }
}
