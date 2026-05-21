// MARK: - BASChapterDoctrineSchemaCompletenessTests
// chapter 四百二十二 / M1058 ORIGINAL
// chapter 七百五十二 / M2430 REDUCED — user directive 2026-05-20
//                                 「大幅度 缩减 doctrine。
//                                  对比 之后 有必要的 全面 comment」
//
// ## What this file pins (invariant unchanged)
//
// Every record in `BASChapterDoctrineRegistry.all` satisfies
// the full doctrine schema:
//   - non-empty chapterTag
//   - mNumberFirst >= 0
//   - mNumberLast >= mNumberFirst
//   - v1MilestoneMNumber within [mNumberFirst, mNumberLast]
//   - non-empty v1MilestoneStatus
//   - knives count > 0
//   - pinHeld count > 0
//   - plannedFutureCuts count > 0
//   - non-empty summary
//
// Plus knife-M-numbers fall within their chapter's M-range。
//
// ## What changed at chapter 七百五十二 第一刀
//
// The original 5513-LOC version had ONE explicit check(...) call
// per chapter,hand-spelled for 60+ chapters。 That was scaffolding
// from when per-chapter forwarder doctrines (`BASChapter###Entropy
// Doctrine.swift`) were the source-of-truth。 Since chapter 七百二
// the registry is the source-of-truth and the forwarders are thin
// passthroughs,so the same invariant collapses to a single loop
// over `BASChapterDoctrineRegistry.all`。
//
// The original 5513-LOC body is preserved verbatim inside
// `#if false ... #endif` below per 「依旧 不删除 只 comment」 —
// the comment-aware LOC counter (chapter 七百二 第四刀 script)
// reports the active test surface as ~60 LOC,not 5513。
//
// ## Why this reduction is safe
//
// 1. The invariant is unchanged — every chapter still gets
//    every field validated。
// 2. The registry is the SAME source-of-truth the original test
//    consumed (via the forwarders)。 Iterating `.all` reaches
//    every record directly。
// 3. NEW chapters automatically participate — no per-chapter
//    test entry to forget when adding a chapter。

import XCTest
@testable import BASRuntimeCore

final class BASChapterDoctrineSchemaCompletenessTests:
    XCTestCase
{

    // MARK: - Active reduced tests (chapter 七百五十二 第一刀)

    /// chapter 七百五十二 第一刀 / M2430 — schema completeness
    /// loop。 Replaces the original 60+ per-chapter check(...)
    /// calls with one iteration over `BASChapterDoctrineRegistry
    /// .all`。
    func testEveryRegistryChapterHasFullSchema() {
        var failures: [String] = []
        let all = BASChapterDoctrineRegistry.all
        XCTAssertGreaterThan(
            all.count, 0,
            "Registry must have at least one chapter record")

        for record in all {
            let tag = record.chapterTag
            if tag.isEmpty {
                failures.append("empty chapterTag")
                continue
            }
            if record.mNumberFirst < 0 {
                failures.append(
                    "\(tag): mNumberFirst < 0")
            }
            if record.mNumberLast < record.mNumberFirst {
                failures.append(
                    "\(tag): mNumberLast < mNumberFirst")
            }
            if record.v1MilestoneMNumber < record.mNumberFirst
                || record.v1MilestoneMNumber > record.mNumberLast
            {
                failures.append(
                    "\(tag): v1MilestoneMNumber " +
                    "\(record.v1MilestoneMNumber) outside " +
                    "[\(record.mNumberFirst),\(record.mNumberLast)]")
            }
            if record.v1MilestoneStatus.isEmpty {
                failures.append(
                    "\(tag): empty v1MilestoneStatus")
            }
            if record.knives.isEmpty {
                failures.append("\(tag): empty knives")
            }
            if record.pinHeld.isEmpty {
                failures.append("\(tag): empty pinHeld")
            }
            if record.plannedFutureCuts.isEmpty {
                failures.append(
                    "\(tag): empty plannedFutureCuts")
            }
            if record.summary.isEmpty {
                failures.append("\(tag): empty summary")
            }
        }

        XCTAssertTrue(
            failures.isEmpty,
            "Schema integrity failures:\n" +
            failures.joined(separator: "\n"))
    }

    /// chapter 七百五十二 第一刀 / M2430 — knife-M contiguity
    /// loop。 Every knife's M-number must fall within its
    /// chapter's M-range。
    func testEveryKnifeInRange() {
        var failures: [String] = []
        for record in BASChapterDoctrineRegistry.all {
            for knife in record.knives {
                if knife.mNumber < record.mNumberFirst
                    || knife.mNumber > record.mNumberLast
                {
                    failures.append(
                        "\(record.chapterTag) knife " +
                        "M\(knife.mNumber) outside " +
                        "[M\(record.mNumberFirst)," +
                        "M\(record.mNumberLast)]")
                }
            }
        }
        XCTAssertTrue(
            failures.isEmpty,
            "Knife-M range failures:\n" +
            failures.joined(separator: "\n"))
    }

    /// chapter 七百五十二 第一刀 / M2430 — M-number monotonicity
    /// (relaxed from the original Phase-2 contiguity test)。
    ///
    /// The original `testMNumberContiguityAcrossPhase2` enforced
    /// strict contiguity for Phase 2 chapters (403-421)。 The
    /// registry now spans Phase 2 + Phase 3 + Phase 4 chapters
    /// with intentional gaps where registry-only / forwarder-
    /// collapsed chapters sit。 The reduced invariant is
    /// monotonicity:sorting records by mNumberFirst yields a
    /// non-decreasing sequence。 Stronger contiguity remains
    /// pinned in the chapter-七百二 SQL phase2 data table。
    func testMNumberMonotonicityAcrossRegistry() {
        let sorted = BASChapterDoctrineRegistry.all
            .sorted { $0.mNumberFirst < $1.mNumberFirst }
        guard sorted.count >= 2 else { return }
        var failures: [String] = []
        for i in 1..<sorted.count {
            let prev = sorted[i - 1]
            let curr = sorted[i]
            // Monotonicity:curr starts no earlier than prev ends
            if curr.mNumberFirst <= prev.mNumberLast {
                failures.append(
                    "\(prev.chapterTag)(M\(prev.mNumberLast))" +
                    " overlaps \(curr.chapterTag)" +
                    "(M\(curr.mNumberFirst))")
            }
        }
        XCTAssertTrue(
            failures.isEmpty,
            "M-number monotonicity failures:\n" +
            failures.joined(separator: "\n"))
    }

    // MARK: - Historical body preserved per 「依旧 不删除 只 comment」
    //
    // The original 5513-LOC implementation (60+ per-chapter
    // hand-spelled `check(...)` calls) is preserved inside
    // `#if false ... #endif` below。 The comment-aware LOC
    // counter (chapter 七百二 第四刀) reports active test surface
    // accurately,not the commented-out historical body。

// chapter 八百二十八 / M2791-M2795 — #if false BODY ARCHIVED (was 5494 LOC) → Archive/Deactivated/Tests/BehavioralAISubstrateTests/BASChapterDoctrineSchemaCompletenessTests_IfFalseBody.txt
}
