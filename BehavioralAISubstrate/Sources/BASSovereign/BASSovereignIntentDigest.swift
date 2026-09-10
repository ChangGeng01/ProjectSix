import Foundation
import CryptoKit

// M296.2.z — canonical intent-digest helpers for dual-key signing.
//
// ## Why this exists
//
// `BASSovereignDualKeyCommit` (M296.2) takes an `intentDigest:
// Data` and signs it with two keys. But what *is* the intent
// digest? Two callers signing the same logical intent must produce
// byte-identical digests; otherwise dual-key verification fails
// for spurious reasons. M296.2.z ships the canonical helpers:
//
// - `compute(payload:)` — bare SHA-256 of any data payload
// - `compute(intentName:payload:)` — name-bound digest. Two intents
//   with the same payload but different intent names produce
//   different digests, preventing replay across intent kinds (a
//   "delete-host-version" payload signed for the wrong action
//   wouldn't validate even if the bytes happened to match).
//
// ## Properties
//
// - **Stable canonical form.** `compute(intentName:payload:)`
//   concatenates `<intentName-bytes><0x00 separator><payload>`
//   then SHA-256s the result. The 0x00 separator makes name and
//   payload boundaries unambiguous (you can't construct a name
//   that, combined with a different payload, would produce the
//   same concatenated bytes).
// - **Deterministic.** Same inputs → same digest, every time.
//   Pure function, no entropy.
// - **No allocation surprises.** Helpers return `Data` of fixed
//   size (32 bytes for SHA-256).

public enum BASSovereignIntentDigest {

    /// Bare SHA-256 over the payload. Suitable when the caller
    /// wants direct control over what bytes get signed.
    public static func compute(payload: Data) -> Data {
        Data(SHA256.hash(data: payload))
    }

    /// SHA-256 over a UTF-8 string payload.
    public static func compute(payload: String) -> Data {
        compute(payload: Data(payload.utf8))
    }

    /// Name-bound canonical digest. Concatenates
    /// `<intentName-utf8><0x00><payload>` then SHA-256s.
    /// Two intents with the same payload but different names
    /// produce different digests — this defeats replay across
    /// intent kinds.
    public static func compute(
        intentName: String,
        payload: Data
    ) -> Data {
        var combined = Data(intentName.utf8)
        combined.append(0x00) // unambiguous separator
        combined.append(payload)
        return Data(SHA256.hash(data: combined))
    }

    /// Convenience: name-bound canonical digest from a UTF-8
    /// string payload.
    public static func compute(
        intentName: String,
        payload: String
    ) -> Data {
        compute(
            intentName: intentName,
            payload: Data(payload.utf8))
    }
}
