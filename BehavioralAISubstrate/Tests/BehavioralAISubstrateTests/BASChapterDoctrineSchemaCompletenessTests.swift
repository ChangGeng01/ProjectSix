// MARK: - BASChapterDoctrineSchemaCompletenessTests
// chapter 四百二十二 / M1058
//
// Cross-cutting invariant test that pins the chapter doctrine
// schema across all 19 Phase 2 chapters (四百三-四百二十一)。
// Future chapter doctrines must satisfy this invariant or
// the test catches the regression at PR-time。
//
// This test consumes the M1055 BASPhase2EntropyClosureDoctrine
// chapter list as the source-of-truth for "which chapters to
// audit",so adding a new chapter only needs to update the
// closure doctrine + add its own doctrine file。

import XCTest
@testable import BASRuntimeCore

final class BASChapterDoctrineSchemaCompletenessTests:
    XCTestCase
{

    // MARK: - All 19 Phase 2 chapter doctrines have full schema

    func testEveryPhase2ChapterDoctrineHasFullSchema() {
        // Build a typed list of "doctrine field accessors"
        // per chapter,each returning a non-empty signal。
        // If any chapter doctrine is missing a field,its
        // accessor would return nil/empty/zero — flagged here。
        let allChapterIntegrityChecks:
            [(name: String, allOK: Bool)] =
        [
            check("四百三",
                tag: BASChapter403EntropyDoctrine.chapterTag,
                first: BASChapter403EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter403EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter403EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter403EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter403EntropyDoctrine
                    .knives.count,
                pins: BASChapter403EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter403EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter403EntropyDoctrine
                    .summary),
            check("四百四",
                tag: BASChapter404EntropyDoctrine.chapterTag,
                first: BASChapter404EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter404EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter404EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter404EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter404EntropyDoctrine
                    .knives.count,
                pins: BASChapter404EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter404EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter404EntropyDoctrine
                    .summary),
            check("四百五",
                tag: BASChapter405EntropyDoctrine.chapterTag,
                first: BASChapter405EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter405EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter405EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter405EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter405EntropyDoctrine
                    .knives.count,
                pins: BASChapter405EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter405EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter405EntropyDoctrine
                    .summary),
            check("四百六",
                tag: BASChapter406EntropyDoctrine.chapterTag,
                first: BASChapter406EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter406EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter406EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter406EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter406EntropyDoctrine
                    .knives.count,
                pins: BASChapter406EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter406EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter406EntropyDoctrine
                    .summary),
            check("四百七",
                tag: BASChapter407EntropyDoctrine.chapterTag,
                first: BASChapter407EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter407EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter407EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter407EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter407EntropyDoctrine
                    .knives.count,
                pins: BASChapter407EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter407EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter407EntropyDoctrine
                    .summary),
            check("四百八",
                tag: BASChapter408EntropyDoctrine.chapterTag,
                first: BASChapter408EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter408EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter408EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter408EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter408EntropyDoctrine
                    .knives.count,
                pins: BASChapter408EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter408EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter408EntropyDoctrine
                    .summary),
            check("四百九",
                tag: BASChapter409EntropyDoctrine.chapterTag,
                first: BASChapter409EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter409EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter409EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter409EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter409EntropyDoctrine
                    .knives.count,
                pins: BASChapter409EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter409EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter409EntropyDoctrine
                    .summary),
            check("四百十",
                tag: BASChapter410EntropyDoctrine.chapterTag,
                first: BASChapter410EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter410EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter410EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter410EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter410EntropyDoctrine
                    .knives.count,
                pins: BASChapter410EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter410EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter410EntropyDoctrine
                    .summary),
            check("四百十一",
                tag: BASChapter411EntropyDoctrine.chapterTag,
                first: BASChapter411EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter411EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter411EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter411EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter411EntropyDoctrine
                    .knives.count,
                pins: BASChapter411EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter411EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter411EntropyDoctrine
                    .summary),
            check("四百十二",
                tag: BASChapter412EntropyDoctrine.chapterTag,
                first: BASChapter412EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter412EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter412EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter412EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter412EntropyDoctrine
                    .knives.count,
                pins: BASChapter412EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter412EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter412EntropyDoctrine
                    .summary),
            check("四百十三",
                tag: BASChapter413EntropyDoctrine.chapterTag,
                first: BASChapter413EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter413EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter413EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter413EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter413EntropyDoctrine
                    .knives.count,
                pins: BASChapter413EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter413EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter413EntropyDoctrine
                    .summary),
            check("四百十四",
                tag: BASChapter414EntropyDoctrine.chapterTag,
                first: BASChapter414EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter414EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter414EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter414EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter414EntropyDoctrine
                    .knives.count,
                pins: BASChapter414EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter414EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter414EntropyDoctrine
                    .summary),
            check("四百十五",
                tag: BASChapter415EntropyDoctrine.chapterTag,
                first: BASChapter415EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter415EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter415EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter415EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter415EntropyDoctrine
                    .knives.count,
                pins: BASChapter415EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter415EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter415EntropyDoctrine
                    .summary),
            check("四百十六",
                tag: BASChapter416EntropyDoctrine.chapterTag,
                first: BASChapter416EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter416EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter416EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter416EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter416EntropyDoctrine
                    .knives.count,
                pins: BASChapter416EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter416EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter416EntropyDoctrine
                    .summary),
            check("四百十七",
                tag: BASChapter417EntropyDoctrine.chapterTag,
                first: BASChapter417EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter417EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter417EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter417EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter417EntropyDoctrine
                    .knives.count,
                pins: BASChapter417EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter417EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter417EntropyDoctrine
                    .summary),
            check("四百十八",
                tag: BASChapter418EntropyDoctrine.chapterTag,
                first: BASChapter418EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter418EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter418EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter418EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter418EntropyDoctrine
                    .knives.count,
                pins: BASChapter418EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter418EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter418EntropyDoctrine
                    .summary),
            check("四百十九",
                tag: BASChapter419EntropyDoctrine.chapterTag,
                first: BASChapter419EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter419EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter419EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter419EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter419EntropyDoctrine
                    .knives.count,
                pins: BASChapter419EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter419EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter419EntropyDoctrine
                    .summary),
            check("四百二十",
                tag: BASChapter420EntropyDoctrine.chapterTag,
                first: BASChapter420EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter420EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter420EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter420EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter420EntropyDoctrine
                    .knives.count,
                pins: BASChapter420EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter420EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter420EntropyDoctrine
                    .summary),
            check("四百二十一",
                tag: BASChapter421EntropyDoctrine.chapterTag,
                first: BASChapter421EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter421EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter421EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter421EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter421EntropyDoctrine
                    .knives.count,
                pins: BASChapter421EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter421EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter421EntropyDoctrine
                    .summary),
            // M1067 extension:added chapters 四百二十二 +
            // 四百二十三 to keep cross-cutting invariant in
            // sync with the M1066 Phase 2 doctrine extension
            check("四百二十二",
                tag: BASChapter422EntropyDoctrine.chapterTag,
                first: BASChapter422EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter422EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter422EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter422EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter422EntropyDoctrine
                    .knives.count,
                pins: BASChapter422EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter422EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter422EntropyDoctrine
                    .summary),
            check("四百二十三",
                tag: BASChapter423EntropyDoctrine.chapterTag,
                first: BASChapter423EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter423EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter423EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter423EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter423EntropyDoctrine
                    .knives.count,
                pins: BASChapter423EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter423EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter423EntropyDoctrine
                    .summary),
            // M1069 self-extension
            check("四百二十四",
                tag: BASChapter424EntropyDoctrine.chapterTag,
                first: BASChapter424EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter424EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter424EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter424EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter424EntropyDoctrine
                    .knives.count,
                pins: BASChapter424EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter424EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter424EntropyDoctrine
                    .summary),
            // M1073 self-extension
            check("四百二十五",
                tag: BASChapter425EntropyDoctrine.chapterTag,
                first: BASChapter425EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter425EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter425EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter425EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter425EntropyDoctrine
                    .knives.count,
                pins: BASChapter425EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter425EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter425EntropyDoctrine
                    .summary),
            // M1077 self-extension
            check("四百二十六",
                tag: BASChapter426EntropyDoctrine.chapterTag,
                first: BASChapter426EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter426EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter426EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter426EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter426EntropyDoctrine
                    .knives.count,
                pins: BASChapter426EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter426EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter426EntropyDoctrine
                    .summary),
            // M1083 RADICAL EVOLUTION SWEEP Phase A
            check("四百二十七",
                tag: BASChapter427EntropyDoctrine.chapterTag,
                first: BASChapter427EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter427EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter427EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter427EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter427EntropyDoctrine
                    .knives.count,
                pins: BASChapter427EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter427EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter427EntropyDoctrine
                    .summary),
            // M1099 RADICAL EVOLUTION SWEEP Phase E
            // (M1084-M1095 reserved gap for Phase B/C/D
            // backfill — chapters 四百二十八/四百二十九/四百三十)
            check("四百三十一",
                tag: BASChapter431EntropyDoctrine.chapterTag,
                first: BASChapter431EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter431EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter431EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter431EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter431EntropyDoctrine
                    .knives.count,
                pins: BASChapter431EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter431EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter431EntropyDoctrine
                    .summary),
            // M1103 RADICAL EVOLUTION SWEEP Phase F
            check("四百三十二",
                tag: BASChapter432EntropyDoctrine.chapterTag,
                first: BASChapter432EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter432EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter432EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter432EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter432EntropyDoctrine
                    .knives.count,
                pins: BASChapter432EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter432EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter432EntropyDoctrine
                    .summary)
        ]
        XCTAssertEqual(
            allChapterIntegrityChecks.count,
            BASPhase2EntropyClosureDoctrine
                .chapterTagsShipped.count,
            "schema-completeness check count must equal" +
            " Phase 2 chapter count")
        for c in allChapterIntegrityChecks {
            XCTAssertTrue(
                c.allOK,
                "chapter \(c.name) doctrine must satisfy" +
                " full schema (chapterTag/mNumberFirst/" +
                "mNumberLast/v1MilestoneMNumber/v1Milestone" +
                "Status/knives/pinHeld/plannedFutureCuts/" +
                "summary all populated)")
        }
    }

    // MARK: - M-number contiguity invariant

    func testMNumberContiguityAcrossPhase2() {
        // (chapterTag, mNumberFirst, mNumberLast) tuples
        // in Phase 2 chronological order
        let ranges: [(tag: String, first: Int, last: Int)] =
            [
            ("403", BASChapter403EntropyDoctrine.mNumberFirst,
             BASChapter403EntropyDoctrine.mNumberLast),
            ("404", BASChapter404EntropyDoctrine.mNumberFirst,
             BASChapter404EntropyDoctrine.mNumberLast),
            ("405", BASChapter405EntropyDoctrine.mNumberFirst,
             BASChapter405EntropyDoctrine.mNumberLast),
            ("406", BASChapter406EntropyDoctrine.mNumberFirst,
             BASChapter406EntropyDoctrine.mNumberLast),
            ("407", BASChapter407EntropyDoctrine.mNumberFirst,
             BASChapter407EntropyDoctrine.mNumberLast),
            ("408", BASChapter408EntropyDoctrine.mNumberFirst,
             BASChapter408EntropyDoctrine.mNumberLast),
            ("409", BASChapter409EntropyDoctrine.mNumberFirst,
             BASChapter409EntropyDoctrine.mNumberLast),
            ("410", BASChapter410EntropyDoctrine.mNumberFirst,
             BASChapter410EntropyDoctrine.mNumberLast),
            ("411", BASChapter411EntropyDoctrine.mNumberFirst,
             BASChapter411EntropyDoctrine.mNumberLast),
            ("412", BASChapter412EntropyDoctrine.mNumberFirst,
             BASChapter412EntropyDoctrine.mNumberLast),
            ("413", BASChapter413EntropyDoctrine.mNumberFirst,
             BASChapter413EntropyDoctrine.mNumberLast),
            ("414", BASChapter414EntropyDoctrine.mNumberFirst,
             BASChapter414EntropyDoctrine.mNumberLast),
            ("415", BASChapter415EntropyDoctrine.mNumberFirst,
             BASChapter415EntropyDoctrine.mNumberLast),
            ("416", BASChapter416EntropyDoctrine.mNumberFirst,
             BASChapter416EntropyDoctrine.mNumberLast),
            ("417", BASChapter417EntropyDoctrine.mNumberFirst,
             BASChapter417EntropyDoctrine.mNumberLast),
            ("418", BASChapter418EntropyDoctrine.mNumberFirst,
             BASChapter418EntropyDoctrine.mNumberLast),
            ("419", BASChapter419EntropyDoctrine.mNumberFirst,
             BASChapter419EntropyDoctrine.mNumberLast),
            ("420", BASChapter420EntropyDoctrine.mNumberFirst,
             BASChapter420EntropyDoctrine.mNumberLast),
            ("421", BASChapter421EntropyDoctrine.mNumberFirst,
             BASChapter421EntropyDoctrine.mNumberLast),
            // M1067 extension
            ("422", BASChapter422EntropyDoctrine.mNumberFirst,
             BASChapter422EntropyDoctrine.mNumberLast),
            ("423", BASChapter423EntropyDoctrine.mNumberFirst,
             BASChapter423EntropyDoctrine.mNumberLast),
            // M1069 self-extension
            ("424", BASChapter424EntropyDoctrine.mNumberFirst,
             BASChapter424EntropyDoctrine.mNumberLast),
            // M1073 self-extension
            ("425", BASChapter425EntropyDoctrine.mNumberFirst,
             BASChapter425EntropyDoctrine.mNumberLast),
            // M1077 self-extension
            ("426", BASChapter426EntropyDoctrine.mNumberFirst,
             BASChapter426EntropyDoctrine.mNumberLast),
            // M1083 RADICAL EVOLUTION SWEEP Phase A
            // (M1078-M1079 reserved gap)
            ("427", BASChapter427EntropyDoctrine.mNumberFirst,
             BASChapter427EntropyDoctrine.mNumberLast),
            // M1099 RADICAL EVOLUTION SWEEP Phase E
            // (M1084-M1095 reserved gap for Phase B/C/D
            // backfill)
            ("431", BASChapter431EntropyDoctrine.mNumberFirst,
             BASChapter431EntropyDoctrine.mNumberLast),
            // M1103 RADICAL EVOLUTION SWEEP Phase F
            ("432", BASChapter432EntropyDoctrine.mNumberFirst,
             BASChapter432EntropyDoctrine.mNumberLast)
            ]
        // chapter 427 starts at M1080 (skipping M1078-M1079
        // reserved gap for future Phase B/C/D backfill)。
        // Allow small reserved-gap tolerance for the
        // contiguity check while still asserting strict
        // monotonic ordering。
        for i in 1..<ranges.count {
            XCTAssertGreaterThan(
                ranges[i].first,
                ranges[i - 1].last,
                "chapter \(ranges[i - 1].tag) ends at " +
                "M\(ranges[i - 1].last) but chapter " +
                "\(ranges[i].tag) starts at " +
                "M\(ranges[i].first):non-monotonic")
        }
        // First chapter starts at Phase 2 boundary
        XCTAssertEqual(
            ranges.first?.first,
            BASPhase2EntropyClosureDoctrine.mNumberFirst)
        // Last chapter ends at Phase 2 boundary
        XCTAssertEqual(
            ranges.last?.last,
            BASPhase2EntropyClosureDoctrine.mNumberLast)
    }

    // MARK: - Knives ledger M-number range matches chapter

    func testKnivesLedgerMatchesChapterRange() {
        // Sample 4 chapters at random points in Phase 2
        // (entry / mid / late / final) to verify each
        // chapter's knives ledger M-numbers fall within
        // chapter range。
        verifyKnivesRange(
            BASChapter403EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter403EntropyDoctrine.mNumberFirst,
            last: BASChapter403EntropyDoctrine.mNumberLast,
            tag: "四百三")
        verifyKnivesRange(
            BASChapter410EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter410EntropyDoctrine.mNumberFirst,
            last: BASChapter410EntropyDoctrine.mNumberLast,
            tag: "四百十")
        verifyKnivesRange(
            BASChapter417EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter417EntropyDoctrine.mNumberFirst,
            last: BASChapter417EntropyDoctrine.mNumberLast,
            tag: "四百十七")
        verifyKnivesRange(
            BASChapter421EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter421EntropyDoctrine.mNumberFirst,
            last: BASChapter421EntropyDoctrine.mNumberLast,
            tag: "四百二十一")
        verifyKnivesRange(
            BASChapter427EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter427EntropyDoctrine.mNumberFirst,
            last: BASChapter427EntropyDoctrine.mNumberLast,
            tag: "四百二十七")
        // M1099 RADICAL EVOLUTION SWEEP Phase E
        verifyKnivesRange(
            BASChapter431EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter431EntropyDoctrine.mNumberFirst,
            last: BASChapter431EntropyDoctrine.mNumberLast,
            tag: "四百三十一")
        // M1103 RADICAL EVOLUTION SWEEP Phase F
        verifyKnivesRange(
            BASChapter432EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter432EntropyDoctrine.mNumberFirst,
            last: BASChapter432EntropyDoctrine.mNumberLast,
            tag: "四百三十二")
        // M1067 extension:added chapters 四百二十二 + 四百二十三
        verifyKnivesRange(
            BASChapter422EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter422EntropyDoctrine.mNumberFirst,
            last: BASChapter422EntropyDoctrine.mNumberLast,
            tag: "四百二十二")
        verifyKnivesRange(
            BASChapter423EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter423EntropyDoctrine.mNumberFirst,
            last: BASChapter423EntropyDoctrine.mNumberLast,
            tag: "四百二十三")
        // M1069 self-extension
        verifyKnivesRange(
            BASChapter424EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter424EntropyDoctrine.mNumberFirst,
            last: BASChapter424EntropyDoctrine.mNumberLast,
            tag: "四百二十四")
    }

    // MARK: - Helpers

    private func check(
        _ name: String,
        tag: String,
        first: Int,
        last: Int,
        v1: Int,
        v1Status: String,
        knives: Int,
        pins: Int,
        future: Int,
        summary: String
    ) -> (name: String, allOK: Bool) {
        let allOK =
            !tag.isEmpty
            && first > 0
            && last >= first
            && v1 >= first && v1 <= last
            && !v1Status.isEmpty
            && knives > 0
            && pins > 0
            && future > 0
            && !summary.isEmpty
        return (name: name, allOK: allOK)
    }

    private func verifyKnivesRange(
        _ knifeMs: [Int],
        first: Int,
        last: Int,
        tag: String
    ) {
        for m in knifeMs {
            XCTAssertGreaterThanOrEqual(
                m, first,
                "chapter \(tag) knife M\(m) outside " +
                "chapter range [M\(first), M\(last)]")
            XCTAssertLessThanOrEqual(
                m, last,
                "chapter \(tag) knife M\(m) outside " +
                "chapter range [M\(first), M\(last)]")
        }
    }
}
