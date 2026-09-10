// MARK: - BASFrameContext+ObservationBundleAdapters
// chapter 四百三 / M957 — 系统熵 第五刀
//
// Phase 2 entropy 第五刀:1-arg `frameContext:` overloads for the
// 12 `withDerivedXxxObservationBundle` factories that today take
// `(turnID:sessionID:emittedAt:)` 3 args separately。Each overload
// is a 1-line wrapper that unpacks `BASFrameContext` and delegates
// to the existing 3-arg method,preserving byte-equality。
//
// ## Why this exists (system entropy framing)
//
// Per the entropy audit + M953 setup:
//
//   - **Threading entropy**: 12 sites in runTurn pass
//     (turnID, sessionID, emittedAt) as 3 separate args
//   - **Cognitive load**: every observation-bundle factory has
//     the same 3 init args repeated;readers must verify the
//     same triplet flows through each
//
// 1-arg overloads collapse this to:
//
//     frame.withDerivedXxxObservationBundle(frameContext: ctx)
//
// runTurn then threads ONE `BASFrameContext` value (M956
// already constructs it at the entry seam) instead of 3 fields。
//
// ## What this ships
//
//   - 12 `(frameContext: BASFrameContext)` overloads spanning:
//       * `BASContextFrame` (1) — presence
//       * `BASDecomposeFrame` (1) — decomposition
//       * `BASThoughtFrame` (10) — tribunal,risk,softHand,
//         updateTicket,worldPrior,leaseLife,hostConstitution,
//         thoughtFold,hippocampalMemory,neuralOrgan
//   - Each overload is purely additive;3-arg sigs unchanged
//   - Byte-equal to the 3-arg call path (verified by tests)
//
// ## Doctrine pins held
//
//   - All M953-M956 doctrine pins
//   - chapter 二百一一 single-source-of-truth — frameContext
//     unwraps via canonical accessors (no inline derivation)
//   - chapter 三百九二 replay-determinism — pure delegation
//   - ADR-014 OPT-IN — additive overloads;legacy 3-arg still
//     works

import Foundation
import BASMemory
import BASObservability
import BASRuntimeCore

// MARK: - BASContextFrame

extension BASContextFrame {

    /// 1-arg overload of `withDerivedPresenceObservationBundle`
    /// taking `BASFrameContext`。Delegates to the existing 3-arg
    /// method;byte-equal output。
    public func withDerivedPresenceObservationBundle(
        frameContext: BASFrameContext
    ) -> BASContextFrame {
        withDerivedPresenceObservationBundle(
            turnID: frameContext.turnID,
            sessionID: frameContext.sessionID,
            emittedAt: frameContext.emittedAt)
    }
}

// MARK: - BASDecomposeFrame

extension BASDecomposeFrame {

    /// 1-arg overload of
    /// `withDerivedDecompositionObservationBundle` taking
    /// `BASFrameContext`。
    public func withDerivedDecompositionObservationBundle(
        frameContext: BASFrameContext
    ) -> BASDecomposeFrame {
        withDerivedDecompositionObservationBundle(
            turnID: frameContext.turnID,
            sessionID: frameContext.sessionID,
            emittedAt: frameContext.emittedAt)
    }
}

// MARK: - BASThoughtFrame (10 factories)

extension BASThoughtFrame {

    public func withDerivedTribunalObservationBundle(
        frameContext: BASFrameContext
    ) -> BASThoughtFrame {
        withDerivedTribunalObservationBundle(
            turnID: frameContext.turnID,
            sessionID: frameContext.sessionID,
            emittedAt: frameContext.emittedAt)
    }

    public func withDerivedRiskObservationBundle(
        frameContext: BASFrameContext
    ) -> BASThoughtFrame {
        withDerivedRiskObservationBundle(
            turnID: frameContext.turnID,
            sessionID: frameContext.sessionID,
            emittedAt: frameContext.emittedAt)
    }

    public func withDerivedSoftHandObservationBundle(
        renderedOutput: BASRenderedOutput,
        frameContext: BASFrameContext
    ) -> BASThoughtFrame {
        withDerivedSoftHandObservationBundle(
            renderedOutput: renderedOutput,
            turnID: frameContext.turnID,
            sessionID: frameContext.sessionID,
            emittedAt: frameContext.emittedAt)
    }

    public func withDerivedUpdateTicketObservationBundle(
        updateTickets: [BASUpdateTicket],
        frameContext: BASFrameContext
    ) -> BASThoughtFrame {
        withDerivedUpdateTicketObservationBundle(
            updateTickets: updateTickets,
            turnID: frameContext.turnID,
            sessionID: frameContext.sessionID,
            emittedAt: frameContext.emittedAt)
    }

    public func withDerivedWorldPriorObservationBundle(
        frameContext: BASFrameContext
    ) -> BASThoughtFrame {
        withDerivedWorldPriorObservationBundle(
            turnID: frameContext.turnID,
            sessionID: frameContext.sessionID,
            emittedAt: frameContext.emittedAt)
    }

    public func withDerivedLeaseLifeObservationBundle(
        budgetFrame: BASBudgetFrame,
        frameContext: BASFrameContext
    ) -> BASThoughtFrame {
        withDerivedLeaseLifeObservationBundle(
            budgetFrame: budgetFrame,
            turnID: frameContext.turnID,
            sessionID: frameContext.sessionID,
            emittedAt: frameContext.emittedAt)
    }

    public func withDerivedHostConstitutionObservationBundle(
        constitution: BASHostConstitution?,
        versionTree: BASHostVersionTree?,
        forgetRequest: BASForgetRequest?,
        frameContext: BASFrameContext
    ) -> BASThoughtFrame {
        withDerivedHostConstitutionObservationBundle(
            constitution: constitution,
            versionTree: versionTree,
            forgetRequest: forgetRequest,
            turnID: frameContext.turnID,
            sessionID: frameContext.sessionID,
            emittedAt: frameContext.emittedAt)
    }

    public func withDerivedThoughtFoldObservationBundle(
        fold: BASThoughtFold,
        frameContext: BASFrameContext
    ) -> BASThoughtFrame {
        withDerivedThoughtFoldObservationBundle(
            fold: fold,
            turnID: frameContext.turnID,
            sessionID: frameContext.sessionID,
            emittedAt: frameContext.emittedAt)
    }

    public func withDerivedHippocampalMemoryObservationBundle(
        memoryBundle: BASMemoryBundle?,
        frameContext: BASFrameContext
    ) -> BASThoughtFrame {
        withDerivedHippocampalMemoryObservationBundle(
            memoryBundle: memoryBundle,
            turnID: frameContext.turnID,
            sessionID: frameContext.sessionID,
            emittedAt: frameContext.emittedAt)
    }

    public func withDerivedNeuralOrganObservationBundle(
        frameContext: BASFrameContext
    ) -> BASThoughtFrame {
        withDerivedNeuralOrganObservationBundle(
            turnID: frameContext.turnID,
            sessionID: frameContext.sessionID,
            emittedAt: frameContext.emittedAt)
    }
}
