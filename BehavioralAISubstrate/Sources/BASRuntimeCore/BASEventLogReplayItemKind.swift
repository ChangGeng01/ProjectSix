// MARK: - BASEventLogReplayItemKind
// chapter 六百八十三 / M2110 第二刀 — typed enum unifying
//                                  the 8 event-payload kinds
//                                  carried by BASEventLogReplay
//                                  Bundle as an additive bridge
//                                  toward BASBundle pattern。
//
// ## Why typed enum + count projection
//
// BASEventLogReplayBundle (chapter 437 / M1085+) carries 8
// separately-typed event payload lists:
//
//   - memoryAtomEvents       (M941)
//   - turnLifecycleEvents    (M1085)
//   - parallelStageEvents    (M1085)
//   - permitEscalationEvents (M1086)
//   - nativeStageDispatchEvents (M1132)
//   - planAssignmentEvents   (M1140)
//   - nativeStagePerStepEvents (M1153)
//   - biomimeticCheckpointEvents (M1245)
//
// Full migration to BASBundle<Item> would require
// unifying these 8 distinct Codable types into one Item
// type (loses type info) OR forcing callers to access via
// type-erased Any (loses Sendable conformance)。
//
// The HONEST additive bridge at chapter 683 / M2110:
//
//   - NEW BASEventLogReplayItemKind enum naming the 8
//     kinds typedly (CaseIterable for iteration patterns)
//   - NEW BASEventLogReplayBundle.kindCounts() extension
//     returning a typed [BASEventLogReplayItemKind: Int]
//     dictionary callers can use to iterate kind counts
//     uniformly without depending on the 8 typed list
//     names directly
//
// Existing call sites continue to work unchanged。

import Foundation

/// Typed enum naming the 8 event-payload kinds carried
/// by `BASEventLogReplayBundle`。 `CaseIterable` so
/// callers can iterate over all kinds uniformly。
///
/// Each case maps to ONE of the typed lists on
/// `BASEventLogReplayBundle`。 Order matches the
/// chronological introduction in the substrate:
///
///   - chapter 402 / M941 — memoryAtom
///   - chapter 428 / M1085 — turnLifecycle + parallelStage
///   - chapter 428 / M1086 — permitEscalation
///   - chapter 439 / M1132 — nativeStageDispatch
///   - chapter 441 / M1140 — planAssignment
///   - chapter 444 / M1153 — nativeStagePerStep
///   - chapter 467 / M1245 — biomimeticCheckpoint
public enum BASEventLogReplayItemKind:
    String, Codable, Sendable, Equatable, Hashable,
    CaseIterable
{
    case memoryAtom = "memory-atom"
    case turnLifecycle = "turn-lifecycle"
    case parallelStage = "parallel-stage"
    case permitEscalation = "permit-escalation"
    case nativeStageDispatch = "native-stage-dispatch"
    case planAssignment = "plan-assignment"
    case nativeStagePerStep = "native-stage-per-step"
    case biomimeticCheckpoint = "biomimetic-checkpoint"

    /// The M-number at which this event kind was first
    /// introduced into the substrate。 Used by
    /// observability / audit tooling to trace event-kind
    /// provenance。
    public var introducedAtMNumber: Int {
        switch self {
        case .memoryAtom:            return 941
        case .turnLifecycle:         return 1085
        case .parallelStage:         return 1085
        case .permitEscalation:      return 1086
        case .nativeStageDispatch:   return 1132
        case .planAssignment:        return 1140
        case .nativeStagePerStep:    return 1153
        case .biomimeticCheckpoint:  return 1245
        }
    }

    /// The chapter at which this event kind was first
    /// introduced。
    public var introducedAtChapter: String {
        switch self {
        case .memoryAtom:           return "chapter 四百二"
        case .turnLifecycle,
             .parallelStage:        return "chapter 四百二十八"
        case .permitEscalation:     return "chapter 四百二十八"
        case .nativeStageDispatch:  return "chapter 四百三十九"
        case .planAssignment:       return "chapter 四百四十一"
        case .nativeStagePerStep:   return "chapter 四百四十四"
        case .biomimeticCheckpoint: return "chapter 四百六十七"
        }
    }
}

/// Total count of event-payload kinds the substrate's
/// event log carries today。 Mirrors BASSweepDoctrine
/// Expectations.eventPayloadKindCount (8 at chapter 467
/// close-out)。
public let basEventLogReplayItemKindCount: Int =
    BASEventLogReplayItemKind.allCases.count
