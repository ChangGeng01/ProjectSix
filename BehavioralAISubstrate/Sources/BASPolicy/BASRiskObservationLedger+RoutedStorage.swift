// MARK: - BASRiskObservationLedger+RoutedStorage
// chapter 七百五十四 第一刀 / M2435
//
// MATURATION ARC L11 production swap — wires the SQL persistence
// layer (chapter 七百三十八 schema + chapter 七百五十一 第三刀 storage
// actor) into the production BASRiskObservationLedger ring actor。
//
// ## What this fixes
//
// Pre-this-knife state:
//   - Chapter 七百三十八 第一刀 landed 006_risk_observations.sql
//     schema unconditionally。
//   - Chapter 七百五十一 第三刀 landed BASRiskObservationsSQLiteStorage
//     Swift actor with persistObservation/loadObservations/COUNT。
//   - BUT:no production code constructed the storage actor and
//     wired it to BASRiskObservationLedger。 The schema lived in
//     the codebase + the storage actor was tested-only。
//
// This knife closes that gap:
//   - Adds `sharedStorage` static slot for caller-supplied storage。
//   - Adds `loadFromSharedStorage(sessionID:)` for cold-restart
//     replay of prior observations into the ring buffer。
//   - Adds `persistToSharedStorage(_:)` for live persistence on
//     every record() call。
//   - Provides marshalling helpers that derive risk_band from
//     score (per chapter 七百三十八 schema CHECK constraint)
//     and derive a stable event_id from observation fields。
//
// ## User directive alignment
//
// 「SQL 不要只做 schema,继续接入真实持久化和 replay」 2026-05-20
//   — chapter 七百五十一 第三刀 wired storage at a TEST seam;
//   THIS knife wires it at the PRODUCTION seam (ledger actor)。
//
// ## ADR-014 OPT-IN preserved
//
// Default constructor (no storage set) preserves chapter 七百三十八
// pre-this-knife behavior — in-memory ring only。 Hosts opt-IN by
// setting `BASRiskObservationLedger.sharedStorage` before
// constructing the ledger actor。 No existing call sites break。

import Foundation

extension BASRiskObservationLedger {

    /// Optional SQLite-backed storage for cross-process persistence。
    /// audit policy-obs-misc MED-2 (comment-lie corrected): this does NOT auto-mirror on every
    /// record() call — `record()` never calls `persistToSharedStorage`, and no in-repo caller does
    /// either (the "production seam" is host-driven, not wired). Hosts that want cold-restart replay
    /// must call `persistToSharedStorage(_:)` EXPLICITLY per bundle. Auto-wiring record() is
    /// deliberately NOT done: `loadFromSharedStorage` seeds the ring by calling `record()`, so an
    /// auto-persist would RE-persist every loaded bundle on cold start. nil = ring-only (the
    /// pre-chapter-七百五十四 default behavior)。
    ///
    /// nonisolated(unsafe) because the storage instance is host-
    /// supplied at startup before the actor is constructed;all
    /// reads/writes go through the actor's isolated boundary。
    public nonisolated(unsafe) static var sharedStorage:
        BASRiskObservationsSQLiteStorage? = nil

    // MARK: - Cold-restart load

    /// Load prior observations from shared storage and seed the
    /// ring buffer。 Idempotent — calling on an empty store is
    /// a no-op。 Storage errors are observability-grade and do
    /// not propagate (in-memory ring stays functional)。
    public func loadFromSharedStorage(
        sessionID: String
    ) {
        guard let storage = Self.sharedStorage else { return }
        guard let records = try? storage.loadObservations(
            sessionID: sessionID) else { return }
        let bundles = Self.bucketObservationsIntoBundles(
            records)
        for bundle in bundles {
            self.record(bundle)
        }
    }

    // MARK: - Live persist

    /// Persist a bundle's observations to shared storage if
    /// available。 Per-observation persist failures are
    /// observability-grade — the in-memory ring stays the
    /// source of truth for the current process。
    public func persistToSharedStorage(
        _ bundle: BASRiskObservationBundle
    ) {
        guard let storage = Self.sharedStorage else { return }
        for record in Self.observationsToRecords(
            bundle: bundle)
        {
            try? storage.persistObservation(record)
        }
    }

    // MARK: - Marshalling

    /// Convert all observations in a bundle to flat SQL rows
    /// per chapter 七百三十八 schema。
    public static func observationsToRecords(
        bundle: BASRiskObservationBundle
    ) -> [BASRiskObservationRecord] {
        // audit policy-obs-misc MED-2: thread each observation's ordinal within the bundle into
        // its event_id, so two observations minted in the SAME millisecond (same intent+kind) do
        // NOT collide → the INSERT's ON CONFLICT DO NOTHING no longer silently drops the second.
        // Deterministic per bundle order (idempotent re-persist of the same bundle).
        return bundle.observations.enumerated().map { (ordinal, obs) in
            toStorageRecord(
                observation: obs, bundle: bundle, ordinal: ordinal)
        }
    }

    /// One BASRiskObservation + bundle context → SQL row。
    /// Derives:
    ///   - event_id from (session,turn,intent,kind,observedAt-ms)
    ///   - risk_band from score per chapter 七百三十八 schema
    ///     CHECK constraint (low/medium/high/critical)
    ///   - risk_score = salience × confidence (host's combined
    ///     attention signal,bounded [0,1])
    public static func toStorageRecord(
        observation: BASRiskObservation,
        bundle: BASRiskObservationBundle,
        ordinal: Int = 0
    ) -> BASRiskObservationRecord {
        let observedAtMs = Int64(
            observation.observedAt.timeIntervalSince1970 * 1000)
        let score = observation.salience * observation.confidence
        let band = deriveBand(score: score)
        let eventID = deriveEventID(
            sessionID: bundle.sessionID,
            turnID: bundle.turnID,
            intentID: observation.intentID,
            kindRaw: observation.kind.rawValue,
            observedAtMs: observedAtMs,
            ordinal: ordinal)
        let payloadJSON: String?
        if observation.content.isEmpty {
            payloadJSON = nil
        } else {
            payloadJSON = observation.content
        }
        return BASRiskObservationRecord(
            eventID: eventID,
            sessionID: bundle.sessionID,
            turnID: bundle.turnID,
            intentID: observation.intentID,
            observedAtMs: observedAtMs,
            riskBand: band,
            riskScore: score,
            observationKind: observation.kind.rawValue,
            salience: observation.salience,
            confidence: observation.confidence,
            payloadJSON: payloadJSON)
    }

    /// Derive a stable opaque event_id from observation fields。
    /// Same (session,turn,intent,kind,observedAt,ordinal) → same
    /// event_id deterministically (replay-friendly)。
    /// audit policy-obs-misc MED-2: `ordinal` (the observation's position within its bundle)
    /// disambiguates two observations that share (intent,kind,observedAtMs) — without it they
    /// collided and the INSERT's ON CONFLICT DO NOTHING silently dropped the second.
    public static func deriveEventID(
        sessionID: String,
        turnID: String,
        intentID: String,
        kindRaw: String,
        observedAtMs: Int64,
        ordinal: Int = 0
    ) -> String {
        return "obs-\(sessionID)-\(turnID)" +
            "-\(intentID)-\(kindRaw)-\(observedAtMs)-\(ordinal)"
    }

    /// Map score → risk_band per chapter 七百三十八 schema
    /// CHECK constraint。 Same band rule used by the existing
    /// L11 BASRiskCalibrationGate so substrate stays consistent。
    public static func deriveBand(
        score: Double
    ) -> String {
        if score >= 0.85 { return "critical" }
        if score >= 0.70 { return "high"     }
        if score >= 0.40 { return "medium"   }
        return "low"
    }

    // MARK: - Bucket records back into bundles for replay

    /// Bucket flat SQL rows back into bundles by turnID。 The
    /// SQL SELECT already orders by observed_at_ms ASC so the
    /// bundle's observations come out in their original order。
    public static func bucketObservationsIntoBundles(
        _ records: [BASRiskObservationRecord]
    ) -> [BASRiskObservationBundle] {
        var byTurn:
            [String: [BASRiskObservationRecord]] = [:]
        var turnOrder: [String] = []
        for r in records {
            if byTurn[r.turnID] == nil {
                turnOrder.append(r.turnID)
            }
            byTurn[r.turnID, default: []].append(r)
        }

        var bundles: [BASRiskObservationBundle] = []
        for turnID in turnOrder {
            guard let group = byTurn[turnID],
                  let first = group.first
            else { continue }

            let observations: [BASRiskObservation] =
                group.compactMap { rec in
                    guard let kind = BASRiskSignalKind(
                        rawValue: rec.observationKind)
                    else { return nil }
                    let observedAt = Date(
                        timeIntervalSince1970:
                            Double(rec.observedAtMs) / 1000.0)
                    return BASRiskObservation(
                        kind: kind,
                        intentID: rec.intentID,
                        salience: rec.salience,
                        confidence: rec.confidence,
                        content: rec.payloadJSON ?? "",
                        observedAt: observedAt)
                }
            let emittedAt = Date(
                timeIntervalSince1970:
                    Double(first.observedAtMs) / 1000.0)
            bundles.append(BASRiskObservationBundle(
                turnID: turnID,
                sessionID: first.sessionID,
                observations: observations,
                emittedAt: emittedAt))
        }
        return bundles
    }
}
