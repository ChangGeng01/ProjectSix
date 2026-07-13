import Foundation
import CryptoKit
import BASRuntimeCore
import BASPolicy

/// QinaoRisk — the L11 risk-gate façade.
///
/// The risk gate is the *first* of the three signatures required
/// to execute a tool call:
///
///     ActionPermit (this module)
///   + SovereignWarrant (QinaoSovereign)
///   + SnapshotContinuityProof (QinaoSovereign.verifyRestore)
///   = runtime is willing to call the tool
///
/// The permit carries a `digest` of the intent. That same digest
/// must appear in the warrant, so the three signatures are bound
/// to the same action.
///
/// # Synthesis pipeline
///
/// `requestActionPermit(for:signals:)` drives a deterministic
/// pipeline over the substrate's L11 risk-plane primitives:
///
/// 1. **Assess** — `RiskSignals` → `RiskAssessment` via the pure
///    `assess(_:)` evaluator. Four-way decision over hard
///    thresholds (block / replace / delay / allow) with stable
///    reason codes; no randomness, no hidden state.
/// 2. **Issue or refuse** — `.allow` returns a live permit bound
///    to the intent digest + session; `.block` throws `.denied`;
///    `.delay` throws `.deferred` (carrying the retry window);
///    `.replace` throws `.replaced` (carrying the substitute hint).
///
/// Internally the evaluator composes `BASHazardVector` +
/// `BASGSITrace` + a derived `BASBrainRiskLevel` and maps the
/// substrate's `BASActionPermitMode` back to the façade's `Mode`
/// so no `BAS*` risk-plane type ever surfaces in the public API.
public actor QinaoRiskGate {

    public enum RiskError: Error, Equatable, Sendable {
        /// The intent is unsafe enough that the gate refuses outright.
        case denied(reason: String)
        /// The gate asks the host to delay the action to a safer moment.
        case deferred(retryAfterSeconds: TimeInterval, reason: String)
        /// The gate asks the host to replace the intent with a softer one.
        case replaced(with: String, reason: String)
        /// The world-prior endpoint did not recognise the template ID
        /// supplied in `WorldRiskContext`. Distinct from `.denied` so
        /// the host can tell "taxonomy miss" from "assessed unsafe".
        case unknownWorldTemplate(id: String)
    }

    public enum Mode: String, Sendable, Equatable, Codable {
        case allow
        case delay
        case replace
        case block
    }

    public struct ActionIntent: Sendable, Equatable {
        public let digest: String
        public let toolName: String
        public let sessionID: String
        public let hostVersionID: String
        public let summary: String

        public init(
            digest: String,
            toolName: String,
            sessionID: String,
            hostVersionID: String,
            summary: String
        ) {
            self.digest = digest
            self.toolName = toolName
            self.sessionID = sessionID
            self.hostVersionID = hostVersionID
            self.summary = summary
        }
    }

    /// Normalised [0,1] risk input vector. Every field has a
    /// defined substrate counterpart but the host only sees scalar
    /// doubles — no `BAS*` types leak through.
    public struct RiskSignals: Sendable, Equatable {
        public let harmSeverity: Double
        public let harmScope: Double
        public let irreversibility: Double
        public let uncertainty: Double
        public let evidenceDebt: Double
        public let manipulationIntensity: Double
        public let pressureAuthenticity: Double
        public let gsiScore: Double

        public init(
            harmSeverity: Double = 0,
            harmScope: Double = 0,
            irreversibility: Double = 0,
            uncertainty: Double = 0,
            evidenceDebt: Double = 0,
            manipulationIntensity: Double = 0,
            pressureAuthenticity: Double = 1,
            gsiScore: Double = 0
        ) {
            // deep-audit P0-5 (2026-07-13): NaN must FAIL CLOSED per field, not pass through
            // `min(max(NaN,0),1)=NaN` and then slip every `>= threshold` block-check
            // (NaN >= x is false) into a baseline .allow. `nan` is the field's fail-closed pole:
            // harm-direction fields (blocked on HIGH) → 1.0; pressureAuthenticity is inverse
            // (blocked on `<= 0.3`) → 0.0 so a NaN still trips its block.
            func clamp(_ v: Double, nan: Double) -> Double {
                guard !v.isNaN else { return nan }
                return min(max(v, 0), 1)
            }
            self.harmSeverity = clamp(harmSeverity, nan: 1)
            self.harmScope = clamp(harmScope, nan: 1)
            self.irreversibility = clamp(irreversibility, nan: 1)
            self.uncertainty = clamp(uncertainty, nan: 1)
            self.evidenceDebt = clamp(evidenceDebt, nan: 1)
            self.manipulationIntensity = clamp(manipulationIntensity, nan: 1)
            self.pressureAuthenticity = clamp(pressureAuthenticity, nan: 0)
            self.gsiScore = clamp(gsiScore, nan: 1)
        }

        /// Default "no risk raised" signals — used when the caller
        /// has no explicit telemetry and wants the baseline allow.
        public static let safe = RiskSignals()
    }

    /// Output of the pure evaluator. `mode` is the primary
    /// decision; `reasonCodes` are stable identifiers so hosts
    /// can key UI copy and audit entries on them.
    public struct RiskAssessment: Sendable, Equatable {
        public let mode: Mode
        public let reasonCodes: [String]
        public let recommendedDelaySeconds: TimeInterval?
        public let substituteHint: String?

        public init(
            mode: Mode,
            reasonCodes: [String],
            recommendedDelaySeconds: TimeInterval? = nil,
            substituteHint: String? = nil
        ) {
            self.mode = mode
            self.reasonCodes = reasonCodes
            self.recommendedDelaySeconds = recommendedDelaySeconds
            self.substituteHint = substituteHint
        }
    }

    /// integration permit-signing (2026-07-12): permits are HMAC-SHA256 signed at mint
    /// (`signature` binds ALL fields incl. `mode` — a forged block→allow flip breaks the
    /// tag) and verified signature-first in `isPermitValid`. This closes the last
    /// field-binding-only lane of the three-signature gate; the permit is now safe to
    /// carry across a process boundary when both sides share the gate's `permitTagKey`.
    public struct ActionPermit: Sendable, Equatable, Codable {
        public let permitID: String
        public let digest: String
        public let sessionID: String
        public let mode: Mode
        public let reasonCodes: [String]
        public let issuedAt: Date
        public let expiresAt: Date
        /// HMAC-SHA256 tag over all seven fields (hex). Minted only by the risk gate.
        public let signature: String

        public init(
            permitID: String,
            digest: String,
            sessionID: String,
            mode: Mode,
            reasonCodes: [String],
            issuedAt: Date,
            expiresAt: Date,
            signature: String
        ) {
            self.permitID = permitID
            self.digest = digest
            self.sessionID = sessionID
            self.mode = mode
            self.reasonCodes = reasonCodes
            self.issuedAt = issuedAt
            self.expiresAt = expiresAt
            self.signature = signature
        }
    }

    private let permitTTL: TimeInterval
    private let defaultDelaySeconds: TimeInterval
    private let now: @Sendable () -> Date
    private let permitEventRecorder: PermitEventRecorder?

    /// integration permit-signing: HMAC key for permit tags. QinaoRisk deliberately
    /// imports no sovereign module — the key is plain CryptoKit, injected by the
    /// composition layer. Random default = mint/verify on the same instance works with
    /// zero config (and forged permits still fail); cross-process hosts inject a shared
    /// stable key on BOTH gates so a permit minted on one verifies on the other.
    private let permitTagKey: SymmetricKey

    /// M99 — callback fired AFTER a permit is successfully issued
    /// but BEFORE it is returned to the caller. Designed to let the
    /// L14 audit ledger record a `permit:issued` event so every
    /// permit that reaches the caller has a durable audit trail.
    ///
    /// Fail-closed semantics: if the recorder throws, the permit
    /// is NOT returned to the caller. The error propagates out of
    /// `requestActionPermit`. This prevents a permit from escaping
    /// into the wild without its audit entry landing — the very
    /// failure mode T8 in the l2-silly-piglet plan calls out
    /// ("ledger append failure must halt").
    ///
    /// Optional: tests and legacy call sites default to `nil`, which
    /// preserves pre-M99 behavior byte-for-byte — permits issue
    /// exactly as before with no recorder call.
    ///
    /// The closure is isolated to the Qinao composition layer
    /// (QinaoRuntime) for reasons of architectural hygiene — keeping
    /// `QinaoRisk` free of a direct `BASSovereign` import maintains
    /// the four-layer nesting model. The composition layer holds
    /// the actual `BASSovereignAuditLedger` reference and adapts it
    /// into this closure shape.
    public typealias PermitEventRecorder = @Sendable (
        ActionPermit
    ) async throws -> Void

    public init(
        permitTTLSeconds: TimeInterval = 30,
        defaultDelaySeconds: TimeInterval = 60,
        permitEventRecorder: PermitEventRecorder? = nil,
        now: @escaping @Sendable () -> Date = { Date() },
        permitTagKey: SymmetricKey = SymmetricKey(size: .bits256)
    ) {
        self.permitTTL = permitTTLSeconds
        self.defaultDelaySeconds = defaultDelaySeconds
        self.permitEventRecorder = permitEventRecorder
        self.now = now
        self.permitTagKey = permitTagKey
    }

    /// integration permit-signing — injective permit tag. Mirrors the sovereign
    /// module's token-tag scheme (length-prefixed fields, dates via bitPattern) with a
    /// domain label so a permit tag can never collide with a warrant/proof tag under a
    /// shared key, and the reason-code COUNT is folded in so variable-arity reason
    /// lists cannot alias adjacent fields.
    /// The injective canonical bytes signed by a permit tag (fields shared by mint+verify).
    static func permitCanonicalBytes(_ permit: ActionPermit) -> Data {
        var fields = [
            "qinao.permit.v1",
            permit.permitID, permit.digest, permit.sessionID,
            permit.mode.rawValue, String(permit.reasonCodes.count),
        ]
        fields.append(contentsOf: permit.reasonCodes)
        fields.append("t\(String(permit.issuedAt.timeIntervalSince1970.bitPattern, radix: 16))")
        fields.append("t\(String(permit.expiresAt.timeIntervalSince1970.bitPattern, radix: 16))")
        return Data(fields.map { "\($0.utf8.count):\($0)" }.joined().utf8)
    }

    static func permitTag(
        key: SymmetricKey, _ permit: ActionPermit
    ) -> String {
        Data(HMAC<SHA256>.authenticationCode(
            for: permitCanonicalBytes(permit), using: key))
            .map { String(format: "%02x", $0) }.joined()
    }

    /// deep-audit MEDIUM-1: decode an even-length hex string to raw bytes; nil on any
    /// malformed input (so a garbage signature fails closed at decode, before verify).
    static func hexToBytes(_ hex: String) -> Data? {
        guard hex.count % 2 == 0 else { return nil }
        var out = Data(capacity: hex.count / 2)
        var idx = hex.startIndex
        while idx < hex.endIndex {
            let next = hex.index(idx, offsetBy: 2)
            guard let b = UInt8(hex[idx..<next], radix: 16) else { return nil }
            out.append(b)
            idx = next
        }
        return out
    }

    // MARK: - Permit issuance

    /// Evaluate with explicit risk signals. `.allow` returns a
    /// live permit; non-`.allow` assessments throw the typed
    /// error matching the assessed mode.
    public func requestActionPermit(
        for intent: ActionIntent,
        signals: RiskSignals
    ) async throws -> ActionPermit {
        let assessment = Self.assess(signals)
        return try await issuePermit(
            for: intent, assessment: assessment)
    }

    /// Zero-signal overload — defaults to `RiskSignals.safe`
    /// which always resolves to `.allow`. Kept for the existing
    /// "no telemetry" happy-path call site.
    public func requestActionPermit(
        for intent: ActionIntent
    ) async throws -> ActionPermit {
        try await requestActionPermit(for: intent, signals: .safe)
    }

    /// World-aware permit request. Consults the supplied
    /// `QinaoWorldPriorEndpoint` for the `worldContext.templateID`,
    /// merges the irreversible-harm score into `signals.irreversibility`
    /// via `max`, forces `.replace` when the matched template requires
    /// informed consent and the caller has not acknowledged it, forces
    /// `.delay` when an irreversible template lacks sufficient evidence,
    /// and otherwise runs the standard four-stage evaluator. Throws
    /// `.unknownWorldTemplate` when the endpoint has no entry for the
    /// requested template ID.
    ///
    /// This is the call path hosts use when they want the L4 world-prior
    /// layer ("懂世界") folded into the permit decision. Tests and
    /// headless callers that never register a world-prior vault can
    /// keep using the non-world overload — world-awareness is additive.
    public func requestActionPermit(
        for intent: ActionIntent,
        signals: RiskSignals,
        worldContext: WorldRiskContext,
        worldEndpoint: any QinaoWorldPriorEndpoint
    ) async throws -> ActionPermit {
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
        return try await issuePermit(
            for: intent, assessment: assessment)
    }

    /// Verify a permit is live for a given intent.
    public func isPermitValid(
        _ permit: ActionPermit,
        for intent: ActionIntent
    ) -> Bool {
        // integration permit-signing: signature FIRST — a permit not minted with this
        // gate's key (or tampered after mint, incl. a block→allow mode flip) fails closed.
        // deep-audit MEDIUM-1 (2026-07-13): CONSTANT-TIME MAC verification (was a hex
        // `String ==` that short-circuits on the first differing byte — a byte-by-byte MAC
        // timing oracle, exactly what the ledger's ch1044 fix eliminated). The permit is
        // advertised cross-process-carry-safe, which is precisely the threat model where a
        // MAC oracle matters. Decode the stored hex to raw bytes and use the constant-time
        // isValidAuthenticationCode; same accept/reject set, no timing side channel.
        guard let rawSig = Self.hexToBytes(permit.signature),
              HMAC<SHA256>.isValidAuthenticationCode(
                rawSig,
                authenticating: Self.permitCanonicalBytes(permit),
                using: permitTagKey)
        else { return false }
        guard permit.digest == intent.digest else { return false }
        guard permit.sessionID == intent.sessionID else { return false }
        guard permit.mode == .allow else { return false }
        guard permit.expiresAt > now() else { return false }
        return true
    }

    // MARK: - Pure evaluator

    /// Deterministic four-way decision over `RiskSignals`.
    ///
    /// Priority (first threshold wins):
    ///
    /// 1. `.block` — irrecoverable harm likely
    ///    (`harmSeverity ≥ 0.85` or `irreversibility ≥ 0.9`).
    /// 2. `.replace` — the intent looks pressure-driven rather
    ///    than autonomous (`manipulationIntensity ≥ 0.7` or
    ///    `gsiScore ≥ 0.7` or `pressureAuthenticity ≤ 0.3`).
    /// 3. `.delay` — we don't know enough yet
    ///    (`uncertainty ≥ 0.7` or `evidenceDebt ≥ 0.7`).
    /// 4. `.allow` — baseline.
    ///
    /// Reason codes are stable strings so host UI and audit
    /// ledger both key on identical values.
    public static func assess(
        _ signals: RiskSignals
    ) -> RiskAssessment {
        var reasons: [String] = []

        // Stage 1: block
        if signals.harmSeverity >= 0.85 {
            reasons.append("harm-severity-ceiling")
        }
        if signals.irreversibility >= 0.9 {
            reasons.append("irreversibility-ceiling")
        }
        if !reasons.isEmpty {
            return RiskAssessment(
                mode: .block,
                reasonCodes: reasons)
        }

        // Stage 2: replace (pressure-driven intent)
        if signals.manipulationIntensity >= 0.7 {
            reasons.append("manipulation-intensity-high")
        }
        if signals.gsiScore >= 0.7 {
            reasons.append("gsi-pressure-high")
        }
        if signals.pressureAuthenticity <= 0.3 {
            reasons.append("pressure-inauthentic")
        }
        if !reasons.isEmpty {
            return RiskAssessment(
                mode: .replace,
                reasonCodes: reasons,
                substituteHint: "mirror-and-compare-instead")
        }

        // Stage 3: delay (evidence shortfall)
        if signals.uncertainty >= 0.7 {
            reasons.append("uncertainty-high")
        }
        if signals.evidenceDebt >= 0.7 {
            reasons.append("evidence-debt-high")
        }
        if !reasons.isEmpty {
            return RiskAssessment(
                mode: .delay,
                reasonCodes: reasons,
                recommendedDelaySeconds: 60)
        }

        // Stage 4: allow
        return RiskAssessment(
            mode: .allow,
            reasonCodes: ["baseline-clear"])
    }

    /// World-aware evaluator. Deterministic layering on top of the
    /// base `assess(_:)` pipeline:
    ///
    /// 1. The matched template's `irreversibleHarmScore` is folded
    ///    into `signals.irreversibility` via `max`. This lets a
    ///    world-prior template raise the bar on an otherwise
    ///    "looks safe" signal set.
    /// 2. The base evaluator runs on the merged signals. If it
    ///    returns `.block`, block wins — hard ceilings trump every
    ///    softer gate, including consent.
    /// 3. If `requiresConsent && !consentAcknowledged`, we force
    ///    `.replace` with the stable reason code `consent-required`
    ///    and the substitute hint `request-informed-consent`. Hosts
    ///    key their consent-prompt UI on this pair.
    /// 4. If `!evidenceSufficient` and the template's irreversibility
    ///    is non-trivial (`≥ 0.5`), we force `.delay` so the caller
    ///    collects more evidence before committing.
    /// 5. Otherwise the base result carries through, annotated with
    ///    the `world-template:<id>` reason code for audit tracing.
    ///
    /// The evaluator is pure — same inputs always produce the same
    /// `RiskAssessment`. No clock, no randomness, no network.
    public static func assess(
        _ signals: RiskSignals,
        worldAssessment: WorldRiskAssessment,
        worldContext: WorldRiskContext
    ) -> RiskAssessment {
        let merged = RiskSignals(
            harmSeverity: signals.harmSeverity,
            harmScope: signals.harmScope,
            irreversibility: max(
                signals.irreversibility,
                worldAssessment.irreversibleHarmScore),
            uncertainty: signals.uncertainty,
            evidenceDebt: signals.evidenceDebt,
            manipulationIntensity: signals.manipulationIntensity,
            pressureAuthenticity: signals.pressureAuthenticity,
            gsiScore: signals.gsiScore)

        let base = assess(merged)
        let templateTag =
            "world-template:\(worldAssessment.matchedTemplateID)"

        // Block wins unconditionally — consent can't unlock a hard
        // ceiling, and evidence gaps can't be deferred past one.
        if base.mode == .block {
            return RiskAssessment(
                mode: .block,
                reasonCodes: base.reasonCodes + [templateTag],
                recommendedDelaySeconds: base.recommendedDelaySeconds,
                substituteHint: base.substituteHint)
        }

        // Consent gate: ethics-domain irreversibles require an
        // explicit host acknowledgement, or we replace with a
        // consent-prompt hint.
        if worldAssessment.requiresConsent
            && !worldContext.consentAcknowledged
        {
            return RiskAssessment(
                mode: .replace,
                reasonCodes: [
                    "consent-required",
                    templateTag
                ],
                substituteHint: "request-informed-consent")
        }

        // Evidence gate: non-trivially irreversible templates need
        // sufficient evidence before we commit.
        if !worldAssessment.evidenceSufficient
            && worldAssessment.irreversibleHarmScore >= 0.5
        {
            return RiskAssessment(
                mode: .delay,
                reasonCodes: [
                    "evidence-insufficient-for-irreversible",
                    templateTag
                ],
                recommendedDelaySeconds: 60)
        }

        return RiskAssessment(
            mode: base.mode,
            reasonCodes: base.reasonCodes + [templateTag],
            recommendedDelaySeconds: base.recommendedDelaySeconds,
            substituteHint: base.substituteHint)
    }

    // MARK: - Internal

    private func issuePermit(
        for intent: ActionIntent,
        assessment: RiskAssessment
    ) async throws -> ActionPermit {
        switch assessment.mode {
        case .allow:
            let issuedAt = now()
            // integration permit-signing: sign at mint, BEFORE the M99 recorder fires,
            // so the audited permit is byte-identical to the returned one.
            let unsigned = ActionPermit(
                permitID: "permit-\(UUID().uuidString)",
                digest: intent.digest,
                sessionID: intent.sessionID,
                mode: .allow,
                reasonCodes: assessment.reasonCodes,
                issuedAt: issuedAt,
                expiresAt: issuedAt.addingTimeInterval(permitTTL),
                signature: "")
            let permit = ActionPermit(
                permitID: unsigned.permitID,
                digest: unsigned.digest,
                sessionID: unsigned.sessionID,
                mode: unsigned.mode,
                reasonCodes: unsigned.reasonCodes,
                issuedAt: unsigned.issuedAt,
                expiresAt: unsigned.expiresAt,
                signature: Self.permitTag(key: permitTagKey, unsigned))
            // M99 — fail-closed audit recording. If a recorder is
            // wired, it MUST succeed before the permit reaches the
            // caller. Any recorder error propagates out so the
            // caller never receives a permit whose audit entry
            // failed to land.
            if let recorder = permitEventRecorder {
                try await recorder(permit)
            }
            return permit
        case .block:
            throw RiskError.denied(
                reason: assessment.reasonCodes.joined(separator: ","))
        case .delay:
            let retry = assessment.recommendedDelaySeconds
                ?? defaultDelaySeconds
            throw RiskError.deferred(
                retryAfterSeconds: retry,
                reason: assessment.reasonCodes.joined(separator: ","))
        case .replace:
            throw RiskError.replaced(
                with: assessment.substituteHint
                    ?? "mirror-and-compare-instead",
                reason: assessment.reasonCodes.joined(separator: ","))
        }
    }
}
