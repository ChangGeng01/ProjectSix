import Foundation

// 六十二.6 — typed restraint surface set (for "no permit" path).
//
// ## Why this exists
//
// Manifesto v3 第六.7 says: "若没有 ActionPermit / SovereignWarrant /
// 快照与连续性证明 — SDK 才能真正执行；否则最多到：compare /
// draft-only / local-only / delay / silent stub". These are
// the 5 typed restraint surfaces the system falls back to
// when execution permits aren't issued.
//
// QinaoUI 已 ship 6/6 surface family (compare / draft / delay /
// boundary / silentStub / localOnly + RiskSurfaceMatrix)
// in QinaoUI module. 六十二.6 names these 5 restraint
// surfaces as a typed enum at the doctrine layer so audit
// can grep "what's the legitimate fallback when permit
// fails" without crossing the QinaoUI module boundary.
//
// ## Properties
//
// - 5 cases — exactly the 5 doctrine-named restraint surfaces.
// - Stable raw values matching QinaoUI file naming.

public enum BASMotherboardRestraintSurface:
    String, Sendable, Equatable, Hashable, Codable,
    CaseIterable
{
    /// Compare panel — show alternatives without executing.
    case compare

    /// Draft only — produce content without committing.
    case draftOnly

    /// Local only — execute on-device without external
    /// side effects.
    case localOnly

    /// Delay packet — defer execution to a future moment.
    case delay

    /// Silent stub — record the intent without surfacing.
    case silentStub
}

public extension BASMotherboardRestraintSurface {
    /// The corresponding QinaoUI surface file (already
    /// shipped). Audit code can cross-reference this string
    /// against the QinaoUI module without importing it.
    var implementingFile: String {
        switch self {
        case .compare:
            return "QinaoComparePanel.swift"
        case .draftOnly:
            return "QinaoDraftShell.swift"
        case .localOnly:
            return "QinaoLocalOnlySheet.swift"
        case .delay:
            return "QinaoDelayPacket.swift"
        case .silentStub:
            return "QinaoSilentStub.swift"
        }
    }

    /// All 5 restraints fall back from the same doctrine —
    /// permit-gate failure (`BASMotherboardRuntimeStep.permitGate`
    /// did not clear).
    var fallbackFrom: BASMotherboardRuntimeStep {
        .permitGate
    }
}
