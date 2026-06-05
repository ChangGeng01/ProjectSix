import Foundation
import BASRuntimeCore

/// `BR-05` VerdictEngine — the sovereign decision loop.
///
/// Given a `VerdictContext` describing the current turn (hard-rule
/// observations, soft-signal scores, operation domain, evidence),
/// produces a `BASSovereignVerdict` and appends it to the audit
/// ledger in a single atomic step. This is the single authoritative
/// place where L14 decides whether an action is allowed.
///
/// ## Decision model
///
/// Three-stage evaluation mirroring §11–12 of the Black Ring spec:
///
/// 1. **Hard rules** (BR-001..BR-012). First match wins. Each rule has
///    a *minimum* verdict level — higher levels may be elected in
///    stage 2 but never lower. Absolute red lines (BR-001, BR-003,
///    BR-006, BR-007, BR-012) always carry `DEAD_STOP`.
///
/// 2. **Lexicographic soft signals**. Seven ordered domains (integrity,
///    privilege violation, self-modification, memory contamination,
///    irreversible harm, runtime instability, manipulation intrusion).
///    Each score is classified into {low/mid/high} and walked in
///    strict priority — the first `.high` in that order pins the
///    verdict. This is non-compensatory: "user experience wants it"
///    cannot offset "privilege violation".
///
/// 3. **Evidence-insufficient upgrade**. For irreversible-effect
///    operation domains (`toolWrite`, `hostMutate`, `memoryPromote`),
///    any final verdict is upgraded to at least `toolCut` when
///    evidence is insufficient — per §12.3 and §11.2 BR-008.
///
/// ## Fail-closed on ledger write (BR-012)
///
/// The engine appends the emitted verdict to the audit ledger. If
/// that append throws, the engine re-throws — the verdict *does not*
/// count as issued. Callers MUST treat the throw as grounds to abort
/// the commit, which is exactly the BR-012 semantics we want.
public actor BASSovereignVerdictEngine {
    public enum EngineError:
        Error, Equatable, Sendable, Codable
    {
        case auditAppendFailed(String)
    }

    // MARK: - Inputs

    /// Which of the BR-001..BR-012 hard-rule conditions are observed
    /// true on this turn. Each flag maps 1:1 to a row in §11.1 of the
    /// spec. The engine is a pure function of these observations +
    /// the soft-signal scores + operation metadata — it does not
    /// perform its own integrity checks (those belong to
    /// IntegritySentinel and feed this struct).
    public struct HardObservations: Sendable, Equatable, Codable {
        public var artifactSignatureInvalid: Bool       // BR-001
        public var thoughtFoldChecksumBroken: Bool      // BR-002
        public var externalSideEffectWithoutSCT: Bool   // BR-003
        public var memoryOrHostWriteBypass: Bool        // BR-004
        public var hostRemovalBypassed: Bool            // BR-005
        public var policyBundleTampered: Bool           // BR-006
        public var unauthorizedSelfMutation: Bool       // BR-007
        public var irreversibleHighGSIWithoutEvidence: Bool // BR-008
        public var runtimeUnstableInHighRisk: Bool      // BR-009
        public var riskPermitHeadConflict: Bool         // BR-010
        public var hostAttemptsBaseBoundaryOverride: Bool // BR-011
        public var auditAppendFailed: Bool              // BR-012

        public init(
            artifactSignatureInvalid: Bool = false,
            thoughtFoldChecksumBroken: Bool = false,
            externalSideEffectWithoutSCT: Bool = false,
            memoryOrHostWriteBypass: Bool = false,
            hostRemovalBypassed: Bool = false,
            policyBundleTampered: Bool = false,
            unauthorizedSelfMutation: Bool = false,
            irreversibleHighGSIWithoutEvidence: Bool = false,
            runtimeUnstableInHighRisk: Bool = false,
            riskPermitHeadConflict: Bool = false,
            hostAttemptsBaseBoundaryOverride: Bool = false,
            auditAppendFailed: Bool = false
        ) {
            self.artifactSignatureInvalid = artifactSignatureInvalid
            self.thoughtFoldChecksumBroken = thoughtFoldChecksumBroken
            self.externalSideEffectWithoutSCT = externalSideEffectWithoutSCT
            self.memoryOrHostWriteBypass = memoryOrHostWriteBypass
            self.hostRemovalBypassed = hostRemovalBypassed
            self.policyBundleTampered = policyBundleTampered
            self.unauthorizedSelfMutation = unauthorizedSelfMutation
            self.irreversibleHighGSIWithoutEvidence = irreversibleHighGSIWithoutEvidence
            self.runtimeUnstableInHighRisk = runtimeUnstableInHighRisk
            self.riskPermitHeadConflict = riskPermitHeadConflict
            self.hostAttemptsBaseBoundaryOverride = hostAttemptsBaseBoundaryOverride
            self.auditAppendFailed = auditAppendFailed
        }

        public static var clean: HardObservations { HardObservations() }
    }

    /// Seven soft signals ordered per §12.2. All scores in [0.0, 1.0].
    public struct SoftSignals: Sendable, Equatable, Codable {
        public var integrity: Double
        public var privilegeViolation: Double
        public var selfMod: Double
        public var memoryContamination: Double
        public var irreversibleHarm: Double
        public var runtimeInstability: Double
        public var manipulationIntrusion: Double

        public init(
            integrity: Double = 0,
            privilegeViolation: Double = 0,
            selfMod: Double = 0,
            memoryContamination: Double = 0,
            irreversibleHarm: Double = 0,
            runtimeInstability: Double = 0,
            manipulationIntrusion: Double = 0
        ) {
            self.integrity = integrity
            self.privilegeViolation = privilegeViolation
            self.selfMod = selfMod
            self.memoryContamination = memoryContamination
            self.irreversibleHarm = irreversibleHarm
            self.runtimeInstability = runtimeInstability
            self.manipulationIntrusion = manipulationIntrusion
        }

        public static var calm: SoftSignals { SoftSignals() }
    }

    /// Which operation domain this turn is attempting. Drives the
    /// evidence-insufficient upgrade path from §12.3.
    public enum OperationDomain: String, Sendable, Equatable, Codable {
        case pureInference    // no external effect, not upgraded
        case toolRead
        case toolWrite        // upgraded to toolCut when evidence insufficient
        case hostMutate       // upgraded to toolCut when evidence insufficient
        case memoryPromote    // upgraded to toolCut when evidence insufficient
        case rulePromotion    // upgraded to toolCut when evidence insufficient
    }

    public struct VerdictContext:
        Sendable, Equatable, Codable
    {
        public let sessionID: String
        public let turnID: String
        public let operation: OperationDomain
        public let hardObservations: HardObservations
        public let softSignals: SoftSignals
        public let evidenceSufficient: Bool
        public let snapshotRef: String
        public let policyHash: String

        public init(
            sessionID: String,
            turnID: String,
            operation: OperationDomain,
            hardObservations: HardObservations = .clean,
            softSignals: SoftSignals = .calm,
            evidenceSufficient: Bool = true,
            snapshotRef: String = "",
            policyHash: String = BASSovereignTrustConstants.builtInPolicyHash
        ) {
            self.sessionID = sessionID
            self.turnID = turnID
            self.operation = operation
            self.hardObservations = hardObservations
            self.softSignals = softSignals
            self.evidenceSufficient = evidenceSufficient
            self.snapshotRef = snapshotRef
            self.policyHash = policyHash
        }
    }

    /// Internal record of "which BR rule fired" — exposed to the
    /// caller via `BASSovereignVerdict.reasonCodes` and used by the
    /// engine to drive permission revocation and mode forcing.
    private struct HardRuleHit {
        let code: String
        let minLevel: BASSovereignVerdictLevel
        let revokes: [BASSovereignPermission]
    }

    // MARK: - Dependencies

    private let ledger: BASSovereignAuditLedger
    private let now: @Sendable () -> Date

    public init(
        ledger: BASSovereignAuditLedger,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.ledger = ledger
        self.now = now
    }

    // MARK: - Public API

    /// Evaluate and emit a verdict. Appends the result to the audit
    /// ledger before returning. Throws `EngineError.auditAppendFailed`
    /// if the ledger rejects the append — callers MUST abort the
    /// commit on this error (BR-012 fail-closed).
    @discardableResult
    public func evaluate(_ context: VerdictContext) async throws -> BASSovereignVerdict {
        // Stage 1: hard rules (Swift — produces hits metadata
        // for reasonCodes/revokedPermissions that the Rust port
        // does not return)。
        // ADR-024 — derive the level via the PURE SYNC rule kernel (one source
        // of truth). `evaluate(...)` only adds IDs/clock/ledger around it.
        let decision = evaluateLevel(context)

        // Build verdict + append to ledger. Ledger-append failure is
        // the BR-012 fail-closed signal.
        let verdictID = "sv-\(UUID().uuidString)"
        let auditID = "av-\(UUID().uuidString)"
        let issuedAt = now()

        let verdict = BASSovereignVerdict(
            verdictID: verdictID,
            verdictLevel: decision.level,
            latched: decision.level.isLatchedByDefault,
            forcedMode: decision.level.defaultForcedMode,
            reasonCodes: decision.reasonCodes,
            revokedPermissions: decision.revokedPermissions,
            quarantineRefs: [],
            rollbackRef: nil,
            userStubMode: defaultStubMode(for: decision.level),
            auditRef: auditID,
            policyHash: context.policyHash,
            expiresAt: nil
        )

        // chapter 九百九十六.5 Round-15 CRITICAL-2:hardened
        // canonical-bytes for verdict engine emission (main
        // L14 audit emission point)
        let entry = BASSovereignAuditEntry(
            // ch 1011 / M3770 — Round-21 HIGH-1: shared constant
            schemaVersion: BASSovereignAuditEntry
                .hardenedSchemaVersion,
            auditID: auditID,
            sessionID: context.sessionID,
            turnID: context.turnID,
            verdictRef: verdictID,
            ruleIDs: decision.reasonCodes,
            signalRefs: [],
            actionRefs: [context.operation.rawValue],
            snapshotRef: context.snapshotRef,
            actor: .system,
            signature: "",
            appendedAt: issuedAt
        )

        do {
            _ = try await ledger.append(entry)
        } catch {
            throw EngineError.auditAppendFailed("\(error)")
        }

        return verdict
    }

    // MARK: - Pure rule kernel (ADR-024 — one verdict authority)

    /// The pure output of `evaluateLevel`: the verdict LEVEL plus its reason
    /// codes and revoked permissions — with NO verdict/audit IDs, NO clock, and
    /// NO ledger side-effect. (ADR-024.)
    public struct LevelDecision: Sendable, Equatable {
        public let level: BASSovereignVerdictLevel
        public let reasonCodes: [String]
        public let revokedPermissions: [BASSovereignPermission]
        public init(
            level: BASSovereignVerdictLevel,
            reasonCodes: [String],
            revokedPermissions: [BASSovereignPermission]
        ) {
            self.level = level
            self.reasonCodes = reasonCodes
            self.revokedPermissions = revokedPermissions
        }
    }

    /// The PURE, SYNCHRONOUS rule kernel: Stage-1 hard rules + (routed/Swift)
    /// level + the evidence-insufficient upgrade + reason codes + revoked
    /// permissions. It has no IDs, no clock, and NO ledger append, so it is
    /// deterministic (same context → same decision) and side-effect-free.
    /// `evaluate(...)` builds the full signed `BASSovereignVerdict` + audit entry
    /// AROUND this. Exposing it lets any other verdict authority (the
    /// coordinator's `computeVerdictDecision`, the parity shadow) derive the SAME
    /// level from the SAME context without an async ledger append — the single
    /// source of truth that makes accidental rule-drift impossible (ADR-024).
    public func evaluateLevel(_ context: VerdictContext) -> LevelDecision {
        // The production default reads the (startup-stable) routing flag at
        // exactly one point and delegates. The explicit-`useRouted` overload
        // below lets tests exercise BOTH branches without mutating the shared
        // `useRoutedVerdictLevel` static — which races under parallel test
        // execution (the verdict engine is the safety arbiter; a concurrent
        // reader must never observe a mid-flip value). byte-equal by
        // construction: same global, same single read, same branch logic.
        evaluateLevel(context, useRouted: Self.useRoutedVerdictLevel)
    }

    /// The pure level kernel with the routed-vs-Swift choice as an EXPLICIT
    /// input (ADR-024: a deterministic function of its inputs — same context +
    /// same `useRouted` → same decision). `evaluateLevel(_:)` passes the
    /// production `useRoutedVerdictLevel` default; tests pass an explicit value
    /// so they never mutate the shared static.
    public func evaluateLevel(_ context: VerdictContext, useRouted: Bool) -> LevelDecision {
        // Stage 1: hard rules (Swift — produces hits metadata
        // for reasonCodes/revokedPermissions that the Rust port
        // does not return)。
        let hits = evaluateHardRules(context.hardObservations)

        var level: BASSovereignVerdictLevel
        let softPinnedDomain: String?

        if useRouted,
           let routedLevel = Self.routedDeriveLevel(
            hardObservations: context.hardObservations,
            softSignals: context.softSignals,
            operation: context.operation,
            evidenceSufficient: context.evidenceSufficient)
        {
            // Rust path:single C ABI call covers Stages 2+3
            // + hard bit cap promotion。 Cross-check max with
            // hits' min levels (belt-and-suspenders)。
            level = routedLevel
            for hit in hits where hit.minLevel > level {
                level = hit.minLevel
            }
            let (_, pinned) =
                evaluateSoftSignals(context.softSignals)
            softPinnedDomain = pinned
        } else {
            // V1 Swift path — Stage 2: soft-signal lex order.
            let (softLevel, pinned) =
                evaluateSoftSignals(context.softSignals)
            softPinnedDomain = pinned

            // Pick the max of (hard hits' min levels, soft level).
            level = softLevel
            for hit in hits where hit.minLevel > level {
                level = hit.minLevel
            }

            // Stage 3: evidence-insufficient upgrade for
            // irreversible ops.
            if isIrreversible(context.operation) &&
                !context.evidenceSufficient
            {
                if level < .toolCut {
                    level = .toolCut
                }
            }
        }

        // Collect revoked permissions from all firing rules.
        var revoked: Set<BASSovereignPermission> = []
        var reasonCodes: [String] = []
        for hit in hits {
            reasonCodes.append(hit.code)
            for perm in hit.revokes {
                revoked.insert(perm)
            }
        }
        if reasonCodes.isEmpty && level != .pass {
            let domain = softPinnedDomain ?? dominantSoftDomain(context.softSignals) ?? "unknown"
            reasonCodes.append("LEX_ORDER:\(domain)")
        }
        if isIrreversible(context.operation) && !context.evidenceSufficient && level == .toolCut {
            reasonCodes.append("EVIDENCE_INSUFFICIENT:\(context.operation.rawValue)")
        }

        return LevelDecision(
            level: level,
            reasonCodes: reasonCodes,
            revokedPermissions: revoked.sorted { $0.rawValue < $1.rawValue })
    }

    // MARK: - Stage 1: hard rules

    private func evaluateHardRules(_ obs: HardObservations) -> [HardRuleHit] {
        var hits: [HardRuleHit] = []

        // Order matches §11.1 of the spec. Absolute red lines first is
        // not required for correctness (each rule has a min level and
        // we take the max) but it makes reading trace logs easier.
        if obs.artifactSignatureInvalid {
            hits.append(HardRuleHit(
                code: "BR-001",
                minLevel: .deadStop,
                revokes: BASSovereignPermission.allCases
            ))
        }
        if obs.thoughtFoldChecksumBroken {
            hits.append(HardRuleHit(
                code: "BR-002",
                minLevel: .rollback,
                revokes: [.memoryWriteHot, .memoryWriteWarm, .memoryWriteCold]
            ))
        }
        if obs.externalSideEffectWithoutSCT {
            hits.append(HardRuleHit(
                code: "BR-003",
                minLevel: .deadStop,
                revokes: [.toolWrite, .externalActuation, .checkpointCommit, .renderHighRisk]
            ))
        }
        if obs.memoryOrHostWriteBypass {
            hits.append(HardRuleHit(
                code: "BR-004",
                minLevel: .memoryFreeze,
                revokes: [.memoryWriteHot, .memoryWriteWarm, .memoryWriteCold, .hostMutation]
            ))
        }
        if obs.hostRemovalBypassed {
            hits.append(HardRuleHit(
                code: "BR-005",
                minLevel: .quarantine,
                revokes: [.hostMutation, .rulePromotion]
            ))
        }
        if obs.policyBundleTampered {
            hits.append(HardRuleHit(
                code: "BR-006",
                minLevel: .deadStop,
                revokes: BASSovereignPermission.allCases
            ))
        }
        if obs.unauthorizedSelfMutation {
            hits.append(HardRuleHit(
                code: "BR-007",
                minLevel: .deadStop,
                revokes: BASSovereignPermission.allCases
            ))
        }
        if obs.irreversibleHighGSIWithoutEvidence {
            hits.append(HardRuleHit(
                code: "BR-008",
                minLevel: .toolCut,
                revokes: [.toolWrite, .externalActuation, .renderHighRisk]
            ))
        }
        if obs.runtimeUnstableInHighRisk {
            hits.append(HardRuleHit(
                code: "BR-009",
                minLevel: .shadowLock,
                revokes: [.deepLoop, .renderHighRisk]
            ))
        }
        if obs.riskPermitHeadConflict {
            hits.append(HardRuleHit(
                code: "BR-010",
                minLevel: .throttle,
                revokes: [.checkpointCommit]
            ))
        }
        if obs.hostAttemptsBaseBoundaryOverride {
            hits.append(HardRuleHit(
                code: "BR-011",
                minLevel: .quarantine,
                revokes: [.hostMutation, .rulePromotion]
            ))
        }
        if obs.auditAppendFailed {
            hits.append(HardRuleHit(
                code: "BR-012",
                minLevel: .deadStop,
                revokes: BASSovereignPermission.allCases
            ))
        }
        return hits
    }

    // MARK: - Stage 2: lexicographic soft signals

    /// Classify a soft signal into low/mid/high buckets. Thresholds
    /// match the spec's description ("high" ≈ ≥0.7, "mid" ≈ 0.4–0.7).
    private enum Band { case low, mid, high }

    private func band(_ score: Double) -> Band {
        if score >= 0.7 { return .high }
        if score >= 0.4 { return .mid }
        return .low
    }

    private func evaluateSoftSignals(_ s: SoftSignals) -> (level: BASSovereignVerdictLevel, pinnedDomain: String?) {
        // Walk in the non-compensatory order from §12.2. First .high
        // domain pins the verdict; otherwise accumulate mids.
        let ordered: [(domain: String, score: Double, highLevel: BASSovereignVerdictLevel, midLevel: BASSovereignVerdictLevel)] = [
            ("integrity",             s.integrity,             .deadStop,     .rollback),
            ("privilegeViolation",    s.privilegeViolation,    .quarantine,   .shadowLock),
            ("selfMod",               s.selfMod,               .deadStop,     .quarantine),
            ("memoryContamination",   s.memoryContamination,   .memoryFreeze, .shadowLock),
            ("irreversibleHarm",      s.irreversibleHarm,      .toolCut,      .throttle),
            ("runtimeInstability",    s.runtimeInstability,    .shadowLock,   .throttle),
            ("manipulationIntrusion", s.manipulationIntrusion, .toolCut,      .throttle)
        ]

        var best: BASSovereignVerdictLevel = .pass
        var bestDomain: String? = nil
        for entry in ordered {
            switch band(entry.score) {
            case .high:
                // Non-compensatory: highest-priority .high pins, return.
                return (entry.highLevel, entry.domain)
            case .mid:
                if entry.midLevel > best {
                    best = entry.midLevel
                    bestDomain = entry.domain
                }
            case .low:
                continue
            }
        }
        return (best, bestDomain)
    }

    private func dominantSoftDomain(_ s: SoftSignals) -> String? {
        let pairs: [(String, Double)] = [
            ("integrity", s.integrity),
            ("privilegeViolation", s.privilegeViolation),
            ("selfMod", s.selfMod),
            ("memoryContamination", s.memoryContamination),
            ("irreversibleHarm", s.irreversibleHarm),
            ("runtimeInstability", s.runtimeInstability),
            ("manipulationIntrusion", s.manipulationIntrusion)
        ]
        let top = pairs.max(by: { $0.1 < $1.1 })
        guard let top, top.1 > 0 else { return nil }
        return top.0
    }

    // MARK: - Helpers

    private func isIrreversible(_ op: OperationDomain) -> Bool {
        switch op {
        case .toolWrite, .hostMutate, .memoryPromote, .rulePromotion:
            return true
        case .pureInference, .toolRead:
            return false
        }
    }

    private func defaultStubMode(for level: BASSovereignVerdictLevel) -> BASSovereignUserStubMode {
        switch level {
        case .pass, .throttle:
            return .none
        case .shadowLock, .toolCut, .memoryFreeze:
            return .minimalReceipt
        case .quarantine, .rollback, .deadStop:
            return .refusalOnly
        }
    }
}
