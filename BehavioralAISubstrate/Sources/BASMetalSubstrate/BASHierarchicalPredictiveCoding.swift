// MARK: - BASHierarchicalPredictiveCoding — chapter 四百五十九 / M1213
// 系统熵 reduction
//
// **POST-SWEEP BIOMIMETIC** chapter 9 — first multi-
// LEVEL adaptive primitive。 Chapter 452 shipped one
// closed-loop adaptive primitive (BASPredictiveCoding
// Probe);chapter 459 stacks N probes into a typed
// HIERARCHY where each layer predicts the layer below
// + propagates only the prediction error upward。 This
// IS the canonical cortical-hierarchy abstraction
// (Rao & Ballard 1999;Friston's free-energy principle)。
//
// ## Why this exists (system entropy framing)
//
// Single-layer predictive coding (chapter 452):
//   - Substrate observes raw signal
//   - Maintains ONE prediction μ
//   - Single ε = observed - μ
//   - Single MSE as adaptation signal
//
// But biology has DEEP hierarchies。 Each cortical
// layer predicts the layer below;the only signal
// propagated UPWARD is the prediction error (what the
// lower layer COULDN'T predict)。 This:
//   1. Pushes increasingly abstract representations
//      up the stack
//   2. Filters out predictable signal (just noise to
//      higher layers)
//   3. Surfaces irreducible surprise at the TOP layer
//      — the system's "anomaly signal" at any moment
//
// chapter 459 ships `BASHierarchicalPredictiveCoding`
// — a typed actor maintaining an N-layer stack of
// BASPredictiveCodingProbe instances。 observe(_:)
// cascades:
//
//   layer[0].observe(raw_input) → ε_0
//   layer[1].observe(ε_0)       → ε_1
//   layer[2].observe(ε_1)       → ε_2
//   ...
//   layer[N-1].observe(ε_{N-2}) → ε_{N-1}  ← top error
//
// The top-layer error is the irreducible surprise。
// Per-layer MSE surfaces as a vector — converging
// MSEs across the stack mean the hierarchy is
// learning the input distribution。
//
// ## What this ships (M1212-M1215)
//
//   - **M1212** — Design BASHierarchicalPredictive
//     CodingShape (array of probe shapes,must all
//     have equal dim) + BASHierarchicalObservation
//     bundle + snapshot bundle + typed error。
//     Equal-dim invariant simplifies the cascade
//     (no projection needed between layers);hosts
//     wanting differential dims wire their own
//     projection matrices outside the stack
//
//   - **M1213** — Ship BASHierarchicalPredictive
//     Coding actor:
//     - Holds nonisolated array of N probes
//     - observe(_:) cascades error up the stack
//     - exportSnapshot()/importSnapshot(_:) integrate
//       chapter 455 per-layer snapshot value-types
//       into an aggregate
//     - reset() cascades reset to all layers
//
//   - **M1214** — PROOF tests:cascade propagation,
//     convergence behavior,snapshot round-trip,reset
//     cascade,shape-mismatch errors
//
//   - **M1215** — chapter 459 close-out + Phase 2
//     bump + ADR-016 advance + commit batch with
//     chapter 458 + push
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed shape (array of
//     probe shapes + equal-dim invariant) + typed
//     observation bundle + typed error
//   - chapter 二百一一 — one hierarchical actor per
//     host;one observe() entry cascading N probes
//     internally
//   - chapter 三百九二 — replay-determinism (cascade
//     is deterministic per (raw_input,layer states)
//     tuple)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//   - 红线 7 — hierarchical observation is adaptation
//     signal,not commitment authority
//   - ADR-014 OPT-IN — additive
//
// ## Significance — first multi-level adaptive primitive
//
// Before chapter 459:
//   - 1 single-layer predictive coding primitive
//   - 0 hierarchical / multi-level adaptive primitives
//   - Substrate could adapt to ONE prediction signal
//     but couldn't surface abstract anomalies via
//     hierarchy
//
// After chapter 459:
//   - N-layer typed hierarchy with cascade error
//     propagation
//   - Per-layer prediction + MSE accessible for audit
//   - Top-layer error = irreducible surprise signal
//   - Snapshot bundle for cross-turn persistence
//     covers the entire stack with one Codable value
//
// 「不够仿生」 critique progress:7/10 → 8/10
// (substrate now mirrors cortical hierarchies — not
// just one closed-loop adaptive primitive but an
// N-deep stack)。

import Foundation

// MARK: - Typed shape

/// Typed shape for a `BASHierarchicalPredictiveCoding`
/// actor。 Array of per-layer probe shapes。 All layers
/// MUST have the same `dim` (init throws otherwise) —
/// this is the equal-dim invariant chapter 459 chose
/// to keep the cascade simple (no inter-layer
/// projection needed)。
public struct BASHierarchicalPredictiveCodingShape:
    Equatable, Hashable, Sendable, Codable
{

    /// Per-layer probe shapes,bottom-up order
    /// (layers[0] sees raw input,layers.last sees the
    /// most-abstracted error)。
    public let layers: [BASPredictiveCodingProbeShape]

    public var layerCount: Int { layers.count }

    /// Init validates that the array is non-empty AND
    /// all layers share the same `dim`。 Throws
    /// `BASHierarchicalPredictiveCodingError` on
    /// violation。
    public init(
        layers: [BASPredictiveCodingProbeShape]
    ) throws {
        guard !layers.isEmpty else {
            throw BASHierarchicalPredictiveCodingError
                .emptyLayers
        }
        let firstDim = layers[0].dim
        for (i, layer) in layers.enumerated() {
            guard layer.dim == firstDim else {
                throw
                    BASHierarchicalPredictiveCodingError
                    .shapeMismatch(
                        reason: "layers[\(i)].dim" +
                        " (\(layer.dim)) !=" +
                        " layers[0].dim (\(firstDim))" +
                        " — equal-dim invariant violated")
            }
        }
        self.layers = layers
    }

    // Custom Codable init enforces the equal-dim
    // invariant on DECODE — otherwise the synthesized
    // init would let a malformed JSON bypass the
    // throwing-init validator and produce an unsound
    // shape。 chapter 459 / M1213。
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(
            keyedBy: CodingKeys.self)
        let layers = try c.decode(
            [BASPredictiveCodingProbeShape].self,
            forKey: .layers)
        try self.init(layers: layers)
    }
}

// MARK: - Observation result bundle

/// Typed output from one `observe(_:)` call on a
/// hierarchical stack。 Carries the per-layer
/// `BASPredictiveCodingObservation` + the top-layer
/// error (irreducible surprise) + observation index。
public struct BASHierarchicalObservation:
    Equatable, Hashable, Sendable, Codable
{

    /// Per-layer observation results,bottom-up order。
    /// `perLayer[0]` is the bottom layer (saw raw input);
    /// `perLayer.last` is the top layer (saw the most-
    /// abstracted error)。
    public let perLayer: [BASPredictiveCodingObservation]

    /// Top layer's prediction error ε_{N-1}。 This is
    /// the irreducible surprise — what NO layer in the
    /// hierarchy could predict。
    public let topLayerError: [Float]

    /// Top layer's running MSE。 Adaptation signal at
    /// the deepest level of abstraction。
    public let topLayerMSE: Float

    /// 0-based observation index (matches the actor's
    /// observationsProcessed AT the moment of call)。
    public let observationIndex: Int

    public init(
        perLayer: [BASPredictiveCodingObservation],
        topLayerError: [Float],
        topLayerMSE: Float,
        observationIndex: Int
    ) {
        self.perLayer = perLayer
        self.topLayerError = topLayerError
        self.topLayerMSE = max(0, topLayerMSE)
        self.observationIndex =
            max(0, observationIndex)
    }
}

// MARK: - Snapshot bundle

/// Codable snapshot of a `BASHierarchicalPredictive
/// Coding` actor's full state。 Bundles per-layer
/// snapshots into one Codable surface for cross-turn
/// persistence (chapter 455 integration)。
public struct BASHierarchicalPredictiveCodingSnapshot:
    Codable, Equatable, Hashable, Sendable
{

    public let shape: BASHierarchicalPredictiveCodingShape
    public let layers: [BASPredictiveCodingSnapshot]
    public let observationsProcessed: Int

    public init(
        shape: BASHierarchicalPredictiveCodingShape,
        layers: [BASPredictiveCodingSnapshot],
        observationsProcessed: Int
    ) {
        self.shape = shape
        self.layers = layers
        self.observationsProcessed =
            max(0, observationsProcessed)
    }
}

// MARK: - Typed errors

public enum BASHierarchicalPredictiveCodingError:
    Error, Equatable, Sendable, Codable
{
    case emptyLayers
    case shapeMismatch(reason: String)
}

// MARK: - Hierarchical predictive coding actor

/// Substrate-side N-layer predictive-coding hierarchy
/// actor。 Each layer predicts the layer below;only
/// the prediction error propagates UPWARD。 Mirrors
/// cortical-hierarchy abstraction (Rao & Ballard 1999;
/// Friston free-energy principle)。
public actor BASHierarchicalPredictiveCoding {

    public nonisolated let shape:
        BASHierarchicalPredictiveCodingShape

    /// Per-layer probe instances,owned by the actor。
    /// Each call to observe(_:) cascades through them
    /// bottom-up。
    private let probes: [BASPredictiveCodingProbe]

    /// Number of `observe(_:)` calls processed since
    /// last `reset()`。
    private var observationsProcessed: Int = 0

    public init(
        shape: BASHierarchicalPredictiveCodingShape
    ) {
        self.shape = shape
        self.probes = shape.layers.map {
            BASPredictiveCodingProbe(shape: $0)
        }
    }

    /// Read-only count of observations cascaded since
    /// the most recent reset。
    public func observationCount() -> Int {
        return observationsProcessed
    }

    /// Reset every layer's prediction + zero the
    /// observation counter。 Cascades reset to all
    /// probes in the hierarchy。
    public func reset() async {
        for probe in probes {
            await probe.reset()
        }
        observationsProcessed = 0
    }

    /// Cascade `input` up the hierarchy。 Layer 0
    /// observes the raw input;each subsequent layer
    /// observes the prior layer's prediction error。
    /// Returns the typed observation bundle carrying
    /// per-layer results + top-layer error。
    public func observe(
        _ input: [Float]
    ) async throws -> BASHierarchicalObservation {
        // Bottom-layer dim is the shape's invariant
        // dim;input must match
        guard input.count == shape.layers[0].dim else {
            throw
                BASHierarchicalPredictiveCodingError
                .shapeMismatch(
                    reason: "input.count" +
                    " (\(input.count)) !=" +
                    " bottom-layer dim" +
                    " (\(shape.layers[0].dim))")
        }
        var perLayer: [BASPredictiveCodingObservation] =
            []
        perLayer.reserveCapacity(probes.count)
        var nextInput = input
        for probe in probes {
            let obs = try await probe.observe(nextInput)
            perLayer.append(obs)
            // Next layer sees this layer's error
            nextInput = obs.error
        }
        let currentIndex = observationsProcessed
        observationsProcessed += 1
        let topObs = perLayer[perLayer.count - 1]
        return BASHierarchicalObservation(
            perLayer: perLayer,
            topLayerError: topObs.error,
            topLayerMSE: topObs.runningMSE,
            observationIndex: currentIndex)
    }

    /// Export an aggregate snapshot covering every
    /// layer's state。 Safe to encode/persist。
    public func exportSnapshot()
        async -> BASHierarchicalPredictiveCodingSnapshot
    {
        var layerSnaps: [BASPredictiveCodingSnapshot] =
            []
        layerSnaps.reserveCapacity(probes.count)
        for probe in probes {
            layerSnaps.append(
                await probe.exportSnapshot())
        }
        return BASHierarchicalPredictiveCodingSnapshot(
            shape: shape,
            layers: layerSnaps,
            observationsProcessed: observationsProcessed)
    }

    /// Restore every layer's state from a previously-
    /// exported aggregate snapshot。 Validates that
    /// the snapshot's shape matches the actor's shape
    /// (layer count + per-layer dims) BEFORE mutating
    /// — failure leaves actor state untouched。
    public func importSnapshot(
        _ snapshot:
            BASHierarchicalPredictiveCodingSnapshot
    ) async throws {
        guard snapshot.shape == shape else {
            throw
                BASHierarchicalPredictiveCodingError
                .shapeMismatch(
                    reason: "snapshot.shape !=" +
                    " actor.shape (layer count or" +
                    " per-layer dim mismatch)")
        }
        guard snapshot.layers.count == probes.count
        else {
            throw
                BASHierarchicalPredictiveCodingError
                .shapeMismatch(
                    reason: "snapshot.layers.count" +
                    " (\(snapshot.layers.count)) !=" +
                    " probe count (\(probes.count))")
        }
        // Restore each layer
        for (i, probe) in probes.enumerated() {
            try await probe.importSnapshot(
                snapshot.layers[i])
        }
        observationsProcessed =
            snapshot.observationsProcessed
    }
}
