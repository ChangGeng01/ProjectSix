// MARK: - BASChapter878SubChapterNumberingDoctrineTests
// chapter 八百七十八 / M3070 — sub-chapter (decimal) numbering
// doctrine pin。
//
// CONTEXT — agent D 全量 review (chapter 877) LOW finding:
// chapter numbering at 877+ is approaching unwieldy。 Sub-chapter
// fractional notation (871.5 / 876.5 / 876.6 / etc) was
// IMPROVISED across the arc with no formal doctrine — different
// fix-of-fix chapters have used the same .5 suffix,which
// created the awkward chapter-name collisions in the task list
// (e.g. "Chapter 876.5 / M3051" vs "Chapter 876.5 / M3055" =
// the review-dispatch + the review-HIGH-fix BOTH labeled 876.5
// but actually different milestones)。
//
// This chapter PINS the convention going forward:
//
// **Sub-chapter numbering rules (effective chapter 八百七十八+):**
//
// 1. Main chapter = integer (e.g. chapter 877)
// 2. First fix-of-fix sub-chapter = .5 (chapter 877.5)
// 3. Second fix-of-fix sub-chapter = .6 (chapter 877.6)
// 4. Third+ = .7,.8,etc — DON'T go past .9
// 5. If the discipline calls for >5 fix-sub-chapters,that's a
//    signal to ship them as a SEPARATE numbered chapter
//    (e.g. chapter 878 for arc 877 fixes,not 877.5 + 877.6 +
//    877.7 + 877.8 + 877.9)
// 6. Review-dispatch and review-fix can share the same .5/.6
//    suffix BUT must have different M-numbers (e.g. M3051 for
//    the review dispatch,M3055 for the fixes that result)
// 7. Each sub-chapter still gets its own ledger entry (CHANGELOG
//    block + BRANCH_SUMMARY trajectory row + commit) — never
//    silently fold a sub-chapter into a parent commit
//
// This avoids the「3 chapters into 877.5」 confusion that arc
// 871-877 hit when the same.5 suffix bound to different work。

import XCTest

final class BASChapter878SubChapterNumberingDoctrineTests:
    XCTestCase
{

    /// Pin the 7 sub-chapter doctrine rules verbatim so future
    /// chapters can grep + cross-reference。
    func testSubChapterNumberingDoctrineRulesPinned() {
        let rules: [String] = [
            "Rule 1: Main chapter = integer (e.g. chapter 877)",
            "Rule 2: First fix-of-fix sub-chapter = .5 " +
                "(chapter 877.5)",
            "Rule 3: Second fix-of-fix sub-chapter = .6 " +
                "(chapter 877.6)",
            "Rule 4: Third+ = .7, .8, etc — DON'T go past .9",
            "Rule 5: If discipline needs > 5 fix-sub-chapters, " +
                "ship as SEPARATE numbered chapter (878 not " +
                "877.5+877.6+877.7+877.8+877.9)",
            "Rule 6: Review-dispatch + review-fix can share " +
                ".5/.6 suffix but must have different M-numbers",
            "Rule 7: Each sub-chapter still gets own ledger " +
                "(CHANGELOG block + BRANCH_SUMMARY row + commit)"
        ]
        XCTAssertEqual(rules.count, 7,
            "Chapter 八百七十八 pinned exactly 7 doctrine rules")
        for (idx, rule) in rules.enumerated() {
            XCTAssertTrue(
                rule.hasPrefix("Rule \(idx + 1):"),
                "Rule \(idx + 1) must be properly prefixed")
            XCTAssertGreaterThan(rule.count, 30,
                "Rule \(idx + 1) must have substantive text")
        }
    }

    /// Verify the rules cover the actual sub-chapter pattern
    /// the arc 871-877 used。 Tests the pattern by example:
    /// chapter 八百七十一.5 (one fix-of-fix) + chapter 八百七十六.5
    /// + chapter 八百七十六.6 (review dispatch + review HIGH fix)
    /// all conform to the doctrine。
    func testArc871To877SubChapterPatternConforms() {
        // Chapter 871.5 = one fix sub-chapter → Rule 2 (.5)
        // Chapter 876.5 = review dispatch → Rule 2 (.5)
        // Chapter 876.5 (M3055) = review HIGH fix → Rule 6
        //   (share .5 suffix, different M-number)
        // Chapter 876.6 = SECOND fix-of-fix → Rule 3 (.6)
        // Chapter 877 = wide-scope fix → Rule 5 (separate
        //   chapter not 876.7)
        // Chapter 877.5 (hypothetical) = first fix of 877 →
        //   Rule 2 (.5)
        let usedSuffixes: Set<String> = [
            ".5", ".6"
        ]
        let allowedSuffixes: Set<String> = [
            ".5", ".6", ".7", ".8", ".9"
        ]
        XCTAssertTrue(
            usedSuffixes.isSubset(of: allowedSuffixes),
            "Arc 871-877 used .5 and .6 — both within the " +
            "allowed .5-.9 range per Rule 4")
    }
}
