// MARK: - BASBrainHistoryAtomID
// 主线 全面 提升 / 解构: single source of truth for the
// SHA256-prefix atomID algorithm shared by the SQL +
// Rust brain history stores。
//
// **Why this exists**: before this commit,
// BASSQLBrainHistoryStore.atomID(forInput:) and
// BASRustBrainHistoryStore.atomID(forInput:) had
// byte-identical Swift implementations。 The hash had to
// stay identical across both stores so hosts using both
// pilots could cross-join records on atomID。 Two copies
// of the same code is a drift hazard — one copy gets
// optimized,the other doesn't,and cross-store joins
// silently break。
//
// This commit pulls the algorithm into one canonical
// function。 Both stores delegate here。 Anti-drift tests
// pin "both stores produce identical atomIDs for identical
// inputs"。
//
// **What the algorithm is**: SHA256(input UTF-8 bytes) →
// first 8 bytes → 16 hex chars (lowercase)。 16-char
// length is "long enough that birthday-collisions are
// negligible in a session" but "short enough that the
// atom_id column stays compact in SQLite + Rust"。

import Foundation
import CryptoKit

/// Canonical SHA256-prefix atomID derivation。 Returns 16
/// lowercase hex characters representing the first 8
/// bytes of SHA256(input UTF-8)。
///
/// Used by:
///   - `BASSQLBrainHistoryStore.atomID(forInput:)`
///   - `BASRustBrainHistoryStore.atomID(forInput:)`
///
/// Both stores delegate here so cross-store joins (e.g.
/// "what does the SQL pilot say about the same atom_id
/// the Rust pilot recorded?") remain byte-equal。
public enum BASBrainHistoryAtomID {

    /// Hex character count emitted。 16 chars = 8 bytes =
    /// first 64 bits of SHA256。 Birthday-collision
    /// probability at 1B-record corpus is ~10^-9。
    public static let hexCharCount: Int = 16

    /// Derive the 16-char hex atomID for an input string。
    public static func derive(forInput input: String)
        -> String
    {
        let digest = SHA256.hash(
            data: Data(input.utf8))
        var hex = ""
        hex.reserveCapacity(hexCharCount)
        let bytesToEmit = hexCharCount / 2
        var emitted = 0
        for byte in digest {
            hex += String(
                format: "%02x", byte)
            emitted += 1
            if emitted >= bytesToEmit { break }
        }
        return hex
    }
}
