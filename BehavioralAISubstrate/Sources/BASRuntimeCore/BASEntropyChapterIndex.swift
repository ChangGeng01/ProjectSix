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
                " advance"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百四十八",
            mNumberFirst: 1168,
            mNumberLast: 1171,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 5,
            summary:
                "POST-SWEEP REAL EXECUTION chapter 2 —" +
                " SECOND REAL GPU KERNEL via MPSGraph。" +
                " BASMPSGraphRMSNormKernel actor composes" +
                " 6-op graph (sq+reduceMean+add+sqrt+" +
                "div+mul) and dispatches through graph." +
                "run(...)。 First MPSGraph usage in" +
                " substrate;establishes pattern for" +
                " future arbitrary-op GPU kernels。 4" +
                " PROOF tests verify GPU output within" +
                " 1e-4 absolute tolerance of CPU" +
                " reference。 「原生利用神经引擎」 progress" +
                " 1/3 → 2/3。 ADR-016 → M1171 advance"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百四十九",
            mNumberFirst: 1172,
            mNumberLast: 1175,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 5,
            summary:
                "POST-SWEEP REAL EXECUTION chapter 3 —" +
                " THIRD + FINAL real GPU kernel" +
                " (rotaryEmbedding via MPSGraph)。 All" +
                " 3 chapter 431 CPU-stub kernels now" +
                " have real GPU-dispatching siblings。" +
                " 「原生利用神经引擎」 2/3 → 3/3 COMPLETE。" +
                " 4 PROOF tests verify identity + 90°" +
                " known result + GPU/CPU agreement" +
                " within 1e-5。 ADR-016 → M1175 advance"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百五十",
            mNumberFirst: 1176,
            mNumberLast: 1179,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 5,
            summary:
                "POST-SWEEP BIOMIMETIC chapter 1 —" +
                " FIRST substrate-level stateful +" +
                " selective-gated primitive。" +
                " BASMambaSSMState actor maintains" +
                " continuous hidden state across" +
                " selectiveScan() calls。 CPU baseline" +
                " canonical Mamba update: dA=exp(Δ·A)" +
                " + h=dA·h+dB·x + y=sum_n(C·h)。 9" +
                " PROOF tests including state-persists" +
                " + Δ=0-freezes (selective gating) +" +
                " multi-batch independence + multi-step" +
                " == sequential。 「不够仿生」 0/10 →" +
                " 4/10。 ADR-016 → M1179"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百五十一",
            mNumberFirst: 1180,
            mNumberLast: 1183,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 5,
            summary:
                "POST-SWEEP BIOMIMETIC chapter 2 —" +
                " GPU acceleration for BASMambaSSMState" +
                " via FIRST custom Metal compute shader" +
                " in substrate。 Runtime-compiled" +
                " selective_scan kernel dispatches B×D" +
                " threads with sequential timestep loop" +
                " per thread。 CPU + GPU paths share" +
                " the SAME actor-isolated hidden state。" +
                " 3 NEW GPU PROOF tests:GPU-matches-" +
                "CPU + state-persists + MIXED GPU/CPU" +
                " interleaved calls share state。" +
                " 「不够仿生」 4/10 → 5/10。" +
                " ADR-016 → M1183"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百五十二",
            mNumberFirst: 1184,
            mNumberLast: 1187,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 5,
            summary:
                "POST-SWEEP BIOMIMETIC chapter 3 —" +
                " substrate's FIRST closed-loop" +
                " adaptive primitive。 BASPredictive" +
                "CodingProbe actor maintains running" +
                " prediction μ + adapts via μ ← μ + α·ε。" +
                " Running MSE surfaces as substrate-" +
                "level adaptation signal。 11 PROOF" +
                " tests including CLOSED-LOOP CONVERGENCE" +
                " (50 obs converges) + ADAPTATION SIGNAL" +
                " (MSE decreases) + DISTRIBUTION SHIFT" +
                " (error spike + recalibration)。" +
                " 「不够灵活」 ~15% → ~35%。" +
                " ADR-016 → M1187"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百五十三",
            mNumberFirst: 1188,
            mNumberLast: 1191,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 5,
            summary:
                "POST-SWEEP REAL EXECUTION chapter —" +
                " adds attention (4th transformer kernel)" +
                " to the matMul + rmsNorm + rotaryEmbed" +
                "ding triad。 CPU softmax via row-wise" +
                " max-shift numerical stability;GPU" +
                " composes transpose + matMul + softMax" +
                " in one MPSGraph executable。 5 PROOF" +
                " tests (identity + uniform-K +" +
                " dominant-K + GPU/CPU agreement)。" +
                " 「原生利用神经引擎」 3/3 → 4/4。" +
                " ADR-016 → M1191"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百五十四",
            mNumberFirst: 1192,
            mNumberLast: 1195,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 5,
            summary:
                "POST-SWEEP BIOMIMETIC chapter 4 —" +
                " substrate's FIRST learning primitive。" +
                " BASPlasticityFold actor maintains" +
                " weight matrix W across apply() calls" +
                " via 3 selectable rules (Hebbian +" +
                " antiHebbian + outcomeModulatedHebbian)。" +
                " 12 PROOF tests including HEBBIAN" +
                " LEARNS ASSOCIATION (10 repeated pre/" +
                "post pairs → forward query produces" +
                " the learned association)。 「不够灵活」" +
                " ~35% → ~50%。 ADR-016 → M1195"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百五十五",
            mNumberFirst: 1196,
            mNumberLast: 1199,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 12,
            futureCutsCount: 5,
            summary:
                "POST-SWEEP BIOMIMETIC chapter 5 —" +
                " cross-turn / cross-session state" +
                " persistence for ALL 3 biomimetic" +
                " primitives。 Codable snapshot bundles" +
                " (BASMambaSSMSnapshot +" +
                " BASPredictiveCodingSnapshot +" +
                " BASPlasticitySnapshot) + aggregate" +
                " BASBiomimeticStateSnapshot + in-actor" +
                " exportSnapshot/importSnapshot methods" +
                " (validate shape + flat-length before" +
                " mutating;fail-fast)。 20 PROOF tests" +
                " including 3 CHECKPOINT-RESTORE-" +
                "EVOLUTION-PARITY proofs:restored" +
                " state's subsequent trajectory byte-" +
                "equals a never-corrupted reference" +
                " actor's trajectory。 「不够仿生」 5/10 →" +
                " 6/10 (substrate REMEMBERS across host" +
                " restarts)。 ADR-016 → M1199"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百五十六",
            mNumberFirst: 1200,
            mNumberLast: 1203,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 5,
            summary:
                "POST-SWEEP BIOMIMETIC chapter 6 —" +
                " substrate's FIRST cross-primitive" +
                " orchestrator。 BASBiomimeticTurn" +
                "Observer bundles the 3 biomimetic" +
                " primitives + chapter 455 snapshot" +
                " value-type behind ONE actor + ONE" +
                " typed observe(_:) entry。 Optional" +
                " primitive slots;observe dispatches" +
                " to populated ones + skips nil。" +
                " exportAggregate/importAggregate" +
                " integrate chapter 455 snapshot with" +
                " 2 boundary clamps:unpopulated-slot" +
                " silently ignored,populated-with-nil-" +
                "snapshot untouched。 15 PROOF tests" +
                " including OBSERVER-LEVEL CHECKPOINT-" +
                "RESTORE-EVOLUTION-PARITY (byte-equal" +
                " trajectory after corruption + restore" +
                " at orchestrator level)。 Hosts" +
                " integrate biomimetic state with one" +
                " actor injection instead of three。" +
                " 「不够灵活」 ~50% → ~58%。" +
                " ADR-016 → M1203"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百五十七",
            mNumberFirst: 1204,
            mNumberLast: 1207,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 5,
            summary:
                "POST-SWEEP BIOMIMETIC chapter 7 — 4th" +
                " plasticity rule completing the" +
                " biomimetic rule quartet。 Canonical" +
                " Spike-Timing-Dependent Plasticity" +
                " (Bi & Poo 1998 + Markram et al 1997)" +
                " as .stdpTemporal case under SAME" +
                " BASPlasticityFold actor。" +
                " BASPlasticitySTDPParams typed (A_+,A_-," +
                "τ_+,τ_-) bundle with chapter 一百八十五" +
                " clamps + Codable backward-compat." +
                " amplitude(Δt) follows asymmetric" +
                " exponential window:LTP for Δt > 0," +
                " LTD for Δt < 0,zero at Δt = 0。 16" +
                " PROOF tests including 4× A bias + 20×" +
                " τ window-widening proofs + legacy" +
                " JSON defaulting + observer routing。" +
                " Substrate now learns CAUSAL ORDERING" +
                " not just correlations。 「不够仿生」" +
                " 6/10 → 7/10。 ADR-016 → M1207"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百五十八",
            mNumberFirst: 1208,
            mNumberLast: 1211,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 5,
            summary:
                "POST-SWEEP BIOMIMETIC chapter 8 — GPU-" +
                "accelerated plasticity update via" +
                " runtime-compiled Metal compute kernel" +
                " (mirrors chapter 451 Mamba GPU" +
                " pattern)。 Each (i,j) thread owns one" +
                " weight cell (no atomic contention);" +
                " scale computed CPU-side so all 4 rules" +
                " (Hebbian / antiHebbian / outcome-" +
                "modulated / STDP) share one kernel。 9" +
                " PROOF tests verify GPU/CPU agreement" +
                " byte-equal within 1e-5 across all 4" +
                " rules + cross-path mixing (CPU→GPU→CPU" +
                " on same fold proves shared hidden" +
                " weight state)。 Plasticity was LAST" +
                " CPU-only compute-heavy primitive;" +
                " GPU gap now closed。 「原生利用神经引擎」" +
                " 4/4 → 5/5。 ADR-016 → M1211"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百五十九",
            mNumberFirst: 1212,
            mNumberLast: 1215,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 5,
            summary:
                "POST-SWEEP BIOMIMETIC chapter 9 —" +
                " substrate's FIRST multi-level adaptive" +
                " primitive。 BASHierarchicalPredictive" +
                "Coding actor maintains N-layer stack" +
                " of probes;observe cascades error up" +
                " the stack (layer K sees layer K-1's" +
                " error,not raw input)。 Equal-dim" +
                " invariant + custom Codable init" +
                " ENFORCES invariant on DECODE" +
                " (malformed JSON fails loudly)。" +
                " Aggregate snapshot via chapter 455" +
                " integration covers entire stack。 12" +
                " PROOF tests verify cascade,convergence," +
                " snapshot round-trip,invariant" +
                " enforcement on malformed JSON。 Top-" +
                "layer error = irreducible surprise" +
                " signal。 Mirrors cortical hierarchies" +
                " (Rao & Ballard 1999;Friston free-" +
                "energy)。 「不够仿生」 7/10 → 8/10。" +
                " ADR-016 → M1215"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百六十",
            mNumberFirst: 1216,
            mNumberLast: 1219,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 5,
            summary:
                "DEBT REPAYMENT 1 — closes BENCHMARK" +
                " debt surfaced by chapter 459 self-" +
                "audit。 BASMetalBenchmarkHarness actor" +
                " runs N warmup + M timed iterations of" +
                " CPU + GPU plasticity paths,returns" +
                " typed report with mean/median/p95 µs" +
                " + speedup ratio。 7 PROOF tests" +
                " including REAL HARNESS RUN on 32×32" +
                " / 256×256 / 1024×1024 shapes emitting" +
                " measured µs。 Real numbers caught a" +
                " NUANCE fictional doctrine hid:GPU" +
                " is SLOWER at tiny shapes (32×32 →" +
                " 0.66x;dispatch overhead);dominates" +
                " at production scale (256×256 → 33.9x;" +
                " 1024×1024 → 138.0x)。 Chapter 458" +
                " doctrine UPDATED to cite harness +" +
                " remove fictional µs claims。" +
                " ADR-016 → M1219"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百六十一",
            mNumberFirst: 1220,
            mNumberLast: 1223,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 5,
            summary:
                "DEBT REPAYMENT 2 — closes INTEGRATION" +
                " debt surfaced by chapter 459 self-" +
                "audit。 First REAL wire from" +
                " BASTurnRuntimeEngine to" +
                " BASBiomimeticTurnObserver via two" +
                " new optional configuration slots" +
                " (biomimeticTurnObserver +" +
                " biomimeticTurnSignalBuilder)" +
                " defaulting to nil for ADR-014 OPT-IN" +
                " + 7-LOC hook block at end of" +
                " runWithPlan firing observer with" +
                " try? swallow (红线 7 observation-" +
                "not-commitment)。 8 PROOF tests verify" +
                " configuration slots + updaters +" +
                " observer-fires-with-builder-signal-" +
                "drives-primitive。 Honest scope:full" +
                " coordinator-level end-to-end test" +
                " deferred (no test-infra exists)。" +
                " Chapters 456+ orchestration no" +
                " longer dead-on-arrival。 「Substrate" +
                " not integrated into turn loop」 0% →" +
                " ~70%。 ADR-016 → M1223"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百六十二",
            mNumberFirst: 1224,
            mNumberLast: 1227,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 5,
            summary:
                "DEBT REPAYMENT 3 — closes LAST 30%" +
                " of chapter 461 integration debt by" +
                " shipping reusable stub-coordinator" +
                " factory + 3 end-to-end PROOF tests" +
                " through REAL engine.runWithPlan。 NEW" +
                " BASCoordinatorTestStubs.swift" +
                " factory wires all 10 service protocols" +
                " + returns ready-to-use" +
                " BASEBrainRuntimeCoordinator。 3 new" +
                " e2e tests verify observer fires per" +
                " real turn,5 runs increment counter" +
                " linearly,V1 byte-equality preserved" +
                " end-to-end (红线 7 verified through" +
                " real coordinator path,not just" +
                " simulated)。 Integration debt 70% →" +
                " 100%。 All 3 debts from chapter 459" +
                " self-audit now CLOSED。 ADR-016 →" +
                " M1227"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百六十三",
            mNumberFirst: 1228,
            mNumberLast: 1231,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 5,
            summary:
                "STRUCTURAL DEBT REPAYMENT chapter 1 —" +
                " Phase 1 of doctrine-collapse debt" +
                " called out in chapter 462 self-audit。" +
                " NEW BASChapterDoctrineRecord value-" +
                "type + BASChapterDoctrineRegistry with" +
                " 10 entries for chapters 453-462" +
                " DERIVED from existing per-chapter" +
                " Swift sources。 14 PROOF tests verify" +
                " byte-mirror equality + Codable round-" +
                "trip + lookup-by-tag + lookup-by-" +
                "mNumberFirst + knife-structure deep" +
                " mirror。 Phase 2 (chapter 464+) ships" +
                " new chapters as registry entries;" +
                " Phase 3 (chapter 465+) deletes the" +
                " 60+ historical Swift files。 Net debt" +
                " repayment after Phase 3:~−11K LOC。" +
                " ADR-016 → M1231"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百六十四",
            mNumberFirst: 1232,
            mNumberLast: 1235,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 5,
            summary:
                "STRUCTURAL DEBT REPAYMENT chapter 2 —" +
                " Phase 2 of doctrine-collapse。 FIRST" +
                " chapter doctrine living ONLY in" +
                " BASChapterDoctrineRegistry,no" +
                " per-chapter Swift file created。 The" +
                " chapter PROVES the Phase 2 pattern" +
                " by BEING its first instance。 10 PROOF" +
                " tests verify schema parity with" +
                " Swift-file chapters + M-range" +
                " contiguity + Codable round-trip of" +
                " literal record + Phase 2 covenant" +
                " (every chapter past 453 has a" +
                " registry entry)。 Per-chapter LOC" +
                " delta:~+50 literal vs ~+200 Swift" +
                " file (4× reduction)。 Phase 3" +
                " (chapter 465+) deletes 60+ historical" +
                " Swift files for the full ~−12K LOC" +
                " repayment。 ADR-016 → M1235"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百六十五",
            mNumberFirst: 1236,
            mNumberLast: 1239,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 5,
            summary:
                "STRUCTURAL DEBT REPAYMENT chapter 3 —" +
                " Phase 2b proof-of-pattern for" +
                " doctrine-collapse literal conversion。" +
                " Course-corrects from original chapter" +
                " 465 plan (destructive Phase 3 `git" +
                " rm`) to auto-mode-safe scope。 NEW" +
                " BASChapterDoctrineRegistry+Literals" +
                ".swift with chapter 453 as LITERAL +" +
                " 6 PROOF tests pinning literal-vs-" +
                "derivation byte-equality + chapter" +
                " 465 itself is registry-only (Phase 2" +
                " pattern continued)。 Phase 3 destruction" +
                " (60+ file `git rm` + bulk conversion)" +
                " requires explicit user confirmation。" +
                " Queued for chapter 466+。 ADR-016 →" +
                " M1239"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百六十六",
            mNumberFirst: 1240,
            mNumberLast: 1243,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 5,
            summary:
                "STRUCTURAL DEBT REPAYMENT chapter 4 —" +
                " Phase 3 of doctrine collapse EXECUTED" +
                " on phase-3-doctrine-collapse branch" +
                " with user OK。 Auto-extracted 61" +
                " chapter literals via Python script +" +
                " swapped BASChapterDoctrineRegistry.all" +
                " to consume literals + replaced 61" +
                " historical Swift doctrine files with" +
                " thin ~50-LOC forwarders。 Net LOC:" +
                " ~−3K reduction。 byte-mirror PROOF" +
                " tests pin every literal against its" +
                " source。 All existing tests pass" +
                " (forwarders preserve static surface)。" +
                " Dependency inverted:registry is now" +
                " the canonical store;per-chapter" +
                " symbols are thin readers。 ADR-016 →" +
                " M1243"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百六十七",
            mNumberFirst: 1244,
            mNumberLast: 1247,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 5,
            summary:
                "POST-PHASE-3 FEATURE 1 — auto-" +
                "checkpoint integration ties chapter 455" +
                " snapshot + chapter 456 observer +" +
                " chapter 461 engine hook + unified" +
                " event log。 NEW 8th payload kind" +
                " .biomimeticCheckpoint + typed" +
                " BASBiomimeticCheckpointEventPayload +" +
                " factory + reverse accessor。 NEW" +
                " biomimeticCheckpointEveryNTurns config" +
                " slot;engine extends chapter 461 hook" +
                " block to emit checkpoint events every" +
                " N turns when observer + cadence +" +
                " eventLog all wired。 12 PROOF tests" +
                " including end-to-end cadence emission" +
                " via stub coordinator (6 turns @" +
                " cadence=3 → 2 events emitted)。 ADR-" +
                "014 OPT-IN preserved (nil cadence = no" +
                " emission)。 Cross-session biomimetic" +
                " state recovery via event-log replay" +
                " now achievable;loop closure in chapter" +
                " 468。 ADR-016 → M1247"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百六十八",
            mNumberFirst: 1248,
            mNumberLast: 1251,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 11,
            futureCutsCount: 5,
            summary:
                "POST-PHASE-3 FEATURE 2 — closes the" +
                " cross-session biomimetic-state" +
                " recovery loop opened by chapter 467。" +
                " NEW BASBiomimeticCheckpointReplay" +
                " typed namespace with 3 helpers:" +
                " latestCheckpoint + restoreObserver +" +
                " checkpointCount。 9 PROOF tests" +
                " including bedrock END-TO-END loop" +
                " closure (engine emits → replay" +
                " restores → byte-equal state)。 Cross-" +
                "session recovery is now a 1-line call。" +
                " ADR-016 → M1251"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百六十九",
            mNumberFirst: 1252, mNumberLast: 1255,
            knivesCount: 4, entropyClassesCount: 4,
            pinsCount: 11, futureCutsCount: 5,
            summary: "BCM meta-plasticity primitive。" +
                " 11 PROOF tests including threshold-" +
                "homeostatic-rise proof。 ADR-016 → M1255"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百七十",
            mNumberFirst: 1256, mNumberLast: 1259,
            knivesCount: 4, entropyClassesCount: 4,
            pinsCount: 11, futureCutsCount: 5,
            summary: "Wire BASHierarchicalPredictive" +
                "Coding into BASBiomimeticTurnObserver" +
                " as 4th optional slot。 5 PROOF tests。" +
                " ADR-016 → M1259"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百七十一",
            mNumberFirst: 1260, mNumberLast: 1263,
            knivesCount: 4, entropyClassesCount: 4,
            pinsCount: 11, futureCutsCount: 3,
            summary: "Expand BASMetalBenchmarkHarness" +
                " with runMambaScan covering Mamba CPU" +
                " + GPU paths。 2 PROOF tests with real" +
                " µs。 ADR-016 → M1263"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百七十二",
            mNumberFirst: 1264, mNumberLast: 1267,
            knivesCount: 4, entropyClassesCount: 4,
            pinsCount: 11, futureCutsCount: 5,
            summary: "Add biomimeticCheckpointEvents" +
                " field to BASEventLogReplayBundle" +
                " (closes chapter 442 projection gap)。" +
                " Codable backward-compat preserved。" +
                " All chapter-468 plannedFutureCuts now" +
                " shipped。 ADR-016 → M1267"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百七十三",
            mNumberFirst: 1268, mNumberLast: 1271,
            knivesCount: 4, entropyClassesCount: 4,
            pinsCount: 11, futureCutsCount: 5,
            summary: "POST-PHASE-3 self-audit cleanup。" +
                " 8 fixes from chapter 466 deep review:" +
                " frozen-SHA256 anti-drift replaces" +
                " circular byte-mirror;BCM wired into" +
                " observer as 5th slot;e2e hierarchical" +
                " + BCM through real engine;chapter 472" +
                " backward-compat decoder PROOF;" +
                " production-scale Mamba benchmark" +
                " (25.85x GPU speedup measured);Python" +
                " scripts committed;chapter 466 prose" +
                " honestly revised。 Branch ready for" +
                " merge review。 ADR-016 → M1271"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百七十四",
            mNumberFirst: 1272, mNumberLast: 1275,
            knivesCount: 4, entropyClassesCount: 4,
            pinsCount: 11, futureCutsCount: 5,
            summary: "REAL HOT-PATH ATTACK phase 1 —" +
                " first chapter that substantively" +
                " closes 3 of the 6 directives scored" +
                " ≤4/10 at chapter 473 deep review。" +
                " Cut 1 — BASANELiveReader factory" +
                " (ANE 1/10 gap)。 Cut 2 —" +
                " BASKernelRegistryDispatchExecutor" +
                " factory (MPSGraph 4/10 gap)。 Cut 3 —" +
                " end-to-end integration PROOF of" +
                " hint→scheduler→assignment→executor→" +
                "registry→kernel chain。 Cut 4 —" +
                " chapter close-out。 ADR-016 → M1275。" +
                " V1 byte-equality preserved via ADR-" +
                "014 OPT-IN — all new surfaces are" +
                " additive factories;hosts opt in to" +
                " activate。"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百七十五",
            mNumberFirst: 1276, mNumberLast: 1279,
            knivesCount: 4, entropyClassesCount: 4,
            pinsCount: 11, futureCutsCount: 5,
            summary: "REAL HOT-PATH ATTACK phase 2 —" +
                " closes the chapter 474 EchoKernel" +
                " placeholder gap。 Cut 1 —" +
                " BASCanonicalKernelInputBuilders" +
                " typed factory namespace (matMul/" +
                "rmsNorm/rotaryEmbedding + Float↔Data" +
                " helpers)。 Cut 2 — FIRST PROOF that" +
                " MPSGraph kernels actually compute" +
                " correctly with 5 numerical tests。" +
                " Cut 3 — full chain end-to-end PROOF" +
                " with REAL BASMPSGraphMatMulKernel" +
                " (replaces EchoKernel stub)。 Cut 4 —" +
                " chapter close-out。 ADR-016 → M1279。" +
                " '更硬核' now has SUBSTANTIVE evidence"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百七十六",
            mNumberFirst: 1280, mNumberLast: 1283,
            knivesCount: 4, entropyClassesCount: 4,
            pinsCount: 11, futureCutsCount: 5,
            summary: "REAL HOT-PATH ATTACK phase 3 —" +
                " RMSNorm + RotaryEmbedding numerical" +
                " PROOF (3 of 4 MPSGraph kernels now" +
                " verified) + FIRST real" +
                " BASBundle<Item> typealias migration" +
                " (closes chapter 429 scaffold-without-" +
                "migration gap)。 Cut 1 — RMSNorm" +
                " kernel correctness。 Cut 2 —" +
                " BASKernelDispatchOutcomeBundle real" +
                " adoption。 Cut 3 — RotaryEmbedding" +
                " kernel correctness。 Cut 4 — chapter" +
                " close-out。 ADR-016 → M1283。"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百七十七",
            mNumberFirst: 1284, mNumberLast: 1287,
            knivesCount: 4, entropyClassesCount: 4,
            pinsCount: 13, futureCutsCount: 5,
            summary: "REAL HOT-PATH ATTACK phase 4 —" +
                " final session close-out。 Cut 1 —" +
                " attention kernel numerical PROOF" +
                " (4-of-4 MPSGraph coverage now" +
                " complete)。 Cut 2 —" +
                " BASRealHotPathAttackEvaluation" +
                "Doctrine honest re-scoring of 6" +
                " user-stated directives (11/60 →" +
                " 28/60 = +17 points net progress)。" +
                " Cut 3 — BASMPSGraphKernelCoverage" +
                "Bundle second real BASBundle<Item>" +
                " migration (pattern scales)。 Cut 4" +
                " — chapter close-out。 ADR-016 →" +
                " M1287。 4-chapter arc sealed (16" +
                " commits / V1 byte-equality" +
                " preserved throughout)。"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百七十八",
            mNumberFirst: 1288, mNumberLast: 1291,
            knivesCount: 4, entropyClassesCount: 4,
            pinsCount: 13, futureCutsCount: 5,
            summary: "REAL HOT-PATH ATTACK to 100%" +
                " Phase A — V1 fold PILOT + stress-" +
                "sweep dual mode regression guard。" +
                " Cut 1 — BASTurnAuditProjections" +
                "KunlunTrio first V1 fold extraction。" +
                " Cut 2 — coordinator splice replaces" +
                " 3 ForAudit declarations。 Cut 3 —" +
                " BASTurnRuntimeFullSummaryStressSweep" +
                "Runner closes chapter 434 deferral +" +
                " canonical60 PROOF with 300-turn-run" +
                " 0-divergence verification。 Cut 4 —" +
                " chapter close-out。 ADR-016 → M1291。"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百七十九",
            mNumberFirst: 1292, mNumberLast: 1295,
            knivesCount: 4, entropyClassesCount: 4,
            pinsCount: 12, futureCutsCount: 5,
            summary: "REAL HOT-PATH ATTACK to 100%" +
                " Phase B — 3 missing MPSGraph kernels" +
                " shipped。 BASNeuralOp coverage:" +
                " 4-of-8 → 7-of-8 (87.5%)。 Cut 1 —" +
                " BASMPSGraphSoftmaxKernel + 5 PROOF" +
                " tests。 Cut 2 — BASMPSGraphLayerNorm" +
                "Kernel + 5 PROOF tests。 Cut 3 —" +
                " BASMPSGraphConv2DKernel + 4 PROOF" +
                " tests。 Cut 4 — chapter close-out。" +
                " ADR-016 → M1295。 Only ssmScan" +
                " (Mamba SSM) deferred to Tier 2。"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百八十",
            mNumberFirst: 1296, mNumberLast: 1299,
            knivesCount: 4, entropyClassesCount: 4,
            pinsCount: 12, futureCutsCount: 4,
            summary: "Phase C — ANE live binding default" +
                " flip + cache observation + 45×-gap" +
                " benchmark。 ADR-016 → M1299。"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百八十一",
            mNumberFirst: 1300, mNumberLast: 1303,
            knivesCount: 4, entropyClassesCount: 4,
            pinsCount: 10, futureCutsCount: 3,
            summary: "Phase D start — 1st BASResult +" +
                " 1st BASCard + 1st BASFrameEnvelope" +
                " adoptions。 4-of-5 primitives in" +
                " production。 ADR-016 → M1303。"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百八十二",
            mNumberFirst: 1304, mNumberLast: 1307,
            knivesCount: 4, entropyClassesCount: 4,
            pinsCount: 10, futureCutsCount: 3,
            summary: "5-of-5 primitive coverage" +
                " (1st BASPermit) + cross-turn KV" +
                " cache substrate surface。 ADR-016 → M1307。"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百八十三",
            mNumberFirst: 1308, mNumberLast: 1311,
            knivesCount: 4, entropyClassesCount: 4,
            pinsCount: 10, futureCutsCount: 3,
            summary: "9 batched typealias adoptions。" +
                " ADR-016 → M1311。"),
        BASEntropyChapterEntry(
            chapterTag: "chapter 四百八十四",
            mNumberFirst: 1312, mNumberLast: 1315,
            knivesCount: 4, entropyClassesCount: 4,
            pinsCount: 10, futureCutsCount: 3,
            summary: "22 cumulative adoptions + scoring" +
                " 28/60 → 41/60。 ADR-016 → M1315。")
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
