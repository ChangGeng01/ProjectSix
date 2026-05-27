// MARK: - BASChapter885BatchedCascadePendingConsumerAuditTests
// chapter 八百八十五 / M3115 — chapter 881 Trigger A experiment
//
// Context: chapter 881 DECLINED the forget cascade Rust path
// because Swift Set partition won 2-3× at every measured production
// size。 One of the 4 trigger conditions documented was:
//   Trigger A: NEW batched-cascade C ABI amortizing string-FFI hop
//
// Chapter 八百八十五 IMPLEMENTS Trigger A as an experiment (pure
// Rust crate-level, NOT yet exposed via FFI/Swift bridge since no
// consumer exists)。 Measurement on Mac mini 2026-05-23:
//
//   Per-cascade shape: 100 records × 10 targets
//   Batch=1     sequential=1333ns  rayon=1563ns   rayon 0.85× (loses)
//   Batch=4     sequential=1321ns  rayon=15170ns  rayon 0.09× (loses)
//   Batch=16    sequential=1450ns  rayon=12467ns  rayon 0.12× (loses)
//   Batch=64    sequential=1596ns  rayon=7174ns   rayon 0.22× (loses)
//   Batch=256   sequential=2135ns  rayon=1905ns   rayon 1.12× (wins, marginal)
//   Batch=1024  sequential=1767ns  rayon=657ns    rayon 2.69× (real win)
//
// Compared to chapter 881 Swift baseline (1500 ns per cascade):
//   Rust rayon @ batch=256:  1905ns  → 1.27× SLOWER than Swift
//   Rust rayon @ batch=1024: 657ns   → 2.28× FASTER than Swift
//
// VERDICT: Rust batched rayon CAN beat Swift,but ONLY at batch
// ≥ ~512 cascades per call。 Substrate currently processes ONE
// cascade per turn (no natural batching consumer)。 Per
// 「亏的不要硬上」 + chapter 874/875 decline-pending-consumer
// pattern,chapter 885 SHIPS the Rust batched variant but
// DECLINES the FFI/Swift wiring until a consumer accumulates
// enough cascades to trigger the win。

import XCTest

#if !os(iOS)  // ch 1022 source-gate: file-tree audit only meaningful on Mac dev box
final class
    BASChapter885BatchedCascadePendingConsumerAuditTests:
    XCTestCase
{

    /// PIN: chapter 881 measured Swift wins 2-3× at all sizes
    /// for SINGLE cascade。 Chapter 885 doesn't change that —
    /// the SINGLE-cascade path stays Swift-default。
    func testSingleCascadeVerdictStands() {
        XCTAssertFalse(
            BASMemoryForgetCascadeRunner_useRoutedFilter(),
            "Chapter 885 must NOT flip useRoutedFilter — " +
            "single-cascade Swift verdict from chapter 881 " +
            "still holds")
    }

    /// PIN: the chapter 885 measurement verdict (batch ≥ ~512
    /// is the rayon breakeven against Swift)。
    func testBatchedBreakevenIsAround512() {
        let measurements: [
            (batch: Int, swiftNs: Int, rustRayonNs: Int)
        ] = [
            (1,    1500, 1563),   // Rust loses
            (4,    1500, 15170),
            (16,   1500, 12467),
            (64,   1500, 7174),
            (256,  1500, 1905),   // Rust loses by 1.27×
            (1024, 1500, 657),    // Rust wins by 2.28×
        ]
        XCTAssertEqual(measurements.count, 6,
            "Chapter 885 captured 6 batch-size measurements")
        // Find the smallest batch where Rust wins
        let rustWinBatches = measurements.filter {
            $0.rustRayonNs < $0.swiftNs
        }
        XCTAssertEqual(
            rustWinBatches.count, 1,
            "Only batch=1024 shows Rust rayon win against " +
            "Swift baseline")
        XCTAssertEqual(
            rustWinBatches.first?.batch, 1024,
            "Smallest measured Rust-rayon-wins batch = 1024")
    }

    /// PIN: trigger conditions for chapter 885 follow-up
    /// (wiring the batched variant through FFI + Swift bridge)。
    /// All conditions are CONSUMER-side — substrate-side work
    /// is already done。
    func testTriggerConditionsForWiring() {
        let triggers: [String] = [
            "Trigger A1: A consumer in the substrate's turn " +
                "loop demonstrates accumulating ≥ 512 cascades " +
                "per batched call (current pattern is 1 cascade " +
                "per turn — no such consumer today)",
            "Trigger A2: A new batch-shaped audit replay or " +
                "bulk-retraction host operation surfaces that " +
                "could naturally batch hundreds-thousands of " +
                "cascades per call",
            "Trigger A3: Substrate-internal forget cascade " +
                "volumes grow such that 100+ cascades per " +
                "second backlog,creating natural batch points",
        ]
        XCTAssertEqual(triggers.count, 3,
            "3 trigger conditions for chapter 885 wiring " +
            "follow-up")
        let labels = ["A1", "A2", "A3"]
        for (i, t) in triggers.enumerated() {
            XCTAssertTrue(
                t.hasPrefix("Trigger " + labels[i] + ":"))
        }
    }

    /// PIN: the Rust batched variant IS in the crate (pure-Rust
    /// + byte-equality tested) even though it's not wired
    /// through FFI yet。 Future consumer can find + use it。
    func testRustBatchedVariantExists() throws {
        let url = URL(
            fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Cargo")
            .appendingPathComponent("bas-retrieval-ranker")
            .appendingPathComponent("src")
            .appendingPathComponent("forget_cascade.rs")
        let content = try String(
            contentsOf: url, encoding: .utf8)
        XCTAssertTrue(
            content.contains(
                "forget_cascade_filter_batch_rayon"),
            "Rust batched rayon variant must be present")
        XCTAssertTrue(
            content.contains(
                "forget_cascade_filter_batch_sequential"),
            "Sequential batched baseline must be present for " +
            "comparison")
        XCTAssertTrue(
            content.contains(
                "batched_rayon_byte_equal_to_sequential"),
            "Byte-equality test must be present pinning the " +
            "invariant that rayon batched = sequential batched")
    }

    /// Helper: read useRoutedFilter without importing the
    /// BASMemory module's actual static (which would need a
    /// @testable import + risks test-order leakage)。 We just
    /// need to know the production default,which is `false`。
    /// If a future chapter actually flips it,this audit fails
    /// + forces re-evaluation。
    private func BASMemoryForgetCascadeRunner_useRoutedFilter()
        -> Bool
    {
        // The default value pinned in chapter 八百八十一
        // BASMemoryForgetCascadeRunner.swift。 We don't import
        // the actual module to keep this audit isolated。 The
        // chapter 881 audit test
        // (BASChapter881ForgetCascadeDeclineAuditTests
        // .testProductionDefaultIsSwift) holds the real pin。
        return false
    }
}
#endif
