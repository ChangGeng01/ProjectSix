// MARK: - BASCognitiveBrain result/value types (cascade digest · risk · verdict · summary)
// chapter 一千〇四十 / WS-brain-decomp — relocated from BASCognitiveBrain.swift (god-object split).
// Pure value types (Codable snapshots the brain returns). Same module + top-level names ⇒ byte-equal:
// every call site (the actor, its extensions, tests) resolves these unqualified, unchanged.

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

/// Unified Codable snapshot returned by
/// `BASCognitiveBrain.cascadeDigest(_:)`。 Surfaces every
/// ML-active layer's contribution in one host-friendly
/// bundle。 Fields are grouped by cascade layer below。
public struct BASCognitiveBrainCascadeDigest: Codable,
    Equatable, Sendable, Hashable
{
    // L0 context
    public let input: String
    public let taskType: BASContextTaskType
    public let confidence: Double
    public let ambiguityScore: Double
    public let emotionalLoad: Double
    public let timePressure: Double
    public let consequenceLevel: Double
    public let relationPattern: String
    public let manipulationHints: [String]

    // L1 memory
    public let recalledAtomCount: Int
    public let memoryRetrievalTags: [String]

    // L2 decompose
    public let decomposeSignals: [String]

    // L3 loop
    public let candidateCount: Int
    public let candidateIDs: [String]

    // L4 triself
    public let mergedScore: Double
    public let vetoApplied: Bool

    // L5 risk
    public let riskLevel: BASBrainRiskLevel
    public let totalRisk: Double
    public let riskFactors: [String]
    public let recommendedMode: BASActionPermitMode

    // L6 action
    public let renderedHeadline: String
    public let alternativeActionCount: Int

    // L7 evolution
    public let ticketCount: Int
    public let ticketSummaries: [String]

    public init(
        input: String,
        taskType: BASContextTaskType,
        confidence: Double,
        ambiguityScore: Double,
        emotionalLoad: Double,
        timePressure: Double,
        consequenceLevel: Double,
        relationPattern: String,
        manipulationHints: [String],
        recalledAtomCount: Int,
        memoryRetrievalTags: [String],
        decomposeSignals: [String],
        candidateCount: Int,
        candidateIDs: [String],
        mergedScore: Double,
        vetoApplied: Bool,
        riskLevel: BASBrainRiskLevel,
        totalRisk: Double,
        riskFactors: [String],
        recommendedMode: BASActionPermitMode,
        renderedHeadline: String,
        alternativeActionCount: Int,
        ticketCount: Int,
        ticketSummaries: [String]
    ) {
        self.input = input
        self.taskType = taskType
        self.confidence = confidence
        self.ambiguityScore = ambiguityScore
        self.emotionalLoad = emotionalLoad
        self.timePressure = timePressure
        self.consequenceLevel = consequenceLevel
        self.relationPattern = relationPattern
        self.manipulationHints = manipulationHints
        self.recalledAtomCount = recalledAtomCount
        self.memoryRetrievalTags = memoryRetrievalTags
        self.decomposeSignals = decomposeSignals
        self.candidateCount = candidateCount
        self.candidateIDs = candidateIDs
        self.mergedScore = mergedScore
        self.vetoApplied = vetoApplied
        self.riskLevel = riskLevel
        self.totalRisk = totalRisk
        self.riskFactors = riskFactors
        self.recommendedMode = recommendedMode
        self.renderedHeadline = renderedHeadline
        self.alternativeActionCount =
            alternativeActionCount
        self.ticketCount = ticketCount
        self.ticketSummaries = ticketSummaries
    }
}

/// Lightweight Codable bundle returned by
/// `BASCognitiveBrain.riskVerdict(_:)`。 Wraps the most
/// useful BASRiskCard fields for typical host
/// consumption without surfacing the full risk-frame
/// internals。
public struct BASCognitiveBrainRiskBundle: Codable,
    Equatable, Sendable, Hashable
{
    /// The user input as received。
    public let input: String

    /// Typed risk level — one of .low / .medium /
    /// .high / .extreme。
    public let riskLevel: BASBrainRiskLevel

    /// Total risk score in [0, 1]。 0 = safe,1 =
    /// maximum risk。 Derived from the L0 ML signals
    /// via a documented weighted combination。
    public let totalRisk: Double

    /// Risk factors that contributed to the assessment。
    /// Stable identifiers like "manipulation_detected",
    /// "high_consequence",etc。 Empty when no factor
    /// exceeded the elevated threshold。
    public let factors: [String]

    /// Recommended action permit mode based on risk
    /// level。 .answer / .compare / .delay etc。
    public let recommendedMode: BASActionPermitMode

    /// Strength of the manipulation signal in [0, 1]。
    /// Non-zero only when the L0 classifier surfaced
    /// .manipulationRisk。
    public let manipulationStrength: Double

    /// Confidence-inverted ambiguity score from L0。
    /// 0 = certain,1 = maximum uncertainty。
    public let uncertainty: Double

    /// Irreversibility echo of consequenceLevel in [0, 1]。
    /// High value = action is hard to undo。
    public let irreversibility: Double

    public init(
        input: String,
        riskLevel: BASBrainRiskLevel,
        totalRisk: Double,
        factors: [String],
        recommendedMode: BASActionPermitMode,
        manipulationStrength: Double,
        uncertainty: Double,
        irreversibility: Double
    ) {
        self.input = input
        self.riskLevel = riskLevel
        self.totalRisk = totalRisk
        self.factors = factors
        self.recommendedMode = recommendedMode
        self.manipulationStrength = manipulationStrength
        self.uncertainty = uncertainty
        self.irreversibility = irreversibility
    }
}

/// Typed safety verdict for `BASCognitiveBrain.safetyVerdict
/// (_:)`。 Hosts gate user input on this — `.block` should
/// stop processing,`.warn` should surface a confirmation,
/// `.safe` proceeds normally。
public enum BASCognitiveSafetyVerdict: String,
    Codable, Sendable, Hashable, CaseIterable
{
    /// Safe to proceed with default behavior。
    case safe
    /// Caution — model flagged urgency/consequence/conflict
    /// with reasonable confidence。 Host should surface
    /// confirmation before destructive operations。
    case warn
    /// Block — model flagged manipulation/coercion with
    /// reasonable confidence。 Host should reject the
    /// request or escalate to a human reviewer。
    case block
}

/// Lightweight DTO exposing the most useful signals from a
/// cognitive brain turn。 Wraps the 50-field
/// BASEBrainTurnResult into 6 fields hosts actually need。
///
/// **Why this exists**: BASEBrainTurnResult has 50+ typed
/// fields covering the full V1 cascade — useful for audit /
/// inspection but unwieldy for typical app integration。
/// `BASCognitiveBrainSummary` is the recommended "I just
/// want to know what the brain thinks" DTO。
public struct BASCognitiveBrainSummary: Codable,
    Equatable, Sendable, Hashable
{
    /// The user input as received。 Echoes
    /// contextFrame.utterance。
    public let input: String

    /// ML-classified task type (one of 7 BASContextTaskType
    /// cases)。
    public let taskType: BASContextTaskType

    /// Softmax confidence of the taskType classification,
    /// in [0, 1]。 1.0 = model is certain;~0.143 (1/7) =
    /// model is guessing uniformly。
    public let confidence: Double

    /// 1 - confidence, clamped to [0, 1]。 Echoes
    /// contextFrame.ambiguityScore。 Useful for callers
    /// that want a "how uncertain is the model" signal
    /// directly instead of computing it from confidence。
    public let ambiguityScore: Double

    /// Typed safety verdict (.safe / .warn / .block)
    /// computed by BASCognitiveBrain.safetyVerdict(_:)
    /// rules。
    public let safetyVerdict: BASCognitiveSafetyVerdict

    /// ML-derived manipulation signals。 Non-empty when
    /// taskType == .manipulationRisk;each entry is a
    /// typed hint like "ml.classifier.confidence=0.XXX"。
    public let manipulationHints: [String]

    /// Wall-clock latency in nanoseconds for the full
    /// summary call (engine cascade + ML inference)。
    /// Measured via the C pilot (BASMonotonicNanos
    /// `clock_gettime_nsec_np`) when the C bridge is
    /// available,V1 DispatchTime fallback otherwise。
    /// Always non-zero for a successful summary call。
    public let latencyNanos: UInt64

    /// ML-derived emotional-load score in [0, 1]。
    /// Sum of softmax probability mass on the four
    /// "non-calm" classes (highPressure + highConsequence
    /// + conflict + manipulationRisk)。 High value = input
    /// is emotionally charged。 0.0 for pre-derived-signals
    /// summaries (default value preserves backwards-compat
    /// for hosts that constructed summaries by hand)。
    public let emotionalLoad: Double

    /// ML-derived urgency score in [0, 1]。 Direct
    /// softmax probability for the highPressure class。
    /// High value = input expresses time pressure。
    public let timePressure: Double

    /// ML-derived consequence score in [0, 1]。 Direct
    /// softmax probability for the highConsequence class。
    /// High value = input describes stakes / consequential
    /// decisions。
    public let consequenceLevel: Double

    /// ML-derived relation-pattern tag。 Either "tense"
    /// (P(conflict) above threshold 0.3) or "neutral"
    /// (otherwise)。 Hosts use this for relationship-
    /// aware UI affordances。
    public let relationPattern: String

    /// 主线 加强 实用性 — number of times this exact input
    /// has been seen BEFORE the current call,across the
    /// native history pilots (SQL + Rust)。 Counts come
    /// from the actual storage engine query (SQL `COUNT(*)
    /// WHERE atom_id = ?` or Rust HashMap filter),NOT
    /// from Swift-side folding。 Hosts use this to:
    ///   - detect repeated manipulation attempts ("user
    ///     has asked this 5 times in this conversation")
    ///   - score user-input familiarity for ML cascade
    ///     weighting
    ///   - skip expensive downstream work on known-safe
    ///     repeats
    ///
    /// 0 when no history pilot is wired OR the input is
    /// genuinely first-seen。 Pre-history hosts (no SQL,
    /// no Rust) always see 0 — the default value
    /// preserves backward-compat for constructed-by-hand
    /// summaries。
    public let repetitionCount: Int

    /// 主线 加强 实用性 — true when this exact input has
    /// been observed across MULTIPLE distinct brain
    /// sessions (different sessionRef values)。 Computed
    /// from the native history pilot's per-atom record
    /// set。 Captures "this input echoes across sessions"
    /// — a signal that some users have a recurring topic
    /// vs a one-off question。
    ///
    /// False when:
    ///   - No history pilot wired
    ///   - Input first-seen
    ///   - All occurrences came from the same session
    ///     (i.e. same brain instance)
    public let crossSessionEcho: Bool

    /// 主线 继续 开发 — Metal-derived deterministic
    /// signature。 Non-nil ONLY when the Metal pilot is
    /// wired AND the brain.summary cascade actually
    /// dispatched the SSMScan kernel for this input。
    ///
    /// Computation (deterministic for a given input):
    ///   1. SHA256(input UTF-8) → first 8 bytes
    ///   2. 8 bytes → 2 Float32 channels normalized to
    ///      [-1, 1] via (raw_uint32 / UInt32.max) - 0.5
    ///   3. Build (B=1, L=1, D=2) SSM scan inputs:
    ///        x[i] = channel[i]
    ///        delta[i] = abs(channel[i]) + 0.5
    ///        A[i] = -0.5
    ///        B[i] = 1.0
    ///        C[i] = 1.0
    ///   4. Dispatch on GPU,read back y[0..2]
    ///   5. Signature = sqrt(y[0]² + y[1]²) — 2D norm
    ///
    /// Same input → identical bytes → identical signature
    /// (chapter 392 replay-determinism preserved)。 Hosts
    /// can use this as a cross-language input fingerprint
    /// for clustering / dedup / "is this the same kind
    /// of input as that one" questions WITHOUT the
    /// CoreML classifier。
    ///
    /// Nil for backward-compat with summaries constructed
    /// before this field existed,or for brains without
    /// a Metal loader wired,or when Metal dispatch
    /// failed (non-fatal — cascade always returns a
    /// summary)。
    public let metalDerivedSignal: Float?

    public init(
        input: String,
        taskType: BASContextTaskType,
        confidence: Double,
        ambiguityScore: Double,
        safetyVerdict: BASCognitiveSafetyVerdict,
        manipulationHints: [String],
        latencyNanos: UInt64,
        emotionalLoad: Double = 0.0,
        timePressure: Double = 0.0,
        consequenceLevel: Double = 0.0,
        relationPattern: String = "neutral",
        repetitionCount: Int = 0,
        crossSessionEcho: Bool = false,
        metalDerivedSignal: Float? = nil
    ) {
        self.input = input
        self.taskType = taskType
        self.confidence = confidence
        self.ambiguityScore = ambiguityScore
        self.safetyVerdict = safetyVerdict
        self.manipulationHints = manipulationHints
        self.latencyNanos = latencyNanos
        self.emotionalLoad = emotionalLoad
        self.timePressure = timePressure
        self.consequenceLevel = consequenceLevel
        self.relationPattern = relationPattern
        self.repetitionCount = repetitionCount
        self.crossSessionEcho = crossSessionEcho
        self.metalDerivedSignal = metalDerivedSignal
    }

    /// 主线 加强 实用性 — rebuild this summary with native-
    /// pilot-derived fields populated。 Used by the cache-
    /// hit path to layer fresh native-pilot signals onto
    /// the cached ML-classification result (the ML parts
    /// don't change across cache hits,but the repetition
    /// counts MUST be computed per-call)。
    ///
    /// 主线 继续 开发 — also takes the Metal-derived signal
    /// (or nil) so cache-hit summaries can carry a fresh
    /// Metal computation when re-dispatched。
    public func withNativePilotSignals(
        repetitionCount: Int,
        crossSessionEcho: Bool,
        metalDerivedSignal: Float? = nil
    ) -> BASCognitiveBrainSummary {
        return BASCognitiveBrainSummary(
            input: input,
            taskType: taskType,
            confidence: confidence,
            ambiguityScore: ambiguityScore,
            safetyVerdict: safetyVerdict,
            manipulationHints: manipulationHints,
            latencyNanos: latencyNanos,
            emotionalLoad: emotionalLoad,
            timePressure: timePressure,
            consequenceLevel: consequenceLevel,
            relationPattern: relationPattern,
            repetitionCount: repetitionCount,
            crossSessionEcho: crossSessionEcho,
            metalDerivedSignal: metalDerivedSignal)
    }
}
