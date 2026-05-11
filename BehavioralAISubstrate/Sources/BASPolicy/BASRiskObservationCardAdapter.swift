// MARK: - BASRiskObservationCardAdapter
// chapter 五百九 / M1413 — typed pure-function adapter
// from existing BASRiskObservation (BASPolicy) to the
// chapter 507 M1407 BASRiskObservationCard<Kind, Body>
// Tier C primitive
//
// Maps the existing 6-field BASRiskObservation onto the
// 7-field BASRiskObservationCard:
//
//   BASRiskObservation field   → BASRiskObservationCard field
//   ─────────────────────────    ────────────────────────────
//   kind: BASRiskSignalKind     → kind: BASRiskSignalKind
//   intentID + observedAt       → riskID (composite stable ID)
//   content                     → body.content
//   intentID                    → body.intentID
//   salience                    → severityScore (clamped)
//   confidence                  → confidenceFloor (clamped)
//   (n/a)                       → reasonCodes ([] default)
//   observedAt                  → observedAtMs (Date → ms)
//
// HONEST SCOPE — chapter 五百九:
// =============================================================
// Pure-function adapter — does NOT modify existing
// BASRiskObservation。 ADR-014 OPT-IN preserved。 V1
// byte-equality untouched (adapter is opt-in only)。
// Hosts that don't need the Tier C card form continue
// to use the original BASRiskObservation directly。

import Foundation
import BASRuntimeCore

/// Typed body for the Tier C-card form of
/// BASRiskObservation。 Carries the 2 string fields not
/// otherwise captured by the card's metadata。
public struct BASRiskObservationCardBody:
    Equatable, Hashable, Codable, Sendable
{
    public let intentID: String
    public let content: String

    public init(intentID: String, content: String) {
        self.intentID = intentID
        self.content = content
    }
}

/// Typed pure-function adapter producing the Tier C-card
/// form of an existing BASRiskObservation。 Migration
/// surface per ADR-019 approved chapter 507。
public enum BASRiskObservationCardAdapter {

    /// Convert a single BASRiskObservation into a typed
    /// BASRiskObservationCard。 riskID is composed as
    /// "<intentID>@<observed-millis>" providing a stable
    /// per-observation identifier。
    public static func card(
        from observation: BASRiskObservation,
        schemaVersion: String = "1.0.0"
    ) -> BASRiskObservationCard<
        BASRiskSignalKind, BASRiskObservationCardBody>
    {
        let body = BASRiskObservationCardBody(
            intentID: observation.intentID,
            content: observation.content)
        let observedAtMs = Int64(
            observation.observedAt.timeIntervalSince1970
            * 1000.0)
        let riskID = "\(observation.intentID)" +
            "@\(observedAtMs)"
        return BASRiskObservationCard(
            riskID: riskID,
            schemaVersion: schemaVersion,
            kind: observation.kind,
            body: body,
            severityScore: observation.salience,
            confidenceFloor: observation.confidence,
            reasonCodes: [],
            observedAtMs: observedAtMs)
    }

    /// Convert a full bundle of N risk observations into
    /// an array of N typed cards。 Preserves emission
    /// order per chapter 三百九二 replay-determinism
    /// contract。
    public static func cards(
        from bundle: BASRiskObservationBundle,
        schemaVersion: String = "1.0.0"
    ) -> [BASRiskObservationCard<
        BASRiskSignalKind, BASRiskObservationCardBody>]
    {
        return bundle.observations.map {
            card(from: $0, schemaVersion: schemaVersion)
        }
    }
}
