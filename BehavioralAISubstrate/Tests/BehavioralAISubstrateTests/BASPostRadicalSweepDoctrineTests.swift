// MARK: - BASPostRadicalSweepDoctrineTests
// chapter 四百四十六 / M1162 — POST-RADICAL Wave 17

import XCTest
@testable import BASRuntimeCore

/// Pin tests for the M1161 close-out meta-doctrine。
/// Validates that the typed sweep-narrative anchor is
/// fully populated with the cumulative achievement
/// (chapters 427-446 / Waves 1-17 / M1080-M1163 / 84
/// commits)。 Future commits that bump the sweep range
/// without bumping these pins fail at PR-time。
final class BASPostRadicalSweepDoctrineTests:
    XCTestCase
{

    // MARK: - Identity

    func testSweepTagPinned() {
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine.sweepTag,
            "post-radical-evolution-sweep")
    }

    func testTriggerDirectivePinnedVerbatim() {
        // The 2026-05-10 directive must remain
        // verbatim — chapter 八十七 raw-value stability。
        XCTAssertTrue(
            BASPostRadicalSweepDoctrine
                .triggerDirective
                .contains("进化升华"))
        XCTAssertTrue(
            BASPostRadicalSweepDoctrine
                .triggerDirective
                .contains("低熵复杂系统"))
        XCTAssertTrue(
            BASPostRadicalSweepDoctrine
                .triggerDirective
                .contains("原生利用神经引擎"))
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine.triggerDate,
            "2026-05-10")
    }

    // MARK: - Range

    func testChapterRangePinned() {
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine
                .firstChapterTag,
            "chapter 四百二十七")
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine
                .lastChapterTag,
            "chapter 四百四十六")
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine
                .chapterTagsShipped.first,
            BASPostRadicalSweepDoctrine
                .firstChapterTag,
            "chapterTagsShipped.first must equal" +
            " firstChapterTag")
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine
                .chapterTagsShipped.last,
            BASPostRadicalSweepDoctrine
                .lastChapterTag,
            "chapterTagsShipped.last must equal" +
            " lastChapterTag")
    }

    func testMNumberRangePinned() {
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine.mNumberFirst,
            1080,
            "RADICAL EVOLUTION SWEEP Phase A starts at" +
            " M1080")
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine.mNumberLast,
            1163,
            "Wave 17 close-out chapter 446 ends at" +
            " M1163")
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine.mNumberSpan,
            84, "M1080-M1163 inclusive = 84 M-numbers")
    }

    func testWaveRangePinned() {
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine
                .firstWaveNumber, 1)
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine
                .lastWaveNumber, 17)
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine.waveCount, 17)
    }

    // MARK: - Counts

    func testChapterCountPinned() {
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine.chapterCount,
            20,
            "chapters 427-446 inclusive = 20 chapters")
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine
                .chapterTagsShipped.count, 20,
            "chapterTagsShipped count matches" +
            " chapterCount accessor")
    }

    func testCommitsShippedPinned() {
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine.commitsShipped,
            84,
            "RADICAL Phases A-F (24 commits at M1080-" +
            "M1107) + RADICAL final cuts (M1108-M1115) +" +
            " POST-RADICAL Waves 5-16 (M1110-M1159) +" +
            " chapter 446 close-out (4 cuts) ≈ 84")
    }

    // MARK: - whatsShipped + whatsDeferred + pins

    func testWhatsShippedPopulated() {
        // Exact-count assertion (chapter 二百一一
        // single-source-of-truth):if any future commit
        // adds a 9th achievement,this test fails until
        // the count is explicitly bumped — preventing
        // silent doctrine drift。
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine
                .whatsShipped.count, 8,
            "Sweep must list EXACTLY 8 substrate-side" +
            " achievements;adding a 9th requires" +
            " explicit count bump to prevent silent" +
            " doctrine drift")
        // Spot-check key narrative anchors
        let joined = BASPostRadicalSweepDoctrine
            .whatsShipped.joined(separator: " | ")
        XCTAssertTrue(
            joined.contains("autonomy"),
            "whatsShipped must mention substrate-side" +
            " autonomy")
        XCTAssertTrue(
            joined.contains("Replay surface"),
            "whatsShipped must mention replay surface")
        XCTAssertTrue(
            joined.contains("Apple Silicon"),
            "whatsShipped must mention native Apple" +
            " Silicon foundation")
    }

    func testWhatsDeferredPopulated() {
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine
                .whatsDeferred.count, 5,
            "Sweep must explicitly defer EXACTLY 5" +
            " items with reasons;adding a 6th deferral" +
            " requires explicit count bump")
        // Each entry must have non-empty reason
        for (item, reason) in
            BASPostRadicalSweepDoctrine.whatsDeferred
        {
            XCTAssertFalse(item.isEmpty)
            XCTAssertFalse(reason.isEmpty,
                "deferred item '\(item)' must have a" +
                " reason — silent omissions forbidden")
        }
    }

    func testPinsHeldThroughoutPopulated() {
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine
                .pinsHeldThroughout.count, 10,
            "Sweep must list EXACTLY 10 doctrine pins" +
            " held at every commit boundary;adding an" +
            " 11th requires explicit count bump")
        let joined = BASPostRadicalSweepDoctrine
            .pinsHeldThroughout.joined(
                separator: " | ")
        XCTAssertTrue(
            joined.contains("不变量 #1"),
            "V1 byte-equality invariant must be in" +
            " pins-held list")
        XCTAssertTrue(
            joined.contains("ADR-014"),
            "ADR-014 OPT-IN must be in pins-held list")
        XCTAssertTrue(
            joined.contains("ADR-016"),
            "ADR-016 substrate completion must be in" +
            " pins-held list")
    }

    // MARK: - Cross-mirror invariants (chapter 446 polish)

    /// Exact chapter count — RADICAL chapters 427-433
    /// (7 chapters) + POST-RADICAL chapters 434-446
    /// (13 chapters) = 20 chapters total。
    func testChapterCountIsExactly20() {
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine.chapterCount,
            20,
            "Sweep covers chapters 427-446 inclusive =" +
            " 20 chapters。 Drift fails this test")
    }

    /// SWEEP commitsShipped MUST equal the radical-
    /// evolution slice's totalKnivesCount in
    /// BASEntropyChapterIndex (both derive from the
    /// same per-chapter knives ledgers)。 If the SWEEP
    /// claim drifts from the index reality,this test
    /// fails at PR-time。
    func testCommitsShippedMatchesIndexTotalKnives() {
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine.commitsShipped,
            BASEntropyChapterIndex.totalKnivesCount,
            "BASPostRadicalSweepDoctrine.commitsShipped" +
            " (\(BASPostRadicalSweepDoctrine.commitsShipped))" +
            " must equal BASEntropyChapterIndex" +
            ".totalKnivesCount" +
            " (\(BASEntropyChapterIndex.totalKnivesCount))" +
            " — both derived from per-chapter knives" +
            " ledgers across radicalEvolutionEntries")
    }

    /// SWEEP commitsShipped at M1163 = 84。
    func testCommitsShippedIsExactly84() {
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine.commitsShipped,
            84,
            "Sweep ships 84 commits at M1163 close-out:" +
            " RADICAL Phases A-F (24) + chapter 433" +
            " final close-out (6) + chapter 434 (6) +" +
            " chapters 435-446 (12 × 4 = 48) = 84")
    }

    /// SWEEP chapterTagsShipped MUST be a contiguous
    /// suffix of BASPhase2EntropyClosureDoctrine
    /// .chapterTagsShipped。 If a future Phase 2
    /// chapter is appended without bumping the SWEEP
    /// doctrine,this test fails — the SWEEP claim is
    /// stale。
    func testChapterTagsShippedMirrorsPhase2DoctrineTail() {
        let phase2 = BASPhase2EntropyClosureDoctrine
            .chapterTagsShipped
        let sweep = BASPostRadicalSweepDoctrine
            .chapterTagsShipped
        XCTAssertGreaterThanOrEqual(
            phase2.count, sweep.count,
            "Phase 2 must contain at least the sweep" +
            " chapters")
        let suffix = Array(
            phase2.suffix(sweep.count))
        XCTAssertEqual(suffix, sweep,
            "BASPostRadicalSweepDoctrine.chapterTagsShipped" +
            " must be a CONTIGUOUS SUFFIX of" +
            " BASPhase2EntropyClosureDoctrine" +
            ".chapterTagsShipped — drift means SWEEP" +
            " doctrine wasn't bumped after Phase 2 added" +
            " a new chapter")
    }

    /// SWEEP firstChapterTag must equal the actual
    /// chapter 427 doctrine — if either drifts
    /// independently,this test fails。
    func testFirstChapterTagMatchesBASChapter427() {
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine
                .firstChapterTag,
            BASChapter427EntropyDoctrine.chapterTag,
            "Sweep firstChapterTag must equal" +
            " BASChapter427EntropyDoctrine.chapterTag")
    }

    /// SWEEP lastChapterTag must equal chapter 446
    /// (the close-out chapter itself)。
    func testLastChapterTagMatchesBASChapter446() {
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine
                .lastChapterTag,
            BASChapter446EntropyDoctrine.chapterTag,
            "Sweep lastChapterTag must equal" +
            " BASChapter446EntropyDoctrine.chapterTag")
    }

    /// SWEEP mNumberFirst must equal chapter 427's
    /// mNumberFirst;mNumberLast must equal chapter
    /// 446's mNumberLast。 Cross-mirror with the actual
    /// chapter doctrines pins the M-range against
    /// independent drift。
    func testMNumberRangeMatchesChapterDoctrines() {
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine.mNumberFirst,
            BASChapter427EntropyDoctrine.mNumberFirst,
            "Sweep mNumberFirst must equal chapter 427's")
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine.mNumberLast,
            BASChapter446EntropyDoctrine.mNumberLast,
            "Sweep mNumberLast must equal chapter 446's")
    }

    /// Wave ↔ chapter accounting:17 waves spread
    /// across 20 chapters。 The 3-chapter gap accounts
    /// for:
    ///   - Wave 3 spans chapters 429 + 430 (-1 chapter)
    ///   - Wave 4 spans chapters 431 + 432 (-1 chapter)
    ///   - chapter 433 is RADICAL final close-out,
    ///     unassigned to any wave (-1 chapter)
    /// → 20 - 17 = 3 chapters absorbed by wave
    ///   distribution。 If this invariant breaks,the
    ///   sweep narrative drifted。
    func testWaveChapterAccountingInvariant() {
        let chapterMinusWaveDelta =
            BASPostRadicalSweepDoctrine.chapterCount -
            BASPostRadicalSweepDoctrine.waveCount
        XCTAssertEqual(
            chapterMinusWaveDelta, 3,
            "Sweep chapter count - wave count must" +
            " equal 3 (Wave 3 spans 2 chapters + Wave 4" +
            " spans 2 chapters + chapter 433 is" +
            " unassigned RADICAL close-out)")
    }

    /// Every chapter listed in
    /// chapterTagsShipped MUST have a corresponding
    /// entry in BASEntropyChapterIndex
    /// .radicalEvolutionEntries with matching
    /// chapterTag。 Cross-mirror catches drift in
    /// EITHER direction。
    func testEverySweepChapterMirroredInIndex() {
        let indexTags = Set(BASEntropyChapterIndex
            .radicalEvolutionEntries
            .map { $0.chapterTag })
        for tag in BASPostRadicalSweepDoctrine
            .chapterTagsShipped
        {
            XCTAssertTrue(
                indexTags.contains(tag),
                "Sweep chapter \(tag) MUST have an" +
                " entry in BASEntropyChapterIndex" +
                ".radicalEvolutionEntries — drift means" +
                " sweep doctrine references a chapter" +
                " the index doesn't know about")
        }
        // Reverse direction: every index radical entry
        // must also be in the sweep
        let sweepTags = Set(
            BASPostRadicalSweepDoctrine
                .chapterTagsShipped)
        for tag in indexTags {
            XCTAssertTrue(
                sweepTags.contains(tag),
                "Index chapter \(tag) MUST be listed" +
                " in BASPostRadicalSweepDoctrine" +
                ".chapterTagsShipped — drift means" +
                " sweep doctrine forgot a chapter the" +
                " index added")
        }
    }

    /// Every deferred item must mention the reason
    /// keyword "blocked" / "deferred" / "required" /
    /// "needs" / "requires" / "gated" — caller-readable
    /// signal that we know WHY it's deferred,not just
    /// that it is。
    func testEveryDeferredItemReasonHasRationaleKeyword() {
        let rationaleKeywords = [
            "blocked", "deferred", "required",
            "needs", "requires", "gated", "scale"
        ]
        for (item, reason) in
            BASPostRadicalSweepDoctrine.whatsDeferred
        {
            let reasonLower = reason.lowercased()
            let hasRationale = rationaleKeywords.contains {
                reasonLower.contains($0)
            }
            XCTAssertTrue(hasRationale,
                "Deferred item '\(item)' reason must" +
                " contain at least one rationale" +
                " keyword (blocked/deferred/required/" +
                "needs/requires/gated/scale);got:" +
                " '\(reason)'")
        }
    }

    /// Determinism:doctrine answers must be
    /// idempotent — same query → same answer。 Pins
    /// the static-let nature against accidental
    /// computed-property regressions。
    func testDoctrineIsDeterministic() {
        let a = BASPostRadicalSweepDoctrine
            .chapterTagsShipped
        let b = BASPostRadicalSweepDoctrine
            .chapterTagsShipped
        XCTAssertEqual(a, b)
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine.commitsShipped,
            BASPostRadicalSweepDoctrine.commitsShipped)
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine.summary,
            BASPostRadicalSweepDoctrine.summary)
    }

    // MARK: - Polish pass 2 cross-mirror invariants

    /// Phase 2 doctrine's mNumberLast MUST equal the
    /// sweep doctrine's mNumberLast — both track the
    /// latest chapter shipped。 If a future Phase 2
    /// chapter ships without bumping the SWEEP doctrine
    /// (or vice versa),this test fails — the chain
    /// has drifted。
    func testPhase2DoctrineMNumberLastMatchesSweepMNumberLast() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .mNumberLast,
            BASPostRadicalSweepDoctrine.mNumberLast,
            "BASPhase2EntropyClosureDoctrine.mNumberLast" +
            " (\(BASPhase2EntropyClosureDoctrine.mNumberLast))" +
            " must equal BASPostRadicalSweepDoctrine" +
            ".mNumberLast" +
            " (\(BASPostRadicalSweepDoctrine.mNumberLast))" +
            " — both track the latest chapter shipped")
    }

    /// Per-entry M-range cross-mirror:every sweep
    /// chapter's M-range MUST match the corresponding
    /// `BASEntropyChapterIndex.radicalEvolutionEntries`
    /// entry's M-range。 This catches drift where the
    /// SWEEP doctrine and the index disagree on a
    /// chapter's actual cuts even when both have the
    /// chapter listed。 Stronger than
    /// `testEverySweepChapterMirroredInIndex` which
    /// only checks tag membership。
    func testSweepChapterMRangesMatchIndexEntries() {
        for tag in BASPostRadicalSweepDoctrine
            .chapterTagsShipped
        {
            guard let entry = BASEntropyChapterIndex
                .entry(forTag: tag)
            else {
                XCTFail(
                    "Sweep chapter \(tag) missing from" +
                    " radicalEvolutionEntries — covered" +
                    " by testEverySweepChapterMirroredInIndex" +
                    " but failing here too means the" +
                    " whole cross-mirror chain broke")
                continue
            }
            // Per-entry M-range sanity:every entry must
            // have mNumberLast >= mNumberFirst (no
            // negative spans)。
            XCTAssertGreaterThanOrEqual(
                entry.mNumberLast,
                entry.mNumberFirst,
                "Index entry for \(tag) has inverted" +
                " M-range:\(entry.mNumberFirst) →" +
                " \(entry.mNumberLast)")
            // First chapter must start at sweep's
            // mNumberFirst;last must end at sweep's
            // mNumberLast — already checked by
            // testMNumberRangeMatchesChapterDoctrines
            // but reaffirmed here against the index
            // (different surface)
            if tag == BASPostRadicalSweepDoctrine
                .firstChapterTag
            {
                XCTAssertEqual(
                    entry.mNumberFirst,
                    BASPostRadicalSweepDoctrine
                        .mNumberFirst,
                    "Sweep first-chapter M-range start" +
                    " must equal sweep mNumberFirst" +
                    " (cross-mirror via index)")
            }
            if tag == BASPostRadicalSweepDoctrine
                .lastChapterTag
            {
                XCTAssertEqual(
                    entry.mNumberLast,
                    BASPostRadicalSweepDoctrine
                        .mNumberLast,
                    "Sweep last-chapter M-range end" +
                    " must equal sweep mNumberLast" +
                    " (cross-mirror via index)")
            }
        }
    }

    /// Summary string MUST embed the trigger directive
    /// verbatim — keeps the narrative anchor inside the
    /// summary itself so a single doctrine read carries
    /// the WHY for the WHAT。 If `summary` drifts away
    /// from `triggerDirective`,this test fails and
    /// reminds the editor to keep them aligned。
    func testSummaryEmbedsTriggerDirective() {
        XCTAssertTrue(
            BASPostRadicalSweepDoctrine.summary
                .contains(
                    BASPostRadicalSweepDoctrine
                        .triggerDirective),
            "BASPostRadicalSweepDoctrine.summary must" +
            " embed triggerDirective verbatim — keeps" +
            " the WHY anchored inside the WHAT。 Got:" +
            " summary='\(BASPostRadicalSweepDoctrine.summary)'")
    }

    // MARK: - Polish pass 4 cross-mirror invariants
    // (cross-mirror against pre-existing RADICAL-only
    // closure doctrine BASRadicalEvolutionSweepClosureDoctrine)

    /// Both the pre-existing RADICAL-only closure
    /// doctrine and the new POST-RADICAL umbrella
    /// doctrine reference the SAME 2026-05-10 trigger
    /// directive (the Chinese 「目前整体底层架构需要全面
    /// 进化升华...」 anchor)。 If either drifts the
    /// other's narrative breaks — pin both directions。
    func testTriggerDirectiveMatchesPreexistingRadicalDoctrine() {
        XCTAssertEqual(
            BASRadicalEvolutionSweepClosureDoctrine
                .sweepDirective,
            BASPostRadicalSweepDoctrine
                .triggerDirective,
            "BASRadicalEvolutionSweepClosureDoctrine" +
            ".sweepDirective MUST equal" +
            " BASPostRadicalSweepDoctrine" +
            ".triggerDirective verbatim — both" +
            " reference the same 2026-05-10 directive。" +
            " Drift means one doctrine's verbatim copy" +
            " went stale")
    }

    /// RADICAL-only doctrine's sweepEntryMNumber MUST
    /// equal POST-RADICAL sweep's mNumberFirst — both
    /// pin the same M1080 entry (chapter 427 Phase A
    /// start)。
    func testRadicalSweepEntryMatchesPostRadicalFirstM() {
        XCTAssertEqual(
            BASRadicalEvolutionSweepClosureDoctrine
                .sweepEntryMNumber,
            BASPostRadicalSweepDoctrine.mNumberFirst,
            "RADICAL doctrine sweepEntryMNumber" +
            " (\(BASRadicalEvolutionSweepClosureDoctrine.sweepEntryMNumber))" +
            " MUST equal POST-RADICAL sweep mNumberFirst" +
            " (\(BASPostRadicalSweepDoctrine.mNumberFirst))" +
            " — both anchor chapter 427's M1080 entry")
    }

    /// RADICAL-only doctrine's sweepCloseOutMNumber
    /// (M1109,chapter 433 final close-out + 2 deep-
    /// review remediations) MUST be a member of the
    /// POST-RADICAL sweep's M-range [mNumberFirst,
    /// mNumberLast]。 If the POST-RADICAL sweep ever
    /// shrinks below M1109 (or RADICAL grows past
    /// POST-RADICAL),this test fails — the chain
    /// broke。
    func testRadicalCloseOutCoveredByPostRadicalRange() {
        XCTAssertGreaterThanOrEqual(
            BASRadicalEvolutionSweepClosureDoctrine
                .sweepCloseOutMNumber,
            BASPostRadicalSweepDoctrine.mNumberFirst,
            "RADICAL close-out M-number must be >= " +
            " POST-RADICAL first M")
        XCTAssertLessThanOrEqual(
            BASRadicalEvolutionSweepClosureDoctrine
                .sweepCloseOutMNumber,
            BASPostRadicalSweepDoctrine.mNumberLast,
            "RADICAL close-out M-number must be <= " +
            " POST-RADICAL last M — RADICAL sweep is" +
            " a strict prefix of POST-RADICAL sweep")
    }

    // MARK: - Polish pass 5 — citation example pin

    /// Pin the `citationExampleSummary` template
    /// against silent drift。 The string is the
    /// in-codebase demonstration of the citation
    /// pattern chapter 447+ doctrines should copy。
    /// Embeds 5 typed accessors (sweepTag /
    /// lastChapterTag / mNumberLast / commitsShipped /
    /// pinsHeldThroughout.count) so if ANY of those
    /// drifts the example stays in sync (because the
    /// string is interpolated at static init time
    /// using the doctrine's own constants)。
    ///
    /// This test catches the case where a future edit
    /// deletes one of the cited accessors or renames it
    /// — the example becomes stale and the citation
    /// pattern's promised IN-CODEBASE DEMONSTRATION
    /// breaks silently。 By pinning specific substrings
    /// the test forces explicit acknowledgment of
    /// drift。
    func testCitationExampleFieldsExist() {
        let example = BASPostRadicalSweepDoctrine
            .citationExampleSummary
        // Each cited field's expected substring must be
        // present in the interpolated example。
        XCTAssertTrue(
            example.contains(
                "sweep=" +
                BASPostRadicalSweepDoctrine.sweepTag),
            "citationExampleSummary must cite sweepTag" +
            " verbatim;got: \(example)")
        XCTAssertTrue(
            example.contains(
                "lastChapter=" +
                BASPostRadicalSweepDoctrine
                    .lastChapterTag),
            "citationExampleSummary must cite" +
            " lastChapterTag verbatim;got: \(example)")
        XCTAssertTrue(
            example.contains(
                "lastM=M" +
                String(BASPostRadicalSweepDoctrine
                    .mNumberLast)),
            "citationExampleSummary must cite" +
            " mNumberLast verbatim;got: \(example)")
        XCTAssertTrue(
            example.contains(
                "commits=" +
                String(BASPostRadicalSweepDoctrine
                    .commitsShipped)),
            "citationExampleSummary must cite" +
            " commitsShipped verbatim;got: \(example)")
        XCTAssertTrue(
            example.contains(
                "pinsHeld=" +
                String(BASPostRadicalSweepDoctrine
                    .pinsHeldThroughout.count)),
            "citationExampleSummary must cite" +
            " pinsHeldThroughout.count verbatim;got:" +
            " \(example)")
    }

    /// citationExampleSummary must be non-empty +
    /// non-degenerate (not just punctuation)。 Cheap
    /// sanity check independent of the field-by-field
    /// test。
    func testCitationExampleIsNonDegenerate() {
        let example = BASPostRadicalSweepDoctrine
            .citationExampleSummary
        XCTAssertFalse(example.isEmpty,
            "citationExampleSummary must be non-empty")
        XCTAssertGreaterThan(
            example.count, 50,
            "citationExampleSummary should be a" +
            " substantial template (> 50 chars);got" +
            " length=\(example.count)")
    }
}
