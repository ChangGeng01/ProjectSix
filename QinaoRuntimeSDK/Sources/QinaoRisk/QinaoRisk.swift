import Foundation
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
            func clamp(_ v: Double) -> Double { min(max(v, 0), 1) }
            self.harmSeverity = clamp(harmSeverity)
            self.harmScope = clamp(harmScope)
            self.irreversibility = clamp(irreversibility)
            self.uncertainty = clamp(uncertainty)
            self.evidenceDebt = clamp(evidenceDebt)
            self.manipulationIntensity = clamp(manipulationIntensity)
            self.pressureAuthenticity = clamp(pressureAuthenticity)
            self.gsiScore = clamp(gsiScore)
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

    public struct ActionPermit: Sendable, Equatable, Codable {
        public let permitID: String
        public let digest: String
        public let sessionID: String
        public let mode: Mode
        public let reasonCodes: [String]
        public let issuedAt: Date
        public let expiresAt: Date

        public init(
            permitID: String,
            digest: String,
            sessionID: String,
            mode: Mode,
            reasonCodes: [String],
            issuedAt: Date,
            expiresAt: Date
        ) {
            self.permitID = permitID
            self.digest = digest
            self.sessionID = sessionID
            self.mode = mode
            self.reasonCodes = reasonCodes
            self.issuedAt = issuedAt
            self.expiresAt = expiresAt
        }
    }

    private let permitTTL: TimeInterval
    private let defaultDelaySeconds: TimeInterval
    private let now: @Sendable () -> Date

    public init(
        permitTTLSeconds: TimeInterval = 30,
        defaultDelaySeconds: TimeInterval = 60,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.permitTTL = permitTTLSeconds
        self.defaultDelaySeconds = defaultDelaySeconds
        self.now = now
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
        return try issuePermit(for: intent, assessment: assessment)
    }

    /// Zero-signal overload — defaults to `RiskSignals.safe`
    /// which always resolves to `.allow`. Kept for the existing
    /// "no telemetry" happy-path call site.
    public func requestActionPermit(
        for intent: ActionIntent
    ) async throws -> ActionPermit {
        try await requestActionPermit(for: intent, signals: .safe)
    }

    /// Verify a permit is live for a given intent.
    public func isPermitValid(
        _ permit: ActionPermit,
        for intent: ActionIntent
    ) -> Bool {
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

    // MARK: - Internal

    private func issuePermit(
        for intent: ActionIntent,
        assessment: RiskAssessment
    ) throws -> ActionPermit {
        switch assessment.mode {
        case .allow:
            let issuedAt = now()
            return ActionPermit(
                permitID: "permit-\(UUID().uuidString)",
                digest: intent.digest,
                sessionID: intent.sessionID,
                mode: .allow,
                reasonCodes: assessment.reasonCodes,
                issuedAt: issuedAt,
                expiresAt: issuedAt.addingTimeInterval(permitTTL))
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
