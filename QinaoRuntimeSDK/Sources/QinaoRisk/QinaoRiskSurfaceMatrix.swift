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
