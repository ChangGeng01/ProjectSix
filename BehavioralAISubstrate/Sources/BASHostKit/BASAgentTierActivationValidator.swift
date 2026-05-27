// MARK: - BASAgentTierActivationValidator
// chapter 一千零八 / M3745 — wires `BASAgentFabricGate.Tier`
// from 🪜 SCAFFOLD → ✅ WIRED (validation-only behavioral wire)
//
// ## The scaffold condition
//
// Per `Docs/SCAFFOLD_VS_WIRED.md` ch 996:
//   > `BASAgentFabricGate.Tier.core` / `.all` | 🪜 SCAFFOLD |
//   > parsed into Activation,surfaced in diagnostics,but NO
//   > Sources/ branches on it for roster filtering。 Decorative
//   > env-var echo per ch 995.5 doctrine。 Full tier-filter
//   > behavioral wire deferred to phase 9+ scope。
//
// Multi-chapter full tier-filter wire requires integrating 7
// watchers + 4 reference skill agents into the host pipeline。
// That's genuinely Phase 9+ work — NOT closable in 1 chapter
// honestly。
//
// BUT — there IS a real wire achievable today:**validation**
// of consistency between `tier` and `activeAgents`。 A host
// declaring `.core` tier while listing watcher names in
// `BAS_ACTIVE_AGENTS` has an internally-inconsistent config。
// The validator catches this BEFORE the pipeline runs。
//
// ## What ch 1008 ships
//
// `BASAgentTierActivationValidator` — pure-fn that takes an
// `Activation` (tier + activeAgents + transcriptMode +
// fabricEnabled) and returns a list of validation diagnostics
// (warnings,not errors — the host pipeline still runs)。
//
// Diagnostic kinds:
//   - `tier.mismatch:tier=core:agent=<watcher-name>` — `.core`
//     tier but activeAgents includes a watcher / skill name
//   - `tier.mismatch:tier=all:agent=<unknown>` — `.all` tier
//     but activeAgents includes an UNKNOWN name (not a core
//     seat,not a watcher,not a skill)
//   - `tier.consistent:tier=<tier>:agents=<count>` —
//     successful validation (informational)
//
// ## Why this is a real wire
//
// 1. The validator EMITS substrate-observable signal per turn
// 2. The diagnostic strings can be threaded into the audit
//    ledger (mirror ch 1003 / 1006 / 1007 pattern)
// 3. The validation logic encodes the tier semantics
//    explicitly — future watcher / skill integration only needs
//    to update the validator's name lists,not invent new
//    semantics
//
// ## What this is NOT
//
// - NOT a full tier-based roster filter — `.core` and `.all`
//   still produce byte-equal dispatcher behavior since no
//   watcher / skill is in the pipeline yet。
// - NOT a fatal error — diagnostics warn,pipeline still runs
//   per ADR-014 OPT-IN principle (host can configure freely;
//   substrate just records the inconsistency)
//
// ## Discipline
//
// - Additive only — no existing API changed
// - Pure-fn — deterministic byte-equal output
// - Sorted output for byte-equal across runs

import Foundation
import BASMemory

public enum BASAgentTierActivationValidator {

    /// Canonical core-tier seat role names (case-insensitive
    /// match against `Activation.activeAgents`)。 These are the
    /// 9 core seats per plan PHASE 1-3。
    private static let coreSeatNames: Set<String> = [
        "scout", "planner", "critic", "memory",
        "hostalignment", "risk", "surface",
        "sovereignsentinel", "evolutionshadow",
    ]

    /// Canonical watcher role names (when included in
    /// activeAgents,implies `.all` tier)。 These are the 7
    /// watchers per plan PHASE 5。
    private static let watcherNames: Set<String> = [
        "anomalywatcher", "gaslightwatcher",
        "memorypollutionwatcher", "hostdriftwatcher",
        "toolinjectionwatcher", "axisdeviationwatcher",
        "sanctumleakwatcher",
    ]

    /// Canonical reference skill agent names (when included,
    /// implies `.all` tier)。 The 4 reference skill agents per
    /// plan PHASE 6 ch 973。
    private static let skillNames: Set<String> = [
        "writingskill", "codeskill",
        "researchskill", "schedulingskill",
    ]

    /// Validate the activation for tier / activeAgents
    /// consistency。 Returns sorted list of diagnostic strings
    /// — empty when no inconsistencies detected (other than
    /// the informational consistency message)。
    public static func validate(
        _ activation: BASAgentFabricGate.Activation
    ) -> [String] {
        var diagnostics: [String] = []
        let activeNames = activation.activeAgents.map {
            $0.lowercased()
        }
        switch activation.tier {
        case .core:
            // Detect any watcher / skill names in activeAgents
            // — they violate the .core tier semantics
            for name in activeNames {
                if watcherNames.contains(name) ||
                    skillNames.contains(name)
                {
                    diagnostics.append(
                        "tier.mismatch:tier=core:agent=\(name)")
                }
            }
        case .all:
            // Detect unknown names — not core,not watcher,
            // not skill
            for name in activeNames {
                if !coreSeatNames.contains(name) &&
                    !watcherNames.contains(name) &&
                    !skillNames.contains(name)
                {
                    diagnostics.append(
                        "tier.mismatch:tier=all:agent=\(name)")
                }
            }
        }
        // Append informational consistency message when no
        // mismatches were found (helps audit triage)
        if diagnostics.isEmpty {
            diagnostics.append(
                "tier.consistent:tier=" +
                "\(activation.tier.rawValue):agents=" +
                "\(activeNames.count)")
        }
        return diagnostics.sorted()
    }
}
