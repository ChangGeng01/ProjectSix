import Foundation
import BASPolicy
import BASRuntimeCore

/// M287 — Cthulhu-inspiration white paper schema parity (5 of 8 objects).
///
/// ## Why this exists
///
/// The L-spec white papers
/// `docs/QINAO_CTHULHU_INSPIRATION_INTEGRATION_SPEC_V1.md` and
/// `docs/QINAO_ABYSSAL_HUMAN_ANCHOR_PROTOCOL_TARGET_VINF.md`
/// (TARGET_VINF §7) name eight cross-cutting observation objects
/// the substrate is expected to expose for L1-L14 consumers. Five
/// of them are observation / classification / branch types that
/// belong with the rest of the orchestration plane:
///
///  1. `BASAbyssalPressure` — depth-of-unknown / consequence-radius
///     pressure budget vector consumed by L1 / L9 / L11 / L14.
///  2. `BASHumanAnchorSignal` — host agency / dignity / overwhelm
///     risk readout consumed by L5 / L10 / L11 / L12 / L14.
///  3. `BASAnomalyTrace` — anomaly-classification trace produced by
///     L6 (presence eye) and L7 (mirror blade) for L11 / L14.
///  4. `BASNarrativeDistortion` — sub-trace specifically tracking
///     narrative-shape distortions (denial / rewrite / forced
///     closure / role inversion / urgency mask).
///  5. `BASAbyssalBranch` — counterfactual branch annotation that
///     marks an L9 dream-loop branch as "abyssal" (high unknown
///     load + high manipulation + ontological-distortion risk).
///
/// The remaining three white-paper objects ship in their natural
/// homes:
///
///  - `BASUnknownReserve` lives in `BASWorldPrior` (L4 axiom layer).
///  - `BASSealEnvelope` and `BASForbiddenKnowledgeCandidate` live in
///    `BASMemory` (L8 hippocampal well + L13 evolution furnace).
///
/// ## Scope
///
/// This file is **schema-only + pure-function helpers**. It defines
/// the five Swift value types, four cross-cutting protocol-helper
/// structs, and the supporting enums. It does NOT:
///
///  - mutate any existing substrate type;
///  - run a watcher agent (white-paper red line 7: watcher hints,
///    not verdicts);
///  - drive a runtime path (e.g. modifying `BASActionPermit`
///    issuance based on pressure — that's the M288 follow-up).
///
/// Cross-layer integration (L11 permit consumption, L8 query
/// gating, L13 candidate routing) is explicitly deferred to
/// later milestones. The brief is to give the substrate a stable
/// vocabulary so future runtime hooks can compose against typed
/// readouts instead of strings.
///
/// ## DAG discipline
///
/// Imports `Foundation` and `BASRuntimeCore` only — no Qinao
/// reference, no upstream substrate-runtime dependency. The five
/// schemas are pure value types; the four helpers are pure
/// functions over them.
///
/// ## Codable layout
///
/// All five schemas use Swift-native `Codable` derivation with
/// camelCase field names. White-paper field names use snake_case
/// (`unknown_load`); JSON serialization preserves the camelCase
/// Swift name. Stable serialization is guaranteed via:
///
///  - explicit `schemaVersion` field on every type;
///  - canonical raw values on every enum (`recommendedSurfaceTone`,
///    `recommendedModes`, `assertionCeiling` etc.);
///  - parity-lock unit tests that pin every field, every raw value,
///    and the round-trip JSON shape (see `BASAbyssalProtocolTests`).

// MARK: - BASAbyssalPressureMode

/// One of six recommended action modes the L11 wind gate may
/// surface in response to elevated abyssal pressure. Stable raw
/// values; cross-layer consumers key on the string without
/// importing this module.
///
/// Mode semantics (white paper §5.1 "深渊压强预算"):
///
///  - `compare` — surface a compare panel with multiple drafts
///    instead of auto-committing.
///  - `delay` — defer the decision to a later turn.
///  - `guardianBranch` — escort the candidate via a guardian-branch
///    flow (alternative path with extra checks).
///  - `sovereignEscalate` — flag the case for L14 sovereign review.
///  - `localDraft` — render a host-local draft (no external commit).
///  - `humanAnchorCheck` — invoke the human-anchor protocol check
///    before proceeding.
public enum BASAbyssalPressureMode:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    case compare = "compare"
    case delay = "delay"
    case guardianBranch = "guardian-branch"
    case sovereignEscalate = "sovereign-escalate"
    case localDraft = "local-draft"
    case humanAnchorCheck = "human-anchor-check"
}

// MARK: - BASAbyssalPressure

/// White paper §7 `AbyssalPressure` — pressure-budget vector that
/// summarises the depth-of-unknown / consequence-radius / evidence-
/// debt / ontology-distortion / manipulation-index / narrative-
/// pollution dimensions of a single turn.
///
/// L1 reads this to scale `BASBudgetFrame` ceilings. L9 reads it
/// to bound dream-loop iteration counts. L11 reads it to widen
/// risk-mode selection. L14 reads it as one of the inputs to the
/// sovereign escalation hint.
///
/// Pressure values are unitless `[0, 1]` floats — `0` = no
/// detected pressure, `1` = max pressure detected by the producer.
/// Producers (L6 / L7 / L4) are responsible for clamping; consumers
/// MUST treat values outside `[0, 1]` as a producer bug rather
/// than silently rescale.
public struct BASAbyssalPressure:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier for this pressure record (e.g.
    /// `"abyssal-pressure-<turnID>"`).
    public var pressureID: String
    /// Volume of unresolved unknowns relevant to this turn.
    public var unknownLoad: Double
    /// Estimated radius of consequence (how far the decision
    /// reaches if executed).
    public var consequenceRadius: Double
    /// How much evidence the system has yet to gather before the
    /// decision is well-supported.
    public var evidenceDebt: Double
    /// Degree to which the candidate would distort the host's
    /// ontology / world-model if accepted.
    public var ontologyDistortion: Double
    /// Estimated manipulation pressure on the host (e.g. coercive
    /// urgency, false-consensus framing).
    public var manipulationIndex: Double
    /// Estimated pollution of the surrounding narrative frame
    /// (denial, rewrite, forced closure...).
    public var narrativePollution: Double
    /// L11 modes the wind gate may want to surface. Order is
    /// preserved (most-preferred first).
    public var recommendedModes: [BASAbyssalPressureMode]
    /// Optional hint for L14 sovereign-escalation routing. Free-
    /// text reason code; nil when escalation is not recommended.
    public var sovereignEscalationHint: String?

    public init(
        schemaVersion: String = BASAbyssalPressure.currentSchemaVersion,
        pressureID: String,
        unknownLoad: Double,
        consequenceRadius: Double,
        evidenceDebt: Double,
        ontologyDistortion: Double,
        manipulationIndex: Double,
        narrativePollution: Double,
        recommendedModes: [BASAbyssalPressureMode],
        sovereignEscalationHint: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.pressureID = pressureID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.unknownLoad = min(1, max(0, unknownLoad))
        self.consequenceRadius = min(1, max(0, consequenceRadius))
        self.evidenceDebt = min(1, max(0, evidenceDebt))
        self.ontologyDistortion = min(1, max(0, ontologyDistortion))
        self.manipulationIndex = min(1, max(0, manipulationIndex))
        self.narrativePollution = min(1, max(0, narrativePollution))
        self.recommendedModes = recommendedModes
        self.sovereignEscalationHint = sovereignEscalationHint
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    /// Convenience: a scalar magnitude estimate combining the six
    /// continuous dimensions. Producers / consumers can use this
    /// for ordering / threshold checks without recomputing the
    /// formula. Pure mean of the six fields, not a weighted score
    /// — weighting belongs to the policy layer.
    public var aggregateMagnitude: Double {
        let total = unknownLoad
            + consequenceRadius
            + evidenceDebt
            + ontologyDistortion
            + manipulationIndex
            + narrativePollution
        return total / 6.0
    }
}

// MARK: - BASHumanAnchorTone

/// Recommended surface tone (L12 柔手 input). Stable raw values.
/// White paper §3.2 / §5.3.
public enum BASHumanAnchorTone:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    /// Plain tone — no rituals, no cosmic framing. Use when the
    /// host is operating from full agency.
    case plain = "plain"
    /// Steady tone — explicitly grounding. Use when overwhelm risk
    /// rises but agency is still intact.
    case steady = "steady"
    /// Warm tone — explicit warmth + de-escalation. Use when
    /// dignity risk rises.
    case warm = "warm"
    /// Reserved tone — minimal, no attempt to interpret. Use when
    /// alienation risk rises and the host needs distance.
    case reserved = "reserved"
}

// MARK: - BASHumanAnchorSignal

/// White paper §7 `HumanAnchorSignal` — readout of the four
/// host-side risks (agency / alienation / dignity / overwhelm)
/// plus the recommended surface tone and the agency reservation
/// the next surface must respect.
///
/// L5 produces this from `BASHostProfile` + situation context.
/// L10 reads it as one of the three-self court inputs. L11 reads
/// it to cap delay / refuse modes. L12 reads it to choose tone /
/// disclosure. L14 reads it as one of the sovereign-decision
/// inputs.
///
/// Risk values are unitless `[0, 1]` floats — `0` = no detected
/// risk, `1` = max detected risk.
public struct BASHumanAnchorSignal:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier for this signal (e.g.
    /// `"human-anchor-<turnID>"`).
    public var anchorID: String
    /// Stable reference to the `BASHostProfile` snapshot the signal
    /// was derived from. Producers store the profile's audit-ref
    /// or version-string; consumers use it for traceability.
    public var hostSummaryRef: String
    /// Risk that the surface erodes the host's decision agency
    /// (e.g. by auto-committing or by hiding choices).
    public var agencyRisk: Double
    /// Risk that the surface alienates the host (cold cosmic-
    /// scale framing without anchor).
    public var alienationRisk: Double
    /// Risk that the surface harms host dignity (condescension,
    /// shaming, urgency-coercion).
    public var dignityRisk: Double
    /// Risk that the surface overwhelms the host (too much
    /// information, too many options, too much risk language).
    public var overwhelmRisk: Double
    /// L12 tone the next surface SHOULD adopt.
    public var recommendedSurfaceTone: BASHumanAnchorTone
    /// Stable reason code the surface MUST honor when reserving
    /// agency for the host (e.g. `"defer-to-host"`,
    /// `"present-options"`). Free-text but agreed-upon between
    /// L11 / L12.
    public var requiredAgencyReservation: String

    public init(
        schemaVersion: String = BASHumanAnchorSignal.currentSchemaVersion,
        anchorID: String,
        hostSummaryRef: String,
        agencyRisk: Double,
        alienationRisk: Double,
        dignityRisk: Double,
        overwhelmRisk: Double,
        recommendedSurfaceTone: BASHumanAnchorTone,
        requiredAgencyReservation: String
    ) {
        self.schemaVersion = schemaVersion
        self.anchorID = anchorID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.hostSummaryRef = hostSummaryRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.agencyRisk = min(1, max(0, agencyRisk))
        self.alienationRisk = min(1, max(0, alienationRisk))
        self.dignityRisk = min(1, max(0, dignityRisk))
        self.overwhelmRisk = min(1, max(0, overwhelmRisk))
        self.recommendedSurfaceTone = recommendedSurfaceTone
        self.requiredAgencyReservation = requiredAgencyReservation
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - BASAnomalyType

/// One of seven canonical anomaly classifications the watcher
/// vocabulary uses. Stable raw values; the seven cover the
/// white paper §5.4 "Anomaly Watch Protocol" categories.
public enum BASAnomalyType:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    case narrativeDistortion = "narrative-distortion"
    case realityDenial = "reality-denial"
    case relationDislocation = "relation-dislocation"
    case powerDislocation = "power-dislocation"
    case falseUrgency = "false-urgency"
    case falseGoodwill = "false-goodwill"
    case anomalousCalm = "anomalous-calm"
    case forcedClosure = "forced-closure"
}

// MARK: - BASAnomalyTrace

/// White paper §7 `AnomalyTrace` — audit-style record of one or
/// more anomalies detected during a turn, plus the pressure
/// vector and relation-shift the watcher inferred. Watchers
/// MUST emit `AnomalyTrace` as a hint only — the verdict
/// machinery (L11 / L14) decides what to do with it (red line 7).
public struct BASAnomalyTrace:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var traceID: String
    /// One or more anomaly types detected. Order is preserved
    /// (severity-descending by convention).
    public var anomalyTypes: [BASAnomalyType]
    /// Pressure-vector summary the watcher attached. Optional
    /// because some watchers only classify, not measure.
    public var pressureVector: BASAbyssalPressure?
    /// Free-text describing the relation-shift detected (e.g.
    /// `"observer→subject inversion"`). Empty string when no
    /// relation shift detected.
    public var relationShift: String
    /// Stable references to the source observations that fed
    /// this trace.
    public var sourceRefs: [String]
    /// Watcher confidence in the classification, `[0, 1]`.
    public var confidence: Double

    public init(
        schemaVersion: String = BASAnomalyTrace.currentSchemaVersion,
        traceID: String,
        anomalyTypes: [BASAnomalyType],
        pressureVector: BASAbyssalPressure? = nil,
        relationShift: String,
        sourceRefs: [String],
        confidence: Double
    ) {
        self.schemaVersion = schemaVersion
        self.traceID = traceID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.anomalyTypes = anomalyTypes
        self.pressureVector = pressureVector
        self.relationShift = relationShift
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceRefs = sourceRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.confidence = min(1, max(0, confidence))
    }
}

// MARK: - BASNarrativeDistortion

/// White paper §7 `NarrativeDistortion` — sub-trace tracking five
/// canonical narrative-shape distortions plus a confidence score.
///
/// Each distortion field is a `[0, 1]` magnitude — `0` = not
/// detected, `1` = strongly detected. A turn may have multiple
/// non-zero fields; the consumer (L7 mirror blade, L10 super-ego
/// judgment, L14 sovereign) decides how to weight them.
public struct BASNarrativeDistortion:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var distortionID: String
    /// Strength of reality-denial framing (e.g. "this isn't
    /// happening"). `[0, 1]`.
    public var realityDenial: Double
    /// Strength of history-rewrite framing (e.g. "we never
    /// agreed on that"). `[0, 1]`.
    public var historyRewrite: Double
    /// Strength of forced-closure framing (e.g. "decide right
    /// now"). `[0, 1]`.
    public var forcedClosure: Double
    /// Strength of role-inversion framing (e.g. blamer flips to
    /// victim). `[0, 1]`.
    public var roleInversion: Double
    /// Strength of urgency-mask framing (genuine deliberation
    /// disguised as decisive action). `[0, 1]`.
    public var urgencyMask: Double
    /// Watcher confidence in the readout, `[0, 1]`.
    public var confidence: Double

    public init(
        schemaVersion: String = BASNarrativeDistortion.currentSchemaVersion,
        distortionID: String,
        realityDenial: Double,
        historyRewrite: Double,
        forcedClosure: Double,
        roleInversion: Double,
        urgencyMask: Double,
        confidence: Double
    ) {
        self.schemaVersion = schemaVersion
        self.distortionID = distortionID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.realityDenial = min(1, max(0, realityDenial))
        self.historyRewrite = min(1, max(0, historyRewrite))
        self.forcedClosure = min(1, max(0, forcedClosure))
        self.roleInversion = min(1, max(0, roleInversion))
        self.urgencyMask = min(1, max(0, urgencyMask))
        self.confidence = min(1, max(0, confidence))
    }
}

// MARK: - BASAbyssalBranch

/// White paper §7 `AbyssalBranch` — annotation that marks an L9
/// dream-loop branch as "abyssal" (high unknown load + high
/// manipulation + ontological-distortion risk).
///
/// L9 attaches one of these to a counterfactual branch when it
/// fails the abyssal-pressure threshold; L14 reads them to decide
/// whether to escalate / sovereign-veto / quarantine. The
/// substrate side stores the annotation; the act of "branching"
/// (the actual counterfactual generation) lives on
/// `BASCounterfactualBranch` in the L9 dream-loop schema.
public struct BASAbyssalBranch:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var branchID: String
    /// Reference to the source candidate this branch annotates.
    public var sourceCandidateRef: String
    /// Stable reason codes describing why the branch was flagged
    /// (e.g. `"unknown-load>0.8"`, `"ontology-distortion-detected"`).
    public var triggerReasons: [String]
    /// Carried unknown-load magnitude `[0, 1]`.
    public var unknownLoad: Double
    /// Carried manipulation-load magnitude `[0, 1]`.
    public var manipulationLoad: Double
    /// Carried ontology-distortion magnitude `[0, 1]`.
    public var ontologyDistortion: Double
    /// References to protective alternative paths the L9 dream
    /// loop generated. Empty when no alternative was found.
    public var protectivePathRefs: [String]
    /// Stable reason codes the branch MUST satisfy before it can
    /// be retired (e.g. `"sovereign-review-passed"`,
    /// `"host-confirms-context"`).
    public var requiredClosureConditions: [String]

    public init(
        schemaVersion: String = BASAbyssalBranch.currentSchemaVersion,
        branchID: String,
        sourceCandidateRef: String,
        triggerReasons: [String],
        unknownLoad: Double,
        manipulationLoad: Double,
        ontologyDistortion: Double,
        protectivePathRefs: [String],
        requiredClosureConditions: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.branchID = branchID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceCandidateRef = sourceCandidateRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.triggerReasons = triggerReasons
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.unknownLoad = min(1, max(0, unknownLoad))
        self.manipulationLoad = min(1, max(0, manipulationLoad))
        self.ontologyDistortion = min(1, max(0, ontologyDistortion))
        self.protectivePathRefs = protectivePathRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.requiredClosureConditions = requiredClosureConditions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}

// MARK: - BASAbyssalPressureBudget (cross-cutting protocol helper)

/// White paper §5.1 "Abyssal Pressure Budget" — pure-function
/// helper that converts a `BASAbyssalPressure` reading into the
/// recommended L11 mode list.
///
/// The mapping is deliberately simple — high load on any of the
/// six continuous dimensions adds a corresponding mode to the
/// returned list. Producers may also call `recommended(for:)`
/// directly to backfill the `recommendedModes` field on
/// `BASAbyssalPressure` when the watcher only provides the
/// continuous dimensions.
///
/// Thresholds are tuned conservatively (`>= 0.6` triggers a
/// mode; `>= 0.8` adds the sovereign-escalation hint). Tuning
/// is the policy layer's job — this helper is a default that
/// callers can override with their own selector.
public enum BASAbyssalPressureBudget {
    /// Default trigger threshold for any single dimension.
    public static let defaultTriggerThreshold: Double = 0.6
    /// Default trigger threshold for the sovereign-escalation hint.
    public static let defaultSovereignEscalationThreshold: Double = 0.8

    /// Returns the recommended L11 mode list for a pressure reading.
    ///
    /// Ordering reflects the order in which the white paper §5.1
    /// surface mentions the modes (compare → delay → guardian →
    /// sovereign → local-draft → human-anchor). Multiple modes can
    /// be triggered by a single reading; duplicates are not
    /// inserted.
    public static func recommendedModes(
        for pressure: BASAbyssalPressure,
        triggerThreshold: Double = defaultTriggerThreshold
    ) -> [BASAbyssalPressureMode] {
        let t = min(1, max(0, triggerThreshold))
        var modes: [BASAbyssalPressureMode] = []
        // unknown-load → compare (more options visible)
        if pressure.unknownLoad >= t { modes.append(.compare) }
        // consequence-radius → delay (slow the commit)
        if pressure.consequenceRadius >= t { modes.append(.delay) }
        // ontology-distortion → guardian-branch
        if pressure.ontologyDistortion >= t {
            modes.append(.guardianBranch)
        }
        // manipulation-index → sovereign-escalate
        if pressure.manipulationIndex >= t {
            modes.append(.sovereignEscalate)
        }
        // evidence-debt → local-draft (host-only, no commit)
        if pressure.evidenceDebt >= t { modes.append(.localDraft) }
        // narrative-pollution → human-anchor-check
        if pressure.narrativePollution >= t {
            modes.append(.humanAnchorCheck)
        }
        return modes
    }

    /// Returns a sovereign-escalation reason code when any
    /// dimension crosses the elevated threshold; nil otherwise.
    public static func sovereignEscalationHint(
        for pressure: BASAbyssalPressure,
        elevatedThreshold: Double = defaultSovereignEscalationThreshold
    ) -> String? {
        let t = min(1, max(0, elevatedThreshold))
        var reasons: [String] = []
        if pressure.unknownLoad >= t { reasons.append("unknown-load") }
        if pressure.consequenceRadius >= t {
            reasons.append("consequence-radius")
        }
        if pressure.evidenceDebt >= t {
            reasons.append("evidence-debt")
        }
        if pressure.ontologyDistortion >= t {
            reasons.append("ontology-distortion")
        }
        if pressure.manipulationIndex >= t {
            reasons.append("manipulation-index")
        }
        if pressure.narrativePollution >= t {
            reasons.append("narrative-pollution")
        }
        guard !reasons.isEmpty else { return nil }
        return "elevated:" + reasons.joined(separator: ",")
    }

    // MARK: - M303 — runtime projection

    /// M303 — pure projection from per-turn substrate state to a
    /// `BASAbyssalPressure` reading. Producers (the L14 audit
    /// path in M303 — see `buildSovereignAuditEntry`) feed in
    /// already-computed risk/uncertainty/evidence signals; the
    /// six output dimensions are clamped to [0, 1] by the
    /// `BASAbyssalPressure` initializer.
    ///
    /// Mapping rationale (white paper §5.1):
    ///   - `unknownLoad`        ← `1 − uncertaintyLedger.confidenceFloor`
    ///                            (low confidence = high unknown load)
    ///   - `consequenceRadius`  ← risk-level scalar mapping
    ///   - `evidenceDebt`       ← evidence-debt count clamped at 10
    ///   - `ontologyDistortion` ← left at 0 unless a watcher fills it
    ///   - `manipulationIndex`  ← left at 0 (filled by M305+)
    ///   - `narrativePollution` ← left at 0 (filled by M305+)
    ///
    /// `recommendedModes` are computed via `recommendedModes(for:)`
    /// after the dimensions are populated; `sovereignEscalationHint`
    /// likewise. The result is a fully-populated typed pressure
    /// reading suitable for streaming into L14 audit signalRefs as
    /// additive metadata (M303 wire) — no verdict escalation, no
    /// permit mutation. The L11 / L13 runtime hooks land in M305+.
    public static func derive(
        turnID: String,
        riskLevel: BASBrainRiskLevel,
        uncertaintyLedger: BASUncertaintyLedger?,
        evidenceDebtCount: Int,
        triggerThreshold: Double = defaultTriggerThreshold,
        elevatedThreshold: Double = defaultSovereignEscalationThreshold
    ) -> BASAbyssalPressure {
        // Confidence floor [0..1]; default mid-range when absent.
        let confidence = uncertaintyLedger?.confidenceFloor ?? 0.5
        let unknownLoad = max(0, min(1, 1 - confidence))

        // Risk-level → consequence-radius scalar. Tuned so the
        // budget's default 0.6 trigger fires at .high; .extreme
        // crosses the elevated 0.8 threshold.
        let consequenceRadius: Double
        switch riskLevel {
        case .low:     consequenceRadius = 0.2
        case .medium:  consequenceRadius = 0.45
        case .high:    consequenceRadius = 0.7
        case .extreme: consequenceRadius = 1.0
        }

        // Evidence-debt count saturates at 10 outstanding debts.
        let evidenceDebt = max(
            0, min(1, Double(evidenceDebtCount) / 10.0))

        // Build the un-mode-populated pressure first, then ask the
        // budget helper for recommended modes + escalation hint
        // using the pressure's own dimensions. This keeps mode
        // selection consistent with the other budget helpers.
        let dimensionsOnly = BASAbyssalPressure(
            pressureID: "abyssal-pressure-\(turnID)",
            unknownLoad: unknownLoad,
            consequenceRadius: consequenceRadius,
            evidenceDebt: evidenceDebt,
            ontologyDistortion: 0,
            manipulationIndex: 0,
            narrativePollution: 0,
            recommendedModes: [])
        let modes = recommendedModes(
            for: dimensionsOnly,
            triggerThreshold: triggerThreshold)
        let escalation = sovereignEscalationHint(
            for: dimensionsOnly,
            elevatedThreshold: elevatedThreshold)
        return BASAbyssalPressure(
            pressureID: dimensionsOnly.pressureID,
            unknownLoad: dimensionsOnly.unknownLoad,
            consequenceRadius: dimensionsOnly.consequenceRadius,
            evidenceDebt: dimensionsOnly.evidenceDebt,
            ontologyDistortion: dimensionsOnly.ontologyDistortion,
            manipulationIndex: dimensionsOnly.manipulationIndex,
            narrativePollution: dimensionsOnly.narrativePollution,
            recommendedModes: modes,
            sovereignEscalationHint: escalation)
    }
}

// MARK: - BASHumanAnchorProtocol (cross-cutting protocol helper)

/// White paper §3 / §5.3 "Human Anchor Protocol" — pure-function
/// helper that derives a `BASHumanAnchorSignal` from
/// `(hostSummaryRef, riskInputs)`.
///
/// The substrate side does not own host-profile derivation
/// (that belongs in `BASMemory.HostConstitutionCore`); this
/// helper is a building block that lets producers package
/// already-computed risks into a typed signal with a sensible
/// tone recommendation.
///
/// Tone selection is a simple three-step rule:
///   - if any risk ≥ 0.8 → reserved (host needs distance)
///   - else if dignity or alienation ≥ 0.5 → warm
///   - else if overwhelm ≥ 0.5 → steady
///   - else → plain
public enum BASHumanAnchorProtocol {
    /// Threshold above which the protocol switches to "reserved".
    public static let reservedTone: Double = 0.8
    /// Threshold above which dignity / alienation pull tone toward
    /// "warm".
    public static let warmTone: Double = 0.5
    /// Threshold above which overwhelm pulls tone toward "steady".
    public static let steadyTone: Double = 0.5

    public static func recommendedTone(
        agencyRisk: Double,
        alienationRisk: Double,
        dignityRisk: Double,
        overwhelmRisk: Double
    ) -> BASHumanAnchorTone {
        let maxRisk = max(
            agencyRisk,
            max(alienationRisk, max(dignityRisk, overwhelmRisk))
        )
        if maxRisk >= reservedTone {
            return .reserved
        }
        if dignityRisk >= warmTone || alienationRisk >= warmTone {
            return .warm
        }
        if overwhelmRisk >= steadyTone {
            return .steady
        }
        return .plain
    }

    /// Convenience: build a fully-populated `BASHumanAnchorSignal`
    /// with the protocol-recommended tone applied.
    public static func signal(
        anchorID: String,
        hostSummaryRef: String,
        agencyRisk: Double,
        alienationRisk: Double,
        dignityRisk: Double,
        overwhelmRisk: Double,
        requiredAgencyReservation: String
    ) -> BASHumanAnchorSignal {
        BASHumanAnchorSignal(
            anchorID: anchorID,
            hostSummaryRef: hostSummaryRef,
            agencyRisk: agencyRisk,
            alienationRisk: alienationRisk,
            dignityRisk: dignityRisk,
            overwhelmRisk: overwhelmRisk,
            recommendedSurfaceTone: recommendedTone(
                agencyRisk: agencyRisk,
                alienationRisk: alienationRisk,
                dignityRisk: dignityRisk,
                overwhelmRisk: overwhelmRisk),
            requiredAgencyReservation: requiredAgencyReservation
        )
    }

    // MARK: - M304 — runtime projection

    /// M304 — pure projection from per-turn substrate state to a
    /// `BASHumanAnchorSignal`. The L14 audit path uses this to
    /// emit `humanAnchor.tone` / `humanAnchor.maxRisk` codes
    /// onto `signalRefs` as additive metadata (red line 7:
    /// watcher hint, never a verdict).
    ///
    /// Mapping rationale (white paper §5.3):
    ///   - `agencyRisk`     ← elevated when permit blocks the
    ///                        host from acting
    ///   - `alienationRisk` ← elevated under extreme risk
    ///                        (cosmic-scale framing without
    ///                        anchor)
    ///   - `dignityRisk`    ← elevated when the surface is
    ///                        forced into block / urgency mode
    ///   - `overwhelmRisk`  ← scales with candidate count
    ///                        (≥6 candidates saturates)
    ///
    /// All four risks clamp to [0, 1] inside the
    /// `BASHumanAnchorSignal` initializer. The tone is computed
    /// via `recommendedTone(...)` so audit consumers see the
    /// same tone the L12 surface layer would.
    public static func derive(
        anchorID: String,
        hostSummaryRef: String,
        riskLevel: BASBrainRiskLevel,
        permitMode: BASActionPermitMode,
        candidateCount: Int,
        requiredAgencyReservation: String = "default-agency-reservation"
    ) -> BASHumanAnchorSignal {
        // Block-mode permit blocks the host's chosen action →
        // agency risk elevated; non-blocking modes keep agency
        // intact. Mid-saturation defaults so the tone helper has
        // room to differentiate.
        let agencyRisk: Double = (permitMode == .block) ? 0.75 : 0.25

        // Alienation tracks the "cosmic" tier — extreme risk +
        // permit blocks raise it.
        let alienationRisk: Double = {
            switch (riskLevel, permitMode) {
            case (.extreme, .block):  return 0.85
            case (.extreme, _):       return 0.55
            case (.high, .block):     return 0.55
            case (.high, _):          return 0.35
            default:                  return 0.15
            }
        }()

        // Dignity erodes under coercive routes (block + extreme
        // risk simultaneously). Lower for any non-block permit.
        let dignityRisk: Double = {
            if permitMode == .block && riskLevel >= .high {
                return 0.7
            }
            if permitMode == .block { return 0.45 }
            return 0.15
        }()

        // Overwhelm scales linearly with candidate count, saturates
        // at 6 candidates.
        let overwhelmRisk = max(
            0, min(1, Double(candidateCount) / 6.0))

        return signal(
            anchorID: anchorID,
            hostSummaryRef: hostSummaryRef,
            agencyRisk: agencyRisk,
            alienationRisk: alienationRisk,
            dignityRisk: dignityRisk,
            overwhelmRisk: overwhelmRisk,
            requiredAgencyReservation: requiredAgencyReservation)
    }
}

// MARK: - M316 / M317 / M318 — derive helpers from runtime state

public extension BASNarrativeDistortion {
    /// **M316** — projection from existing turn state into the
    /// 5-axis narrative-distortion shape.
    ///
    /// Pre-M316 the `BASNarrativeDistortion` schema (white paper
    /// §7) was load-bearing in tests + governance only; no
    /// runtime path produced one. M316 closes the gap by
    /// projecting from L11 risk + L12 permit + L9 candidate state
    /// — same pattern as M303 `BASAbyssalPressureBudget.derive`.
    ///
    /// Mappings (deliberately conservative — placeholders use 0
    /// rather than over-claim signal):
    ///
    /// - **`realityDenial`**: stays 0 until L7 mirror blade wires
    ///   real signal. The substrate has no audit on whether the
    ///   host is denying observable reality; this would require
    ///   the host_constitution + L8 memory to disagree, which
    ///   M316 doesn't yet wire.
    /// - **`historyRewrite`**: same — stays 0 until L7 / L8 wires.
    /// - **`forcedClosure`**: scales with permit mode tightness.
    ///   `.block` → 0.7 (decision shut down), `.delay` → 0.4,
    ///   `.compare` → 0.2, `.answer` → 0.0. Mirrors the
    ///   white-paper "decide right now" framing reading.
    /// - **`roleInversion`**: stays 0 — needs L10 tribunal voice
    ///   shift detection (future milestone).
    /// - **`urgencyMask`**: scales with risk-level paired with
    ///   permissive permit. `.extreme` + `.answer` → 0.9
    ///   (genuine deliberation disguised as decisive action),
    ///   `.high` + `.answer` → 0.6, `.medium` + `.answer` → 0.3,
    ///   else 0.
    ///
    /// `confidence` is fixed at 0.5 — projection is structural,
    /// not introspective; downstream watchers can override with
    /// higher confidence after deeper inspection.
    static func derive(
        distortionID: String,
        riskLevel: BASBrainRiskLevel,
        permitMode: BASActionPermitMode
    ) -> BASNarrativeDistortion {
        let forcedClosure: Double
        switch permitMode {
        case .block: forcedClosure = 0.7
        case .delay: forcedClosure = 0.4
        case .compare: forcedClosure = 0.2
        case .answer: forcedClosure = 0.0
        // M316 — newer permit modes (added by L12 surface
        // expansion) all signal less forced-closure than block
        // but more than answer; default to 0.2 (parity with
        // compare) until L7 mirror blade wires more nuance.
        case .mirror, .draftOnly, .localOnly,
             .replace, .escalate:
            forcedClosure = 0.2
        }
        let urgencyMask: Double
        switch (riskLevel, permitMode) {
        case (.extreme, .answer): urgencyMask = 0.9
        case (.high, .answer): urgencyMask = 0.6
        case (.medium, .answer): urgencyMask = 0.3
        default: urgencyMask = 0.0
        }
        return BASNarrativeDistortion(
            distortionID: distortionID,
            realityDenial: 0,
            historyRewrite: 0,
            forcedClosure: forcedClosure,
            roleInversion: 0,
            urgencyMask: urgencyMask,
            confidence: 0.5)
    }

    /// True when at least one distortion field exceeds 0.0 — the
    /// audit-entry consumer uses this to decide whether to emit
    /// `narrative.*` codes for the turn.
    var isNonTrivial: Bool {
        realityDenial > 0
            || historyRewrite > 0
            || forcedClosure > 0
            || roleInversion > 0
            || urgencyMask > 0
    }

    /// Maximum across the 5 distortion axes. The audit signal
    /// surface uses this as a one-line readout.
    var maxAxis: Double {
        max(
            realityDenial,
            max(
                historyRewrite,
                max(
                    forcedClosure,
                    max(roleInversion, urgencyMask))))
    }
}

public extension BASAnomalyTrace {
    /// **M317** — projection from a derived
    /// `BASNarrativeDistortion` plus existing turn refs into a
    /// runtime-built `BASAnomalyTrace`. Reuses
    /// `BASAnomalyWatchProtocol.trace(...)` so the trace shape
    /// stays identical to the watcher-protocol output.
    ///
    /// The audit-entry consumer treats `nil` as "no anomaly to
    /// report" — i.e., when the distortion has no axis above
    /// the emit threshold. Consumer never escalates the verdict
    /// (red line 7); it only emits additive `anomaly.*`
    /// signalRefs codes.
    static func deriveOrNil(
        traceID: String,
        distortion: BASNarrativeDistortion,
        relationShift: String,
        sourceRefs: [String],
        pressureVector: BASAbyssalPressure? = nil,
        emitThreshold: Double =
            BASAnomalyWatchProtocol.defaultEmitThreshold
    ) -> BASAnomalyTrace? {
        let trace = BASAnomalyWatchProtocol.trace(
            traceID: traceID,
            distortion: distortion,
            relationShift: relationShift,
            sourceRefs: sourceRefs,
            pressureVector: pressureVector,
            emitThreshold: emitThreshold)
        return trace.anomalyTypes.isEmpty ? nil : trace
    }
}

public extension BASAbyssalBranch {
    /// **M318** — projection from L9 dream-loop counterfactual
    /// bundles + an `BASAbyssalPressure` reading into 0-or-N
    /// branches.
    ///
    /// A branch is emitted for each counterfactual bundle whose
    /// abyssal-pressure threshold is exceeded — meaning the
    /// branch carries non-trivial unknown-load + manipulation +
    /// ontology distortion. White paper §7 says these are L9's
    /// hint to L14: "this counterfactual ventured into abyssal
    /// territory and needs sovereign review before the host can
    /// commit to it."
    ///
    /// Mappings:
    /// - `branchID` ← `"abyssal-branch-{candidateID}"`
    /// - `sourceCandidateRef` ← `bundle.candidateID`
    /// - `unknownLoad` ← `pressure.unknownLoad`
    /// - `manipulationLoad` ← `pressure.manipulationIndex`
    /// - `ontologyDistortion` ← `pressure.ontologyDistortion`
    /// - `triggerReasons` ← reason codes drawn from each non-zero
    ///   axis above the abyssal threshold
    /// - `protectivePathRefs` ← empty (real protective paths come
    ///   from L9 alternative-counterfactual generation in a
    ///   future milestone; M318 ships the projection shape)
    /// - `requiredClosureConditions` ← `["sovereign-review-passed"]`
    ///   when escalation threshold met, else empty
    static func deriveAll(
        candidateIDs: [String],
        pressure: BASAbyssalPressure,
        abyssalThreshold: Double = 0.5
    ) -> [BASAbyssalBranch] {
        // Below abyssal threshold → no branches; the abyssal
        // signal isn't strong enough to warrant L14 review.
        guard pressure.aggregateMagnitude >= abyssalThreshold
        else {
            return []
        }
        var triggerReasons: [String] = []
        if pressure.unknownLoad >= abyssalThreshold {
            triggerReasons.append(
                "unknown-load>=\(abyssalThreshold)")
        }
        if pressure.manipulationIndex >= abyssalThreshold {
            triggerReasons.append(
                "manipulation-index>=\(abyssalThreshold)")
        }
        if pressure.ontologyDistortion >= abyssalThreshold {
            triggerReasons.append(
                "ontology-distortion>=\(abyssalThreshold)")
        }
        if triggerReasons.isEmpty {
            triggerReasons.append("aggregate-magnitude-elevated")
        }
        let closureConditions: [String] =
            pressure.aggregateMagnitude >= 0.7
                ? ["sovereign-review-passed"]
                : []
        return candidateIDs.map { candidateID in
            BASAbyssalBranch(
                branchID: "abyssal-branch-\(candidateID)",
                sourceCandidateRef: candidateID,
                triggerReasons: triggerReasons,
                unknownLoad: pressure.unknownLoad,
                manipulationLoad: pressure.manipulationIndex,
                ontologyDistortion:
                    pressure.ontologyDistortion,
                protectivePathRefs: [],
                requiredClosureConditions: closureConditions)
        }
    }
}

// MARK: - BASAnomalyWatchProtocol (cross-cutting protocol helper)

/// White paper §5.4 "Anomaly Watch Protocol" — pure-function
/// helper that derives a `BASNarrativeDistortion` summary from
/// the five canonical narrative-shape inputs and packages it
/// into a `BASAnomalyTrace` ready for ledger streaming.
///
/// Watchers MUST treat this as a hint only — the verdict
/// machinery (L11 / L14) decides what to do with the trace
/// (red line 7).
public enum BASAnomalyWatchProtocol {
    /// Default minimum-confidence threshold for emitting a trace.
    /// Watchers below this threshold should suppress the trace
    /// rather than flood the ledger with low-signal hints.
    public static let defaultEmitThreshold: Double = 0.4

    /// Builds an `AnomalyTrace` for a single distortion signal.
    /// `anomalyTypes` is derived by which distortion fields are
    /// non-trivial (≥ `defaultEmitThreshold`).
    public static func trace(
        traceID: String,
        distortion: BASNarrativeDistortion,
        relationShift: String,
        sourceRefs: [String],
        pressureVector: BASAbyssalPressure? = nil,
        emitThreshold: Double = defaultEmitThreshold
    ) -> BASAnomalyTrace {
        let t = min(1, max(0, emitThreshold))
        var types: [BASAnomalyType] = []
        if distortion.realityDenial >= t {
            types.append(.realityDenial)
        }
        if distortion.historyRewrite >= t {
            types.append(.narrativeDistortion)
        }
        if distortion.forcedClosure >= t {
            types.append(.forcedClosure)
        }
        if distortion.roleInversion >= t {
            types.append(.relationDislocation)
        }
        if distortion.urgencyMask >= t {
            types.append(.falseUrgency)
        }
        return BASAnomalyTrace(
            traceID: traceID,
            anomalyTypes: types,
            pressureVector: pressureVector,
            relationShift: relationShift,
            sourceRefs: sourceRefs,
            confidence: distortion.confidence
        )
    }
}
