// MARK: - BASBiomimeticCheckpointReplay — chapter 四百六十八 / M1249
// 系统熵 reduction
//
// **POST-PHASE-3 FEATURE chapter 2** — closes the
// cross-session biomimetic-state recovery loop opened
// by chapter 467 auto-checkpoint emission。
//
// ## Why this exists (system entropy framing)
//
// Chapter 467 wired `BASTurnRuntimeEngine` to auto-
// emit a typed `BASBiomimeticCheckpointEventPayload`
// event every N turns。 But hosts couldn't easily
// RESTORE from those checkpoints on a new session:
// they'd have to manually:
//
//   1. Query the event log for events with the right
//      payload kind discriminator
//   2. Filter by session
//   3. Find the most recent (highest turnIndex)
//   4. Decode the JSON payload
//   5. Extract the snapshot
//   6. Call observer.importAggregate(snapshot)
//
// Six steps with error handling at each。 Chapter 468
// ships those 6 steps as one typed namespace surface:
//
//   - `BASBiomimeticCheckpointReplay.latestCheckpoint
//     (in:sessionID:)` returns the most recent typed
//     payload from a session,or nil if no checkpoint
//     exists
//   - `BASBiomimeticCheckpointReplay.restoreObserver
//     (_:from:sessionID:)` queries the log + restores
//     the observer in one call,returning whether
//     restoration happened
//
// Cross-session biomimetic-state recovery is now a
// 1-line call instead of 6 steps of imperative
// plumbing。
//
// ## What this ships (M1249)
//
//   - `BASBiomimeticCheckpointReplay` typed namespace
//     (enum,no instantiation)
//   - `latestCheckpoint(in:sessionID:)` returning the
//     most recent payload (or nil)
//   - `restoreObserver(_:from:sessionID:)` async
//     throws Bool — true if restored,false if no
//     checkpoint found,throws on shape mismatch
//
// Both helpers use the chapter 467 reverse accessor
// `entry.biomimeticCheckpointEventPayload` for
// decoding。 Most-recent selection is by highest
// turnIndex (not by sequence number);if multiple
// checkpoints share the same turnIndex,the LAST one
// emitted wins (stable ordering preserved by event
// log)。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed namespace + typed
//     return values
//   - chapter 二百一一 — single namespace for the
//     replay surface;not scattered as observer
//     extension methods
//   - chapter 三百九二 — replay deterministic per
//     (event log contents,session ID) pair;byte-
//     stable decode via chapter 467 payload Codable
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (additive namespace;no existing API touched)
//   - 红线 7 — replay is observation-side restoration,
//     not commitment authority
//   - ADR-014 OPT-IN — additive

import Foundation
import BASRuntimeCore

/// Typed namespace for biomimetic-checkpoint replay
/// from an event log into an observer。 chapter 468 /
/// M1249。
public enum BASBiomimeticCheckpointReplay {

    /// Query an event log for the most recent
    /// biomimetic checkpoint emitted under the given
    /// session ID。 Returns the decoded payload,or
    /// nil if no checkpoint events exist for that
    /// session。 "Most recent" = highest turnIndex;
    /// when ties exist,the last emitted entry wins
    /// (event log preserves stable insertion order)。
    public static func latestCheckpoint(
        in eventLog: any BASEventLogStorage,
        sessionID: String
    ) async -> BASBiomimeticCheckpointEventPayload? {
        let entries = await eventLog.events(
            forSession: sessionID)
        var bestPayload:
            BASBiomimeticCheckpointEventPayload? = nil
        var bestTurnIndex: Int = -1
        for entry in entries {
            guard entry.payloadKind ==
                .biomimeticCheckpoint
            else { continue }
            guard let payload = entry
                .biomimeticCheckpointEventPayload
            else { continue }
            if payload.turnIndex >= bestTurnIndex {
                bestTurnIndex = payload.turnIndex
                bestPayload = payload
            }
        }
        return bestPayload
    }

    /// Restore a fresh `BASBiomimeticTurnObserver`
    /// from the most recent checkpoint in the event
    /// log for the given session ID。 Returns true if
    /// a checkpoint was found AND applied;false if
    /// no checkpoint exists (observer left untouched)。
    /// Throws `BASBiomimeticSnapshotError.shapeMismatch`
    /// if the snapshot's shape doesn't match the
    /// observer's populated primitives (preserving
    /// chapter 455 fail-fast contract)。
    @discardableResult
    public static func restoreObserver(
        _ observer: BASBiomimeticTurnObserver,
        from eventLog: any BASEventLogStorage,
        sessionID: String
    ) async throws -> Bool {
        guard let payload = await latestCheckpoint(
            in: eventLog,
            sessionID: sessionID)
        else { return false }
        try await observer.importAggregate(
            payload.snapshot)
        return true
    }

    /// Count of distinct checkpoint events for a
    /// session。 Useful for audit + tests verifying
    /// emission cadence。 Returns 0 if no
    /// checkpoints。
    public static func checkpointCount(
        in eventLog: any BASEventLogStorage,
        sessionID: String
    ) async -> Int {
        let entries = await eventLog.events(
            forSession: sessionID)
        return entries.filter {
            $0.payloadKind == .biomimeticCheckpoint
        }.count
    }
}
