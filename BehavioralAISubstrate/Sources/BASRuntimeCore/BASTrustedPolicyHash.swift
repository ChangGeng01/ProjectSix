import Foundation
import CryptoKit

// MARK: - BASTrustedPolicyHash — the canonical policy-hash recipe (single source of truth)
//
// Comprehensive-audit fix (MEDIUM): the commit gate previously sourced its `expectedPolicyHash` FROM the token
// (`token.policyHash`), making the policy-rotation check tautological (token verified against itself). The fix
// is a host-owned `BASTrustedPolicyHashProvider` that recomputes the trusted hash INDEPENDENTLY from the
// canonical active host policy bundle and compares it to the token/warrant `policyHash`.
//
// For that comparison to admit a LEGITIMATE token, the provider must hash the SAME bytes the token-minting path
// (`sovereignPolicyHash`) hashes. `BASTrustedPolicyHash.compute` is that single shared recipe — used by BOTH
// the minting path (for a present lineage) and the provider — so the two can never drift.

public enum BASTrustedPolicyHash {

    /// SHA256 over the INJECTIVE length-prefixed encoding of the 4 policy-lineage identity fields, lowercase
    /// hex. Byte-identical to `sovereignPolicyHash(for:)` for a present lineage (same fields, same order, same
    /// `lengthPrefixed` + SHA256 + `bytesToHexLower` primitives).
    public static func compute(lineage: BASRuntimePolicyLineage) -> String {
        let components = [
            lineage.bundleVersion,
            lineage.providerRoutingPolicyID,
            lineage.runtimeTuningPolicyID,
            lineage.resolutionSourceID,
        ]
        let digest = SHA256.hash(data: BASSovereignCanonicalBytes.lengthPrefixed(components))
        return BASAutoRouteRanker.bytesToHexLower(Array(digest))
    }
}

/// Why a trusted-policy-hash recompute failed. The commit gate must FAIL CLOSED on any of these (reject the
/// irreversible op) — never fall back to the token-carried hash.
public enum BASTrustedPolicyHashError: Error, Equatable, Sendable {
    case missingRuntimePolicyLineage
    case malformedRuntimePolicyLineage(field: String)
}

/// HOST-OWNED source of the trusted policy hash. The commit gate calls this to obtain the expected `policyHash`
/// INDEPENDENTLY of the token/warrant. Per doctrine the trusted hash is derived from the canonical active host
/// policy bundle (`runtimePolicyLineage` + the resolved runtime-tuning / policy-registry identity); it is NEVER
/// taken from the token-carried hash, the agent fabric, proposals, or the event log. A production provider MUST
/// throw (fail-closed) when the host policy lineage is absent or malformed.
public protocol BASTrustedPolicyHashProvider: Sendable {
    func trustedPolicyHash() throws -> String
}
