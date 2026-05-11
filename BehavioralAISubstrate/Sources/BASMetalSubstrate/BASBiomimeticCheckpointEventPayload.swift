// MARK: - BASBiomimeticCheckpointEventPayload — chapter 四百六十七 / M1245
// 系统熵 reduction
//
// **POST-PHASE-3 FEATURE chapter 1** — auto-checkpoint
// integration tying together:
//
//   - chapter 455 BASBiomimeticStateSnapshot (Codable
//     aggregate of Mamba + predictive-coding +
//     plasticity state)
//   - chapter 456 BASBiomimeticTurnObserver (cross-
//     primitive orchestrator with exportAggregate()
//     surface)
//   - chapter 461 engine hook (already fires observer
//     every turn via biomimeticTurnObserver +
//     biomimeticTurnSignalBuilder slots)
//   - chapter 428 unified event log + 8 typed payload
//     kinds (chapter 467 added the 8th:
//     .biomimeticCheckpoint)
//
// ## What this ships (M1245)
//
//   - `BASBiomimeticCheckpointEventPayload` typed
//     Codable payload wrapping `BASBiomimeticState
//     Snapshot` + turn index + cadence metadata
//   - `BASEventLogEntry.biomimeticCheckpointEvent(...)`
//     factory + reverse `biomimeticCheckpointEvent
//     Payload` accessor (mirrors chapter 428 pattern)
//   - Discriminator action tag matches
//     `BASEventPayloadKind.biomimeticCheckpoint
//     .rawValue` for filter-scan compatibility
//
// ## How auto-checkpointing works (chapter 467 / M1246)
//
// `BASTurnRuntimeEngineConfiguration` gains a new
// optional `biomimeticCheckpointEveryNTurns: Int?`
// slot。 When all 3 prerequisites are wired:
//
//   1. `biomimeticTurnObserver: BASBiomimeticTurn
//      Observer?` (chapter 461)
//   2. `biomimeticCheckpointEveryNTurns: Int?` (this
//      chapter,non-nil + >= 1)
//   3. `eventLog: (any BASEventLogStorage)?` (M998)
//
// the engine,AFTER the observer hook fires per turn,
// checks if `observer.turnsObservedCount() %
// everyN == 0` and if so:
//
//   1. Calls `await observer.exportAggregate()` to
//      get a fresh `BASBiomimeticStateSnapshot`
//   2. Wraps it in `BASBiomimeticCheckpointEvent
//      Payload`
//   3. Builds a `BASEventLogEntry` via the factory
//      below
//   4. Appends to the event log
//
// On next session,a replay consumer can find the
// most recent biomimetic-checkpoint event in the log
// + restore the observer via importAggregate(...)。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed payload + typed
//     cadence slot
//   - chapter 二百一一 — single payload type for
//     biomimetic checkpoints;piggybacks on the
//     unified event log
//   - chapter 三百九二 — Codable byte-stable via
//     JSONEncoder sortedKeys (chapter 428 pattern)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (additive payload + opt-in slot;default nil
//     → no emission → no behavior change)
//   - 红线 7 — checkpoint events are observation/
//     audit;not commitment
//   - ADR-014 OPT-IN — additive

import Foundation
import BASRuntimeCore

/// Typed Codable payload encoded inside
/// `BASEventLogEntry.payloadJson` when the entry
/// represents a biomimetic auto-checkpoint。
public struct BASBiomimeticCheckpointEventPayload:
    Codable, Equatable, Sendable, Hashable
{

    /// The aggregate biomimetic state snapshot at the
    /// moment of emission。 Carries Mamba SSM,
    /// predictive-coding probe,+ plasticity fold
    /// state (any subset may be nil if the host
    /// didn't populate that primitive slot)。
    public let snapshot: BASBiomimeticStateSnapshot

    /// Observer's turn counter at the moment of
    /// emission (i.e. the N'th turn that triggered
    /// this checkpoint per the cadence)。
    public let turnIndex: Int

    /// Cadence that triggered this emission。 e.g. 10
    /// means "emit every 10 turns";the engine
    /// emitted because turnIndex % 10 == 0。
    public let everyNTurns: Int

    /// Session ID this checkpoint binds to。 Mirrors
    /// the chapter 428 turn-lifecycle payload pattern。
    public let sessionID: String

    public init(
        snapshot: BASBiomimeticStateSnapshot,
        turnIndex: Int,
        everyNTurns: Int,
        sessionID: String
    ) {
        self.snapshot = snapshot
        self.turnIndex = max(0, turnIndex)
        self.everyNTurns = max(1, everyNTurns)
        self.sessionID = sessionID
    }
}

// MARK: - BASEventLogEntry extension

extension BASEventLogEntry {

    /// Build a `BASEventLogEntry` carrying a biomimetic
    /// checkpoint payload。 Engine calls this when it
    /// auto-emits every N turns。 Encodes the typed
    /// payload into `payloadJson` via JSONEncoder with
    /// sorted-keys output (chapter 三百九二 byte
    /// stability)。 chapter 467 / M1245。
    public static func biomimeticCheckpointEvent(
        eventID: String,
        timestampMs: Int64,
        sessionID: String,
        sequenceNumber: Int64 = 0,
        payload: BASBiomimeticCheckpointEventPayload,
        source: String? = "biomimetic-checkpoint",
        turnRef: String? = nil
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
            turnRef: turnRef,
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
                    .biomimeticCheckpoint.rawValue
            ],
            confidence: 0,
            payloadJson: json)
    }

    /// Decode the `BASBiomimeticCheckpointEventPayload`
    /// if this entry is a biomimetic checkpoint event。
    /// Returns nil for non-checkpoint entries or
    /// malformed payloads。
    public var biomimeticCheckpointEventPayload:
        BASBiomimeticCheckpointEventPayload?
    {
        guard payloadKind ==
            .biomimeticCheckpoint
        else { return nil }
        guard let json = payloadJson,
              let data = json.data(using: .utf8)
        else { return nil }
        return try? JSONDecoder().decode(
            BASBiomimeticCheckpointEventPayload.self,
            from: data)
    }
}
