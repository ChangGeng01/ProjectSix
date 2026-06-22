// MARK: - BASDecodeStrategyTests — the single decode-strategy planner (Option-3, additive S2)
//
// Pins BASDecodeLanePolicy.decodeStrategy(...): the pure planner that replaces the electAccelerated Bool + the
// scattered greedy gates. Verifies the byte-safety gate (temp==0), purpose eligibility, capability gating, the
// cold-start priority (draftModel > saguaro > model-free), profiler-driven ranking, the hit-floor fallback, and
// warm-started K. The planner is NOT yet wired into the adapter (S3 does that at parity).

import XCTest
@testable import BASOrgan

final class BASDecodeStrategyTests: XCTestCase {

    typealias P = BASDecodeLanePolicy.Purpose
    private let all = BASDecodeCapabilities(draftModelLoaded: true, saguaroAvailable: true, modelFreeAvailable: true)
    private let mfOnly = BASDecodeCapabilities(draftModelLoaded: false, saguaroAvailable: false, modelFreeAvailable: true)
    private let nothing = BASDecodeCapabilities(draftModelLoaded: false, saguaroAvailable: false, modelFreeAvailable: false)
    private let draftOnly = BASDecodeCapabilities(draftModelLoaded: true, saguaroAvailable: false, modelFreeAvailable: false)

    private func plan(_ purpose: P, _ temp: Double, _ caps: BASDecodeCapabilities,
                      _ prof: BASAcceptanceProfiler = BASAcceptanceProfiler(), k: Int = 4) -> BASDecodeStrategy {
        BASDecodeLanePolicy.decodeStrategy(
            purpose: purpose, temperature: temp, capabilities: caps, profiler: prof, numDraftTokens: k)
    }

    // 1. The hard byte-safety gate: any temperature > 0 → plain, regardless of caps/profiler.
    func testNonGreedyAlwaysPlain() {
        XCTAssertEqual(plan(.factual, 0.7, all), .plain)
        XCTAssertEqual(plan(.deterministic, 0.1, all), .plain)
    }

    // 2a. Non-eligible purpose with NO draft model → plain (model-free + saguaro are purpose-gated).
    func testNonEligibleNoDraftModelPlain() {
        XCTAssertEqual(plan(.creative, 0, mfOnly), .plain)
        XCTAssertEqual(plan(.scoutDefault, 0, mfOnly), .plain)
    }

    // 2b. Non-eligible purpose WITH a draft model → still draftModelSpec: draft-spec is byte-identical and runs for
    //     ANY greedy turn regardless of purpose (preserves the legacy draft(), which spec'd regardless of elect).
    func testNonEligibleWithDraftModelStillSpecs() {
        guard case .draftModelSpec = plan(.scoutDefault, 0, all) else {
            return XCTFail(".scoutDefault + draft model should still draftModelSpec (not purpose-gated)")
        }
        guard case .draftModelSpec = plan(.creative, 0, all) else {
            return XCTFail(".creative + draft model should still draftModelSpec")
        }
    }

    // 3. No capabilities → plain.
    func testNoCapabilitiesPlain() {
        XCTAssertEqual(plan(.factual, 0, nothing), .plain)
    }

    // 4. Model-free only, cold → suffixLookup (the cross-turn superset is the cold-start model-free pick).
    func testModelFreeColdPrefersSuffix() {
        guard case .suffixLookup = plan(.factual, 0, mfOnly) else {
            return XCTFail("cold model-free should be .suffixLookup")
        }
    }

    // 5. All lanes available, cold → draftModelSpec (capability priority: model-backed first).
    func testAllColdPrefersDraftModel() {
        guard case .draftModelSpec = plan(.factual, 0, all) else {
            return XCTFail("cold all-available should be .draftModelSpec")
        }
    }

    // 6. Saguaro available, no draft model, cold → saguaro (next in priority).
    func testSaguaroColdWhenNoDraftModel() {
        let caps = BASDecodeCapabilities(draftModelLoaded: false, saguaroAvailable: true, modelFreeAvailable: true)
        guard case .saguaro = plan(.factual, 0, caps) else {
            return XCTFail("cold (saguaro + model-free) should be .saguaro")
        }
    }

    // 7. Profiler-driven: a warm high-acceptance model-free lane beats a cold draft-model lane.
    func testWarmModelFreeBeatsColdDraftModel() {
        var prof = BASAcceptanceProfiler()
        // prompt-lookup warm, emaAccepted=4, hit=1.0; suffix warm but lower so source(for:) picks prompt-lookup.
        prof = prof.observing(sourceID: BASDraftSourceChoice.promptLookupID, purpose: .factual, accepted: 8, proposed: 8, rounds: 2)
        prof = prof.observing(sourceID: BASDraftSourceChoice.suffixAutomatonID, purpose: .factual, accepted: 1, proposed: 8, rounds: 4)
        guard case .promptLookup = plan(.factual, 0, all, prof) else {
            return XCTFail("warm high-acceptance prompt-lookup should beat cold draft-model")
        }
    }

    // 8. Hit-floor fallback: every model-free lane below the floor → plain.
    func testHitFloorFallsBackToPlain() {
        var prof = BASAcceptanceProfiler()
        prof = prof.observing(sourceID: BASDraftSourceChoice.suffixAutomatonID, purpose: .factual, accepted: 1, proposed: 100, rounds: 1)
        prof = prof.observing(sourceID: BASDraftSourceChoice.promptLookupID, purpose: .factual, accepted: 1, proposed: 100, rounds: 1)
        XCTAssertEqual(plan(.factual, 0, mfOnly, prof), .plain, "all model-free lanes below hit floor → plain")
    }

    // 9. Cold warm-start K = the cap passed in.
    func testColdRecommendedKIsCap() {
        XCTAssertEqual(plan(.factual, 0, all, BASAcceptanceProfiler(), k: 6), .draftModelSpec(numDraftTokens: 6))
    }

    // 10. The existing model-free router is unchanged by composition (sanity: acceleratedChoice still pins it).
    func testModelFreeSubDecisionStillPinned() {
        // mirrors BASDraftSourceRouter: greedy factual, cold → suffixAutomaton.
        XCTAssertEqual(
            BASDecodeLanePolicy.acceleratedChoice(temperature: 0, purpose: .factual, profiler: BASAcceptanceProfiler()),
            .suffixAutomaton)
    }

    // 11. Draft-MODEL net-positive floor (Gate 2b cost-aware gate). The draft-model lane is high-cost (a full draft
    //     forward / token), so once MEASURED below the ≈2.7 accepted-per-round break-even it's a latency LOSS and must
    //     fall back to plain — even though its hit-rate (0.5) clears the cheap model-free floor (0.05).
    func testDraftModelBelowNetPositiveFloorFallsBackToPlain() {
        let prof = BASAcceptanceProfiler().observing(
            sourceID: BASDecodeStrategy.draftModelID, purpose: .scoutDefault, accepted: 8, proposed: 16, rounds: 4) // a=2.0
        XCTAssertEqual(plan(.scoutDefault, 0, draftOnly, prof), .plain,
                       "draft-model measured a=2.0 (<2.7 break-even, free-form) ⇒ latency loss ⇒ fall back to plain")
    }

    // 12. Above break-even (reasoning-like a=3.0 ≥ 2.7) ⇒ the draft-model lane is net-positive ⇒ kept.
    func testDraftModelAboveNetPositiveFloorStillSpecs() {
        let prof = BASAcceptanceProfiler().observing(
            sourceID: BASDecodeStrategy.draftModelID, purpose: .scoutDefault, accepted: 12, proposed: 16, rounds: 4) // a=3.0
        guard case .draftModelSpec = plan(.scoutDefault, 0, draftOnly, prof) else {
            return XCTFail("draft-model measured a=3.0 (≥2.7) should keep draftModelSpec")
        }
    }

    // 13. Cold (no measurement yet) ⇒ kept, to engage once and gather the acceptance data — the net-positive floor
    //     only applies once there IS a measurement (otherwise the lane could never learn its own acceptance).
    func testColdDraftModelStaysToLearn() {
        guard case .draftModelSpec = plan(.scoutDefault, 0, draftOnly) else {
            return XCTFail("cold draft-model should stay in to learn (draftModelSpec)")
        }
    }

    // 14. ReSpec ENTROPY GATE (telemetry-free never-worse safety): a HIGH next-token entropy (novel/free-form region)
    //     drops the COLD draft-model lane EVEN THOUGH #13 would otherwise keep it — turning the free-form regime from
    //     the measured 0.88× LOSS into plain (~1.0×). nil entropy (not fed) ⇒ unchanged; low entropy ⇒ kept.
    private func planH(_ p: P, _ caps: BASDecodeCapabilities, _ h: Double?) -> BASDecodeStrategy {
        BASDecodeLanePolicy.decodeStrategy(
            purpose: p, temperature: 0, capabilities: caps, profiler: BASAcceptanceProfiler(), topTokenEntropy: h)
    }
    func testEntropyGateDropsColdDraftModelOnHighEntropy() {
        XCTAssertEqual(planH(.scoutDefault, draftOnly, 5.0), .plain,
                       "high entropy (>3.0 bits) drops the COLD draft-model lane → plain (never-worse on free-form)")
        guard case .draftModelSpec = planH(.scoutDefault, draftOnly, 0.5) else {
            return XCTFail("low entropy should KEEP the draft-model lane")
        }
        guard case .draftModelSpec = planH(.scoutDefault, draftOnly, nil) else {
            return XCTFail("nil entropy (not fed) must NOT change behaviour (cold draft-model stays, == #13)")
        }
    }

    // 15. The gate removes ONLY the costly draft-MODEL lane: with model-free also available + an eligible purpose, a
    //     high-entropy turn falls back to a model-free lane (≈0 cost), NOT all the way to plain.
    func testEntropyGateFallsBackToModelFreeWhenEligible() {
        switch planH(.factual, all, 5.0) {
        case .promptLookup, .suffixLookup: break   // model-free fallback — correct
        case let s: XCTFail("high entropy + .factual + model-free available → model-free lane, got \(s)")
        }
    }
}
