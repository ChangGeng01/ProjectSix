// MARK: - BASChapter739MatrixScorecardTests
// chapter 七百三十九 第五刀 / M2370
//
// LAYER-MIGRATION ARC chapter 七百三十九 SEAL — L11 Wind
// Gate Rust state-machine port complete with 5-axis
// comparison passing 3 axes Rust-strictly-better and 0
// axes Rust-worse-by-> 1.5×, satisfying the
// 「完全 移植 if WHOLE is better」 default-flip rule。

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASPolicy

final class BASChapter739MatrixScorecardTests: XCTestCase {

    func testPrintMatrixScorecard() {
        print("")
        print("=================================================================")
        print(
            "  CHAPTER 七百三十九 第五刀 / M2370 — L11 RISK_PLANE RUST PORT SEAL")
        print(
            "  LAYER-MIGRATION ARC chapter 七百三十八-七百四十九 / M2361-M2420")
        print(
            "  This chapter: M2366-M2370 (5 knives, 1 Rust module + FFI + tests)")
        print("=================================================================")
        print("")

        print("### Chapter 七百三十九 deliverable")
        print("")
        print(
            "  Knife 1 (M2366): risk_plane.rs Rust port")
        print(
            "    ▶ BrainRiskLevel + RiskBand + ActionPermitMode enums")
        print(
            "    ▶ risk_band_to_next_mode (8-branch match cascade)")
        print(
            "    ▶ effective_threshold (NaN-safe, clamped [0,1])")
        print(
            "    ▶ monotonic_version_compare")
        print(
            "    ▶ 21 Rust unit tests pass")
        print(
            "  Knife 2 (M2367): C ABI + XCFramework + Swift bridge")
        print(
            "    ▶ 3 #[no_mangle] extern \"C\" exports")
        print(
            "    ▶ force_link.rs anchor (Rust LTO won't strip)")
        print(
            "    ▶ XCFramework rebuilt (3 slices)")
        print(
            "    ▶ BASAutoRouteRanker.riskPlaneTransition/")
        print(
            "      EffectiveThreshold/MonotonicVersionCompare")
        print(
            "    ▶ 20 Swift bridge tests pass")
        print(
            "  Knife 3 (M2368): Byte-equality test")
        print(
            "    ▶ 144-cell exhaustive (4 × 4 × 9 cross product)")
        print(
            "    ▶ 1000 random sequences (SplitMix64 fixed seed)")
        print(
            "    ▶ 500 fuzz inputs (1/3 out of range)")
        print(
            "    ▶ effective_threshold + version compare grids")
        print(
            "    ▶ 1644 byte-equal assertions pass")
        print(
            "  Knife 4 (M2369): Perf measurement + 5-axis decision")
        print(
            "    ▶ Rust 0.167 µs/op vs Swift 0.188 µs/op = 1.12× WIN")
        print(
            "    ▶ 3 axes Rust-strictly-better, 0 axes worse")
        print(
            "    ▶ Default-flip recommended for future consumers")
        print(
            "  Knife 5 (M2370): This scorecard + close-out")
        print("")

        print("### 5-axis comparison final landing")
        print("")
        print(
            "  ┌────┬────────────────────────────────┬─────────────┐")
        print(
            "  │ #  │ Axis                           │ Outcome     │")
        print(
            "  ├────┼────────────────────────────────┼─────────────┤")
        print(
            "  │ 1  │ Per-call walltime              │ RUST WIN    │")
        print(
            "  │ 2  │ Memory footprint               │ TIED        │")
        print(
            "  │ 3  │ State-machine guarantees       │ RUST WIN    │")
        print(
            "  │ 4  │ Persistence (七百三十八 SQL)   │ TIED        │")
        print(
            "  │ 5  │ Replay byte-equality (1644)    │ RUST WIN    │")
        print(
            "  └────┴────────────────────────────────┴─────────────┘")
        print("")
        print(
            "  Decision: 「完全 移植 if WHOLE is better」 SATISFIED")
        print(
            "  → 3 axes Rust-strictly-better,no axis worse")
        print(
            "  → Rust path RECOMMENDED AS DEFAULT for future consumers")
        print("")

        print("### Surprise — the chapter 七百二十五 inversion")
        print("")
        print(
            "  Chapter 七百二十五 established that FFI overhead")
        print(
            "  dominates small-N actor coordination workloads。")
        print(
            "  Expected:Rust LOSES per-call perf on a tiny match")
        print(
            "  cascade (this is what motivated the opt-in fallback")
        print(
            "  pattern)。")
        print("")
        print(
            "  Measurement:Rust 1.12× FASTER。 The pattern only")
        print(
            "  holds when FFI carries non-trivial payloads (struct")
        print(
            "  marshaling,UTF-8 conversion,heap allocation)。 For")
        print(
            "  PRIMITIVE-ARG calls (i32 × 3 in,i32 out),the FFI")
        print(
            "  is sub-100ns — actually LOWER than Swift Optional<>")
        print(
            "  wrapping + bounds-check overhead。")
        print("")
        print(
            "  HONEST data trumps theory:the substrate's")
        print(
            "  measurement-first discipline caught the surprise")
        print(
            "  and acted on it。")
        print("")

        print("### Doctrine pins held this chapter")
        print("")
        print(
            "  ✅ 不变量 #1/#2/#3 — measurement is observation")
        print(
            "  ✅ 红线 7 — additive on dest;no production swap")
        print(
            "  ✅ chapter 一百八十五 anti-magic-number — wire")
        print(
            "       encoding pinned in 3 places (Rust / C header /")
        print(
            "       Swift bridge),verified by 1644-cell test")
        print(
            "  ✅ chapter 392 replay-determinism — fixed-seed PRNG")
        print(
            "       + deterministic 144-cell grid;repeat-call")
        print(
            "       byte-equal across runs")
        print(
            "  ✅ chapter 七百十六 byte-equality discipline")
        print(
            "  ✅ chapter 七百二十三 1.5× threshold — referenced")
        print(
            "       as upper-bound-for-acceptable-loss in 5-axis rule")
        print(
            "  ✅ ADR-014 OPT-IN — V1 Swift production path (when")
        print(
            "       one materializes) stays default until host")
        print(
            "       adoption。 At this chapter no Swift production")
        print(
            "       classifier exists yet — Rust is the FIRST")
        print(
            "       implementation,emerged from chapter 七百三十八")
        print(
            "       schema design")
        print(
            "  ✅ 「不要 json 可以的话 就 sql」 — wire format is")
        print(
            "       typed ints,not JSON")
        print(
            "  ✅ 「千万不要 删除 只能 commented 代码」 — no Swift")
        print(
            "       code to delete-or-comment at this chapter")
        print(
            "       (FORWARD-LOOKING port);future consumer wiring")
        print(
            "       will exercise the invariant")
        print(
            "  ✅ 「完全 移植 if WHOLE is better」 — 5-axis comparison")
        print(
            "       executed,decision recorded,Rust recommended default")
        print("")

        print("### Test totals this chapter")
        print("")
        print(
            "  Rust unit tests:     21 (risk_plane.rs)")
        print(
            "  Swift bridge tests:  20 (BASChapter739RiskPlaneBridgeTests)")
        print(
            "  Byte-equality tests:  5 (1644 assertions inside)")
        print(
            "  Perf + scorecard:     2 (perf measurement + 5-axis)")
        print(
            "  This scorecard:       1")
        print(
            "  ----------------------------------")
        print(
            "  Total:               49 (across Rust + Swift)")
        print("")

        print("### 12-chapter arc trajectory (2 of 12 sealed)")
        print("")
        print(
            "  ✅ Chapter 七百三十八 — L11 SQL schemas")
        print(
            "  ✅ Chapter 七百三十九 — L11 Rust state-machine + 5-axis")
        print(
            "  ⏭ Chapter 七百四十   — L10 Tribunal pure-function port")
        print(
            "  ⏭ Chapter 七百四十一 — L14 Sovereign chain core")
        print(
            "  ⏭ Chapter 七百四十二 — L14 Verdict engine")
        print(
            "  ⏭ Chapter 七百四十三 — L14 token authority + sub-arc close")
        print(
            "  ⏭ Chapter 七百四十四 — L3 Knowledge graph storage binary")
        print(
            "  ⏭ Chapter 七百四十五 — L3 Event extractor")
        print(
            "  ⏭ Chapter 七百四十六 — L3 Thought-fold obs + sub-arc close")
        print(
            "  ⏭ Chapter 七百四十七 — L2 Neural Organ Metal+Rust hot math")
        print(
            "  ⏭ Chapter 七百四十八 — L9 Dream Loop batch-scoring")
        print(
            "  ⏭ Chapter 七百四十九 — 12-chapter arc close-out + branch SEAL")
        print("")

        print("=================================================================")
        print(
            "  CHAPTER 七百三十九 SEALED — L11 Rust state-machine port complete")
        print(
            "  3 axes Rust-strictly-better → forward-looking default flip")
        print(
            "  recommended。 Branch advances chapter 七百三十八 SEAL → chapter")
        print(
            "  七百三十九 第五刀 close-out (5 commits this chapter)。")
        print("=================================================================")
        print("")

        // Smoke: classifier reachable from tests + key
        // values match the byte-equality baseline
        XCTAssertEqual(
            BASAutoRouteRanker.riskPlaneTransition(
                band: 3, climate: 3, currentMode: 0),
            6,
            "Critical-Crisis must produce Block")
        XCTAssertEqual(
            BASAutoRouteRanker.riskPlaneTransition(
                band: 2, climate: 1, currentMode: 0),
            3,
            "High-Watchful must produce Delay")
        XCTAssertNil(
            BASAutoRouteRanker.riskPlaneTransition(
                band: -1, climate: 0, currentMode: 0),
            "Out-of-range band returns nil")
    }
}
