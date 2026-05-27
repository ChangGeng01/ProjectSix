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

    /// chapter 一千零十.5 / M3760 — Round-20 HIGH-1 fix:derive
    /// `coreSeatNames` and `watcherNames` structurally from
    /// `BASAgentRole.allCases` via an EXHAUSTIVE switch。 Adding
    /// a new role case fails compile here — forces explicit
    /// categorization,preventing silent drift。
    ///
    /// Pre-fix:hardcoded String literal sets。 If `BASAgentRole`
    /// added (say) a 10th core agent,this validator silently
    /// classified it as "unknown" under `.all` tier → false
    /// MISMATCH。 Same drift-class as ch 1000.5 single-canonical
    /// doctrine。
    private enum RoleCategory {
        case core
        case watcher
        case sealed
    }

    /// Exhaustive categorization。 Swift's exhaustivity check
    /// fails compile if a new BASAgentRole case is added without
    /// updating this switch — the canonical drift detector。
    private static func category(
        of role: BASAgentRole
    ) -> RoleCategory {
        switch role {
        // Core 9 — always-available per plan PHASE 1-3
        case .scout, .memory, .planner, .critic,
             .hostAlignment, .risk, .surface,
             .sovereignSentinel, .evolutionShadow:
            return .core
        // Watcher 7 — quiet observers per plan PHASE 5
        case .anomalyWatcher, .gaslightWatcher,
             .memoryPollutionWatcher, .hostDriftWatcher,
             .toolInjectionWatcher, .axisDeviationWatcher,
             .sanctumLeakWatcher:
            return .watcher
        // Sovereign-sealed 4 — LOW tier, no user customization
        case .actionPermit, .deleteRollbackSeal,
             .memorySeal, .compareModerator:
            return .sealed
        }
    }

    /// Canonical core-tier seat names — derived from
    /// `BASAgentRole.allCases` at type-init time。 Lowercased
    /// for case-insensitive match against
    /// `Activation.activeAgents`。
    internal static let coreSeatNames: Set<String> = {
        Set(BASAgentRole.allCases
            .filter { category(of: $0) == .core }
            .map { $0.rawValue.lowercased() })
    }()

    /// Canonical watcher role names — derived from
    /// `BASAgentRole.allCases`。 Pre-ch-1010.5 drift now
    /// impossible:adding a watcher case bumps this set
    /// automatically。
    internal static let watcherNames: Set<String> = {
        Set(BASAgentRole.allCases
            .filter { category(of: $0) == .watcher }
            .map { $0.rawValue.lowercased() })
    }()

    /// Canonical reference skill agent names — these have NO
    /// `BASAgentRole` enum counterpart (per ch 1010.5 Round-20
    /// LOW-3 audit observation;plan PHASE 6 ch 973 documents
    /// them but no enum case shipped yet)。 Hardcoded set is
    /// honest doctrine until the future arc adds the cases。
    internal static let skillNames: Set<String> = [
        "writingskill", "codeskill",
        "researchskill", "schedulingskill",
    ]

    /// Validate the activation for tier / activeAgents
    /// consistency。 Returns sorted list of diagnostic strings
    /// — empty when no inconsistencies detected (other than
    /// the informational consistency message)。
    ///
    /// chapter 一千零十.5 / M3760 — Round-20 CRITICAL-3 fix:
    /// adopts U+001F unit-separator for diagnostic field
    /// joining。 Pre-fix `:` + `=` separators were vulnerable
    /// to injection — a host setting
    /// `BAS_ACTIVE_AGENTS=foo:tier=all:agent=evil,Planner`
    /// could inject a synthetic diagnostic that parsed as a
    /// fake mismatch。 Post-fix U+001F is illegal in normal
    /// text so collisions cannot happen。
    ///
    /// Diagnostic format (post-fix):
    ///   `tier.mismatch\u{001F}tier=<tier>\u{001F}agent=<name>`
    ///   `tier.consistent\u{001F}tier=<tier>\u{001F}agents=<count>`
    public static func validate(
        _ activation: BASAgentFabricGate.Activation
    ) -> [String] {
        var diagnostics: [String] = []
        let activeNames = activation.activeAgents.map {
            $0.lowercased()
        }
        let sep = "\u{001F}"
        switch activation.tier {
        case .core:
            // Detect any watcher / skill names in activeAgents
            // — they violate the .core tier semantics
            for name in activeNames {
                if watcherNames.contains(name) ||
                    skillNames.contains(name)
                {
                    diagnostics.append(
                        "tier.mismatch\(sep)tier=core" +
                        "\(sep)agent=\(name)")
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
                        "tier.mismatch\(sep)tier=all" +
                        "\(sep)agent=\(name)")
                }
            }
        }
        // Append informational consistency message when no
        // mismatches were found (helps audit triage)
        if diagnostics.isEmpty {
            diagnostics.append(
                "tier.consistent\(sep)tier=" +
                "\(activation.tier.rawValue)\(sep)agents=" +
                "\(activeNames.count)")
        }
        return diagnostics.sorted()
    }
}
