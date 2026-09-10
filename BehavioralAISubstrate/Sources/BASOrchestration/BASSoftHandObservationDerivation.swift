import Foundation
import BASPolicy

// MARK: - M57 main-chain derivation from a completed BASThoughtFrame + BASRenderedOutput
//
// M57 graduates M27 `BASSoftHand*` primitives from test-only
// sidecars to main-chain load-bearing output. The derivation
// lives in BASOrchestration because it references
// `BASThoughtFrame`, `BASRenderedOutput` (both here) and
// `BASActionPermitMode` / `BASRiskPermitBinding` / `BASRiskDecisionPackage`
// (BASPolicy). The only direction of module dependency that
// closes the cycle is "BASOrchestration → BASPolicy", which is
// already the shape of M56.
//
// Unlike M52–M56 this derivation takes TWO inputs (the thought
// frame *and* the final rendered output): suggestion / direction
// evidence lives on the frame (`riskBindings`,
// `riskDecisionPackage.actionModeDecision`), but the selection /
// render / deferral evidence is only sealed after
// `actionService.render` + `projectedRenderedOutput` finish. The
// coordinator reuses M53's derived (sessionID, turnID) so the L6
// / L7 / L10 / L11 / L12 bundles on the same turn share strictly
// equal coordinates — the L14 audit surface joins them by that
// key.
//
// The derive function is a pure value transform:
//   - No I/O, no actor hop.
//   - Deterministic for the same (frame, renderedOutput, turnID,
//     sessionID, emittedAt) tuple.
//   - Coherent-by-construction with `riskBindings` /
//     `riskDecisionPackage` / `renderedOutput`: every signal
//     references fields the coordinator has already sealed before
//     calling `derive`.
//
// Consumers:
//   - `EBrainRuntimeCoordinator.run(request:)` calls
//     `thoughtFrame.withDerivedSoftHandObservationBundle(...)`
//     right after the rendered output is produced.
//   - The L14 audit surface reads
//     `BASThoughtFrame.softHandObservationBundle` to reconcile
//     "what the L12 observer claimed about render R" against
//     "what surface R actually carried".
//   - M32's L12 coverage projection reads `hasCoreSignalCoverage`
//     (= has `.selection` AND `.render`) from the derived bundle.

extension BASSoftHandObservationBundle {
    /// M57 — Derive an L12 soft-hand observation bundle from a
    /// completed `BASThoughtFrame` and its final `BASRenderedOutput`.
    /// The derivation is deterministic: for the same input
    /// (frame, renderedOutput, turnID, sessionID, emittedAt) it
    /// produces the same bundle byte-for-byte. No I/O, no actor
    /// hop.
    ///
    /// Primary path: iterate `thoughtFrame.riskBindings`. Each
    /// binding emits a per-candidate suggestion + selection +
    /// (optional) direction observation stream with
    /// `subjectID = binding.candidateID`. The render / deferral
    /// stream is emitted for the subject that matches the
    /// `renderedOutput`'s candidate (resolved via the risk
    /// decision package's `candidateRef`) — typically one binding
    /// out of N.
    ///
    /// Fallback path: when `riskBindings` is empty but
    /// `riskDecisionPackage` exists, emit a single package-level
    /// stream with `subjectID = package.riskField.candidateRef`
    /// (or `packageID` when candidateRef is empty).
    ///
    /// Empty-empty path: when neither bindings nor package are
    /// available, emit only the selection + render + deferral
    /// signals from `renderedOutput` with
    /// `subjectID = "l12.subject.step-<stepIndex>"` as a stable
    /// fallback so the bundle still carries a provenance.
    ///
    /// DUPLICATE-candidateID CONTRACT: upstream can (pathologically)
    /// produce two `BASRiskPermitBinding` instances with the same
    /// `candidateID`. This function does NOT dedup — it emits the
    /// per-binding signals for each, preserving binding order. The
    /// `subjectIDs` helper on the resulting bundle uses first-seen
    /// dedup which is the intended coverage semantics (one subject
    /// listed once even when observed twice).
    public static func derive(
        from frame: BASThoughtFrame,
        renderedOutput: BASRenderedOutput,
        turnID: String,
        sessionID: String,
        emittedAt: Date
    ) -> BASSoftHandObservationBundle {
        var observations: [BASSoftHandObservation] = []

        let selectedPermitMode = renderedOutput.mode
        let selectedSoftHandMode =
            mapPermitToSoftHand(selectedPermitMode)
        let selectedRank = rank(of: selectedPermitMode)

        // --- Primary path: per-binding observations ------------
        if let bindings = frame.riskBindings, bindings.isEmpty == false {
            // Resolve the "active" subject — the candidate that
            // actually produced the rendered output. We trust
            // the risk decision package's candidateRef when
            // present; otherwise the first binding is the
            // render subject.
            let activeSubjectID: String
            if let ref = frame.riskDecisionPackage?.riskField.candidateRef,
               ref.isEmpty == false {
                activeSubjectID = ref
            } else {
                activeSubjectID = bindings[0].candidateID
            }

            for binding in bindings {
                // Suggestion — what this binding recommended.
                observations.append(BASSoftHandObservation(
                    kind: .suggestion,
                    mode: mapPermitToSoftHand(binding.recommendedMode),
                    subjectID: binding.candidateID,
                    salience: 0.70,
                    confidence: 0.80,
                    content:
                        "l12.suggestion.recommended:"
                        + binding.recommendedMode.rawValue,
                    observedAt: emittedAt
                ))

                // Selection — what this binding settled on.
                observations.append(BASSoftHandObservation(
                    kind: .selection,
                    mode: mapPermitToSoftHand(binding.permitMode),
                    subjectID: binding.candidateID,
                    salience: 1.0,
                    confidence: 1.0,
                    content:
                        "l12.selection.mode:"
                        + binding.permitMode.rawValue,
                    observedAt: emittedAt
                ))

                // Direction — escalation or downgrade relative to
                // the binding's own recommendation. No signal
                // when the binding's selection equals its
                // recommendation.
                let recRank = rank(of: binding.recommendedMode)
                let permitRank = rank(of: binding.permitMode)
                if permitRank > recRank {
                    let delta = permitRank - recRank
                    observations.append(BASSoftHandObservation(
                        kind: .escalation,
                        mode: mapPermitToSoftHand(binding.permitMode),
                        subjectID: binding.candidateID,
                        salience: min(1.0, Double(delta) * 0.20),
                        confidence: 0.90,
                        content:
                            "l12.escalation.from:"
                            + binding.recommendedMode.rawValue
                            + ".to:" + binding.permitMode.rawValue
                            + ".delta:\(delta)",
                        observedAt: emittedAt
                    ))
                } else if permitRank < recRank {
                    let delta = recRank - permitRank
                    observations.append(BASSoftHandObservation(
                        kind: .downgrade,
                        mode: mapPermitToSoftHand(binding.permitMode),
                        subjectID: binding.candidateID,
                        salience: min(1.0, Double(delta) * 0.20),
                        confidence: 0.90,
                        content:
                            "l12.downgrade.from:"
                            + binding.recommendedMode.rawValue
                            + ".to:" + binding.permitMode.rawValue
                            + ".delta:\(delta)",
                        observedAt: emittedAt
                    ))
                }
            }

            // Render / deferral for the active subject only.
            appendRenderEvidence(
                into: &observations,
                subjectID: activeSubjectID,
                renderedOutput: renderedOutput,
                selectedSoftHandMode: selectedSoftHandMode,
                selectedPermitMode: selectedPermitMode,
                emittedAt: emittedAt
            )
            appendSovereignEscalation(
                into: &observations,
                subjectID: activeSubjectID,
                renderedOutput: renderedOutput,
                package: frame.riskDecisionPackage,
                emittedAt: emittedAt
            )
            return BASSoftHandObservationBundle(
                turnID: turnID,
                sessionID: sessionID,
                observations: observations,
                emittedAt: emittedAt
            )
        }

        // --- Fallback path: package-level observations ---------
        if let package = frame.riskDecisionPackage {
            let subjectID: String = {
                let ref = package.riskField.candidateRef
                if ref.isEmpty == false { return ref }
                if package.packageID.isEmpty == false {
                    return package.packageID
                }
                return "l12.subject.step-\(frame.stepIndex)"
            }()

            // Primary-mode suggestion.
            let primary = package.actionModeDecision.primaryMode
            observations.append(BASSoftHandObservation(
                kind: .suggestion,
                mode: mapPermitToSoftHand(primary),
                subjectID: subjectID,
                salience: 0.70,
                confidence: 0.80,
                content:
                    "l12.suggestion.recommended:" + primary.rawValue,
                observedAt: emittedAt
            ))

            // Stacked-mode suggestions — decreasing salience per
            // rank position so the first alternative reads more
            // prominently than the fourth. Salience table:
            // idx=0→0.60, 1→0.50, 2→0.40, 3+→0.30.
            for (index, stacked) in
                package.actionModeDecision.stackedModes.enumerated()
            where stacked != primary {
                let decayed = max(0.30, 0.60 - Double(index) * 0.10)
                observations.append(BASSoftHandObservation(
                    kind: .suggestion,
                    mode: mapPermitToSoftHand(stacked),
                    subjectID: subjectID,
                    salience: decayed,
                    confidence: 0.70,
                    content:
                        "l12.suggestion.stacked:"
                        + stacked.rawValue
                        + ".idx:\(index)",
                    observedAt: emittedAt
                ))
            }

            // Selection from the rendered output (not the
            // decision package — rendering may have applied an
            // additional clamp).
            observations.append(BASSoftHandObservation(
                kind: .selection,
                mode: selectedSoftHandMode,
                subjectID: subjectID,
                salience: 1.0,
                confidence: 1.0,
                content:
                    "l12.selection.mode:" + selectedPermitMode.rawValue,
                observedAt: emittedAt
            ))

            // Direction — primaryMode vs rendered mode.
            let primaryRank = rank(of: primary)
            if selectedRank > primaryRank {
                let delta = selectedRank - primaryRank
                observations.append(BASSoftHandObservation(
                    kind: .escalation,
                    mode: selectedSoftHandMode,
                    subjectID: subjectID,
                    salience: min(1.0, Double(delta) * 0.20),
                    confidence: 0.90,
                    content:
                        "l12.escalation.from:" + primary.rawValue
                        + ".to:" + selectedPermitMode.rawValue
                        + ".delta:\(delta)",
                    observedAt: emittedAt
                ))
            } else if selectedRank < primaryRank {
                let delta = primaryRank - selectedRank
                observations.append(BASSoftHandObservation(
                    kind: .downgrade,
                    mode: selectedSoftHandMode,
                    subjectID: subjectID,
                    salience: min(1.0, Double(delta) * 0.20),
                    confidence: 0.90,
                    content:
                        "l12.downgrade.from:" + primary.rawValue
                        + ".to:" + selectedPermitMode.rawValue
                        + ".delta:\(delta)",
                    observedAt: emittedAt
                ))
            }

            // Render / deferral / sovereign.
            appendRenderEvidence(
                into: &observations,
                subjectID: subjectID,
                renderedOutput: renderedOutput,
                selectedSoftHandMode: selectedSoftHandMode,
                selectedPermitMode: selectedPermitMode,
                emittedAt: emittedAt
            )
            appendSovereignEscalation(
                into: &observations,
                subjectID: subjectID,
                renderedOutput: renderedOutput,
                package: package,
                emittedAt: emittedAt
            )
            return BASSoftHandObservationBundle(
                turnID: turnID,
                sessionID: sessionID,
                observations: observations,
                emittedAt: emittedAt
            )
        }

        // --- Empty-empty path: render-only signal with stable
        //     step-index subject so the bundle still carries
        //     provenance. No suggestion / direction evidence
        //     exists in the frame.
        let fallbackSubjectID =
            "l12.subject.step-\(frame.stepIndex)"
        observations.append(BASSoftHandObservation(
            kind: .selection,
            mode: selectedSoftHandMode,
            subjectID: fallbackSubjectID,
            salience: 1.0,
            confidence: 1.0,
            content:
                "l12.selection.mode:" + selectedPermitMode.rawValue,
            observedAt: emittedAt
        ))
        appendRenderEvidence(
            into: &observations,
            subjectID: fallbackSubjectID,
            renderedOutput: renderedOutput,
            selectedSoftHandMode: selectedSoftHandMode,
            selectedPermitMode: selectedPermitMode,
            emittedAt: emittedAt
        )
        appendSovereignEscalation(
            into: &observations,
            subjectID: fallbackSubjectID,
            renderedOutput: renderedOutput,
            package: nil,
            emittedAt: emittedAt
        )
        return BASSoftHandObservationBundle(
            turnID: turnID,
            sessionID: sessionID,
            observations: observations,
            emittedAt: emittedAt
        )
    }

    // MARK: - Helpers (shared render / deferral / sovereign paths)

    /// Append `.render` (if the output carries any visible content)
    /// and `.deferral` (if the output is delay-shaped) signals for
    /// the given subject.
    fileprivate static func appendRenderEvidence(
        into observations: inout [BASSoftHandObservation],
        subjectID: String,
        renderedOutput: BASRenderedOutput,
        selectedSoftHandMode: BASSoftHandMode,
        selectedPermitMode: BASActionPermitMode,
        emittedAt: Date
    ) {
        let trimmedHeadline = renderedOutput.headline
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = renderedOutput.body
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let hasContent =
            trimmedHeadline.isEmpty == false
            || trimmedBody.isEmpty == false
        if hasContent {
            observations.append(BASSoftHandObservation(
                kind: .render,
                mode: selectedSoftHandMode,
                subjectID: subjectID,
                salience: 0.95,
                confidence: 1.0,
                content:
                    "l12.render.headline-len:\(renderedOutput.headline.count)"
                    + ".body-len:\(renderedOutput.body.count)"
                    + ".alt-count:\(renderedOutput.alternativeActions.count)",
                observedAt: emittedAt
            ))
        }

        // Deferral fires when the selection is structurally a
        // delay: either the permit mode itself is .delay, or the
        // surface guide carries a delayReservation / delayWindow.
        let guide = renderedOutput.surfaceGuide
        let hasDelayEvidence =
            selectedPermitMode == .delay
            || (guide?.delayReservation != nil)
            || ((guide?.delayWindow?.isEmpty == false) == true)
        if hasDelayEvidence {
            observations.append(BASSoftHandObservation(
                kind: .deferral,
                mode: .delay,
                subjectID: subjectID,
                salience: 0.80,
                confidence: 0.90,
                content: "l12.deferral",
                observedAt: emittedAt
            ))
        }
    }

    /// Append a sovereign-forced `.escalation` signal when a
    /// sovereign escalation hint is attached — either on the
    /// surface guide (rendered path) or on the risk decision
    /// package (pre-render path). Emitted unconditionally
    /// regardless of the rank-based direction, because sovereign
    /// escalation overrides whatever L11 recommended.
    fileprivate static func appendSovereignEscalation(
        into observations: inout [BASSoftHandObservation],
        subjectID: String,
        renderedOutput: BASRenderedOutput,
        package: BASRiskDecisionPackage?,
        emittedAt: Date
    ) {
        let hasHint =
            renderedOutput.surfaceGuide?.sovereignEscalationHint != nil
            || package?.sovereignEscalationHint != nil
        guard hasHint else { return }
        observations.append(BASSoftHandObservation(
            kind: .escalation,
            mode: .boundary,
            subjectID: subjectID,
            salience: 0.95,
            confidence: 1.0,
            content: "l12.escalation.sovereign-hint",
            observedAt: emittedAt
        ))
    }
}

// MARK: - Permit-mode → soft-hand-mode mapping
//
// L11 emits a 9-case `BASActionPermitMode` in a semantic
// stringency ladder (see rank table below). L12 renders in a
// 5-case `BASSoftHandMode`. This mapping condenses nine to five
// while preserving the two key protective axes — "is this a
// boundary?" and "is this a deferred surface?":
//
//   answer     → silentStub  (no protection intervention — the
//                             hand chose not to intervene)
//   mirror     → compare     (mirror ≈ showing heard vs said on
//                             the same surface)
//   compare    → compare     (exact match)
//   draftOnly  → draft       (exact match)
//   delay      → delay       (exact match)
//   localOnly  → silentStub  (local-only = nothing rendered
//                             externally)
//   block      → boundary    (the hardest protective declaration)
//   replace    → boundary    (replacement signals the original
//                             ask crossed a boundary)
//   escalate   → boundary    (escalation signals boundary to a
//                             human / sovereign surface)
//
// MAINTAIN WITH:
//   - `BASSoftHandMode` enum (this file's sister) at
//     `BASOrchestration/BASSoftHandObservation.swift` (M27 seed).
//   - `BASActionPermitMode` enum at
//     `BASPolicy/EBrainRiskPlaneCore.swift` — adding a new
//     permit case requires extending this switch.
fileprivate func mapPermitToSoftHand(
    _ mode: BASActionPermitMode
) -> BASSoftHandMode {
    switch mode {
    case .answer:
        return .silentStub
    case .mirror:
        return .compare
    case .compare:
        return .compare
    case .draftOnly:
        return .draft
    case .delay:
        return .delay
    case .localOnly:
        return .silentStub
    case .block:
        return .boundary
    case .replace:
        return .boundary
    case .escalate:
        return .boundary
    }
}

// MARK: - Semantic stringency rank table (0 = lightest, 8 = heaviest)
//
// Shared with M56 `BASRiskObservationDerivation` — rank ordering
// is a cross-layer contract (L11 gate pressure direction and L12
// downgrade / escalation direction MUST agree). Any reordering
// here forces a matching reorder in M56.
//
// MAINTAIN WITH `BASActionPermitMode` ENUM (defined in BASPolicy
// at `EBrainRiskPlaneCore.swift:50`). Adding a new permit mode
// requires:
//   1. Extending this switch with its stringency rank.
//   2. Extending M56's identical `rank(of:)` table.
//   3. Extending M57's `mapPermitToSoftHand` switch.
//
//   answer=0 / mirror=1 / compare=2 / draftOnly=3 / localOnly=4 /
//   delay=5 / replace=6 / block=7 / escalate=8
fileprivate func rank(of mode: BASActionPermitMode) -> Int {
    switch mode {
    case .answer:
        return 0
    case .mirror:
        return 1
    case .compare:
        return 2
    case .draftOnly:
        return 3
    case .localOnly:
        return 4
    case .delay:
        return 5
    case .replace:
        return 6
    case .block:
        return 7
    case .escalate:
        return 8
    }
}
