// ch1044 audit fix (CRITICAL) — injective canonical byte encoding for signing.
//
// A delimiter-JOIN canonical form (e.g. `fields.joined(separator: "\u{1F}")` or
// `allowedTargets.joined(separator: ",")`) is FORGEABLE: if a field value contains
// the separator, a different field sequence can produce identical bytes, so one
// signature validates for two distinct tokens (a scope-expansion forgery on
// `allowedTargets` was confirmed by the ch1044 adversarial audit).
//
// This length-prefixed (netstring-style) encoding is INJECTIVE by construction —
// each field is emitted as `<utf8ByteCount>:<utf8 bytes>`, so the verifier reads
// EXACTLY `count` bytes for each field and no value (even one containing `:`,
// `\u{1F}`, or `\u{1E}`) can shift a boundary. Distinct field sequences — including
// sequences of different arity — always produce distinct bytes. (Bernstein
// netstring, minus the trailing comma; injective ⟺ unambiguously decodable.)

import Foundation

public enum BASSovereignCanonicalBytes {

    /// Injective length-prefixed encoding of an ordered field sequence. Use this for
    /// ANY value that will be signed or hashed for authenticity — never a
    /// delimiter-join, which an in-band separator can forge.
    public static func lengthPrefixed(_ fields: [String]) -> Data {
        var out = Data()
        for field in fields {
            let bytes = Array(field.utf8)
            out.append(contentsOf: Array("\(bytes.count):".utf8))
            out.append(contentsOf: bytes)
        }
        return out
    }

    /// Convenience for a list field embedded in a larger sequence: a count marker
    /// followed by each element as its own length-prefixed field. The count guards
    /// arity and each element is individually delimited, so neither the element
    /// boundaries nor the list length can be shifted by an in-band separator.
    public static func list(_ elements: [String]) -> [String] {
        [String(elements.count)] + elements
    }
}
