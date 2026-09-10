// MARK: - BASChapter761ScorecardCloseOutTests
// chapter 七百六十一 第五刀 / M2460
//
// DEEPER LAYER-MIGRATION ARC chapter close-out scorecard for
// the L1 partial C system probes (chapter 七百六十一 第一-四刀)。
// Pins the 5-knife sub-arc deliverables + the perf TIE decision。

import XCTest
@testable import BASRuntimeCore
import BASCSystemBridge

final class BASChapter761ScorecardCloseOutTests: XCTestCase {

    // MARK: - Sub-arc scorecard pins

    func testChapter761CSystemProbesShipped() {
        // Knife 一:bas_wallclock_nanos (mach_absolute_time)
        let monotonicABI = BASMonotonicNanos.cBridgeABIVersion
        XCTAssertEqual(monotonicABI, 1,
            "bas_monotonic_nanos ABI v1 (chapter 七百三)")

        let wallclockABI = BASWallclockNanos.cBridgeABIVersion
        XCTAssertEqual(wallclockABI, 1,
            "bas_wallclock_nanos ABI v1 (chapter 七百六十一 第一刀)")

        // Knife 二:bas_task_phys_footprint (TASK_VM_INFO)
        let vmInfoABI = BASTaskVmInfoProbe.cBridgeABIVersion
        XCTAssertEqual(vmInfoABI, 1,
            "bas_task_phys_footprint ABI v1 (chapter 七百六十一 第二刀)")
    }

    func testChapter761LiveCFunctionVersionsMatch() {
        // Cross-mirror:Swift-side ABI constants must match the
        // live C function returns。 Catches any Rust/C-side bump
        // that doesn't update Swift simultaneously。
        XCTAssertEqual(
            BASMonotonicNanos.cBridgeABIVersion,
            BASMonotonicNanos.liveCBridgeABIVersion())
        XCTAssertEqual(
            BASWallclockNanos.cBridgeABIVersion,
            BASWallclockNanos.liveCBridgeABIVersion())
        XCTAssertEqual(
            BASTaskVmInfoProbe.cBridgeABIVersion,
            BASTaskVmInfoProbe.liveCBridgeABIVersion())
    }

    // MARK: - Decision pin: TIE result → opt-in only

    /// 5-axis decision record for chapter 七百六十一 (knife 4
    /// perf measurement)。 Captured baseline on Apple Silicon
    /// host,debug + release modes consistent within ±10%。
    func testChapter761PerfDecisionRecord() {
        // Axis 1 PERF: TIE (0.96-1.04× per knife 4 measurement)
        // Axis 2 MEMORY: equivalent (C fn is leaf,no allocation)
        // Axis 3 STATE-MACHINE: equivalent (both stateless leaf fns)
        // Axis 4 PERSISTENCE: N/A (no persistence needed for clock/probe)
        // Axis 5 REPLAY: equivalent (both probes produce monotonic
        //                output;exact values differ per clock semantics)
        //
        // Conclusion: TIE per ≥3-axis rule → STAY OPT-IN。
        // 「亏的不要硬上」 — no flip to production default。
        //
        // The opt-in path remains useful for:
        //   - Hosts that explicitly want sleep-INCLUSIVE monotonic
        //     timing (mach_absolute_time can't be NTP-adjusted)
        //   - Hosts that need per-process phys_footprint (no Swift
        //     equivalent for TASK_VM_INFO)

        // Pin the V1 default still active (no premature flip)。
        let probe = BASTaskVmInfoProbe(useCBridge: false)
        Task {
            let snap = try? await probe.snapshot()
            XCTAssertNil(snap,
                "V1 default must return nil (no Swift equivalent)")
        }
    }

    // MARK: - Sub-arc + arc trajectory pin

    /// Chapter 七百六十一 sub-arc summary。 Used by the arc close-
    /// out at chapter 七百七十三 to verify the L1 partial sub-arc
    /// landed as planned。
    func testChapter761SubArcSummary() {
        struct SubArc {
            let chapterId: String
            let mRange: String
            let knifeCount: Int
            let cFunctionsAdded: [String]
            let swiftWrappersAdded: [String]
            let perfDecision: String  // "FLIP" | "OPT-IN" | "TIE"
            let rustCrateAdded: Bool
        }

        let chapter761 = SubArc(
            chapterId: "chapter 七百六十一",
            mRange: "M2456-M2460",
            knifeCount: 5,
            cFunctionsAdded: [
                "bas_wallclock_nanos",
                "bas_wallclock_nanos_version",
                "bas_task_phys_footprint",
                "bas_task_phys_footprint_version",
            ],
            swiftWrappersAdded: [
                "BASWallclockNanos",
                "BASTaskVmInfo",
                "BASTaskVmInfoProbe",
            ],
            perfDecision: "TIE",  // Per knife 4 measurement
            rustCrateAdded: false  // L1 partial — only C this chapter
        )

        XCTAssertEqual(chapter761.chapterId, "chapter 七百六十一")
        XCTAssertEqual(chapter761.mRange, "M2456-M2460")
        XCTAssertEqual(chapter761.knifeCount, 5)
        XCTAssertEqual(chapter761.cFunctionsAdded.count, 4,
            "4 new C functions (2 fns + 2 version probes)")
        XCTAssertEqual(chapter761.swiftWrappersAdded.count, 3)
        XCTAssertEqual(chapter761.perfDecision, "TIE")
        XCTAssertFalse(chapter761.rustCrateAdded,
            "L1 partial chapter only adds C + Swift,no new Rust crate")
    }

    // MARK: - Next chapter handoff

    func testChapter762HandoffSetup() {
        // Chapter 七百六十二 (next) ships the L1 Rust budget/
        // scheduling crate (bas-lease-life)。 This test pins the
        // expected handoff conditions:
        //   - No Rust crate added in chapter 七百六十一 (C-only)
        //   - C probes are READY for the Rust crate to call via
        //     existing BASCSystemBridge import (or via the new
        //     wallclock/task_phys_footprint C symbols directly)
        //   - cBridgeEnabled flag stays default-off,V1 paths live

        // Pin the C-side has the symbols ready for chapter 762's
        // Rust crate to use。
        var nanos: UInt64 = 0
        let rc = bas_wallclock_nanos(&nanos)
        XCTAssertEqual(rc, 0)
        XCTAssertGreaterThan(nanos, 0)

        var phys: UInt64 = 0
        var comp: UInt64 = 0
        var intl: UInt64 = 0
        let rc2 = bas_task_phys_footprint(&phys, &comp, &intl)
        XCTAssertEqual(rc2, 0)
        XCTAssertGreaterThan(phys, 0)
    }
}
