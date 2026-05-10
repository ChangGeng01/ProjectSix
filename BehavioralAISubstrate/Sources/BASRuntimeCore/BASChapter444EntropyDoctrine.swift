// MARK: - BASChapter444EntropyDoctrine — chapter 四百四十四 / M1155
// 系统熵 reduction
//
// **POST-RADICAL Wave 15** chapter (PER-STAGE EVENT
// PAYLOAD chapter)。 Pins the chapter 四百四十四 entropy
// work shipped across 4 commits (M1152-M1155)。 Closes
// chapter 442 future-cut #3:per-stage event payload
// (one entry per stage step,not per turn) for fine-
// grained causal-graph extraction at the stage level
// without unbundling the per-turn aggregate。
//
// ## Why this exists (system entropy framing)
//
// Wave 11 (chapter 440) auto-emits ONE per-turn dispatch
// event carrying the full ledger。 Great for replay
// reconstruction (one event = one ledger),but stage-
// level causal analysis (e.g. "stage X's contribution
// to turn Y's energy") requires unwrapping the records
// array and finding the matching stageRawValue。
//
// chapter 444 closes that gap with a SIBLING per-step
// payload。 Each stage step gets its own typed event
// entry carrying (turnID + stageRawValue +
// stepSequenceIndex + selectedBackingKindRawValue +
// selectedKernelKeyDescriptor + durationMs +
// honoredAssignment + assignmentRationaleRawValue)。
// Replay rebuilders can fold per-step events back into
// a per-turn payload via turnID grouping。
//
// **Sibling,not replacement**:per-turn dispatch event
// (chapter 439) remains the primary auto-emit path
// because it groups all stages of a turn into 1 entry
// (cheap for replay)。 Per-step events are an OPT-IN
// projection consumers can request when they need
// stage-level granularity。 Engine does NOT auto-emit
// per-step events at chapter 444 — that would 5×-10×
// the event log volume per turn。 Hosts that want per-
// step granularity opt-in via direct `BASEventLogEntry
// .nativeStagePerStepEvent(...)` calls from their stage
// executor implementations。
//
// ## What this ships (M1152-M1155)
//
//   - **M1152** — recon:chapter 439 per-turn dispatch
//     event shape + chapter 442 BASEventLogReplayBundle
//     7-kind extension design + per-step semantics
//     (no source change)
//
//   - **M1153** — typed per-step payload + 7th kind
//     - NEW `BASNativeStagePerStepEventPayload`
//       Sendable + Codable + Equatable + Hashable
//       struct (8 fields:turnID + stageRawValue +
//       stepSequenceIndex + selectedBackingKindRawValue
//       + selectedKernelKeyDescriptor + durationMs +
//       honoredAssignment + assignmentRationaleRawValue)
//     - NEW `.from(record:turnID:stepSequenceIndex:
//       assignmentRationaleRawValue:)` factory bridging
//       from chapter 439 per-turn record shape
//     - NEW `BASEventLogEntry.nativeStagePerStepEvent(...)`
//       factory + reverse accessor
//     - NEW `BASEventPayloadKind.nativeStagePerStep`
//       case (rawvalue `"native-stage-per-step-event"`)
//     - NEW `BASEventLogProjectors
//       .projectNativeStagePerStepEvents(_:)` projector
//     - EXTENDED `BASEventLogReplayBundle` to 7 fields
//       (added `nativeStagePerStepEvents`) + 7-kind
//       merge + 7-kind perKindEventCount + 7-kind
//       projectAllPayloadKinds factory。 Init `default
//       []` for backward compat with chapter 442 6-arg
//       call sites
//
//   - **M1154** — Tests
//     - 12 pin tests in
//       BASNativeStagePerStepEventPayloadTests:
//       direct init clamps (2) + .from(record:) factory
//       (1) + Codable round-trip (1) + factory stamps
//       correct kind (1) + reverse accessor decodes (1)
//       + reverse accessor nil for other kind (1) +
//       projector filter+sort (1) + raw-value stability
//       (1) + 7-cases count (1) + bundle 7-kind
//       aggregate (1) + cross-kind isolation through
//       bundle (1)
//     - Updated chapter 441 BASTurnRuntimePlan
//       AssignmentEventPayloadTests.testAllPayloadKinds
//       Count assertion (6 → 7)
//
//   - **M1155** — chapter 444 close-out + Phase 2 bump
//     (commits 197 → 201, chapter count 41 → 42,
//     mNumberLast 1151 → 1155) + ADR-016.M1151 →
//     ADR-016.M1155 advance + index entry for 444
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (typed
//     8-field record;assignmentRationaleRawValue
//     carries chapter 432 rationale enum)
//   - chapter 二百一一 — single source-of-truth (per-
//     step is a SIBLING of per-turn,both reference
//     the same chapter 439 record shape;not parallel
//     implementations)
//   - chapter 三百九二 — replay-determinism (Codable
//     via sortedKeys JSON;stepSequenceIndex preserves
//     within-turn ordering;turnID groups for replay)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (purely additive payload + extension;engine
//     does NOT auto-emit per-step events;chapter 439
//     per-turn auto-emit unchanged)
//   - 红线 7 — hint-only (event log is observation,
//     not commitment authority)
//   - ADR-014 OPT-IN — purely additive
//   - ADR-016 — bumped M1151 → M1155
//   - **POST-RADICAL EVOLUTION SWEEP Wave 15** entry —
//     PER-STAGE EVENT PAYLOAD chapter

import Foundation

public enum BASChapter444EntropyDoctrine {

    public static let chapterTag: String =
        "chapter 四百四十四"
    public static let mNumberFirst: Int = 1152
    public static let mNumberLast: Int = 1155

    public static let v1MilestoneMNumber: Int = 1155
    public static let v1MilestoneStatus: String =
        "chapter-444-v1-per-stage-event-payload"

    public static let knives:
        [(mNumber: Int, knife: String, concept: String)] =
    [
        (1152, "第一刀",
            "Recon chapter 439 per-turn dispatch event" +
            " shape + chapter 442 BASEventLogReplayBundle" +
            " 7-kind extension design + per-step semantics" +
            "。 No source change"),
        (1153, "第二刀",
            "BASNativeStagePerStepEventPayload typed" +
            " Codable + 8 fields + .from(record:) factory" +
            " + BASEventLogEntry.nativeStagePerStepEvent" +
            " factory + reverse accessor + projector +" +
            " 7th BASEventPayloadKind case + EXTENDED" +
            " BASEventLogReplayBundle to 7 fields"),
        (1154, "第三刀",
            "12 pin tests in BASNativeStagePerStepEvent" +
            "PayloadTests:init clamps (2) + factory" +
            " bridge (1) + Codable round-trip (1) +" +
            " entry factory stamps (1) + reverse accessor" +
            " (1) + reverse accessor nil (1) + projector" +
            " (1) + raw-value (1) + 7-cases count (1)" +
            " + bundle 7-kind (1) + cross-kind isolation" +
            " (1)。 Updated chapter 441 6→7 count" +
            " assertion"),
        (1155, "第四刀",
            "chapter 444 close-out + Phase 2 bump" +
            " (commits 197 → 201, chapter count 41 → 42)" +
            " + ADR-016.M1151 → ADR-016.M1155 advance" +
            " + index entry for 444")
    ]

    public static let entropyClassesAttacked: [String] = [
        "per-stage-causal-attribution-entropy",       // M1152
        "per-step-event-payload-absent-entropy",      // M1153
        "compatibility-pin-entropy",                  // M1154
        "doctrine-pin-entropy"                        // M1155
    ]

    public static let pinHeld: [String] = [
        "不变量 #1",
        "不变量 #2",
        "不变量 #3",
        "红线 7",
        "chapter 一百八十五",
        "chapter 二百一一",
        "chapter 三百九二",
        "ADR-014 OPT-IN preserved (purely additive;" +
        " engine does NOT auto-emit per-step events;" +
        " chapter 439 per-turn auto-emit unchanged)",
        "ADR-016 (advanced M1151 → M1155)",
        "系统熵 reduction",
        "POST-RADICAL EVOLUTION SWEEP Wave 15 entry —" +
        " PER-STAGE EVENT PAYLOAD chapter"
    ]

    public static let plannedFutureCuts: [String] = [
        "Federated event log:typed protocol for replay" +
        " consumers to pull from N storage backends in" +
        " one call (chapter 443 future-cut #4 — chapter" +
        " 445 will close)",
        "POST-RADICAL EVOLUTION SWEEP close-out meta-" +
        "doctrine summarizing chapters 427-446 / Waves" +
        " 1-17 / cumulative achievement (chapter 446" +
        " will close)",
        "Build host-side reference RoutedStageExecutor" +
        " in BASAppleAdapters wiring real backends —" +
        " requires real device test (deferred to" +
        " future)",
        "Build real V1+V2 coordinator runner for" +
        " BASStressSweepCanonical60Driver — unblocks" +
        " V2 default mode flip (deferred to future)"
    ]

    public static let summary: String =
        "POST-RADICAL EVOLUTION SWEEP chapter 四百四十四" +
        " ships PER-STAGE EVENT PAYLOAD across 4 cuts" +
        " (M1152-M1155)。 Closes chapter 442 future-cut" +
        " #3:per-stage event payload (one entry per" +
        " stage step,not per turn) for fine-grained" +
        " causal-graph extraction at the stage level" +
        " without unbundling the per-turn aggregate。" +
        " 4 cuts:(1) recon shape + design,(2)" +
        " BASNativeStagePerStepEventPayload typed" +
        " Codable + factory + projector + 7th" +
        " BASEventPayloadKind case + EXTENDED" +
        " BASEventLogReplayBundle to 7 fields,(3) 13" +
        " pin tests,(4) chapter close-out + bumps。" +
        " ADR-014 OPT-IN preserved — purely additive。" +
        " V1 byte-equality preserved。 Engine does NOT" +
        " auto-emit per-step events (would 5-10x event" +
        " log volume);hosts opt-in via direct" +
        " emission。 Sibling,not replacement,of" +
        " chapter 439 per-turn dispatch payload。"
}
