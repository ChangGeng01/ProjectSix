// MARK: - BASEntropyChapterIndex — chapter 四百三十 / M1092
// 系统熵 reduction
//
// RADICAL EVOLUTION SWEEP Phase D entry。 Single typed
// data table that mirrors what each `BASChapter*Entropy
// Doctrine` enum surfaces today as a public namespace。
// Sets up the future cleanup path:once consumers
// migrate to read from this table,the 25+ per-chapter
// `.swift` files can collapse without changing call
// sites。
//
// ## Why this exists (system entropy framing)
//
// The substrate ships 29 `BASChapter*EntropyDoctrine.
// swift` files (one per shipped chapter)。 Each follows
// nearly the same shape:
//
//   - chapterTag: String
//   - mNumberFirst / mNumberLast: Int
//   - knives: [(mNumber, knife, concept)]
//   - entropyClassesAttacked: [String]
//   - pinHeld: [String]
//   - plannedFutureCuts: [String]
//   - summary: String
//
// 31 files × ~120 LOC each = ~3,700 LOC of doctrine
// scaffolding (count current as of M1109)。 The original
// Phase D plan called for collapsing all of them into a
// single data table file (~120 LOC),with the 24 non-
// RADICAL chapter doctrines (chapters 403-426) being
// deletion targets and the 7 RADICAL chapters (427-433)
// surviving as `BASEntropyChapterIndex` entries。
// (Original plan said "22 doctrines" but the count
// drifted as Phase 2 grew through chapters 427-433 —
// M1109 deep-review correction。)
//
// In autonomous mode that deletion is too risky:
//
//   1. Each per-chapter doctrine has its own per-chapter
//      tests (BASChapter*EntropyDoctrineTests) that
//      reference the namespace directly
//   2. BASDoctrineChainConsistencyTests +
//      BASChapterDoctrineSchemaCompletenessTests cross-
//      reference per-chapter doctrines by symbol
//   3. Future commits that bump the doctrine version
//      pin reference per-chapter doctrines via
//      `BASChapter4XX EntropyDoctrine.mNumberLast`
//
// `BASEntropyChapterIndex` ships the typed data table
// that mirrors the per-chapter doctrines。 Once
// consumers migrate to read from the table (future
// chapter), the per-chapter `.swift` files become
// removable。
//
// ## What this ships (M1092)
//
//   - `BASEntropyChapterEntry` Sendable + Codable +
//     Equatable struct (chapterTag + mNumberFirst +
//     mNumberLast + knivesCount + entropyClassesCount
//     + pinsCount + futureCutsCount + summary)
//   - `BASEntropyChapterIndex` namespace with
//     `entries: [BASEntropyChapterEntry]` static
//     constant covering all 29 shipped chapters
//   - Cross-check helpers (`entry(forTag:)`,
//     `entry(forMNumber:)`,`coversMNumberRange()`)
//
// The table is HAND-MAINTAINED at M1092 — same
// chapterTag + mNumberFirst/Last as the per-chapter
// doctrines。 Future work could derive it via macro
// or build script。
//
// ## What this DOES NOT ship (deferred)
//
// The per-chapter `BASChapter*EntropyDoctrine.swift`
// files are NOT deleted at M1092。 The plan's planned
// −1,280 LOC delete (22 doctrine files + 22 test
// files) is deferred to a follow-up chapter under
// explicit user control。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (typed
//     entry struct + named accessors)
//   - chapter 二百一一 — single source-of-truth (one
//     table mirrors all 29 chapter doctrines)
//   - chapter 三百九二 — replay-determinism (entries
//     list is a static constant — same across processes)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (purely additive table;no per-chapter doctrine
//     deleted)
//   - 红线 7 — hint-only
//   - ADR-014 OPT-IN — purely additive
//   - RADICAL EVOLUTION SWEEP Phase D — this chapter

import Foundation

// MARK: - Entry struct

/// Typed Sendable + Codable mirror of a single chapter
/// doctrine。 One per shipped chapter doctrine。
public struct BASEntropyChapterEntry:
    Equatable, Hashable, Codable, Sendable
{

    public let chapterTag: String
    public let mNumberFirst: Int
    public let mNumberLast: Int
    public let knivesCount: Int
    public let entropyClassesCount: Int
    public let pinsCount: Int
    public let futureCutsCount: Int
    public let summary: String

    public init(
        chapterTag: String,
        mNumberFirst: Int,
        mNumberLast: Int,
        knivesCount: Int,
        entropyClassesCount: Int,
        pinsCount: Int,
        futureCutsCount: Int,
        summary: String
    ) {
        self.chapterTag = chapterTag
        self.mNumberFirst = mNumberFirst
        self.mNumberLast = mNumberLast
        self.knivesCount = knivesCount
        self.entropyClassesCount = entropyClassesCount
        self.pinsCount = pinsCount
        self.futureCutsCount = futureCutsCount
        self.summary = summary
    }

    /// Number of M-numbers covered by this chapter
    /// (inclusive)。 Pre-computed for tests + observability。
    public var mNumberSpan: Int {
        return (mNumberLast - mNumberFirst) + 1
    }
}

// MARK: - Index

/// Single-source-of-truth typed data table mirroring
/// all shipped per-chapter doctrines。 Hand-maintained
/// at M1092;future work could derive via macro。
public enum BASEntropyChapterIndex {

    /// Entries covering the 7 RADICAL EVOLUTION SWEEP
    /// chapters (M1092 shipped 5 entries;M1108 deep-
    /// review extension added chapters 四百三十 + 四百三十三
    /// for completeness)。
    /// (The 24 pre-RADICAL Phase 2 chapters live in
    /// per-chapter doctrines from chapters 四百三 through
    /// 四百二十六;this index focuses on the RADICAL
    /// EVOLUTION SWEEP arc which is the deletion-target
    /// scope for the future cleanup chapter。)
    public static let radicalEvolutionEntries:
        [BASEntropyChapterEntry] =
    [
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百二十七",
            mNumberFirst: 1080,
            mNumberLast: 1083,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 13,
            futureCutsCount: 6,
            summary:
                "RADICAL EVOLUTION SWEEP Phase A entry " +
                "— V2 RUNTIME COMPOSITION SURFACE"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百二十八",
            mNumberFirst: 1084,
            mNumberLast: 1087,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 7,
            summary:
                "RADICAL EVOLUTION SWEEP Phase B " +
                "backfill — UNIFIED EVENT LOG PAYLOAD-" +
                "KINDS BACKBONE"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百二十九",
            mNumberFirst: 1088,
            mNumberLast: 1091,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 3,
            summary:
                "RADICAL EVOLUTION SWEEP Phase C " +
                "backfill — LOW-ENTROPY GENERIC " +
                "PRIMITIVES"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百三十",
            mNumberFirst: 1092,
            mNumberLast: 1095,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 5,
            summary:
                "RADICAL EVOLUTION SWEEP Phase D " +
                "backfill — CONSOLIDATION SCAFFOLDING"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百三十一",
            mNumberFirst: 1096,
            mNumberLast: 1099,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 4,
            summary:
                "RADICAL EVOLUTION SWEEP Phase E entry " +
                "— NATIVE APPLE SILICON FOUNDATION"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百三十二",
            mNumberFirst: 1100,
            mNumberLast: 1103,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 5,
            summary:
                "RADICAL EVOLUTION SWEEP Phase F entry " +
                "— HARDWARE-AWARE SCHEDULER COMPOSITION"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百三十三",
            mNumberFirst: 1104,
            mNumberLast: 1109,
            knivesCount: 6,
            entropyClassesCount: 6,
            pinsCount: 11,
            futureCutsCount: 4,
            summary:
                "RADICAL EVOLUTION SWEEP final close-" +
                "out — sidecar + cumulative sweep " +
                "doctrine + 2 deep-review remediation " +
                "rounds (M1108 + M1109) + ADR-016 → " +
                "M1107 → M1109 advance。 Loop closed"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百三十四",
            mNumberFirst: 1110,
            mNumberLast: 1115,
            knivesCount: 6,
            entropyClassesCount: 6,
            pinsCount: 11,
            futureCutsCount: 6,
            summary:
                "POST-RADICAL safety substrate +" +
                " canonical60 driver — external" +
                " consumer audit (Qinao SDK reality" +
                " reflected) + BASEntropyChapterIndex" +
                " extended to 31 chapters +" +
                " BASStressSweepCanonical60Driver" +
                " (typed 60-fixture set + identity/" +
                "divergence stub runners) + ADR-016 →" +
                " M1115 advance"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百三十五",
            mNumberFirst: 1116,
            mNumberLast: 1119,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 4,
            summary:
                "POST-RADICAL Wave 6 entry — FIRST" +
                " production scheduler consumption。" +
                " BASTurnRuntimeEngine.runWithPlan(...)" +
                " now calls scheduler.assign(...) per" +
                " stage step + captures decisions into" +
                " typed BASTurnRuntimePlanAssignmentLedger。" +
                " ADR-016 → M1119 advance"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百三十六",
            mNumberFirst: 1120,
            mNumberLast: 1123,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 4,
            summary:
                "POST-RADICAL Wave 7 entry — FIRST" +
                " ledger-driven dispatch。 BASNativeStage" +
                "Executor.executePlanWithAssignments(...)" +
                " reads assignment ledger + routes each" +
                " stage via RoutedStageExecutor closure +" +
                " captures honored vs fall-through into" +
                " BASNativeStageDispatchLedger。 ADR-016" +
                " → M1123 advance"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百三十七",
            mNumberFirst: 1124,
            mNumberLast: 1127,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 4,
            summary:
                "POST-RADICAL Wave 8 entry — END-TO-END" +
                " routed dispatch。 BASRuntimeInternal" +
                "Delegate.runScaffoldedWithAssignments" +
                "(...) bridges executor's routed path +" +
                " engine.runWithPlan(...) branches on" +
                " assignment ledger + captures dispatch" +
                " ledger。 ADR-016 → M1127 advance"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百三十八",
            mNumberFirst: 1128,
            mNumberLast: 1131,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 4,
            summary:
                "POST-RADICAL Wave 9 entry — HOST-SIDE" +
                " INJECTION。 BASTurnRuntimeEngine" +
                "Configuration gains routedStageExecutor" +
                " + fallbackStageExecutor optional slots;" +
                " engine threads them through to delegate" +
                " automatically。 Substrate-side end-to-end" +
                " is now COMPLETE — Qinao SDK can wire" +
                " real backend dispatch via single config" +
                " slot。 ADR-016 → M1131 advance"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百三十九",
            mNumberFirst: 1132,
            mNumberLast: 1135,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 4,
            summary:
                "POST-RADICAL Wave 10 entry — DISPATCH" +
                " ↔ EVENT LOG BRIDGE。 5th typed payload" +
                " kind (.nativeStageDispatch) connects" +
                " chapter 436 BASNativeStageDispatchLedger" +
                " to Phase B's chapter 428 unified event" +
                " log。 Replay surface complete — no more" +
                " blackbox actor state for runtime" +
                " decisions。 ADR-016 → M1135 advance"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百四十",
            mNumberFirst: 1136,
            mNumberLast: 1139,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 4,
            summary:
                "POST-RADICAL Wave 11 entry — DISPATCH" +
                " AUTO-EMIT。 BASTurnRuntimeEngine.run" +
                "WithPlan(...) auto-emits dispatch event" +
                " to configured event log when ledger" +
                " non-empty。 Substrate-side autonomy" +
                " COMPLETE — hosts only wire event log。" +
                " ADR-016 → M1139 advance"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百四十一",
            mNumberFirst: 1140,
            mNumberLast: 1143,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 4,
            summary:
                "POST-RADICAL Wave 12 entry — PLAN-" +
                "ASSIGNMENT EVENT TYPE。 6th typed event" +
                " payload kind on the unified event log;" +
                " engine auto-emits captured scheduler" +
                " decisions after dispatch event so" +
                " capture → honor temporal order is" +
                " replay-deterministic。 Substrate-side" +
                " replay surface COMPLETE — full routed-" +
                "dispatch story event-replayable from one" +
                " canonical stream。 ADR-016 → M1143 advance"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百四十二",
            mNumberFirst: 1144,
            mNumberLast: 1147,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 4,
            summary:
                "POST-RADICAL Wave 13 entry — REPLAY-" +
                "REBUILD INTEGRATION。 BASEventLogReplay" +
                "Bundle typed Sendable + Equatable +" +
                " Hashable struct aggregates all 6" +
                " projector outputs;13 round-trip" +
                " integration tests prove byte-equal" +
                " round-trip through real BASInMemoryEvent" +
                "LogStorage + cross-kind isolation +" +
                " sequenceNumber ordering preservation。" +
                " Replay surface is PROVEN end-to-end。" +
                " ADR-016 → M1147 advance"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百四十三",
            mNumberFirst: 1148,
            mNumberLast: 1151,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 4,
            summary:
                "POST-RADICAL Wave 14 entry — CROSS-" +
                "SESSION REPLAY ASSEMBLY。 BASEventLog" +
                "ReplayBundle.merging(_:) + .combining(_:)" +
                " typed composition + BASEventLogProjectors" +
                ".projectAcrossAllSessions(from:" +
                "sinceTimestampMs:limit:) async factory" +
                " pulling events globally-time-ordered" +
                " from storage。 14 cross-session" +
                " integration tests。 Replay surface" +
                " offers complete typed API for distributed" +
                " consumers without boilerplate。 ADR-016" +
                " → M1151 advance"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百四十四",
            mNumberFirst: 1152,
            mNumberLast: 1155,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 4,
            summary:
                "POST-RADICAL Wave 15 entry — PER-STAGE" +
                " EVENT PAYLOAD。 BASNativeStagePerStepEvent" +
                "Payload typed Codable + 8 fields +" +
                " factory bridging from chapter 439" +
                " per-turn record + 7th BASEventPayloadKind" +
                " case + EXTENDED BASEventLogReplayBundle" +
                " to 7 fields。 Sibling of chapter 439" +
                " per-turn dispatch event for fine-grained" +
                " causal-graph extraction。 Engine does" +
                " NOT auto-emit per-step events;hosts" +
                " opt-in directly。 ADR-016 → M1155 advance"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百四十五",
            mNumberFirst: 1156,
            mNumberLast: 1159,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 4,
            summary:
                "POST-RADICAL Wave 16 entry — FEDERATED" +
                " EVENT LOG MULTI-BACKEND。 BASFederated" +
                "EventLogStorage actor wraps N backend" +
                " conformers + presents them as ONE" +
                " unified event log via the existing" +
                " BASEventLogStorage protocol。 Chapter" +
                " 443 projectAcrossAllSessions(from:)" +
                " accepts it as drop-in。 15 integration" +
                " tests prove construction + routing +" +
                " global ordering + propagation +" +
                " determinism。 ADR-016 → M1159 advance"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百四十六",
            mNumberFirst: 1160,
            mNumberLast: 1163,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 4,
            summary:
                "POST-RADICAL Wave 17 entry — POST-" +
                "RADICAL EVOLUTION SWEEP CLOSE-OUT" +
                " meta-doctrine。 BASPostRadicalSweep" +
                "Doctrine typed namespace summarizes" +
                " cumulative achievement (Waves 1-17," +
                " chapters 427-446,M1080-M1163,84" +
                " commits) + 8 substrate-side" +
                " achievements + 5 explicitly deferred" +
                " items + 10 doctrine pins held" +
                " throughout。 Anchor for future" +
                " chapter narratives。 ADR-016 → M1163" +
                " advance"),
    ]

    /// Number of RADICAL EVOLUTION chapters indexed
    /// (7 after M1108 extension covering all 6 phase
    /// chapters + the chapter 四百三十三 final close-out)。
    public static var radicalEvolutionEntryCount: Int {
        return radicalEvolutionEntries.count
    }

    /// **M1111 — Wave 2 STAGE 1 extension**:complete
    /// 31-entry mirror covering ALL Phase 2 chapters
    /// (chapters 四百三 through 四百三十三)。 This is the
    /// single source-of-truth that makes the per-chapter
    /// `BASChapter*EntropyDoctrine.swift` files
    /// deletable in a future cleanup chapter without
    /// losing any chapter summary。
    ///
    /// 24 pre-RADICAL chapters (403-426) + 7 RADICAL
    /// chapters (427-433) = 31 entries。 Hand-maintained
    /// at M1111 with field values cross-checked against
    /// the corresponding chapter doctrine `.swift` files
    /// via grep audit。 chapter 447 onward extends via
    /// `postSweepRealExecutionEntries` — keeping SWEEP
    /// chapter 446 frozen as the SWEEP narrative
    /// snapshot。
    public static let phase2Entries:
        [BASEntropyChapterEntry] =
        prePhase2RadicalEntries +
        radicalEvolutionEntries +
        postSweepRealExecutionEntries

    /// POST-SWEEP REAL EXECUTION FOLLOW-THROUGH entries
    /// (chapter 447 onward)。 Chapter 446 closed the
    /// SWEEP narrative as a discrete 17-wave snapshot;
    /// chapter 447 opens the next chapter sequence
    /// focused on real compute (vs scaffolding)。
    /// SWEEP doctrine intentionally stays frozen at
    /// chapter 446 so its narrative remains a historical
    /// anchor。
    public static let postSweepRealExecutionEntries:
        [BASEntropyChapterEntry] =
    [
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百四十七",
            mNumberFirst: 1164,
            mNumberLast: 1167,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 5,
            summary:
                "POST-SWEEP REAL EXECUTION FOLLOW-" +
                "THROUGH chapter 1 — FIRST REAL GPU" +
                " KERNEL EXECUTION。 BASMPSGraphMatMul" +
                "Kernel actor wraps MTLDevice +" +
                " MPSMatrixMultiplication;input bytes" +
                " actually flow CPU → MTLBuffer → GPU" +
                " shaders → MTLBuffer → CPU。 4 PROOF" +
                " tests verify byte-equal output +" +
                " non-square shapes + GPU/CPU" +
                " agreement。 「原生利用神经引擎」 first" +
                " truthful endpoint。 ADR-016 → M1167" +
                " advance")
    ]

    /// 24 pre-RADICAL Phase 2 chapter mirrors (chapters
    /// 403-426)。 Hand-maintained — pinsCount /
    /// futureCutsCount /knivesCount values cross-checked
    /// against the corresponding chapter doctrine files。
    private static let prePhase2RadicalEntries:
        [BASEntropyChapterEntry] =
    [
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百三",
            mNumberFirst: 953,
            mNumberLast: 962,
            knivesCount: 10,
            entropyClassesCount: 0,
            pinsCount: 11,
            futureCutsCount: 4,
            summary:
                "chapter-403-v1-entry-doctrine-pin —" +
                " Phase 2 entry chapter,V2 RUNTIME REWRITE" +
                " architectural baseline"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百四",
            mNumberFirst: 963,
            mNumberLast: 980,
            knivesCount: 18,
            entropyClassesCount: 0,
            pinsCount: 11,
            futureCutsCount: 10,
            summary:
                "chapter-404-v1-complete — V2 actor" +
                " delegation skeleton + composition-" +
                "entropy ledger + threading entropy" +
                " collapse + naming bridge + bundle" +
                " protocol + 9 typed primitives"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百五",
            mNumberFirst: 981,
            mNumberLast: 988,
            knivesCount: 8,
            entropyClassesCount: 0,
            pinsCount: 11,
            futureCutsCount: 5,
            summary:
                "chapter-405-v1-bundle-protocol-" +
                "comprehensive — BASBundleProtocol" +
                " + 9 BAS*Bundle conformer migrations"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百六",
            mNumberFirst: 989,
            mNumberLast: 997,
            knivesCount: 9,
            entropyClassesCount: 0,
            pinsCount: 11,
            futureCutsCount: 4,
            summary:
                "chapter-406-v1-v2-lifecycle-" +
                "comprehensive — V2 actor lifecycle" +
                " envelope (start + complete) + audit" +
                " emission summary"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百七",
            mNumberFirst: 998,
            mNumberLast: 1001,
            knivesCount: 4,
            entropyClassesCount: 0,
            pinsCount: 11,
            futureCutsCount: 4,
            summary:
                "chapter-407-v1-v2-actor-four-" +
                "foundations — BASTurnRuntimeEngine" +
                "Configuration + 4-foundation V2 init"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百八",
            mNumberFirst: 1002,
            mNumberLast: 1005,
            knivesCount: 4,
            entropyClassesCount: 0,
            pinsCount: 11,
            futureCutsCount: 4,
            summary:
                "chapter-408-v1-v2-stage-execution-" +
                "foundation — BASTurnRuntimeStageRecord" +
                " + BASTurnRuntimeStageLedger M1003"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百九",
            mNumberFirst: 1006,
            mNumberLast: 1009,
            knivesCount: 4,
            entropyClassesCount: 0,
            pinsCount: 11,
            futureCutsCount: 4,
            summary:
                "chapter-409-v1-v2-stage-plan-" +
                "foundation — BASTurnRuntimeStagePlan" +
                " + BASTurnRuntimeStageStep M1006"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百十",
            mNumberFirst: 1010,
            mNumberLast: 1013,
            knivesCount: 4,
            entropyClassesCount: 0,
            pinsCount: 11,
            futureCutsCount: 4,
            summary:
                "chapter-410-v1-v2-permit-fold-input-" +
                "foundation — BASPermitEscalationFoldInput"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百十一",
            mNumberFirst: 1014,
            mNumberLast: 1017,
            knivesCount: 4,
            entropyClassesCount: 0,
            pinsCount: 11,
            futureCutsCount: 4,
            summary:
                "chapter-411-v1-v2-stress-sweep-input-" +
                "foundation — BASStressSweepInput primitive"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百十二",
            mNumberFirst: 1018,
            mNumberLast: 1021,
            knivesCount: 4,
            entropyClassesCount: 0,
            pinsCount: 11,
            futureCutsCount: 4,
            summary:
                "chapter-412-v1-v2-stress-sweep-plan-" +
                "foundation — BASStressSweepFixturePlan"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百十三",
            mNumberFirst: 1022,
            mNumberLast: 1025,
            knivesCount: 4,
            entropyClassesCount: 0,
            pinsCount: 11,
            futureCutsCount: 4,
            summary:
                "chapter-413-v1-v2-stress-sweep-verdict-" +
                "foundation — BASStressSweepVerdict typed"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百十四",
            mNumberFirst: 1026,
            mNumberLast: 1029,
            knivesCount: 4,
            entropyClassesCount: 0,
            pinsCount: 11,
            futureCutsCount: 4,
            summary:
                "chapter-414-v1-v2-parallel-dispatch-" +
                "foundation — BASParallelStageDispatch" +
                "Input + ParallelGroup discriminator"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百十五",
            mNumberFirst: 1030,
            mNumberLast: 1033,
            knivesCount: 4,
            entropyClassesCount: 0,
            pinsCount: 11,
            futureCutsCount: 4,
            summary:
                "chapter-415-v1-v2-parallel-dispatch-" +
                "summary-foundation — BASParallelStage" +
                "DispatchSummary + envelope integration"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百十六",
            mNumberFirst: 1034,
            mNumberLast: 1037,
            knivesCount: 4,
            entropyClassesCount: 0,
            pinsCount: 11,
            futureCutsCount: 4,
            summary:
                "chapter-416-v1-v2-parallel-summary-" +
                "envelope-integration — payload threading"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百十七",
            mNumberFirst: 1038,
            mNumberLast: 1041,
            knivesCount: 4,
            entropyClassesCount: 0,
            pinsCount: 11,
            futureCutsCount: 4,
            summary:
                "chapter-417-v1-v2-stage-ledger-" +
                "validation-foundation — typed ledger" +
                " invariant validation"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百十八",
            mNumberFirst: 1042,
            mNumberLast: 1045,
            knivesCount: 4,
            entropyClassesCount: 0,
            pinsCount: 11,
            futureCutsCount: 4,
            summary:
                "chapter-418-v1-v2-plan-ledger-coherence-" +
                "foundation — BASTurnRuntimePlanLedger" +
                "Coherence projection"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百十九",
            mNumberFirst: 1046,
            mNumberLast: 1049,
            knivesCount: 4,
            entropyClassesCount: 0,
            pinsCount: 11,
            futureCutsCount: 4,
            summary:
                "chapter-419-v1-v2-coherence-envelope-" +
                "integration — coherence threading into" +
                " complete envelope"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百二十",
            mNumberFirst: 1050,
            mNumberLast: 1053,
            knivesCount: 4,
            entropyClassesCount: 0,
            pinsCount: 11,
            futureCutsCount: 4,
            summary:
                "chapter-420-v1-v2-summary-digest-" +
                "foundation — typed digest accessor over" +
                " BASRuntimeAuditEmissionSummary"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百二十一",
            mNumberFirst: 1054,
            mNumberLast: 1057,
            knivesCount: 4,
            entropyClassesCount: 0,
            pinsCount: 11,
            futureCutsCount: 5,
            summary:
                "chapter-421-v1-v2-phase-2-close-out — " +
                "Phase 2 entropy closure doctrine + 19-" +
                "chapter ledger pin (later self-extended)"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百二十二",
            mNumberFirst: 1058,
            mNumberLast: 1061,
            knivesCount: 4,
            entropyClassesCount: 0,
            pinsCount: 11,
            futureCutsCount: 4,
            summary:
                "chapter-422-v1-v2-substrate-integrity — " +
                "schema-completeness invariant test pin"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百二十三",
            mNumberFirst: 1062,
            mNumberLast: 1065,
            knivesCount: 4,
            entropyClassesCount: 0,
            pinsCount: 11,
            futureCutsCount: 3,
            summary:
                "chapter-423-v1-v2-roadmap-ops-" +
                "convenience — BASRoadmapDoctrine" +
                " convenience accessors"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百二十四",
            mNumberFirst: 1066,
            mNumberLast: 1069,
            knivesCount: 4,
            entropyClassesCount: 0,
            pinsCount: 11,
            futureCutsCount: 3,
            summary:
                "chapter-424-v1-v2-doctrine-chain-" +
                "consistency — BASDoctrineChain" +
                "ConsistencyTests cross-cutting invariant"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百二十五",
            mNumberFirst: 1070,
            mNumberLast: 1073,
            knivesCount: 4,
            entropyClassesCount: 0,
            pinsCount: 12,
            futureCutsCount: 4,
            summary:
                "chapter-425-v1-v2-real-executor-" +
                "foundation — BASPermitEscalationFold" +
                "Executor + BASParallelStageDispatch" +
                "Executor real-actor versions"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百二十六",
            mNumberFirst: 1074,
            mNumberLast: 1077,
            knivesCount: 4,
            entropyClassesCount: 0,
            pinsCount: 13,
            futureCutsCount: 3,
            summary:
                "chapter-426-v1-v2-adr018-full-" +
                "ratification — BASStressSweepHarness" +
                " + BASNativeStageExecutor — ADR-018" +
                " 4/4 ratified")
    ]

    /// Total Phase 2 entry count (after M1111 extension)。
    public static var phase2EntryCount: Int {
        return phase2Entries.count
    }

    /// Look up an entry by chapter tag across the
    /// COMPLETE 31-entry Phase 2 mirror (M1111
    /// extension)。 Returns nil if no match。
    public static func phase2Entry(
        forTag tag: String
    ) -> BASEntropyChapterEntry? {
        return phase2Entries.first {
            $0.chapterTag == tag
        }
    }

    /// Look up an entry covering the given M-number
    /// across the COMPLETE 31-entry Phase 2 mirror。
    public static func phase2Entry(
        forMNumber m: Int
    ) -> BASEntropyChapterEntry? {
        return phase2Entries.first {
            m >= $0.mNumberFirst && m <= $0.mNumberLast
        }
    }

    // MARK: - Accessors

    /// Look up entry by chapterTag。 Returns nil if no
    /// matching entry。
    public static func entry(
        forTag tag: String
    ) -> BASEntropyChapterEntry? {
        return radicalEvolutionEntries.first {
            $0.chapterTag == tag
        }
    }

    /// Look up entry covering the given M-number。
    /// Returns nil if no matching chapter spans the
    /// number。
    public static func entry(
        forMNumber m: Int
    ) -> BASEntropyChapterEntry? {
        return radicalEvolutionEntries.first {
            m >= $0.mNumberFirst && m <= $0.mNumberLast
        }
    }

    /// Predicate:does any indexed chapter cover the
    /// given M-number range (inclusive endpoints)?
    public static func coversMNumberRange(
        from first: Int,
        to last: Int
    ) -> Bool {
        for entry in radicalEvolutionEntries {
            if entry.mNumberFirst >= first
                && entry.mNumberLast <= last
            {
                return true
            }
        }
        return false
    }

    /// Total knives (cuts) shipped across all indexed
    /// chapters。 At M1092: 5 chapters × 4 knives = 20。
    public static var totalKnivesCount: Int {
        return radicalEvolutionEntries.reduce(0) {
            $0 + $1.knivesCount
        }
    }

    /// Earliest M-number indexed (chapter 四百二十七's
    /// M1080)。
    public static var earliestMNumber: Int {
        return radicalEvolutionEntries.map {
            $0.mNumberFirst
        }.min() ?? 0
    }

    /// Latest M-number indexed (chapter 四百三十二's
    /// M1103)。
    public static var latestMNumber: Int {
        return radicalEvolutionEntries.map {
            $0.mNumberLast
        }.max() ?? 0
    }
}
