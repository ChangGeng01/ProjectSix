// MARK: - BASArbitrationObservationFrame
// chapter 五百八 / M1409 — 3rd Tier C shape-specific
// generic primitive per ADR-019 (approved M1405)
//
// HONEST naming note:proposal called this "BAS
// ArbitrationFrame" but that name is already taken by
// a concrete L10-tribunal struct in BASOrchestration。
// Renamed at chapter 508 to BASArbitrationObservationFrame
// <Body> to avoid collision while preserving semantic
// distinction (typed generic body)。
//
// Targets the "L10 tribunal arbitration aggregate"
// shape:N arbiter refs + N disputed-claim refs + typed
// stage + arbitration policy + verdictHint + Body +
// diagnostics。
//
// HONEST SCOPE — chapter 五百八:
// =============================================================
// 3rd Tier C primitive。 Pure-additive — existing
// BASArbitrationFrame migration is follow-up arc。 V1
// byte-equality preserved。 ADR-014 OPT-IN preserved。

import Foundation

/// Typed arbitration-stage classifier for the generic
/// frame。 Stable raw values per chapter 一百八十五。
public enum BASArbitrationStage:
    String, Codable, Sendable, Equatable, Hashable, CaseIterable
{
    /// Arbiters reviewing the disputed claims — no
    /// verdict emitted yet。
    case review = "review"

    /// Arbiters negotiating — typed reason codes
    /// captured for audit。
    case negotiate = "negotiate"

    /// Verdict converged — arbiters reached agreement。
    case converged = "converged"

    /// Arbiters unable to reach agreement — escalation
    /// required per L14 sovereign doctrine。
    case escalated = "escalated"
}

/// Generic arbitration-observation envelope per ADR-019
/// approved chapter 五百七 M1405。
public struct BASArbitrationObservationFrame<Body>:
    Equatable, Hashable, Codable, Sendable
where
    Body: Equatable & Hashable & Codable & Sendable
{

    /// Stable identifier for this arbitration event。
    public let arbitrationID: String

    /// Schema version pin for replay-determinism。
    public let schemaVersion: String

    /// Stable refs to the arbiter(s) participating。
    /// Non-empty per arbitration-doctrine pin (no
    /// anonymous arbitrations)。
    public let arbiterRefs: [String]

    /// Stable refs to the disputed claim(s)。 Non-empty
    /// per arbitration-doctrine pin (no empty
    /// arbitrations)。
    public let disputedClaimRefs: [String]

    /// Current arbitration stage per typed classifier。
    public let stage: BASArbitrationStage

    /// Typed arbitration policy code (caller-defined
    /// taxonomy)。
    public let arbitrationPolicy: String

    /// Optional verdict hint emitted at stage = .converged。
    /// Nil when stage is not .converged。
    public let verdictHint: String?

    /// Millis since epoch when the arbitration was
    /// observed / emitted。
    public let arbitratedAtMs: Int64

    /// Typed body payload。
    public let body: Body

    /// Ordered diagnostic codes in caller-defined
    /// taxonomy。
    public let diagnostics: [String]

    public init(
        arbitrationID: String,
        schemaVersion: String,
        arbiterRefs: [String],
        disputedClaimRefs: [String],
        stage: BASArbitrationStage,
        arbitrationPolicy: String,
        verdictHint: String? = nil,
        arbitratedAtMs: Int64,
        body: Body,
        diagnostics: [String] = []
    ) {
        precondition(!arbiterRefs.isEmpty,
            "BASArbitrationObservationFrame arbiterRefs" +
            " MUST be non-empty (no anonymous" +
            " arbitrations per ADR-019 arbitration-" +
            "doctrine pin)")
        precondition(!disputedClaimRefs.isEmpty,
            "BASArbitrationObservationFrame disputed" +
            "ClaimRefs MUST be non-empty (no empty" +
            " arbitrations per ADR-019 pin)")
        self.arbitrationID = arbitrationID
        self.schemaVersion = schemaVersion
        self.arbiterRefs = arbiterRefs
        self.disputedClaimRefs = disputedClaimRefs
        self.stage = stage
        self.arbitrationPolicy = arbitrationPolicy
        self.verdictHint = verdictHint
        self.arbitratedAtMs = arbitratedAtMs
        self.body = body
        self.diagnostics = diagnostics
    }

    // MARK: - Derived queries

    /// `true` when stage is `.converged` AND
    /// verdictHint is populated。 L14 audit walkers
    /// consume this for "did the tribunal reach a
    /// verdict?" rollups。
    public var hasReachedVerdict: Bool {
        stage == .converged && verdictHint != nil
    }

    /// `true` when stage is `.escalated`。 Sovereign
    /// layer (L14) consumes this for escalation routing。
    public var requiresSovereignEscalation: Bool {
        stage == .escalated
    }

    /// Distinct arbiters participating (dedups raw refs)。
    public var distinctArbiterCount: Int {
        Set(arbiterRefs).count
    }
}
