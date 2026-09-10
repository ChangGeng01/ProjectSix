// ch1044 A1 — the canonical sovereign action-digest, as a single source of truth.
//
// `makeCommitToken` computes a commit token's `actionDigest` from the action's content
// parts + turn identity. For a verifier to enforce "the host executes EXACTLY what the
// brain authorized", it must INDEPENDENTLY recompute this digest from the
// actually-approved artifact and compare it to the token's `actionDigest` — never read
// the digest off the token. Extracting the computation here gives both the minter and
// the verifier ONE implementation, so they can't drift.

import Foundation
import CryptoKit

public enum BASSovereignActionDigest {

    /// The canonical action-digest: SHA256 over the INJECTIVE length-prefixed encoding
    /// of `actionDigestParts + [sessionID, turnID, scope, snapshotRef, policyHash]`,
    /// lowercase hex. (Length-prefixed so an in-band separator in a part — e.g. a
    /// rendered headline/body — cannot shift a boundary and alias two distinct actions.)
    public static func compute(
        scope: BASSovereignCommitScope,
        actionDigestParts: [String],
        sessionID: String,
        turnID: String,
        snapshotRef: String,
        policyHash: String
    ) -> String {
        let components = actionDigestParts
            + [sessionID, turnID, scope.rawValue, snapshotRef, policyHash]
        let digest = SHA256.hash(
            data: BASSovereignCanonicalBytes.lengthPrefixed(components))
        return BASAutoRouteRanker.bytesToHexLower(Array(digest))
    }
}
