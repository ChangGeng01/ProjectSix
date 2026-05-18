// MARK: - BASCognitiveBrainPlaceholderServices
// chapter 七百三十五 / M2249 第一刀 — PRODUCTION placeholder
//                                     services for the
//                                     14-layer 电子脑 facade。
//
// ## Honest scope acknowledgment
//
// These are RULES-FALLTHROUGH PLACEHOLDER implementations
// of the 11 cognitive-OS services (BASPowerClockServicing,
// BASHostProfileServicing, BASContextServicing,
// BASDecomposeServicing, BASMemoryServicing,
// BASLoopServicing, BASTriSelfServicing, BASRiskServicing,
// BASActionServicing, BASEvolutionServicing). They emit
// nominal/neutral values across every signal so the V1
// audit cascade can run end-to-end — they do NOT perform
// any real ML inference。
//
// **What this gives hosts**:
//   - One-line `BASCognitiveBrain.makeWithDefaults()`
//     construction
//   - A complete `BASEBrainTurnResult` with 50+ typed audit
//     fields (sovereign verdict / commit tokens / projection
//     bundles / etc.) populated by the V1 cascade
//   - SQLite event log + user state + vector RAG +
//     knowledge graph (via BASCognitiveOSBuilder defaults)
//
// **What this does NOT give hosts**:
//   - Real ML inference at any of the 41 canonical mesh
//     slots (see BAS14LayerMeshAssembler:118)
//   - Real Rust pilot invocation from the Swift turn path
//   - G8 Mamba SSM real inference (state-shell only)
//
// **Phase B replacement target**: replace
// `Placeholder*Service` with adapter services that invoke
// real CoreML/MLX heads trained from substrate corpus。
//
// ## Provenance
//
// These services are production-grade copies of the
// `Tests/BehavioralAISubstrateTests/BASCoordinatorTestStubs
// .swift` test stubs (chapter 462 / M1225) but exposed
// publicly so hosts get a default facade without depending
// on the test target。 Behavior is IDENTICAL — same nominal
// outputs。 The only difference is module location +
// public visibility。

import Foundation
import BASMemory
import BASPolicy
import BASRuntimeCore

/// Centralized constants for the BASPlaceholder* services。
///
/// These are NOT magic numbers — they are documented
/// nominal values that drive the rules-fallthrough cascade
/// when no ML adapter is wired into a given service。 Each
/// constant has a rationale + the Phase that will replace
/// it with real ML inference。
///
/// **Why centralize**: previously each placeholder service
/// inlined `0.1` / `0.5` / `0.2` / `1` / `100` literals。
/// Centralizing forces every value to be NAMED + makes the
/// scope of the placeholder layer audit-able in one place。
public enum BASCognitiveBrainPlaceholderConstants {

    // MARK: - Budget frame (PowerClock service)

    /// Default budget loop limit。 1 loop = single-pass
    /// cognition,no iterative refinement。 Phase C+ will
    /// raise this based on risk class + budget。
    public static let defaultMaxLoops: Int = 1
    /// Default candidate-path limit。 1 candidate = no
    /// branching, just pick the model's top choice。
    public static let defaultMaxCandidates: Int = 1
    /// Default decode-token cap。 100 = short reply。
    public static let defaultMaxDecodeTokens: Int = 100
    /// Default retrieval depth (memory hops)。 1 = single
    /// lookup,no graph traversal。
    public static let defaultRetrievalDepth: Int = 1
    /// Default output-length cap (chars) for action permit。
    public static let defaultOutputLengthCap: Int = 100

    // MARK: - Context frame (ContextService placeholder)

    /// Neutral emotional-load。 Slightly non-zero baseline
    /// indicating "small but present" arousal vs vacuous 0。
    public static let neutralEmotionalLoad: Double = 0.1
    /// Neutral time-pressure。
    public static let neutralTimePressure: Double = 0.1
    /// Neutral ambiguity-score for the placeholder
    /// service。 (BASMLContextService overrides this with
    /// real 1-confidence value。)
    public static let neutralAmbiguityScore: Double = 0.1
    /// Neutral consequence-level。
    public static let neutralConsequenceLevel: Double = 0.1
    /// Neutral host-relevance score。 0.5 = "neither
    /// strongly relevant nor irrelevant"。
    public static let neutralHostRelevance: Double = 0.5
    /// Neutral relation-pattern string tag。
    public static let neutralRelationPattern: String =
        "neutral"

    // MARK: - Candidate path (Loop service)

    /// Neutral expected-benefit / expected-cost /
    /// reversibility / confidence for a single placeholder
    /// candidate path。 0.5 = no strong signal either way。
    public static let neutralCandidateScore: Double = 0.5
    /// Neutral forecast uncertainty。 0.3 = "moderate"。
    public static let neutralForecastUncertainty:
        Double = 0.3
    /// Neutral critique severity (evidence-gap critique
    /// applied to every candidate by placeholder)。
    public static let neutralCritiqueSeverity: Double = 0.3
    /// Neutral thought-frame stability score。
    public static let neutralStabilityScore: Double = 0.5
    /// Step index for the single placeholder thought-frame
    /// iteration。
    public static let placeholderStepIndex: Int = 0

    // MARK: - TriSelf scores

    /// Neutral id / ego / superego / merged scores for the
    /// 3-self merge。 All 0.5 = no veto, no preference。
    public static let neutralTriSelfScore: Double = 0.5

    // MARK: - Risk

    /// Total-risk score for placeholder。 Low (0.2)
    /// because the cascade has no real risk-analysis ML。
    public static let neutralTotalRisk: Double = 0.2
    /// Risk-card uncertainty。
    public static let neutralRiskUncertainty: Double = 0.2
    /// Risk-card irreversibility。
    public static let neutralRiskIrreversibility:
        Double = 0.1
    /// Risk-card manipulation-strength (zero by default —
    /// only the ML context classifier surfaces manipulation,
    /// not the placeholder risk service)。
    public static let neutralRiskManipulationStrength:
        Double = 0.0
    /// Generalized safety index (GSI) baseline。
    public static let neutralGSIScore: Double = 0.2

    // MARK: - String tags

    /// Tag string emitted by every placeholder service for
    /// fields where rich semantic text would come from a
    /// real ML head (e.g. action.headline, critique.text)。
    /// Auditors can grep on this to find every placeholder
    /// emission site。
    public static let placeholderTag: String = "placeholder"
    /// Tag for placeholder-derived candidate identifiers。
    public static let placeholderCandidateID: String =
        "placeholder-c1"
    /// Tag for placeholder-derived decompose-frame
    /// identifiers。
    public static let placeholderDecomposeRef: String =
        "placeholder-decomp"
    /// Tone-policy string for placeholder action permit。
    public static let placeholderTonePolicy: String =
        "neutral"
    /// Template-policy string for placeholder action permit。
    public static let placeholderTemplatePolicy: String =
        "default"
    /// "long term goal" string for the placeholder host
    /// profile。
    public static let placeholderHostLongTermGoal:
        String = "placeholder"
}

/// Placeholder PowerClock service — returns nominal budget
/// + scout-CPU route + no maintenance。 No power planning。
public struct BASPlaceholderPowerClockService:
    BASPowerClockServicing, Sendable
{
    public init() {}

    public func planBudget(
        deviceState: BASDeviceState,
        taskPing: String,
        riskHint: BASBrainRiskLevel?
    ) -> BASBudgetFrame {
        let K = BASCognitiveBrainPlaceholderConstants.self
        return BASBudgetFrame(
            runMode: .engage,
            maxLoops: K.defaultMaxLoops,
            maxCandidates: K.defaultMaxCandidates,
            maxDecodeTokens: K.defaultMaxDecodeTokens,
            retrievalDepth: K.defaultRetrievalDepth,
            precisionProfile: .minimal,
            deviceRoute: .scoutCPU,
            thermalGuardLevel: .nominal,
            maintenanceAllowed: false)
    }

    public func routeDevice(
        deviceState: BASDeviceState,
        budget: BASBudgetFrame
    ) -> BASDeviceRoute {
        return budget.deviceRoute
    }

    public func scheduleMaintenance(
        deviceState: BASDeviceState,
        budget: BASBudgetFrame
    ) -> Bool {
        return false
    }
}

/// Placeholder HostProfile service — returns trivial
/// host profile, no host gating, trivial rollback。
public struct BASPlaceholderHostProfileService:
    BASHostProfileServicing, Sendable
{
    public init() {}

    public func resolveHost(
        hostID: String,
        contextFrame: BASContextFrame?,
        riskCard: BASRiskCard?
    ) -> BASHostProfile {
        return BASHostProfile(
            hostID: hostID,
            longTermGoals: [
                BASCognitiveBrainPlaceholderConstants
                    .placeholderHostLongTermGoal
            ],
            noGoZones: [])
    }

    public func applyHostGate(
        profile: BASHostProfile,
        taskType: BASContextTaskType,
        riskCard: BASRiskCard?,
        confidence: Double
    ) -> Double {
        return confidence
    }

    public func rollbackHostVersion(
        profile: BASHostProfile,
        to versionID: String
    ) -> BASHostVersion {
        return BASHostVersion(
            versionID: versionID,
            changedFields: [],
            reason: BASCognitiveBrainPlaceholderConstants
                .placeholderTag,
            approvedByPolicy: true)
    }
}

/// Placeholder Context service — returns a neutral context
/// frame echoing the userInput as utterance。
public struct BASPlaceholderContextService:
    BASContextServicing, Sendable
{
    public init() {}

    public func analyzeContext(
        userInput: String,
        hostContext: BASHostProfile,
        budget: BASBudgetFrame
    ) -> BASContextFrame {
        let K = BASCognitiveBrainPlaceholderConstants.self
        return BASContextFrame(
            utterance: userInput,
            taskType: .chat,
            emotionalLoad: K.neutralEmotionalLoad,
            timePressure: K.neutralTimePressure,
            relationPattern: K.neutralRelationPattern,
            ambiguityScore: K.neutralAmbiguityScore,
            consequenceLevel: K.neutralConsequenceLevel,
            manipulationHints: [],
            hostRelevance: K.neutralHostRelevance)
    }
}

/// Placeholder Decompose service — returns an empty
/// decomposition frame with a trivial mirror string。
public struct BASPlaceholderDecomposeService:
    BASDecomposeServicing, Sendable
{
    public init() {}

    public func decompose(
        contextFrame: BASContextFrame,
        memoryHints: [String]
    ) -> BASDecomposeFrame {
        return BASDecomposeFrame(
            facts: [],
            goals: [],
            emotions: [],
            unknowns: [],
            contradictions: [],
            pressureSignals: [],
            manipulationSignals: [],
            mirrorText:
                BASCognitiveBrainPlaceholderConstants
                    .placeholderTag + " mirror")
    }

    public func mirror(
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame
    ) -> String {
        return decomposeFrame.mirrorText
    }

    public func checkContradiction(
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame
    ) -> [String] {
        return []
    }
}

/// Placeholder Memory service — returns an empty memory
/// bundle, candidate-state promotion, freeze succeeds。
public struct BASPlaceholderMemoryService:
    BASMemoryServicing, Sendable
{
    public init() {}

    public func retrieve(
        decomposeFrame: BASDecomposeFrame,
        hostContext: BASHostProfile,
        budget: BASBudgetFrame
    ) -> BASMemoryBundle {
        return BASMemoryBundle(
            atoms: [],
            retrievalTags: [],
            activeHostVersion: hostContext.activeVersion)
    }

    public func promote(
        atom: BASMemoryAtom,
        hostContext: BASHostProfile
    ) -> BASPromotionState {
        return .candidate
    }

    public func freeze(memoryID: String) -> Bool {
        return true
    }
}

/// Placeholder Loop service — returns one trivial
/// candidate path with neutral scores。 No real reasoning。
public struct BASPlaceholderLoopService:
    BASLoopServicing, Sendable
{
    public init() {}

    public func proposePaths(
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle,
        budget: BASBudgetFrame
    ) -> [BASCandidatePath] {
        let K = BASCognitiveBrainPlaceholderConstants.self
        return [
            BASCandidatePath(
                candidateID: K.placeholderCandidateID,
                title: K.placeholderTag,
                actionSummary: K.placeholderTag,
                expectedBenefit: K.neutralCandidateScore,
                expectedCost: K.neutralCandidateScore,
                reversibility: K.neutralCandidateScore,
                confidence: K.neutralCandidateScore)
        ]
    }

    public func forecast(
        candidates: [BASCandidatePath],
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle
    ) -> [BASForecastItem] {
        let K = BASCognitiveBrainPlaceholderConstants.self
        return candidates.map {
            BASForecastItem(
                candidateID: $0.candidateID,
                shortTermOutcome: K.placeholderTag,
                midTermOutcome: K.placeholderTag,
                worstCase: K.placeholderTag,
                uncertainty: K.neutralForecastUncertainty)
        }
    }

    public func critique(
        candidates: [BASCandidatePath],
        forecasts: [BASForecastItem],
        hostContext: BASHostProfile
    ) -> [BASCritiqueItem] {
        let K = BASCognitiveBrainPlaceholderConstants.self
        return candidates.map {
            BASCritiqueItem(
                candidateID: $0.candidateID,
                critiqueType: .evidenceGap,
                critiqueText: K.placeholderTag,
                severity: K.neutralCritiqueSeverity)
        }
    }

    public func iterate(
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle,
        budget: BASBudgetFrame
    ) -> BASThoughtFrame {
        let K = BASCognitiveBrainPlaceholderConstants.self
        let candidates = proposePaths(
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle,
            budget: budget)
        return BASThoughtFrame(
            stepIndex: K.placeholderStepIndex,
            decomposeRef: K.placeholderDecomposeRef,
            memoryRefs: [],
            candidates: candidates,
            forecasts: forecast(
                candidates: candidates,
                decomposeFrame: decomposeFrame,
                memoryBundle: memoryBundle),
            critiques: critique(
                candidates: candidates,
                forecasts: [],
                hostContext: BASHostProfile(
                    hostID: K.placeholderTag)),
            stabilityScore: K.neutralStabilityScore,
            stopReason: .candidateStable)
    }
}

/// Placeholder TriSelf service — neutral merge with no
/// veto + picks first candidate。
public struct BASPlaceholderTriSelfService:
    BASTriSelfServicing, Sendable
{
    public init() {}

    public func mergeChoice(
        thoughtFrame: BASThoughtFrame,
        hostContext: BASHostProfile
    ) -> ([BASTriSelfScore], BASMergedChoice) {
        let K = BASCognitiveBrainPlaceholderConstants.self
        let scores = thoughtFrame.candidates.map {
            BASTriSelfScore(
                candidateID: $0.candidateID,
                idScore: K.neutralTriSelfScore,
                egoScore: K.neutralTriSelfScore,
                superegoScore: K.neutralTriSelfScore,
                mergedScore: K.neutralTriSelfScore,
                veto: false)
        }
        let pick = thoughtFrame.candidates.first
            ?? BASCandidatePath(
                candidateID: K.placeholderCandidateID,
                title: K.placeholderTag,
                actionSummary: K.placeholderTag,
                expectedBenefit: K.neutralCandidateScore,
                expectedCost: K.neutralCandidateScore,
                reversibility: K.neutralCandidateScore,
                confidence: K.neutralCandidateScore)
        return (
            scores,
            BASMergedChoice(
                candidateID: pick.candidateID,
                title: pick.title,
                actionSummary: pick.actionSummary))
    }
}

/// Placeholder Risk service — returns low-risk card with
/// answer permit。 No real risk modeling。
public struct BASPlaceholderRiskService:
    BASRiskServicing, Sendable
{
    public init() {}

    public func calibrateRisk(
        contextFrame: BASContextFrame,
        thoughtFrame: BASThoughtFrame,
        triScores: [BASTriSelfScore],
        budget: BASBudgetFrame
    ) -> BASRiskCard {
        let K = BASCognitiveBrainPlaceholderConstants.self
        return BASRiskCard(
            totalRisk: K.neutralTotalRisk,
            riskLevel: .low,
            factors: [],
            uncertainty: K.neutralRiskUncertainty,
            irreversibility: K.neutralRiskIrreversibility,
            manipulationStrength:
                K.neutralRiskManipulationStrength,
            gsiScore: K.neutralGSIScore,
            recommendedMode: .answer)
    }

    public func computeGSI(
        contextFrame: BASContextFrame,
        thoughtFrame: BASThoughtFrame
    ) -> Double {
        return BASCognitiveBrainPlaceholderConstants
            .neutralGSIScore
    }

    public func gateAction(
        contextFrame: BASContextFrame,
        thoughtFrame: BASThoughtFrame,
        triScores: [BASTriSelfScore],
        budget: BASBudgetFrame
    ) -> (BASRiskCard, BASActionPermit) {
        let K = BASCognitiveBrainPlaceholderConstants.self
        return (
            calibrateRisk(
                contextFrame: contextFrame,
                thoughtFrame: thoughtFrame,
                triScores: triScores,
                budget: budget),
            BASActionPermit(
                mode: .answer,
                reasonCodes: [K.placeholderTag],
                outputLengthCap:
                    K.defaultOutputLengthCap,
                tonePolicy: K.placeholderTonePolicy,
                templatePolicy:
                    K.placeholderTemplatePolicy))
    }
}

/// Placeholder Action service — echoes the merged choice
/// as headline/body。
public struct BASPlaceholderActionService:
    BASActionServicing, Sendable
{
    public init() {}

    public func render(
        choice: BASMergedChoice,
        riskCard: BASRiskCard,
        permit: BASActionPermit,
        hostContext: BASHostProfile
    ) -> BASRenderedOutput {
        return BASRenderedOutput(
            mode: permit.mode,
            headline: choice.title,
            body: choice.actionSummary,
            alternativeActions: [],
            explanationCodes: permit.reasonCodes)
    }
}

/// Placeholder Evolution service — emits no update tickets。
public struct BASPlaceholderEvolutionService:
    BASEvolutionServicing, Sendable
{
    public init() {}

    public func buildTickets(
        thoughtFrame: BASThoughtFrame,
        output: BASRenderedOutput,
        feedbackEvent: BASFeedbackEvent?
    ) -> [BASUpdateTicket] {
        return []
    }
}
