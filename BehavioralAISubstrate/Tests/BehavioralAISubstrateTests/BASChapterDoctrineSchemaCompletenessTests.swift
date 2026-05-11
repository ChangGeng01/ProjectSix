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
            // M1087 RADICAL EVOLUTION SWEEP Phase B backfill
            check("四百二十八",
                tag: BASChapter428EntropyDoctrine.chapterTag,
                first: BASChapter428EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter428EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter428EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter428EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter428EntropyDoctrine
                    .knives.count,
                pins: BASChapter428EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter428EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter428EntropyDoctrine
                    .summary),
            // M1091 RADICAL EVOLUTION SWEEP Phase C backfill
            check("四百二十九",
                tag: BASChapter429EntropyDoctrine.chapterTag,
                first: BASChapter429EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter429EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter429EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter429EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter429EntropyDoctrine
                    .knives.count,
                pins: BASChapter429EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter429EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter429EntropyDoctrine
                    .summary),
            // M1095 RADICAL EVOLUTION SWEEP Phase D backfill
            check("四百三十",
                tag: BASChapter430EntropyDoctrine.chapterTag,
                first: BASChapter430EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter430EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter430EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter430EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter430EntropyDoctrine
                    .knives.count,
                pins: BASChapter430EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter430EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter430EntropyDoctrine
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
                    .summary),
            // M1107 RADICAL EVOLUTION SWEEP final close-out
            check("四百三十三",
                tag: BASChapter433EntropyDoctrine.chapterTag,
                first: BASChapter433EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter433EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter433EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter433EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter433EntropyDoctrine
                    .knives.count,
                pins: BASChapter433EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter433EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter433EntropyDoctrine
                    .summary),
            // M1115 POST-RADICAL safety substrate
            check("四百三十四",
                tag: BASChapter434EntropyDoctrine.chapterTag,
                first: BASChapter434EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter434EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter434EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter434EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter434EntropyDoctrine
                    .knives.count,
                pins: BASChapter434EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter434EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter434EntropyDoctrine
                    .summary),
            // M1119 POST-RADICAL Wave 6 (first scheduler consumption)
            check("四百三十五",
                tag: BASChapter435EntropyDoctrine.chapterTag,
                first: BASChapter435EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter435EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter435EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter435EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter435EntropyDoctrine
                    .knives.count,
                pins: BASChapter435EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter435EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter435EntropyDoctrine
                    .summary),
            // M1123 POST-RADICAL Wave 7 (first ledger-driven dispatch)
            check("四百三十六",
                tag: BASChapter436EntropyDoctrine.chapterTag,
                first: BASChapter436EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter436EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter436EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter436EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter436EntropyDoctrine
                    .knives.count,
                pins: BASChapter436EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter436EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter436EntropyDoctrine
                    .summary),
            // M1127 POST-RADICAL Wave 8 (end-to-end routed dispatch)
            check("四百三十七",
                tag: BASChapter437EntropyDoctrine.chapterTag,
                first: BASChapter437EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter437EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter437EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter437EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter437EntropyDoctrine
                    .knives.count,
                pins: BASChapter437EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter437EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter437EntropyDoctrine
                    .summary),
            // M1131 POST-RADICAL Wave 9 (host-side injection)
            check("四百三十八",
                tag: BASChapter438EntropyDoctrine.chapterTag,
                first: BASChapter438EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter438EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter438EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter438EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter438EntropyDoctrine
                    .knives.count,
                pins: BASChapter438EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter438EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter438EntropyDoctrine
                    .summary),
            // M1135 POST-RADICAL Wave 10 (dispatch ↔ event log bridge)
            check("四百三十九",
                tag: BASChapter439EntropyDoctrine.chapterTag,
                first: BASChapter439EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter439EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter439EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter439EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter439EntropyDoctrine
                    .knives.count,
                pins: BASChapter439EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter439EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter439EntropyDoctrine
                    .summary),
            // M1139 POST-RADICAL Wave 11 (dispatch auto-emit)
            check("四百四十",
                tag: BASChapter440EntropyDoctrine.chapterTag,
                first: BASChapter440EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter440EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter440EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter440EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter440EntropyDoctrine
                    .knives.count,
                pins: BASChapter440EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter440EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter440EntropyDoctrine
                    .summary),
            // M1143 POST-RADICAL Wave 12 (plan-assignment event type)
            check("四百四十一",
                tag: BASChapter441EntropyDoctrine.chapterTag,
                first: BASChapter441EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter441EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter441EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter441EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter441EntropyDoctrine
                    .knives.count,
                pins: BASChapter441EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter441EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter441EntropyDoctrine
                    .summary),
            // M1147 POST-RADICAL Wave 13 (replay-rebuild integration)
            check("四百四十二",
                tag: BASChapter442EntropyDoctrine.chapterTag,
                first: BASChapter442EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter442EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter442EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter442EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter442EntropyDoctrine
                    .knives.count,
                pins: BASChapter442EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter442EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter442EntropyDoctrine
                    .summary),
            // M1151 POST-RADICAL Wave 14 (cross-session replay assembly)
            check("四百四十三",
                tag: BASChapter443EntropyDoctrine.chapterTag,
                first: BASChapter443EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter443EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter443EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter443EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter443EntropyDoctrine
                    .knives.count,
                pins: BASChapter443EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter443EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter443EntropyDoctrine
                    .summary),
            // M1155 POST-RADICAL Wave 15 (per-stage event payload)
            check("四百四十四",
                tag: BASChapter444EntropyDoctrine.chapterTag,
                first: BASChapter444EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter444EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter444EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter444EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter444EntropyDoctrine
                    .knives.count,
                pins: BASChapter444EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter444EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter444EntropyDoctrine
                    .summary),
            // M1159 POST-RADICAL Wave 16 (federated event log multi-backend)
            check("四百四十五",
                tag: BASChapter445EntropyDoctrine.chapterTag,
                first: BASChapter445EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter445EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter445EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter445EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter445EntropyDoctrine
                    .knives.count,
                pins: BASChapter445EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter445EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter445EntropyDoctrine
                    .summary),
            // M1163 POST-RADICAL Wave 17 (POST-RADICAL EVOLUTION SWEEP close-out)
            check("四百四十六",
                tag: BASChapter446EntropyDoctrine.chapterTag,
                first: BASChapter446EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter446EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter446EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter446EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter446EntropyDoctrine
                    .knives.count,
                pins: BASChapter446EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter446EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter446EntropyDoctrine
                    .summary),
            // M1167 POST-SWEEP REAL EXECUTION FOLLOW-THROUGH chapter 1
            check("四百四十七",
                tag: BASChapter447EntropyDoctrine.chapterTag,
                first: BASChapter447EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter447EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter447EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter447EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter447EntropyDoctrine
                    .knives.count,
                pins: BASChapter447EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter447EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter447EntropyDoctrine
                    .summary),
            // M1171 POST-SWEEP REAL EXECUTION chapter 2
            check("四百四十八",
                tag: BASChapter448EntropyDoctrine.chapterTag,
                first: BASChapter448EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter448EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter448EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter448EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter448EntropyDoctrine
                    .knives.count,
                pins: BASChapter448EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter448EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter448EntropyDoctrine
                    .summary),
            // M1175 POST-SWEEP REAL EXECUTION chapter 3
            check("四百四十九",
                tag: BASChapter449EntropyDoctrine.chapterTag,
                first: BASChapter449EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter449EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter449EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter449EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter449EntropyDoctrine
                    .knives.count,
                pins: BASChapter449EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter449EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter449EntropyDoctrine
                    .summary),
            // M1179 POST-SWEEP BIOMIMETIC chapter 1
            check("四百五十",
                tag: BASChapter450EntropyDoctrine.chapterTag,
                first: BASChapter450EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter450EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter450EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter450EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter450EntropyDoctrine
                    .knives.count,
                pins: BASChapter450EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter450EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter450EntropyDoctrine
                    .summary),
            // M1183 POST-SWEEP BIOMIMETIC chapter 2 (GPU)
            check("四百五十一",
                tag: BASChapter451EntropyDoctrine.chapterTag,
                first: BASChapter451EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter451EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter451EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter451EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter451EntropyDoctrine
                    .knives.count,
                pins: BASChapter451EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter451EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter451EntropyDoctrine
                    .summary),
            // M1187 POST-SWEEP BIOMIMETIC chapter 3 (adaptive)
            check("四百五十二",
                tag: BASChapter452EntropyDoctrine.chapterTag,
                first: BASChapter452EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter452EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter452EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter452EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter452EntropyDoctrine
                    .knives.count,
                pins: BASChapter452EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter452EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter452EntropyDoctrine
                    .summary),
            // M1191 POST-SWEEP REAL EXECUTION (attention)
            check("四百五十三",
                tag: BASChapter453EntropyDoctrine.chapterTag,
                first: BASChapter453EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter453EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter453EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter453EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter453EntropyDoctrine
                    .knives.count,
                pins: BASChapter453EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter453EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter453EntropyDoctrine
                    .summary),
            // M1195 POST-SWEEP BIOMIMETIC chapter 4 (learning)
            check("四百五十四",
                tag: BASChapter454EntropyDoctrine.chapterTag,
                first: BASChapter454EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter454EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter454EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter454EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter454EntropyDoctrine
                    .knives.count,
                pins: BASChapter454EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter454EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter454EntropyDoctrine
                    .summary),
            // M1199 POST-SWEEP BIOMIMETIC chapter 5 (state persistence)
            check("四百五十五",
                tag: BASChapter455EntropyDoctrine.chapterTag,
                first: BASChapter455EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter455EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter455EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter455EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter455EntropyDoctrine
                    .knives.count,
                pins: BASChapter455EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter455EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter455EntropyDoctrine
                    .summary),
            // M1203 POST-SWEEP BIOMIMETIC chapter 6 (turn observer orchestrator)
            check("四百五十六",
                tag: BASChapter456EntropyDoctrine.chapterTag,
                first: BASChapter456EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter456EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter456EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter456EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter456EntropyDoctrine
                    .knives.count,
                pins: BASChapter456EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter456EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter456EntropyDoctrine
                    .summary),
            // M1207 POST-SWEEP BIOMIMETIC chapter 7 (STDP 4th plasticity rule)
            check("四百五十七",
                tag: BASChapter457EntropyDoctrine.chapterTag,
                first: BASChapter457EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter457EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter457EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter457EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter457EntropyDoctrine
                    .knives.count,
                pins: BASChapter457EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter457EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter457EntropyDoctrine
                    .summary),
            // M1211 POST-SWEEP BIOMIMETIC chapter 8 (GPU plasticity)
            check("四百五十八",
                tag: BASChapter458EntropyDoctrine.chapterTag,
                first: BASChapter458EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter458EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter458EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter458EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter458EntropyDoctrine
                    .knives.count,
                pins: BASChapter458EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter458EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter458EntropyDoctrine
                    .summary),
            // M1215 POST-SWEEP BIOMIMETIC chapter 9 (hierarchical predictive coding)
            check("四百五十九",
                tag: BASChapter459EntropyDoctrine.chapterTag,
                first: BASChapter459EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter459EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter459EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter459EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter459EntropyDoctrine
                    .knives.count,
                pins: BASChapter459EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter459EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter459EntropyDoctrine
                    .summary),
            // M1219 DEBT REPAYMENT 1 (benchmark harness)
            check("四百六十",
                tag: BASChapter460EntropyDoctrine.chapterTag,
                first: BASChapter460EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter460EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter460EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter460EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter460EntropyDoctrine
                    .knives.count,
                pins: BASChapter460EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter460EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter460EntropyDoctrine
                    .summary),
            // M1223 DEBT REPAYMENT 2 (real wire from engine to observer)
            check("四百六十一",
                tag: BASChapter461EntropyDoctrine.chapterTag,
                first: BASChapter461EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter461EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter461EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter461EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter461EntropyDoctrine
                    .knives.count,
                pins: BASChapter461EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter461EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter461EntropyDoctrine
                    .summary),
            // M1227 DEBT REPAYMENT 3 (mock-coordinator infra + e2e tests)
            check("四百六十二",
                tag: BASChapter462EntropyDoctrine.chapterTag,
                first: BASChapter462EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter462EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter462EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter462EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter462EntropyDoctrine
                    .knives.count,
                pins: BASChapter462EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter462EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter462EntropyDoctrine
                    .summary),
            // M1231 STRUCTURAL DEBT REPAYMENT 1 (doctrine-collapse Phase 1)
            check("四百六十三",
                tag: BASChapter463EntropyDoctrine.chapterTag,
                first: BASChapter463EntropyDoctrine
                    .mNumberFirst,
                last: BASChapter463EntropyDoctrine
                    .mNumberLast,
                v1: BASChapter463EntropyDoctrine
                    .v1MilestoneMNumber,
                v1Status: BASChapter463EntropyDoctrine
                    .v1MilestoneStatus,
                knives: BASChapter463EntropyDoctrine
                    .knives.count,
                pins: BASChapter463EntropyDoctrine
                    .pinHeld.count,
                future: BASChapter463EntropyDoctrine
                    .plannedFutureCuts.count,
                summary: BASChapter463EntropyDoctrine
                    .summary),
            // M1235 STRUCTURAL DEBT REPAYMENT 2 (Phase 2 — REGISTRY-ONLY chapter,no Swift file)
            // chapter 464 has no BASChapter464EntropyDoctrine.swift。
            // Look up the record from the registry instead。
            checkRegistry("四百六十四",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百六十四")!),
            // M1239 STRUCTURAL DEBT REPAYMENT 3 (Phase 2b — registry-only)
            checkRegistry("四百六十五",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百六十五")!),
            // M1243 STRUCTURAL DEBT REPAYMENT 4 (Phase 3 EXECUTED — registry-only)
            checkRegistry("四百六十六",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百六十六")!),
            // M1247 POST-PHASE-3 FEATURE 1 (auto-checkpoint — registry-only)
            checkRegistry("四百六十七",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百六十七")!),
            // M1251 POST-PHASE-3 FEATURE 2 (replay loop closure — registry-only)
            checkRegistry("四百六十八",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百六十八")!),
            // M1255 POST-PHASE-3 FEATURE 3 (BCM meta-plasticity)
            checkRegistry("四百六十九",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百六十九")!),
            // M1259 POST-PHASE-3 FEATURE 4 (hierarchical observer slot)
            checkRegistry("四百七十",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百七十")!),
            // M1263 POST-PHASE-3 FEATURE 5 (Mamba benchmark)
            checkRegistry("四百七十一",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百七十一")!),
            // M1267 POST-PHASE-3 FEATURE 6 (bundle projection)
            checkRegistry("四百七十二",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百七十二")!),
            // M1271 POST-PHASE-3 SELF-AUDIT CLEANUP
            // (frozen SHA256 anti-drift PROOF + BCM 5th
            // slot wiring + E2E hierarchical/BCM tests +
            // 472 legacy-JSON Codable PROOF + production-
            // scale Mamba benchmark + honest prose +
            // Python extractor/forwarder scripts)
            checkRegistry("四百七十三",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百七十三")!),
            // M1275 POST-PHASE-3 REAL HOT-PATH ATTACK
            // phase 1 (BASANELiveReader + BASKernel
            // RegistryDispatchExecutor + end-to-end
            // integration PROOF + chapter close-out)
            checkRegistry("四百七十四",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百七十四")!),
            // M1279 POST-PHASE-3 REAL HOT-PATH ATTACK
            // phase 2 (BASCanonicalKernelInputBuilders
            // + first PROOF that MPSGraph kernels
            // actually compute correctly + EchoKernel
            // placeholder gap closed)
            checkRegistry("四百七十五",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百七十五")!),
            // M1283 POST-PHASE-3 REAL HOT-PATH ATTACK
            // phase 3 (RMSNorm + RotaryEmbedding
            // numerical PROOF + first real
            // BASBundle<Item> typealias migration)
            checkRegistry("四百七十六",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百七十六")!),
            // M1287 POST-PHASE-3 REAL HOT-PATH ATTACK
            // phase 4 final session close-out
            // (attention numerical PROOF closes 4-of-4
            // MPSGraph + honest re-scoring doctrine +
            // second BASBundle migration)
            checkRegistry("四百七十七",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百七十七")!),
            // M1291 V1 fold PILOT (BASTurnAuditProjections
            // KunlunTrio + coordinator splice + stress-
            // sweep regression guard)
            checkRegistry("四百七十八",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百七十八")!),
            // M1295 Phase B 3 missing MPSGraph kernels
            checkRegistry("四百七十九",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百七十九")!),
            // M1299 Phase C ANE flip + cache observation
            checkRegistry("四百八十",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百八十")!),
            // M1303 Phase D start 5-primitive adoption
            checkRegistry("四百八十一",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百八十一")!),
            // M1307 5-of-5 primitives + KV cache
            checkRegistry("四百八十二",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百八十二")!),
            // M1311 9 batched typealias adoptions
            checkRegistry("四百八十三",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百八十三")!),
            // M1315 22 cumulative + scoring update
            checkRegistry("四百八十四",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百八十四")!),
            // M1319 V1 fold cluster A 12-of-18
            checkRegistry("四百八十五",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百八十五")!),
            // M1323 cluster A 100% + cluster B start
            checkRegistry("四百八十六",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百八十六")!),
            // M1327 cluster B 8 declarations folded
            checkRegistry("四百八十七",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百八十七")!),
            // M1331 cluster B lifecycle quartet
            checkRegistry("四百八十八",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百八十八")!),
            // M1335 cluster B sextet
            checkRegistry("四百八十九",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百八十九")!),
            // M1339 TIER 1 SEALED
            checkRegistry("四百九十",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百九十")!)
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
            // M1087 RADICAL EVOLUTION SWEEP Phase B
            // backfill (chapter 428 fills the M1084-M1087
            // slot of the prior reserved gap)
            ("428", BASChapter428EntropyDoctrine.mNumberFirst,
             BASChapter428EntropyDoctrine.mNumberLast),
            // M1091 RADICAL EVOLUTION SWEEP Phase C
            // backfill (chapter 429 fills the M1088-M1091
            // slot of the prior reserved gap)
            ("429", BASChapter429EntropyDoctrine.mNumberFirst,
             BASChapter429EntropyDoctrine.mNumberLast),
            // M1095 RADICAL EVOLUTION SWEEP Phase D
            // backfill (chapter 430 fills the M1092-M1095
            // slot of the prior reserved gap — all of
            // M1084-M1095 now backfilled)
            ("430", BASChapter430EntropyDoctrine.mNumberFirst,
             BASChapter430EntropyDoctrine.mNumberLast),
            // M1099 RADICAL EVOLUTION SWEEP Phase E
            ("431", BASChapter431EntropyDoctrine.mNumberFirst,
             BASChapter431EntropyDoctrine.mNumberLast),
            // M1103 RADICAL EVOLUTION SWEEP Phase F
            ("432", BASChapter432EntropyDoctrine.mNumberFirst,
             BASChapter432EntropyDoctrine.mNumberLast),
            // M1107 RADICAL EVOLUTION SWEEP final close-out
            ("433", BASChapter433EntropyDoctrine.mNumberFirst,
             BASChapter433EntropyDoctrine.mNumberLast),
            // M1115 POST-RADICAL safety substrate
            ("434", BASChapter434EntropyDoctrine.mNumberFirst,
             BASChapter434EntropyDoctrine.mNumberLast),
            // M1119 POST-RADICAL Wave 6 (first scheduler consumption)
            ("435", BASChapter435EntropyDoctrine.mNumberFirst,
             BASChapter435EntropyDoctrine.mNumberLast),
            // M1123 POST-RADICAL Wave 7 (first ledger-driven dispatch)
            ("436", BASChapter436EntropyDoctrine.mNumberFirst,
             BASChapter436EntropyDoctrine.mNumberLast),
            // M1127 POST-RADICAL Wave 8 (end-to-end routed dispatch)
            ("437", BASChapter437EntropyDoctrine.mNumberFirst,
             BASChapter437EntropyDoctrine.mNumberLast),
            // M1131 POST-RADICAL Wave 9 (host-side injection)
            ("438", BASChapter438EntropyDoctrine.mNumberFirst,
             BASChapter438EntropyDoctrine.mNumberLast),
            // M1135 POST-RADICAL Wave 10 (dispatch ↔ event log bridge)
            ("439", BASChapter439EntropyDoctrine.mNumberFirst,
             BASChapter439EntropyDoctrine.mNumberLast),
            // M1139 POST-RADICAL Wave 11 (dispatch auto-emit)
            ("440", BASChapter440EntropyDoctrine.mNumberFirst,
             BASChapter440EntropyDoctrine.mNumberLast),
            // M1143 POST-RADICAL Wave 12 (plan-assignment event type)
            ("441", BASChapter441EntropyDoctrine.mNumberFirst,
             BASChapter441EntropyDoctrine.mNumberLast),
            // M1147 POST-RADICAL Wave 13 (replay-rebuild integration)
            ("442", BASChapter442EntropyDoctrine.mNumberFirst,
             BASChapter442EntropyDoctrine.mNumberLast),
            // M1151 POST-RADICAL Wave 14 (cross-session replay assembly)
            ("443", BASChapter443EntropyDoctrine.mNumberFirst,
             BASChapter443EntropyDoctrine.mNumberLast),
            // M1155 POST-RADICAL Wave 15 (per-stage event payload)
            ("444", BASChapter444EntropyDoctrine.mNumberFirst,
             BASChapter444EntropyDoctrine.mNumberLast),
            // M1159 POST-RADICAL Wave 16 (federated event log multi-backend)
            ("445", BASChapter445EntropyDoctrine.mNumberFirst,
             BASChapter445EntropyDoctrine.mNumberLast),
            // M1163 POST-RADICAL Wave 17 (POST-RADICAL EVOLUTION SWEEP close-out)
            ("446", BASChapter446EntropyDoctrine.mNumberFirst,
             BASChapter446EntropyDoctrine.mNumberLast),
            // M1167 POST-SWEEP REAL EXECUTION FOLLOW-THROUGH chapter 1
            ("447", BASChapter447EntropyDoctrine.mNumberFirst,
             BASChapter447EntropyDoctrine.mNumberLast),
            // M1171 POST-SWEEP REAL EXECUTION chapter 2
            ("448", BASChapter448EntropyDoctrine.mNumberFirst,
             BASChapter448EntropyDoctrine.mNumberLast),
            // M1175 POST-SWEEP REAL EXECUTION chapter 3
            ("449", BASChapter449EntropyDoctrine.mNumberFirst,
             BASChapter449EntropyDoctrine.mNumberLast),
            // M1179 POST-SWEEP BIOMIMETIC chapter 1
            ("450", BASChapter450EntropyDoctrine.mNumberFirst,
             BASChapter450EntropyDoctrine.mNumberLast),
            // M1183 POST-SWEEP BIOMIMETIC chapter 2 (GPU)
            ("451", BASChapter451EntropyDoctrine.mNumberFirst,
             BASChapter451EntropyDoctrine.mNumberLast),
            // M1187 POST-SWEEP BIOMIMETIC chapter 3 (adaptive)
            ("452", BASChapter452EntropyDoctrine.mNumberFirst,
             BASChapter452EntropyDoctrine.mNumberLast),
            // M1191 POST-SWEEP REAL EXECUTION (attention)
            ("453", BASChapter453EntropyDoctrine.mNumberFirst,
             BASChapter453EntropyDoctrine.mNumberLast),
            // M1195 POST-SWEEP BIOMIMETIC chapter 4 (learning)
            ("454", BASChapter454EntropyDoctrine.mNumberFirst,
             BASChapter454EntropyDoctrine.mNumberLast),
            // M1199 POST-SWEEP BIOMIMETIC chapter 5 (state persistence)
            ("455", BASChapter455EntropyDoctrine.mNumberFirst,
             BASChapter455EntropyDoctrine.mNumberLast),
            // M1203 POST-SWEEP BIOMIMETIC chapter 6 (turn observer orchestrator)
            ("456", BASChapter456EntropyDoctrine.mNumberFirst,
             BASChapter456EntropyDoctrine.mNumberLast),
            // M1207 POST-SWEEP BIOMIMETIC chapter 7 (STDP 4th plasticity rule)
            ("457", BASChapter457EntropyDoctrine.mNumberFirst,
             BASChapter457EntropyDoctrine.mNumberLast),
            // M1211 POST-SWEEP BIOMIMETIC chapter 8 (GPU plasticity)
            ("458", BASChapter458EntropyDoctrine.mNumberFirst,
             BASChapter458EntropyDoctrine.mNumberLast),
            // M1215 POST-SWEEP BIOMIMETIC chapter 9 (hierarchical predictive coding)
            ("459", BASChapter459EntropyDoctrine.mNumberFirst,
             BASChapter459EntropyDoctrine.mNumberLast),
            // M1219 DEBT REPAYMENT 1 (benchmark harness)
            ("460", BASChapter460EntropyDoctrine.mNumberFirst,
             BASChapter460EntropyDoctrine.mNumberLast),
            // M1223 DEBT REPAYMENT 2 (real engine→observer wire)
            ("461", BASChapter461EntropyDoctrine.mNumberFirst,
             BASChapter461EntropyDoctrine.mNumberLast),
            // M1227 DEBT REPAYMENT 3 (mock-coordinator + e2e tests)
            ("462", BASChapter462EntropyDoctrine.mNumberFirst,
             BASChapter462EntropyDoctrine.mNumberLast),
            // M1231 STRUCTURAL DEBT REPAYMENT 1 (doctrine-collapse Phase 1)
            ("463", BASChapter463EntropyDoctrine.mNumberFirst,
             BASChapter463EntropyDoctrine.mNumberLast),
            // M1235 STRUCTURAL DEBT REPAYMENT 2 (Phase 2 — REGISTRY-ONLY chapter)
            // chapter 464 has no Swift symbol;query registry directly
            ("464",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百六十四")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百六十四")!
                .mNumberLast),
            // M1239 STRUCTURAL DEBT REPAYMENT 3 (Phase 2b — registry-only)
            ("465",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百六十五")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百六十五")!
                .mNumberLast),
            // M1243 STRUCTURAL DEBT REPAYMENT 4 (Phase 3 EXECUTED — registry-only)
            ("466",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百六十六")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百六十六")!
                .mNumberLast),
            // M1247 POST-PHASE-3 FEATURE 1 (auto-checkpoint — registry-only)
            ("467",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百六十七")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百六十七")!
                .mNumberLast),
            // M1251 POST-PHASE-3 FEATURE 2 (replay loop — registry-only)
            ("468",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百六十八")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百六十八")!
                .mNumberLast),
            // M1255 POST-PHASE-3 FEATURE 3 (BCM)
            ("469",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百六十九")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百六十九")!
                .mNumberLast),
            // M1259 POST-PHASE-3 FEATURE 4 (hier obs slot)
            ("470",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百七十")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百七十")!
                .mNumberLast),
            // M1263 POST-PHASE-3 FEATURE 5 (Mamba bench)
            ("471",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百七十一")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百七十一")!
                .mNumberLast),
            // M1267 POST-PHASE-3 FEATURE 6 (bundle proj)
            ("472",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百七十二")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百七十二")!
                .mNumberLast),
            // M1271 POST-PHASE-3 SELF-AUDIT CLEANUP
            ("473",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百七十三")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百七十三")!
                .mNumberLast),
            // M1275 POST-PHASE-3 REAL HOT-PATH ATTACK
            ("474",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百七十四")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百七十四")!
                .mNumberLast),
            // M1279 POST-PHASE-3 REAL HOT-PATH ATTACK
            // phase 2
            ("475",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百七十五")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百七十五")!
                .mNumberLast),
            // M1283 POST-PHASE-3 REAL HOT-PATH ATTACK
            // phase 3
            ("476",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百七十六")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百七十六")!
                .mNumberLast),
            // M1287 POST-PHASE-3 REAL HOT-PATH ATTACK
            // phase 4 final session close-out
            ("477",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百七十七")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百七十七")!
                .mNumberLast),
            // M1291 V1 fold PILOT chapter 478
            ("478",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百七十八")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百七十八")!
                .mNumberLast),
            // M1295 Phase B chapter 479
            ("479",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百七十九")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百七十九")!
                .mNumberLast),
            // M1299 Phase C chapter 480
            ("480",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百八十")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百八十")!
                .mNumberLast),
            // M1303 Phase D start chapter 481
            ("481",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百八十一")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百八十一")!
                .mNumberLast),
            // M1307 chapter 482
            ("482",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百八十二")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百八十二")!
                .mNumberLast),
            // M1311 chapter 483
            ("483",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百八十三")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百八十三")!
                .mNumberLast),
            // M1315 chapter 484
            ("484",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百八十四")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百八十四")!
                .mNumberLast),
            // M1319 chapter 485
            ("485",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百八十五")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百八十五")!
                .mNumberLast),
            // M1323 chapter 486
            ("486",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百八十六")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百八十六")!
                .mNumberLast),
            // M1327 chapter 487
            ("487",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百八十七")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百八十七")!
                .mNumberLast),
            // M1331 chapter 488
            ("488",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百八十八")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百八十八")!
                .mNumberLast),
            // M1335 chapter 489
            ("489",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百八十九")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百八十九")!
                .mNumberLast),
            // M1339 chapter 490
            ("490",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百九十")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百九十")!
                .mNumberLast)
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
        // M1087 RADICAL EVOLUTION SWEEP Phase B backfill
        verifyKnivesRange(
            BASChapter428EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter428EntropyDoctrine.mNumberFirst,
            last: BASChapter428EntropyDoctrine.mNumberLast,
            tag: "四百二十八")
        // M1091 RADICAL EVOLUTION SWEEP Phase C backfill
        verifyKnivesRange(
            BASChapter429EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter429EntropyDoctrine.mNumberFirst,
            last: BASChapter429EntropyDoctrine.mNumberLast,
            tag: "四百二十九")
        // M1095 RADICAL EVOLUTION SWEEP Phase D backfill
        verifyKnivesRange(
            BASChapter430EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter430EntropyDoctrine.mNumberFirst,
            last: BASChapter430EntropyDoctrine.mNumberLast,
            tag: "四百三十")
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
        // M1107 RADICAL EVOLUTION SWEEP final close-out
        verifyKnivesRange(
            BASChapter433EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter433EntropyDoctrine.mNumberFirst,
            last: BASChapter433EntropyDoctrine.mNumberLast,
            tag: "四百三十三")
        // M1115 POST-RADICAL safety substrate
        verifyKnivesRange(
            BASChapter434EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter434EntropyDoctrine.mNumberFirst,
            last: BASChapter434EntropyDoctrine.mNumberLast,
            tag: "四百三十四")
        // M1119 POST-RADICAL Wave 6 (first scheduler consumption)
        verifyKnivesRange(
            BASChapter435EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter435EntropyDoctrine.mNumberFirst,
            last: BASChapter435EntropyDoctrine.mNumberLast,
            tag: "四百三十五")
        // M1123 POST-RADICAL Wave 7 (first ledger-driven dispatch)
        verifyKnivesRange(
            BASChapter436EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter436EntropyDoctrine.mNumberFirst,
            last: BASChapter436EntropyDoctrine.mNumberLast,
            tag: "四百三十六")
        // M1127 POST-RADICAL Wave 8 (end-to-end routed dispatch)
        verifyKnivesRange(
            BASChapter437EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter437EntropyDoctrine.mNumberFirst,
            last: BASChapter437EntropyDoctrine.mNumberLast,
            tag: "四百三十七")
        // M1131 POST-RADICAL Wave 9 (host-side injection)
        verifyKnivesRange(
            BASChapter438EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter438EntropyDoctrine.mNumberFirst,
            last: BASChapter438EntropyDoctrine.mNumberLast,
            tag: "四百三十八")
        // M1135 POST-RADICAL Wave 10 (dispatch ↔ event log bridge)
        verifyKnivesRange(
            BASChapter439EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter439EntropyDoctrine.mNumberFirst,
            last: BASChapter439EntropyDoctrine.mNumberLast,
            tag: "四百三十九")
        // M1139 POST-RADICAL Wave 11 (dispatch auto-emit)
        verifyKnivesRange(
            BASChapter440EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter440EntropyDoctrine.mNumberFirst,
            last: BASChapter440EntropyDoctrine.mNumberLast,
            tag: "四百四十")
        // M1143 POST-RADICAL Wave 12 (plan-assignment event type)
        verifyKnivesRange(
            BASChapter441EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter441EntropyDoctrine.mNumberFirst,
            last: BASChapter441EntropyDoctrine.mNumberLast,
            tag: "四百四十一")
        // M1147 POST-RADICAL Wave 13 (replay-rebuild integration)
        verifyKnivesRange(
            BASChapter442EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter442EntropyDoctrine.mNumberFirst,
            last: BASChapter442EntropyDoctrine.mNumberLast,
            tag: "四百四十二")
        // M1151 POST-RADICAL Wave 14 (cross-session replay assembly)
        verifyKnivesRange(
            BASChapter443EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter443EntropyDoctrine.mNumberFirst,
            last: BASChapter443EntropyDoctrine.mNumberLast,
            tag: "四百四十三")
        // M1155 POST-RADICAL Wave 15 (per-stage event payload)
        verifyKnivesRange(
            BASChapter444EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter444EntropyDoctrine.mNumberFirst,
            last: BASChapter444EntropyDoctrine.mNumberLast,
            tag: "四百四十四")
        // M1159 POST-RADICAL Wave 16 (federated event log multi-backend)
        verifyKnivesRange(
            BASChapter445EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter445EntropyDoctrine.mNumberFirst,
            last: BASChapter445EntropyDoctrine.mNumberLast,
            tag: "四百四十五")
        // M1163 POST-RADICAL Wave 17 (POST-RADICAL EVOLUTION SWEEP close-out)
        verifyKnivesRange(
            BASChapter446EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter446EntropyDoctrine.mNumberFirst,
            last: BASChapter446EntropyDoctrine.mNumberLast,
            tag: "四百四十六")
        // M1167 POST-SWEEP REAL EXECUTION FOLLOW-THROUGH chapter 1
        verifyKnivesRange(
            BASChapter447EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter447EntropyDoctrine.mNumberFirst,
            last: BASChapter447EntropyDoctrine.mNumberLast,
            tag: "四百四十七")
        // M1171 POST-SWEEP REAL EXECUTION chapter 2
        verifyKnivesRange(
            BASChapter448EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter448EntropyDoctrine.mNumberFirst,
            last: BASChapter448EntropyDoctrine.mNumberLast,
            tag: "四百四十八")
        // M1175 POST-SWEEP REAL EXECUTION chapter 3
        verifyKnivesRange(
            BASChapter449EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter449EntropyDoctrine.mNumberFirst,
            last: BASChapter449EntropyDoctrine.mNumberLast,
            tag: "四百四十九")
        // M1179 POST-SWEEP BIOMIMETIC chapter 1
        verifyKnivesRange(
            BASChapter450EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter450EntropyDoctrine.mNumberFirst,
            last: BASChapter450EntropyDoctrine.mNumberLast,
            tag: "四百五十")
        // M1183 POST-SWEEP BIOMIMETIC chapter 2 (GPU)
        verifyKnivesRange(
            BASChapter451EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter451EntropyDoctrine.mNumberFirst,
            last: BASChapter451EntropyDoctrine.mNumberLast,
            tag: "四百五十一")
        // M1187 POST-SWEEP BIOMIMETIC chapter 3 (adaptive)
        verifyKnivesRange(
            BASChapter452EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter452EntropyDoctrine.mNumberFirst,
            last: BASChapter452EntropyDoctrine.mNumberLast,
            tag: "四百五十二")
        // M1191 POST-SWEEP REAL EXECUTION (attention)
        verifyKnivesRange(
            BASChapter453EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter453EntropyDoctrine.mNumberFirst,
            last: BASChapter453EntropyDoctrine.mNumberLast,
            tag: "四百五十三")
        // M1195 POST-SWEEP BIOMIMETIC chapter 4 (learning)
        verifyKnivesRange(
            BASChapter454EntropyDoctrine.knives.map {
                $0.mNumber },
            first: BASChapter454EntropyDoctrine.mNumberFirst,
            last: BASChapter454EntropyDoctrine.mNumberLast,
            tag: "四百五十四")
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

    /// chapter 464 / M1234 — schema completeness
    /// check for REGISTRY-ONLY chapters。 Phase 2 of
    /// doctrine collapse means new chapters don't
    /// have BASChapter###EntropyDoctrine Swift symbols;
    /// they live exclusively in BASChapterDoctrine
    /// Registry。 This helper queries a record + runs
    /// the same completeness check as `check(...)`。
    private func checkRegistry(
        _ name: String,
        record: BASChapterDoctrineRecord
    ) -> (name: String, allOK: Bool) {
        return check(name,
            tag: record.chapterTag,
            first: record.mNumberFirst,
            last: record.mNumberLast,
            v1: record.v1MilestoneMNumber,
            v1Status: record.v1MilestoneStatus,
            knives: record.knives.count,
            pins: record.pinHeld.count,
            future: record.plannedFutureCuts.count,
            summary: record.summary)
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
