import Foundation
import BASPolicy
import BASRuntimeCore

/// L12 — pure selector that maps a turn's `BASActionPermit` +
/// `BASSovereignVerdict` (and other context) to a single
/// `BASSoftHandMode`.
///
/// ## Why this exists
///
/// Pre-M280 the `BASSoftHandMode` enum (compare / draft / delay
/// / boundary / silentStub) was schema-only. The runtime decision
/// "given an admit-permit and a verdict, which surface mode does
/// the host render" was implicit, scattered across host code. This
/// file lands the canonical mapping as a pure function so:
///
/// - Hosts get a one-call helper that takes the admit context and
///   returns the mode to render.
/// - Tests pin the mapping; future tweaks surface as a diff.
/// - Audit / observability layers can replay the mapping
///   independently of any specific host's rendering path.
///
/// ## Mapping rules
///
/// Severity escalates from low (pass) to high (deadStop). The
/// selector reads the worst signal (highest verdict level OR most
/// restrictive permit mode) and emits one mode:
///
/// | input                                      | mode        |
/// |--------------------------------------------|-------------|
/// | verdict ≥ deadStop / quarantine / rollback | silentStub  |
/// | verdict ≥ memoryFreeze / toolCut           | boundary    |
/// | verdict == throttle/shadowLock             | draft       |
/// | permit.mode == .block / .replace           | boundary    |
/// | permit.mode == .delay                      | delay       |
/// | permit.mode == .draftOnly / .compare       | compare     |
/// | permit.mode == .escalate                   | boundary    |
/// | permit.mode == .mirror / .localOnly        | draft       |
/// | permit.mode == .answer + verdict.pass      | draft       |
/// | (no permit, verdict.pass)                  | silentStub  |
///
/// `silentStub` is the fail-safe default — when in doubt, render
/// nothing actionable. The host can always upgrade explicitly via
/// `selectMode(...)` overrides; the selector itself never picks a
/// less-restrictive mode than the inputs imply.
public enum BASSoftHandModeSelector {

    /// Pure mode selector. Inputs that a turn already has by the
    /// time the surface is being chosen.
    ///
    /// - Parameters:
    ///   - permit: the L11 ActionPermit that gate-passed this
    ///     turn. May be `nil` only if the turn is purely advisory
    ///     and never asked for a permit (rare; selector treats nil
    ///     as silentStub).
    ///   - verdict: the L14 SovereignVerdict if any. `nil` when
    ///     the turn didn't trigger a verdict (default = pass).
    ///   - candidateCount: number of co-equal candidates the L9
    ///     dream-cycle produced. ≥2 hints at compare mode when
    ///     other signals don't override.
    /// - Returns: the canonical `BASSoftHandMode`.
    public static func selectMode(
        permit: BASActionPermit?,
        verdict: BASSovereignVerdict? = nil,
        candidateCount: Int = 0
    ) -> BASSoftHandMode {
        // 1. Verdict tier (highest priority — sovereign override).
        if let v = verdict {
            let lvl = v.verdictLevel
            // Catastrophic — render nothing actionable.
            if lvl.rank >= BASSovereignVerdictLevel
                .quarantine.rank
            {
                return .silentStub
            }
            // Hard freeze / cut — surface the boundary
            // explicitly so the host knows execution stopped.
            if lvl.rank >= BASSovereignVerdictLevel
                .toolCut.rank
            {
                return .boundary
            }
            // Throttle / shadow lock — draft only, no commit.
            if lvl.rank >= BASSovereignVerdictLevel
                .throttle.rank
            {
                return .draft
            }
            // verdict.pass — fall through to permit-based rules
        }

        // 2. Permit mode tier.
        if let p = permit {
            switch p.mode {
            case .block, .replace:
                return .boundary
            case .delay:
                return .delay
            case .draftOnly, .compare:
                return .compare
            case .escalate:
                return .boundary
            case .mirror, .localOnly:
                return .draft
            case .answer:
                // Multi-candidate even in answer mode → compare
                // instead of single draft.
                return candidateCount >= 2
                    ? .compare : .draft
            }
        }

        // 3. Default fail-safe — no permit, verdict.pass / nil →
        // render nothing actionable. Host can override.
        return .silentStub
    }

    /// Convenience: derive only from a verdict (no permit). Used
    /// in observation pipelines where the surface must be set
    /// before a permit is even built (e.g. when sovereign
    /// quarantine fires before the permit gate runs).
    public static func selectMode(
        forVerdict verdict: BASSovereignVerdict
    ) -> BASSoftHandMode {
        selectMode(permit: nil, verdict: verdict)
    }
}
