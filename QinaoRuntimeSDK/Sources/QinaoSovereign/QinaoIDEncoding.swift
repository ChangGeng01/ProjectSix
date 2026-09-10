import Foundation

/// M165 — single source of truth for percent-escaping in Qinao
/// internal identifier paths.
///
/// Pre-M165 there were two helpers in two namespaces with two
/// reserved-character sets:
///
///   - M163 `syntheticRef` escaped `%` and `.` for visible audit
///     refs ("frame.<sess>.<turn>"-style strings).
///   - M164 `compoundTurnKey` escaped `%` and `|` for internal
///     storage keys ("<sess>|<turn>"-style strings).
///
/// Both functions lived as public/private statics on
/// `QinaoSovereignControlPlane`, an actor with no isolation need
/// for pure value transforms. The duplication was a NIH long-term
/// debt: a future refactor that "unifies encoding" could silently
/// break one of the two namespaces.
///
/// M165 collapses the two into one parameterized helper that
/// always escapes `%` first (so `%XX` payloads round-trip), then
/// escapes whichever extra reserved character the caller named.
/// The helpers live in this dedicated file so they can be reused
/// by any Qinao module without going through the actor and so
/// that the file stays well under the 800-line house limit.
public enum QinaoIDEncoding {

    /// M165 — namespaces with their reserved characters fixed in
    /// one place. Every existing escape site picks a namespace
    /// and the encoding falls out automatically.
    public enum Namespace: Sendable {
        /// Visible synthetic ref segments (M163). Reserved: `.`
        /// (the segment separator).
        case syntheticRef
        /// Internal compound key segments (M164). Reserved: `|`
        /// (the segment separator).
        case compoundKey
    }

    /// M165 — percent-escape `value` for the given `namespace`.
    /// Order: `%` → `%25` first, then the namespace's reserved
    /// character → its percent-encoded form. Order matters so a
    /// literal `%2E` payload doesn't get double-encoded into
    /// `%25 + 2E`.
    public static func escape(
        _ value: String, for namespace: Namespace
    ) -> String {
        let escaped =
            value.replacingOccurrences(of: "%", with: "%25")
        switch namespace {
        case .syntheticRef:
            return escaped
                .replacingOccurrences(of: ".", with: "%2E")
        case .compoundKey:
            return escaped
                .replacingOccurrences(of: "|", with: "%7C")
        }
    }

    /// M165 — inverse of `escape`. Order matters: decode the
    /// reserved character first so a literal `%XX` payload does
    /// not get double-decoded.
    public static func unescape(
        _ value: String, for namespace: Namespace
    ) -> String {
        let intermediate: String
        switch namespace {
        case .syntheticRef:
            intermediate = value
                .replacingOccurrences(of: "%2E", with: ".")
        case .compoundKey:
            intermediate = value
                .replacingOccurrences(of: "%7C", with: "|")
        }
        return intermediate
            .replacingOccurrences(of: "%25", with: "%")
    }

    /// M163 + M165 — assemble a deterministic synthetic ref from
    /// a fixed prefix and a (sessionID, turnID) pair. The dot
    /// (`.`) is the segment separator; ID dots become `%2E` so
    /// `(sess.A, B)` and `(sess, A.B)` produce distinct refs.
    public static func syntheticRef(
        prefix: String,
        sessionID: String,
        turnID: String
    ) -> String {
        prefix + "."
            + escape(sessionID, for: .syntheticRef)
            + "."
            + escape(turnID, for: .syntheticRef)
    }

    /// M164 + M165 — assemble a deterministic compound storage
    /// key. The pipe (`|`) is the segment separator; ID pipes
    /// become `%7C`.
    public static func compoundTurnKey(
        sessionID: String, turnID: String
    ) -> String {
        escape(sessionID, for: .compoundKey)
            + "|"
            + escape(turnID, for: .compoundKey)
    }
}
