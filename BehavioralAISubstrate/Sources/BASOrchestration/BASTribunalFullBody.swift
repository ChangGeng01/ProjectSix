import Foundation
import BASRuntimeCore

/// M89 — Pure derivation functions for the L10 full-body tribunal
/// schemas.
///
/// ## Why this file exists
///
/// The schemas themselves (`BASIdImpulseProfile`,
/// `BASEgoRealityAssessment`, `BASSuperegoJudgment`,
/// `BASArbitrationFrame`) live in `EBrainCognitionPlaneCore.swift`
/// alongside the other cognition-plane types. Their derivation
/// logic — pure, deterministic projections FROM an existing
/// `BASThoughtFrame` — lives HERE to keep the schema file focused
/// on shape and this file focused on the derivation contract.
///
/// The pattern mirrors `BASTribunalObservation.derive(from:)` (M25):
/// static factory, no I/O, no actor state, same inputs → same outputs.
/// That determinism is the hinge that lets the coordinator call the
/// factories from any context and get the same audit-trail-stable
/// result.
///
/// ## What the derivations read
///
/// All four factories work from a `BASThoughtFrame` (optionally with
/// an accompanying `BASDecomposeFrame` for richer signals). The
/// thought frame already carries:
///
/// - `triScores: [BASTriSelfScore]` — the raw id / ego / superego
///   votes, produced by `EBrainHostRuntime+TriSelfService.swift`
/// - `vetoMarks: [BASVetoMark]?` — explicit vetoes applied
/// - `remandOrders: [BASRemandOrder]?` — remand directives
/// - `courtDecisionDraft: BASCourtDecisionDraft?` — integrated draft
/// - `candidates: [BASCandidatePath]` — candidate set
/// - `forecasts: [BASForecastItem]` — per-candidate forecasts
/// - `critiques: [BASCritiqueItem]` — per-candidate critiques
/// - `uncertaintyLedger: BASUncertaintyLedger?` — turn-level epistemic state
///
/// Derivations aggregate across candidates with stable sort
/// (candidate-ID ascending) so repeated calls yield byte-equal outputs.

public extension BASIdImpulseProfile {

    /// M89 — Derive an id-voice profile from the thought frame.
    ///
    /// ## Aggregation formula
    ///
    /// - `controlRecoveryNeed = mean(idScore) across triScores`
    ///   (clamped) — the id voice's average desperation grade.
    /// - `urgencyFeel = max(idScore * (1 - confidence))` across
    ///   candidate paths, or `mean(idScore)` if no candidates.
    ///   Higher when the id voice wants something it isn't confident
    ///   about.
    /// - `vitalityLoad = max(expectedBenefit) across candidates` —
    ///   the strongest pull the id voice is feeling this turn.
    /// - `desiredRelief / aversionTargets / unmetNeeds` read from
    ///   non-empty critique / forecast reason codes (best-effort
    ///   categorical extraction).
    ///
    /// ## Empty-frame behaviour
    ///
    /// A frame with zero triScores yields a profile with zero scores
    /// and empty arrays — a valid "no-id-voice-this-turn" signal.
    static func derive(
        from thoughtFrame: BASThoughtFrame,
        profileID: String
    ) -> BASIdImpulseProfile {
        let triScores = thoughtFrame.triScores
        let controlRecoveryNeed: Double
        if triScores.isEmpty {
            controlRecoveryNeed = 0
        } else {
            let sum = triScores.reduce(0.0) { $0 + clamp01($1.idScore) }
            controlRecoveryNeed = sum / Double(triScores.count)
        }

        let candidates = thoughtFrame.candidates
        let urgencyFeel: Double
        if !candidates.isEmpty && !triScores.isEmpty {
            // idScore × (1 − confidence) — the id voice is most
            // urgent when pulling hard toward something it isn't
            // sure of.
            let perCandidate: [Double] = candidates.compactMap { candidate in
                guard let score = triScores.first(where: {
                    $0.candidateID == candidate.candidateID
                }) else { return nil }
                let id = clamp01(score.idScore)
                let conf = clamp01(candidate.confidence)
                return id * (1 - conf)
            }
            urgencyFeel = perCandidate.max() ?? controlRecoveryNeed
        } else {
            urgencyFeel = controlRecoveryNeed
        }

        let vitalityLoad: Double
        if candidates.isEmpty {
            vitalityLoad = 0
        } else {
            vitalityLoad = candidates
                .map { clamp01($0.expectedBenefit) }
                .max() ?? 0
        }

        // Categorical arrays — empty unless the frame's critique /
        // forecast codes surface them. This factory does not invent
        // free-text codes; richer derivations can project from the
        // decompose frame in a follow-up.
        return BASIdImpulseProfile(
            profileID: profileID,
            desiredRelief: [],
            controlRecoveryNeed: controlRecoveryNeed,
            aversionTargets: [],
            urgencyFeel: urgencyFeel,
            unmetNeeds: [],
            vitalityLoad: vitalityLoad)
    }
}

public extension BASEgoRealityAssessment {

    /// M89 — Derive an ego-voice assessment from the thought frame.
    ///
    /// ## Aggregation formula
    ///
    /// - `feasibleCandidateIDs` = candidateIDs where ego score ≥ 0.5
    ///   AND no veto mark applies (the ego voice thinks this is
    ///   realistic).
    /// - `blockedCandidateIDs` = candidateIDs where ego score < 0.3
    ///   OR a veto mark applies (the ego voice considers this
    ///   blocked — timing / evidence / resource constraint violated).
    /// - `timingFit = mean(candidate.reversibility)` clamped — low
    ///   reversibility means the window is narrow, proxy for "fit
    ///   this turn's timing".
    /// - `evidenceReadiness = mean(candidate.confidence)` clamped.
    /// - `leaseFit = 1 − mean(expectedCost)` clamped — cheaper
    ///   candidates fit the lease budget more.
    /// - `realismScore = mean(egoScore)` clamped — the canonical
    ///   aggregate per the whitepaper.
    ///
    /// ## Invariant enforced
    ///
    /// `feasibleCandidateIDs` and `blockedCandidateIDs` are disjoint
    /// by construction (veto overrides ego-score categorization).
    /// Candidates with 0.3 ≤ egoScore < 0.5 and no veto land in
    /// neither array — the ego voice is undecided on them.
    static func derive(
        from thoughtFrame: BASThoughtFrame,
        assessmentID: String
    ) -> BASEgoRealityAssessment {
        let triScores = thoughtFrame.triScores
        let candidates = thoughtFrame.candidates
        let vetoIDs: Set<String> = Set(
            (thoughtFrame.vetoMarks ?? []).map { $0.candidateID })

        var feasible: [String] = []
        var blocked: [String] = []
        for score in triScores.sorted(by: {
            $0.candidateID < $1.candidateID
        }) {
            if vetoIDs.contains(score.candidateID) {
                blocked.append(score.candidateID)
            } else if score.egoScore >= 0.5 {
                feasible.append(score.candidateID)
            } else if score.egoScore < 0.3 {
                blocked.append(score.candidateID)
            }
        }

        let timingFit: Double
        let evidenceReadiness: Double
        let leaseFit: Double
        if candidates.isEmpty {
            timingFit = 0
            evidenceReadiness = 0
            leaseFit = 0
        } else {
            let n = Double(candidates.count)
            let reversibilitySum = candidates.reduce(0.0) {
                $0 + clamp01($1.reversibility)
            }
            let confidenceSum = candidates.reduce(0.0) {
                $0 + clamp01($1.confidence)
            }
            let costSum = candidates.reduce(0.0) {
                $0 + clamp01($1.expectedCost)
            }
            timingFit = reversibilitySum / n
            evidenceReadiness = confidenceSum / n
            leaseFit = clamp01(1 - (costSum / n))
        }

        let realismScore: Double
        if triScores.isEmpty {
            realismScore = 0
        } else {
            let sum = triScores.reduce(0.0) { $0 + clamp01($1.egoScore) }
            realismScore = sum / Double(triScores.count)
        }

        return BASEgoRealityAssessment(
            assessmentID: assessmentID,
            feasibleCandidateIDs: feasible,
            blockedCandidateIDs: blocked,
            timingFit: timingFit,
            evidenceReadiness: evidenceReadiness,
            resourceCosts: [],
            leaseFit: leaseFit,
            realismScore: realismScore)
    }
}

public extension BASSuperegoJudgment {

    /// M89 — Derive a superego-voice judgment from the thought frame.
    ///
    /// ## Aggregation rules
    ///
    /// The superego voice is categorical, not scalar. The derivation
    /// projects:
    ///
    /// - `vetoCandidateIDs` = candidateIDs carrying any veto mark
    ///   (sorted ascending for stable output).
    /// - `boundaryConflicts` = `reasonCodes` from vetoMarks whose
    ///   `vetoType.rawValue` contains "boundary" (i.e. `.boundary`),
    ///   de-duplicated + sorted.
    /// - `dignityRisks` = `reasonCodes` where the rawValue contains
    ///   "dignity" (`.dignity`); `irreversibleWarnings` = contains
    ///   "irreversib" (`.irreversibility`). Both de-duplicated + sorted.
    /// - `valueViolations` / `relationEthicsLoad` are ALWAYS empty on
    ///   this baseline derivation — no `BASCourtVetoType` case maps to
    ///   them; hosts with richer context populate them via the init.
    /// - blindspot MED id34: this baseline categorises only 3 of the 6
    ///   `BASCourtVetoType` cases (`.boundary`/`.dignity`/
    ///   `.irreversibility`). The other three (`.hostConstitution`,
    ///   `.sovereignPrecondition`, `.calibration`) still contribute
    ///   their candidateIDs to `vetoCandidateIDs` (every veto mark is
    ///   counted there), but their `reasonCodes` are not bucketed into a
    ///   category field. (The doc previously named non-existent enum
    ///   cases `.boundaryConflict` / `.valueViolation`.)
    ///
    /// ## Empty-frame behaviour
    ///
    /// A frame with zero veto marks yields a judgment with empty
    /// arrays — a valid "no-superego-concerns-this-turn" signal.
    /// The absence of a superego voice never throws.
    static func derive(
        from thoughtFrame: BASThoughtFrame,
        judgmentID: String
    ) -> BASSuperegoJudgment {
        let marks = thoughtFrame.vetoMarks ?? []

        // vetoCandidateIDs — stable sort on candidateID ascending,
        // de-duplicated.
        let uniqueVetoIDs = Array(Set(marks.map { $0.candidateID }))
            .sorted()

        // Dedup + sort reason codes by vetoType category. We only
        // bucket codes we recognise; others are left for hosts that
        // want richer projection via the init.
        var boundary: Set<String> = []
        var dignity: Set<String> = []
        var irreversible: Set<String> = []
        for mark in marks {
            // Categorize by vetoType raw values. We intentionally
            // inspect the rawValue rather than the enum case to stay
            // robust if BASCourtVetoType gains new cases.
            let kind = mark.vetoType.rawValue.lowercased()
            if kind.contains("boundary") {
                boundary.formUnion(mark.reasonCodes)
            } else if kind.contains("dignity") {
                dignity.formUnion(mark.reasonCodes)
            } else if kind.contains("irreversib") {
                irreversible.formUnion(mark.reasonCodes)
            }
        }

        return BASSuperegoJudgment(
            judgmentID: judgmentID,
            dignityRisks: dignity.sorted(),
            boundaryConflicts: boundary.sorted(),
            valueViolations: [],
            relationEthicsLoad: [],
            irreversibleWarnings: irreversible.sorted(),
            vetoCandidateIDs: uniqueVetoIDs)
    }
}

public extension BASArbitrationFrame {

    /// M89 — Aggregate the three sub-profiles plus the turn's
    /// tribunal refs into a single `BASArbitrationFrame`.
    ///
    /// The `frameID` must be unique per tribunal turn (typically
    /// derived from `sessionID + turnID`). The sub-profile IDs
    /// (`idProfile.profileID` etc.) cross-reference back to the
    /// inlined sub-records; `vetoRefs` / `remandRefs` /
    /// `tradeoffLedgerRefs` / `decisionDraftRef` point to the
    /// already-shipped tribunal objects by their canonical IDs.
    ///
    /// ## Ref list construction
    ///
    /// - `vetoRefs` = `vetoMarks.map(\.candidateID)` (the existing
    ///   BASVetoMark doesn't carry a vetoID so candidateID is the
    ///   stable natural ID within a turn).
    /// - `remandRefs` = `remandOrders.map(\.targetLayer)` (same
    ///   rationale — targetLayer is the stable natural ID).
    /// - `tradeoffLedgerRefs` = `tradeoffLedgers.map(\.candidateID)`.
    /// - `decisionDraftRef` = draft's `preferredCandidateID` if the
    ///   draft exists, else nil.
    ///
    /// ## Empty / skip semantics
    ///
    /// Any sub-profile may be nil (voice skipped); any ref array may
    /// be empty (no records this turn). The resulting frame is still
    /// valid — it just records a sparse tribunal turn.
    static func aggregate(
        frameID: String,
        candidateFrontierRef: String? = nil,
        outcomeRefs: [String] = [],
        adversarialRefs: [String] = [],
        hostConstitutionRef: String? = nil,
        memoryBundleRef: String? = nil,
        idProfile: BASIdImpulseProfile? = nil,
        egoAssessment: BASEgoRealityAssessment? = nil,
        superegoJudgment: BASSuperegoJudgment? = nil,
        vetoMarks: [BASVetoMark] = [],
        remandOrders: [BASRemandOrder] = [],
        tradeoffLedgers: [BASTradeoffLedger] = [],
        agencyReservationRef: String? = nil,
        decisionDraft: BASCourtDecisionDraft? = nil
    ) -> BASArbitrationFrame {
        BASArbitrationFrame(
            frameID: frameID,
            candidateFrontierRef: candidateFrontierRef,
            outcomeRefs: outcomeRefs,
            adversarialRefs: adversarialRefs,
            hostConstitutionRef: hostConstitutionRef,
            memoryBundleRef: memoryBundleRef,
            idProfile: idProfile,
            egoAssessment: egoAssessment,
            superegoJudgment: superegoJudgment,
            tradeoffLedgerRefs: tradeoffLedgers.map { $0.candidateID },
            agencyReservationRef: agencyReservationRef,
            vetoRefs: vetoMarks.map { $0.candidateID },
            remandRefs: remandOrders.map { $0.targetLayer },
            decisionDraftRef: decisionDraft?.preferredCandidateID)
    }
}

public extension BASThoughtFrame {

    /// M89 — Return a copy of this thought frame with all four L10
    /// full-body tribunal records derived and attached.
    ///
    /// Convenience for coordinator code: instead of calling four
    /// separate `.derive(...)` / `.aggregate(...)` factories and
    /// re-building the frame from a dozen fields, hosts can
    /// `let enriched = frame.withDerivedL10FullBody(frameIDBase: ...)`
    /// and get an atomically-populated copy.
    ///
    /// `frameIDBase` is used as a prefix for the four sub-record IDs:
    ///
    /// - `"\(frameIDBase).id"` for the id profile
    /// - `"\(frameIDBase).ego"` for the ego assessment
    /// - `"\(frameIDBase).superego"` for the superego judgment
    /// - `"\(frameIDBase).arbitration"` for the arbitration frame
    ///
    /// Using a stable prefix (e.g. `sessionID + "." + turnID`) makes
    /// the IDs audit-trail-stable across replays.
    func withDerivedL10FullBody(
        frameIDBase: String
    ) -> BASThoughtFrame {
        let id = BASIdImpulseProfile.derive(
            from: self,
            profileID: "\(frameIDBase).id")
        let ego = BASEgoRealityAssessment.derive(
            from: self,
            assessmentID: "\(frameIDBase).ego")
        let superego = BASSuperegoJudgment.derive(
            from: self,
            judgmentID: "\(frameIDBase).superego")
        let arbitration = BASArbitrationFrame.aggregate(
            frameID: "\(frameIDBase).arbitration",
            idProfile: id,
            egoAssessment: ego,
            superegoJudgment: superego,
            vetoMarks: self.vetoMarks ?? [],
            remandOrders: self.remandOrders ?? [],
            tradeoffLedgers: self.tradeoffLedgers ?? [],
            decisionDraft: self.courtDecisionDraft)

        return BASThoughtFrame(
            schemaVersion: self.schemaVersion,
            stepIndex: self.stepIndex,
            decomposeRef: self.decomposeRef,
            memoryRefs: self.memoryRefs,
            candidates: self.candidates,
            forecasts: self.forecasts,
            critiques: self.critiques,
            triScores: self.triScores,
            riskCard: self.riskCard,
            actionPermit: self.actionPermit,
            organMap: self.organMap,
            candidateFrontier: self.candidateFrontier,
            counterfactualBundles: self.counterfactualBundles,
            critiqueBundles: self.critiqueBundles,
            uncertaintyLedger: self.uncertaintyLedger,
            evidenceDebts: self.evidenceDebts,
            convergenceCertificate: self.convergenceCertificate,
            loopLeaseReceipt: self.loopLeaseReceipt,
            sovereignBreakpointHints: self.sovereignBreakpointHints,
            vetoMarks: self.vetoMarks,
            tradeoffLedgers: self.tradeoffLedgers,
            agencyReservation: self.agencyReservation,
            remandOrders: self.remandOrders,
            courtDecisionDraft: self.courtDecisionDraft,
            idImpulseProfile: id,
            egoRealityAssessment: ego,
            superegoJudgment: superego,
            arbitrationFrame: arbitration,
            riskBindings: self.riskBindings,
            riskDecisionPackage: self.riskDecisionPackage,
            toolIntentEnvelope: self.toolIntentEnvelope,
            neuralLeaseReceipt: self.neuralLeaseReceipt,
            stabilityScore: self.stabilityScore,
            stopReason: self.stopReason,
            tribunalObservationBundle: self.tribunalObservationBundle,
            riskObservationBundle: self.riskObservationBundle,
            softHandObservationBundle: self.softHandObservationBundle,
            updateTicketObservationBundle:
                self.updateTicketObservationBundle,
            worldPriorObservationBundle:
                self.worldPriorObservationBundle,
            leaseLifeObservationBundle:
                self.leaseLifeObservationBundle,
            hostConstitutionObservationBundle:
                self.hostConstitutionObservationBundle,
            thoughtFoldObservationBundle:
                self.thoughtFoldObservationBundle,
            hippocampalMemoryObservationBundle:
                self.hippocampalMemoryObservationBundle,
            neuralOrganObservationBundle:
                self.neuralOrganObservationBundle)
    }
}

// MARK: - File-local helpers

private func clamp01(_ value: Double) -> Double {
    min(max(value, 0), 1)
}
