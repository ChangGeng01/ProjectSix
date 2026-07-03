import XCTest
@testable import BASOrgan
@testable import BASMLXAdapter

/// Ship-cert planner integration for the .mtpSpec lane (checklist §2): own floor (NOT 2.7), entropy-gate
/// exemption, default-off byte-equality, temperature gate, profiler-floor drop.
final class BASMTPPlannerIntegrationTests: XCTestCase {

    private func caps(mtp: Bool) -> BASDecodeCapabilities {
        BASDecodeCapabilities(draftModelLoaded: false, saguaroAvailable: false,
                              modelFreeAvailable: false, mtpHeadLoaded: mtp)
    }

    func testDefaultOffIsByteEqual() {
        let s = BASDecodeLanePolicy.decodeStrategy(
            purpose: .factual, temperature: 0, capabilities: caps(mtp: false),
            profiler: BASAcceptanceProfiler())
        XCTAssertEqual(s, BASDecodeStrategy.plain)
    }

    func testOptInRoutesToMTPWhenGreedy() {
        let s = BASDecodeLanePolicy.decodeStrategy(
            purpose: .factual, temperature: 0, capabilities: caps(mtp: true),
            profiler: BASAcceptanceProfiler())
        XCTAssertEqual(s, BASDecodeStrategy.mtpSpec, "cold MTP must engage (device-certified a=0.85 >> floor 0.15)")
    }

    func testTemperatureGateForcesPlain() {
        let s = BASDecodeLanePolicy.decodeStrategy(
            purpose: .factual, temperature: 0.7, capabilities: caps(mtp: true),
            profiler: BASAcceptanceProfiler())
        XCTAssertEqual(s, BASDecodeStrategy.plain, "byte-safety: no speculation at temperature > 0")
    }

    func testEntropyGateDoesNotExileMTP() {
        let s = BASDecodeLanePolicy.decodeStrategy(
            purpose: .factual, temperature: 0, capabilities: caps(mtp: true),
            profiler: BASAcceptanceProfiler(), topTokenEntropy: 5.0)
        XCTAssertEqual(s, BASDecodeStrategy.mtpSpec, "MTP is purpose-independent — must survive high entropy")
    }

    func testOwnFloorDropsCollapsedLane() {
        var p = BASAcceptanceProfiler()
        for _ in 0 ..< 8 {
            p = p.observing(sourceID: BASDecodeStrategy.mtpSpecID, purpose: .factual,
                            accepted: 0, proposed: 10, rounds: 10)
        }
        let s = BASDecodeLanePolicy.decodeStrategy(
            purpose: .factual, temperature: 0, capabilities: caps(mtp: true), profiler: p)
        XCTAssertEqual(s, BASDecodeStrategy.plain, "collapsed acceptance must drop the lane (wiring-break detector)")
    }

    func testThermalGateDropsToPlain() {
        let s = BASDecodeLanePolicy.decodeStrategy(
            purpose: .factual, temperature: 0, capabilities: caps(mtp: true),
            profiler: BASAcceptanceProfiler(), thermalThrottled: true)
        XCTAssertEqual(s, BASDecodeStrategy.plain,
                       "cert finding: spec is net-negative under serious throttle (0.52-0.62x) — never-worse gate")
    }

    func testHealthyStatsKeepLane() {
        var p = BASAcceptanceProfiler()
        for _ in 0 ..< 8 {
            p = p.observing(sourceID: BASDecodeStrategy.mtpSpecID, purpose: .factual,
                            accepted: 85, proposed: 100, rounds: 100)   // a=0.85 per round (device cert)
        }
        let s = BASDecodeLanePolicy.decodeStrategy(
            purpose: .factual, temperature: 0, capabilities: caps(mtp: true), profiler: p)
        XCTAssertEqual(s, BASDecodeStrategy.mtpSpec)
    }
}

/// Default-ON resolution (operator-elected 2026-07-03): canonical discovery + kill-switch.
final class BASMTPDefaultOnTests: XCTestCase {
    func testAutoResolutionFindsCanonicalWeights() throws {
        // Mac dev canonical path (staged by the campaign tooling)
        guard FileManager.default.fileExists(atPath: "/tmp/gdn_coreai/qwen35_mtp_folded.safetensors") else {
            throw XCTSkip("canonical weights not staged")
        }
        let organ = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)          // NO explicit URL
        XCTAssertNotNil(organ._resolveMTPWeightsURL(), "default-ON must discover canonical weights")
    }

    func testKillSwitchDisablesResolution() {
        let organ = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit, mtpSpecEnabled: false)
        XCTAssertNil(organ._resolveMTPWeightsURL(), "kill-switch must disable the lane entirely")
    }

    func testNonQwenModelNeverResolves() {
        let organ = MLXOrganAdapter(model: MLXModelCatalog.llama3_2_3B_4bit)
        XCTAssertNil(organ._resolveMTPWeightsURL(), "the MTP head is Qwen3.5's — never offered elsewhere")
    }
}
