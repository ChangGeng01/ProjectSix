// MARK: - BASCognitiveBrain safety/risk verdict + cascade digest (Phase B+ ML safety gate)
// chapter 一千〇四十 / WS-brain-decomp — relocated from BASCognitiveBrain.swift (god-object split).
// `extension BASCognitiveBrain` cluster — same actor, same symbols, call sites unchanged.
// Designated inits stay in the actor body (Swift requires it); only these methods relocate.
// Pure relocation ⇒ byte-equal (cascade-digest net).

import Foundation
import CryptoKit
import BASMemory
import BASPolicy
import BASRuntimeCore
import BASMetalSubstrate
import BASRustCoreBridge
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

extension BASCognitiveBrain {
    // MARK: - Safety verdict (Phase B+: real ML safety gate)

    /// Confidence threshold above which a hazardous
    /// classification triggers a verdict change。 Below
    /// the threshold,the classifier isn't sure enough to
    /// override .safe。 0.6 = "more sure than wrong"
    /// without requiring overwhelming evidence。
    ///
    /// ## Architectural decision (documented)
    ///
    /// Threshold 0.6 chosen because:
    ///   - Random 7-class guess has confidence ~0.143
    ///     (1/7)
    ///   - 0.6 is well above guess-rate (won't fire on
    ///     ambiguous input)
    ///   - But well below "extremely sure" (0.9+),so
    ///     models with imperfect training still surface
    ///     genuine risks
    ///   - A future config knob can expose this if
    ///     hosts need different sensitivity profiles
    public static let safetyConfidenceThreshold: Double
        = 0.6

    /// The "1" in `confidence = 1 - ambiguityScore` (and
    /// vice versa)。 Named so the inversion semantics are
    /// explicit at every call site that derives one from
    /// the other。
    public static let ambiguityComplement: Double = 1.0

    /// Clamp a host-supplied safety threshold into the
    /// valid [0, 1] confidence range。 Out-of-range values
    /// are not errors — they're treated as the nearest
    /// boundary。 An input of -0.5 becomes 0 (always
    /// escalate);1.5 becomes 1 (never escalate)。
    public static func clampedThreshold(
        _ raw: Double
    ) -> Double {
        if raw.isNaN { return safetyConfidenceThreshold }
        return min(max(raw, 0.0), 1.0)
    }

    /// Compute a typed safety verdict for a user input。
    /// Uses the ML context classifier internally。
    ///
    /// **Returns** a tuple of:
    ///   - verdict: .safe / .warn / .block typed enum
    ///   - taskType: the underlying ML classification
    ///   - confidence: softmax confidence of the
    ///     classification
    ///
    /// **Verdict rules** (real product behavior, NOT
    /// placeholder):
    ///   - .block if taskType == .manipulationRisk AND
    ///     confidence ≥ safetyConfidenceThreshold
    ///   - .warn if taskType ∈ [.highPressure,
    ///     .highConsequence, .conflict] AND confidence ≥
    ///     safetyConfidenceThreshold
    ///   - .safe otherwise (chat, task, choice, or any
    ///     low-confidence prediction)
    public func safetyVerdict(
        _ input: String,
        deviceState: BASDeviceState =
            BASCognitiveBrain.defaultDeviceState,
        hostID: String =
            BASCognitiveBrain.defaultHostID
    ) async -> (verdict: BASCognitiveSafetyVerdict,
                taskType: BASContextTaskType,
                confidence: Double) {
        // Run the full process — gives the host the
        // ContextFrame which already has taskType +
        // ambiguityScore (= 1 - confidence)。 Threading
        // deviceState + hostID through preserves the
        // same plumbing as `summary(_:)` and `process
        // (_:)` so all three entry points see consistent
        // turn context。
        let result = await self.process(
            input,
            deviceState: deviceState,
            hostID: hostID)
        let taskType = result.contextFrame.taskType
        // confidence ≡ 1 - ambiguityScore (BASMLContextService
        // sets ambiguityScore as the softmax-confidence
        // complement). Documented inversion, not a magic
        // constant.
        let confidence =
            BASCognitiveBrain.ambiguityComplement
                - result.contextFrame.ambiguityScore
        let verdict: BASCognitiveSafetyVerdict
        if confidence >=
            instanceSafetyConfidenceThreshold
        {
            switch taskType {
            case .manipulationRisk:
                verdict = .block
            case .highPressure, .highConsequence,
                .conflict:
                verdict = .warn
            case .chat, .task, .choice:
                verdict = .safe
            }
        } else {
            // Low confidence → don't override safe。
            verdict = .safe
        }
        return (verdict, taskType, confidence)
    }

    /// Compute a typed risk verdict for a user input
    /// using the L5 risk service (BASMLRiskService when
    /// the brain was built via the ML init path)。 Runs
    /// the full cascade,extracts the BASRiskCard
    /// produced by the risk service,returns a host-
    /// friendly Codable bundle。
    ///
    /// **Why this exists**: hosts integrating the brain
    /// for safety-aware UI need both the safety verdict
    /// (typed L0 mapping) AND the typed risk level
    /// (L5 deterministic derivation)。 The risk level
    /// is more granular (4 classes: low/medium/high/
    /// extreme) than the safety verdict (3 classes:
    /// safe/warn/block) and includes the factors array
    /// for telemetry。 This surface exposes it without
    /// requiring hosts to dig through the full
    /// BASEBrainTurnResult。
    public func riskVerdict(
        _ input: String,
        deviceState: BASDeviceState =
            BASCognitiveBrain.defaultDeviceState,
        hostID: String =
            BASCognitiveBrain.defaultHostID
    ) async -> BASCognitiveBrainRiskBundle {
        let result = await self.process(
            input,
            deviceState: deviceState,
            hostID: hostID)
        let card = result.riskCard
        return BASCognitiveBrainRiskBundle(
            input: input,
            riskLevel: card.riskLevel,
            totalRisk: card.totalRisk,
            factors: card.factors,
            recommendedMode: card.recommendedMode,
            manipulationStrength: card
                .manipulationStrength,
            uncertainty: card.uncertainty,
            irreversibility: card.irreversibility)
    }

    /// Unified cascade snapshot — runs the brain's full
    /// cognitive cascade once and returns a Codable
    /// bundle exposing every ML-active layer's
    /// contribution。 This is the recommended API for
    /// hosts wanting complete cascade visibility without
    /// digging through BASEBrainTurnResult's 50+ fields。
    ///
    /// **Layer mapping**:
    ///   L0 (context)    → taskType / confidence /
    ///                    ambiguityScore / signals /
    ///                    manipulationHints
    ///   L1 (memory)     → recalledAtomCount /
    ///                    memoryRetrievalTags
    ///   L2 (decompose)  → decomposeSignals (union of
    ///                    all 5 signal arrays)
    ///   L3 (loop)       → candidateCount /
    ///                    candidateIDs
    ///   L4 (triself)    → mergedScore / vetoApplied
    ///   L5 (risk)       → riskLevel / totalRisk /
    ///                    riskFactors / recommendedMode
    ///   L6 (action)     → renderedHeadline /
    ///                    alternativeActionCount
    ///   L7 (evolution)  → ticketCount / ticketSummaries
    public func cascadeDigest(
        _ input: String,
        deviceState: BASDeviceState =
            BASCognitiveBrain.defaultDeviceState,
        hostID: String =
            BASCognitiveBrain.defaultHostID
    ) async -> BASCognitiveBrainCascadeDigest {
        let result = await self.process(
            input,
            deviceState: deviceState,
            hostID: hostID)
        let contextFrame = result.contextFrame
        let decomposeFrame = result.decomposeFrame
        let thoughtFrame = result.thoughtFrame
        let memoryBundle = result.memoryBundle
        let card = result.riskCard
        let rendered = result.renderedOutput
        let tickets = result.updateTickets
        // L1 decompose signals — union of all 5 typed
        // signal arrays from L2 decompose service。
        var decomposeSignals: [String] = []
        decomposeSignals.append(
            contentsOf: decomposeFrame.emotions)
        decomposeSignals.append(
            contentsOf: decomposeFrame.pressureSignals)
        decomposeSignals.append(
            contentsOf: decomposeFrame
                .manipulationSignals)
        decomposeSignals.append(
            contentsOf: decomposeFrame.unknowns)
        decomposeSignals.append(
            contentsOf: decomposeFrame.contradictions)
        // L4 triself — average merged score across
        // candidates (single representative scalar)
        let avgMergedScore: Double
        if thoughtFrame.triScores.isEmpty {
            avgMergedScore = 0.0
        } else {
            avgMergedScore = thoughtFrame.triScores
                .map { $0.mergedScore }
                .reduce(0, +)
                / Double(thoughtFrame.triScores.count)
        }
        let vetoApplied = thoughtFrame.triScores
            .allSatisfy { $0.veto }
            && !thoughtFrame.triScores.isEmpty
        return BASCognitiveBrainCascadeDigest(
            input: input,
            taskType: contextFrame.taskType,
            confidence: BASCognitiveBrain
                .ambiguityComplement
                - contextFrame.ambiguityScore,
            ambiguityScore: contextFrame.ambiguityScore,
            emotionalLoad: contextFrame.emotionalLoad,
            timePressure: contextFrame.timePressure,
            consequenceLevel: contextFrame
                .consequenceLevel,
            relationPattern: contextFrame
                .relationPattern,
            manipulationHints: contextFrame
                .manipulationHints,
            recalledAtomCount: memoryBundle.atoms.count,
            memoryRetrievalTags: memoryBundle
                .retrievalTags,
            decomposeSignals: decomposeSignals,
            candidateCount: thoughtFrame.candidates
                .count,
            candidateIDs: thoughtFrame.candidates.map {
                $0.candidateID },
            mergedScore: avgMergedScore,
            vetoApplied: vetoApplied,
            riskLevel: card.riskLevel,
            totalRisk: card.totalRisk,
            riskFactors: card.factors,
            recommendedMode: card.recommendedMode,
            renderedHeadline: rendered.headline,
            alternativeActionCount: rendered
                .alternativeActions.count,
            ticketCount: tickets.count,
            ticketSummaries: tickets.map { $0.summary })
    }
}
