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

    // MARK: - Prompt-lookup eligibility (Track A SSD — gate the free-form −8% off, keep the repetitive wins)

    func testPromptLookupEligibleForFactualAndDeterministic() {
        // The lanes the iPhone-Air A/B measured net-positive (1.23×–2.05×, byte-identical 5/5).
        XCTAssertTrue(BASDecodeLanePolicy.promptLookupEligible(for: .factual),
            "RAG / extraction / verification reuse the prompt — the n-gram draft hits")
        XCTAssertTrue(BASDecodeLanePolicy.promptLookupEligible(for: .deterministic),
            "replay-spine turns are repetition by construction + byte-identical-safe under greedy verify")
    }

    func testPromptLookupNotEligibleForCreativeOrScoutDefault() {
        // creative measured 0.92× (−8%): the per-round n-gram scan isn't amortized when nothing is accepted.
        XCTAssertFalse(BASDecodeLanePolicy.promptLookupEligible(for: .creative),
            "free-form pays the scan with no acceptance — 亏的不要, gate it off")
        // scoutDefault: preserve the ADR-014 byte-equal default; also temp 0.1 ≠ 0 (not byte-valid for argmax accept).
        XCTAssertFalse(BASDecodeLanePolicy.promptLookupEligible(for: .scoutDefault),
            "default-on is a separate evidence-gated step; scout is temp 0.1 so argmax-accept isn't byte-valid")
    }

    func testPromptLookupEligibilityImpliesGreedyLane() {
        // The load-bearing INVARIANT: prompt-lookup byte-identity is a GREEDY property. Any purpose the policy
        // deems eligible MUST route to the greedy lane (temp 0) — else the argmax-equality accept changes bytes.
        for purpose in BASDecodeLanePolicy.Purpose.allCases where
            BASDecodeLanePolicy.promptLookupEligible(for: purpose) {
            let lane = BASDecodeLanePolicy.lane(for: purpose)
            XCTAssertEqual(lane, .greedy,
                "\(purpose) is prompt-lookup-eligible but does not map to the greedy lane")
            XCTAssertEqual(lane.preset.temperature, 0,
                "\(purpose) is prompt-lookup-eligible but its preset isn't temp 0 — byte-identity would break")
        }
    }

    // MARK: - P1 production purpose election (2026-07-13)

    /// A host that elected greedy (temp 0) gets `.deterministic` — the model-free repetitive
    /// lanes become production-eligible. Any other temperature stays `.scoutDefault`.
    func testProductionPurposeElectsDeterministicOnlyAtTempZero() {
        XCTAssertEqual(BASDecodeLanePolicy.productionPurpose(temperature: 0), .deterministic,
            "a host-elected greedy turn must unlock the model-free repetitive lanes")
        for temp in [0.1, 0.3, 0.7, 1.0] {
            XCTAssertEqual(BASDecodeLanePolicy.productionPurpose(temperature: temp), .scoutDefault,
                "temp \(temp) must keep the ADR-014 byte-equal default purpose")
        }
    }

    /// The elected purpose composes with the pinned invariants: the temp-0 election is prompt-
    /// lookup-eligible AND still maps to the greedy lane (no generation-param change); the scout
    /// election stays ineligible. Reverting productionPurpose to always-.scoutDefault reds this.
    func testProductionPurposeComposesWithEligibilityInvariants() {
        let greedy = BASDecodeLanePolicy.productionPurpose(temperature: 0)
        XCTAssertTrue(BASDecodeLanePolicy.promptLookupEligible(for: greedy),
            "the temp-0 election exists precisely to make prompt-lookup production-eligible")
        XCTAssertEqual(BASDecodeLanePolicy.lane(for: greedy), .greedy,
            "the election must not change the lane a temp-0 host already chose")
        let scout = BASDecodeLanePolicy.productionPurpose(temperature: 0.1)
        XCTAssertFalse(BASDecodeLanePolicy.promptLookupEligible(for: scout),
            "the default (temp 0.1) path must remain byte-equal — no model-free lane")
        // NaN discipline (P0-5 family): a NaN temperature is NOT greedy-byte-safe → scout default.
        XCTAssertEqual(BASDecodeLanePolicy.productionPurpose(temperature: .nan), .scoutDefault,
            "NaN temperature must fail closed to the default purpose")
    }
}
