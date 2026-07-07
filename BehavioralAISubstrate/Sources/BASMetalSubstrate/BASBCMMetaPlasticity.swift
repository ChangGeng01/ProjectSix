// MARK: - BASBCMMetaPlasticity — chapter 四百六十九 / M1253
// 系统熵 reduction
//
// **POST-PHASE-3 FEATURE chapter 3** — adaptive
// modification-threshold meta-plasticity (BCM rule
// from Bienenstock-Cooper-Munro 1982)。 Extends
// chapter 454/457 plasticity primitives with a typed
// adaptive threshold that itself adapts based on
// post-synaptic activity history。
//
// ## Why this exists (system entropy framing)
//
// Chapters 454/457 ship 4 plasticity rules (Hebbian +
// antiHebbian + outcomeModulated + STDP)。 Each uses
// a FIXED learning rate α and FIXED STDP params (A/τ)。
// But biology doesn't:synapses regulate their own
// learning rates via meta-plasticity。 BCM rule:
//
//   ΔW = pre · post · (post - θ)
//
// where θ is a SLIDING MODIFICATION THRESHOLD that
// tracks recent post-synaptic activity (mean of post²
// over a temporal window)。 Effect:
//
//   - When post < θ → ΔW negative (LTD-like)
//   - When post > θ → ΔW positive (LTP-like)
//   - θ adapts:high post activity → θ rises → more
//     post needed to trigger LTP → homeostatic
//     stability against runaway potentiation
//
// chapter 469 ships this as a typed actor primitive
// parallel to BASPlasticityFold,not bundled into the
// existing rule enum (BCM's adaptive θ doesn't fit
// the fixed-α schema)。
//
// ## What this ships (M1253)
//
//   - `BASBCMMetaPlasticityShape` typed shape with
//     dimensions + learning rate + threshold time
//     constant
//   - `BASBCMMetaPlasticity` actor maintaining weight
//     matrix + sliding threshold θ
//   - `apply(pre:post:)` typed update returning
//     the per-update delta + new threshold value
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed shape + clamped
//     parameters
//   - chapter 二百一一 — one BCM primitive;not
//     branched into existing rule enum
//   - chapter 三百九二 — replay-determinism (weight
//     + threshold evolution deterministic per
//     (pre,post) sequence)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (additive primitive)
//   - 红线 7 — weight updates are observation-derived,
//     not commitment
//   - ADR-014 OPT-IN — additive

import Foundation

// MARK: - Typed shape

// ⚖️ P4 遗留清算判决 (RSI 章程 2026-07-07):本文件 = 全库唯一二阶可塑性基元,
// 调用者 = Tests + doctrine 文本(审计读者2实锤)。封存为【二阶禁区证物】标本:
// 章程教义第④级(机器改规则)= 禁止;本基元永不引为"已有基建",激活它 = 推翻
// ADR-021/ADR-018-P4,需操作员战役级新证据。保留原因:删除厌恶 + 证物价值。
public struct BASBCMMetaPlasticityShape:
    Equatable, Hashable, Sendable, Codable
{

    /// Pre-synaptic feature dim P。 Clamped >= 1。
    public let preDim: Int

    /// Post-synaptic feature dim Q。 Clamped >= 1。
    public let postDim: Int

    /// Base learning rate α。 Clamped >= 0。
    public let learningRate: Float

    /// Threshold time constant τ_θ:fraction of recent
    /// post² to mix into θ on each update。 Clamped to
    /// (0, 1]。 Larger → θ adapts slower (longer
    /// memory of past activity)。 Smaller → θ adapts
    /// faster (shorter window)。 Default 0.05 ≈ 20-
    /// update memory。
    public let thresholdTimeConstant: Float

    /// Initial threshold value θ_0。 Clamped >= 0。
    public let initialThreshold: Float

    public init(
        preDim: Int,
        postDim: Int,
        learningRate: Float = 0.01,
        thresholdTimeConstant: Float = 0.05,
        initialThreshold: Float = 0.5
    ) {
        self.preDim = max(1, preDim)
        self.postDim = max(1, postDim)
        self.learningRate = max(0, learningRate)
        self.thresholdTimeConstant =
            max(1e-6, min(1.0, thresholdTimeConstant))
        self.initialThreshold =
            max(0, initialThreshold)
    }
}

// MARK: - Typed update bundle

public struct BASBCMMetaPlasticityUpdate:
    Equatable, Hashable, Sendable, Codable
{

    public let pre: [Float]
    public let post: [Float]

    /// Threshold value θ BEFORE this update。
    public let priorThreshold: Float

    /// Threshold value θ AFTER this update (sliding
    /// average of post² mixed in via
    /// thresholdTimeConstant)。
    public let updatedThreshold: Float

    /// Per-element weight delta applied this update。
    public let weightDelta: [Float]

    /// Weight matrix snapshot AFTER applying delta。
    public let updatedWeightSnapshot: [Float]

    public let updateIndex: Int

    public init(
        pre: [Float],
        post: [Float],
        priorThreshold: Float,
        updatedThreshold: Float,
        weightDelta: [Float],
        updatedWeightSnapshot: [Float],
        updateIndex: Int
    ) {
        self.pre = pre
        self.post = post
        self.priorThreshold = priorThreshold
        self.updatedThreshold = updatedThreshold
        self.weightDelta = weightDelta
        self.updatedWeightSnapshot =
            updatedWeightSnapshot
        self.updateIndex = max(0, updateIndex)
    }
}

// MARK: - Typed snapshot bundle

/// Codable snapshot of a `BASBCMMetaPlasticity` actor's
/// internal state at a point in time。 chapter 455-style
/// cross-turn persistence parity:weight matrix +
/// sliding threshold θ + update counter,with the shape
/// stored alongside so import can validate dimensional
/// compatibility before mutating。 Closes the chapter
/// 467/468 checkpoint→replay gap where BCM learned state
/// was silently dropped (BCM had no snapshot surface)。
public struct BASBCMMetaPlasticitySnapshot:
    Codable, Equatable, Hashable, Sendable
{

    /// Shape the snapshot was taken at。 Import requires
    /// matching shape on the target actor。
    public let shape: BASBCMMetaPlasticityShape

    /// Weight matrix flattened (preDim × postDim)。
    public let weights: [Float]

    /// Sliding modification threshold θ at snapshot time。
    public let threshold: Float

    /// Number of apply() calls since reset()。
    public let updatesProcessed: Int

    public init(
        shape: BASBCMMetaPlasticityShape,
        weights: [Float],
        threshold: Float,
        updatesProcessed: Int
    ) {
        self.shape = shape
        self.weights = weights
        self.threshold = threshold
        self.updatesProcessed =
            max(0, updatesProcessed)
    }
}

// MARK: - Typed error

public enum BASBCMMetaPlasticityError:
    Error, Equatable, Sendable, Codable
{
    case shapeMismatch(reason: String)
}

// MARK: - Actor

/// Substrate-side BCM meta-plasticity actor。
/// Maintains weight matrix W:(preDim × postDim) +
/// sliding modification threshold θ across apply()
/// calls。 chapter 469 / M1253。
public actor BASBCMMetaPlasticity {

    public nonisolated let shape:
        BASBCMMetaPlasticityShape

    private var weights: [Float]
    private var threshold: Float
    private var updatesProcessed: Int = 0

    public init(shape: BASBCMMetaPlasticityShape) {
        self.shape = shape
        self.weights = Array(
            repeating: 0,
            count: shape.preDim * shape.postDim)
        self.threshold = shape.initialThreshold
    }

    public func currentWeightsSnapshot() -> [Float] {
        return weights
    }

    public func currentThreshold() -> Float {
        return threshold
    }

    public func updateCount() -> Int {
        return updatesProcessed
    }

    /// Reset weights + threshold to initial state。
    public func reset() {
        weights = Array(
            repeating: 0,
            count: shape.preDim * shape.postDim)
        threshold = shape.initialThreshold
        updatesProcessed = 0
    }

    /// Apply one BCM update。 Algorithm:
    ///
    ///   ΔW[i, j] = α · pre[i] · post[j] · (post[j] - θ)
    ///   θ_new = (1 - τ_θ) · θ_old + τ_θ · mean(post²)
    ///
    /// The threshold update is performed BEFORE
    /// computing ΔW with the post values so callers
    /// see consistent (W, θ) state:after apply,both
    /// reflect this update。
    public func apply(
        pre: [Float],
        post: [Float]
    ) throws -> BASBCMMetaPlasticityUpdate {
        guard pre.count == shape.preDim else {
            throw BASBCMMetaPlasticityError
                .shapeMismatch(
                    reason: "pre.count" +
                    " (\(pre.count)) must equal" +
                    " preDim (\(shape.preDim))")
        }
        guard post.count == shape.postDim else {
            throw BASBCMMetaPlasticityError
                .shapeMismatch(
                    reason: "post.count" +
                    " (\(post.count)) must equal" +
                    " postDim (\(shape.postDim))")
        }
        let priorTheta = threshold
        // ΔW[i, j] = α · pre[i] · post[j] · (post[j] - θ)
        var delta: [Float] = Array(
            repeating: 0,
            count: shape.preDim * shape.postDim)
        for i in 0..<shape.preDim {
            for j in 0..<shape.postDim {
                delta[i * shape.postDim + j] =
                    shape.learningRate
                    * pre[i]
                    * post[j]
                    * (post[j] - priorTheta)
            }
        }
        // Apply delta to weights
        for k in 0..<weights.count {
            weights[k] += delta[k]
        }
        // Update threshold:θ_new = (1-τ)·θ + τ·mean(post²)
        var sumSq: Float = 0
        for v in post {
            sumSq += v * v
        }
        let meanSq = sumSq / Float(shape.postDim)
        let newTheta =
            (1 - shape.thresholdTimeConstant)
            * priorTheta
            + shape.thresholdTimeConstant * meanSq
        threshold = newTheta
        let currentIndex = updatesProcessed
        updatesProcessed += 1
        return BASBCMMetaPlasticityUpdate(
            pre: pre,
            post: post,
            priorThreshold: priorTheta,
            updatedThreshold: newTheta,
            weightDelta: delta,
            updatedWeightSnapshot: weights,
            updateIndex: currentIndex)
    }

    // MARK: - chapter 455-parity snapshot persistence

    /// Capture an immutable snapshot of the actor's
    /// current weight matrix + sliding threshold θ +
    /// update counter。 Safe to encode/persist (Codable
    /// via BASBCMMetaPlasticitySnapshot)。
    public func exportSnapshot()
        -> BASBCMMetaPlasticitySnapshot
    {
        return BASBCMMetaPlasticitySnapshot(
            shape: shape,
            weights: weights,
            threshold: threshold,
            updatesProcessed: updatesProcessed)
    }

    /// Restore actor state from a previously-exported
    /// snapshot。 Throws `.shapeMismatch` if the
    /// snapshot's shape doesn't match the actor's shape,
    /// or if `weights.count` doesn't match
    /// `preDim × postDim`。 Validation happens BEFORE any
    /// mutation — failure leaves actor state untouched。
    public func importSnapshot(
        _ snapshot: BASBCMMetaPlasticitySnapshot
    ) throws {
        guard snapshot.shape == shape else {
            throw BASBCMMetaPlasticityError
                .shapeMismatch(
                    reason: "snapshot.shape" +
                    " (\(snapshot.shape)) !=" +
                    " actor.shape (\(shape))")
        }
        let expectedSize =
            shape.preDim * shape.postDim
        guard snapshot.weights.count == expectedSize
        else {
            throw BASBCMMetaPlasticityError
                .shapeMismatch(
                    reason:
                    "snapshot.weights.count" +
                    " (\(snapshot.weights.count))" +
                    " != expected (\(expectedSize))")
        }
        weights = snapshot.weights
        threshold = snapshot.threshold
        updatesProcessed = snapshot.updatesProcessed
    }
}
