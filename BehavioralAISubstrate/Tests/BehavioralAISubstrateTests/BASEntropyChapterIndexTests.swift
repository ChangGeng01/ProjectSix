// MARK: - BASEntropyChapterIndexTests — chapter 四百三十 / M1092

import XCTest
@testable import BASRuntimeCore

final class BASEntropyChapterIndexTests: XCTestCase {

    // MARK: - RADICAL EVOLUTION entry count
    // (uses named expected constant per chapter 一百八十五
    // anti-magic-number doctrine; cross-mirrors against
    // BASPostRadicalSweepDoctrine as second source-of-
    // truth)

    func testRadicalEvolutionEntryCountMatchesExpected() {
        XCTAssertEqual(
            BASEntropyChapterIndex
                .radicalEvolutionEntryCount,
            BASSweepDoctrineExpectations
                .sweepChapterCount,
            "radicalEvolutionEntryCount must match" +
            " named expected — drift means index" +
            " doctrine fell out of sync with the SWEEP" +
            " narrative")
        // Cross-mirror:second source-of-truth is the
        // SWEEP doctrine's own chapter count
        XCTAssertEqual(
            BASEntropyChapterIndex
                .radicalEvolutionEntryCount,
            BASPostRadicalSweepDoctrine.chapterCount,
            "radicalEvolutionEntryCount must equal" +
            " BASPostRadicalSweepDoctrine.chapterCount" +
            " — independent typed surfaces must agree")
    }

    // MARK: - Entry shape

    func testEntryDirectInit() {
        let entry = BASEntropyChapterEntry(
            chapterTag: "test",
            mNumberFirst: 100,
            mNumberLast: 103,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 5,
            futureCutsCount: 2,
            summary: "test summary")
        XCTAssertEqual(entry.chapterTag, "test")
        XCTAssertEqual(entry.mNumberFirst, 100)
        XCTAssertEqual(entry.mNumberLast, 103)
        XCTAssertEqual(entry.knivesCount, 4)
        XCTAssertEqual(entry.mNumberSpan, 4)
    }

    func testMNumberSpanInclusive() {
        let entry = BASEntropyChapterEntry(
            chapterTag: "x",
            mNumberFirst: 1080,
            mNumberLast: 1083,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 0,
            futureCutsCount: 0,
            summary: "")
        XCTAssertEqual(entry.mNumberSpan, 4,
            "span is inclusive on both endpoints" +
            " (M1080+M1081+M1082+M1083 = 4)")
    }

    // MARK: - Index lookups

    func testEntryForTagFound() {
        let entry = BASEntropyChapterIndex.entry(
            forTag: "chapter 四百三十二")
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.mNumberFirst, 1100)
        XCTAssertEqual(entry?.mNumberLast, 1103)
    }

    func testEntryForTagNilWhenMissing() {
        let entry = BASEntropyChapterIndex.entry(
            forTag: "chapter does-not-exist")
        XCTAssertNil(entry)
    }

    func testEntryForMNumberFound() {
        let entry = BASEntropyChapterIndex.entry(
            forMNumber: 1097)
        XCTAssertNotNil(entry)
        XCTAssertEqual(
            entry?.chapterTag,
            "chapter 四百三十一",
            "M1097 lives in chapter 四百三十一's M1096-M1099 range")
    }

    func testEntryForMNumberNilWhenOutsideSweep() {
        // Pre-RADICAL Phase 2 chapters (e.g. M1077 from
        // chapter 426) are NOT indexed — the sweep index
        // covers M1080-M1107 only。
        let entry = BASEntropyChapterIndex.entry(
            forMNumber: 1077)
        XCTAssertNil(entry,
            "M1077 is outside the RADICAL EVOLUTION" +
            " SWEEP M-range (sweep starts at M1080)")
    }

    func testEntryForMNumberInPhaseDRange() {
        // M1108 extension:M1093 now resolves to
        // chapter 四百三十 (Phase D) instead of nil
        let entry = BASEntropyChapterIndex.entry(
            forMNumber: 1093)
        XCTAssertEqual(
            entry?.chapterTag,
            "chapter 四百三十",
            "M1093 lives in chapter 四百三十's M1092-M1095" +
            " range (added by M1108 deep-review extension)")
    }

    func testEntryForMNumberInChapter433Range() {
        // M1108 extension:chapter 433 entries now
        // resolve to the typed entry。
        // M1109 self-extension bumped the upper bound
        // from 1107 → 1109 to cover M1108-M1109.
        let entry = BASEntropyChapterIndex.entry(
            forMNumber: 1108)
        XCTAssertEqual(
            entry?.chapterTag,
            "chapter 四百三十三",
            "M1108 lives in chapter 四百三十三's M1104-M1109" +
            " range (M1109 self-extension covers M1108)")
        let entry2 = BASEntropyChapterIndex.entry(
            forMNumber: 1109)
        XCTAssertEqual(
            entry2?.chapterTag,
            "chapter 四百三十三",
            "M1109 also resolves to chapter 四百三十三")
    }

    // MARK: - Aggregates (named expected + cross-mirror)

    func testTotalKnivesCountMatchesExpected() {
        XCTAssertEqual(
            BASEntropyChapterIndex.totalKnivesCount,
            BASSweepDoctrineExpectations
                .sweepCommitsShipped,
            "totalKnivesCount must equal named expected" +
            " constant — derivation in" +
            " BASSweepDoctrineExpectations doc-comment")
        // Cross-mirror with SWEEP doctrine
        XCTAssertEqual(
            BASEntropyChapterIndex.totalKnivesCount,
            BASPostRadicalSweepDoctrine.commitsShipped,
            "totalKnivesCount must equal" +
            " BASPostRadicalSweepDoctrine.commitsShipped" +
            " — independent typed surfaces must agree")
    }

    func testEarliestMNumberMatchesExpected() {
        XCTAssertEqual(
            BASEntropyChapterIndex.earliestMNumber,
            BASSweepDoctrineExpectations
                .sweepMNumberFirst,
            "earliestMNumber must equal sweep" +
            " mNumberFirst (named constant)")
    }

    func testLatestMNumberMatchesExpected() {
        XCTAssertEqual(
            BASEntropyChapterIndex.latestMNumber,
            BASSweepDoctrineExpectations
                .sweepMNumberLast,
            "M\(BASSweepDoctrineExpectations.sweepMNumberLast)" +
            " POST-RADICAL Wave 17 latestMNumber pin" +
            " (chapter" +
            " 446 covers M1160-M1163)。 Sweep complete")
    }

    // MARK: - Mirroring chapter doctrines

    func testIndexMirrorsChapter427() {
        let entry = BASEntropyChapterIndex.entry(
            forTag: BASChapter427EntropyDoctrine
                .chapterTag)
        XCTAssertEqual(
            entry?.mNumberFirst,
            BASChapter427EntropyDoctrine.mNumberFirst)
        XCTAssertEqual(
            entry?.mNumberLast,
            BASChapter427EntropyDoctrine.mNumberLast)
    }

    func testIndexMirrorsChapter432() {
        let entry = BASEntropyChapterIndex.entry(
            forTag: BASChapter432EntropyDoctrine
                .chapterTag)
        XCTAssertEqual(
            entry?.mNumberFirst,
            BASChapter432EntropyDoctrine.mNumberFirst)
        XCTAssertEqual(
            entry?.mNumberLast,
            BASChapter432EntropyDoctrine.mNumberLast)
    }

    // MARK: - M1108 deep-review extension cross-mirror

    func testIndexMirrorsChapter430() {
        let entry = BASEntropyChapterIndex.entry(
            forTag: BASChapter430EntropyDoctrine
                .chapterTag)
        XCTAssertEqual(
            entry?.mNumberFirst,
            BASChapter430EntropyDoctrine.mNumberFirst)
        XCTAssertEqual(
            entry?.mNumberLast,
            BASChapter430EntropyDoctrine.mNumberLast)
    }

    func testIndexMirrorsChapter433() {
        let entry = BASEntropyChapterIndex.entry(
            forTag: BASChapter433EntropyDoctrine
                .chapterTag)
        XCTAssertEqual(
            entry?.mNumberFirst,
            BASChapter433EntropyDoctrine.mNumberFirst)
        XCTAssertEqual(
            entry?.mNumberLast,
            BASChapter433EntropyDoctrine.mNumberLast)
    }

    // MARK: - M1111 Wave 2 STAGE 1 — phase2Entries (31 entries)

    func testPhase2EntryCountMatchesExpected() {
        XCTAssertEqual(
            BASEntropyChapterIndex.phase2EntryCount,
            BASSweepDoctrineExpectations
                .phase2ChapterCount,
            "phase2EntryCount must match named expected" +
            " constant — see BASSweepDoctrineExpectations" +
            ".phase2ChapterCount doc-comment。 Originally" +
            " a magic 44;refactored per chapter 一百八十五" +
            "。 Detail:complete Phase 2 mirror covers" +
            " (24 pre-RADICAL + 20 sweep) chapters。" +
            " Original message context:M1163 POST-" +
            "RADICAL Wave 17 complete Phase" +
            " 2 mirror covers all 44 chapters (24 pre-" +
            "RADICAL + 7 RADICAL + 434/435/436/437/438/" +
            "439/440/441/442/443/444/445/446)。 Sweep" +
            " complete")
        XCTAssertEqual(
            BASEntropyChapterIndex
                .phase2Entries.count,
            BASPhase2EntropyClosureDoctrine
                .chapterTagsShipped.count,
            "phase2Entries count must equal Phase 2" +
            " doctrine's chapterTagsShipped count")
    }

    func testPhase2EntriesChronological() {
        let entries = BASEntropyChapterIndex
            .phase2Entries
        for i in 1..<entries.count {
            XCTAssertGreaterThanOrEqual(
                entries[i].mNumberFirst,
                entries[i-1].mNumberFirst,
                "phase2Entries must be in chronological" +
                " M-number order")
        }
    }

    func testPhase2EntryForChapter403() {
        let entry = BASEntropyChapterIndex.phase2Entry(
            forTag: "chapter 四百三")
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.mNumberFirst, 953)
        XCTAssertEqual(entry?.mNumberLast, 962)
    }

    func testPhase2EntryForChapter426() {
        let entry = BASEntropyChapterIndex.phase2Entry(
            forTag: "chapter 四百二十六")
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.mNumberFirst, 1074)
        XCTAssertEqual(entry?.mNumberLast, 1077)
    }

    func testPhase2EntryForChapter433() {
        let entry = BASEntropyChapterIndex.phase2Entry(
            forTag: "chapter 四百三十三")
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.mNumberFirst, 1104)
        XCTAssertEqual(entry?.mNumberLast, 1109)
    }

    func testPhase2EntryForMNumberInPreRadicalRange() {
        // M955 lives in chapter 四百三 (M953-M962)
        let entry = BASEntropyChapterIndex.phase2Entry(
            forMNumber: 955)
        XCTAssertEqual(
            entry?.chapterTag, "chapter 四百三")
    }

    func testPhase2EntryForMNumberInRadicalRange() {
        // M1102 lives in chapter 四百三十二 (M1100-M1103)
        let entry = BASEntropyChapterIndex.phase2Entry(
            forMNumber: 1102)
        XCTAssertEqual(
            entry?.chapterTag, "chapter 四百三十二")
    }

    func testPhase2EntryForMNumberOutsidePhase2() {
        // M940 is pre-Phase 2 (Phase 1 chapter 四百二
        // territory)
        let entry = BASEntropyChapterIndex.phase2Entry(
            forMNumber: 940)
        XCTAssertNil(entry,
            "M940 is outside Phase 2 (M953+)")
    }

    func testEveryPhase2DoctrineChapterHasIndexEntry() {
        // Cross-mirror check: every chapter tag in the
        // Phase 2 closure doctrine must have a
        // corresponding entry in the index。
        for tag in BASPhase2EntropyClosureDoctrine
            .chapterTagsShipped
        {
            let entry = BASEntropyChapterIndex
                .phase2Entry(forTag: tag)
            XCTAssertNotNil(entry,
                "Phase 2 chapter \(tag) must have index" +
                " entry — required for future doctrine" +
                " cleanup deletion")
        }
    }

    func testIndexMirrorsAllPreRadicalDoctrineMRanges() {
        // Spot-check 4 pre-RADICAL chapters whose
        // doctrine .swift files I cross-checked at M1111
        XCTAssertEqual(
            BASEntropyChapterIndex.phase2Entry(
                forTag: BASChapter403EntropyDoctrine
                    .chapterTag)?.mNumberFirst,
            BASChapter403EntropyDoctrine.mNumberFirst)
        XCTAssertEqual(
            BASEntropyChapterIndex.phase2Entry(
                forTag: BASChapter410EntropyDoctrine
                    .chapterTag)?.mNumberLast,
            BASChapter410EntropyDoctrine.mNumberLast)
        XCTAssertEqual(
            BASEntropyChapterIndex.phase2Entry(
                forTag: BASChapter421EntropyDoctrine
                    .chapterTag)?.mNumberLast,
            BASChapter421EntropyDoctrine.mNumberLast)
        XCTAssertEqual(
            BASEntropyChapterIndex.phase2Entry(
                forTag: BASChapter426EntropyDoctrine
                    .chapterTag)?.mNumberLast,
            BASChapter426EntropyDoctrine.mNumberLast)
    }

    // MARK: - Determinism

    func testPhase2EntriesAreDeterministic() {
        let a = BASEntropyChapterIndex.phase2Entries
        let b = BASEntropyChapterIndex.phase2Entries
        XCTAssertEqual(a, b)
    }

    // MARK: - Codable round-trip

    func testEntryCodableRoundTrip() throws {
        let original = BASEntropyChapterIndex
            .radicalEvolutionEntries.first!
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder()
            .decode(
                BASEntropyChapterEntry.self,
                from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Determinism

    func testIndexIsDeterministic() {
        let a = BASEntropyChapterIndex
            .radicalEvolutionEntries
        let b = BASEntropyChapterIndex
            .radicalEvolutionEntries
        XCTAssertEqual(a, b)
    }
}
