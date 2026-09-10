// MARK: - BASEBrainTurnRequest+FrameContext — chapter 四百三 / M954
//
// Phase 2 系统熵 第二刀:single-source derivation extension that
// materializes `BASFrameContext` (M953) from the typed inputs
// the coordinator already holds at the seam where it derives
// sessionID + turnID inline today。
//
// ## Why this exists (system entropy framing)
//
// `EBrainRuntimeCoordinator.runTurn(_:)` derives `sessionID` +
// `turnID` inline at L756-762 then threads them through 12
// downstream observation-bundle factories as 3 separate args。
// The formula could re-implement at any consumer site,causing
// drift。
//
// M953 shipped `BASFrameContext` as the typed triplet。M954
// ships the canonical extension that runTurn (and any future
// V2 actor) calls instead of inlining the formula。chapter
// 二百一一 single-source-of-truth — formula lives in ONE place。
//
// ## What this ships
//
//   - `BASEBrainTurnRequest.makeFrameContext(rawContextFrame:
//     routedBudget:)` factory method
//   - Pure function: same input → same output (chapter 三百九二
//     replay-determinism)
//   - Documentation pin: when runTurn V2 lands,it MUST call
//     this factory rather than inlining the join formula
//
// ## Doctrine pins held
//
//   - All M953 doctrine pins
//   - chapter 二百一一 single-source-of-truth — formula lives
//     in `BASFrameContext.init(hostID:taskTypeRaw:runModeRaw:
//     recordedAt:)` and this extension routes the right inputs
//     to it
//   - chapter 三百九二 replay-determinism — pure function
//   - ADR-014 OPT-IN — additive extension;V1 inline derivation
//     keeps working until V2 swaps it

import Foundation
import BASRuntimeCore
import BASOrchestration

extension BASEBrainTurnRequest {

    /// Canonical factory:materialize a `BASFrameContext` from
    /// `self` + the two frames runTurn already has at the
    /// derivation seam (L756-762)。
    ///
    /// **Rule pin (chapter 二百一一)**:future runTurn rewrites
    /// MUST call this factory instead of inlining the formula。
    /// Drift triggers the M955+ doctrine guardrail tests。
    public func makeFrameContext(
        rawContextFrame: BASContextFrame,
        routedBudget: BASBudgetFrame
    ) -> BASFrameContext {
        BASFrameContext(
            hostID: hostID,
            taskTypeRaw: rawContextFrame.taskType.rawValue,
            runModeRaw: routedBudget.runMode.rawValue,
            recordedAt: recordedAt)
    }
}
