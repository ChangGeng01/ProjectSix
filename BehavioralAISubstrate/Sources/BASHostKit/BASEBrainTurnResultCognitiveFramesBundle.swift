// MARK: - BASEBrainTurnResultCognitiveFramesBundle
// chapter 五百二十八 / M1489 — typed cognitive-frames
//                              cluster packaging surface
//
// Aggregates the 5 cognitive-frame fields of
// `BASEBrainTurnResult` into one typed input surface。
// 5th cluster bundle in the BASEBrainTurnResult fold
// arc (after evolution + sovereign + host +
// auditProjectionForward)。
//
// ## Why this exists
//
// `BASEBrainTurnResult.init(...)` has ~22 remaining
// args after the 4 cluster bundles (M1473/M1477/M1481/
// M1481-auditFwd) absorb 30 fields。 5 of the remaining
// args form a cohesive cognitive-processing-chain
// cluster:
//
//   1. contextFrame — L1/L3 input synthesis
//   2. decomposeFrame — L7 problem decomposition
//   3. memoryBundle — L8 memory retrieval
//   4. thoughtFrame — L11 candidate thoughts
//   5. thoughtFold — L7/L8 thought fold output
//
// All 5 represent SUCCESSIVE stages of the cognitive
// chain — context → decompose → memory → thought →
// fold。 Packaging into a typed bundle makes the
// cognitive-chain boundary visible at call sites that
// emit/consume turn results。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive surface only
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth — 5
//     cognitive frames via ONE typed surface
//   - chapter 三百九二:replay-determinism via Equatable
//     + Sendable
//   - chapter 四百二十九:typed-surface count 73 → 74
//   - ADR-014 OPT-IN:default behavior unchanged
//   - ADR-016 advances M1488 → M1489

import Foundation
import BASMemory
import BASOrchestration
import BASRuntimeCore

/// Typed-surface bundle packaging the 5 cognitive-frame
/// fields of `BASEBrainTurnResult`。 All 5 fields are
/// REQUIRED (non-optional) since the cognitive chain
/// always emits frames per turn。
public struct BASEBrainTurnResultCognitiveFramesBundle:
    Equatable, Sendable
{

    // MARK: - 5 cognitive-frame fields

    /// L1/L3 input synthesis frame (required)。
    public let contextFrame: BASContextFrame

    /// L7 problem decomposition frame (required)。
    public let decomposeFrame: BASDecomposeFrame

    /// L8 memory retrieval bundle (required)。
    public let memoryBundle: BASMemoryBundle

    /// L11 candidate thoughts frame (required)。
    public let thoughtFrame: BASThoughtFrame

    /// L7/L8 thought fold output (required)。
    public let thoughtFold: BASThoughtFold

    // MARK: - Construction

    public init(
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle,
        thoughtFrame: BASThoughtFrame,
        thoughtFold: BASThoughtFold
    ) {
        self.contextFrame = contextFrame
        self.decomposeFrame = decomposeFrame
        self.memoryBundle = memoryBundle
        self.thoughtFrame = thoughtFrame
        self.thoughtFold = thoughtFold
    }

    // MARK: - Coverage queries

    /// All 5 cognitive frames are non-optional,so the
    /// count is always 5。 Provided for shape symmetry
    /// with sibling bundles。
    public var populatedFieldCount: Int { 5 }

    /// Field count invariant — 5 cognitive frames。
    public static let cognitiveFrameCount: Int = 5
}
