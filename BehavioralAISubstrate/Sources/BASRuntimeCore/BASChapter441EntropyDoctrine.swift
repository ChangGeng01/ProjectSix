// MARK: - BASChapter441EntropyDoctrine — chapter 四百四十一 / M1143
// 系统熵 reduction
//
// **POST-RADICAL Wave 12** chapter (PLAN-ASSIGNMENT
// EVENT TYPE chapter)。 Pins the chapter 四百四十一
// entropy work shipped across 4 commits (M1140-M1143)。
// Closes the OTHER half of the routed-dispatch replay
// surface:scheduler decisions CAPTURED at probe time
// now flow through the unified event log automatically,
// sibling to chapter 440's downstream dispatch HONOR
// outcomes。
//
// ## Why this exists (system entropy framing)
//
// chapter 440 closed dispatch auto-emit (decisions
// HONORED at executor flow through event log
// automatically)。 But the upstream evidence — the
// scheduler's CAPTURED decisions inside
// `BASTurnRuntimePlanAssignmentLedger` — still lived
// ONLY in `BASTurnRuntimeEngine.lastAssignmentLedger`
// actor-isolated state。 Future replay (G8 SSM training,
// causal graph extraction,distributed audit) could
// reconstruct dispatch HONORS from the event stream but
// not the upstream scheduler decisions that drove them。
//
// chapter 441 closes that gap:
// `BASTurnRuntimeEngine.runWithPlan(...)` now ALSO
// auto-emits a typed `BASTurnRuntimePlanAssignmentEvent
// Payload` after the dispatch event,gated by 2
// conditions:
//   1. `eventLog != nil`
//   2. `lastAssignmentLedger.recordCount > 0`
//
// Result:hosts get FULL routed-dispatch replay surface
// (capture → honor) for free。 6 typed payload kinds now
// flow through the unified event log;the entire scheduler
// + dispatch story is event-replayable from a single
// canonical stream。
//
// ## What this ships (M1140-M1143)
//
//   - **M1140** — typed payload + factory + projector
//     - NEW `BASTurnRuntimePlanAssignmentEventRecord`
//       Sendable + Codable + Equatable + Hashable
//       (7 fields:stageRawValue + hintOperationRawValue
//       + hintBatchSize + hintSequenceLength +
//       selectedBackingKindRawValue +
//       selectedKernelKeyDescriptor + sequenceIndex)
//     - NEW `BASTurnRuntimePlanAssignmentEventPayload`
//       Sendable + Codable + Equatable + Hashable
//       (5 fields:turnID + records + recordCount +
//       acceleratedRecordCount + uniqueStageCount)
//     - NEW `.from(ledger:)` factory
//     - NEW `BASEventLogEntry.planAssignmentEvent(...)`
//       factory + reverse accessor
//     - NEW `BASEventLogProjectors
//       .projectPlanAssignmentEvents(_:)` projector
//     - NEW `BASEventPayloadKind.planAssignment` case
//       with rawvalue `"plan-assignment-event"`
//
//   - **M1141** — engine auto-emit wiring
//     - NEW `lastEmittedPlanAssignmentEventID: String?`
//       actor-isolated field
//     - NEW `lastEmittedPlanAssignmentEventIDValue()`
//       async accessor for tests + audit
//     - NEW `emitPlanAssignmentEventIfNeeded(...)`
//       private async helper:
//       * guards on `eventLog != nil`
//       * guards on `lastAssignmentLedger.recordCount > 0`
//       * builds payload via `.from(ledger:)`
//       * appends via `eventLog.append(_:)` (try? per 红线 7)
//       * stores eventID in
//         `lastEmittedPlanAssignmentEventID`
//     - `runWithPlan(...)` calls helper AFTER dispatch
//       auto-emit so plan-assignment event lands
//       chronologically AFTER dispatch event (capture
//       → honor temporal order preserved on the stream)
//
//   - **M1142** — Tests
//     - 12 payload pin tests (factory empty/populated +
//       Codable round-trip + factory stamps correct
//       kind + reverse accessor + projector
//       filter+sort + foreign-kind filter + raw-value
//       stability + 6-cases count + determinism)
//     - 4 engine accessor pin tests (signature compile
//       pin + guard skip empty + guard emit populated
//       + storage append compile pin)
//     - Full integration test deferred to host-side
//       (requires 10-service coordinator stub harness,
//       same as chapters 437-440)
//
//   - **M1143** — chapter 441 close-out + Phase 2 bump
//     (commits 185 → 189, chapter count 38 → 39,
//     mNumberLast 1139 → 1143) + ADR-016.M1139 →
//     ADR-016.M1143 advance + 6th payload kind in
//     unified event log
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (typed
//     7-field record + 5-field payload;no untyped JSON
//     blobs;all enum rawvalues stable per chapter 八十七)
//   - chapter 二百一一 — single source-of-truth (one
//     payload shape;tests + audit + future replay
//     rebuilders all consume the same shape;auto-emit
//     path co-located with dispatch auto-emit)
//   - chapter 三百九二 — replay-determinism (Codable
//     via sortedKeys JSON;sequenceIndex preserves
//     ordering;chronological order plan-assignment
//     event AFTER dispatch event AFTER lifecycle
//     envelopes)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (gates skip emission when conditions don't hold;
//     V1 fallback path untouched)
//   - 红线 7 — hint-only (storage errors swallowed via
//     try?;runtime correctness independent of emission
//     success)
//   - ADR-014 OPT-IN — purely additive
//   - ADR-016 — bumped M1139 → M1143
//   - **POST-RADICAL EVOLUTION SWEEP Wave 12** entry —
//     PLAN-ASSIGNMENT EVENT TYPE chapter
//
// ## Significance — full routed-dispatch replay surface
//
// Before chapter 441:event log carried 5 typed payload
// kinds (memoryAtom / turnLifecycle / permitEscalation
// / parallelStage / nativeStageDispatch)。 Replay could
// rebuild the dispatch ledger but not the upstream
// scheduler decisions that drove it。
//
// After chapter 441:event log carries 6 typed payload
// kinds。 Replay can rebuild BOTH the captured
// scheduler decisions AND the honored dispatch
// outcomes from a SINGLE event stream。 The full
// routed-dispatch story is now event-replayable end-
// to-end:hint → assignment (CAPTURED) → execution
// (HONORED)。
//
// **Substrate-side replay surface is now COMPLETE**:
//   - 5 in-memory ledgers (memory atoms, lifecycle,
//     permit escalation, parallel stage, native
//     dispatch, plan assignment)
//   - 6 typed event payloads on the unified log
//   - 6 projectors that rebuild ledgers from event
//     stream alone
//   - All emission automatic — hosts only wire the
//     event log

import Foundation

public enum BASChapter441EntropyDoctrine {

    public static let chapterTag: String =
        "chapter 四百四十一"
    public static let mNumberFirst: Int = 1140
    public static let mNumberLast: Int = 1143

    /// `v1` milestone:PLAN-ASSIGNMENT EVENT TYPE at
    /// M1143。 First chapter where the unified event
    /// log carries 6 typed payload kinds — the full
    /// routed-dispatch surface (capture → honor) is
    /// now event-replayable end-to-end。
    public static let v1MilestoneMNumber: Int = 1143
    public static let v1MilestoneStatus: String =
        "chapter-441-v1-plan-assignment-event-type"

    public static let knives:
        [(mNumber: Int, knife: String, concept: String)] =
    [
        (1140, "第一刀",
            "BASTurnRuntimePlanAssignmentEventPayload" +
            " typed Codable payload + 7-field record" +
            " mirror + .from(ledger:) factory +" +
            " BASEventLogEntry.planAssignmentEvent(...)" +
            " factory + reverse accessor + projector +" +
            " new BASEventPayloadKind.planAssignment" +
            " case (rawvalue \"plan-assignment-event\")"),
        (1141, "第二刀",
            "BASTurnRuntimeEngine wiring:" +
            " lastEmittedPlanAssignmentEventID actor" +
            " field + lastEmittedPlanAssignmentEventID" +
            "Value() accessor + emitPlanAssignmentEventIf" +
            "Needed(...) helper。 runWithPlan(...) calls" +
            " helper AFTER dispatch auto-emit so plan-" +
            "assignment event lands chronologically" +
            " after dispatch event (capture → honor" +
            " temporal order preserved)"),
        (1142, "第三刀",
            "Tests:12 payload pin tests + 4 engine" +
            " accessor pin tests = 16 new tests。" +
            " Covers factory empty + populated +" +
            " Codable round-trip + factory stamps +" +
            " reverse accessor + projector filter+sort" +
            " + foreign-kind filter + raw-value" +
            " stability + 6-cases count + determinism" +
            " + accessor signature + guard skip empty" +
            " + guard emit populated + storage append" +
            " compile pin"),
        (1143, "第四刀",
            "chapter 441 close-out + Phase 2 bump" +
            " (commits 185 → 189, chapter count 38 → 39)" +
            " + ADR-016.M1139 → ADR-016.M1143 advance" +
            " + index entry for 441")
    ]

    public static let entropyClassesAttacked: [String] = [
        "scheduler-decisions-not-on-stream-entropy", // M1140
        "engine-no-plan-assignment-emit-entropy",    // M1141
        "compatibility-pin-entropy",                 // M1142
        "doctrine-pin-entropy"                       // M1143
    ]

    public static let pinHeld: [String] = [
        "不变量 #1",
        "不变量 #2",
        "不变量 #3",
        "红线 7",
        "chapter 一百八十五",
        "chapter 二百一一",
        "chapter 三百九二",
        "ADR-014 OPT-IN preserved (gates skip emission" +
        " when eventLog nil OR recordCount 0;V1" +
        " fallback unchanged)",
        "ADR-016 (advanced M1139 → M1143)",
        "系统熵 reduction",
        "POST-RADICAL EVOLUTION SWEEP Wave 12 entry —" +
        " PLAN-ASSIGNMENT EVENT TYPE chapter"
    ]

    public static let plannedFutureCuts: [String] = [
        "Replay-rebuild integration test:write a" +
        " sequence of mixed-kind events to a" +
        " BASInMemoryEventLogStorage, then reconstruct" +
        " all 6 typed ledgers via projectors and" +
        " verify byte-equal to source — proves" +
        " end-to-end replay determinism for the full" +
        " 6-kind unified event log",
        "Build host-side reference RoutedStageExecutor" +
        " in BASAppleAdapters wiring mlxArray →" +
        " BASMLXAdapter,mlMultiArray → CoreML," +
        " metalBuffer → BASMetalKernelRegistry —" +
        " substrate-side autonomy was already complete" +
        " at chapter 440;chapter 441 makes the" +
        " replay surface complete too",
        "Build real V1+V2 coordinator runner for" +
        " BASStressSweepCanonical60Driver — unblocks" +
        " V2 default mode flip with byte-equality" +
        " evidence across canonical60 fixture set",
        "Per-stage event payload (one entry per stage" +
        " step,not one per turn) so causal graph" +
        " extraction can attribute stage-level" +
        " entropy reduction without bundle decoding"
    ]

    public static let summary: String =
        "POST-RADICAL EVOLUTION SWEEP chapter 四百四十一" +
        " ships PLAN-ASSIGNMENT EVENT TYPE across 4 cuts" +
        " (M1140-M1143)。 Closes the upstream half of" +
        " the routed-dispatch replay surface (the" +
        " downstream dispatch HONOR half landed in" +
        " chapter 440):scheduler decisions CAPTURED at" +
        " probe time now flow through the unified event" +
        " log automatically。 4 cuts:(1) typed payload" +
        " + factory + projector + 6th BASEventPayloadKind" +
        " case,(2) engine wiring with 2 guards + try?" +
        " error swallowing,(3) 16 pin tests,(4) chapter" +
        " close-out + bumps。 ADR-014 OPT-IN preserved" +
        " — gates skip emission when conditions don't" +
        " hold。 V1 byte-equality preserved。 First" +
        " chapter where the substrate's replay surface" +
        " is COMPLETE — 6 typed payload kinds carry" +
        " the FULL routed-dispatch story (capture → honor)" +
        " through ONE canonical event log。"
}
