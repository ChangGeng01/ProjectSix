// MARK: - BASAgentPersonaSDK
// chapter 九百六十九 / M3550 — Phase 4 close:Persona SDK surface
//
// User design Section 11 + plan PHASE 4 ch4 (close):the
// public-facing SDK surface for Persona Studio。 Wraps the
// ch 966 + ch 967 + ch 968 + ch 969 detector into a single
// caller-friendly API。
//
// ## Why a SDK module + not direct calls
//
// Per ch 944 H5 + plan:consumers (Qinao runtime,3rd-party
// hosts) need ONE entry point that:
//
//   1. Validates the input persona against forbidden patterns
//      BEFORE composition
//   2. Composes via ch 966 resolver
//   3. Applies ch 967 Risk clamp
//   4. Applies ch 968 Sovereign clamp
//   5. RE-validates the resolved persona against forbidden
//      patterns AFTER composition (catches sandwiched harm)
//   6. Returns the persona + outcomes + findings as one record
//      for the audit ledger
//
// Direct calls to each module work but require the consumer to
// orchestrate the chain + duplicate the validate step。 The SDK
// surface centralizes this。
//
// ## Compare modes
//
// Per plan + Section 14:transcripts can show one agent's
// answer,or compare multiple personas side-by-side。 The mode
// enum lives here so SDK consumers can switch behavior。
//
// ## Pure-fn discipline
//
// Same as ch 957-968 — pure function。 No actor,no I/O,no
// persistence。 Persistence (`personaVersionTreeStore`) lives
// in a future ch 970+ store。

import Foundation

// MARK: - Compare mode (transcript display)

/// Per plan Section 14:transcript modes for showing persona-
/// shaped output。 Drives the surface render decision in ch 969
/// hosts。
public enum BASAgentPersonaTranscriptMode: String,
    Sendable, Equatable, Hashable, Codable, CaseIterable
{
    /// Show ONE agent's answer (typical / default)。
    case singleAgent
    /// Show all currently-active agents side-by-side。
    case compareAll
    /// Show a caller-selected subset (e.g. Planner + Critic
    /// only)。 The selection is in `BASHostSessionRequest
    /// .activeAgents`。
    case compareSelected
}

// MARK: - Resolve request

/// Caller-supplied bundle for `BASAgentPersonaSDK.resolve(...)`
/// — everything needed to compose + clamp + validate a persona
/// in one call。
public struct BASAgentPersonaResolveRequest:
    Sendable, Equatable
{
    public let agentSpec: BASAgentSpec
    public let userOverlay: BASAgentPersonaSpec?
    public let hostOverlay: BASAgentPersonaSpec?
    public let risk: BASAgentPersonaRiskContext
    public let sovereign: BASAgentPersonaSovereignContext
    public let personaID: String
    public let hostConstraintsRef: String
    public let riskConstraintsRef: String
    public let sovereignConstraintsRef: String
    public let versionRef: String
    public let reportThreshold: Double

    public init(
        agentSpec: BASAgentSpec,
        userOverlay: BASAgentPersonaSpec? = nil,
        hostOverlay: BASAgentPersonaSpec? = nil,
        risk: BASAgentPersonaRiskContext = .identity,
        sovereign: BASAgentPersonaSovereignContext =
            .identity,
        personaID: String,
        hostConstraintsRef: String = "",
        riskConstraintsRef: String = "",
        sovereignConstraintsRef: String = "",
        versionRef: String = "",
        reportThreshold: Double =
            BASAgentPersonaForbiddenDetector
                .defaultReportThreshold
    ) {
        self.agentSpec = agentSpec
        self.userOverlay = userOverlay
        self.hostOverlay = hostOverlay
        self.risk = risk
        self.sovereign = sovereign
        self.personaID = personaID
        self.hostConstraintsRef = hostConstraintsRef
        self.riskConstraintsRef = riskConstraintsRef
        self.sovereignConstraintsRef =
            sovereignConstraintsRef
        self.versionRef = versionRef
        self.reportThreshold = reportThreshold
    }
}

// MARK: - Resolve result

public struct BASAgentPersonaResolveResult:
    Sendable, Equatable
{
    /// Composed + clamped persona ready for the dispatcher to
    /// consume。 Nil when `rejected = true`。
    public let persona: BASAgentPersonaSpec?
    /// True when forbidden patterns rejected the persona BEFORE
    /// composition (input persona was forbidden) or AFTER
    /// composition (a sandwich-attack landed in forbidden zone)。
    public let rejected: Bool
    /// Forbidden findings — sorted by pattern enum。 Empty when
    /// no forbidden pattern detected。
    public let findings: [BASAgentPersonaForbiddenFinding]
    /// Outcome of the ch 967 Risk clamp step。
    public let riskClampOutcome:
        BASAgentPersonaRiskClampOutcome
    /// Outcome of the ch 968 Sovereign clamp step。
    public let sovereignClampOutcome:
        BASAgentPersonaSovereignClampOutcome
    /// True when an input overlay (user OR host) was forbidden
    /// — caller can distinguish "user supplied harmful overlay"
    /// from "harmless inputs composed into harmful output"。
    public let inputRejected: Bool

    public init(
        persona: BASAgentPersonaSpec?,
        rejected: Bool,
        findings:
            [BASAgentPersonaForbiddenFinding] = [],
        riskClampOutcome:
            BASAgentPersonaRiskClampOutcome = .none,
        sovereignClampOutcome:
            BASAgentPersonaSovereignClampOutcome = .none,
        inputRejected: Bool = false
    ) {
        self.persona = persona
        self.rejected = rejected
        self.findings = findings
        self.riskClampOutcome = riskClampOutcome
        self.sovereignClampOutcome =
            sovereignClampOutcome
        self.inputRejected = inputRejected
    }
}

// MARK: - SDK

public enum BASAgentPersonaSDK {

    /// Full Persona Studio pipeline:validate inputs → compose →
    /// Risk clamp → Sovereign clamp → validate output → return
    /// audited result。 Pure function。
    ///
    /// Pipeline ordering rationale:
    ///   1. INPUT validation FIRST:reject caller-supplied
    ///      forbidden overlays before any computation,so an
    ///      obviously-harmful user request short-circuits
    ///   2. Compose (ch 966):layer template + user + host
    ///   3. Risk clamp (ch 967):monotonic raise of defensive
    ///      biases
    ///   4. Sovereign clamp (ch 968):LOW-tier force-default +
    ///      lockdown + heightened-protection caps
    ///   5. OUTPUT validation:catch sandwich-attacks where
    ///      individually-OK overlays compose into forbidden
    ///      patterns
    ///   6. Return result with persona + findings + outcomes
    public static func resolve(
        _ request: BASAgentPersonaResolveRequest
    ) -> BASAgentPersonaResolveResult {
        // Step 1:INPUT validation — caller-supplied overlays
        let inputFindings = inputOverlayFindings(
            request: request)
        if !inputFindings.isEmpty {
            return BASAgentPersonaResolveResult(
                persona: nil,
                rejected: true,
                findings: inputFindings,
                inputRejected: true)
        }

        // Step 2:compose (ch 966)
        let composed = BASAgentPersonaResolver.resolve(
            agentSpec: request.agentSpec,
            userOverlay: request.userOverlay,
            hostOverlay: request.hostOverlay,
            hostConstraintsRef:
                request.hostConstraintsRef,
            riskConstraintsRef:
                request.riskConstraintsRef,
            sovereignConstraintsRef:
                request.sovereignConstraintsRef,
            personaID: request.personaID,
            versionRef: request.versionRef)

        // Step 3:Risk clamp (ch 967)
        let (risked, riskOutcome) =
            BASAgentPersonaRiskClamp.apply(
                to: composed, risk: request.risk)

        // Step 4:Sovereign clamp (ch 968)
        let (final, sovOutcome) =
            BASAgentPersonaSovereignClamp.apply(
                to: risked,
                sovereign: request.sovereign,
                role: request.agentSpec.role)

        // Step 5:OUTPUT validation — sandwich-attack catch。
        // chapter 九百六十九.5 USER-PASS-6 CG1 fix:LOW-tier
        // sovereign-blessed templates are intentionally cold +
        // skeptical (warmth ≤ 0.20,skepticism ≥ 0.85,comparison
        // ≤ 0.05) — these are BY DESIGN forbidden-pattern matches
        // (gaslight + controlling),and rejecting them would be
        // a sovereignty crisis (the system refusing its own
        // sovereign agents)。 Per Root Law 4 (单主权) sovereign-
        // sealed agents are exempt from output validation。
        // Input validation (Step 1) already rejects user/host
        // overlays that match forbidden patterns,so the only
        // way a LOW-tier persona reaches this step is via the
        // sovereign-blessed force-default path of ch 968 — which
        // is BY DEFINITION sovereign-allowed。
        if request.agentSpec.visibility == .low {
            return BASAgentPersonaResolveResult(
                persona: final,
                rejected: false,
                findings: [],
                riskClampOutcome: riskOutcome,
                sovereignClampOutcome: sovOutcome,
                inputRejected: false)
        }
        let outputFindings =
            BASAgentPersonaForbiddenDetector.scan(
                final,
                reportThreshold: request.reportThreshold)
        if !outputFindings.isEmpty {
            // Output is forbidden — reject。 Caller's audit
            // ledger sees BOTH the inputs that composed into
            // forbidden AND the resulting persona that triggered
            // detection。 `persona` is nil in the result because
            // the dispatcher MUST NOT use a forbidden persona。
            return BASAgentPersonaResolveResult(
                persona: nil,
                rejected: true,
                findings: outputFindings,
                riskClampOutcome: riskOutcome,
                sovereignClampOutcome: sovOutcome,
                inputRejected: false)
        }

        // Step 6:clean result
        return BASAgentPersonaResolveResult(
            persona: final,
            rejected: false,
            findings: [],
            riskClampOutcome: riskOutcome,
            sovereignClampOutcome: sovOutcome,
            inputRejected: false)
    }

    /// Scan caller-supplied overlays for forbidden patterns。
    /// Used internally by `resolve(...)` but also exposed for
    /// callers who want to pre-flight a persona before submitting。
    ///
    /// chapter 九百六十九.5 USER-PASS-6 H2 fix:de-dup preserves
    /// EVIDENCE UNION across overlays (previously kept only the
    /// higher-score finding's evidence,silently discarding the
    /// other source's evidence — audit ledger lost forbidden
    /// input visibility when both overlays triggered the same
    /// pattern)。 Now when both user AND host trigger the same
    /// pattern,the merged finding carries:
    ///   - highest matchScore (per original spec)
    ///   - UNION of evidence prefixed with `source=user:` or
    ///     `source=host:` so trace replay sees both
    public static func validateOverlays(
        userOverlay: BASAgentPersonaSpec?,
        hostOverlay: BASAgentPersonaSpec?,
        reportThreshold: Double =
            BASAgentPersonaForbiddenDetector
                .defaultReportThreshold
    ) -> [BASAgentPersonaForbiddenFinding] {
        let userFindings: [BASAgentPersonaForbiddenFinding]
        if let u = userOverlay {
            userFindings =
                BASAgentPersonaForbiddenDetector.scan(
                    u, reportThreshold: reportThreshold)
        } else {
            userFindings = []
        }
        let hostFindings: [BASAgentPersonaForbiddenFinding]
        if let h = hostOverlay {
            hostFindings =
                BASAgentPersonaForbiddenDetector.scan(
                    h, reportThreshold: reportThreshold)
        } else {
            hostFindings = []
        }
        // Tag each finding's evidence with its source,then
        // de-dup by pattern keeping highest matchScore + UNION
        // of source-tagged evidence (sorted)。
        var perPatternScore:
            [BASAgentPersonaForbiddenPattern: Double] = [:]
        var perPatternEvidence:
            [BASAgentPersonaForbiddenPattern: [String]] = [:]
        func absorb(
            _ findings:
                [BASAgentPersonaForbiddenFinding],
            source: String
        ) {
            for f in findings {
                let tagged = f.evidence.map {
                    "source=\(source):\($0)"
                }
                perPatternScore[f.pattern] = max(
                    perPatternScore[f.pattern] ?? 0.0,
                    f.matchScore)
                perPatternEvidence[f.pattern, default: []]
                    .append(contentsOf: tagged)
            }
        }
        absorb(userFindings, source: "user")
        absorb(hostFindings, source: "host")
        return perPatternScore.keys.sorted {
            $0.rawValue < $1.rawValue
        }.map { pattern in
            BASAgentPersonaForbiddenFinding(
                pattern: pattern,
                matchScore: perPatternScore[pattern]!,
                evidence: perPatternEvidence[pattern]
                    ?? [])
        }
    }

    // MARK: - Internal

    private static func inputOverlayFindings(
        request: BASAgentPersonaResolveRequest
    ) -> [BASAgentPersonaForbiddenFinding] {
        validateOverlays(
            userOverlay: request.userOverlay,
            hostOverlay: request.hostOverlay,
            reportThreshold: request.reportThreshold)
    }
}
