import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore
@testable import BASObservability

/// M359 — pin substrate contracts that
/// `QinaoSampleHost --full-stack-bench` relies on.
///
/// Sample-host benches are not directly importable. This file
/// pins the substrate primitives the bench composes:
///
///   1. `BASHostRuntime` can be constructed with the bench
///      configuration shape (M359-style label-prefixed
///      identifiers) without throwing.
///   2. `runtime.startSession(_:)` returns a result with a
///      non-nil `eBrainTurn` for the canonical bench request
///      shape.
///   3. Multiple sequential `BASHostRuntime` instances are
///      independently constructable (no global state collision).
///   4. `BASBenchLatencyStats` (M355) compute over per-session
///      latencies produces sensible stats for the bench
///      collection shape.
final class M359FullStackBenchTests: XCTestCase {

    private func makeRuntime(
        label: String
    ) -> BASHostRuntime {
        BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID:
                    "host.m359.test.\(label)",
                policyProfileID:
                    "host.m359.test.\(label).policy",
                prefersPureLocal: true,
                defaultDeviceState:
                    BASHostConfiguration
                        .fixtureDefaultDeviceState,
                console: .generic,
                lifecycleBehavior: .generic,
                workflowBehavior: .generic,
                cognitionBehavior: .generic,
                presentation: .generic,
                runtimeTuning:
                    BASEBrainRuntimeSynthesisPolicy
                        .generic
                        .withSchemaVersion(
                            "host.runtime-synthesis." +
                            "m359.test.\(label).v1"),
                runtimePolicyLineage:
                    BASRuntimePolicyLineage(
                        bundleVersion:
                            "host.m359.test.\(label).bundle.v1",
                        providerRoutingRegistryVersion:
                            "host.m359.test.\(label).rrv.v1",
                        providerRoutingPolicyID:
                            "host.m359.test.\(label).rp.v1",
                        runtimeTuningRegistryVersion:
                            "host.m359.test.\(label).trv.v1",
                        runtimeTuningPolicyID:
                            "host.m359.test.\(label).tp.v1",
                        resolutionSourceID: "m359_test"),
                hostRhythmProfile: .generic))
    }

    func testRuntimeConstructsWithBenchConfiguration() {
        let runtime = makeRuntime(label: "single")
        XCTAssertNotNil(runtime)
    }

    func testStartSessionReturnsEBrainTurn() throws {
        let runtime = makeRuntime(label: "session")
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: "test prompt",
                title: "test title",
                riskLevel: .medium))
        XCTAssertNotNil(result.eBrainTurn)
    }

    func testMultipleRuntimesAreIndependent() throws {
        for i in 0..<3 {
            let runtime = makeRuntime(label: "n\(i)")
            let result = try runtime.startSession(
                BASHostSessionRequest(
                    kind: .interactive,
                    workflowProfile: .reflective,
                    surface: .application,
                    prompt: "session \(i)",
                    title: "test",
                    riskLevel: .medium))
            XCTAssertNotNil(result.eBrainTurn)
        }
    }

    func testBenchStatsComputeOverPerSessionLatencies() {
        // Synthesize plausible per-session latencies (3 cold,
        // 7 warm).
        let samples = [
            45.0, 12.0, 38.0,  // cold-start spikes
            5.5, 5.2, 5.4, 5.3, 5.5, 5.4, 5.6,  // warm
        ]
        let stats = BASBenchLatencyStats.compute(
            samples: samples)!
        XCTAssertEqual(stats.sampleCount, 10)
        XCTAssertEqual(stats.min, 5.2)
        XCTAssertEqual(stats.max, 45.0)
        // p50 = nearest-rank ceil(0.5*10)-1 = 4 → samples sorted[4]
        // sorted = [5.2, 5.3, 5.4, 5.4, 5.5, 5.5, 5.6, 12.0, 38.0, 45.0]
        // index 4 → 5.5
        XCTAssertEqual(stats.p50, 5.5)
        // Mean: (45+12+38+5.5+5.2+5.4+5.3+5.5+5.4+5.6) / 10 = 13.29
        XCTAssertEqual(stats.mean, 13.29, accuracy: 0.01)
        // Coefficient of variation high (cold-start outliers
        // dominate variance).
        XCTAssertGreaterThan(
            stats.coefficientOfVariation, 0.5)
    }
}
