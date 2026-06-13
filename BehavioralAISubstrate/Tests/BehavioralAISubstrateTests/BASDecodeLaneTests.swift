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

    // MARK: - Single-authority unification (the .scoutDefault → .scout byte-equal default)

    func testScoutDefaultPurposeRoutesToScoutPreset() {
        // The policy can now NAME today's default, so default call sites resolve THROUGH it byte-equal.
        XCTAssertEqual(BASDecodeLanePolicy.lane(for: .scoutDefault), .scout)
        XCTAssertEqual(BASDecodeLanePolicy.preset(for: .scoutDefault).name, BASOrganPreset.scout.name)
        XCTAssertEqual(
            BASDecodeLanePolicy.preset(for: .scoutDefault).temperature, BASOrganPreset.scout.temperature)
    }

    func testScoutLaneDoesNotEngageSpeculation() {
        // The new lane sits on the NON-speculative side of the doctrine→mechanism contract.
        XCTAssertFalse(BASDecodeLane.scout.engagesSpeculativeDecode)
        XCTAssertGreaterThan(BASDecodeLane.scout.preset.temperature, 0, "scout is temp 0.1, not greedy")
        XCTAssertFalse(BASDecodeLane.scout.isReproducible)
        XCTAssertEqual(BASDecodeLane.scout.preset.name, BASOrganPreset.scout.name)
    }

    func testEveryLanePresetMatchesGateExpectation() {
        // The contract, exhaustive: a lane engages spec-decode IFF its preset is temp 0 (the adapter gate).
        for lane in BASDecodeLane.allCases {
            XCTAssertEqual(lane.engagesSpeculativeDecode, lane.preset.temperature == 0,
                "\(lane).engagesSpeculativeDecode must equal (preset.temperature == 0)")
        }
        XCTAssertTrue(BASDecodeLane.greedy.engagesSpeculativeDecode)
        XCTAssertFalse(BASDecodeLane.sampling.engagesSpeculativeDecode)
        XCTAssertFalse(BASDecodeLane.scout.engagesSpeculativeDecode)
    }
}
