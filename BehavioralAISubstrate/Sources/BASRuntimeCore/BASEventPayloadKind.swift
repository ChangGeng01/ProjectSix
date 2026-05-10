// MARK: - BASEventPayloadKind — chapter 四百二十八 / M1084
// (extended chapters 439 + 441 + 444 to 7 kinds)
// 系统熵 reduction
//
// RADICAL EVOLUTION SWEEP Phase B entry。 Single typed
// discriminator naming the 7 payload kinds the unified
// event log carries (originally 4 at M1084; extended
// to 5 by chapter 439 M1132 nativeStageDispatch; to 6
// by chapter 441 M1140 planAssignment; to 7 by chapter
// 444 M1153 nativeStagePerStep)。 Cheap filter scan key
// for callers that need to pluck only-this-kind events
// out of the stream without decoding `payloadJson`。
//
// ## Why this exists (system entropy framing)
//
// Pre-M1084 the substrate had 4 fragmented audit
// channels:
//
//   1. M941 BASMemoryAtomEventPayload (memory mutations
//      via BASEventLog)
//   2. BASRuntimeAuditEmissionSummary (turn lifecycle
//      via BASTurnRuntimeAuditEnvelope JSON payload)
//   3. BASPermitEscalationLedger (5-step permit
//      escalation chain — held in TurnResult,not the
//      event log)
//   4. BASTurnRuntimeStageLedger + parallel-stage
//      observation (stage execution — held in TurnResult,
//      not the event log)
//
// Three of the four ledgers don't live in BASEventLog
// at all,which means downstream consumers (Phase E
// scheduler probe,future SSM training,causal graph
// extraction) have to consume from 4 different surfaces。
// `BASEventPayloadKind` is the typed naming that lets
// all 4 consolidate via the unified event log。
//
// ## What this ships (M1084)
//
//   - `BASEventPayloadKind` enum (4 cases) with String
//     rawvalues that match each payload's existing
//     action discriminator tag (chapter 八十七 raw value
//     stability):
//       * `.memoryAtom = "memory-atom-event"` — matches
//         M941 `BASMemoryAtomEventPayload` action tag
//       * `.turnLifecycle = "turn-lifecycle-event"` —
//         M1085 BASTurnLifecycleEventPayload
//       * `.permitEscalation = "permit-escalation-event"`
//         — M1086 BASPermitEscalationEventPayload
//       * `.parallelStage = "parallel-stage-event"` —
//         M1085 BASParallelStageEventPayload
//   - `BASEventLogEntry.payloadKind` accessor returning
//     `BASEventPayloadKind?` — reads the discriminator
//     from `actions` array,nil for entries without a
//     known payload kind
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (typed enum,
//     not raw String matching scattered across consumers)
//   - chapter 二百一一 — single source-of-truth (one
//     discriminator;all 7 payload kinds reference it
//     after chapters 439/441/444 extended from 4 → 7)
//   - chapter 三百九二 — replay-determinism (rawvalues
//     pinned;byte-stable across processes)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (additive enum + accessor;no existing call site
//     touched)
//   - 红线 7 — hint-only (event log is observation-only
//     audit plumbing)
//   - ADR-014 OPT-IN — purely additive

import Foundation

/// Typed discriminator naming the 7 payload kinds the
/// unified event log carries (originally 4 at chapter
/// 428 M1084;extended to 7 across chapters 439/441/444)。
/// Cheap filter scan key for callers that need to pluck
/// only-this-kind events without decoding `payloadJson`。
public enum BASEventPayloadKind:
    String, Codable, Equatable, Hashable, Sendable, CaseIterable
{

    /// M941 memory-atom mutation payload。 Raw value
    /// matches the existing
    /// `BASEventLogEntry.memoryAtomEventActionTag`
    /// constant for backward compatibility。
    case memoryAtom = "memory-atom-event"

    /// M1085 turn lifecycle payload (turn:start /
    /// turn:complete envelope summary)。 Replaces the
    /// untyped JSON shape inside
    /// `BASTurnRuntimeAuditEnvelope.payloadJson`。
    case turnLifecycle = "turn-lifecycle-event"

    /// M1086 permit escalation payload。 Encodes the
    /// 5-step BASPermitEscalationLedger summary as a
    /// typed event so downstream replay can rebuild the
    /// ledger from the event stream alone。
    case permitEscalation = "permit-escalation-event"

    /// M1085 parallel-stage dispatch payload。 Encodes
    /// the M1072 BASParallelStageDispatchExecutor's
    /// per-fan-out result summary so downstream replay
    /// can rebuild the stage ledger from events。
    case parallelStage = "parallel-stage-event"

    /// M1132 native-stage dispatch payload (chapter
    /// 四百三十九 — POST-RADICAL Wave 10)。 Encodes the
    /// chapter 436 BASNativeStageDispatchLedger as a
    /// typed event so the unified event log carries
    /// proof of which stages honored their scheduler
    /// assignment and which fell through to the
    /// fallback path。 Future replay can rebuild the
    /// dispatch ledger from event stream alone。
    case nativeStageDispatch =
        "native-stage-dispatch-event"

    /// M1140 plan-assignment payload (chapter 四百四十一
    /// — POST-RADICAL Wave 12)。 Encodes the chapter 435
    /// BASTurnRuntimePlanAssignmentLedger as a typed
    /// event so the unified event log carries proof of
    /// which stages were CONSULTED by the M1102
    /// BASHardwareAwareScheduler at probe time (the
    /// upstream surface;sibling to nativeStageDispatch
    /// which carries the downstream HONOR outcomes)。
    /// Future replay can rebuild the assignment ledger
    /// from event stream alone — full routed-dispatch
    /// surface (capture → honor) becomes event-replayable。
    case planAssignment = "plan-assignment-event"

    /// M1153 native-stage per-step payload (chapter
    /// 四百四十四 — POST-RADICAL Wave 15)。 Sibling of
    /// `nativeStageDispatch` (per-turn aggregate);
    /// `nativeStagePerStep` carries ONE stage step's
    /// dispatch outcome per event entry。 Enables
    /// fine-grained causal-graph extraction at the
    /// stage level without unbundling the per-turn
    /// payload。 OPT-IN — engine does not auto-emit
    /// per-step events;hosts opt in directly via
    /// `BASEventLogEntry.nativeStagePerStepEvent(...)`。
    case nativeStagePerStep =
        "native-stage-per-step-event"
}

// MARK: - BASEventLogEntry accessor

extension BASEventLogEntry {

    /// Returns the payload kind of this entry by reading
    /// the discriminator action tag from `actions`。
    /// Returns nil for entries that don't carry a typed
    /// payload (legacy / forward-compat events)。
    ///
    /// O(actions.count) scan — actions arrays are
    /// typically 1-3 entries so this is effectively O(1)。
    public var payloadKind: BASEventPayloadKind? {
        for action in actions {
            if let kind = BASEventPayloadKind(
                rawValue: action)
            {
                return kind
            }
        }
        return nil
    }

    /// Returns true if this entry carries the given
    /// payload kind discriminator。 Convenience for
    /// stream filtering。
    public func hasPayloadKind(
        _ kind: BASEventPayloadKind
    ) -> Bool {
        return actions.contains(kind.rawValue)
    }
}
