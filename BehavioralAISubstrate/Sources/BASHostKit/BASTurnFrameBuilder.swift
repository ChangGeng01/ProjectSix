// MARK: - BASTurnFrameBuilder — chapter 四百三 / M961 — 系统熵 reduction
//
// Phase 2 entropy 第九刀:typed immutable accumulator that
// replaces runTurn's var-reassignment mutation pattern with
// a `with(...)`-based functional updates pattern。
//
// Per the chapter 四百三 entropy audit:
//
//   > Mutation entropy: 19 reassignments to var thoughtFrame
//   > + 5 to var boundActionPermit + 2 each to decomposeFrame
//   > / triScores / normalizedRiskDecisionPackage in runTurn。
//   > V2 actor adoption replaces this with immutable
//   > `BASTurnFrameBuilder.with(...)` chain。
//
// This commit ships the typed builder primitive。Future
// commits implement V2 actor stages that consume it。Existing
// V1 runTurn stays unchanged (ADR-014 OPT-IN)。
//
// ## What this ships (M961)
//
//   - `BASTurnFrameBuilder` immutable Sendable value type
//     holding (frameContext, routedBudget, contextFrame,
//     decomposeFrame, thoughtFrame, mergedChoice, riskCard,
//     permit, renderedOutput) — the most frequently mutated
//     locals in runTurn
//   - `init(frameContext:)` minimal init — all frame slots
//     start nil
//   - `with(...)` family — one method per slot,returns fresh
//     builder with the slot updated
//   - Convenience: `withFrameContext(_:)` for re-deriving
//     mid-turn (rare;mostly used by tests)
//
// ## Doctrine pins held
//
//   - 不变量 #1/#2/#3 — builder is observation plumbing
//   - 红线 7 hint-only — builder holds frames,not decisions
//   - chapter 一百八十五 anti-magic-number — fields typed
//   - chapter 二百一一 single-source-of-truth — ONE accumulator
//     pattern for V2 actor stages
//   - chapter 三百九二 replay-determinism — same chain → same
//     final builder (Equatable + value semantics)
//   - ADR-014 OPT-IN → purely additive

import Foundation
import BASMemory
import BASOrchestration
import BASPolicy
import BASRuntimeCore

/// Typed immutable accumulator for V2 runtime engine stages。
/// Replaces V1 runTurn's var-reassignment pattern。
public struct BASTurnFrameBuilder: Sendable {

    // MARK: - Identity (always present)

    public let frameContext: BASFrameContext

    // MARK: - Accumulating slots (nil until populated)

    public let routedBudget: BASBudgetFrame?
    public let contextFrame: BASContextFrame?
    public let decomposeFrame: BASDecomposeFrame?
    public let thoughtFrame: BASThoughtFrame?
    public let mergedChoice: BASMergedChoice?
    public let riskCard: BASRiskCard?
    public let permit: BASActionPermit?
    public let renderedOutput: BASRenderedOutput?

    // MARK: - Init

    public init(
        frameContext: BASFrameContext,
        routedBudget: BASBudgetFrame? = nil,
        contextFrame: BASContextFrame? = nil,
        decomposeFrame: BASDecomposeFrame? = nil,
        thoughtFrame: BASThoughtFrame? = nil,
        mergedChoice: BASMergedChoice? = nil,
        riskCard: BASRiskCard? = nil,
        permit: BASActionPermit? = nil,
        renderedOutput: BASRenderedOutput? = nil
    ) {
        self.frameContext = frameContext
        self.routedBudget = routedBudget
        self.contextFrame = contextFrame
        self.decomposeFrame = decomposeFrame
        self.thoughtFrame = thoughtFrame
        self.mergedChoice = mergedChoice
        self.riskCard = riskCard
        self.permit = permit
        self.renderedOutput = renderedOutput
    }

    // MARK: - Immutable updates (with-chain)

    public func with(
        routedBudget: BASBudgetFrame
    ) -> BASTurnFrameBuilder {
        BASTurnFrameBuilder(
            frameContext: frameContext,
            routedBudget: routedBudget,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice,
            riskCard: riskCard,
            permit: permit,
            renderedOutput: renderedOutput)
    }

    public func with(
        contextFrame: BASContextFrame
    ) -> BASTurnFrameBuilder {
        BASTurnFrameBuilder(
            frameContext: frameContext,
            routedBudget: routedBudget,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice,
            riskCard: riskCard,
            permit: permit,
            renderedOutput: renderedOutput)
    }

    public func with(
        decomposeFrame: BASDecomposeFrame
    ) -> BASTurnFrameBuilder {
        BASTurnFrameBuilder(
            frameContext: frameContext,
            routedBudget: routedBudget,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice,
            riskCard: riskCard,
            permit: permit,
            renderedOutput: renderedOutput)
    }

    public func with(
        thoughtFrame: BASThoughtFrame
    ) -> BASTurnFrameBuilder {
        BASTurnFrameBuilder(
            frameContext: frameContext,
            routedBudget: routedBudget,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice,
            riskCard: riskCard,
            permit: permit,
            renderedOutput: renderedOutput)
    }

    public func with(
        mergedChoice: BASMergedChoice
    ) -> BASTurnFrameBuilder {
        BASTurnFrameBuilder(
            frameContext: frameContext,
            routedBudget: routedBudget,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice,
            riskCard: riskCard,
            permit: permit,
            renderedOutput: renderedOutput)
    }

    public func with(
        riskCard: BASRiskCard
    ) -> BASTurnFrameBuilder {
        BASTurnFrameBuilder(
            frameContext: frameContext,
            routedBudget: routedBudget,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice,
            riskCard: riskCard,
            permit: permit,
            renderedOutput: renderedOutput)
    }

    public func with(
        permit: BASActionPermit
    ) -> BASTurnFrameBuilder {
        BASTurnFrameBuilder(
            frameContext: frameContext,
            routedBudget: routedBudget,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice,
            riskCard: riskCard,
            permit: permit,
            renderedOutput: renderedOutput)
    }

    public func with(
        renderedOutput: BASRenderedOutput
    ) -> BASTurnFrameBuilder {
        BASTurnFrameBuilder(
            frameContext: frameContext,
            routedBudget: routedBudget,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice,
            riskCard: riskCard,
            permit: permit,
            renderedOutput: renderedOutput)
    }
}
