import Foundation

/// M74 — Tri-self tribunal three-voice scoring + veto explain.
///
/// The existing `critiqueStrength` scalar collapses four concern
/// axes (manipulation / boundary / emotion / evidence) plus the L4
/// world-prior contradiction signal into a single number. That's
/// adequate to decide "does guardian fire?" but inadequate to
/// explain "why did guardian fire, and whose voice did it".
///
/// L10's canonical shape is three voices:
///
/// - **guardian** (the protector) — speaks on safety: manipulation
///   pressure, host-boundary conflict, world-prior contradiction.
/// - **scout**    (the explorer) — speaks on readiness: evidence
///   gaps, low confidence, low expected benefit.
/// - **harmony**  (the reconciler) — speaks on cost-of-regret:
///   emotional bias, low reversibility.
///
/// Each voice produces an independent concern score in [0,1] with
/// its own reason code vocabulary (ordered by that voice's
/// internal priority). `vetoExplain(sessionID:)` returns the
/// vetoing voice + reason codes + the substitute chosen, so a
/// host can tell the user *whose* concern stopped a candidate,
/// not just *that* a concern did.
///
/// # Public surface
///
/// - `TriSelfVoice` — enum naming the three voices.
/// - `TriSelfVoiceReading` — one voice's reading (concern +
///   reason codes) on a single candidate.
/// - `TriSelfScore` — all three voices on one candidate + which
///   voice dominates (ties break guardian > scout > harmony).
/// - `VetoExplain` — enriched `guardianBranch` with voice
///   attribution. Nil when no voice crosses 0.7 for any candidate.
///
/// Nothing here mentions substrate vocabulary. Reason codes are
/// Qinao-stable and UI-keyable.
public extension QinaoLoop {

    /// Which of the three tribunal voices is reading a candidate.
    /// Raw values are stable for Codable round-trips and for
    /// keying UI copy against a specific voice.
    enum TriSelfVoice: String, Sendable, Equatable, Codable, CaseIterable {
        /// The protector — manipulation, boundary conflict,
        /// world-prior contradiction. Speaks first on safety.
        case guardian = "guardian"
        /// The explorer — evidence gap, low confidence, low
        /// expected benefit. Speaks first on readiness.
        case scout = "scout"
        /// The reconciler — emotional bias, low reversibility.
        /// Speaks first on cost of regret.
        case harmony = "harmony"
    }

    /// A single voice's reading on a single candidate.
    ///
    /// `concern` is in [0,1]. `reasonCodes` is sorted by the
    /// voice's internal priority so host UI can pick the first
    /// entry as the primary surfaced concern.
    struct TriSelfVoiceReading: Sendable, Equatable, Codable {
        public let concern: Double
        public let reasonCodes: [String]
        public init(concern: Double, reasonCodes: [String]) {
            self.concern = concern
            self.reasonCodes = reasonCodes
        }
    }

    /// Per-candidate three-voice reading.
    ///
    /// `dominantVoice` is whichever voice has the highest
    /// concern. Ties break guardian > scout > harmony — the
    /// protector speaks first on safety matters.
    struct TriSelfScore: Sendable, Equatable, Codable {
        public let candidateID: String
        public let guardVoice: TriSelfVoiceReading
        public let scoutVoice: TriSelfVoiceReading
        public let harmonyVoice: TriSelfVoiceReading
        public let dominantVoice: TriSelfVoice
        public init(
            candidateID: String,
            guardVoice: TriSelfVoiceReading,
            scoutVoice: TriSelfVoiceReading,
            harmonyVoice: TriSelfVoiceReading,
            dominantVoice: TriSelfVoice
        ) {
            self.candidateID = candidateID
            self.guardVoice = guardVoice
            self.scoutVoice = scoutVoice
            self.harmonyVoice = harmonyVoice
            self.dominantVoice = dominantVoice
        }
    }

    /// Enriched form of `guardianBranch`. When any candidate has
    /// a voice concern ≥ 0.7, `vetoExplain(sessionID:)` returns:
    ///
    /// - `candidateID` — the vetoed candidate (MAX-voice-concern
    ///   highest; ties break on ID asc).
    /// - `vetoingVoice` — the candidate's dominant voice.
    /// - `concernLevel` — that voice's concern on the candidate.
    /// - `primaryReason` — the first reason code that voice
    ///   flagged (voice-internal priority).
    /// - `supportingReasons` — remaining reason codes that voice
    ///   flagged, in priority order.
    /// - `alternativeID` — candidate with the *lowest* MAX voice
    ///   concern (ties: higher reversibility wins; then ID asc).
    ///   `"no-alternative-available"` if the session has only the
    ///   vetoed candidate.
    /// - `alternativeRationale` — `"lowest-tri-self-max:<0.NN>"`
    ///   reporting the alternative's MAX voice concern rounded to
    ///   two decimals; `"no-alternative-available"` when none.
    struct VetoExplain: Sendable, Equatable, Codable {
        public let candidateID: String
        public let vetoingVoice: TriSelfVoice
        public let concernLevel: Double
        public let primaryReason: String
        public let supportingReasons: [String]
        public let alternativeID: String
        public let alternativeRationale: String
        public init(
            candidateID: String,
            vetoingVoice: TriSelfVoice,
            concernLevel: Double,
            primaryReason: String,
            supportingReasons: [String],
            alternativeID: String,
            alternativeRationale: String
        ) {
            self.candidateID = candidateID
            self.vetoingVoice = vetoingVoice
            self.concernLevel = concernLevel
            self.primaryReason = primaryReason
            self.supportingReasons = supportingReasons
            self.alternativeID = alternativeID
            self.alternativeRationale = alternativeRationale
        }
    }
}

// MARK: - Pure helpers

extension QinaoLoop {

    /// Compose the three-voice reading for one candidate. Pure
    /// deterministic function — same inputs always yield the same
    /// `TriSelfScore`. Called once per candidate from
    /// `triSelfScores(sessionID:)`.
    static func triSelfScore(
        for c: CandidateInput,
        worldPriorContradiction: Double
    ) -> TriSelfScore {
        let wpc = clampUnit(worldPriorContradiction)

        // Guardian (protector): manipulation / boundary / world-prior.
        // Weights reflect tribunal posture — manipulation carries the
        // most direct "someone is pushing the host" signal, boundary
        // and world-prior each carry structural signals.
        let guardianConcern = clampUnit(
            0.40 * c.manipulationRisk
            + 0.30 * c.boundaryConflict
            + 0.30 * wpc)

        // Scout (explorer): evidence gap dominates, low confidence
        // next, then low expected benefit. The scout asks "do we
        // know enough / believe strongly enough to act".
        let scoutConcern = clampUnit(
            0.55 * c.evidenceGap
            + 0.30 * (1.0 - c.confidence)
            + 0.15 * (1.0 - c.expectedBenefit))

        // Harmony (reconciler): emotional bias dominates, then low
        // reversibility. The harmony voice asks "if we're wrong,
        // can we walk it back".
        let harmonyConcern = clampUnit(
            0.60 * c.emotionalBias
            + 0.40 * (1.0 - c.reversibility))

        let guardianReasons = guardianReasonCodes(
            manipulation: c.manipulationRisk,
            boundary: c.boundaryConflict,
            worldPrior: wpc)
        let scoutReasons = scoutReasonCodes(
            evidenceGap: c.evidenceGap,
            confidence: c.confidence,
            expectedBenefit: c.expectedBenefit)
        let harmonyReasons = harmonyReasonCodes(
            emotional: c.emotionalBias,
            reversibility: c.reversibility)

        let dominant = dominantTriSelfVoice(
            guardian: guardianConcern,
            scout: scoutConcern,
            harmony: harmonyConcern)

        return TriSelfScore(
            candidateID: c.candidateID,
            guardVoice: TriSelfVoiceReading(
                concern: guardianConcern,
                reasonCodes: guardianReasons),
            scoutVoice: TriSelfVoiceReading(
                concern: scoutConcern,
                reasonCodes: scoutReasons),
            harmonyVoice: TriSelfVoiceReading(
                concern: harmonyConcern,
                reasonCodes: harmonyReasons),
            dominantVoice: dominant)
    }

    /// Guardian voice reason codes. Priority:
    /// world-prior-contradiction > manipulation-risk >
    /// boundary-conflict. Thresholds: world-prior ≥ 0.5 (any
    /// demote or reject trips), manipulation > 0.5, boundary >
    /// 0.5. Returned array is already in priority order.
    static func guardianReasonCodes(
        manipulation: Double,
        boundary: Double,
        worldPrior: Double
    ) -> [String] {
        var codes: [String] = []
        if worldPrior >= 0.5 { codes.append("world-prior-contradiction") }
        if manipulation > 0.5 { codes.append("manipulation-risk") }
        if boundary > 0.5 { codes.append("boundary-conflict") }
        return codes
    }

    /// Scout voice reason codes. Priority: evidence-gap >
    /// low-confidence > low-expected-benefit. Thresholds:
    /// evidence > 0.5, confidence < 0.4, benefit < 0.3.
    static func scoutReasonCodes(
        evidenceGap: Double,
        confidence: Double,
        expectedBenefit: Double
    ) -> [String] {
        var codes: [String] = []
        if evidenceGap > 0.5 { codes.append("evidence-gap") }
        if confidence < 0.4 { codes.append("low-confidence") }
        if expectedBenefit < 0.3 { codes.append("low-expected-benefit") }
        return codes
    }

    /// Harmony voice reason codes. Priority: emotional-bias >
    /// low-reversibility. Thresholds: emotional > 0.5,
    /// reversibility < 0.3.
    static func harmonyReasonCodes(
        emotional: Double,
        reversibility: Double
    ) -> [String] {
        var codes: [String] = []
        if emotional > 0.5 { codes.append("emotional-bias") }
        if reversibility < 0.3 { codes.append("low-reversibility") }
        return codes
    }

    /// Pick the dominant voice. Ties break guardian > scout >
    /// harmony (protector first on safety, then explorer on
    /// readiness, then reconciler on regret cost).
    static func dominantTriSelfVoice(
        guardian: Double,
        scout: Double,
        harmony: Double
    ) -> TriSelfVoice {
        if guardian >= scout && guardian >= harmony {
            return .guardian
        }
        if scout >= harmony {
            return .scout
        }
        return .harmony
    }

    /// Return the largest concern across the three voices.
    static func maxTriSelfConcern(_ score: TriSelfScore) -> Double {
        max(
            score.guardVoice.concern,
            max(score.scoutVoice.concern, score.harmonyVoice.concern))
    }

    /// Return the voice reading for a given voice on a given
    /// `TriSelfScore`. Used by `vetoExplain` to surface the
    /// vetoing voice's reason codes.
    static func voiceReading(
        _ voice: TriSelfVoice,
        on score: TriSelfScore
    ) -> TriSelfVoiceReading {
        switch voice {
        case .guardian: return score.guardVoice
        case .scout:    return score.scoutVoice
        case .harmony:  return score.harmonyVoice
        }
    }

    /// Format the alternative rationale string. Stable,
    /// UI-keyable: `"lowest-tri-self-max:0.NN"`.
    static func alternativeRationale(
        forMaxConcern max: Double
    ) -> String {
        "lowest-tri-self-max:\(String(format: "%.2f", max))"
    }

    /// Clamp x to [0,1]. Private helper so we don't invent
    /// different clamp behavior across voices.
    static func clampUnit(_ x: Double) -> Double {
        min(max(x, 0), 1)
    }
}
