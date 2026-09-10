import Foundation

// 六十二.4 — typed Sovereign Microkernel emergency operations.
//
// ## Why this exists
//
// Manifesto v3 第三节内核一 lists 4 specific emergency
// operations the sovereign microkernel **must** support:
//
// - Dead Stop
// - Rollback
// - Quarantine
// - Clean Reboot
//
// These 4 are the **physical realization of Doctrine 5**
// ("删除回滚净启第一公民"). Without typed pin, audit code
// can't grep "which emergency operations are reachable" in
// a single typed surface; ops are scattered across
// `BASSovereignSnapshotManager.rollback`,
// `BASSovereignCleanRebootCoordinator`, etc.
//
// 六十二.4 ships the typed surface. Existing implementations
// stay where they are; this file is the catalog.
//
// ## Properties
//
// - **All 4 ops trace to `BASMotherboardPrinciple.deleteRollbackRebootFirstClass`.**
// - **All 4 ops produce `BASMotherboardSovereignDuty.emergencyOps`.**
// - **Severity ordering pinned**: deadStop > quarantine > rollback > cleanReboot
//   (deadStop is most disruptive — halt everything; cleanReboot is
//   most graceful — wipe + restart in known-good state).

public enum BASMotherboardSovereignEmergencyOp:
    String, Sendable, Equatable, Hashable, Codable,
    CaseIterable
{
    /// Halt all execution immediately. Most disruptive op;
    /// used when integrity is unverifiable.
    case deadStop
    /// Restore from a known-good snapshot. Reverses recent
    /// changes; partial impact.
    case rollback
    /// Isolate a component (a layer / a tool / a session)
    /// so it cannot affect the rest while diagnostics run.
    case quarantine
    /// Wipe transient state and restart from a clean
    /// baseline. Most graceful op; used after rollback can't
    /// resolve the issue.
    case cleanReboot
}

public extension BASMotherboardSovereignEmergencyOp {
    /// All 4 ops are realizations of the
    /// `.deleteRollbackRebootFirstClass` principle.
    var triggeredByPrinciple: BASMotherboardPrinciple {
        .deleteRollbackRebootFirstClass
    }

    /// All 4 ops are subsumed under the sovereign
    /// `.emergencyOps` duty.
    var producesDuty: BASMotherboardSovereignDuty {
        .emergencyOps
    }

    /// Severity ordering — lower rank = more disruptive.
    /// Pinned for audit policies that want to escalate
    /// from least-disruptive to most-disruptive.
    var severityRank: Int {
        switch self {
        case .deadStop: return 0     // most disruptive
        case .quarantine: return 1
        case .rollback: return 2
        case .cleanReboot: return 3   // most graceful
        }
    }
}
