import Foundation
import BASMemory
import BASPolicy
import BASRuntimeCore

public struct BASEBrainTurnRequest: Codable, Equatable, Sendable {
    public var userInput: String
    public var deviceState: BASDeviceState
    public var hostID: String
    public var recordedAt: Date
    public var riskHint: BASBrainRiskLevel?
    public var feedbackEvent: BASFeedbackEvent?
    public var activeKillSwitches: [BASKillSwitchID]
    /// Recent cross-turn summary/history entries (most-recent-last). OPT-IN per-turn context for the
    /// SSM caution operator (the 3rd of its three sources). Default empty ⇒ the operator's history
    /// source is empty; combined with the operator's default-off flag, the turn is byte-equal to before
    /// (ADR-014 / 红线 7). The host populates this from its summary ring; it is NOT echoed into the
    /// turn result, so default-[] does not change any result bytes.
    public var turnHistory: [String]
    /// OPT-IN cross-turn SSM hidden state carried from the prior turn's observation
    /// (`BASMambaSSMTurnObservation.ssmStateOut`). nil ⇒ the SSM caution operator starts a FRESH
    /// recurrence (byte-equal-off). The host folds the prior turn's `ssmStateOut` here to make the
    /// operator TEMPORAL — caution reflects the sustained-pressure trajectory across turns. Not echoed
    /// into the result ⇒ result bytes unchanged; default nil ⇒ identical to the stateless operator.
    public var priorSSMState: [Float]?
    /// OPT-IN per-turn effort plan (the surprise-gated tier from `BASEffortGovernor` / `BASBrainChat`). nil ⇒ no
    /// effort sizing — byte-equal with the pre-effort pipeline (same pattern as `turnHistory` / `priorSSMState`).
    /// When set, `runTurn` FLOORS the deliberation pass budget by
    /// `BASEffortBudgetConsumer.deliberationPasses(applied)` (mirrors the thermal floor): a low tier spends fewer
    /// refinement passes (avoided compute), and it can only TIGHTEN within the thermally/lease-routed budget —
    /// never raise it (and always ≥ 1 pass). Not echoed into the result, so default-nil changes no result bytes.
    public var effortPlan: BASEffortPlan?

    public init(
        userInput: String,
        deviceState: BASDeviceState,
        hostID: String,
        recordedAt: Date = .now,
        riskHint: BASBrainRiskLevel? = nil,
        feedbackEvent: BASFeedbackEvent? = nil,
        activeKillSwitches: [BASKillSwitchID] = [],
        turnHistory: [String] = [],
        priorSSMState: [Float]? = nil,
        effortPlan: BASEffortPlan? = nil
    ) {
        self.userInput = userInput
        self.deviceState = deviceState
        self.hostID = hostID
        self.recordedAt = recordedAt
        self.riskHint = riskHint
        self.feedbackEvent = feedbackEvent
        self.activeKillSwitches = activeKillSwitches
        self.turnHistory = turnHistory
        self.priorSSMState = priorSSMState
        self.effortPlan = effortPlan
    }

    private enum CodingKeys: String, CodingKey {
        case userInput, deviceState, hostID, recordedAt
        case riskHint, feedbackEvent, activeKillSwitches, turnHistory, priorSSMState, effortPlan
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userInput = try c.decode(String.self, forKey: .userInput)
        deviceState = try c.decode(BASDeviceState.self, forKey: .deviceState)
        hostID = try c.decode(String.self, forKey: .hostID)
        recordedAt = try c.decode(Date.self, forKey: .recordedAt)
        riskHint = try c.decodeIfPresent(BASBrainRiskLevel.self, forKey: .riskHint)
        feedbackEvent = try c.decodeIfPresent(BASFeedbackEvent.self, forKey: .feedbackEvent)
        activeKillSwitches = try c.decodeIfPresent(
            [BASKillSwitchID].self, forKey: .activeKillSwitches) ?? []
        // Backward-compatible: pre-existing encodings have no turnHistory ⇒ [].
        turnHistory = try c.decodeIfPresent([String].self, forKey: .turnHistory) ?? []
        // Backward-compatible: absent ⇒ nil (stateless operator).
        priorSSMState = try c.decodeIfPresent([Float].self, forKey: .priorSSMState)
        // Backward-compatible: absent ⇒ nil (no effort sizing — byte-equal pipeline).
        effortPlan = try c.decodeIfPresent(BASEffortPlan.self, forKey: .effortPlan)
    }
}
