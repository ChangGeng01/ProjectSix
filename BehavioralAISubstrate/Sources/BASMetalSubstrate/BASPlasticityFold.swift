// MARK: - BASPlasticityFold — chapter 四百五十四 / M1193
// 系统熵 reduction
//
// **POST-SWEEP BIOMIMETIC** chapter 4 — substrate-level
// **learning primitive**。 Substantive answer to 「不够
// 灵活」 critique on the learning axis (chapter 452
// predictive-coding probe added closed-loop adaptation;
// chapter 454 adds the substrate-level weight update
// that 学权重 from per-outcome signal pairs)。
//
// ## Why this exists (system entropy framing)
//
// Biology has synaptic plasticity at every level:
// Hebbian learning ("neurons that fire together wire
// together"), anti-Hebbian for normalization, STDP
// for temporal sequence learning, etc。 The common
// shape:**pre-synaptic + post-synaptic + outcome
// signal → weight update**。
//
// chapter 454 ships a typed substrate primitive with
// 3 selectable rules,each consuming the same
// (pre, post, outcome) typed bundle:
//
//   1. **Hebbian**: W += α · (pre ⊗ post)
//      Strengthens correlations between pre + post。
//      Drives the substrate to learn statistical
//      regularities in the input-output pairing。
//
//   2. **Anti-Hebbian**: W -= α · (pre ⊗ post)
//      Weakens correlations。 Useful for normalization
//      / decorrelation / divisive inhibition。
//
//   3. **Outcome-modulated Hebbian**:
//      W += α · outcome_scalar · (pre ⊗ post)
//      The outcome scalar (e.g. reward signal) gates
//      the learning rate per-update。 If outcome=0 no
//      learning;outcome>0 reinforces;outcome<0
//      anti-reinforces。 Biology analogue:
//      dopaminergic gating of plasticity。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed shape + typed rule
//     enum + typed update bundle;no magic numbers in
//     plasticity rule
//   - chapter 二百一一 — one substrate-level
//     plasticity primitive;different rules under
//     same actor (not parallel implementations)
//   - chapter 三百九二 — replay-determinism (weight
//     evolution deterministic per (pre, post, outcome)
//     sequence + chosen rule)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (additive)
//   - 红线 7 — weight updates are observation-derived
//     hints,not commitment authority
//   - ADR-014 OPT-IN — additive
//
// ## Significance — first substrate-level learning
//
// Before chapter 454:
//   - 0 substrate-level weight update primitives
//   - Substrate adapted predictions (chapter 452) but
//     never accumulated reusable weights
//
// After chapter 454:
//   - Substrate has typed actor maintaining weight
//     matrix W,updated via plasticity rule from
//     observed (pre, post, outcome) pairs
//   - Weights persist across `apply(...)` calls
//   - Three biology-inspired rules available;hosts
//     pick the rule that matches their domain (Hebbian
//     for correlation learning,outcome-modulated for
//     reinforcement)
//
// 「不够灵活」 critique progress:~35% → **~50%** (now
// has BOTH predictive-coding adaptation AND substrate-
// level weight learning)。

import Foundation

// MARK: - Typed rule enum

public enum BASPlasticityRule:
    String, CaseIterable, Codable, Equatable, Hashable, Sendable
{
    /// W += α · (pre ⊗ post)。 Strengthens correlations。
    case hebbian = "hebbian"

    /// W -= α · (pre ⊗ post)。 Weakens correlations。
    case antiHebbian = "anti-hebbian"

    /// W += α · outcome · (pre ⊗ post)。 Outcome scalar
    /// gates the per-update learning rate (positive
    /// reinforces,negative anti-reinforces,zero
    /// freezes)。 Biology analogue:dopaminergic
    /// gating of plasticity。
    case outcomeModulatedHebbian =
        "outcome-modulated-hebbian"

    /// Spike-Timing-Dependent Plasticity (STDP):
    /// W += α · amplitude(Δt) · (pre ⊗ post),where
    /// amplitude(Δt) follows the canonical asymmetric
    /// exponential window (Bi & Poo 1998;Markram et
    /// al 1997):
    ///
    ///   amplitude(Δt) =  A_+ · exp(-Δt / τ_+)   when Δt > 0  (LTP)
    ///   amplitude(Δt) = -A_- · exp( Δt / τ_-)   when Δt < 0  (LTD)
    ///   amplitude(Δt) =  0                      when Δt = 0  (no causal info)
    ///
    /// Δt is the time difference t_post - t_pre。
    /// Positive Δt (pre fires BEFORE post) → causal →
    /// LTP。 Negative Δt (post fires BEFORE pre) →
    /// anti-causal → LTD。 |Δt| larger → amplitude
    /// decays exponentially toward 0。
    ///
    /// Params (A_+,A_-,τ_+,τ_-) live in
    /// `BASPlasticityFoldShape.stdpParams`。 chapter
    /// 457 / M1205。
    case stdpTemporal = "stdp-temporal"
}

// MARK: - STDP params

/// Typed STDP curve parameters。 chapter 457 / M1205。
/// Defaults match canonical Bi & Poo 1998 values:
/// A_+ = A_- = 1.0,τ_+ = τ_- = 20 ms。 Asymmetric
/// values shift the LTP/LTD balance (e.g. A_+ > A_-
/// biases toward potentiation;τ_- > τ_+ widens the
/// LTD window relative to LTP)。
public struct BASPlasticitySTDPParams:
    Equatable, Hashable, Sendable, Codable
{

    /// Potentiation amplitude A_+ (for Δt > 0)。
    /// Clamped to >= 0。
    public let aPlus: Float

    /// Depression amplitude A_- (for Δt < 0)。
    /// Clamped to >= 0。 The rule applies the
    /// sign internally (amplitude is negative for
    /// LTD);A_- is stored as a non-negative magnitude。
    public let aMinus: Float

    /// Potentiation time constant τ_+ in the same
    /// timing unit Δt is measured in (typically ms)。
    /// Clamped to >= 1e-6 to avoid divide-by-zero。
    public let tauPlus: Float

    /// Depression time constant τ_-。 Clamped >= 1e-6。
    public let tauMinus: Float

    public init(
        aPlus: Float = 1.0,
        aMinus: Float = 1.0,
        tauPlus: Float = 20.0,
        tauMinus: Float = 20.0
    ) {
        self.aPlus = max(0, aPlus)
        self.aMinus = max(0, aMinus)
        self.tauPlus = max(1e-6, tauPlus)
        self.tauMinus = max(1e-6, tauMinus)
    }
}

// MARK: - Typed shape

public struct BASPlasticityFoldShape:
    Equatable, Hashable, Sendable, Codable
{

    /// Pre-synaptic feature dim P。 Clamped to >= 1。
    public let preDim: Int

    /// Post-synaptic feature dim Q。 Clamped to >= 1。
    public let postDim: Int

    /// Learning rate α。 Clamped to >= 0 (no clamp on
    /// upper bound — rule-specific stability is the
    /// caller's responsibility)。
    public let learningRate: Float

    /// Which plasticity rule the fold applies on
    /// `apply(...)`。
    public let rule: BASPlasticityRule

    /// STDP curve parameters (used only when rule is
    /// `.stdpTemporal`;ignored for hebbian /
    /// antiHebbian / outcomeModulatedHebbian)。
    /// Defaults to canonical Bi & Poo 1998 values。
    /// chapter 457 / M1205。
    public let stdpParams: BASPlasticitySTDPParams

    public init(
        preDim: Int,
        postDim: Int,
        learningRate: Float = 0.01,
        rule: BASPlasticityRule = .hebbian,
        stdpParams: BASPlasticitySTDPParams =
            BASPlasticitySTDPParams()
    ) {
        self.preDim = max(1, preDim)
        self.postDim = max(1, postDim)
        self.learningRate = max(0, learningRate)
        self.rule = rule
        self.stdpParams = stdpParams
    }

    // Custom Codable init handles snapshots encoded
    // before stdpParams field existed — defaults the
    // missing key to canonical Bi & Poo values。
    // chapter 457 / M1205 backward-compat。
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(
            keyedBy: CodingKeys.self)
        let p = try c.decode(
            Int.self, forKey: .preDim)
        let q = try c.decode(
            Int.self, forKey: .postDim)
        let alpha = try c.decode(
            Float.self, forKey: .learningRate)
        let r = try c.decode(
            BASPlasticityRule.self, forKey: .rule)
        let stdp = try c.decodeIfPresent(
            BASPlasticitySTDPParams.self,
            forKey: .stdpParams)
            ?? BASPlasticitySTDPParams()
        self.init(
            preDim: p,
            postDim: q,
            learningRate: alpha,
            rule: r,
            stdpParams: stdp)
    }
}

// MARK: - Typed update result bundle

public struct BASPlasticityUpdate:
    Equatable, Hashable, Sendable
{

    /// The pre-synaptic vector caller passed in。
    public let pre: [Float]

    /// The post-synaptic vector caller passed in。
    public let post: [Float]

    /// Outcome scalar (used only by
    /// outcomeModulatedHebbian rule;ignored by
    /// hebbian / antiHebbian / stdpTemporal)。
    public let outcome: Float

    /// Spike-timing delta Δt = t_post - t_pre used by
    /// `.stdpTemporal` rule;ignored by the other 3
    /// rules。 chapter 457 / M1205。
    public let timingDelta: Float

    /// STDP amplitude factor applied this update。
    /// 0 for non-STDP rules。 Positive for LTP (Δt > 0),
    /// negative for LTD (Δt < 0)。 chapter 457 / M1205。
    public let stdpAmplitude: Float

    /// Per-element weight delta applied this update
    /// (post-rule)。 Length = preDim × postDim。
    public let weightDelta: [Float]

    /// Weight matrix snapshot AFTER applying the
    /// delta。 Length = preDim × postDim。
    public let updatedWeightSnapshot: [Float]

    /// 0-based update sequence number。
    public let updateIndex: Int

    public init(
        pre: [Float],
        post: [Float],
        outcome: Float,
        weightDelta: [Float],
        updatedWeightSnapshot: [Float],
        updateIndex: Int,
        timingDelta: Float = 0,
        stdpAmplitude: Float = 0
    ) {
        self.pre = pre
        self.post = post
        self.outcome = outcome
        self.timingDelta = timingDelta
        self.stdpAmplitude = stdpAmplitude
        self.weightDelta = weightDelta
        self.updatedWeightSnapshot =
            updatedWeightSnapshot
        self.updateIndex = max(0, updateIndex)
    }
}

// MARK: - Typed errors

public enum BASPlasticityError:
    Error, Equatable, Sendable
{
    case shapeMismatch(reason: String)
}

// MARK: - Plasticity fold actor

/// Substrate-side plasticity actor maintaining a
/// weight matrix W:(preDim × postDim) updated per
/// `apply(pre:post:outcome:)` call via the configured
/// `BASPlasticityRule`。
public actor BASPlasticityFold {

    public nonisolated let shape:
        BASPlasticityFoldShape

    /// Weight matrix W flattened row-major:row i is
    /// the post-synaptic vector for pre-index i。
    /// Length = preDim × postDim。 Initialized to all
    /// zeros;mutated by `apply(...)`。
    private var weights: [Float]

    /// Number of `apply(...)` calls processed since
    /// most recent `reset()`。
    private var updatesProcessed: Int = 0

    public init(shape: BASPlasticityFoldShape) {
        self.shape = shape
        self.weights = Array(
            repeating: 0,
            count: shape.preDim * shape.postDim)
    }

    public func currentWeightsSnapshot() -> [Float] {
        return weights
    }

    public func updateCount() -> Int {
        return updatesProcessed
    }

    /// Reset weights to all zeros + zero counter。
    public func reset() {
        weights = Array(
            repeating: 0,
            count: shape.preDim * shape.postDim)
        updatesProcessed = 0
    }

    /// Apply one plasticity update with the typed
    /// (pre, post, outcome [, timingDelta]) bundle。
    /// Computes the rule-specific weight delta,mutates
    /// the internal weight matrix,returns a typed
    /// result snapshot。
    ///
    /// `timingDelta` carries Δt = t_post - t_pre for
    /// `.stdpTemporal` rule。 Ignored by the other 3
    /// rules。 chapter 457 / M1205。
    public func apply(
        pre: [Float],
        post: [Float],
        outcome: Float = 0,
        timingDelta: Float = 0
    ) throws -> BASPlasticityUpdate {
        guard pre.count == shape.preDim else {
            throw BASPlasticityError.shapeMismatch(
                reason: "pre.count (\(pre.count)) must" +
                " equal preDim (\(shape.preDim))")
        }
        guard post.count == shape.postDim else {
            throw BASPlasticityError.shapeMismatch(
                reason: "post.count (\(post.count))" +
                " must equal postDim (\(shape.postDim))")
        }
        // Determine the per-update scale factor based
        // on the configured rule。 stdpAmplitude is
        // recorded into the update bundle for audit;
        // 0 for non-STDP rules。
        let scale: Float
        var stdpAmplitude: Float = 0
        switch shape.rule {
        case .hebbian:
            scale = shape.learningRate
        case .antiHebbian:
            scale = -shape.learningRate
        case .outcomeModulatedHebbian:
            scale = shape.learningRate * outcome
        case .stdpTemporal:
            // STDP amplitude follows asymmetric
            // exponential window:
            //   Δt > 0 → +A_+ · exp(-Δt / τ_+) (LTP)
            //   Δt < 0 → -A_- · exp( Δt / τ_-) (LTD)
            //   Δt = 0 → 0 (no causal info)
            let p = shape.stdpParams
            if timingDelta > 0 {
                stdpAmplitude =
                    p.aPlus * expf(-timingDelta / p.tauPlus)
            } else if timingDelta < 0 {
                stdpAmplitude =
                    -p.aMinus * expf(timingDelta / p.tauMinus)
            } else {
                stdpAmplitude = 0
            }
            scale = shape.learningRate * stdpAmplitude
        }
        // Compute weight delta = scale · (pre ⊗ post)
        // Δ[i, j] = scale * pre[i] * post[j]
        var delta: [Float] = Array(
            repeating: 0,
            count: shape.preDim * shape.postDim)
        for i in 0..<shape.preDim {
            for j in 0..<shape.postDim {
                delta[i * shape.postDim + j] =
                    scale * pre[i] * post[j]
            }
        }
        // Apply delta to weights
        for k in 0..<weights.count {
            weights[k] += delta[k]
        }
        let currentIndex = updatesProcessed
        updatesProcessed += 1
        return BASPlasticityUpdate(
            pre: pre,
            post: post,
            outcome: outcome,
            weightDelta: delta,
            updatedWeightSnapshot: weights,
            updateIndex: currentIndex,
            timingDelta: timingDelta,
            stdpAmplitude: stdpAmplitude)
    }

    /// Forward-pass over the current weights:
    /// `output[j] = sum_i(pre[i] * weights[i, j])`。
    /// Useful for callers to query "what would the
    /// substrate predict for this pre-vector given
    /// current weights"。 Does NOT mutate state。
    public func forward(
        pre: [Float]
    ) throws -> [Float] {
        guard pre.count == shape.preDim else {
            throw BASPlasticityError.shapeMismatch(
                reason: "pre.count (\(pre.count)) must" +
                " equal preDim (\(shape.preDim))")
        }
        var output: [Float] = Array(
            repeating: 0, count: shape.postDim)
        for j in 0..<shape.postDim {
            var acc: Float = 0
            for i in 0..<shape.preDim {
                acc += pre[i] *
                    weights[i * shape.postDim + j]
            }
            output[j] = acc
        }
        return output
    }

    // MARK: - chapter 455 / M1197 — snapshot persistence

    /// Capture an immutable snapshot of the fold's
    /// current weight matrix + update counter。 Safe
    /// to encode/persist (Codable via
    /// BASPlasticitySnapshot)。
    public func exportSnapshot()
        -> BASPlasticitySnapshot
    {
        return BASPlasticitySnapshot(
            shape: shape,
            weights: weights,
            updatesProcessed: updatesProcessed)
    }

    /// Restore fold state from a previously-exported
    /// snapshot。 Throws `.shapeMismatch` if the
    /// snapshot's shape doesn't match the fold's
    /// shape,or if `weights.count` doesn't match
    /// `preDim × postDim`。 Validation happens BEFORE
    /// any mutation — failure leaves fold state
    /// untouched。
    public func importSnapshot(
        _ snapshot: BASPlasticitySnapshot
    ) throws {
        guard snapshot.shape == shape else {
            throw BASBiomimeticSnapshotError
                .shapeMismatch(
                    reason: "snapshot.shape" +
                    " (\(snapshot.shape)) !=" +
                    " fold.shape (\(shape))")
        }
        let expectedSize =
            shape.preDim * shape.postDim
        guard snapshot.weights.count == expectedSize
        else {
            throw BASBiomimeticSnapshotError
                .shapeMismatch(
                    reason:
                    "snapshot.weights.count" +
                    " (\(snapshot.weights.count))" +
                    " != expected (\(expectedSize))")
        }
        weights = snapshot.weights
        updatesProcessed = snapshot.updatesProcessed
    }
}
