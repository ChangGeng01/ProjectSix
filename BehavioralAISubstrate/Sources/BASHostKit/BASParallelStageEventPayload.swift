// MARK: - BASParallelStageEventPayload — chapter 四百二十八 / M1085
// 系统熵 reduction
//
// RADICAL EVOLUTION SWEEP Phase B 第二刀 part 2。 Typed
// Codable payload that encodes a single
// `BASParallelStageDispatchExecutor` (M1072) fan-out
// into a `BASEventLogEntry`,so downstream replay can
// rebuild the parallel-stage observation set from the
// event stream alone。
//
// ## Why this exists (system entropy framing)
//
// Pre-M1085 the M1072 parallel-stage executor's per-call
// result lived only in the in-memory return value of
// `dispatchTwoWayFanOut(...)` /
// `dispatchFourWayFanOut(...)`。 No persistent log of
// "which fan-out fired,which member stages observed
// outputs,what total wall-clock time elapsed"。 The
// future SSM training pipeline (G8) + causal graph
// extraction (G9) cannot replay parallel-stage decisions
// because they aren't recorded。
//
// `BASParallelStageEventPayload` is the typed payload
// the M1072 executor SHOULD emit per fan-out。 At M1085
// the type ships;the actual emission wiring on
// BASParallelStageDispatchExecutor is deferred to a
// follow-up commit (executor lives in BASRuntimeCore
// which doesn't import BASEventLog;the wiring needs
// a thin caller-side bridge)。
//
// ## What this ships (M1085 part 2)
//
//   - `BASParallelStageGroupTag` enum (4 cases:
//     entryAA2 / dD2 / m1FourWay / generic) naming
//     which parallel-group fan-out fired
//   - `BASParallelStageEventPayload` Sendable + Codable
//     + Equatable + Hashable struct (5 fields)
//   - `BASEventLogEntry` extension factory
//     `parallelStageEvent(...)` + reverse accessor
//     `parallelStageEventPayload`
//   - Discriminator action tag matches
//     `BASEventPayloadKind.parallelStage.rawValue`
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (typed
//     group tag + named fields)
//   - chapter 二百一一 — single source-of-truth (one
//     payload shape for all parallel-group emissions)
//   - chapter 三百九二 — replay-determinism (Codable
//     via sortedKeys JSON;executionNanos field allows
//     precise wall-clock replay)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (additive payload + extension)
//   - 红线 7 — hint-only
//   - ADR-014 OPT-IN — purely additive

import Foundation
import BASRuntimeCore

// MARK: - Group tag enum

/// Typed enum naming which parallel-group fan-out
/// produced this event。 Matches the M1072
/// `BASParallelStageDispatchExecutor`'s 3 named
/// fan-outs + a generic catch-all。
public enum BASParallelStageGroupTag:
    String, Codable, Equatable, Hashable, Sendable, CaseIterable
{
    /// chapter 二百八十九 entry attractor 2-way fan-out
    /// (entryAA1 + entryAA2)。
    case entryAA2 = "entry-aa-2"

    /// chapter 三百二十三 D2 2-way fan-out (dD1 + dD2)。
    case dD2 = "d-d-2"

    /// chapter 三百九十一 M1 4-way fan-out (stageM1 +
    /// stageM1A + stageM1B + stageM1C)。
    case m1FourWay = "m1-four-way"

    /// Generic catch-all for future fan-out registrations
    /// that don't yet have a named tag。
    case generic = "generic"
}

// MARK: - Payload struct

/// Typed Codable payload encoded inside
/// `BASEventLogEntry.payloadJson` when the entry
/// represents a parallel-stage fan-out result。
public struct BASParallelStageEventPayload:
    Codable, Equatable, Sendable, Hashable
{

    /// Which named fan-out this entry observed。
    public let groupTag: BASParallelStageGroupTag

    /// Turn ID this entry binds to。
    public let turnID: String

    /// Number of member stages inside the fan-out (e.g.
    /// 2 for entryAA2/dD2,4 for m1FourWay)。
    public let memberStageCount: Int

    /// Number of member-stage outputs observed (typically
    /// matches `memberStageCount` on success;differs
    /// when individual member stages report no-output
    /// per the M1072 protocol)。
    public let observedOutputCount: Int

    /// Wall-clock execution time for the fan-out in
    /// nanoseconds。 Mirrors the M1098 kernel
    /// `BASKernelOutputs.executionNanos` shape so the
    /// future hardware-aware scheduler can correlate
    /// kernel timing with parallel-group timing。
    public let executionNanos: UInt64

    public init(
        groupTag: BASParallelStageGroupTag,
        turnID: String,
        memberStageCount: Int,
        observedOutputCount: Int,
        executionNanos: UInt64
    ) {
        self.groupTag = groupTag
        self.turnID = turnID
        self.memberStageCount = memberStageCount
        self.observedOutputCount = observedOutputCount
        self.executionNanos = executionNanos
    }
}

// MARK: - BASEventLogEntry extension

extension BASEventLogEntry {

    /// Build a `BASEventLogEntry` carrying a parallel-
    /// stage fan-out payload。
    public static func parallelStageEvent(
        eventID: String,
        timestampMs: Int64,
        sessionID: String,
        sequenceNumber: Int64 = 0,
        payload: BASParallelStageEventPayload,
        source: String? = "parallel-stage-dispatch-executor"
    ) -> BASEventLogEntry {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json: String?
        if let data = try? encoder.encode(payload) {
            json = String(data: data, encoding: .utf8)
        } else {
            json = nil
        }
        return BASEventLogEntry(
            eventID: eventID,
            timestampMs: timestampMs,
            kind: .substrateAudit,
            sessionID: sessionID,
            sequenceNumber: sequenceNumber,
            source: source,
            turnRef: payload.turnID,
            rawInputDigest: nil,
            intent: nil,
            emotion: nil,
            riskBand: .unknown,
            project: nil,
            memoryRefs: [],
            stateBeforeID: nil,
            stateAfterID: nil,
            actions: [
                BASEventPayloadKind
                    .parallelStage.rawValue
            ],
            confidence: 0,
            payloadJson: json)
    }

    /// Decode the `BASParallelStageEventPayload` if this
    /// entry is a parallel-stage event。
    public var parallelStageEventPayload:
        BASParallelStageEventPayload?
    {
        guard hasPayloadKind(.parallelStage) else {
            return nil
        }
        guard let json = payloadJson,
              let data = json.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(
            BASParallelStageEventPayload.self,
            from: data)
    }
}
