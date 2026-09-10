import Foundation

// M296.2.x — high-consequence intent gate (uses M296.2 dual-key
// commit primitive).
//
// ## Why this exists
//
// M296.2 ships the cryptographic dual-key commit primitive
// (`BASSovereignDualKeyCommit` + `BASSovereignDualKeyVerifier`),
// but doesn't say *when* an action should require dual-key
// signing. Most sovereign actions (routine verdict / typical
// permit issuance / standard audit append) work fine with single-
// key signing — requiring dual-key on every action would be heavy
// and miss the doctrinal point. **High-consequence** actions
// (delete a host version / change sovereign policy / acknowledge
// cross-device sentinel override) are where single-key compromise
// shouldn't equal capitulation.
//
// `BASSovereignHighConsequenceGate` is the typed seam between
// "is this intent high-consequence?" and "is the dual-key commit
// valid?" One verifier per gate; one classification call per
// intent. Returns Bool — engines that integrate this branch on
// the result.
//
// ## Properties
//
// - **Routine intents always pass.** No commit required, no
//   verification overhead.
// - **High-consequence intents require both:**
//   - a non-nil `BASSovereignDualKeyCommit`
//   - whose `intentDigest` matches the caller-supplied
//     `intentDigest`
//   - whose two signatures both validate under the gate's
//     verifier
//   Any miss → false.
// - **Doesn't classify intents itself.** Caller decides which
//   intents are high-consequence; gate only enforces the rule
//   *given* that classification. This keeps the rule local and
//   auditable.
// - **Doesn't throw.** Verification failure returns false.
//   Callers branch on Bool. Same doctrine as
//   `BASSovereignDualKeyVerifier.verify(_:)`.

public enum BASSovereignIntentClass:
    String, Sendable, Equatable, Hashable, Codable, CaseIterable
{
    /// Routine sovereign action — single-key signing is enough.
    case routine
    /// High-consequence — dual-key commit required.
    case highConsequence
}

public struct BASSovereignHighConsequenceGate: Sendable {

    public let verifier: BASSovereignDualKeyVerifier

    public init(verifier: BASSovereignDualKeyVerifier) {
        self.verifier = verifier
    }

    /// Authorize an intent. Returns true if the intent passes the
    /// gate's policy: routine intents always pass; high-consequence
    /// intents require a valid dual-key commit whose digest matches
    /// `intentDigest` and whose signatures both verify under the
    /// gate's verifier.
    ///
    /// - Parameters:
    ///   - intentClass: caller-supplied classification.
    ///   - intentDigest: digest the dual-key commit must cover
    ///     for high-consequence intents. Ignored for routine.
    ///   - commit: dual-key commit. Required for high-consequence
    ///     intents (nil → false). Ignored for routine.
    public func authorize(
        intentClass: BASSovereignIntentClass,
        intentDigest: Data,
        commit: BASSovereignDualKeyCommit?
    ) -> Bool {
        switch intentClass {
        case .routine:
            return true
        case .highConsequence:
            guard let commit else { return false }
            guard commit.intentDigest == intentDigest else {
                return false
            }
            return verifier.verify(commit)
        }
    }
}
