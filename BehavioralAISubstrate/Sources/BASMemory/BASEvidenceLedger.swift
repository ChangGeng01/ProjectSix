// MARK: - BASEvidenceLedger
// ADR-020 Arc-2 — latent plumbing for evidence-resolving deliberation.
//
// An immutable, append-only collection of `BASEvidenceAtom`。 The
// evidence-plane sibling of `BASMemoryBundle` (which collects
// `BASMemoryAtom`)。 The ledger is the cross-turn store the matcher
// queries when asking "which of these required unknowns now have
// resolving evidence?"。
//
// ## Immutability
//
// Per the repo coding-style rule:NEVER mutate。 `appending` returns a
// NEW ledger with the atom added;the receiver is untouched。 This is
// what makes the type safe to share across turns + threads (it is
// `Sendable`)。
//
// DORMANT (ADR-020 Arc-2 Step 2a):nothing in production references
// this type yet。 Byte-equal-by-construction — no existing type is
// modified + nothing is wired into the runtime。

import Foundation

/// An immutable, append-only collection of resolved-evidence atoms。
/// Query it via `matches(evidenceKey:relevanceFloor:)` or — for
/// many keys at once — `BASEvidenceMatcher.resolvedKeys`。 See
/// ADR-020 Arc-2。
public struct BASEvidenceLedger: Codable, Equatable, Sendable {
    /// The recorded evidence atoms,in insertion order。
    public var atoms: [BASEvidenceAtom]

    public init(atoms: [BASEvidenceAtom] = []) {
        self.atoms = atoms
    }

    /// Return a NEW ledger with `atom` appended。 Does NOT mutate the
    /// receiver (immutability — see coding-style rule)。
    public func appending(_ atom: BASEvidenceAtom) -> BASEvidenceLedger {
        BASEvidenceLedger(atoms: atoms + [atom])
    }

    /// The atoms whose `evidenceKey` EXACTLY equals `evidenceKey` AND
    /// whose `confidence` is at or above `relevanceFloor`。 Exact key
    /// equality only (never fuzzy / substring) — the anti-"theater"
    /// guarantee。 Pure。
    public func matches(
        evidenceKey: String,
        relevanceFloor: Double
    ) -> [BASEvidenceAtom] {
        atoms.filter {
            $0.evidenceKey == evidenceKey
                && $0.confidence >= relevanceFloor
        }
    }
}
