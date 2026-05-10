// MARK: - BASBiomimeticStateSnapshot — chapter 四百五十五 / M1197
// 系统熵 reduction
//
// **POST-SWEEP BIOMIMETIC** chapter 5 — cross-turn /
// cross-session state persistence for ALL 3 biomimetic
// substrate primitives shipped so far:
//   1. BASMambaSSMState  (chapter 450/451)
//   2. BASPredictiveCodingProbe  (chapter 452)
//   3. BASPlasticityFold  (chapter 454)
//
// ## Why this exists (system entropy framing)
//
// chapters 450-454 shipped 3 biomimetic primitives,
// each maintaining mutable state inside actor
// isolation。 But the state lived ONLY in-memory
// per actor instance — when the host process
// restarted (or the actor was discarded),the state
// vanished。 The whole point of biomimetic state
// (recurrent memory,learned predictions,plastic
// weights) is that it ACCUMULATES across sessions。
// Without persistence,each substrate-side learning
// step would start from scratch — anti-biomimetic。
//
// chapter 455 ships:
//
//   1. Per-primitive Codable snapshot bundles
//      (`BASMambaSSMSnapshot`,`BASPredictiveCoding
//      Snapshot`,`BASPlasticitySnapshot`)
//   2. `exportSnapshot()` + `importSnapshot(_:)` on
//      each actor (declared inside actor body so they
//      can mutate private state;typed,validates
//      shape match before mutating)
//   3. Aggregate `BASBiomimeticStateSnapshot` value-
//      type bundling all 3 — single Codable surface
//      for whole-substrate state checkpoint
//
// Hosts can now:
//
//   1. Run a session,let substrate state evolve
//   2. Call `exportSnapshot()` on each primitive
//   3. Aggregate into a `BASBiomimeticStateSnapshot`
//   4. JSON-encode + persist (file,event log,
//      remote backup,etc)
//   5. On next session,decode + call `importSnapshot
//      (_:)` to restore exactly the prior state
//
// State evolution then continues from the restored
// state,not from zero。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed snapshot bundles;
//     shape stored alongside data so import can
//     validate dimensional compatibility
//   - chapter 二百一一 — one snapshot type per
//     primitive;one aggregate type for the substrate
//   - chapter 三百九二 — replay-determinism (snapshots
//     are byte-stable Codable via Float arrays + Int
//     counters)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (additive surface;no existing API touched)
//   - 红线 7 — snapshots are observation/audit,not
//     commitment authority
//   - ADR-014 OPT-IN — additive
//
// ## Implementation note — methods live in actor bodies
//
// The actor methods `exportSnapshot()` +
// `importSnapshot(_:)` are declared INSIDE each
// actor's body (in `BASMambaSSMState.swift`,
// `BASPredictiveCodingProbe.swift`,
// `BASPlasticityFold.swift`),not in extensions in
// this file。 Reason:Swift actor private state can
// only be mutated from within the actor's primary
// declaration scope — extensions in separate files
// have no access to private vars。 The Codable
// VALUE-TYPES live here (they're pure data structs);
// the actor METHODS live with each actor。

import Foundation

// MARK: - Per-primitive snapshot bundles

/// Codable snapshot of a `BASMambaSSMState` actor's
/// internal state at a point in time。
public struct BASMambaSSMSnapshot:
    Codable, Equatable, Hashable, Sendable
{

    /// Shape the snapshot was taken at。 Import
    /// requires matching shape on the target actor。
    public let shape: BASMambaSSMShape

    /// Hidden state flattened (B × D × N)。
    public let hiddenState: [Float]

    /// Number of selectiveScan() calls that produced
    /// this state since the actor's most recent
    /// `reset()`。
    public let processedScanCalls: Int

    public init(
        shape: BASMambaSSMShape,
        hiddenState: [Float],
        processedScanCalls: Int
    ) {
        self.shape = shape
        self.hiddenState = hiddenState
        self.processedScanCalls =
            max(0, processedScanCalls)
    }
}

/// Codable snapshot of a `BASPredictiveCodingProbe`
/// actor's internal state at a point in time。
public struct BASPredictiveCodingSnapshot:
    Codable, Equatable, Hashable, Sendable
{

    public let shape: BASPredictiveCodingProbeShape

    /// Current prediction vector μ。
    public let prediction: [Float]

    /// Number of observe() calls since reset()。
    public let observationsProcessed: Int

    /// Accumulated sum of per-observation squared
    /// errors。 Running MSE = sumSquaredError /
    /// observationsProcessed (when observationsProcessed
    /// > 0)。
    public let sumSquaredError: Float

    public init(
        shape: BASPredictiveCodingProbeShape,
        prediction: [Float],
        observationsProcessed: Int,
        sumSquaredError: Float
    ) {
        self.shape = shape
        self.prediction = prediction
        self.observationsProcessed =
            max(0, observationsProcessed)
        self.sumSquaredError =
            max(0, sumSquaredError)
    }
}

/// Codable snapshot of a `BASPlasticityFold` actor's
/// internal state at a point in time。
public struct BASPlasticitySnapshot:
    Codable, Equatable, Hashable, Sendable
{

    public let shape: BASPlasticityFoldShape

    /// Weight matrix flattened (preDim × postDim)。
    public let weights: [Float]

    /// Number of apply() calls since reset()。
    public let updatesProcessed: Int

    public init(
        shape: BASPlasticityFoldShape,
        weights: [Float],
        updatesProcessed: Int
    ) {
        self.shape = shape
        self.weights = weights
        self.updatesProcessed =
            max(0, updatesProcessed)
    }
}

// MARK: - Aggregate snapshot

/// Aggregate snapshot bundling the 3 biomimetic
/// primitives' states into one Codable value-type。
/// Hosts checkpoint the whole substrate's adaptive
/// state with a single encode call;restore with a
/// single decode + 3 importSnapshot() calls。
public struct BASBiomimeticStateSnapshot:
    Codable, Equatable, Hashable, Sendable
{

    /// Mamba SSM hidden state snapshot。 nil when
    /// the host's substrate doesn't use Mamba。
    public let mamba: BASMambaSSMSnapshot?

    /// Predictive-coding probe state snapshot。 nil
    /// when not used。
    public let predictive: BASPredictiveCodingSnapshot?

    /// Plasticity fold weight state snapshot。 nil
    /// when not used。
    public let plasticity: BASPlasticitySnapshot?

    /// Snapshot version tag for forward-compat
    /// migration。 chapter 八十七 raw-value stability:
    /// bumping requires explicit audit。
    public let snapshotVersion: String

    /// Wall-clock UTC timestamp the snapshot was
    /// taken at (milliseconds since 1970-01-01)。
    /// Useful for cross-session ordering + audit。
    public let timestampMs: Int64

    public init(
        mamba: BASMambaSSMSnapshot? = nil,
        predictive: BASPredictiveCodingSnapshot? = nil,
        plasticity: BASPlasticitySnapshot? = nil,
        snapshotVersion: String =
            "biomimetic-snapshot-v1",
        timestampMs: Int64 = Int64(
            Date().timeIntervalSince1970 * 1000)
    ) {
        self.mamba = mamba
        self.predictive = predictive
        self.plasticity = plasticity
        self.snapshotVersion = snapshotVersion
        self.timestampMs = timestampMs
    }

    /// Convenience:count of populated (non-nil)
    /// primitive snapshots in this aggregate。
    public var populatedPrimitiveCount: Int {
        var count = 0
        if mamba != nil { count += 1 }
        if predictive != nil { count += 1 }
        if plasticity != nil { count += 1 }
        return count
    }
}

// MARK: - Snapshot error

public enum BASBiomimeticSnapshotError:
    Error, Equatable, Sendable
{
    /// Imported snapshot's shape doesn't match the
    /// target actor's shape。 Cross-shape import
    /// silently corrupting weights/state would be a
    /// real bug — fail loudly。
    case shapeMismatch(reason: String)
}
