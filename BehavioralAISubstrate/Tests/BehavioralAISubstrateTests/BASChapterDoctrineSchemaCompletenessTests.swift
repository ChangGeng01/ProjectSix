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
                            "chapter 四百九十")!),
            // M1343 cluster B 87.5%
            checkRegistry("四百九十一",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百九十一")!),
            // M1347 surface trio + honest scope
            checkRegistry("四百九十二",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百九十二")!),
            // M1352 downstream Kunlun fold (axis + seal/river)
            checkRegistry("四百九十三",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百九十三")!),
            // M1356 Tianmen trio + gate-side axis reuse
            checkRegistry("四百九十四",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百九十四")!),
            // M1360 permit pipeline typed-surface ship
            checkRegistry("四百九十五",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百九十五")!),
            // M1364 Tier 2 entry — ssmScan stub + coverage
            checkRegistry("四百九十六",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百九十六")!),
            // M1368 REAL HOT-PATH ATTACK SEALED
            checkRegistry("四百九十七",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百九十七")!),
            // M1372 Tier 1 honest closure push starts
            checkRegistry("四百九十八",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百九十八")!),
            // M1376 更极致/低熵 substantive 3-adoption push
            checkRegistry("四百九十九",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 四百九十九")!),
            // M1380 chapter 500 — 最创新/原生神经引擎
            checkRegistry("五百",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百")!),
            // M1383 chapter 501 — Tier 1 honest SEAL at 52/60
            checkRegistry("五百一",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百一")!),
            // M1388 chapter 502 — wire-in push
            checkRegistry("五百二",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百二")!),
            // M1392 chapter 503 — observer wire-ins
            checkRegistry("五百三",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百三")!),
            // M1396 chapter 504 — bundle aggregator wire-ins
            checkRegistry("五百四",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百四")!),
            // M1400 chapter 505 — unified audit emission MILESTONE
            checkRegistry("五百五",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百五")!),
            // M1404 chapter 506 — cluster B fold continues
            checkRegistry("五百六",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百六")!),
            // M1408 chapter 507 — Tier C ADR-019 entry
            checkRegistry("五百七",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百七")!),
            // M1412 chapter 508 — Tier C ADR-019 COMPLETE
            checkRegistry("五百八",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百八")!),
            // M1416 chapter 509 — Tier C migration adapters
            checkRegistry("五百九",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百九")!),
            // M1420 chapter 510 — V1 monolith fold continues
            checkRegistry("五百十",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百十")!),
            // M1424 chapter 511 — projection-block fold
            checkRegistry("五百十一",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百十一")!),
            // M1428 chapter 512 — projection-block wire-in
            checkRegistry("五百十二",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百十二")!),
            // M1432 chapter 513 — 5-pipeline unified audit
            checkRegistry("五百十三",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百十三")!),
            // M1436 chapter 514 — 3rd typed input block
            checkRegistry("五百十四",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百十四")!),
            // M1440 chapter 515 — V1 monolith projections fold
            checkRegistry("五百十五",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百十五")!),
            // M1444 chapter 516 — 4th input block + V1 splice extension
            checkRegistry("五百十六",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百十六")!),
            // M1448 chapter 517 — 5th input block + V1 splice extension
            checkRegistry("五百十七",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百十七")!),
            // M1452 chapter 518 — 6th input block + V1 splice extension
            checkRegistry("五百十八",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百十八")!),
            // M1456 chapter 519 — FIRST PRODUCTION WIRE-IN
            checkRegistry("五百十九",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百十九")!),
            // M1460 chapter 520 — 10-chapter arc close-out
            checkRegistry("五百二十",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百二十")!),
            // M1464 chapter 521 — 7th input block + V1 splice
            checkRegistry("五百二十一",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百二十一")!),
            // M1468 chapter 522 — 100% V1 packaging coverage
            checkRegistry("五百二十二",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百二十二")!),
            // M1472 chapter 523 — 12-chapter arc milestone
            checkRegistry("五百二十三",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百二十三")!),
            // M1476 chapter 524 — pivot to BASEBrainTurnResult fold
            checkRegistry("五百二十四",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百二十四")!),
            // M1480 chapter 525 — sovereign bundle 2nd cluster
            checkRegistry("五百二十五",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百二十五")!),
            // M1484 chapter 526 — audit-projection-forward 3rd cluster
            checkRegistry("五百二十六",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百二十六")!),
            // M1488 chapter 527 — parallel-run reconciliation
            checkRegistry("五百二十七",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百二十七")!),
            // M1492 chapter 528 — cognitive frames 5th cluster
            checkRegistry("五百二十八",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百二十八")!),
            // M1496 chapter 529 — risk/choice 6th cluster
            checkRegistry("五百二十九",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百二十九")!),
            // M1500 chapter 530 — M1500 MILESTONE misc 7th cluster
            checkRegistry("五百三十",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百三十")!),
            // M1504 chapter 531 — device/lifecycle 8th cluster
            checkRegistry("五百三十一",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百三十一")!),
            // M1508 chapter 532 — 100% PACKAGING MILESTONE — forensic 9th + FINAL cluster
            checkRegistry("五百三十二",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百三十二")!),
            // M1512 chapter 533 — fold arc sealed milestone doctrine + 20 PROOF tests
            checkRegistry("五百三十三",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百三十三")!),
            // M1516 chapter 534 — 30-declaration dead-code purge + doctrine + 11 PROOF tests
            checkRegistry("五百三十四",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百三十四")!),
            // M1520 chapter 535 — substrate-wide warning purge + doctrine + 12 PROOF tests
            checkRegistry("五百三十五",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百三十五")!),
            // M1524 chapter 536 — typed observability sink + wire-in + 7 PROOF tests
            checkRegistry("五百三十六",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百三十六")!),
            // M1528 chapter 537 — engine observation failure sink + wire-in + 9 PROOF tests
            checkRegistry("五百三十七",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百三十七")!),
            // M1532 chapter 538 — test-target warning purge + doctrine + 13 PROOF tests
            checkRegistry("五百三十八",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百三十八")!),
            // M1536 chapter 539 — 3rd typed observability sink (cross-module) + wire-in + 10 PROOF tests
            checkRegistry("五百三十九",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百三十九")!),
            // M1540 chapter 540 — unified observability sink catalogue + 23 PROOF tests
            checkRegistry("五百四十",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百四十")!),
            // M1544 chapter 541 — Codable conformance addition + typed milestone + 7 PROOF tests
            checkRegistry("五百四十一",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百四十一")!),
            // M1548 chapter 542 — Codable round-trip PROOF + Hashable blocker doctrine + 10 PROOF tests
            checkRegistry("五百四十二",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百四十二")!),
            // M1552 chapter 543 — Codable round-trip coverage extension + tracking doctrine + 13 PROOF tests
            checkRegistry("五百四十三",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百四十三")!),
            // M1556 chapter 544 — MiscBundle round-trip + coverage doctrine update + anti-drift tests
            checkRegistry("五百四十四",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百四十四")!),
            // M1560 chapter 545 — DeviceLifecycle round-trip + coverage doctrine update + anti-drift tests
            checkRegistry("五百四十五",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百四十五")!),
            // M1564 chapter 546 — RiskChoice round-trip + coverage doctrine update + anti-drift tests
            checkRegistry("五百四十六",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百四十六")!),
            // M1568 chapter 547 — 100% MILESTONE — CognitiveFrames round-trip + 100% doctrine + milestone invariants
            checkRegistry("五百四十七",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百四十七")!),
            // M1572 chapter 548 — Codable arc sealed doctrine + 21 PROOF tests
            checkRegistry("五百四十八",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百四十八")!),
            // M1576 chapter 549 — state-of-the-union audit doctrine + 23 PROOF tests
            checkRegistry("五百四十九",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百四十九")!),
            // M1580 chapter 550 — meta-catalogue + 21 PROOF tests
            checkRegistry("五百五十",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百五十")!),
            // M1584 chapter 551 — cascading Codable + doctrine + 10 PROOF tests
            checkRegistry("五百五十一",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百五十一")!),
            // M1588 chapter 552 — Codable cascade extension + 6 PROOF tests
            checkRegistry("五百五十二",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百五十二")!),
            // M1592 chapter 553 — Final Codable cascade arc seal + 5 PROOF tests + BASCodableCascadeArcSealedDoctrine milestone
            checkRegistry("五百五十三",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百五十三")!),
            // M1596 chapter 554 — Post-arc-seal follow-through + 8 PROOF tests + EndToEndJsonProof doctrine + 13 anti-drift tests
            checkRegistry("五百五十四",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百五十四")!),
            // M1600 chapter 555 — 5-namespace populated JSON PROOF + FiveNamespacePopulatedJsonProof doctrine + 15 anti-drift tests
            checkRegistry("五百五十五",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百五十五")!),
            // M1604 chapter 556 — JSON PROOF meta-catalogue + 15 anti-drift tests + 9 wire-in tests
            checkRegistry("五百五十六",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百五十六")!),
            // M1608 chapter 557 — 5-of-5 ProjectionsBlock populated JSON PROOF + new doctrine + 15 anti-drift/wire-in tests + catalogue extension
            checkRegistry("五百五十七",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百五十七")!),
            // M1612 chapter 558 — JSON REJECTION PROOF + rejection doctrine + 12 anti-drift/wire-in tests + catalogue extension to 6
            checkRegistry("五百五十八",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百五十八")!),
            // M1616 chapter 559 — Floating-point determinism PROOF + 100th typed surface CENTURY MILESTONE + catalogue extension to 7
            checkRegistry("五百五十九",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百五十九")!),
            // M1620 chapter 560 — Replay-determinism contract closure milestone (BASReplayDeterminismContractClosureDoctrine) + 29 PROOF tests
            checkRegistry("五百六十",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百六十")!),
            // M1624 chapter 561 — Real substrate change adding Codable to 3 aggregator types + PROOF tests + typed surface
            checkRegistry("五百六十一",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百六十一")!),
            // M1628 chapter 562 — Continued real substrate change adding Codable to 5 more aggregator types + PROOF tests + typed surface
            checkRegistry("五百六十二",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百六十二")!),
            // M1632 chapter 563 — Continued real substrate change adding Codable to 7 more aggregator types + PROOF tests + typed surface
            checkRegistry("五百六十三",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百六十三")!),
            // M1636 chapter 564 — Aggregator extension arc-seal milestone + 20 anti-drift + 13 wire-in PROOF tests
            checkRegistry("五百六十四",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百六十四")!),
            // M1640 chapter 565 — Post-arc follow-up Codable extension to 2 Inputs aggregator types
            checkRegistry("五百六十五",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百六十五")!),
            // M1644 chapter 566 — Cross-module Codable extension to 5 types in BASRuntimeCore + BASMemory
            checkRegistry("五百六十六",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百六十六")!),
            // M1648 chapter 567 — Continued cross-module Codable extension to 5 more BASMemory types
            checkRegistry("五百六十七",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百六十七")!),
            // M1652 chapter 568 — Third-wave cross-module Codable extension to 3 more types
            checkRegistry("五百六十八",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百六十八")!),
            // M1656 chapter 569 — Cross-module Codable extension arc-seal milestone
            checkRegistry("五百六十九",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百六十九")!),
            // M1660 chapter 570 — Tri-arc completion meta-meta milestone (round-number M1660)
            checkRegistry("五百七十",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百七十")!),
            // M1664 chapter 571 — First-ever Orchestration Codable extension
            checkRegistry("五百七十一",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百七十一")!),
            // M1668 chapter 572 — Second-wave Orchestration Codable extension
            checkRegistry("五百七十二",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百七十二")!),
            // M1672 chapter 573 — Third-wave Orchestration Codable extension
            checkRegistry("五百七十三",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百七十三")!),
            // M1676 chapter 574 — Orchestration Codable extension arc-seal
            checkRegistry("五百七十四",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百七十四")!),
            // M1680 chapter 575 — Quad-arc completion meta-meta milestone
            checkRegistry("五百七十五",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百七十五")!),
            // M1684 chapter 576 — Post-arc Orchestration Codable extension
            checkRegistry("五百七十六",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百七十六")!),
            // M1688 chapter 577 — Post-arc wave 2 Orchestration Codable
            checkRegistry("五百七十七",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百七十七")!),
            // M1692 chapter 578 — Post-arc wave 3 Orchestration Codable
            checkRegistry("五百七十八",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百七十八")!),
            // M1696 chapter 579 — Post-arc trilogy seal milestone
            checkRegistry("五百七十九",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百七十九")!),
            // M1700 chapter 580 — Penta-milestone completion meta-meta
            checkRegistry("五百八十",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百八十")!),
            // M1704 chapter 581 — First-ever BASLeaseLife Codable extension
            checkRegistry("五百八十一",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百八十一")!),
            // M1708 chapter 582 — BASLeaseLife wave 2 Codable extension
            checkRegistry("五百八十二",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百八十二")!),
            // M1712 chapter 583 — BASLeaseLife wave 3 Codable extension
            checkRegistry("五百八十三",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百八十三")!),
            // M1716 chapter 584 — BASLeaseLife arc-seal milestone
            checkRegistry("五百八十四",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百八十四")!),
            // M1720 chapter 585 — Hexa-milestone completion meta-meta
            checkRegistry("五百八十五",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百八十五")!),
            // M1724 chapter 586 — First-ever BASObservability Codable
            checkRegistry("五百八十六",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百八十六")!),
            // M1728 chapter 587 — BASMemory post-cross-module-arc Codable
            checkRegistry("五百八十七",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百八十七")!),
            // M1732 chapter 588 — BASMemory post-cross-module-arc wave 2
            checkRegistry("五百八十八",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百八十八")!),
            // M1736 chapter 589 — BASMemory post-cross-module-arc wave 3
            checkRegistry("五百八十九",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百八十九")!),
            // M1740 chapter 590 — BASMemory post-arc trilogy seal milestone
            checkRegistry("五百九十",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百九十")!),
            // M1744 chapter 591 — Hepta-milestone completion meta-meta
            checkRegistry("五百九十一",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百九十一")!),
            // M1748 chapter 592 — BASHostKit configuration + hint Codable
            checkRegistry("五百九十二",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百九十二")!),
            // M1752 chapter 593 — BASHostKit non-projection wave 2
            checkRegistry("五百九十三",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百九十三")!),
            // M1756 chapter 594 — BASHostKit non-projection wave 3
            checkRegistry("五百九十四",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百九十四")!),
            // M1760 chapter 595 — BASHostKit non-projection wave 4 CULMINATION
            checkRegistry("五百九十五",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百九十五")!),
            // M1764 chapter 596 — BASHostKit non-projection 4-wave arc seal
            checkRegistry("五百九十六",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百九十六")!),
            // M1768 chapter 597 — octa-milestone completion meta-meta
            checkRegistry("五百九十七",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百九十七")!),
            // M1772 chapter 598 — BASOrgan first-ever Codable extension wave 1
            checkRegistry("五百九十八",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百九十八")!),
            // M1776 chapter 599 — BASMLXAdapter first-ever Codable extension wave 1
            checkRegistry("五百九十九",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 五百九十九")!),
            // M1780 chapter 600 — REAL HOT-PATH ATTACK Phase I continuation V1 extraction
            checkRegistry("六百",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百")!),
            // M1784 chapter 601 — REAL HOT-PATH ATTACK Phase I continuation wave 2 V1 extraction
            checkRegistry("六百一",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百一")!),
            // M1788 chapter 602 — REAL HOT-PATH ATTACK Phase I continuation wave 3 BIG MOVE
            checkRegistry("六百二",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百二")!),
            // M1792 chapter 603 — BASChatCompletionsAdapter first-ever (9th-module)
            checkRegistry("六百三",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百三")!),
            // M1796 chapter 604 — BASAppleAdapters wave 1 (10th-module formal entry)
            checkRegistry("六百四",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百四")!),
            // M1800 chapter 605 — BASMetalSubstrate wave 1 (11th-module formal entry, M1800 milestone)
            checkRegistry("六百五",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百五")!),
            // M1804 chapter 606 — BASSovereign wave 1 (12th-module formal entry)
            checkRegistry("六百六",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百六")!),
            // M1808 chapter 607 — Post-octa hexa catalog meta-meta milestone
            checkRegistry("六百七",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百七")!),
            // M1812 chapter 608 — BASHostKit mesh-sweep Codable extension wave 1
            checkRegistry("六百八",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百八")!),
            // M1816 chapter 609 — BASOrgan Codable extension wave 2 gap-fill
            checkRegistry("六百九",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百九")!),
            // M1820 chapter 610 — BASOrchestration Codable extension continuation gap-fill
            checkRegistry("六百一十",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百一十")!),
            // M1824 chapter 611 — BASSovereign Codable extension wave 2 gap-fill
            checkRegistry("六百一十一",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百一十一")!),
            // M1828 chapter 612 — BASSovereign Codable extension wave 3 gap-fill
            checkRegistry("六百一十二",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百一十二")!),
            // M1832 chapter 613 — BASOrchestration Codable extension continuation wave 2 gap-fill (6th consecutive — triggers hexa catalog)
            checkRegistry("六百一十三",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百一十三")!),
            // M1836 chapter 614 — gap-fill hexa catalog meta-meta milestone (parallel to chapter 607 post-octa hexa)
            checkRegistry("六百一十四",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百一十四")!),
            // M1840 chapter 615 — BASLeaseLife Codable extension continuation gap-fill (first post-hexa-catalog gap-fill)
            checkRegistry("六百一十五",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百一十五")!),
            // M1844 chapter 616 — BASOrgan Codable extension wave 3 gap-fill (domino effect, 2nd post-hexa-catalog)
            checkRegistry("六百一十六",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百一十六")!),
            // M1848 chapter 617 — BASOrgan Codable extension wave 4 gap-fill (domino chain, 3rd post-hexa-catalog)
            checkRegistry("六百一十七",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百一十七")!),
            // M1852 chapter 618 — BASOrgan Codable extension wave 5 gap-fill (sibling enums, 4th post-hexa-catalog)
            checkRegistry("六百一十八",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百一十八")!),
            // M1856 chapter 619 — BASMemory Codable extension post-trilogy gap-fill (5th post-hexa, 1st non-BASOrgan)
            checkRegistry("六百一十九",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百一十九")!),
            // M1860 chapter 620 — BASHostKit Codable extension post-mesh-sweep gap-fill (6th post-hexa, triggers hexa #2)
            checkRegistry("六百二十",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百二十")!),
            // M1864 chapter 621 — 2nd gap-fill hexa catalog meta-meta milestone (parallel to chapter 614 hexa #1)
            checkRegistry("六百二十一",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百二十一")!),
            // M1868 chapter 622 — cross-module trio Codable extension gap-fill (1st post-hexa-#2)
            checkRegistry("六百二十二",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百二十二")!),
            // M1872 chapter 623 — BASObservability nested-pair Codable extension gap-fill (2nd post-hexa-#2)
            checkRegistry("六百二十三",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百二十三")!),
            // M1876 chapter 624 — BASRuntimeCore solo enum Codable extension gap-fill (3rd post-hexa-#2)
            checkRegistry("六百二十四",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百二十四")!),
            // M1880 chapter 625 — BASHostKit error trio Codable extension gap-fill (4th post-hexa-#2, M1880 round-number milestone)
            checkRegistry("六百二十五",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百二十五")!),
            // M1884 chapter 626 — BASMetalSubstrate metal error trio Codable extension gap-fill (5th post-hexa-#2)
            checkRegistry("六百二十六",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百二十六")!),
            // M1888 chapter 627 — cross-module error trio Codable extension gap-fill (6TH post-hexa-#2, triggers hexa #3)
            checkRegistry("六百二十七",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百二十七")!),
            // M1892 chapter 628 — 3rd gap-fill hexa catalog meta-meta milestone (parallel to chapter 614 hexa #1 + chapter 621 hexa #2)
            checkRegistry("六百二十八",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百二十八")!),
            // M1896 chapter 629 — BASMemory SQLite error trio Codable extension gap-fill (1st post-hexa-#3)
            checkRegistry("六百二十九",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百二十九")!),
            // M1900 chapter 630 — BASMetalSubstrate biomimetic error trio Codable extension gap-fill (2nd post-hexa-#3, M1900 round-number milestone)
            checkRegistry("六百三十",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百三十")!),
            // M1904 chapter 631 — BASMemory pipeline error trio Codable extension gap-fill (3rd post-hexa-#3, 2nd BASMemory touch)
            checkRegistry("六百三十一",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百三十一")!),
            // M1908 chapter 632 — cross-module BCM/HPC/Schedule error trio Codable extension gap-fill (4th post-hexa-#3)
            checkRegistry("六百三十二",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百三十二")!),
            // M1912 chapter 633 — BASSovereign error trio Codable extension gap-fill (5th post-hexa-#3, 1st BASSovereign post-hexa-#3 touch)
            checkRegistry("六百三十三",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百三十三")!),
            // M1916 chapter 634 — cross-module BASOrgan/BASObservability/BASOrchestration error trio Codable extension gap-fill (6th post-hexa-#3 FINAL before hexa #4)
            checkRegistry("六百三十四",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百三十四")!),
            // M1920 chapter 635 — 4TH gap-fill hexa catalog meta-meta milestone (cataloging 629-634)
            checkRegistry("六百三十五",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百三十五")!),
            // M1924 chapter 636 — cross-module BASWorldPrior + BASAppleAdapters error trio Codable extension gap-fill (1st post-hexa-#4, 1st BASWorldPrior touch ever)
            checkRegistry("六百三十六",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百三十六")!),
            // M1928 chapter 637 — BASRuntimeCore SQLite storage error trio Codable extension gap-fill (2nd post-hexa-#4, structural triple-mirror parallel)
            checkRegistry("六百三十七",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百三十七")!),
            // M1932 chapter 638 — BASSovereign secondary error trio Codable extension gap-fill (3rd post-hexa-#4, complements chapter 633 primary trio)
            checkRegistry("六百三十八",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百三十八")!),
            // M1936 chapter 639 — cross-module organ/tool/feature-builder error trio Codable extension gap-fill (4th post-hexa-#4, 2nd BASOrgan + 3rd BASAppleAdapters touch)
            checkRegistry("六百三十九",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百三十九")!),
            // M1940 chapter 640 — cross-module runtime-step enum trio Codable extension gap-fill (5th post-hexa-#4, FIRST non-Error-trio in post-hexa-#4 run)
            checkRegistry("六百四十",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百四十")!),
            // M1944 chapter 641 — categorization-enum trio Codable extension gap-fill (6th and FINAL post-hexa-#4, 2nd non-Error-trio in post-hexa-#4 run)
            checkRegistry("六百四十一",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百四十一")!),
            // M1948 chapter 642 — 5TH gap-fill hexa catalog meta-meta milestone (cataloging 636-641)
            checkRegistry("六百四十二",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百四十二")!),
            // M1952 chapter 643 — BASSovereign clock+tree typed-trio Codable extension gap-fill (1st post-hexa-#5, FIRST mixed enum+struct trio)
            checkRegistry("六百四十三",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百四十三")!),
            // M1956 chapter 644 — BASSovereign snapshot+token struct-trio Codable extension gap-fill (2nd post-hexa-#5, PURE STRUCT TRIO)
            checkRegistry("六百四十四",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百四十四")!),
            // M1960 chapter 645 — BASSovereign contamination-guard trio Codable extension gap-fill (3rd post-hexa-#5, DEEP-COVERAGE single-actor trio)
            checkRegistry("六百四十五",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百四十五")!),
            // M1964 chapter 646 — BASSovereign trust-record trio Codable extension gap-fill (4th post-hexa-#5, MULTI-ACTOR trio, breaks 20-surface barrier)
            checkRegistry("六百四十六",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百四十六")!),
            // M1968 chapter 647 — BASSovereign privilege-scan trio Codable extension gap-fill (5th post-hexa-#5, 3-level recursive Codable proof)
            checkRegistry("六百四十七",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百四十七")!),
            // M1972 chapter 648 — BASSovereign tertiary error trio Codable extension gap-fill (6th and FINAL post-hexa-#5, closes BASSovereign Error enum coverage)
            checkRegistry("六百四十八",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百四十八")!),
            // M1976 chapter 649 — 6TH gap-fill hexa catalog meta-meta milestone (cataloging 643-648, entirely BASSovereign)
            checkRegistry("六百四十九",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百四十九")!),
            // M1980 chapter 650 — BASRuntimeCore knowledge-mesh trio Codable extension gap-fill (1st post-hexa-#6, ROUND-NUMBER chapter)
            checkRegistry("六百五十",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百五十")!),
            // M1984 chapter 651 — BASSovereign reboot+verdict+lock trio Codable extension gap-fill (2nd post-hexa-#6)
            checkRegistry("六百五十一",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百五十一")!),
            // M1988 chapter 652 — Mamba+federated-storage trio Codable extension gap-fill (3rd post-hexa-#6, cross-module)
            checkRegistry("六百五十二",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百五十二")!),
            // M1992 chapter 653 — BASOrgan LLM-cache-mock trio Codable extension gap-fill (5th post-hexa-#6, single-module BASOrgan)
            checkRegistry("六百五十三",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百五十三")!),
            // M1996 chapter 654 — BASRuntimeCore validation-result trio Codable extension gap-fill (6th and FINAL post-hexa-#6, single-module BASRuntimeCore)
            checkRegistry("六百五十四",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百五十四")!),
            // M2000 chapter 655 — Cross-module validation-issue trio Codable extension gap-fill (6th and TRUE FINAL post-hexa-#6, cross-module BASHostKit + BASRuntimeCore, M2000 round-number milestone)
            checkRegistry("六百五十五",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百五十五")!),
            // M2004 chapter 656 — 7TH GAP-FILL HEXA CATALOG META-META MILESTONE cataloging post-hexa-#6 chapters 650-655
            checkRegistry("六百五十六",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百五十六")!),
            // M2008 chapter 657 — Roadmap-eval-mock trio Codable extension gap-fill (1st post-hexa-#7, cross-module BASRuntimeCore + BASOrgan)
            checkRegistry("六百五十七",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百五十七")!),
            // M2012 chapter 658 — BASMetalSubstrate biomimetic-observation trio Codable extension gap-fill (2nd post-hexa-#7, FIRST all-struct trio in autonomous loop)
            checkRegistry("六百五十八",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百五十八")!),
            // M2016 chapter 659 — kernel-result trio Codable extension gap-fill (3rd post-hexa-#7, 2nd consecutive all-struct trio, 600-COMMIT MILESTONE)
            checkRegistry("六百五十九",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百五十九")!),
            // M2020 chapter 660 — host-projection trio Codable extension gap-fill (4th post-hexa-#7, 3rd consecutive all-struct trio)
            checkRegistry("六百六十",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百六十")!),
            // M2024 chapter 661 — convenience-cadence-record trio Codable extension gap-fill (5th post-hexa-#7, 4th consecutive all-struct trio)
            checkRegistry("六百六十一",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百六十一")!),
            // M2028 chapter 662 — biomimetic-signal-record trio Codable extension gap-fill (6th and TRUE FINAL post-hexa-#7, 5th consecutive all-struct trio, closes 6-chapter run)
            checkRegistry("六百六十二",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百六十二")!),
            // M2032 chapter 663 — 8TH GAP-FILL HEXA CATALOG META-META MILESTONE cataloging post-hexa-#7 chapters 657-662
            checkRegistry("六百六十三",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百六十三")!),
            // M2036 chapter 664 — PHASE J 第一刀 wild-rolling-meerkat plan resumption first chapter
            checkRegistry("六百六十四",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百六十四")!),
            // M2040 chapter 665 — PHASE J kernel wiring continues (rmsNorm + rotaryEmbedding)
            checkRegistry("六百六十五",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百六十五")!),
            // M2044 chapter 666 — PHASE J kernel wiring (attention + softmax + layerNorm)
            checkRegistry("六百六十六",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百六十六")!),
            // M2048 chapter 667 — PHASE J COMPLETE (conv2D + 5x speedup benchmark + Phase J close-out doctrine)
            checkRegistry("六百六十七",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百六十七")!),
            // M2052 chapter 668 — PHASE K first chapter (runtimeMode toggle knob)
            checkRegistry("六百六十八",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百六十八")!),
            // M2056 chapter 669 — PHASE K dual-mode stress sweep tests
            checkRegistry("六百六十九",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百六十九")!),
            // M2060 chapter 670 — PHASE K env var bridge
            checkRegistry("六百七十",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百七十")!),
            // M2064 chapter 671 — PHASE K COMPLETE
            checkRegistry("六百七十一",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百七十一")!),
            // M2068 chapter 672 — Phase L pre-flip safety net
            checkRegistry("六百七十二",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百七十二")!),
            // M2072 chapter 673 — Phase L readiness gate
            checkRegistry("六百七十三",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百七十三")!),
            // M2076 chapter 674 — THE FLIP
            checkRegistry("六百七十四",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百七十四")!),
            // M2080 chapter 675 — PHASE L SEALED
            checkRegistry("六百七十五",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百七十五")!),
            // M2084 chapter 676 — HEXA #9 CATALOG (mid-plan)
            checkRegistry("六百七十六",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百七十六")!),
            // M2088 chapter 677 — Phase M SSMScan.metal ship
            checkRegistry("六百七十七",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百七十七")!),
            // M2092 chapter 678 — Phase M GPU+CPU+cross-val
            checkRegistry("六百七十八",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百七十八")!),
            // M2096 chapter 679 — Phase M canonical fixtures
            checkRegistry("六百七十九",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百七十九")!),
            // M2100 chapter 680 — Phase M extended + wallclock
            checkRegistry("六百八十",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百八十")!),
            // M2104 chapter 681 — Phase M 8-of-8 milestone
            checkRegistry("六百八十一",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百八十一")!),
            // M2108 chapter 682 — PHASE M SEALED
            checkRegistry("六百八十二",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百八十二")!),
            // M2112 chapter 683 — Phase N scope-reduced
            checkRegistry("六百八十三",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百八十三")!),
            // M2117 chapter 686 — Phase O opening
            checkRegistry("六百八十六",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百八十六")!),
            // M2121 chapter 687 — Phase O wire-in
            checkRegistry("六百八十七",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百八十七")!),
            // M2125 chapter 688 — Phase O FULLY SEALED
            checkRegistry("六百八十八",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百八十八")!),
            // M2129 chapter 689 — *** FINAL PLAN SEAL ***
            checkRegistry("六百八十九",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百八十九")!),
            // M2133 chapter 690 — post-seal LRU eviction
            checkRegistry("六百九十",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百九十")!),
            // M2137 chapter 691 — TTL + .never + catalog
            checkRegistry("六百九十一",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百九十一")!),
            // M2141 chapter 692 — FULL Tier A/B/C
            // completion via HONEST DISCOVERY
            checkRegistry("六百九十二",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百九十二")!),
            // M2145 chapter 693 — OPTIONAL pre-existing
            // cleanup arc
            checkRegistry("六百九十三",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百九十三")!),
            // M2149 chapter 694 — COMPREHENSIVE GAP
            // REMEDIATION arc
            checkRegistry("六百九十四",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百九十四")!),
            // M2153 chapter 695 — TERMINAL HONEST STATE
            // arc
            checkRegistry("六百九十五",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百九十五")!),
            // M2157 chapter 696 — RECOVERY OF TERMINAL
            // arc
            checkRegistry("六百九十六",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百九十六")!),
            // M2161 chapter 697 — 100% SIGBUS RECOVERY arc
            checkRegistry("六百九十七",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百九十七")!),
            // M2162 chapter 698 — HONEST SELF-CRITIQUE
            checkRegistry("六百九十八",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百九十八")!),
            // M2164 chapter 699 — CONSOLIDATION
            checkRegistry("六百九十九",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag:
                            "chapter 六百九十九")!),
            // M2166 chapter 700 — FURTHER CONSOLIDATION
            checkRegistry("七百",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百")!),
            // M2170 chapter 701 — MULTI-LANGUAGE
            // AUGMENTATION ARC scaffold
            checkRegistry("七百一",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百一")!),
            // M2174 chapter 702 — MULTI-LANGUAGE
            // AUGMENTATION ARC SQL pilot
            checkRegistry("七百二",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百二")!),
            // M2178 chapter 703 — MULTI-LANGUAGE
            // AUGMENTATION ARC C pilot
            checkRegistry("七百三",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百三")!),
            // M2182 chapter 704 — MULTI-LANGUAGE
            // AUGMENTATION ARC Metal pilot
            checkRegistry("七百四",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百四")!),
            // M2186 chapter 705 — MULTI-LANGUAGE
            // AUGMENTATION ARC C++ pilot
            checkRegistry("七百五",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百五")!),
            // M2190 chapter 706 — MULTI-LANGUAGE
            // AUGMENTATION ARC Rust pilot (FINAL of 5,
            // ARC SEALED)
            checkRegistry("七百六",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百六")!),
            // M2194 chapter 707 — RUST XCFRAMEWORK iOS-
            // SLICE EXPANSION (chapter 七百六 planned-
            // future-cut fulfilled)
            checkRegistry("七百七",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百七")!),
            // M2196 chapter 708 — ZERO-WARNING BUILD
            // (chapter 707 planned-future-cut #1 fulfilled)
            checkRegistry("七百八",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百八")!),
            // M2198 chapter 709 — DEAD-CODE CLEANUP
            // (chapter 708 strict-review acknowledgment
            // addressed)
            checkRegistry("七百九",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百九")!),
            // M2200 chapter 710 — PER-FLAG-DEFAULTS
            // REFACTOR (chapter 709 planned-future-cut
            // #3 fulfilled;unblocks production wire-in)
            checkRegistry("七百十",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百十")!),
            // M2202 chapter 711 — FIRST PRODUCTION
            // WIRE-IN (chapter 710 planned-future-cut
            // #1 fulfilled, 「全面 转向」 1/5 delivered)
            checkRegistry("七百十一",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百十一")!),
            // M2204 chapter 712 — FULL「全面 转向」
            // COMPLETION (remaining 4 pilots wired,
            // 5/5 default-ON at factory pattern)
            checkRegistry("七百十二",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百十二")!),
            // M2206 chapter 713 — HOST ADOPTION
            // CONVENIENCE (makeWithDefaults() factories
            // for all 5 pilots)
            checkRegistry("七百十三",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百十三")!),
            // M2208 chapter 714 — SUBSTRATE ADOPTION
            // AUDIT + 5-pilot e2e integration test
            checkRegistry("七百十四",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百十四")!),
            // M2210 chapter 715 — CONCURRENT-CONSTRUCTION
            // STRESS TESTS
            checkRegistry("七百十五",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百十五")!),
            // M2212 chapter 716 — BOUNDARY + ERROR-PATH
            // TESTS
            checkRegistry("七百十六",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百十六")!),
            // M2214 chapter 717 — ERROR CODABLE MATRIX +
            // CONFORMANCE
            checkRegistry("七百十七",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百十七")!),
            // M2216 chapter 718 — ERROR HASHABLE MATRIX +
            // SET DEDUPLICATION
            checkRegistry("七百十八",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百十八")!),
            // M2218 chapter 719 — ERROR SENDABLE CROSS-TASK
            // TRANSFER MATRIX
            checkRegistry("七百十九",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百十九")!),
            // M2220 chapter 720 — CASE-IDENTIFIER
            // INTROSPECTION MATRIX
            checkRegistry("七百二十",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百二十")!),
            // M2222 chapter 721 — WIRE-FORMAT SHA256
            // FINGERPRINT MATRIX
            checkRegistry("七百二十一",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百二十一")!),
            // M2224 chapter 722 — TYPE-CASE-IDENTIFIER
            // GLOBAL UNIQUENESS MATRIX
            checkRegistry("七百二十二",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百二十二")!),
            // M2226 chapter 723 — DESCRIPTION MATRIX
            checkRegistry("七百二十三",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百二十三")!),
            // M2228 chapter 724 — CASE COUNT INVARIANT
            checkRegistry("七百二十四",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百二十四")!),
            // M2230 chapter 725 — ACTOR TYPE-NAME INTRO
            checkRegistry("七百二十五",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百二十五")!),
            // M2232 chapter 726 — ACTOR COUNT INVARIANT
            checkRegistry("七百二十六",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百二十六")!),
            // M2234 chapter 727 — ACTOR SENDABLE TRANSFER
            checkRegistry("七百二十七",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百二十七")!),
            // M2236 chapter 728 — ACTOR MODULE-QUALIFIED NAME
            checkRegistry("七百二十八",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百二十八")!),
            // M2238 chapter 729 — ACTOR DISTINCT INSTANCE
            checkRegistry("七百二十九",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百二十九")!),
            // M2240 chapter 730 — MAKEWITHDEFAULTS FACTORY
            checkRegistry("七百三十",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百三十")!),
            // M2242 chapter 731 — FLAG ACTOR SURFACE
            checkRegistry("七百三十一",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百三十一")!),
            // M2244 chapter 732 — FACTORY FLAG-SAMPLING
            checkRegistry("七百三十二",
                record: BASChapterDoctrineRegistry
                    .recordFor(
                        chapterTag: "chapter 七百三十二")!)
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
                .mNumberLast),
            // M1343 chapter 491
            ("491",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百九十一")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百九十一")!
                .mNumberLast),
            // M1347 chapter 492
            ("492",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百九十二")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百九十二")!
                .mNumberLast),
            // M1352 chapter 493
            ("493",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百九十三")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百九十三")!
                .mNumberLast),
            // M1356 chapter 494
            ("494",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百九十四")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百九十四")!
                .mNumberLast),
            // M1360 chapter 495
            ("495",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百九十五")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百九十五")!
                .mNumberLast),
            // M1364 chapter 496
            ("496",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百九十六")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百九十六")!
                .mNumberLast),
            // M1368 chapter 497 — REAL HOT-PATH ATTACK SEALED
            ("497",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百九十七")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百九十七")!
                .mNumberLast),
            // M1372 chapter 498 — Tier 1 honest closure starts
            ("498",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百九十八")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百九十八")!
                .mNumberLast),
            // M1376 chapter 499 — 更极致/低熵 substantive
            ("499",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百九十九")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 四百九十九")!
                .mNumberLast),
            // M1380 chapter 500 — 最创新/原生神经引擎 push
            ("500",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百")!
                .mNumberLast),
            // M1383 chapter 501 — Tier 1 honest SEAL at 52/60
            ("501",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百一")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百一")!
                .mNumberLast),
            // M1388 chapter 502 — wire-in push
            ("502",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百二")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百二")!
                .mNumberLast),
            // M1392 chapter 503 — observer wire-ins
            ("503",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百三")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百三")!
                .mNumberLast),
            // M1396 chapter 504 — bundle aggregator wire-ins
            ("504",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百四")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百四")!
                .mNumberLast),
            // M1400 chapter 505 — unified audit emission MILESTONE
            ("505",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百五")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百五")!
                .mNumberLast),
            // M1404 chapter 506 — cluster B fold continues
            ("506",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百六")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百六")!
                .mNumberLast),
            // M1408 chapter 507 — Tier C ADR-019 entry
            ("507",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百七")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百七")!
                .mNumberLast),
            // M1412 chapter 508 — Tier C ADR-019 COMPLETE
            ("508",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百八")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百八")!
                .mNumberLast),
            // M1416 chapter 509 — Tier C migration adapters
            ("509",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百九")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百九")!
                .mNumberLast),
            // M1420 chapter 510 — V1 monolith fold continues
            ("510",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百十")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百十")!
                .mNumberLast),
            // M1424 chapter 511 — projection-block fold
            ("511",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百十一")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百十一")!
                .mNumberLast),
            // M1428 chapter 512 — projection-block wire-in
            ("512",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百十二")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百十二")!
                .mNumberLast),
            // M1432 chapter 513 — 5-pipeline unified audit
            ("513",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百十三")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百十三")!
                .mNumberLast),
            // M1436 chapter 514 — 3rd typed input block
            ("514",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百十四")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百十四")!
                .mNumberLast),
            // M1440 chapter 515 — V1 monolith projections fold
            ("515",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百十五")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百十五")!
                .mNumberLast),
            // M1444 chapter 516 — 4th input block + V1 splice extension
            ("516",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百十六")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百十六")!
                .mNumberLast),
            // M1448 chapter 517 — 5th input block + V1 splice extension
            ("517",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百十七")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百十七")!
                .mNumberLast),
            // M1452 chapter 518 — 6th input block + V1 splice extension
            ("518",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百十八")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百十八")!
                .mNumberLast),
            // M1456 chapter 519 — FIRST PRODUCTION WIRE-IN
            ("519",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百十九")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百十九")!
                .mNumberLast),
            // M1460 chapter 520 — 10-chapter arc close-out
            ("520",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百二十")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百二十")!
                .mNumberLast),
            // M1464 chapter 521 — 7th input block + V1 splice
            ("521",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百二十一")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百二十一")!
                .mNumberLast),
            // M1468 chapter 522 — 100% V1 packaging coverage
            ("522",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百二十二")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百二十二")!
                .mNumberLast),
            // M1472 chapter 523 — 12-chapter arc milestone
            ("523",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百二十三")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百二十三")!
                .mNumberLast),
            // M1476 chapter 524 — pivot to BASEBrainTurnResult fold
            ("524",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百二十四")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百二十四")!
                .mNumberLast),
            // M1480 chapter 525 — sovereign bundle 2nd cluster
            ("525",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百二十五")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百二十五")!
                .mNumberLast),
            // M1484 chapter 526 — audit-projection-forward 3rd cluster
            ("526",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百二十六")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百二十六")!
                .mNumberLast),
            // M1488 chapter 527 — parallel-run reconciliation
            ("527",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百二十七")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百二十七")!
                .mNumberLast),
            // M1492 chapter 528 — cognitive frames 5th cluster
            ("528",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百二十八")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百二十八")!
                .mNumberLast),
            // M1496 chapter 529 — risk/choice 6th cluster
            ("529",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百二十九")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百二十九")!
                .mNumberLast),
            // M1500 chapter 530 — M1500 MILESTONE misc 7th cluster
            ("530",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百三十")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百三十")!
                .mNumberLast),
            // M1504 chapter 531 — device/lifecycle 8th cluster
            ("531",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百三十一")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百三十一")!
                .mNumberLast),
            // M1508 chapter 532 — 100% PACKAGING MILESTONE — forensic 9th + FINAL cluster
            ("532",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百三十二")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百三十二")!
                .mNumberLast),
            // M1512 chapter 533 — fold arc sealed milestone doctrine + 20 PROOF tests
            ("533",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百三十三")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百三十三")!
                .mNumberLast),
            // M1516 chapter 534 — 30-declaration dead-code purge + doctrine + 11 PROOF tests
            ("534",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百三十四")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百三十四")!
                .mNumberLast),
            // M1520 chapter 535 — substrate-wide warning purge + doctrine + 12 PROOF tests
            ("535",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百三十五")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百三十五")!
                .mNumberLast),
            // M1524 chapter 536 — typed observability sink + wire-in + 7 PROOF tests
            ("536",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百三十六")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百三十六")!
                .mNumberLast),
            // M1528 chapter 537 — engine observation failure sink + wire-in + 9 PROOF tests
            ("537",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百三十七")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百三十七")!
                .mNumberLast),
            // M1532 chapter 538 — test-target warning purge + doctrine + 13 PROOF tests
            ("538",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百三十八")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百三十八")!
                .mNumberLast),
            // M1536 chapter 539 — 3rd typed observability sink (cross-module) + wire-in + 10 PROOF tests
            ("539",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百三十九")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百三十九")!
                .mNumberLast),
            // M1540 chapter 540 — unified observability sink catalogue + 23 PROOF tests
            ("540",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百四十")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百四十")!
                .mNumberLast),
            // M1544 chapter 541 — Codable conformance + doctrine + 7 PROOF tests
            ("541",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百四十一")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百四十一")!
                .mNumberLast),
            // M1548 chapter 542 — Codable round-trip + Hashable blocker doctrine + 10 PROOF tests
            ("542",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百四十二")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百四十二")!
                .mNumberLast),
            // M1552 chapter 543 — Codable round-trip coverage extension + tracking doctrine + 13 PROOF tests
            ("543",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百四十三")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百四十三")!
                .mNumberLast),
            // M1556 chapter 544 — MiscBundle round-trip + coverage doctrine update + anti-drift tests
            ("544",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百四十四")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百四十四")!
                .mNumberLast),
            // M1560 chapter 545 — DeviceLifecycle round-trip + coverage doctrine update + anti-drift tests
            ("545",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百四十五")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百四十五")!
                .mNumberLast),
            // M1564 chapter 546 — RiskChoice round-trip + coverage doctrine update + anti-drift tests
            ("546",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百四十六")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百四十六")!
                .mNumberLast),
            // M1568 chapter 547 — 100% MILESTONE — CognitiveFrames round-trip + 100% doctrine + milestone invariants
            ("547",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百四十七")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百四十七")!
                .mNumberLast),
            // M1572 chapter 548 — Codable arc sealed doctrine + 21 PROOF tests
            ("548",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百四十八")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百四十八")!
                .mNumberLast),
            // M1576 chapter 549 — state-of-the-union audit doctrine + 23 PROOF tests
            ("549",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百四十九")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百四十九")!
                .mNumberLast),
            // M1580 chapter 550 — meta-catalogue + 21 PROOF tests
            ("550",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百五十")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百五十")!
                .mNumberLast),
            // M1584 chapter 551 — cascading Codable + doctrine + 10 PROOF tests
            ("551",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百五十一")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百五十一")!
                .mNumberLast),
            // M1588 chapter 552 — Codable cascade extension + 6 PROOF tests
            ("552",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百五十二")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百五十二")!
                .mNumberLast),
            // M1592 chapter 553 — Final Codable cascade arc seal + 5 PROOF tests + BASCodableCascadeArcSealedDoctrine
            ("553",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百五十三")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百五十三")!
                .mNumberLast),
            // M1596 chapter 554 — Post-arc-seal follow-through + 8 PROOF tests + EndToEndJsonProof doctrine + 13 anti-drift tests
            ("554",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百五十四")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百五十四")!
                .mNumberLast),
            // M1600 chapter 555 — 5-namespace populated JSON PROOF + FiveNamespacePopulatedJsonProof doctrine + 15 anti-drift tests
            ("555",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百五十五")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百五十五")!
                .mNumberLast),
            // M1604 chapter 556 — JSON PROOF meta-catalogue + 15 anti-drift tests + 9 wire-in tests
            ("556",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百五十六")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百五十六")!
                .mNumberLast),
            // M1608 chapter 557 — 5-of-5 ProjectionsBlock populated JSON PROOF + new doctrine + 15 anti-drift/wire-in tests + catalogue extension
            ("557",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百五十七")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百五十七")!
                .mNumberLast),
            // M1612 chapter 558 — JSON REJECTION PROOF + new doctrine + 12 anti-drift/wire-in tests + catalogue extension to 6
            ("558",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百五十八")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百五十八")!
                .mNumberLast),
            // M1616 chapter 559 — Floating-point determinism PROOF + 100th typed surface + catalogue extension to 7
            ("559",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百五十九")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百五十九")!
                .mNumberLast),
            // M1620 chapter 560 — Replay-determinism contract closure milestone + 29 PROOF tests
            ("560",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百六十")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百六十")!
                .mNumberLast),
            // M1624 chapter 561 — Real substrate change adding Codable to 3 aggregator types + PROOF tests + typed surface
            ("561",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百六十一")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百六十一")!
                .mNumberLast),
            // M1628 chapter 562 — Continued real substrate change adding Codable to 5 more aggregator types
            ("562",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百六十二")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百六十二")!
                .mNumberLast),
            // M1632 chapter 563 — Continued real substrate change adding Codable to 7 more aggregator types
            ("563",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百六十三")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百六十三")!
                .mNumberLast),
            // M1636 chapter 564 — Aggregator extension arc-seal milestone
            ("564",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百六十四")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百六十四")!
                .mNumberLast),
            // M1640 chapter 565 — Post-arc Inputs Codable extension
            ("565",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百六十五")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百六十五")!
                .mNumberLast),
            // M1644 chapter 566 — Cross-module Codable extension
            ("566",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百六十六")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百六十六")!
                .mNumberLast),
            // M1648 chapter 567 — Continued cross-module Codable extension
            ("567",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百六十七")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百六十七")!
                .mNumberLast),
            // M1652 chapter 568 — Third-wave cross-module Codable extension
            ("568",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百六十八")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百六十八")!
                .mNumberLast),
            // M1656 chapter 569 — Cross-module extension arc-seal milestone
            ("569",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百六十九")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百六十九")!
                .mNumberLast),
            // M1660 chapter 570 — Tri-arc completion meta-meta milestone (round-number M1660)
            ("570",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百七十")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百七十")!
                .mNumberLast),
            // M1664 chapter 571 — First-ever Orchestration Codable extension
            ("571",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百七十一")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百七十一")!
                .mNumberLast),
            // M1668 chapter 572 — Second-wave Orchestration Codable extension
            ("572",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百七十二")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百七十二")!
                .mNumberLast),
            // M1672 chapter 573 — Third-wave Orchestration Codable extension
            ("573",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百七十三")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百七十三")!
                .mNumberLast),
            // M1676 chapter 574 — Orchestration Codable extension arc-seal
            ("574",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百七十四")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百七十四")!
                .mNumberLast),
            // M1680 chapter 575 — Quad-arc completion meta-meta milestone
            ("575",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百七十五")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百七十五")!
                .mNumberLast),
            // M1684 chapter 576 — Post-arc Orchestration Codable extension
            ("576",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百七十六")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百七十六")!
                .mNumberLast),
            // M1688 chapter 577 — Post-arc wave 2 Orchestration Codable
            ("577",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百七十七")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百七十七")!
                .mNumberLast),
            // M1692 chapter 578 — Post-arc wave 3 Orchestration Codable
            ("578",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百七十八")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百七十八")!
                .mNumberLast),
            // M1696 chapter 579 — Post-arc trilogy seal milestone
            ("579",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百七十九")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百七十九")!
                .mNumberLast),
            // M1700 chapter 580 — Penta-milestone completion meta-meta
            ("580",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百八十")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百八十")!
                .mNumberLast),
            // M1704 chapter 581 — First-ever BASLeaseLife Codable extension
            ("581",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百八十一")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百八十一")!
                .mNumberLast),
            // M1708 chapter 582 — BASLeaseLife wave 2 Codable extension
            ("582",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百八十二")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百八十二")!
                .mNumberLast),
            // M1712 chapter 583 — BASLeaseLife wave 3 Codable extension
            ("583",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百八十三")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百八十三")!
                .mNumberLast),
            // M1716 chapter 584 — BASLeaseLife arc-seal milestone
            ("584",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百八十四")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百八十四")!
                .mNumberLast),
            // M1720 chapter 585 — Hexa-milestone completion meta-meta
            ("585",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百八十五")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百八十五")!
                .mNumberLast),
            // M1724 chapter 586 — First-ever BASObservability Codable
            ("586",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百八十六")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百八十六")!
                .mNumberLast),
            // M1728 chapter 587 — BASMemory post-cross-module-arc Codable
            ("587",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百八十七")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百八十七")!
                .mNumberLast),
            // M1732 chapter 588 — BASMemory post-cross-module-arc wave 2
            ("588",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百八十八")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百八十八")!
                .mNumberLast),
            // M1736 chapter 589 — BASMemory post-cross-module-arc wave 3
            ("589",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百八十九")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百八十九")!
                .mNumberLast),
            // M1740 chapter 590 — BASMemory post-arc trilogy seal milestone
            ("590",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百九十")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百九十")!
                .mNumberLast),
            // M1744 chapter 591 — Hepta-milestone completion meta-meta
            ("591",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百九十一")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百九十一")!
                .mNumberLast),
            // M1748 chapter 592 — BASHostKit configuration + hint Codable
            ("592",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百九十二")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百九十二")!
                .mNumberLast),
            // M1752 chapter 593 — BASHostKit non-projection wave 2
            ("593",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百九十三")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百九十三")!
                .mNumberLast),
            // M1756 chapter 594 — BASHostKit non-projection wave 3
            ("594",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百九十四")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百九十四")!
                .mNumberLast),
            // M1760 chapter 595 — BASHostKit non-projection wave 4 CULMINATION
            ("595",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百九十五")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百九十五")!
                .mNumberLast),
            // M1764 chapter 596 — BASHostKit non-projection 4-wave arc seal
            ("596",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百九十六")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百九十六")!
                .mNumberLast),
            // M1768 chapter 597 — octa-milestone completion meta-meta
            ("597",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百九十七")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百九十七")!
                .mNumberLast),
            // M1772 chapter 598 — BASOrgan first-ever Codable extension wave 1
            ("598",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百九十八")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百九十八")!
                .mNumberLast),
            // M1776 chapter 599 — BASMLXAdapter first-ever Codable extension wave 1
            ("599",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百九十九")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 五百九十九")!
                .mNumberLast),
            // M1780 chapter 600 — REAL HOT-PATH ATTACK Phase I continuation V1 extraction
            ("600",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百")!
                .mNumberLast),
            // M1784 chapter 601 — REAL HOT-PATH ATTACK Phase I continuation wave 2 V1 extraction
            ("601",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百一")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百一")!
                .mNumberLast),
            // M1788 chapter 602 — REAL HOT-PATH ATTACK Phase I continuation wave 3 BIG MOVE
            ("602",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百二")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百二")!
                .mNumberLast),
            // M1792 chapter 603 — BASChatCompletionsAdapter first-ever (9th-module)
            ("603",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百三")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百三")!
                .mNumberLast),
            // M1796 chapter 604 — BASAppleAdapters wave 1 (10th-module formal entry)
            ("604",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百四")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百四")!
                .mNumberLast),
            // M1800 chapter 605 — BASMetalSubstrate wave 1 (11th-module formal entry, M1800)
            ("605",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百五")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百五")!
                .mNumberLast),
            // M1804 chapter 606 — BASSovereign wave 1 (12th-module formal entry)
            ("606",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百六")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百六")!
                .mNumberLast),
            // M1808 chapter 607 — Post-octa hexa catalog meta-meta milestone
            ("607",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百七")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百七")!
                .mNumberLast),
            // M1812 chapter 608 — BASHostKit mesh-sweep Codable extension wave 1
            ("608",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百八")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百八")!
                .mNumberLast),
            // M1816 chapter 609 — BASOrgan Codable extension wave 2 gap-fill
            ("609",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百九")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百九")!
                .mNumberLast),
            // M1820 chapter 610 — BASOrchestration Codable extension continuation gap-fill
            ("610",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百一十")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百一十")!
                .mNumberLast),
            // M1824 chapter 611 — BASSovereign Codable extension wave 2 gap-fill
            ("611",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百一十一")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百一十一")!
                .mNumberLast),
            // M1828 chapter 612 — BASSovereign Codable extension wave 3 gap-fill
            ("612",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百一十二")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百一十二")!
                .mNumberLast),
            // M1832 chapter 613 — BASOrchestration Codable extension continuation wave 2 gap-fill (6th consecutive)
            ("613",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百一十三")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百一十三")!
                .mNumberLast),
            // M1836 chapter 614 — gap-fill hexa catalog meta-meta milestone (parallel to chapter 607 post-octa hexa)
            ("614",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百一十四")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百一十四")!
                .mNumberLast),
            // M1840 chapter 615 — BASLeaseLife Codable extension continuation gap-fill (first post-hexa-catalog)
            ("615",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百一十五")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百一十五")!
                .mNumberLast),
            // M1844 chapter 616 — BASOrgan Codable extension wave 3 gap-fill (domino effect)
            ("616",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百一十六")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百一十六")!
                .mNumberLast),
            // M1848 chapter 617 — BASOrgan Codable extension wave 4 gap-fill (domino chain)
            ("617",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百一十七")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百一十七")!
                .mNumberLast),
            // M1852 chapter 618 — BASOrgan Codable extension wave 5 gap-fill (sibling enums)
            ("618",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百一十八")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百一十八")!
                .mNumberLast),
            // M1856 chapter 619 — BASMemory Codable extension post-trilogy gap-fill
            ("619",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百一十九")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百一十九")!
                .mNumberLast),
            // M1860 chapter 620 — BASHostKit Codable extension post-mesh-sweep gap-fill
            ("620",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百二十")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百二十")!
                .mNumberLast),
            // M1864 chapter 621 — 2nd gap-fill hexa catalog meta-meta milestone
            ("621",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百二十一")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百二十一")!
                .mNumberLast),
            // M1868 chapter 622 — cross-module trio Codable extension gap-fill
            ("622",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百二十二")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百二十二")!
                .mNumberLast),
            // M1872 chapter 623 — BASObservability nested-pair Codable extension gap-fill
            ("623",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百二十三")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百二十三")!
                .mNumberLast),
            // M1876 chapter 624 — BASRuntimeCore solo enum Codable extension gap-fill
            ("624",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百二十四")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百二十四")!
                .mNumberLast),
            // M1880 chapter 625 — BASHostKit error trio Codable extension gap-fill
            ("625",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百二十五")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百二十五")!
                .mNumberLast),
            // M1884 chapter 626 — BASMetalSubstrate metal error trio Codable extension gap-fill
            ("626",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百二十六")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百二十六")!
                .mNumberLast),
            // M1888 chapter 627 — cross-module error trio Codable extension gap-fill
            ("627",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百二十七")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百二十七")!
                .mNumberLast),
            // M1892 chapter 628 — 3rd gap-fill hexa catalog meta-meta milestone
            ("628",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百二十八")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百二十八")!
                .mNumberLast),
            // M1896 chapter 629 — BASMemory SQLite error trio Codable extension gap-fill
            ("629",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百二十九")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百二十九")!
                .mNumberLast),
            // M1900 chapter 630 — BASMetalSubstrate biomimetic error trio Codable extension gap-fill
            ("630",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百三十")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百三十")!
                .mNumberLast),
            // M1904 chapter 631 — BASMemory pipeline error trio Codable extension gap-fill
            ("631",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百三十一")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百三十一")!
                .mNumberLast),
            // M1908 chapter 632 — cross-module BCM/HPC/Schedule error trio Codable extension gap-fill
            ("632",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百三十二")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百三十二")!
                .mNumberLast),
            // M1912 chapter 633 — BASSovereign error trio Codable extension gap-fill
            ("633",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百三十三")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百三十三")!
                .mNumberLast),
            // M1916 chapter 634 — cross-module BASOrgan/BASObservability/BASOrchestration error trio Codable extension gap-fill (FINAL pre-hexa #4)
            ("634",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百三十四")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百三十四")!
                .mNumberLast),
            // M1920 chapter 635 — 4TH gap-fill hexa catalog meta-meta milestone (cataloging 629-634)
            ("635",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百三十五")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百三十五")!
                .mNumberLast),
            // M1924 chapter 636 — cross-module BASWorldPrior + BASAppleAdapters error trio Codable extension gap-fill (1st post-hexa-#4)
            ("636",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百三十六")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百三十六")!
                .mNumberLast),
            // M1928 chapter 637 — BASRuntimeCore SQLite storage error trio Codable extension gap-fill (2nd post-hexa-#4)
            ("637",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百三十七")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百三十七")!
                .mNumberLast),
            // M1932 chapter 638 — BASSovereign secondary error trio Codable extension gap-fill (3rd post-hexa-#4)
            ("638",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百三十八")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百三十八")!
                .mNumberLast),
            // M1936 chapter 639 — cross-module organ/tool/feature-builder error trio Codable extension gap-fill (4th post-hexa-#4)
            ("639",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百三十九")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百三十九")!
                .mNumberLast),
            // M1940 chapter 640 — cross-module runtime-step enum trio Codable extension gap-fill (5th post-hexa-#4)
            ("640",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百四十")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百四十")!
                .mNumberLast),
            // M1944 chapter 641 — categorization-enum trio Codable extension gap-fill (6th and FINAL post-hexa-#4)
            ("641",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百四十一")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百四十一")!
                .mNumberLast),
            // M1948 chapter 642 — 5TH gap-fill hexa catalog meta-meta milestone (cataloging 636-641)
            ("642",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百四十二")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百四十二")!
                .mNumberLast),
            // M1952 chapter 643 — BASSovereign clock+tree typed-trio Codable extension gap-fill (1st post-hexa-#5)
            ("643",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百四十三")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百四十三")!
                .mNumberLast),
            // M1956 chapter 644 — BASSovereign snapshot+token struct-trio Codable extension gap-fill (2nd post-hexa-#5)
            ("644",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百四十四")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百四十四")!
                .mNumberLast),
            // M1960 chapter 645 — BASSovereign contamination-guard trio Codable extension gap-fill (3rd post-hexa-#5)
            ("645",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百四十五")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百四十五")!
                .mNumberLast),
            // M1964 chapter 646 — BASSovereign trust-record trio Codable extension gap-fill (4th post-hexa-#5)
            ("646",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百四十六")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百四十六")!
                .mNumberLast),
            // M1968 chapter 647 — BASSovereign privilege-scan trio Codable extension gap-fill (5th post-hexa-#5)
            ("647",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百四十七")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百四十七")!
                .mNumberLast),
            // M1972 chapter 648 — BASSovereign tertiary error trio Codable extension gap-fill (6th and FINAL post-hexa-#5)
            ("648",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百四十八")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百四十八")!
                .mNumberLast),
            // M1976 chapter 649 — 6TH gap-fill hexa catalog meta-meta milestone (cataloging 643-648)
            ("649",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百四十九")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百四十九")!
                .mNumberLast),
            // M1980 chapter 650 — BASRuntimeCore knowledge-mesh trio Codable extension gap-fill (1st post-hexa-#6, ROUND-NUMBER chapter)
            ("650",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百五十")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百五十")!
                .mNumberLast),
            // M1984 chapter 651 — BASSovereign reboot+verdict+lock trio Codable extension gap-fill (2nd post-hexa-#6)
            ("651",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百五十一")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百五十一")!
                .mNumberLast),
            // M1988 chapter 652 — Mamba+federated-storage trio Codable extension gap-fill (3rd post-hexa-#6)
            ("652",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百五十二")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百五十二")!
                .mNumberLast),
            // M1992 chapter 653 — BASOrgan LLM-cache-mock trio Codable extension gap-fill (5th post-hexa-#6)
            ("653",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百五十三")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百五十三")!
                .mNumberLast),
            // M1996 chapter 654 — BASRuntimeCore validation-result trio Codable extension gap-fill (6th and FINAL post-hexa-#6)
            ("654",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百五十四")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百五十四")!
                .mNumberLast),
            // M2000 chapter 655 — Cross-module validation-issue trio Codable extension gap-fill (6th and TRUE FINAL post-hexa-#6, M2000 round-number milestone)
            ("655",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百五十五")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百五十五")!
                .mNumberLast),
            // M2004 chapter 656 — 7TH GAP-FILL HEXA CATALOG META-META MILESTONE
            ("656",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百五十六")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百五十六")!
                .mNumberLast),
            // M2008 chapter 657 — Roadmap-eval-mock trio Codable extension gap-fill (1st post-hexa-#7)
            ("657",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百五十七")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百五十七")!
                .mNumberLast),
            // M2012 chapter 658 — BASMetalSubstrate biomimetic-observation trio Codable extension gap-fill (2nd post-hexa-#7, FIRST all-struct trio)
            ("658",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百五十八")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百五十八")!
                .mNumberLast),
            // M2016 chapter 659 — kernel-result trio Codable extension gap-fill (3rd post-hexa-#7)
            ("659",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百五十九")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百五十九")!
                .mNumberLast),
            // M2020 chapter 660 — host-projection trio Codable extension gap-fill (4th post-hexa-#7)
            ("660",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百六十")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百六十")!
                .mNumberLast),
            // M2024 chapter 661 — convenience-cadence-record trio Codable extension gap-fill (5th post-hexa-#7)
            ("661",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百六十一")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百六十一")!
                .mNumberLast),
            // M2028 chapter 662 — biomimetic-signal-record trio Codable extension gap-fill (6th and TRUE FINAL post-hexa-#7)
            ("662",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百六十二")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百六十二")!
                .mNumberLast),
            // M2032 chapter 663 — 8TH GAP-FILL HEXA CATALOG META-META MILESTONE
            ("663",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百六十三")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百六十三")!
                .mNumberLast),
            // M2036 chapter 664 — PHASE J 第一刀 plan resumption
            ("664",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百六十四")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百六十四")!
                .mNumberLast),
            // M2040 chapter 665 — PHASE J kernel wiring (rmsNorm + rotaryEmbedding)
            ("665",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百六十五")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百六十五")!
                .mNumberLast),
            // M2044 chapter 666 — PHASE J kernel wiring (attention + softmax + layerNorm)
            ("666",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百六十六")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百六十六")!
                .mNumberLast),
            // M2048 chapter 667 — PHASE J COMPLETE (conv2D + 5x speedup benchmark + Phase J close-out doctrine)
            ("667",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百六十七")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百六十七")!
                .mNumberLast),
            // M2052 chapter 668 — PHASE K first chapter (runtimeMode toggle knob)
            ("668",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百六十八")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百六十八")!
                .mNumberLast),
            // M2056 chapter 669 — PHASE K dual-mode stress sweep tests
            ("669",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百六十九")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百六十九")!
                .mNumberLast),
            // M2060 chapter 670 — PHASE K env var bridge
            ("670",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百七十")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百七十")!
                .mNumberLast),
            // M2064 chapter 671 — PHASE K COMPLETE
            ("671",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百七十一")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百七十一")!
                .mNumberLast),
            // M2068 chapter 672 — Phase L pre-flip safety net
            ("672",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百七十二")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百七十二")!
                .mNumberLast),
            // M2072 chapter 673 — Phase L readiness gate
            ("673",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百七十三")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百七十三")!
                .mNumberLast),
            // M2076 chapter 674 — THE FLIP
            ("674",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百七十四")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百七十四")!
                .mNumberLast),
            // M2080 chapter 675 — PHASE L SEALED
            ("675",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百七十五")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百七十五")!
                .mNumberLast),
            // M2084 chapter 676 — HEXA #9 CATALOG (mid-plan)
            ("676",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百七十六")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百七十六")!
                .mNumberLast),
            // M2088 chapter 677
            ("677",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百七十七")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百七十七")!
                .mNumberLast),
            // M2092 chapter 678
            ("678",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百七十八")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百七十八")!
                .mNumberLast),
            // M2096 chapter 679
            ("679",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百七十九")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百七十九")!
                .mNumberLast),
            // M2100 chapter 680
            ("680",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百八十")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百八十")!
                .mNumberLast),
            // M2104 chapter 681
            ("681",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百八十一")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百八十一")!
                .mNumberLast),
            // M2108 chapter 682 — PHASE M SEALED
            ("682",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百八十二")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百八十二")!
                .mNumberLast),
            // M2112 chapter 683 — Phase N (scope-reduced)
            ("683",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百八十三")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百八十三")!
                .mNumberLast),
            // M2117 chapter 686 — Phase O opening
            ("686",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百八十六")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百八十六")!
                .mNumberLast),
            // M2121 chapter 687 — Phase O wire-in
            ("687",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百八十七")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百八十七")!
                .mNumberLast),
            // M2125 chapter 688 — Phase O FULLY SEALED
            ("688",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百八十八")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百八十八")!
                .mNumberLast),
            // M2129 chapter 689 — *** FINAL PLAN SEAL ***
            ("689",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百八十九")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百八十九")!
                .mNumberLast),
            // M2133 chapter 690 — post-seal LRU eviction
            ("690",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百九十")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百九十")!
                .mNumberLast),
            // M2137 chapter 691 — TTL + .never + catalog
            ("691",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百九十一")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百九十一")!
                .mNumberLast),
            // M2141 chapter 692 — FULL Tier A/B/C
            ("692",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百九十二")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百九十二")!
                .mNumberLast),
            // M2145 chapter 693 — OPTIONAL pre-existing
            // cleanup arc
            ("693",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百九十三")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百九十三")!
                .mNumberLast),
            // M2149 chapter 694 — COMPREHENSIVE GAP
            // REMEDIATION arc
            ("694",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百九十四")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百九十四")!
                .mNumberLast),
            // M2153 chapter 695 — TERMINAL HONEST STATE
            // arc
            ("695",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百九十五")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百九十五")!
                .mNumberLast),
            // M2157 chapter 696 — RECOVERY OF TERMINAL
            // arc
            ("696",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百九十六")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百九十六")!
                .mNumberLast),
            // M2161 chapter 697 — 100% SIGBUS RECOVERY
            ("697",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百九十七")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百九十七")!
                .mNumberLast),
            // M2162 chapter 698 — HONEST SELF-CRITIQUE
            ("698",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百九十八")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百九十八")!
                .mNumberLast),
            // M2164 chapter 699 — CONSOLIDATION
            ("699",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百九十九")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 六百九十九")!
                .mNumberLast),
            // M2166 chapter 700 — FURTHER CONSOLIDATION
            ("700",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百")!
                .mNumberLast),
            // M2170 chapter 701 — MULTI-LANGUAGE
            // AUGMENTATION SCAFFOLD
            ("701",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百一")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百一")!
                .mNumberLast),
            // M2174 chapter 702 — MULTI-LANGUAGE
            // AUGMENTATION SQL PILOT
            ("702",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百二")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百二")!
                .mNumberLast),
            // M2178 chapter 703 — MULTI-LANGUAGE
            // AUGMENTATION C PILOT
            ("703",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百三")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百三")!
                .mNumberLast),
            // M2182 chapter 704 — MULTI-LANGUAGE
            // AUGMENTATION METAL PILOT
            ("704",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百四")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百四")!
                .mNumberLast),
            // M2186 chapter 705 — MULTI-LANGUAGE
            // AUGMENTATION C++ PILOT
            ("705",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百五")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百五")!
                .mNumberLast),
            // M2190 chapter 706 — MULTI-LANGUAGE
            // AUGMENTATION RUST PILOT (FINAL, ARC SEALED)
            ("706",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百六")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百六")!
                .mNumberLast),
            // M2194 chapter 707 — RUST XCFRAMEWORK iOS-
            // SLICE EXPANSION
            ("707",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百七")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百七")!
                .mNumberLast),
            // M2196 chapter 708 — ZERO-WARNING BUILD
            ("708",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百八")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百八")!
                .mNumberLast),
            // M2198 chapter 709 — DEAD-CODE CLEANUP
            ("709",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百九")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百九")!
                .mNumberLast),
            // M2200 chapter 710 — PER-FLAG-DEFAULTS REFACTOR
            ("710",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百十")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百十")!
                .mNumberLast),
            // M2202 chapter 711 — FIRST PRODUCTION WIRE-IN
            ("711",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百十一")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百十一")!
                .mNumberLast),
            // M2204 chapter 712 — FULL「全面 转向」
            ("712",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百十二")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百十二")!
                .mNumberLast),
            // M2206 chapter 713 — HOST ADOPTION CONVENIENCE
            ("713",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百十三")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百十三")!
                .mNumberLast),
            // M2208 chapter 714 — SUBSTRATE ADOPTION AUDIT
            ("714",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百十四")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百十四")!
                .mNumberLast),
            // M2210 chapter 715 — CONCURRENT STRESS
            ("715",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百十五")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百十五")!
                .mNumberLast),
            // M2212 chapter 716 — BOUNDARY + ERROR PATHS
            ("716",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百十六")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百十六")!
                .mNumberLast),
            // M2214 chapter 717 — ERROR CODABLE MATRIX
            ("717",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百十七")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百十七")!
                .mNumberLast),
            // M2216 chapter 718 — ERROR HASHABLE MATRIX
            ("718",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百十八")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百十八")!
                .mNumberLast),
            // M2218 chapter 719 — ERROR SENDABLE TRANSFER
            ("719",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百十九")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百十九")!
                .mNumberLast),
            // M2220 chapter 720 — CASE-IDENTIFIER MATRIX
            ("720",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百二十")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百二十")!
                .mNumberLast),
            // M2222 chapter 721 — WIRE-FORMAT SHA256 MATRIX
            ("721",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百二十一")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百二十一")!
                .mNumberLast),
            // M2224 chapter 722 — TYPE-CASE-IDENTIFIER UNIQUE
            ("722",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百二十二")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百二十二")!
                .mNumberLast),
            // M2226 chapter 723 — DESCRIPTION MATRIX
            ("723",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百二十三")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百二十三")!
                .mNumberLast),
            // M2228 chapter 724 — CASE COUNT INVARIANT
            ("724",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百二十四")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百二十四")!
                .mNumberLast),
            // M2230 chapter 725 — ACTOR TYPE-NAME INTRO
            ("725",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百二十五")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百二十五")!
                .mNumberLast),
            // M2232 chapter 726 — ACTOR COUNT INVARIANT
            ("726",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百二十六")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百二十六")!
                .mNumberLast),
            // M2234 chapter 727 — ACTOR SENDABLE TRANSFER
            ("727",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百二十七")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百二十七")!
                .mNumberLast),
            // M2236 chapter 728 — ACTOR MODULE-QUALIFIED
            ("728",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百二十八")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百二十八")!
                .mNumberLast),
            // M2238 chapter 729 — ACTOR DISTINCT INSTANCE
            ("729",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百二十九")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百二十九")!
                .mNumberLast),
            // M2240 chapter 730 — MAKEWITHDEFAULTS
            ("730",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百三十")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百三十")!
                .mNumberLast),
            // M2242 chapter 731 — FLAG ACTOR SURFACE
            ("731",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百三十一")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百三十一")!
                .mNumberLast),
            // M2244 chapter 732 — FACTORY FLAG-SAMPLING
            ("732",
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百三十二")!
                .mNumberFirst,
             BASChapterDoctrineRegistry.recordFor(
                chapterTag: "chapter 七百三十二")!
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
