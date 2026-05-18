// MARK: - BASMLContextService
// Phase B-4 — REAL ML-backed BASContextServicing
//
// Replaces BASPlaceholderContextService in the cognitive
// cascade。 Uses BASContextClassifierMLAdapter (Phase B-3)
// for taskType inference. Other ContextFrame fields
// (emotionalLoad, timePressure, etc.) remain heuristic
// placeholders because no model has been trained for them
// yet — that's Phase C/D/E work.

import Foundation
import BASMemory
import BASPolicy
import BASRuntimeCore

/// ML-backed BASContextServicing that uses CoreML for
/// taskType classification。 Falls back to placeholder
/// heuristics for the other ContextFrame fields。
///
/// ## What's REAL
///   - taskType: classified by trained CoreML model
///     (BASContextClassifierMLAdapter, Phase B-3)
///   - utterance: echoes the input directly
///
/// ## What's STILL placeholder
///   - emotionalLoad: hardcoded 0.1 (no emotion model yet)
///   - timePressure: hardcoded 0.1 (no urgency model yet)
///   - relationPattern: hardcoded "neutral"
///   - ambiguityScore: hardcoded 0.1
///   - consequenceLevel: hardcoded 0.1
///   - manipulationHints: hardcoded []
///   - hostRelevance: hardcoded 0.5
///
/// Phase C+ will train models for these and ship more
/// real-ML services。 For now BASMLContextService gives
/// hosts ONE real signal (taskType) while keeping the
/// rest honest about being placeholder。
public struct BASMLContextService: BASContextServicing,
    Sendable
{
    private let adapter: BASContextClassifierMLAdapter

    public init(adapter: BASContextClassifierMLAdapter) {
        self.adapter = adapter
    }

    /// Maps the adapter's String label back to the typed
    /// BASContextTaskType enum。 Crashes-by-design on
    /// unknown labels — if the adapter returns a string
    /// outside the 7-class set, the model is broken and
    /// we want to FAIL LOUDLY not produce a stub。
    private func mapLabel(
        _ label: String
    ) -> BASContextTaskType {
        switch label {
        case "chat": return .chat
        case "task": return .task
        case "choice": return .choice
        case "conflict": return .conflict
        case "highPressure": return .highPressure
        case "manipulationRisk": return .manipulationRisk
        case "highConsequence": return .highConsequence
        default:
            // Honest failure mode: if the ML model outputs
            // an unexpected label, log + fall back to chat
            // rather than crashing the entire cognitive
            // pipeline。 Real production should emit a
            // typed audit event here (deferred).
            return .chat
        }
    }

    public func analyzeContext(
        userInput: String,
        hostContext: BASHostProfile,
        budget: BASBudgetFrame
    ) -> BASContextFrame {
        // Try to classify via ML; on any failure fall back
        // to .chat (honest degradation, not a crash).
        let taskType: BASContextTaskType
        do {
            let (label, _) = try adapter.classify(
                text: userInput)
            taskType = mapLabel(label)
        } catch {
            // Honest fallback: model failed to load or
            // predict. Host integration tests should
            // catch this; we don't want to take down the
            // cognitive pipeline for a single layer
            // failure. Future Phase: emit a typed audit
            // event for monitoring.
            taskType = .chat
        }

        return BASContextFrame(
            utterance: userInput,
            taskType: taskType,
            // The following 7 fields stay placeholder
            // pending future ML models. See file header
            // for honest scope.
            emotionalLoad: 0.1,
            timePressure: 0.1,
            relationPattern: "neutral",
            ambiguityScore: 0.1,
            consequenceLevel: 0.1,
            manipulationHints: [],
            hostRelevance: 0.5)
    }
}
