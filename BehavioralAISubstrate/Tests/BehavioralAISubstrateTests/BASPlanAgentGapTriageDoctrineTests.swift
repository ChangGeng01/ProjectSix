// MARK: - BASPlanAgentGapTriageDoctrineTests
// chapter 七百五十 / M2421-M2425 ad-hoc tests
//
// Pins the typed triage of the three Plan-agent gaps
// flagged across the 49-chapter branch arc。 User directive
// 「剩余 一次性 解决掉」 (2026-05-20) — close out the gaps
// in a single comprehensive triage。

import XCTest
@testable import BASRuntimeCore

final class BASPlanAgentGapTriageDoctrineTests: XCTestCase {

    // MARK: - Milestone + chapter tags

    func testChapterTag() {
        XCTAssertEqual(
            BASPlanAgentGapTriageDoctrine.chapterTag,
            "chapter 七百五十")
    }

    func testMilestoneRangeIs2421To2425() {
        XCTAssertEqual(
            BASPlanAgentGapTriageDoctrine.milestoneMNumberRange,
            2421...2425)
    }

    // MARK: - Gap 1 (Float16) status pin

    func testGap1FloatSixteenIsAlreadyClosed() {
        XCTAssertEqual(
            BASPlanAgentGapTriageDoctrine
                .gap1FloatSixteen.status,
            .alreadyClosed)
    }

    func testGap1ClosureChaptersListsThreeChapters() {
        XCTAssertEqual(
            BASPlanAgentGapTriageDoctrine
                .gap1FloatSixteen.closureChapters.count,
            3,
            "Float16 closure spans 七百三十三 + 七百三十四 + 七百三十五")
    }

    func testGap1ClosureChaptersReferenceCorrectChapters() {
        let chapters = BASPlanAgentGapTriageDoctrine
            .gap1FloatSixteen.closureChapters
            .joined(separator: " | ")
        XCTAssertTrue(chapters.contains("七百三十三"))
        XCTAssertTrue(chapters.contains("七百三十四"))
        XCTAssertTrue(chapters.contains("七百三十五"))
    }

    // MARK: - Gap 2 (Audit ledger) status pin

    func testGap2AuditLedgerIsMisframed() {
        XCTAssertEqual(
            BASPlanAgentGapTriageDoctrine
                .gap2AuditLedger.status,
            .misframed)
    }

    func testGap2EvidenceMentionsM91() {
        XCTAssertTrue(
            BASPlanAgentGapTriageDoctrine
                .gap2AuditLedger.evidence.contains("M91"))
    }

    func testGap2EvidenceMentionsAuditEntriesTable() {
        XCTAssertTrue(
            BASPlanAgentGapTriageDoctrine
                .gap2AuditLedger.evidence
                .contains("audit_entries"))
    }

    // MARK: - Gap 3 (JSON sweep) status pin

    func testGap3JsonSweepIsPinnedViaInventory() {
        XCTAssertEqual(
            BASPlanAgentGapTriageDoctrine
                .gap3JsonSweep.status,
            .pinnedViaInventory)
    }

    func testGap3ProductionSiteCountIs48() {
        XCTAssertEqual(
            BASPlanAgentGapTriageDoctrine
                .gap3JsonSweep.productionSiteCount,
            48,
            "Honest count of production .swift JSON sites")
    }

    func testGap3InventoryCountMatchesProductionSiteCount() {
        XCTAssertEqual(
            BASPlanAgentGapTriageDoctrine.jsonSiteCount,
            BASPlanAgentGapTriageDoctrine
                .gap3JsonSweep.productionSiteCount,
            "Inventory length must match declared site count")
    }

    // MARK: - Inventory integrity tests

    func testEveryInventoryPathStartsWithSources() {
        for (path, _) in BASPlanAgentGapTriageDoctrine
            .jsonSiteClassification
        {
            XCTAssertTrue(
                path.hasPrefix("Sources/"),
                "path must start with Sources/: \(path)")
        }
    }

    func testEveryInventoryPathEndsWithSwift() {
        for (path, _) in BASPlanAgentGapTriageDoctrine
            .jsonSiteClassification
        {
            XCTAssertTrue(
                path.hasSuffix(".swift"),
                "path must end with .swift: \(path)")
        }
    }

    func testNoDuplicatePathsInInventory() {
        let paths = BASPlanAgentGapTriageDoctrine
            .jsonSiteClassification.map { $0.path }
        let uniquePaths = Set(paths)
        XCTAssertEqual(
            paths.count,
            uniquePaths.count,
            "Inventory paths must be unique")
    }

    // MARK: - Category histogram tests

    func testCategoryHistogramSumsToInventoryCount() {
        var sum = 0
        for category in
            BASPlanAgentGapTriageDoctrine
                .JsonSiteCategory.allCases
        {
            sum += BASPlanAgentGapTriageDoctrine
                .count(of: category)
        }
        XCTAssertEqual(
            sum,
            BASPlanAgentGapTriageDoctrine.jsonSiteCount,
            "Histogram sum must equal inventory count")
    }

    func testEveryCategoryHasAtLeastOneSite() {
        for category in
            BASPlanAgentGapTriageDoctrine
                .JsonSiteCategory.allCases
        {
            let count = BASPlanAgentGapTriageDoctrine
                .count(of: category)
            XCTAssertGreaterThan(
                count, 0,
                "category \(category.rawValue) " +
                "should have ≥ 1 production site")
        }
    }

    func testSevenCategoriesEnumerated() {
        XCTAssertEqual(
            BASPlanAgentGapTriageDoctrine
                .JsonSiteCategory.allCases.count,
            7,
            "7 deliberate substrate-design categories")
    }

    // MARK: - User directive pin

    func testUserDirective2026_05_20Pinned() {
        XCTAssertEqual(
            BASPlanAgentGapTriageDoctrine
                .userDirective2026_05_20,
            "剩余 一次性 解决掉")
    }

    func testTriageDecisionRuleMentionsAllThreeGaps() {
        let rule = BASPlanAgentGapTriageDoctrine
            .triageDecisionRule
        XCTAssertTrue(rule.contains("Gap 1"))
        XCTAssertTrue(rule.contains("Gap 2"))
        XCTAssertTrue(rule.contains("Gap 3"))
    }

    // MARK: - chapter 698 discipline-gate satisfaction

    func testChapter698GateOptionIsOptionB() {
        XCTAssertTrue(
            BASPlanAgentGapTriageDoctrine
                .chapter698DisciplineGateOptionUsed
                .contains("option-b"))
        XCTAssertTrue(
            BASPlanAgentGapTriageDoctrine
                .chapter698DisciplineGateOptionUsed
                .contains("explicit-user-directive"))
    }

    func testUserAuthorizationQuoteReferencesDirective() {
        XCTAssertTrue(
            BASPlanAgentGapTriageDoctrine
                .userAuthorizationQuote.contains("剩余"))
        XCTAssertTrue(
            BASPlanAgentGapTriageDoctrine
                .userAuthorizationQuote.contains("2026-05-20"))
    }

    // MARK: - GapStatus exhaustiveness

    func testGapStatusHasThreeCases() {
        XCTAssertEqual(
            BASPlanAgentGapTriageDoctrine
                .GapStatus.allCases.count,
            3,
            "3 triage outcomes: alreadyClosed / misframed / " +
            "pinnedViaInventory")
    }

    // MARK: - Scorecard print

    func testPrintChapter750TriageScorecard() {
        print("")
        print("=================================================================")
        print(
            "  CHAPTER 七百五十 / M2421-M2425 — PLAN-AGENT GAP TRIAGE CLOSE-OUT")
        print("=================================================================")
        print("")
        print("### User directive 2026-05-20")
        print("")
        print("  「剩余 一次性 解决掉」")
        print("")
        print("### 3 Plan-agent gaps — triage outcomes")
        print("")
        print("  Gap 1 — Float16 path:")
        print(
            "    status:        ALREADY CLOSED")
        print(
            "    closed via:    chapter 七百三十三 + 七百三十四 + 七百三十五")
        print("")
        print("  Gap 2 — Audit ledger SQL wire format:")
        print(
            "    status:        MISFRAMED")
        print(
            "    evidence:      BASSovereignLedgerStorage M91")
        print(
            "                   already ships pure SQL with typed columns。")
        print(
            "                   No JSON payload exists to migrate。")
        print("")
        print("  Gap 3 — Full 89-site JSON Codable sweep:")
        print(
            "    status:        PINNED VIA INVENTORY")
        print(
            "    honest count:  48 production .swift sites")
        print(
            "                   (89 was an overcount of .md + SQL comments)")
        print(
            "    categories:    7 deliberate substrate-design choices")
        print("")
        print("### 7-category JSON site histogram")
        print("")
        for category in
            BASPlanAgentGapTriageDoctrine
                .JsonSiteCategory.allCases
        {
            let n = BASPlanAgentGapTriageDoctrine
                .count(of: category)
            let pad = String(
                repeating: " ",
                count: max(0, 45 - category.rawValue.count))
            print("  \(category.rawValue):\(pad)\(n)")
        }
        print("")
        print("  Total:                                       \(BASPlanAgentGapTriageDoctrine.jsonSiteCount)")
        print("")
        print("### Triage decision rule")
        print("")
        let lines = BASPlanAgentGapTriageDoctrine
            .triageDecisionRule
            .split(separator: "\n")
        for line in lines {
            print("  \(line)")
        }
        print("")
        print("### 49-chapter branch arc + ad-hoc close-out")
        print("")
        print(
            "  Branch arc:    chapter 七百二 → 七百四十九 (SEALED)")
        print(
            "  Ad-hoc 一次性: chapter 七百五十 / M2421-M2425 (THIS COMMIT)")
        print("")
        print(
            "  All three Plan-agent gaps now have typed,test-pinned,")
        print(
            "  doctrine-recorded answers。 Future readers can navigate")
        print(
            "  the gap history without re-investigation。")
        print("")

        // Smoke assertions
        XCTAssertEqual(
            BASPlanAgentGapTriageDoctrine
                .gap1FloatSixteen.status,
            .alreadyClosed)
        XCTAssertEqual(
            BASPlanAgentGapTriageDoctrine
                .gap2AuditLedger.status,
            .misframed)
        XCTAssertEqual(
            BASPlanAgentGapTriageDoctrine
                .gap3JsonSweep.status,
            .pinnedViaInventory)
    }
}
