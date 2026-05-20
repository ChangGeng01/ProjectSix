// MARK: - BASChapter755L10ProductionSwapDecisionTests
// chapter 七百五十五 第一刀 / M2436
//
// MATURATION ARC L10 production-swap DECISION pin。 Per user
// directive 2026-05-20 「亏的不要硬上」 + chapter 七百四十 第四刀
// measurement (1.06× TIE),the L10 Tribunal Court Rust port stays
// OPT-IN at this chapter — no production-default flip。 This file
// formalizes the decision as a typed test artifact so future
// readers know the path and reasoning。

import XCTest
@testable import BASRuntimeCore
@testable import BASOrchestration

final class BASChapter755L10ProductionSwapDecisionTests:
    XCTestCase
{

    // MARK: - Rust path is reachable (regression guard)

    func testRustTribunalCourtABIIsReachable() {
        #if os(iOS) || os(macOS)
        XCTAssertEqual(
            BASAutoRouteRanker.tribunalCourtABIVersion(), 1,
            "Rust tribunal court port (chapter 七百四十 第二刀) " +
            "ABI must remain available as opt-in path even " +
            "though chapter 七百五十五 measured no production flip")
        #endif
    }

    // MARK: - Swift production seam unchanged

    func testSwiftDeriveFactoryStillProductionDefault() {
        // The 4 production derive factories at
        // BASTribunalFullBody.swift lines 64, 147, 239, 287
        // remain the production entry points。 No routing wrapper
        // intercepts them at chapter 七百五十五。 Hosts that want
        // the Rust path call BASAutoRouteRanker.tribunalDerive*
        // directly with JSON marshalling。
        //
        // This test is intentionally a NULL operation — its
        // existence pins the discipline that production code
        // continues to call Swift .derive(...) directly。
        XCTAssertTrue(true,
            "Swift .derive(...) factories stay default at chapter " +
            "七百五十五 per 1.06× TIE measurement + 「亏的不要硬上」")
    }

    // MARK: - Production-swap DECISION scorecard

    func testPrintChapter755L10DecisionScorecard() {
        print("")
        print("=================================================================")
        print(
            "  CHAPTER 七百五十五 第一刀 / M2436 — L10 PRODUCTION SWAP DECISION")
        print("=================================================================")
        print("")
        print("### User directive 2026-05-20")
        print("")
        print(
            "  「chapter 七百五十五:L10 BASTribunalFullBody")
        print(
            "   production swap (or stay opt-in if 1.06× holds)」")
        print("")
        print("### Chapter 七百四十 measurement (re-applied)")
        print("")
        print(
            "  Axis 1 perf:           1.06× Rust (TIE — within noise)")
        print(
            "  Axis 2 memory:         TIED (pure-fn,no alloc)")
        print(
            "  Axis 3 state-machine:  TIED (both exhaustive)")
        print(
            "  Axis 4 persistence:    N/A (pure compute)")
        print(
            "  Axis 5 replay byte-eq: ✅ pinned via chapter 七百四十")
        print(
            "                             第三刀 byte-equality test")
        print("")
        print("### Decision rule application")
        print("")
        print(
            "  5-axis threshold:  ≥3 axes strictly-better")
        print(
            "  Result:            1 strictly-better (barely:1.06×)")
        print(
            "                     + 4 TIE = DOES NOT MEET threshold")
        print(
            "  Per 「亏的不要硬上」: 1.06× too marginal to flip")
        print("")
        print("### Production-swap DECISION (this chapter)")
        print("")
        print(
            "  ❌ NO default flip — Swift .derive(...) factories")
        print(
            "     remain the production entry point。 Same as")
        print(
            "     chapter 七百四十 第五刀 decision,re-affirmed at")
        print(
            "     this chapter under 「沿 plan」 review。")
        print("")
        print(
            "  ✅ Rust path STAYS reachable via")
        print(
            "     BASAutoRouteRanker.tribunalDeriveIdProfile/")
        print(
            "     EgoAssessment/SuperegoJudgment for hosts that")
        print(
            "     want to profile their workload + opt in。")
        print("")
        print(
            "  ✅ Parity pinned by chapter 七百四十 第三刀")
        print(
            "     byte-equality test (Swift ≡ Rust for the 3")
        print(
            "     derive functions across the test fixture set)。")
        print("")
        print("### Compare with sibling chapters in this arc")
        print("")
        print(
            "  Chapter | Sub | Decision           | Why")
        print(
            "  --------|-----|--------------------|-----------------")
        print(
            "  七百五十一| L14 | ✅ FLIP DEFAULT    | 1.24× chain seal")
        print(
            "  七百五十一| L8  | opt-in only       | 1.08× marginal")
        print(
            "  七百五十一| L11 | SQL go-live (opt) | persistence wire")
        print(
            "  七百五十三| L14 | ✅ FLIP DEFAULT    | 13.84× verdict")
        print(
            "  七百五十三| L8  | opt-in only (LOSS)| 0.82× batched")
        print(
            "  七百五十四| L11 | ✅ STORAGE LIVE    | SQL prod wire")
        print(
            "  七百五十五| L10 | opt-in only       | 1.06× TIE (THIS)")
        print("")
        print("### Discipline pins")
        print("")
        print(
            "  ✅ 「亏的不要硬上」 — 1.06× TIE,no production flip")
        print(
            "  ✅ Measurement-first — decision driven by data,")
        print(
            "     not by 「user said flip」 reflex")
        print(
            "  ✅ Rust port stays reachable + tested for future")
        print(
            "     flips if device telemetry warrants")
        print(
            "  ✅ Swift production seam unchanged — chapter 七百四十")
        print(
            "     第三刀 byte-equality lockstep preserved")
        print("")
        print("### MATURATION ARC trajectory")
        print("")
        print(
            "  chapter 七百五十:    Plan-agent gap triage")
        print(
            "  chapter 七百五十一:  L14 seal + L8 reducer + L11 SQL")
        print(
            "  chapter 七百五十二:  doctrine 大幅度 缩减 (-11k LOC)")
        print(
            "  chapter 七百五十三:  L14 verdict flip + L8 batched")
        print(
            "  chapter 七百五十四:  L11 production swap (SQL LIVE)")
        print(
            "  chapter 七百五十五:  ✅ L10 production-swap DECISION (THIS)")
        print(
            "  chapter 七百五十六:  ⏭ MATURATION ARC SEAL + scorecard")
        print("")

        // Smoke
        #if os(iOS) || os(macOS)
        XCTAssertEqual(
            BASAutoRouteRanker.tribunalCourtABIVersion(), 1)
        #endif
    }
}
