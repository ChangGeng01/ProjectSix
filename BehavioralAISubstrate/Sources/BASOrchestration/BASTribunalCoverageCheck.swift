import Foundation

/// L10 / M283 — coverage check for `BASTribunalObservationBundle`.
///
/// ## Why this exists
///
/// M89 shipped the full-body tribunal (3 voices: baseSelf / ruleSelf
/// / aspireSelf, plus convergence / dissent signals) with a complete
/// observation pipeline. The remaining gap: a fast "did every voice
/// actually speak?" check — runtime / audit code that wanted to
/// validate the tribunal's surface coverage had to filter the
/// observations array manually.
///
/// `BASTribunalCoverageReport` is the typed coverage result.
/// `BASTribunalCoverageCheck.report(...)` is the pure derive
/// function. Audit walkers, integration tests, and runtime
/// validators consume the report to decide whether the tribunal
/// rendered its full opinion or whether some voice was silent.
public struct BASTribunalCoverageReport:
    Sendable, Equatable, Hashable, Codable
{
    /// Voices that emitted at least one observation in the
    /// bundle. Empty set means a degenerate tribunal turn (no
    /// voices spoke) — host should treat this as "not deliberated"
    /// rather than "all 3 abstained".
    public let voicesPresent: Set<BASTribunalVoice>

    /// Distinct subjects (candidate IDs / decision IDs) the
    /// tribunal voted on. Empty when no votes were cast.
    public let subjectIDs: [String]

    /// Whether the tribunal emitted at least one `.convergence`
    /// signal — meaning all three voices aligned on at least one
    /// subject.
    public let hasConvergence: Bool

    /// Whether the tribunal emitted at least one `.dissent`
    /// signal — meaning at least one subject cannot advance
    /// without further deliberation.
    public let hasDissent: Bool

    /// Whether all three canonical voices (baseSelf / ruleSelf /
    /// aspireSelf) emitted at least one observation. The
    /// "doctrinally complete" tribunal turn requires this to be
    /// true; if false, a voice was silent.
    public var isFullBody: Bool {
        Set(BASTribunalVoice.allCases)
            .isSubset(of: voicesPresent)
    }

    /// Voices that did NOT emit any observation. Empty when
    /// `isFullBody` is true.
    public var silentVoices: Set<BASTribunalVoice> {
        Set(BASTribunalVoice.allCases)
            .subtracting(voicesPresent)
    }

    /// Stable status string for audit grouping:
    /// - `"full-body-converged"` — all 3 voices spoke +
    ///   convergence signal present
    /// - `"full-body-dissent"` — all 3 voices spoke + dissent
    ///   signal present (deliberation incomplete)
    /// - `"full-body-incomplete"` — all 3 voices spoke but
    ///   neither convergence nor dissent emitted (rare;
    ///   indicates the tribunal didn't reach a verdict)
    /// - `"partial-<n>-voices"` — fewer than 3 voices spoke
    /// - `"empty"` — no observations
    public var statusCode: String {
        if voicesPresent.isEmpty { return "empty" }
        if isFullBody {
            if hasConvergence {
                return "full-body-converged"
            }
            if hasDissent {
                return "full-body-dissent"
            }
            return "full-body-incomplete"
        }
        return "partial-\(voicesPresent.count)-voices"
    }

    public init(
        voicesPresent: Set<BASTribunalVoice>,
        subjectIDs: [String],
        hasConvergence: Bool,
        hasDissent: Bool
    ) {
        self.voicesPresent = voicesPresent
        self.subjectIDs = subjectIDs
        self.hasConvergence = hasConvergence
        self.hasDissent = hasDissent
    }
}

public enum BASTribunalCoverageCheck {
    /// L10 / M283 — derive the coverage report from a bundle.
    /// Pure function; deterministic for the same bundle.
    public static func report(
        for bundle: BASTribunalObservationBundle
    ) -> BASTribunalCoverageReport {
        var voices: Set<BASTribunalVoice> = []
        var subjects: [String] = []
        var seenSubjects: Set<String> = []
        var hasConvergence = false
        var hasDissent = false

        for obs in bundle.observations {
            if let v = obs.voice {
                voices.insert(v)
            }
            if obs.kind == .vote {
                if seenSubjects.insert(obs.subjectID).inserted {
                    subjects.append(obs.subjectID)
                }
            }
            switch obs.kind {
            case .convergence: hasConvergence = true
            case .dissent: hasDissent = true
            default: break
            }
        }

        return BASTribunalCoverageReport(
            voicesPresent: voices,
            subjectIDs: subjects,
            hasConvergence: hasConvergence,
            hasDissent: hasDissent)
    }
}
