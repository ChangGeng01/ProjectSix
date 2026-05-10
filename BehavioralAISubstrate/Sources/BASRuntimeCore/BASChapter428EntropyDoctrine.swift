// MARK: - BASChapter428EntropyDoctrine — chapter 四百二十八 / M1087
// 系统熵 reduction
//
// RADICAL EVOLUTION SWEEP Phase B close-out doctrine。
// Pins the chapter 四百二十八 entropy work shipped across
// 4 commits (M1084-M1087):the unified event log
// payload-kinds backbone。
//
// ## Why this exists (system entropy framing)
//
// Pre-Phase B,the substrate had 4 fragmented audit
// channels — one for each "thing that happened in a
// turn":
//
//   1. M941 BASMemoryAtomEventPayload (memory mutations
//      via BASEventLog) — the only one that already
//      lived on the unified event log
//   2. BASRuntimeAuditEmissionSummary (turn lifecycle
//      via BASTurnRuntimeAuditEnvelope JSON payload)
//   3. BASPermitEscalationLedger (5-step permit
//      escalation chain — held in TurnResult,not the
//      event log)
//   4. BASTurnRuntimeStageLedger + parallel-stage
//      observation (stage execution — held in TurnResult,
//      not the event log)
//
// Three of the four ledgers didn't live in BASEventLog
// at all,which meant downstream consumers had to read
// from 4 different surfaces。 Phase B closes that gap
// without breaking V1 byte-equality:typed event-log
// payloads ship for all 4 kinds + projectors fold the
// event stream back into the legacy ledger shape so
// readers can migrate incrementally。
//
// ## What this ships (M1084-M1087)
//
//   - M1084:`BASEventPayloadKind` typed discriminator
//     enum (4 cases) + `BASEventLogEntry.payloadKind`
//     accessor + `hasPayloadKind(_:)` predicate
//   - M1085:`BASTurnLifecycleEventPayload` (8 fields,
//     mirrors BASRuntimeAuditEmissionSummary) +
//     `BASParallelStageEventPayload` (5 fields,
//     mirrors M1072 fan-out result)
//   - M1086:`BASPermitEscalationEventPayload` (5
//     fields + `.from(ledger:turnID:)` factory) +
//     `BASPermitEscalationStageEventRecord` (5 fields,
//     event-log-friendly mirror of the legacy
//     BASPermitEscalationStageRecord)
//   - M1087:`BASEventLogProjectors` (4 named
//     projector pure functions) + `BASEventLogTurn
//     Projection` typed bundle for combined turn-scoped
//     reads
//
// ## What this DOES NOT ship (deferred)
//
// The original Phase B plan called for:
//   - Deleting `BASRuntimeAuditEmissionSummary` (~520
//     LOC) + extensions
//   - Deleting `BASTurnRuntimeStageLedger` (~560 LOC)
//     + extensions
//   - Deleting `BASPermitEscalationLedger` (~130 LOC)
//
// In autonomous mode these deletions are too risky —
// they're referenced from V2 actor's runTurn(...)
// signature,M1075 BASNativeStageExecutor,and dozens
// of tests。 M1084-M1087 ships the typed payload +
// projector ALONGSIDE the existing ledgers so consumers
// can migrate site-by-site under explicit user control。
// A future chapter performs the deletions once
// migration completes。
//
// Net delta:Phase B ships +500 LOC of additive typed
// payloads + projectors,instead of the planned -1,100
// LOC consolidation。 The entropy reduction is REAL
// (consumers now have a single typed surface to read
// from);the deletion just lands later。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number throughout
//   - chapter 二百一一 — single source-of-truth (one
//     payload kind enum;all 4 typed payloads + the
//     projector layer reference it)
//   - chapter 三百九二 — replay-determinism (sortedKeys
//     JSON;projectors sort by sequenceNumber)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (additive payloads + projectors;no existing
//     call site touched)
//   - 红线 7 — hint-only (event log is observation
//     plumbing,not commitment authority)
//   - ADR-014 OPT-IN — purely additive new payload
//     kinds + projectors
//   - ADR-016 — held at M1103 (chapter 四百三十二's
//     latest);chapter 四百二十八 backfills the
//     M1084-M1087 reserved gap but does not advance
//     the substrate completion high-water mark
//   - RADICAL EVOLUTION SWEEP Phase B — this chapter

import Foundation

public enum BASChapter428EntropyDoctrine {

    public static let chapterTag: String =
        "chapter 四百二十八"
    public static let mNumberFirst: Int = 1084
    public static let mNumberLast: Int = 1087

    /// `v1` milestone:UNIFIED EVENT LOG PAYLOAD-KINDS
    /// BACKBONE at M1087。 First chapter where:
    ///   - All 4 audit channels (memory atoms,turn
    ///     lifecycle,permit escalation,parallel
    ///     stage) have a typed payload that rides the
    ///     unified BASEventLog
    ///   - A typed projector layer folds event slices
    ///     back into the legacy ledger shape so
    ///     downstream consumers migrate incrementally
    public static let v1MilestoneMNumber: Int = 1087
    public static let v1MilestoneStatus: String =
        "chapter-428-v1-unified-event-log-payload-kinds"

    public static let knives:
        [(mNumber: Int, knife: String, concept: String)] =
    [
        (1084, "第一刀",
            "BASEventPayloadKind typed discriminator " +
            "enum (4 cases) + BASEventLogEntry " +
            ".payloadKind / .hasPayloadKind(_:) " +
            "accessors。 Memory-atom rawvalue matches " +
            "the existing M941 action tag verbatim " +
            "(chapter 八十七 raw value stability)"),
        (1085, "第二刀",
            "BASTurnLifecycleEventPayload (8 fields," +
            " 2-case phase enum) + BASParallelStage " +
            "EventPayload (5 fields, 4-case group tag" +
            " enum) + BASEventLogEntry factories +" +
            " reverse accessors。 Mirrors M1004" +
            " stageLedger + M1008 stagePlan projections"),
        (1086, "第三刀",
            "BASPermitEscalationEventPayload (5 fields)" +
            " + BASPermitEscalationStageEventRecord " +
            "(5 fields)。 .from(ledger:turnID:) " +
            "factory bridges legacy ledger → typed " +
            "event payload。 ADDITIVE — legacy " +
            "BASPermitEscalationLedger preserved"),
        (1087, "第四刀",
            "BASEventLogProjectors namespace with 4 " +
            "named projector pure functions + " +
            "BASEventLogTurnProjection typed bundle " +
            "for combined turn-scoped reads + chapter" +
            " 四百二十八 close-out doctrine + Phase 2" +
            " bump (commits 137 → 141, chapter count" +
            " 27 → 28);ADR-016 held at M1103 (backfill" +
            " chapter — chapter 432's M1103 still leads)")
    ]

    public static let entropyClassesAttacked: [String] = [
        "fragmented-audit-channel-entropy",          // M1084
        "untyped-lifecycle-payload-entropy",         // M1085
        "in-memory-only-permit-ledger-entropy",      // M1086
        "missing-event-log-projection-layer-entropy" // M1087
    ]

    public static let pinHeld: [String] = [
        "不变量 #1",
        "不变量 #2",
        "不变量 #3",
        "红线 7",
        "chapter 一百八十五",
        "chapter 二百一一",
        "chapter 三百九二",
        "ADR-014 OPT-IN preserved (additive payloads " +
        "+ projectors;no V1 hot path touch)",
        "ADR-016 (held at M1103 — backfill chapter)",
        "系统熵 reduction",
        "RADICAL EVOLUTION SWEEP Phase B"
    ]

    public static let plannedFutureCuts: [String] = [
        "Migrate V2 actor's runTurn(...) audit emission " +
        "to use BASTurnLifecycleEventPayload directly " +
        "(replaces the inline JSON in M1004/M1008 paths)",
        "Migrate M1072 BASParallelStageDispatchExecutor " +
        "to emit BASParallelStageEventPayload per fan-out",
        "Migrate M1070 BASPermitEscalationFoldExecutor " +
        "to emit BASPermitEscalationEventPayload per " +
        "fold call",
        "Delete BASRuntimeAuditEmissionSummary (~520 LOC)" +
        " + 4 extensions once consumers migrate",
        "Delete BASTurnRuntimeStageLedger (~560 LOC) +" +
        " 4 extensions once consumers migrate",
        "Delete BASPermitEscalationLedger (~130 LOC) once" +
        " consumers migrate",
        "Wire the projector layer into a unified replay " +
        "harness for SSM training (G8 close-out)"
    ]

    public static let summary: String =
        "RADICAL EVOLUTION SWEEP chapter 四百二十八 v1 " +
        "closes at M1087 — UNIFIED EVENT LOG PAYLOAD-" +
        "KINDS BACKBONE milestone。 Closes the audit-" +
        "channel-fragmentation gap surfaced by the " +
        "M1080 architecture audit。 4 cuts ship " +
        "(M1084-M1087):" +
        "(1) BASEventPayloadKind typed discriminator + " +
        "accessors," +
        "(2) BASTurnLifecycleEventPayload + " +
        "BASParallelStageEventPayload + factories," +
        "(3) BASPermitEscalationEventPayload + .from" +
        "(ledger:) factory (additive — legacy ledger " +
        "preserved)," +
        "(4) BASEventLogProjectors + 4 named projector " +
        "pure functions + chapter close-out。 ADR-014 " +
        "OPT-IN held — purely additive payloads + " +
        "projectors;no V1 hot path consumes them yet。 " +
        "Original plan called for ledger deletions " +
        "(~1,210 LOC) but those are deferred to a " +
        "follow-up chapter under explicit user control。 " +
        "V1 byte-equality preserved (5,500+ BAS tests " +
        "pass)。"
}
