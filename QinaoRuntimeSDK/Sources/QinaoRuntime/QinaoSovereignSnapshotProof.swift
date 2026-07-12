// integration S3 (2026-07-12, audit F2 discharge) — snapshot-continuity-proof issuance.
//
// Pre-S3 the proof type had NO production issuance path anywhere (every construction was
// a test's hand-built struct), and `execute()` validated only `intentDigest` — expiry,
// sessionID and signature were unchecked. This extension gives the control plane the
// mint + verify pair, keyed by the same `tokenTagKey` that signs warrants. It lives in
// the QinaoRuntime module because the proof type belongs to `QinaoRuntime`; `package`
// visibility on `tokenTagKey`/`tokenTag` lets the extension reach the key without
// widening any public surface.

import Foundation
import QinaoSovereign

extension QinaoSovereignControlPlane {

    /// Mint a signed snapshot-continuity proof for one intent. TTL mirrors the warrant's
    /// short-lived design (default 30s) so a leaked proof can't be replayed much later.
    public func issueSnapshotContinuityProof(
        for intent: Intent,
        anchorID: String,
        ttlSeconds: TimeInterval = 30
    ) -> QinaoRuntime.SnapshotContinuityProof {
        let issuedAt = now()
        let proofID = "proof-\(UUID().uuidString)"
        let expiresAt = issuedAt.addingTimeInterval(ttlSeconds)
        let signature = Self.tokenTag(
            key: tokenTagKey,
            fields: [
                proofID, intent.sessionID, anchorID, intent.digest,
                Self.tagDate(issuedAt), Self.tagDate(expiresAt),
            ])
        return QinaoRuntime.SnapshotContinuityProof(
            proofID: proofID,
            sessionID: intent.sessionID,
            anchorID: anchorID,
            intentDigest: intent.digest,
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            signature: signature)
    }

    /// Verify a proof: signature FIRST (fail closed on any non-minted proof), then
    /// session + digest binding, then expiry — the checks the pre-S3 gate was missing.
    public func isSnapshotProofValid(
        _ proof: QinaoRuntime.SnapshotContinuityProof,
        for intent: Intent
    ) -> Bool {
        let expected = Self.tokenTag(
            key: tokenTagKey,
            fields: [
                proof.proofID, proof.sessionID, proof.anchorID, proof.intentDigest,
                Self.tagDate(proof.issuedAt), Self.tagDate(proof.expiresAt),
            ])
        guard proof.signature == expected else { return false }
        guard proof.sessionID == intent.sessionID else { return false }
        guard proof.intentDigest == intent.digest else { return false }
        guard proof.expiresAt > now() else { return false }
        return true
    }
}
