import Foundation

// M296.2.y — typed `(intent + classification + digest + commit)`
// bundle for dual-key gating. Pairs M296.2 / M296.2.x / M296.2.z
// into a single Codable value any engine / runtime can adopt
// without re-deriving the call signature on each use.
//
// ## Why this exists
//
// `BASSovereignHighConsequenceGate.authorize(...)` (M296.2.x) takes
// four parameters: classification, digest, commit, the implicit
// verifier on the gate itself. Real engines and audit ledgers
// pass the same triple around together — `(intentName, digest,
// optional dual-key commit)`. M296.2.y bundles the triple as
// `BASSovereignGatedIntent` and ships a Validator that closes
// over the gate.
//
// This is the doctrinal seam between manifest v2 「极高后果操作必
// 须双钥」 and code that actually authors high-consequence intents:
// hosts construct a `GatedIntent`, the validator says yes/no.
//
// ## Properties
//
// - **Codable bundle.** Round-trips through any storage layer
//   without losing the dual-key linkage.
// - **Validator delegates to gate.** Same Bool-returning, no-throw
//   contract.
// - **Doesn't modify VerdictEngine.** The engine schema modifying
//   work (M296.2.yy+) is still on the roadmap; M296.2.y just
//   provides the typed shape engines plug in.

public struct BASSovereignGatedIntent:
    Sendable, Equatable, Hashable, Codable
{
    /// Stable name of the intent — what action the dual-key
    /// commit (if present) authorizes.
    public let intentName: String

    /// Classification — does this intent require dual-key?
    public let intentClass: BASSovereignIntentClass

    /// Digest the dual-key commit (if any) signed.
    public let intentDigest: Data

    /// Dual-key commit — required for `.highConsequence`,
    /// optional for `.routine`.
    public let dualKeyCommit: BASSovereignDualKeyCommit?

    public init(
        intentName: String,
        intentClass: BASSovereignIntentClass,
        intentDigest: Data,
        dualKeyCommit: BASSovereignDualKeyCommit?
    ) {
        self.intentName = intentName
        self.intentClass = intentClass
        self.intentDigest = intentDigest
        self.dualKeyCommit = dualKeyCommit
    }
}

public struct BASSovereignGatedIntentValidator: Sendable {
    public let gate: BASSovereignHighConsequenceGate

    public init(gate: BASSovereignHighConsequenceGate) {
        self.gate = gate
    }

    /// Authorize a typed gated intent. Delegates to the
    /// underlying gate; returns true if the intent passes,
    /// false otherwise (no throw).
    public func authorize(
        _ intent: BASSovereignGatedIntent
    ) -> Bool {
        gate.authorize(
            intentClass: intent.intentClass,
            intentDigest: intent.intentDigest,
            commit: intent.dualKeyCommit)
    }
}
