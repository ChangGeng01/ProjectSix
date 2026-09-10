import Foundation

/// M75 — L12 柔手 surface matrix + executable substitutes.
///
/// `QinaoRiskGate.assess` returns a four-mode verdict
/// (`.allow / .delay / .replace / .block`) with an unstructured
/// `substituteHint: String?`. That's enough to decide whether to
/// issue a permit but not enough for the UI layer to actually
/// render: a string "mirror-and-compare-instead" tells no-one
/// *which* surface to show, *who* decides (host vs user vs gate),
/// or *what* the payload looks like.
///
/// M75 bridges the gap. The risk gate now projects each assessment
/// onto a 4-axis surface matrix:
///
/// - **Surface** — which of QinaoUI's 5 柔手 components to mount
///   (compare-panel / draft-shell / delay-packet / boundary-script
///   / silent-stub). Raw values match `QinaoUI.ComponentID` so a
///   host that logs a surface event can round-trip between layers.
/// - **Agency** — who holds the decision this turn: `autoComply`
///   (gate executes), `userChoose` (user picks from ≥2 options),
///   `userAffirm` (user approves/dismisses one option), or
///   `hostOverride` (host enforces without user input).
/// - **Disclosure** — how much risk context is exposed:
///   `silent` / `minimal` / `reasoned` / `explicit`.
/// - **Substitute** — the executable payload the UI needs to draw
///   (compare candidates / delay window / consent prompt key /
///   render candidate / refuse with audit ref).
///
/// The projection is pure and deterministic — same assessment in
/// always yields the same `SurfaceAction` out. Nothing here mentions
/// `BAS*` vocabulary; reason codes pass through verbatim, surface /
/// agency / disclosure / substitute are Qinao-stable identifiers.
///
/// # Public surface added to `QinaoRiskGate`
///
/// - `SurfaceMode` — 5-case enum mirroring `QinaoUI.ComponentID`.
/// - `SurfaceAgency` — 4-case enum.
/// - `SurfaceDisclosure` — 4-case enum.
/// - `SubstitutePayload` — 5-case enum with associated values.
/// - `SurfaceAction` — struct bundling all four axes + reason
///   codes + audit reference.
/// - `surfaceAction(for:auditReference:candidateIDs:consentPromptKey:)`
///   — static pure mapper.
/// - `requestSurfaceAction(for:signals:...)` and world-aware variant
///   — actor-level convenience that runs the assessor then maps.
public extension QinaoRiskGate {

    /// Which of QinaoUI's 5 柔手 surface components the gate wants
    /// mounted. Raw values match `QinaoUI.ComponentID` so hosts can
    /// log a single string across risk / UI layers without translating.
    enum SurfaceMode: String, Sendable, Equatable, Codable, CaseIterable {
        /// 比较板 — side-by-side candidate comparison.
        case comparePanel = "compare-panel"
        /// 底稿壳 — single draft with approve/edit/dismiss hooks.
        case draftShell = "draft-shell"
        /// 缓手信封 — retry-later notice.
        case delayPacket = "delay-packet"
        /// 边界脚本 — explicit boundary + redirection lines.
        case boundaryScript = "boundary-script"
        /// 沉默回执 — minimal refusal with audit reference.
        case silentStub = "silent-stub"
    }

    /// Who holds the decision this turn. Hosts use this to decide
    /// whether the surface needs user interaction or the gate should
    /// just apply the chosen action.
    enum SurfaceAgency: String, Sendable, Equatable, Codable, CaseIterable {
        /// The gate applies without user input — e.g. baseline allow
        /// with no candidates needing review.
        case autoComply = "auto-comply"
        /// The user picks one of ≥2 alternatives (compare panel).
        case userChoose = "user-choose"
        /// The user affirms or dismisses a single option (draft
        /// shell, boundary script).
        case userAffirm = "user-affirm"
        /// The host enforces without user input — e.g. block, delay.
        case hostOverride = "host-override"
    }

    /// How much risk context is visible on the surface. Stable
    /// identifiers; hosts map to copy libraries.
    enum SurfaceDisclosure: String, Sendable, Equatable, Codable, CaseIterable {
        /// No visible reason (silent stub default).
        case silent
        /// One-line "held for a moment" (delay packet default).
        case minimal
        /// Reason codes surfaced for user judgement (compare panel
        /// default, draft shell when score is marginal).
        case reasoned
        /// Full boundary language + alternatives (boundary script
        /// default).
        case explicit
    }

    /// The executable payload the UI layer needs to render. Carries
    /// exactly the parameters each of the 5 surfaces asks for —
    /// nothing more, nothing less — so the gate→UI hand-off is a
    /// pure value-type and trace-friendly.
    enum SubstitutePayload: Sendable, Equatable, Codable {
        /// Render candidate drafts side-by-side. `candidateIDs`
        /// ordered by host preference. Empty list is valid but the
        /// host should fall through to `.refuse` rather than show
        /// an empty compare panel.
        case mirrorAndCompare(candidateIDs: [String])
        /// Defer to later; UI translates seconds with
        /// `QinaoDelayPacketModel.retryDurationToken()`.
        case deferToLater(retryAfterSeconds: Int)
        /// Prompt the user for informed consent before proceeding.
        /// `promptKey` is a stable copy-library key the host's
        /// i18n layer resolves to localized text.
        case requestConsent(promptKey: String)
        /// Render a single draft candidate. The host wires the
        /// approve/edit/dismiss hooks via `QinaoDraftShellView`.
        case render(candidateID: String)
        /// Refuse silently. `auditReference` is the audit ledger
        /// anchor so the user can reference the refusal.
        case refuse(auditReference: String)

        // Codable conformance via a discriminated union. The
        // `kind` key selects the case; the associated value is
        // decoded from a sibling key specific to that case.
        private enum CodingKeys: String, CodingKey {
            case kind
            case candidateIDs
            case retryAfterSeconds
            case promptKey
            case candidateID
            case auditReference
        }

        private enum Kind: String, Codable {
            case mirrorAndCompare = "mirror-and-compare"
            case deferToLater = "defer-to-later"
            case requestConsent = "request-consent"
            case render
            case refuse
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let kind = try c.decode(Kind.self, forKey: .kind)
            switch kind {
            case .mirrorAndCompare:
                let ids = try c.decode([String].self, forKey: .candidateIDs)
                self = .mirrorAndCompare(candidateIDs: ids)
            case .deferToLater:
                let s = try c.decode(Int.self, forKey: .retryAfterSeconds)
                self = .deferToLater(retryAfterSeconds: s)
            case .requestConsent:
                let k = try c.decode(String.self, forKey: .promptKey)
                self = .requestConsent(promptKey: k)
            case .render:
                let id = try c.decode(String.self, forKey: .candidateID)
                self = .render(candidateID: id)
            case .refuse:
                let ref = try c.decode(String.self, forKey: .auditReference)
                self = .refuse(auditReference: ref)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .mirrorAndCompare(let ids):
                try c.encode(Kind.mirrorAndCompare, forKey: .kind)
                try c.encode(ids, forKey: .candidateIDs)
            case .deferToLater(let s):
                try c.encode(Kind.deferToLater, forKey: .kind)
                try c.encode(s, forKey: .retryAfterSeconds)
            case .requestConsent(let k):
                try c.encode(Kind.requestConsent, forKey: .kind)
                try c.encode(k, forKey: .promptKey)
            case .render(let id):
                try c.encode(Kind.render, forKey: .kind)
                try c.encode(id, forKey: .candidateID)
            case .refuse(let ref):
                try c.encode(Kind.refuse, forKey: .kind)
                try c.encode(ref, forKey: .auditReference)
            }
        }
    }

    /// Full value-typed projection of a `RiskAssessment` onto the
    /// L12 surface matrix. Deterministic and Codable — the
    /// gate→UI hand-off can be logged, diffed, and round-tripped.
    struct SurfaceAction: Sendable, Equatable, Codable {
        public let surface: SurfaceMode
        public let agency: SurfaceAgency
        public let disclosure: SurfaceDisclosure
        public let substitute: SubstitutePayload
        public let reasonCodes: [String]
        public let auditReference: String?

        public init(
            surface: SurfaceMode,
            agency: SurfaceAgency,
            disclosure: SurfaceDisclosure,
            substitute: SubstitutePayload,
            reasonCodes: [String],
            auditReference: String? = nil
        ) {
            self.surface = surface
            self.agency = agency
            self.disclosure = disclosure
            self.substitute = substitute
            self.reasonCodes = reasonCodes
            self.auditReference = auditReference
        }
    }
}

// MARK: - Pure projection

extension QinaoRiskGate {

    /// Project a `RiskAssessment` onto the L12 surface matrix.
    /// Pure, deterministic, Qinao-stable.
    ///
    /// Mapping rules:
    ///
    /// - `.block` → `silentStub` · `hostOverride` · `silent` ·
    ///   `.refuse(auditReference:)`. The audit reference defaults to
    ///   `"unspecified"` when none is supplied so the surface can
    ///   always render something.
    /// - `.delay` → `delayPacket` · `hostOverride` · `reasoned` ·
    ///   `.deferToLater(retryAfterSeconds:)`. The retry window comes
    ///   from `assessment.recommendedDelaySeconds`, defaulting to 60
    ///   when absent (matches the pure evaluator's stage-3 default).
    /// - `.replace` with the stable reason `consent-required` →
    ///   `boundaryScript` · `userAffirm` · `explicit` ·
    ///   `.requestConsent(promptKey:)`. The prompt key comes from
    ///   the caller; `"default-consent-prompt"` is used when none.
    /// - `.replace` (non-consent, e.g. pressure-driven) →
    ///   `comparePanel` · `userChoose` if the host supplied ≥2
    ///   candidates, else `userAffirm` · `reasoned` ·
    ///   `.mirrorAndCompare(candidateIDs:)`.
    /// - `.allow` → `draftShell` · `userAffirm` if the host supplied
    ///   candidate IDs, else `autoComply` · `minimal` ·
    ///   `.render(candidateID:)` — the first candidate if any,
    ///   otherwise `"primary-candidate"` as a stable placeholder.
    ///
    /// Reason codes pass through to the `SurfaceAction`'s
    /// `reasonCodes` verbatim so hosts can key copy libraries on
    /// the exact same strings that the assessor emitted.
    public static func surfaceAction(
        for assessment: RiskAssessment,
        auditReference: String? = nil,
        candidateIDs: [String] = [],
        consentPromptKey: String = "default-consent-prompt"
    ) -> SurfaceAction {
        switch assessment.mode {
        case .block:
            return SurfaceAction(
                surface: .silentStub,
                agency: .hostOverride,
                disclosure: .silent,
                substitute: .refuse(
                    auditReference: auditReference ?? "unspecified"),
                reasonCodes: assessment.reasonCodes,
                auditReference: auditReference)

        case .delay:
            let seconds = Int(
                assessment.recommendedDelaySeconds ?? 60)
            return SurfaceAction(
                surface: .delayPacket,
                agency: .hostOverride,
                disclosure: .reasoned,
                substitute: .deferToLater(retryAfterSeconds: seconds),
                reasonCodes: assessment.reasonCodes,
                auditReference: auditReference)

        case .replace:
            // Consent-required replacements surface as a boundary
            // script with an explicit consent prompt.
            if assessment.reasonCodes.contains("consent-required") {
                return SurfaceAction(
                    surface: .boundaryScript,
                    agency: .userAffirm,
                    disclosure: .explicit,
                    substitute: .requestConsent(
                        promptKey: consentPromptKey),
                    reasonCodes: assessment.reasonCodes,
                    auditReference: auditReference)
            }
            // Generic replace (pressure / mirror-and-compare).
            // userChoose requires ≥2 options; otherwise degrade to
            // userAffirm so the surface is still coherent with a
            // single candidate.
            let agency: SurfaceAgency =
                candidateIDs.count >= 2 ? .userChoose : .userAffirm
            return SurfaceAction(
                surface: .comparePanel,
                agency: agency,
                disclosure: .reasoned,
                substitute: .mirrorAndCompare(
                    candidateIDs: candidateIDs),
                reasonCodes: assessment.reasonCodes,
                auditReference: auditReference)

        case .allow:
            // Baseline allow renders the primary draft. If the host
            // hasn't named any candidate we still emit a stable
            // placeholder so logging and traces don't see empty
            // strings; agency drops to autoComply to signal "no
            // user interaction required for this surface".
            let primary = candidateIDs.first ?? "primary-candidate"
            let agency: SurfaceAgency =
                candidateIDs.isEmpty ? .autoComply : .userAffirm
            return SurfaceAction(
                surface: .draftShell,
                agency: agency,
                disclosure: .minimal,
                substitute: .render(candidateID: primary),
                reasonCodes: assessment.reasonCodes,
                auditReference: auditReference)
        }
    }
}

// MARK: - Actor convenience

public extension QinaoRiskGate {

    /// Run the pure evaluator on `signals` and project onto the
    /// surface matrix. Does **not** issue a permit — callers that
    /// need the permit side should keep calling
    /// `requestActionPermit(for:signals:)`. This call path is for
    /// hosts that want the UI surface decision without binding to
    /// a specific intent digest (e.g. pre-flight UI preview).
    func requestSurfaceAction(
        for signals: RiskSignals,
        auditReference: String? = nil,
        candidateIDs: [String] = [],
        consentPromptKey: String = "default-consent-prompt"
    ) -> SurfaceAction {
        let assessment = Self.assess(signals)
        return Self.surfaceAction(
            for: assessment,
            auditReference: auditReference,
            candidateIDs: candidateIDs,
            consentPromptKey: consentPromptKey)
    }

    /// World-aware variant: runs the world-prior-aware evaluator
    /// then projects. Throws `.unknownWorldTemplate` when the vault
    /// doesn't recognise `worldContext.templateID`, matching the
    /// permit-path semantics so hosts can share error handling.
    func requestSurfaceAction(
        for signals: RiskSignals,
        worldContext: WorldRiskContext,
        worldEndpoint: any QinaoWorldPriorEndpoint,
        auditReference: String? = nil,
        candidateIDs: [String] = [],
        consentPromptKey: String = "default-consent-prompt"
    ) async throws -> SurfaceAction {
        guard
            let worldAssessment = try await worldEndpoint
                .assessRisk(templateID: worldContext.templateID)
        else {
            throw RiskError.unknownWorldTemplate(
                id: worldContext.templateID)
        }
        let assessment = Self.assess(
            signals,
            worldAssessment: worldAssessment,
            worldContext: worldContext)
        return Self.surfaceAction(
            for: assessment,
            auditReference: auditReference,
            candidateIDs: candidateIDs,
            consentPromptKey: consentPromptKey)
    }
}

// MARK: - M85: counterfactual-aware surface enrichment

public extension QinaoRiskGate {

    /// M85 — Qinao-local mirror of L9's
    /// `QinaoLoop.DreamCycleOutcome.CandidateCounterfactualView`.
    ///
    /// The risk gate uses this to decide whether the surface matrix
    /// should be upgraded by L9 dream-cycle evidence. It is
    /// deliberately a **value copy** of the loop's view type rather
    /// than a direct re-export: the risk module does not import the
    /// loop module, so hosts that ran
    /// `QinaoLoop.refineAgainstCounterfactuals(...)` first copy the
    /// four numeric fields into this struct before calling the
    /// enriched surface-matrix overload. That pattern keeps the
    /// Qinao module graph a DAG (Risk is leaf; Loop depends on
    /// nothing below Risk; composition belongs in QinaoRuntime).
    ///
    /// All inputs are clamped at init: `aggregatedContradiction` to
    /// [0, 1]; each branch count to ≥0. This prevents a sloppy
    /// caller from poisoning the `dominantSignal` / threshold
    /// derivations.
    struct CounterfactualEvidence: Sendable, Equatable, Codable {
        public let aggregatedContradiction: Double
        public let branchesExposedInsufficient: Int
        public let branchesEqualEvidence: Int
        public let branchesRobustlySurvived: Int

        public init(
            aggregatedContradiction: Double,
            branchesExposedInsufficient: Int,
            branchesEqualEvidence: Int,
            branchesRobustlySurvived: Int
        ) {
            self.aggregatedContradiction =
                min(max(aggregatedContradiction, 0), 1)
            self.branchesExposedInsufficient =
                max(0, branchesExposedInsufficient)
            self.branchesEqualEvidence =
                max(0, branchesEqualEvidence)
            self.branchesRobustlySurvived =
                max(0, branchesRobustlySurvived)
        }

        /// Total branches the refinement pass examined. Equal to
        /// the sum of the three tally fields (invariant pinned by
        /// M84's `QinaoLoopDreamCycleTests`).
        public var branchesExamined: Int {
            branchesExposedInsufficient
              + branchesEqualEvidence
              + branchesRobustlySurvived
        }

        /// Stable dominant-signal label host copy libraries can key
        /// on. Five cases:
        /// - `"no-branches"` — the refinement ran but produced 0
        ///   branches (the vault had no perturbations to project).
        /// - `"exposed-insufficient-dominant"` — exposed strictly
        ///   exceeds BOTH equal and survived; the candidate's claim
        ///   fails in most perturbed worlds.
        /// - `"equal-evidence-dominant"` — equal strictly exceeds
        ///   BOTH exposed and survived; the claim barely survives
        ///   most perturbed worlds.
        /// - `"robust-survival-dominant"` — survived strictly
        ///   exceeds BOTH exposed and equal; the claim is robust.
        /// - `"balanced"` — no single category dominates (e.g. 1/1/1
        ///   or 2/2/2); evidence is split.
        public var dominantSignal: String {
            let e = branchesExposedInsufficient
            let q = branchesEqualEvidence
            let s = branchesRobustlySurvived
            if e + q + s == 0 { return "no-branches" }
            if e > q && e > s { return "exposed-insufficient-dominant" }
            if q > e && q > s { return "equal-evidence-dominant" }
            if s > e && s > q { return "robust-survival-dominant" }
            return "balanced"
        }

        /// True when aggregated contradiction has crossed the same
        /// 0.7 threshold L9's `guardianBranch` uses. This is the
        /// trigger for upgrading the surface matrix: if the
        /// dream-cycle evidence alone would have tripped L9's
        /// guardian, L12 柔手 should disclose the world-prior
        /// concern explicitly rather than render a bare draft.
        public var crossesGuardianThreshold: Bool {
            aggregatedContradiction >= 0.7
        }
    }

    /// M85 — surface action enriched with dream-cycle evidence.
    ///
    /// `base` is the `SurfaceAction` the matrix would have produced
    /// from the risk assessment alone; `evidence` is the
    /// counterfactual summary the caller supplied; `upgraded` is
    /// true when the evidence caused the surface to be rewritten
    /// (see `surfaceAction(for:counterfactualEvidence:...)` for
    /// the upgrade rules).
    ///
    /// Hosts that log a surface event should log both the original
    /// `assessment.mode` AND this value's `upgraded` bit so the
    /// audit trail records whether the UI seen by the user came
    /// from the risk gate's own verdict or from a dream-cycle
    /// upgrade path.
    struct EnrichedSurfaceAction: Sendable, Equatable, Codable {
        public let base: SurfaceAction
        public let evidence: CounterfactualEvidence
        public let upgraded: Bool

        public init(
            base: SurfaceAction,
            evidence: CounterfactualEvidence,
            upgraded: Bool
        ) {
            self.base = base
            self.evidence = evidence
            self.upgraded = upgraded
        }
    }
}

// MARK: - M85: Pure enriched projection

extension QinaoRiskGate {

    /// M85 — project an assessment onto the surface matrix, then
    /// optionally upgrade the surface using counterfactual evidence
    /// from a dream-cycle refinement pass.
    ///
    /// ## Upgrade rules (stable — pinned by tests)
    ///
    /// The upgrade fires when BOTH conditions hold:
    /// - `counterfactualEvidence.crossesGuardianThreshold` is true
    ///   (aggregated contradiction ≥ 0.7), AND
    /// - the base surface is either `.draftShell` (from an `.allow`
    ///   assessment) or `.comparePanel` (from a non-consent
    ///   `.replace` assessment). Blocks, delays, and consent-gated
    ///   replacements already produce stringent surfaces; upgrading
    ///   them would duplicate signals.
    ///
    /// When the upgrade fires the base action is rewritten:
    /// - `surface` → `.boundaryScript`
    /// - `agency`  → `.userAffirm`
    /// - `disclosure` → `.explicit`
    /// - `substitute` → `.requestConsent(promptKey:
    ///   "dream-cycle-counterfactual-concern")` (stable key the
    ///   host's copy library maps to language explaining that the
    ///   world-prior counterfactual check raised a concern)
    /// - `reasonCodes` gets `"world-prior-contradiction-counterfactual"`
    ///   appended (if not already present); existing reason codes
    ///   are preserved so the audit trail still names the underlying
    ///   risk assessment's concerns.
    ///
    /// When the upgrade does not fire, `upgraded == false` and the
    /// base action is returned verbatim. The evidence is always
    /// attached so hosts that want to expose counterfactual readings
    /// alongside a non-upgraded surface can do so (e.g. show a
    /// "robust survival" badge on a draft shell).
    ///
    /// Non-upgrade assessments where the evidence is still surfaced:
    /// - `.block` — silentStub / refuse stays as-is; evidence
    ///   attached for audit.
    /// - `.delay` — delayPacket / deferToLater stays as-is.
    /// - `.replace` with `"consent-required"` — boundaryScript /
    ///   requestConsent stays as-is (already explicit).
    public static func surfaceAction(
        for assessment: RiskAssessment,
        counterfactualEvidence: CounterfactualEvidence,
        auditReference: String? = nil,
        candidateIDs: [String] = [],
        consentPromptKey: String = "default-consent-prompt"
    ) -> EnrichedSurfaceAction {
        let base = surfaceAction(
            for: assessment,
            auditReference: auditReference,
            candidateIDs: candidateIDs,
            consentPromptKey: consentPromptKey)

        let isUpgradeable =
            base.surface == .draftShell
            || base.surface == .comparePanel
        let shouldUpgrade =
            counterfactualEvidence.crossesGuardianThreshold
            && isUpgradeable

        guard shouldUpgrade else {
            return EnrichedSurfaceAction(
                base: base,
                evidence: counterfactualEvidence,
                upgraded: false)
        }

        var reasons = base.reasonCodes
        let mark = "world-prior-contradiction-counterfactual"
        if !reasons.contains(mark) {
            reasons.append(mark)
        }
        let upgraded = SurfaceAction(
            surface: .boundaryScript,
            agency: .userAffirm,
            disclosure: .explicit,
            substitute: .requestConsent(
                promptKey: "dream-cycle-counterfactual-concern"),
            reasonCodes: reasons,
            auditReference: base.auditReference)
        return EnrichedSurfaceAction(
            base: upgraded,
            evidence: counterfactualEvidence,
            upgraded: true)
    }
}

// MARK: - M85: Actor convenience (enriched)

public extension QinaoRiskGate {

    /// Run the pure evaluator on `signals`, project onto the surface
    /// matrix, and fold in counterfactual evidence from a prior
    /// dream-cycle refinement pass. See
    /// `surfaceAction(for:counterfactualEvidence:...)` for the
    /// upgrade rules.
    ///
    /// Does **not** issue a permit (same contract as the pre-M85
    /// `requestSurfaceAction(...)` — the permit path lives on
    /// `requestActionPermit(for:signals:)`).
    func requestSurfaceAction(
        for signals: RiskSignals,
        counterfactualEvidence: CounterfactualEvidence,
        auditReference: String? = nil,
        candidateIDs: [String] = [],
        consentPromptKey: String = "default-consent-prompt"
    ) -> EnrichedSurfaceAction {
        let assessment = Self.assess(signals)
        return Self.surfaceAction(
            for: assessment,
            counterfactualEvidence: counterfactualEvidence,
            auditReference: auditReference,
            candidateIDs: candidateIDs,
            consentPromptKey: consentPromptKey)
    }

    /// World-aware variant that additionally folds in counterfactual
    /// evidence. Throws `.unknownWorldTemplate` when the vault
    /// doesn't recognise `worldContext.templateID`, matching the
    /// permit-path semantics.
    func requestSurfaceAction(
        for signals: RiskSignals,
        worldContext: WorldRiskContext,
        worldEndpoint: any QinaoWorldPriorEndpoint,
        counterfactualEvidence: CounterfactualEvidence,
        auditReference: String? = nil,
        candidateIDs: [String] = [],
        consentPromptKey: String = "default-consent-prompt"
    ) async throws -> EnrichedSurfaceAction {
        guard
            let worldAssessment = try await worldEndpoint
                .assessRisk(templateID: worldContext.templateID)
        else {
            throw RiskError.unknownWorldTemplate(
                id: worldContext.templateID)
        }
        let assessment = Self.assess(
            signals,
            worldAssessment: worldAssessment,
            worldContext: worldContext)
        return Self.surfaceAction(
            for: assessment,
            counterfactualEvidence: counterfactualEvidence,
            auditReference: auditReference,
            candidateIDs: candidateIDs,
            consentPromptKey: consentPromptKey)
    }
}
