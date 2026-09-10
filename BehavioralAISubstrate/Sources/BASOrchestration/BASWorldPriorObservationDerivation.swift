import Foundation
import BASWorldPrior

// MARK: - M59 main-chain derivation from the turn's finalized
//         `BASThoughtFrame` world-prior signals
//
// M59 graduates the L4 observation surface from primitive-only (M30)
// to main-chain load-bearing observation output. Before M59, the
// `BASWorldPriorObservation` family existed but the BAS coordinator
// never emitted a bundle — L4 signals showed up only in M50's public
// `QinaoWorldPrior` façade and M51's `QinaoLoop` candidate critique.
// As a result, the L14 audit surface could verify "what L4 said about
// template T" only by reading the vault, never by reading a per-turn
// record.
//
// The derivation lives in BASOrchestration (next to the rest of the
// observation family) and imports BASWorldPrior so the extension can
// construct `BASWorldPriorObservation` values. The thought frame —
// defined in this same module — is the input; every signal we emit
// references fields the coordinator has already sealed before calling
// `derive`.
//
// The derive function is a pure value transform:
//   - No I/O, no actor hop.
//   - Deterministic for the same (frame, turnID, sessionID,
//     emittedAt) tuple.
//   - Coherent-by-construction with the populated thought frame:
//     every signal references a frame field that already exists
//     (candidates, counterfactualBundles, critiqueBundles,
//     uncertaintyLedger).
//
// Consumers:
//   - `EBrainRuntimeCoordinator.run(request:)` calls
//     `thoughtFrame.withDerivedWorldPriorObservationBundle(...)`
//     after `materializeThoughtArtifacts` has filled in
//     counterfactualBundles / critiqueBundles / uncertaintyLedger
//     and before tri-self tribunal reads the frame.
//   - The L14 audit surface reads
//     `BASThoughtFrame.worldPriorObservationBundle` to reconcile
//     "what L4 claimed fired for candidate C" against "what L9
//     dream-loop and L10 tribunal decided about C".
//   - M32's L4 coverage projection reads `hasCoreSignalCoverage`
//     (= has `.templateMatched` AND
//     (`.counterfactualSeeded` OR `.boundaryBedrockConsulted`))
//     from the derived bundle.

extension BASWorldPriorObservationBundle {
    /// M59 — Derive an L4 world-prior observation bundle from the
    /// turn's populated `BASThoughtFrame`. The derivation is
    /// deterministic: for the same input (frame, turnID, sessionID,
    /// emittedAt) it produces the same bundle byte-for-byte. No I/O,
    /// no actor hop.
    ///
    /// Signal emission rules (per candidate in the frame, source
    /// order preserved):
    ///
    ///   - `.templateMatched`           one per candidate — the L4
    ///                                   reasoner's "I applied a
    ///                                   pattern to this candidate"
    ///                                   marker. evidenceLevel
    ///                                   derived from the candidate's
    ///                                   own `confidence`. Always
    ///                                   emitted when candidates
    ///                                   exist.
    ///   - `.counterfactualSeeded`      one per `BASCounterfactualBundle`
    ///                                   in `counterfactualBundles` —
    ///                                   a branch was synthesized
    ///                                   against this candidate.
    ///                                   evidenceLevel derived from
    ///                                   `1 - uncertainty`.
    ///   - `.domainBridgeCrossed`       one per counterfactual bundle
    ///                                   with `affectedDomains.count
    ///                                   >= 2` — structure carried
    ///                                   across at least two domains.
    ///   - `.boundaryBedrockConsulted`  one per `BASCritiqueBundle`
    ///                                   where `boundaryConflict >
    ///                                   0.5` — a boundary axiom
    ///                                   was actively weighed.
    ///                                   evidenceLevel = `.axiomatic`
    ///                                   (bedrock is axiomatic by
    ///                                   definition).
    ///   - `.evidenceRevised`           one per `BASCritiqueBundle`
    ///                                   where `evidenceGap > 0.3`
    ///                                   PLUS one per
    ///                                   `uncertaintyLedger.weakPredictions`
    ///                                   item. Signals widening of
    ///                                   uncertainty.
    ///   - `.priorContradiction`        gated on a critique with
    ///                                   `boundaryConflict > 0.8`
    ///                                   AND `critiqueStrength > 0.8`
    ///                                   — two axiomatic claims
    ///                                   colliding. evidenceLevel =
    ///                                   `.axiomatic`, salience 1.0,
    ///                                   highest audit weight.
    ///
    /// Empty path: frame has no candidates → return a bundle with
    /// zero observations. This is the legitimate "no-L4-turn" signal
    /// (L4 fires only when there is something to reason about).
    /// `hasCoreSignalCoverage == false` on this path — the L14 audit
    /// surface interprets that as "no world-prior evidence applied",
    /// NOT as a coverage gap.
    public static func derive(
        fromThoughtFrame frame: BASThoughtFrame,
        turnID: String,
        sessionID: String,
        emittedAt: Date
    ) -> BASWorldPriorObservationBundle {
        var observations: [BASWorldPriorObservation] = []

        // templateMatched — one per candidate.
        for candidate in frame.candidates {
            let level = Self.evidenceLevel(
                fromConfidence: candidate.confidence)
            let salience = Self.clamp(candidate.confidence)
            let confidence = max(0.5, Self.clamp(candidate.confidence))
            observations.append(
                BASWorldPriorObservation(
                    kind: .templateMatched,
                    templateID:
                        "l4.template.candidate:" + candidate.candidateID,
                    evidenceLevel: level,
                    salience: salience,
                    confidence: confidence,
                    content:
                        "l4.template-matched.candidate:"
                        + candidate.candidateID
                        + ".evidence:" + level.rawValue
                        + ".confidence:"
                        + Self.formatFraction(candidate.confidence),
                    observedAt: emittedAt)
            )
        }

        // counterfactualSeeded + domainBridgeCrossed — per
        // counterfactual bundle.
        for bundle in frame.counterfactualBundles ?? [] {
            let level = Self.evidenceLevel(
                fromUncertainty: bundle.uncertainty)
            let salience = Self.clamp(1.0 - bundle.uncertainty)
            let confidence = Self.clamp(1.0 - bundle.uncertainty)
            let primaryDomain = bundle.affectedDomains.first
                ?? "unknown"
            observations.append(
                BASWorldPriorObservation(
                    kind: .counterfactualSeeded,
                    templateID:
                        "l4.counterfactual.domain:" + primaryDomain,
                    evidenceLevel: level,
                    salience: salience,
                    confidence: confidence,
                    content:
                        "l4.counterfactual.candidate:"
                        + bundle.candidateID
                        + ".domains:"
                        + bundle.affectedDomains
                            .joined(separator: ","),
                    observedAt: emittedAt)
            )
            if bundle.affectedDomains.count >= 2 {
                observations.append(
                    BASWorldPriorObservation(
                        kind: .domainBridgeCrossed,
                        templateID:
                            "l4.bridge.domains:"
                            + bundle.affectedDomains
                                .joined(separator: "-"),
                        evidenceLevel: .plausible,
                        salience: 0.60,
                        confidence: confidence,
                        content:
                            "l4.bridge.candidate:"
                            + bundle.candidateID
                            + ".domains:"
                            + bundle.affectedDomains
                                .joined(separator: ","),
                        observedAt: emittedAt)
                )
            }
        }

        // boundaryBedrockConsulted / evidenceRevised /
        // priorContradiction — per critique bundle.
        for critique in frame.critiqueBundles ?? [] {
            if critique.boundaryConflict > 0.5 {
                observations.append(
                    BASWorldPriorObservation(
                        kind: .boundaryBedrockConsulted,
                        templateID:
                            "l4.boundary.candidate:"
                            + critique.candidateID,
                        evidenceLevel: .axiomatic,
                        salience: Self.clamp(
                            critique.boundaryConflict),
                        confidence: Self.clamp(
                            critique.critiqueStrength),
                        content:
                            "l4.bedrock-consulted.candidate:"
                            + critique.candidateID
                            + ".boundary:"
                            + Self.formatFraction(
                                critique.boundaryConflict),
                        observedAt: emittedAt)
                )
            }
            if critique.evidenceGap > 0.3 {
                let level = Self.evidenceLevel(
                    fromGap: critique.evidenceGap)
                observations.append(
                    BASWorldPriorObservation(
                        kind: .evidenceRevised,
                        templateID:
                            "l4.evidence.candidate:"
                            + critique.candidateID,
                        evidenceLevel: level,
                        salience: Self.clamp(critique.evidenceGap),
                        confidence: Self.clamp(
                            1.0 - critique.evidenceGap),
                        content:
                            "l4.evidence-revised.candidate:"
                            + critique.candidateID
                            + ".gap:"
                            + Self.formatFraction(
                                critique.evidenceGap),
                        observedAt: emittedAt)
                )
            }
            if critique.boundaryConflict > 0.8
               && critique.critiqueStrength > 0.8
            {
                observations.append(
                    BASWorldPriorObservation(
                        kind: .priorContradiction,
                        templateID:
                            "l4.contradiction.candidate:"
                            + critique.candidateID,
                        evidenceLevel: .axiomatic,
                        salience: 1.0,
                        confidence: 1.0,
                        content:
                            "l4.prior-contradiction.candidate:"
                            + critique.candidateID
                            + ".boundary:"
                            + Self.formatFraction(
                                critique.boundaryConflict)
                            + ".strength:"
                            + Self.formatFraction(
                                critique.critiqueStrength),
                        observedAt: emittedAt)
                )
            }
        }

        // evidenceRevised — one per weak prediction on the ledger.
        if let ledger = frame.uncertaintyLedger {
            for (idx, prediction)
                in ledger.weakPredictions.enumerated()
            {
                observations.append(
                    BASWorldPriorObservation(
                        kind: .evidenceRevised,
                        templateID:
                            "l4.evidence.ledger:"
                            + ledger.ledgerID
                            + ".prediction:"
                            + String(idx),
                        evidenceLevel: .speculative,
                        salience: Self.clamp(
                            1.0 - ledger.confidenceFloor),
                        confidence: Self.clamp(
                            ledger.confidenceFloor),
                        content:
                            "l4.evidence-revised.ledger:"
                            + ledger.ledgerID
                            + ".prediction:"
                            + Self.truncated(prediction, maxLength: 40),
                        observedAt: emittedAt)
                )
            }
        }

        return BASWorldPriorObservationBundle(
            turnID: turnID,
            sessionID: sessionID,
            observations: observations,
            emittedAt: emittedAt
        )
    }

    // MARK: - Helpers

    /// Map candidate confidence to an evidence rung.
    /// - `confidence >= 0.85` → `.wellSupported`
    /// - `confidence >= 0.55` → `.plausible`
    /// - `confidence >= 0.30` → `.speculative`
    /// - `confidence <  0.30` → `.contested`
    /// Axiomatic is reserved for bedrock — never derived from
    /// candidate confidence.
    fileprivate static func evidenceLevel(
        fromConfidence confidence: Double
    ) -> BASWorldPriorEvidenceLevel {
        let c = clamp(confidence)
        if c >= 0.85 { return .wellSupported }
        if c >= 0.55 { return .plausible }
        if c >= 0.30 { return .speculative }
        return .contested
    }

    /// Map counterfactual uncertainty to an evidence rung.
    /// Mirrors the confidence mapping (low uncertainty = high
    /// evidence) with the same thresholds.
    fileprivate static func evidenceLevel(
        fromUncertainty uncertainty: Double
    ) -> BASWorldPriorEvidenceLevel {
        let clampedUncertainty = clamp(uncertainty)
        return evidenceLevel(
            fromConfidence: 1.0 - clampedUncertainty)
    }

    /// Map an evidence gap to a rung. Wider gap → lower rung.
    fileprivate static func evidenceLevel(
        fromGap gap: Double
    ) -> BASWorldPriorEvidenceLevel {
        let clampedGap = clamp(gap)
        if clampedGap >= 0.70 { return .contested }
        if clampedGap >= 0.45 { return .speculative }
        return .plausible
    }

    fileprivate static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    /// Format a fractional value in [0, 1] as a 2-decimal string so
    /// content fields are deterministic across locales. Mirrors the
    /// M58 helper so downstream deterministic-parity assertions
    /// compose across the L13/L4 bundles.
    fileprivate static func formatFraction(
        _ value: Double
    ) -> String {
        let c = clamp(value)
        let scaled = Int((c * 100).rounded())
        let padded = scaled < 10 ? "0\(scaled)" : "\(scaled)"
        return "0." + padded
    }

    /// Truncate a string to at most `maxLength` characters without
    /// breaking grapheme boundaries, appending an ellipsis sentinel
    /// when truncation occurred.
    fileprivate static func truncated(
        _ string: String,
        maxLength: Int
    ) -> String {
        guard string.count > maxLength else { return string }
        let prefix = string.prefix(max(0, maxLength))
        return prefix + "…"
    }
}
