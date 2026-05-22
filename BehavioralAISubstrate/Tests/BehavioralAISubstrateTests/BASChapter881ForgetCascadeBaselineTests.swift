// MARK: - BASChapter881ForgetCascadeBaselineTests
// chapter 八百八十一 / M3090 knife 1 — LIVE 2-way baseline
//
// Measures Swift Set<String> partition vs Rust C ABI partition
// across (recordCount, targetCount) grid to find the breakeven
// where Rust starts winning。 Prior chapter 七百十七 第二刀 deferred
// this measurement;chapter 八百八十一 picks it back up per gap-3
// directive (forget Rust path default-OFF because "之前 perf 证明
// 小批量 FFI 不划算" — we now measure where it ISN'T small)。
//
// Print-only。 Knife 3 of chapter 881 uses these numbers to set
// the default value of
// `BASAutoRouteThresholds.forgetCascadeRustMinRecords`。

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASMemory

final class BASChapter881ForgetCascadeBaselineTests: XCTestCase {

    /// Skip-by-default per chapter 七百九/七百十一/七百十二 archive
    /// pattern。 Comment out to run interactively for measurement。
    /// Knife 1 captures the numbers ONCE,then this stays archived。
    /// Chapter 八百八十一 / M3090 knife 1 captured the LIVE
    /// measurement on Mac mini (2026-05-23):
    ///
    ///   records=10,  targets=1,    Swift = 1.5 μs   Rust = 5.2 μs   (Swift 3.5×)
    ///   records=100, targets=100,  Swift wins (all hit rates)
    ///   records=1000,targets=100,  Swift wins (all hit rates)
    ///   records=10K, targets=1K,   Swift = 1.79ms   Rust = 4.62ms   (Swift 2.58×)
    ///
    /// VERDICT (chapter 881 knife 2 docs decision): Swift Set
    /// partition wins at EVERY measured production size by
    /// 2-3×。 String FFI encode/decode + HashMap rebuild costs
    /// dominate;rayon doesn't help because per-call work is
    /// too small。 Chapter 881 DECLINES the flip per 「亏的不要
    /// 硬上」 discipline。 Same pattern as chapter 874/875
    /// RoPE/RMSNorm decline。
    ///
    /// Skip-by-default after the chapter 881 capture is committed
    /// (per chapter 七百九/七百十一/七百十二 archive pattern)。
    /// Future chapter that wants to re-evaluate the decline
    /// (e.g.,after adding a batched-cascade API or numeric ID
    /// encoding) can flip the skip off and re-run for fresh
    /// data。 The trigger conditions for revisit are pinned by
    /// `BASChapter881ForgetCascadeDeclineAuditTests`。
    override func setUp() async throws {
        try await super.setUp()
        throw XCTSkip(
            "Chapter 881 knife 1 LIVE baseline — captured" +
            " 2026-05-23 → DECLINE verdict (Swift 2-3× faster" +
            " at every measured size)。 Skip stays on until a" +
            " future chapter changes the FFI shape" +
            " (batched-cascade,numeric IDs,etc)。")
    }

    private func makeIDs(_ n: Int, prefix: String) -> [String] {
        return (0..<n).map { i in "\(prefix)-\(i)" }
    }

    /// Bench Swift Set<String> partition (legacy path) vs Rust
    /// C ABI partition at a given (recordCount, targetCount) grid
    /// point。 targetHitFraction = what fraction of targets are
    /// actually present in records (varies real-world dedup work)。
    private func benchAt(
        recordCount: Int,
        targetCount: Int,
        targetHitFraction: Float = 0.5
    ) {
        let recordIDs = makeIDs(recordCount, prefix: "rec")
        // Some target IDs match records,others miss
        let hitCount = Int(
            Float(targetCount) * targetHitFraction)
        let missCount = max(0, targetCount - hitCount)
        var targetIDs: [String] = []
        targetIDs.reserveCapacity(targetCount)
        for i in 0..<hitCount {
            // Pick a record by deterministic index
            let recIdx = (i * 17) % max(1, recordCount)
            targetIDs.append("rec-\(recIdx)")
        }
        for i in 0..<missCount {
            targetIDs.append("miss-\(i)")
        }

        // Pre-warm output slots so allocation isn't measured
        var swiftSink: Int = 0
        var rustSink: Int = 0

        let res = BASBenchmarkHarness.tournament(
            warmup: 50,
            rounds: 3,
            iterations: recordCount >= 1000 ? 100 : 500,
            contestants: [
                ("Swift Set partition", {
                    var targetSet = Set<String>()
                    for id in targetIDs {
                        targetSet.insert(id)
                    }
                    var removedCount = 0
                    var keptCount = 0
                    for id in recordIDs {
                        if targetSet.contains(id) {
                            removedCount += 1
                        } else {
                            keptCount += 1
                        }
                    }
                    swiftSink = swiftSink &+ removedCount
                        &+ keptCount
                }),
                ("Rust C ABI partition", {
                    let r = BASAutoRouteRanker
                        .forgetCascadeFilter(
                            recordIds: recordIDs,
                            targetIds: targetIDs)
                    rustSink = rustSink &+ r.value.kept.count
                        &+ r.value.removed.count
                }),
            ])
        let winner = res.summaries[res.winnerIndex]
        print("BENCH forget_cascade " +
            "(records=\(recordCount),targets=\(targetCount)," +
            "hit=\(Int(targetHitFraction * 100))%) — winner: " +
            winner.label)
        for s in res.summaries { print("  " + s.formatted) }
        _ = (swiftSink, rustSink)
    }

    // MARK: - 2-D sweep

    /// Sweep across (recordCount × targetCount) at 50% hit rate
    /// (typical mid-load shape — half the targets in cascade are
    /// in the field,half are stale references)。
    func testBaselineSweep50PercentHit() {
        let recordCounts = [10, 100, 1000, 10000]
        let targetCounts = [1, 10, 100, 1000]
        for rc in recordCounts {
            for tc in targetCounts {
                benchAt(recordCount: rc, targetCount: tc,
                    targetHitFraction: 0.5)
            }
        }
    }

    /// Sweep at 10% hit (mostly-stale targets — rarely-hit
    /// cascade applied to a long-lived field)。
    func testBaselineSweep10PercentHit() {
        let recordCounts = [100, 1000, 10000]
        let targetCounts = [10, 100, 1000]
        for rc in recordCounts {
            for tc in targetCounts {
                benchAt(recordCount: rc, targetCount: tc,
                    targetHitFraction: 0.1)
            }
        }
    }

    /// Sweep at 100% hit (cascade designed to clean a specific
    /// retraction set — every target matches a record)。
    func testBaselineSweep100PercentHit() {
        let recordCounts = [100, 1000, 10000]
        let targetCounts = [10, 100, 1000]
        for rc in recordCounts {
            for tc in targetCounts {
                benchAt(recordCount: rc, targetCount: tc,
                    targetHitFraction: 1.0)
            }
        }
    }
}
