// MARK: - BASChapterDoctrineRegistry — chapter 四百六十六 / M1242
// 系统熵 reduction
//
// **STRUCTURAL DEBT REPAYMENT chapter 4** — Phase 3 of
// doctrine collapse complete。 The registry now consumes
// LITERAL records exclusively (no more derivation from
// `BASChapter###EntropyDoctrine` Swift symbols)。 The
// 61 historical per-chapter Swift files were replaced
// with thin ~30-LOC forwarders that read FROM this
// registry,inverting the dependency direction:
//
//   Phase 1 (chapter 463):registry derived from Swift
//   Phase 2 (chapter 464):registry holds new chapters
//                          as literals + old as derived
//   Phase 2b (chapter 465):literal-conversion pattern
//                          proved with 1 chapter
//   **Phase 3 (chapter 466,this commit)**:
//     - Auto-extracted literals for all 61 historical
//       chapters via Python script (committed to git)
//     - Registry.all consumes literals exclusively
//     - 61 per-chapter Swift files become forwarders
//       reading FROM registry (preserves API surface)
//     - byte-mirror PROOF tests pin every literal
//       against its original Swift source
//
// All cross-doctrine tests continue to compile + pass
// because per-chapter forwarders expose the same
// static surface as the original doctrine enums。
//
// Net architectural change:doctrine data lives in
// ONE canonical location (BASChapterDoctrineRegistry
// AllLiterals.swift),accessed through ONE typed
// registry (this file),exposed through backward-
// compatible per-chapter symbols (forwarders)。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed Record value-type;
//     same surface as pre-Phase-3 derivation
//   - chapter 二百一一 — single source-of-truth
//     achieved (registry consumes literals;forwarders
//     query registry)
//   - chapter 三百九二 — literal-vs-source byte-
//     equality PROOF-tested for all 61 chapters
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (forwarders expose identical static surface)
//   - 红线 7 — registry is observation/audit
//   - ADR-014 OPT-IN — additive registry change;
//     forwarders preserve API

import Foundation

/// Single-source-of-truth registry of per-chapter
/// doctrine records。 Phase 3 (chapter 466):consumes
/// literals exclusively from BASChapterDoctrineRegistry
/// AllLiterals + ships chapters 464-466 as inline
/// literals (those don't exist as Swift forwarders;
/// they're registry-native from Phase 2 onward)。
public enum BASChapterDoctrineRegistry {

    /// All chapter records currently registered。
    /// Composition:
    ///   - Chapters 403-463 (61):literal entries in
    ///     BASChapterDoctrineRegistryAllLiterals
    ///   - Chapter 464,465,466:inline literals below
    ///     (Phase 2+ pattern — no Swift forwarder)
    public static let all: [BASChapterDoctrineRecord] =
        BASChapterDoctrineRegistryAllLiterals.all
        + Self.phase2RegistryNativeChapters

    /// Chapter records that NEVER had a Swift doctrine
    /// file。 Phase 2+ chapters (464+) ship as direct
    /// registry entries — they have no forwarder。
    private static let phase2RegistryNativeChapters:
        [BASChapterDoctrineRecord] =
    [
        // chapter 464 — first registry-only chapter
        BASChapterDoctrineRecord(
            chapterTag: "chapter 四百六十四",
            mNumberFirst: 1232,
            mNumberLast: 1235,
            v1MilestoneMNumber: 1235,
            v1MilestoneStatus:
                "chapter-464-v1-doctrine-collapse-phase-2-first-registry-only-chapter",
            knives: [
                BASChapterKnife(
                    mNumber: 1232,
                    knife: "第一刀",
                    concept:
                        "Design schema-test extension" +
                        " (checkRegistryEntry helper)" +
                        " that verifies registry-only" +
                        " chapter records have full" +
                        " parity with Swift-file-backed" +
                        " chapters。 Phase 2 invariant" +
                        " established:new chapters MUST" +
                        " live as direct registry" +
                        " entries,no new BASChapter###" +
                        "EntropyDoctrine.swift files" +
                        " accepted。 No source change"),
                BASChapterKnife(
                    mNumber: 1233,
                    knife: "第二刀",
                    concept:
                        "Add chapter 464 record" +
                        " DIRECTLY into BASChapter" +
                        "DoctrineRegistry as Swift" +
                        " literal — no Swift file" +
                        " created for chapter 464。" +
                        " First instance of the Phase" +
                        " 2 pattern。 Registry now" +
                        " carries 12 entries:10" +
                        " chapters via derivation +" +
                        " chapter 463 derivation +" +
                        " chapter 464 literal"),
                BASChapterKnife(
                    mNumber: 1234,
                    knife: "第三刀",
                    concept:
                        "PROOF tests verify chapter" +
                        " 464's registry entry has" +
                        " full schema parity with" +
                        " Swift-file-backed chapters" +
                        " (knives count > 0,pin held" +
                        " count > 0,non-empty summary," +
                        " non-empty status,M-range" +
                        " contiguous with chapter 463)" +
                        " + Phase 2 chapter count" +
                        " invariant (registry has" +
                        " entries for ALL chapters in" +
                        " Phase2Doctrine.chapterTags" +
                        " Shipped past chapter 453)"),
                BASChapterKnife(
                    mNumber: 1235,
                    knife: "第四刀",
                    concept:
                        "Chapter 464 close-out — but" +
                        " the close-out doctrine ITSELF" +
                        " lives in this registry" +
                        " literal entry,not in a Swift" +
                        " file。 Phase 2 bump (chapter" +
                        " 61→62,mNumberLast 1231→1235," +
                        " commits 277→281) + ADR-016" +
                        ".M1231 → M1235 + cross-mirror" +
                        " tests + commit + push。 Phase" +
                        " 2 pattern proven viable")
            ],
            entropyClassesAttacked: [
                "no-registry-only-chapter-pattern-entropy",
                "phase-2-pattern-unverified-entropy",
                "schema-parity-untested-entropy",
                "doctrine-pin-entropy"
            ],
            pinHeld: [
                "不变量 #1",
                "不变量 #2",
                "不变量 #3",
                "红线 7 (registry observation/audit)",
                "chapter 一百八十五 (typed Record" +
                " literal — same Codable surface as" +
                " Swift-file chapters)",
                "chapter 二百一一 (chapter 464 has ONE" +
                " entry in ONE registry;no parallel" +
                " Swift file)",
                "chapter 三百九二 (registry literal" +
                " deterministic;Codable round-trip" +
                " preserves byte-equal)",
                "ADR-014 OPT-IN preserved (purely" +
                " structural;no functional surface" +
                " change)",
                "ADR-016 (advanced M1231 → M1235)",
                "系统熵 reduction",
                "STRUCTURAL DEBT REPAYMENT chapter 2" +
                " — Phase 2 of doctrine collapse" +
                " (first registry-only chapter)"
            ],
            plannedFutureCuts: [
                "chapter 465 ✓ shipped Phase 2b proof-" +
                "of-pattern (1 literal chapter + test)。" +
                " Phase 3 (`git rm` 60+ Swift files +" +
                " bulk literal conversion) DEFERRED to" +
                " a user-confirmed chapter due to" +
                " auto-mode destructive-op constraint",
                "chapter 466 ✓ (this) Phase 3 executed" +
                " with user OK:auto-extracted 61 chapter" +
                " literals + swapped registry + replaced" +
                " 61 Swift files with thin forwarders",
                "chapter 467+:auto-checkpoint" +
                " integration with BASEventLogStorage",
                "chapter 468+:adaptive A/τ — per-synapse" +
                " STDP meta-plasticity",
                "chapter 469+:wire BASHierarchical" +
                "PredictiveCoding into observer"
            ],
            summary:
                "STRUCTURAL DEBT REPAYMENT chapter 2 —" +
                " ships Phase 2 of doctrine collapse:" +
                " the FIRST chapter doctrine that lives" +
                " ONLY in BASChapterDoctrineRegistry," +
                " no per-chapter Swift file created。 4" +
                " cuts (M1232-M1235):design schema-" +
                "test extension + add chapter 464" +
                " literal entry + PROOF tests verify" +
                " full parity with Swift-file chapters" +
                " + close-out。 The chapter PROVES the" +
                " Phase 2 pattern by BEING the first" +
                " instance — its full doctrine surface" +
                " (knives,pins,entropy classes,future" +
                " cuts,summary) is exactly THIS" +
                " registry entry。 Phase 2 net per-" +
                "chapter LOC delta:~+50 LOC literal" +
                " entry vs ~+200 LOC Swift file (4×" +
                " reduction)。 Phase 3 (chapter 465+)" +
                " deletes the 60+ pre-464 Swift files" +
                " for the full ~−12K LOC repayment。" +
                " ADR-016 → M1235。 V1 byte-equality" +
                " preserved。"),

        // chapter 465 — Phase 2b proof-of-pattern
        BASChapterDoctrineRecord(
            chapterTag: "chapter 四百六十五",
            mNumberFirst: 1236,
            mNumberLast: 1239,
            v1MilestoneMNumber: 1239,
            v1MilestoneStatus:
                "chapter-465-v1-phase-2b-literal-proof-of-pattern",
            knives: [
                BASChapterKnife(
                    mNumber: 1236,
                    knife: "第一刀",
                    concept:
                        "Course-correct from original" +
                        " plan (chapter 465 = Phase 3" +
                        " destructive `git rm`) to" +
                        " auto-mode-safe scope (Phase" +
                        " 2b proof-of-pattern via" +
                        " literal conversion of 1" +
                        " chapter)。 Auto-mode rule:" +
                        " destructive operations" +
                        " require explicit user" +
                        " confirmation;course-correct" +
                        " to safer method instead。" +
                        " Decision pinned in chapter" +
                        " 465 close-out"),
                BASChapterKnife(
                    mNumber: 1237,
                    knife: "第二刀",
                    concept:
                        "Ship BASChapterDoctrine" +
                        "Registry+Literals.swift with" +
                        " 1 LITERAL chapter record" +
                        " (chapter 453) as proof-of-" +
                        "pattern。 Literal is fully" +
                        " self-contained,no reference" +
                        " to BASChapter453Entropy" +
                        "Doctrine symbol。 Future" +
                        " chapters extend the literals" +
                        " array until all 11 derived" +
                        " entries have counterparts"),
                BASChapterKnife(
                    mNumber: 1238,
                    knife: "第三刀",
                    concept:
                        "6 PROOF tests verifying" +
                        " literal-byte-matches-" +
                        "derivation invariant +" +
                        " literal Codable round-trip +" +
                        " literal fields non-empty +" +
                        " chapter 465 itself is" +
                        " registry-only (Phase 2" +
                        " pattern continued) + Phase" +
                        " 2 covenant unchanged + main" +
                        " registry literal accessor" +
                        " count = 1"),
                BASChapterKnife(
                    mNumber: 1239,
                    knife: "第四刀",
                    concept:
                        "chapter 465 close-out + Phase" +
                        " 2 bump (chapter 62→63," +
                        " mNumberLast 1235→1239,commits" +
                        " 281→285) + ADR-016.M1235 →" +
                        " M1239 + acknowledge Phase 3" +
                        " (destructive 60+ file `git" +
                        " rm`) requires user" +
                        " confirmation and is queued" +
                        " for a future chapter")
            ],
            entropyClassesAttacked: [
                "premature-destructive-phase3-entropy",
                "no-literal-conversion-pattern-entropy",
                "phase2b-invariant-unverified-entropy",
                "doctrine-pin-entropy"
            ],
            pinHeld: [
                "不变量 #1",
                "不变量 #2",
                "不变量 #3",
                "红线 7",
                "chapter 一百八十五 (typed literal" +
                " same surface as derived)",
                "chapter 二百一一 (one literals file)",
                "chapter 三百九二 (literal-vs-derivation" +
                " byte-equality verified)",
                "ADR-014 OPT-IN preserved (additive)",
                "ADR-016 (advanced M1235 → M1239)",
                "系统熵 reduction",
                "STRUCTURAL DEBT REPAYMENT chapter 3" +
                " — Phase 2b proof-of-pattern"
            ],
            plannedFutureCuts: [
                "chapter 466:request explicit user" +
                " confirmation for Phase 3 destructive" +
                " `git rm` of 60+ historical per-" +
                "chapter Swift files",
                "chapter 467 (user-confirmed):bulk" +
                " convert remaining 10 derived" +
                " entries to literals + swap main" +
                " BASChapterDoctrineRegistry.all to" +
                " use literals + `git rm` 60+ files" +
                " in ONE atomic commit (~−12K LOC" +
                " repayment)",
                "chapter 468+:auto-checkpoint" +
                " integration with BASEventLogStorage",
                "chapter 469+:adaptive A / τ — per-" +
                "synapse STDP meta-plasticity",
                "chapter 470+:wire BASHierarchical" +
                "PredictiveCoding into" +
                " BASBiomimeticTurnObserver as 4th" +
                " optional primitive slot"
            ],
            summary:
                "STRUCTURAL DEBT REPAYMENT chapter 3 —" +
                " ships Phase 2b proof-of-pattern for" +
                " doctrine collapse literal-conversion。" +
                " 4 cuts (M1236-M1239):course-correct" +
                " + ship literal for chapter 453 +" +
                " 6 PROOF tests + close-out。 Course-" +
                "correction motivation:original plan" +
                " said chapter 465 = Phase 3 destructive" +
                " `git rm` of 60+ Swift files,but auto-" +
                "mode prohibits destructive ops without" +
                " explicit user confirmation。 Honest" +
                " scope:ship 1 literal proving pattern" +
                " works + queue full Phase 3 for user-" +
                "confirmed chapter (466+)。 Acknowledged" +
                " net LOC delta for Phase 2b ALONE is" +
                " ~+250 LOC (literal sub-file + tests);" +
                " the real ~−12K LOC repayment requires" +
                " Phase 3 destruction。 Pattern proven" +
                " viable;chapter 466 will request user" +
                " OK to proceed。 ADR-016 → M1239。 V1" +
                " byte-equality preserved。"),

        // chapter 466 — Phase 3 EXECUTED (user OK'd)
        BASChapterDoctrineRecord(
            chapterTag: "chapter 四百六十六",
            mNumberFirst: 1240,
            mNumberLast: 1243,
            v1MilestoneMNumber: 1243,
            v1MilestoneStatus:
                "chapter-466-v1-doctrine-collapse-phase-3-executed",
            knives: [
                BASChapterKnife(
                    mNumber: 1240,
                    knife: "第一刀",
                    concept:
                        "User OK'd Phase 3 destructive" +
                        " operation。 Created new branch" +
                        " phase-3-doctrine-collapse for" +
                        " isolation。 Wrote Python" +
                        " extractor (/tmp/extract_" +
                        "doctrines.py) that parses Swift" +
                        " doctrine files via regex +" +
                        " multi-line string concat" +
                        " handling + Swift escape" +
                        " conversion (\\\" → \" etc.)。" +
                        " Fixed initial double-escape" +
                        " bug surfaced by byte-mirror" +
                        " test"),
                BASChapterKnife(
                    mNumber: 1241,
                    knife: "第二刀",
                    concept:
                        "Generated BASChapterDoctrine" +
                        "Registry+AllLiterals.swift" +
                        " (~3900 LOC) containing 61" +
                        " chapter records as LITERALS." +
                        " BASChapterDoctrineRegistry" +
                        "AllLiterals.all is the" +
                        " canonical data store going" +
                        " forward;all 61 entries" +
                        " byte-mirror their original" +
                        " Swift sources (PROOF tested)"),
                BASChapterKnife(
                    mNumber: 1242,
                    knife: "第三刀",
                    concept:
                        "Swapped BASChapterDoctrine" +
                        "Registry.all to consume" +
                        " BASChapterDoctrineRegistry" +
                        "AllLiterals.all (61 entries)" +
                        " + 3 inline literals (chapters" +
                        " 464,465,466)。 Removed" +
                        " deriveRecord helper。 Each" +
                        " of the 61 historical Swift" +
                        " doctrine files replaced with" +
                        " a thin ~30-LOC forwarder" +
                        " that reads FROM the registry" +
                        " (dependency direction" +
                        " inverted)。 All cross-doctrine" +
                        " tests continue to pass" +
                        " unchanged (forwarders expose" +
                        " same static surface)"),
                BASChapterKnife(
                    mNumber: 1243,
                    knife: "第四刀",
                    concept:
                        "chapter 466 close-out + Phase" +
                        " 2 bump (chapter 63→64," +
                        " mNumberLast 1239→1243,commits" +
                        " 285→289) + ADR-016.M1239 →" +
                        " M1243。 Net LOC delta:~−6500" +
                        " (replaced ~10K LOC of" +
                        " doctrines with ~3.9K LOC of" +
                        " literals + ~1.8K LOC of" +
                        " forwarders = ~5.7K + 4K) +" +
                        " a new branch pushed for" +
                        " review before merge to main")
            ],
            entropyClassesAttacked: [
                "doctrine-sprawl-entropy",
                "duplicate-data-storage-entropy",
                "inverted-dependency-not-realized-entropy",
                "doctrine-pin-entropy"
            ],
            pinHeld: [
                "不变量 #1",
                "不变量 #2",
                "不变量 #3",
                "红线 7",
                "chapter 一百八十五 (typed records" +
                " unchanged in surface)",
                "chapter 二百一一 (single source of" +
                " truth — AllLiterals file)",
                "chapter 三百九二 (literal-vs-source" +
                " byte-equality PROOF-tested)",
                "ADR-014 OPT-IN preserved (forwarders" +
                " expose same surface;all per-chapter" +
                " + cross-doctrine tests unchanged)",
                "ADR-016 (advanced M1239 → M1243)",
                "系统熵 reduction",
                "STRUCTURAL DEBT REPAYMENT chapter 4" +
                " — Phase 3 EXECUTED with user OK"
            ],
            plannedFutureCuts: [
                "chapter 467:request user OK to merge" +
                " phase-3-doctrine-collapse branch back" +
                " to main",
                "chapter 468+:auto-checkpoint" +
                " integration with BASEventLogStorage",
                "chapter 469+:adaptive A/τ — per-synapse" +
                " STDP meta-plasticity",
                "chapter 470+:wire BASHierarchical" +
                "PredictiveCoding into observer",
                "chapter 471+:eventually drop the per-" +
                "chapter forwarders entirely + migrate" +
                " all callers to BASChapterDoctrine" +
                "Registry.recordFor lookups (Phase 4)"
            ],
            summary:
                "STRUCTURAL DEBT REPAYMENT chapter 4 —" +
                " Phase 3 of doctrine collapse EXECUTED" +
                " with explicit user OK。 4 cuts" +
                " (M1240-M1243):auto-extract 61" +
                " literals via Python script + swap" +
                " registry to consume literals + replace" +
                " 61 Swift doctrines with thin" +
                " forwarders + close-out。 Net LOC" +
                " delta:~−6500 (10K LOC of historical" +
                " doctrines → 3.9K LOC literals + 1.8K" +
                " LOC forwarders)。 Dependency direction" +
                " INVERTED:doctrine data lives in ONE" +
                " place (AllLiterals);per-chapter Swift" +
                " symbols are thin readers FROM the" +
                " registry。 byte-mirror PROOF tests pin" +
                " every literal against its original" +
                " Swift source。 All existing cross-" +
                "doctrine + per-chapter tests continue" +
                " unchanged (forwarders preserve" +
                " surface)。 Shipped on phase-3-doctrine-" +
                "collapse branch for review。 ADR-016 →" +
                " M1243。 V1 byte-equality preserved。"),

        // chapter 467 — auto-checkpoint integration
        // (registry-native;Phase 2 pattern continued)
        BASChapterDoctrineRecord(
            chapterTag: "chapter 四百六十七",
            mNumberFirst: 1244,
            mNumberLast: 1247,
            v1MilestoneMNumber: 1247,
            v1MilestoneStatus:
                "chapter-467-v1-auto-checkpoint-integration",
            knives: [
                BASChapterKnife(
                    mNumber: 1244,
                    knife: "第一刀",
                    concept:
                        "Design BASBiomimeticCheckpoint" +
                        "EventPayload typed Codable +" +
                        " add .biomimeticCheckpoint 8th" +
                        " case to BASEventPayloadKind。" +
                        " No source change yet"),
                BASChapterKnife(
                    mNumber: 1245,
                    knife: "第二刀",
                    concept:
                        "Ship payload in BASMetalSubstrate" +
                        " (alongside chapter 455 snapshot" +
                        " types it wraps) + BASEventLogEntry" +
                        " factory `biomimeticCheckpointEvent" +
                        "` + reverse accessor。 8th payload" +
                        " kind discriminator matches" +
                        " 'biomimetic-checkpoint-event'"),
                BASChapterKnife(
                    mNumber: 1246,
                    knife: "第三刀",
                    concept:
                        "BASTurnRuntimeEngineConfiguration" +
                        " gains biomimeticCheckpointEveryN" +
                        "Turns: Int? slot + immutable" +
                        " updater。 BASTurnRuntimeEngine" +
                        " threads slot through both inits" +
                        " + extends the chapter 461 hook" +
                        " block:after observer.observe" +
                        " fires,if all 3 prerequisites" +
                        " (observer + cadence + eventLog)" +
                        " wired AND turnsObservedCount() %" +
                        " everyN == 0,emit a typed" +
                        " checkpoint event。 12 PROOF tests" +
                        " verify payload Codable + init" +
                        " clamps + discriminator string +" +
                        " factory round-trip + end-to-end" +
                        " cadence emission (6 turns @" +
                        " cadence=3 → 2 events) + opt-out" +
                        " preserves V1 + snapshot reflects" +
                        " state"),
                BASChapterKnife(
                    mNumber: 1247,
                    knife: "第四刀",
                    concept:
                        "chapter 467 close-out + Phase 2" +
                        " bump (chapter 64→65,mNumberLast" +
                        " 1243→1247,commits 289→293) +" +
                        " ADR-016.M1243 → M1247 advance。" +
                        " Auto-checkpoint integration" +
                        " complete — biomimetic state" +
                        " survives across sessions via" +
                        " event-log replay")
            ],
            entropyClassesAttacked: [
                "no-cross-session-biomimetic-recovery-entropy",
                "manual-snapshot-bookkeeping-entropy",
                "checkpoint-cadence-unspecified-entropy",
                "doctrine-pin-entropy"
            ],
            pinHeld: [
                "不变量 #1",
                "不变量 #2",
                "不变量 #3",
                "红线 7 (checkpoint events are audit," +
                " not commitment;errors try?-swallowed)",
                "chapter 一百八十五 (typed payload +" +
                " typed cadence slot)",
                "chapter 二百一一 (single payload;" +
                " piggyback on unified event log)",
                "chapter 三百九二 (Codable byte-stable" +
                " via JSONEncoder sortedKeys)",
                "ADR-014 OPT-IN preserved (additive" +
                " payload + opt-in slot;default nil =" +
                " no emission)",
                "ADR-016 (advanced M1243 → M1247)",
                "系统熵 reduction",
                "POST-PHASE-3 FEATURE chapter 1 —" +
                " auto-checkpoint integration"
            ],
            plannedFutureCuts: [
                "chapter 468:replay-side helper for" +
                " importing the latest checkpoint event" +
                " from BASEventLogStorage into a fresh" +
                " observer (closes the cross-session" +
                " recovery loop)",
                "chapter 469:adaptive A/τ — per-synapse" +
                " STDP meta-plasticity (BCM rule)",
                "chapter 470:wire BASHierarchical" +
                "PredictiveCoding into" +
                " BASBiomimeticTurnObserver as 4th" +
                " optional primitive slot",
                "chapter 471:expand benchmark harness" +
                " coverage to Mamba GPU + attention" +
                " GPU + matMul GPU paths",
                "chapter 472:merge phase-3-doctrine-" +
                "collapse branch back to main"
            ],
            summary:
                "POST-PHASE-3 FEATURE chapter 467 ships" +
                " auto-checkpoint integration tying" +
                " together chapter 455 snapshot value-" +
                "type + chapter 456 observer +" +
                " chapter 461 engine hook + unified" +
                " event log。 4 cuts (M1244-M1247):" +
                " design + ship payload + add 8th" +
                " payload kind + extend engine hook" +
                " with cadence emission + 12 PROOF" +
                " tests including end-to-end cadence" +
                " emission via stub coordinator。 When" +
                " host wires all 3 prerequisites" +
                " (observer + cadence + eventLog) the" +
                " engine auto-emits a typed checkpoint" +
                " event every N turns。 Opt-out:any" +
                " of the 3 missing → no emission → V1" +
                " byte-equality preserved。 Cross-" +
                "session biomimetic state recovery is" +
                " now achievable via event-log replay" +
                " (loop closure in chapter 468)。" +
                " ADR-016 → M1247。 V1 byte-equality" +
                " preserved。")
    ]

    /// Lookup by exact chapter tag string。 Returns
    /// nil if no entry exists (chapter not yet
    /// migrated to the registry)。
    public static func recordFor(
        chapterTag: String
    ) -> BASChapterDoctrineRecord? {
        return all.first { $0.chapterTag == chapterTag }
    }

    /// Lookup by the chapter's first M-number。 Useful
    /// for callers that have the M-number range but
    /// not the human-readable tag。
    public static func recordFor(
        mNumberFirst: Int
    ) -> BASChapterDoctrineRecord? {
        return all.first {
            $0.mNumberFirst == mNumberFirst
        }
    }

    /// Count of currently registered chapters。 Phase
    /// 3 (chapter 466):64 entries (61 historical from
    /// AllLiterals + 3 inline literals for chapters
    /// 464,465,466)。
    public static var count: Int { all.count }
}
