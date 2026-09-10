// ch1055 / v1.0 §6 step 3 — pre-work sovereign gate (refuse BEFORE spending cognition).
//
// The gap audit found `runTurn` has NO pre-work sovereign gate: the verdict is computed AFTER the full
// cognition cascade, so a turn that should be refused still spends all the effort first. Editing the
// 2016-line coordinator to early-deny would require synthesizing a valid 52-field result mid-body —
// unsafe (R1 / 亏的不要上). The 小心翼翼 way is a STANDALONE gate the host calls BEFORE `runTurn` and
// skips the turn on deny: additive, no coordinator edit, byte-equal-off (a host that does not call it
// is completely unchanged).

import Foundation
import BASObservability   // BASKillSwitchID

/// The pre-work decision. `deny` carries a reason; the host must NOT call `runTurn` on a deny.
public enum BASSovereignPreflightDecision: Sendable, Equatable {
    case proceed
    case deny(reason: String)

    public var isProceed: Bool { if case .proceed = self { return true }; return false }
    public var denyReason: String? { if case .deny(let r) = self { return r }; return nil }
}

/// A cheap sovereign gate evaluated at turn entry, before any cognition. Pure / stateless.
public struct BASSovereignPreflightGate: Sendable {
    /// Kill-switch IDs that, if present on the request, deny the turn outright.
    private let denyingKillSwitches: Set<BASKillSwitchID>
    /// Host predicate: return a reason to deny, or nil to allow — lets the host bind its own
    /// hardNoGo / constitution boundary at entry without this type depending upward.
    private let hardNoGo: (@Sendable (BASEBrainTurnRequest) -> String?)?

    public init(denyingKillSwitches: Set<BASKillSwitchID> = [],
                hardNoGo: (@Sendable (BASEBrainTurnRequest) -> String?)? = nil) {
        self.denyingKillSwitches = denyingKillSwitches
        self.hardNoGo = hardNoGo
    }

    /// Evaluate the turn BEFORE any work. Order: a denying kill-switch on the request → deny; else
    /// the host `hardNoGo` predicate; else proceed. The host calls this first and skips `runTurn` on
    /// `.deny` — refusing early instead of after a full, wasted cognition cascade (§6 step 3).
    public func evaluate(_ request: BASEBrainTurnRequest) -> BASSovereignPreflightDecision {
        for ks in request.activeKillSwitches where denyingKillSwitches.contains(ks) {
            return .deny(reason: "kill_switch:\(ks.rawValue)")
        }
        if let hardNoGo, let reason = hardNoGo(request) {
            return .deny(reason: reason)
        }
        return .proceed
    }
}
