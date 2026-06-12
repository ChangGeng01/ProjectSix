// MARK: - BASDecodeLaneTests — A2 decode dual-lane policy gate
//
// Pins the doctrine: deterministic/factual → greedy (engages spec-decode, byte-reproducible, temp 0);
// creative → sampling (diverse, single-model, temp 0.7). The greedy lane's preset MUST satisfy the
// spec-decode gate (temperature == 0) or the +31% never engages — that linkage is the load-bearing
// claim and is pinned here.

import XCTest
@testable import BASOrgan

final class BASDecodeLaneTests: XCTestCase {

    func testGreedyLaneUsesTempZeroPreset() {
        XCTAssertEqual(BASDecodeLane.greedy.preset.temperature, 0,
            "the greedy lane MUST be temperature 0 — the spec-decode gate " +
            "(requestEligibleForSpeculation) requires temp==0; any non-zero " +
            "means the certified +31% never engages")
        XCTAssertEqual(BASDecodeLane.greedy.preset.name, "bas.greedy.v1")
        XCTAssertTrue(BASDecodeLane.greedy.isReproducible)
    }

    func testSamplingLaneUsesCorePreset() {
        XCTAssertGreaterThan(BASDecodeLane.sampling.preset.temperature, 0,
            "the sampling lane must be temperature > 0 (single-model diverse)")
        XCTAssertEqual(BASDecodeLane.sampling.preset.name, "bas.core.v1")
        XCTAssertFalse(BASDecodeLane.sampling.isReproducible)
    }

    func testPolicyRoutesDeterministicAndFactualToGreedy() {
        XCTAssertEqual(BASDecodeLanePolicy.lane(for: .deterministic), .greedy,
            "replay-spine / reproducible turns must take the greedy lane")
        XCTAssertEqual(BASDecodeLanePolicy.lane(for: .factual), .greedy,
            "structured extraction benefits from greedy reproducibility + speed")
        XCTAssertEqual(
            BASDecodeLanePolicy.preset(for: .deterministic).temperature, 0)
    }

    func testPolicyRoutesCreativeToSampling() {
        XCTAssertEqual(BASDecodeLanePolicy.lane(for: .creative), .sampling,
            "creative user-facing turns keep sampling for output diversity")
        XCTAssertGreaterThan(
            BASDecodeLanePolicy.preset(for: .creative).temperature, 0)
    }

    func testEveryPurposeMapsAndEveryGreedyPresetGatesSpeculation() {
        // Exhaustive: every purpose resolves a lane, and any greedy-lane preset satisfies the gate.
        for purpose in BASDecodeLanePolicy.Purpose.allCases {
            let lane = BASDecodeLanePolicy.lane(for: purpose)
            if lane == .greedy {
                XCTAssertEqual(lane.preset.temperature, 0,
                    "greedy preset for \(purpose) must gate spec-decode (temp==0)")
            }
        }
    }
}
