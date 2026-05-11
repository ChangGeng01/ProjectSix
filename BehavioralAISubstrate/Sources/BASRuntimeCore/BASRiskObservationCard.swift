// MARK: - BASRiskObservationCard
// chapter 五百七 / M1407 — 2nd Tier C shape-specific
// generic primitive per ADR-019 (approved M1405)
//
// HONEST naming note:proposal called this "BASRiskCard"
// but that name is already taken by a concrete L11
// risk-plane struct in BASPolicy。 Renamed at chapter
// 507 to BASRiskObservationCard<Kind, Body> matching
// the original BASRiskObservationBundle migration
// target name。
//
// Two-parameter shape (Kind + Body) targeting the
// "risk observation aggregate":
//   - riskID (stable identifier)
//   - kind:Kind (typed risk classifier)
//   - body:Body (generic risk observation payload)
//   - severityScore (clamped to [0, 1])
//   - confidenceFloor (clamped to [0, 1])
//   - reasonCodes ([String] in arrival order)
//   - observedAtMs (Int64)
//
// HONEST SCOPE — chapter 五百七:
// =============================================================
// 2nd Tier C primitive。 Pure-additive — existing
// BASRiskObservationBundle migration is follow-up arc。
// V1 byte-equality preserved。 ADR-014 OPT-IN preserved。

import Foundation

/// Generic risk-observation card per ADR-019 approved
/// chapter 五百七 M1405。
public struct BASRiskObservationCard<Kind, Body>:
    Equatable, Hashable, Codable, Sendable
where
    Kind: Equatable & Hashable & Codable & Sendable,
    Body: Equatable & Hashable & Codable & Sendable
{

    /// Stable identifier for this risk observation。
    public let riskID: String

    /// Schema version pin for replay-determinism。
    public let schemaVersion: String

    /// Typed risk classifier (caller-defined enum)。
    public let kind: Kind

    /// Typed body payload。
    public let body: Body

    /// Severity score in [0, 1]。 1.0 = maximum
    /// severity;0.0 = no concern。 Out-of-range values
    /// are clamped at construction time per L11 risk-
    /// plane invariant。
    public let severityScore: Double

    /// Confidence floor in [0, 1]。 1.0 = fully
    /// confident in the observation;0.0 = no confidence
    /// (observation should not influence permits)。
    public let confidenceFloor: Double

    /// Ordered reason codes in caller-defined taxonomy。
    public let reasonCodes: [String]

    /// Millis since epoch when the risk was observed。
    public let observedAtMs: Int64

    public init(
        riskID: String,
        schemaVersion: String,
        kind: Kind,
        body: Body,
        severityScore: Double,
        confidenceFloor: Double,
        reasonCodes: [String] = [],
        observedAtMs: Int64
    ) {
        self.riskID = riskID
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.body = body
        // Clamp severity + confidence per L11 risk-
        // plane invariant
        self.severityScore = max(0.0,
            min(1.0, severityScore))
        self.confidenceFloor = max(0.0,
            min(1.0, confidenceFloor))
        self.reasonCodes = reasonCodes
        self.observedAtMs = observedAtMs
    }

    // MARK: - Derived queries

    /// `true` when severity is at or above the typed
    /// `actionRequiredThreshold` (default 0.7 per L11
    /// risk-plane doctrine)。
    public func requiresAction(
        actionRequiredThreshold: Double = 0.7
    ) -> Bool {
        severityScore >= actionRequiredThreshold
    }

    /// `true` when confidenceFloor is at or above the
    /// minimum-trust threshold (default 0.5)。
    public func isTrustworthy(
        minTrust: Double = 0.5
    ) -> Bool {
        confidenceFloor >= minTrust
    }

    /// Effective weighted risk = severity × confidence。
    /// L11 risk-plane uses this when composing multiple
    /// risk observations。 In [0, 1] by construction
    /// (both factors clamped)。
    public var effectiveWeightedRisk: Double {
        severityScore * confidenceFloor
    }
}
