import Foundation

/// Shared constants for the L14 sovereign microkernel.
///
/// Centralising these values here keeps every submodule (ledger, token
/// authority, verdict engine, lock manager, etc.) consistent about what
/// counts as "the current policy" and "the current signing key namespace."
///
/// Design note: nothing in this file is user-tunable at runtime. L14 is
/// intentionally insulated from prompt content, host preference, and L2/L3
/// model output. Policy rotations happen out-of-band.
public enum BASSovereignTrustConstants {
    /// Identifier of the rule bundle the current executable was built against.
    /// Emitted into every verdict and audit entry so replay/governance can
    /// verify that the decision logic hasn't been swapped silently.
    public static let builtInPolicyHash = "sovereign.policy.v1.0.0"

    /// Signing key namespace. A real deployment rotates keys through a key
    /// authority; this identifier lets the audit ledger reject entries whose
    /// signature came from a namespace other than the one the reader trusts.
    public static let signingNamespace = "sovereign.keyring.v1"

    /// Default TTL window for a freshly-issued sovereign commit token.
    /// Callers can override per-intent but the default is intentionally
    /// short so unused tokens self-evaporate.
    public static let defaultCommitTokenTTLMs = 30_000
}
