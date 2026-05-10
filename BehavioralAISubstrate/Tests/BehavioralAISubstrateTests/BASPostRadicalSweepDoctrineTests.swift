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
            BASSweepDoctrineExpectations
                .sweepMNumberFirst,
            "RADICAL EVOLUTION SWEEP Phase A starts at" +
            " M\(BASSweepDoctrineExpectations.sweepMNumberFirst)")
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine.mNumberLast,
            BASSweepDoctrineExpectations
                .sweepMNumberLast,
            "Wave 17 close-out chapter 446 ends at" +
            " M\(BASSweepDoctrineExpectations.sweepMNumberLast)")
        // Span is fully derivable from first+last —
        // assert against the derivation, not against
        // a literal duplicate
        let expectedSpan =
            BASSweepDoctrineExpectations
                .sweepMNumberLast
            - BASSweepDoctrineExpectations
                .sweepMNumberFirst
            + 1
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine.mNumberSpan,
            expectedSpan,
            "mNumberSpan must equal" +
            " (mNumberLast - mNumberFirst + 1) —" +
            " derivation,not a magic constant")
    }

    func testWaveRangePinned() {
        // First wave is 1 (numbering starts there per
        // chapter 三百九二 replay-determinism)。 The "1"
        // here is the FIRST-INDEX convention,not a
        // drift-pin;left as literal。
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine
                .firstWaveNumber, 1)
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine
                .lastWaveNumber,
            BASSweepDoctrineExpectations
                .sweepWaveCount)
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine.waveCount,
            BASSweepDoctrineExpectations
                .sweepWaveCount)
    }

    // MARK: - Counts (anti-magic-number: named via
    //         BASSweepDoctrineExpectations namespace)

    func testChapterCountPinned() {
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine.chapterCount,
            BASSweepDoctrineExpectations
                .sweepChapterCount,
            "chapter count must match named expected" +
            " constant (chapters 427-446 inclusive)")
        // Cross-mirror via index (preferred over
        // any literal pin):both sources MUST agree
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine
                .chapterTagsShipped.count,
            BASEntropyChapterIndex
                .radicalEvolutionEntries.count,
            "chapterTagsShipped count must equal" +
            " BASEntropyChapterIndex.radicalEvolutionEntries" +
            ".count — both source-of-truth surfaces" +
            " for the same fact")
    }

    func testCommitsShippedPinned() {
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine.commitsShipped,
            BASSweepDoctrineExpectations
                .sweepCommitsShipped,
            "commits must match named expected constant" +
            " (sum of per-chapter knives — see" +
            " BASSweepDoctrineExpectations doc-comment" +
            " for derivation)")
    }

    // MARK: - whatsShipped + whatsDeferred + pins

    func testWhatsShippedPopulated() {
        // Exact-count assertion (chapter 二百一一
        // single-source-of-truth):if any future commit
        // adds a 9th achievement,this test fails until
        // the named constant is explicitly bumped —
        // preventing silent doctrine drift。
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine
                .whatsShipped.count,
            BASSweepDoctrineExpectations
                .whatsShippedCount,
            "whatsShipped count must match named" +
            " expected;adding an item requires" +
            " explicit constant bump to prevent silent" +
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
                .whatsDeferred.count,
            BASSweepDoctrineExpectations
                .whatsDeferredCount,
            "whatsDeferred count must match named" +
            " expected;adding a deferral requires" +
            " explicit constant bump")
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
                .pinsHeldThroughout.count,
            BASSweepDoctrineExpectations
                .pinsHeldThroughoutCount,
            "pinsHeldThroughout count must match named" +
            " expected;adding a pin requires explicit" +
            " constant bump")
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

    /// Chapter count cross-mirror via index — preferred
    /// over a literal pin because the index is an
    /// independent typed surface that must agree with
    /// the SWEEP doctrine。 Drift in EITHER source
    /// fails this test。 (Replaces previous magic-number
    /// `count, 20` per chapter 一百八十五 anti-magic-
    /// number doctrine。)
    func testChapterCountMatchesIndex() {
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine.chapterCount,
            BASEntropyChapterIndex
                .radicalEvolutionEntries.count,
            "Sweep chapterCount must equal" +
            " BASEntropyChapterIndex.radicalEvolutionEntries" +
            ".count — independent typed surfaces must" +
            " agree")
        // Named-constant pin as second source-of-truth
        // for the same fact (catches the case where
        // BOTH surfaces drift in lockstep,which the
        // cross-mirror above can't detect)。
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine.chapterCount,
            BASSweepDoctrineExpectations
                .sweepChapterCount,
            "Sweep chapterCount must match named" +
            " expected constant")
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

    /// SWEEP commitsShipped matches named expected。
    /// (Replaces previous magic-number `count, 84` per
    /// chapter 一百八十五 anti-magic-number doctrine —
    /// see BASSweepDoctrineExpectations doc-comment for
    /// the 84 derivation。)
    func testCommitsShippedMatchesExpected() {
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine.commitsShipped,
            BASSweepDoctrineExpectations
                .sweepCommitsShipped,
            "commitsShipped must match named expected" +
            " constant — derivation in" +
            " BASSweepDoctrineExpectations doc-comment")
    }

    /// SWEEP chapterTagsShipped MUST appear as a
    /// CONTIGUOUS SLICE inside
    /// BASPhase2EntropyClosureDoctrine.chapterTagsShipped。
    /// Originally was a suffix invariant;reframed to
    /// contiguous-slice at chapter 447 ship — SWEEP
    /// stayed frozen at chapter 446 but Phase 2
    /// extended to chapter 447+,so SWEEP is now a
    /// middle slice (not a suffix)。
    func testChapterTagsShippedAppearsContiguouslyInPhase2() {
        let phase2 = BASPhase2EntropyClosureDoctrine
            .chapterTagsShipped
        let sweep = BASPostRadicalSweepDoctrine
            .chapterTagsShipped
        XCTAssertGreaterThanOrEqual(
            phase2.count, sweep.count,
            "Phase 2 must contain at least the sweep" +
            " chapters")
        guard let firstSweepIdx = phase2.firstIndex(
            of: sweep[0])
        else {
            XCTFail(
                "sweep firstChapterTag (\(sweep[0]))" +
                " not found in Phase 2 — drift means" +
                " Phase 2 lost a sweep chapter")
            return
        }
        let endIdx = firstSweepIdx + sweep.count
        guard endIdx <= phase2.count else {
            XCTFail(
                "sweep slice would overflow Phase 2" +
                " end")
            return
        }
        let sweepSliceInPhase2 = Array(
            phase2[firstSweepIdx..<endIdx])
        XCTAssertEqual(sweepSliceInPhase2, sweep,
            "BASPostRadicalSweepDoctrine.chapterTagsShipped" +
            " must appear as a CONTIGUOUS SLICE inside" +
            " BASPhase2EntropyClosureDoctrine" +
            ".chapterTagsShipped (not necessarily as a" +
            " suffix — chapter 447+ extends Phase 2" +
            " past SWEEP boundary)")
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

    /// Wave ↔ chapter accounting invariant — uses
    /// named expected (see
    /// BASSweepDoctrineExpectations.sweepChapterMinusWaveDelta
    /// doc-comment for the 3-slot derivation:Wave 3 +
    /// Wave 4 each span 2 chapters + chapter 433 is
    /// unassigned)。 Replaces previous magic-number `3`
    /// per chapter 一百八十五 anti-magic-number doctrine。
    func testWaveChapterAccountingInvariant() {
        let chapterMinusWaveDelta =
            BASPostRadicalSweepDoctrine.chapterCount -
            BASPostRadicalSweepDoctrine.waveCount
        XCTAssertEqual(
            chapterMinusWaveDelta,
            BASSweepDoctrineExpectations
                .sweepChapterMinusWaveDelta,
            "chapter-wave delta must match named" +
            " expected;derivation in" +
            " BASSweepDoctrineExpectations doc-comment")
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

    /// Phase 2 doctrine's mNumberLast MUST be >= the
    /// SWEEP doctrine's mNumberLast — Phase 2 is an
    /// ongoing umbrella;SWEEP was a 17-wave snapshot
    /// that closed at chapter 446。 chapter 447 onward
    /// extends Phase 2 but NOT SWEEP (SWEEP intentionally
    /// stays frozen as historical anchor)。 Loosened
    /// from `==` to `>=` at chapter 447 ship。
    func testPhase2MNumberLastIsAtLeastSweepMNumberLast() {
        XCTAssertGreaterThanOrEqual(
            BASPhase2EntropyClosureDoctrine
                .mNumberLast,
            BASPostRadicalSweepDoctrine.mNumberLast,
            "BASPhase2EntropyClosureDoctrine.mNumberLast" +
            " (\(BASPhase2EntropyClosureDoctrine.mNumberLast))" +
            " must be >= BASPostRadicalSweepDoctrine" +
            ".mNumberLast" +
            " (\(BASPostRadicalSweepDoctrine.mNumberLast))" +
            " — SWEEP is a frozen prefix of Phase 2's" +
            " ongoing range")
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
        // Substantial-template floor:the example must
        // be longer than any single one of its 5 cited
        // field values。 Derivation:if even the
        // longest cited field (lastChapterTag,e.g.
        // "chapter 四百四十六") would fit alone in the
        // example,it would mean the template structure
        // wasn't being applied。 The floor is the sum
        // of cited values' lengths,not a magic 50。
        let citedFieldsTotalLength =
            BASPostRadicalSweepDoctrine.sweepTag.count
            + BASPostRadicalSweepDoctrine
                .lastChapterTag.count
            + String(BASPostRadicalSweepDoctrine
                .mNumberLast).count
            + String(BASPostRadicalSweepDoctrine
                .commitsShipped).count
            + String(BASPostRadicalSweepDoctrine
                .pinsHeldThroughout.count).count
        XCTAssertGreaterThanOrEqual(
            example.count,
            citedFieldsTotalLength,
            "citationExampleSummary must be at least" +
            " as long as the sum of its 5 cited field" +
            " values (derivation, not a magic floor)")
    }

    // MARK: - Deep-review fix 3: narrative content pins
    // (audit-driven:count assertions don't catch item-
    // for-item replacement;pin SPECIFIC anchor content
    // for every item in whatsShipped + whatsDeferred)

    /// Each substrate-side achievement in `whatsShipped`
    /// MUST contain its specific anchor phrase。 Count-
    /// only assertion (already tested) would silently
    /// pass if someone replaced item N with completely
    /// different content。 This test catches semantic
    /// drift。 (Renamed from `…All8SpecificAnchors`
    /// per chapter 一百八十五 anti-magic-number — the
    /// count is implicit in requiredAnchors.count + the
    /// cross-mirror assertion below。)
    func testWhatsShippedContainsAllSpecificAnchors() {
        let joined = BASPostRadicalSweepDoctrine
            .whatsShipped.joined(separator: " ||| ")
        // Specific anchors,one per achievement item。
        // Array size IS the source-of-truth count;
        // cross-mirror against doctrine.count below。
        let requiredAnchors: [String] = [
            "autonomy COMPLETE",            // item 1
            "Replay surface COMPLETE",      // item 2
            "Apple Silicon foundation",     // item 3
            "Hardware-aware scheduler",     // item 4
            "End-to-end routed dispatch",   // item 5
            "V2 FOUNDATION milestones",     // item 6
            "Phase 2 entropy chapter",      // item 7
            "ADR-016 substrate completion"  // item 8
        ]
        for anchor in requiredAnchors {
            XCTAssertTrue(
                joined.contains(anchor),
                "whatsShipped MUST contain anchor" +
                " '\(anchor)' — semantic drift detected")
        }
        // Verify count still matches the anchor count
        // (catches the case where someone adds a 9th
        // achievement without bumping the test)
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine
                .whatsShipped.count,
            requiredAnchors.count,
            "anchor list count must match whatsShipped" +
            " count;drift means either anchor list" +
            " or whatsShipped fell out of sync")
    }

    /// Each deferred item in `whatsDeferred` MUST
    /// contain its specific anchor phrase。 Catches
    /// item-for-item replacement that count-only
    /// assertions miss。 (Renamed from
    /// `…All5SpecificAnchors` per chapter 一百八十五
    /// anti-magic-number。)
    func testWhatsDeferredContainsAllSpecificAnchors() {
        let joinedItems = BASPostRadicalSweepDoctrine
            .whatsDeferred
            .map { $0.item }
            .joined(separator: " ||| ")
        let requiredAnchors: [String] = [
            "V1 runTurn 2,540 LOC monolith",
            "V2 default mode flip",
            "Drop 4 dead-weight modules",
            "Delete 24 pre-RADICAL chapter doctrine",
            "host-side reference RoutedStage"
        ]
        for anchor in requiredAnchors {
            XCTAssertTrue(
                joinedItems.contains(anchor),
                "whatsDeferred MUST contain item" +
                " anchor '\(anchor)' — semantic drift" +
                " detected")
        }
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine
                .whatsDeferred.count,
            requiredAnchors.count,
            "anchor list count must match whatsDeferred" +
            " count")
    }
}
