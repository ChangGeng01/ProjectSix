import Foundation

/// M215 — store abstraction the L8 mutation writer mutates.
///
/// ## Why this exists
///
/// `BASMemoryTieringReconciler` (M21) emits typed
/// `BASMemoryTierTransition` recommendations. Pre-M215 nothing
/// applied them — the reconciler's output was logged for audit
/// but the actual memory atoms never moved between tiers, never
/// got quarantined, never got evicted. The honesty board's L8
/// row noted this gap directly:
///
/// > reconciliation → mutation writer 尚未接线
///
/// `BASMemoryMutationWriter` (also M215) consumes a
/// `BASMemoryTieringReconciliationOutcome` and applies each
/// decision to a store via this protocol. The protocol is the
/// seam: the writer is store-agnostic, hosts plug their own
/// backend (in-memory, SQLite, CRDT-synced) by conforming.
///
/// `BASInMemoryMemoryAtomStore` is the canonical in-process
/// implementation — stores `BASGovernedMemory` values keyed by
/// their string ID. Tests use this; production hosts that want
/// persistence subclass or replace.
///
/// ## ID convention
///
/// `BASMemoryTieringProfile.atomID` is a `String`, but
/// `BASGovernedMemory.id` is a `UUID`. The store does NOT enforce
/// any particular mapping: hosts choose. The in-memory impl keys
/// by `id.uuidString` so reconciler profiles built with that
/// key match.
public protocol BASMemoryAtomStore: Sendable {
    /// Look up an atom by string ID. Returns nil if absent.
    func atom(forID id: String) async -> BASGovernedMemory?

    /// Move the atom's `tier` to `newTier`. Returns true if the
    /// atom existed and was updated; false if not found.
    @discardableResult
    func updateTier(
        forID id: String,
        to newTier: BASMemoryTier
    ) async -> Bool

    /// Move the atom's `governanceStatus` to `newStatus`. Same
    /// found-or-not semantics as `updateTier`.
    @discardableResult
    func updateGovernanceStatus(
        forID id: String,
        to newStatus: BASMemoryGovernanceStatus
    ) async -> Bool

    /// Remove the atom by ID. Returns the removed value, or nil
    /// if not found.
    @discardableResult
    func remove(forID id: String) async -> BASGovernedMemory?
}

/// Canonical in-memory implementation. Stores
/// `BASGovernedMemory` values keyed by `id.uuidString`. Atoms
/// are mutated in place via `inout` — same semantics as
/// `Dictionary.subscript(key:)` setter.
public actor BASInMemoryMemoryAtomStore: BASMemoryAtomStore {
    private var atoms: [String: BASGovernedMemory] = [:]

    public init(initial: [BASGovernedMemory] = []) {
        for atom in initial {
            atoms[atom.id.uuidString] = atom
        }
    }

    public func atom(
        forID id: String
    ) async -> BASGovernedMemory? {
        atoms[id]
    }

    public var count: Int { atoms.count }

    public var allIDs: Set<String> { Set(atoms.keys) }

    @discardableResult
    public func updateTier(
        forID id: String,
        to newTier: BASMemoryTier
    ) async -> Bool {
        guard var atom = atoms[id] else { return false }
        atom.tier = newTier
        atoms[id] = atom
        return true
    }

    @discardableResult
    public func updateGovernanceStatus(
        forID id: String,
        to newStatus: BASMemoryGovernanceStatus
    ) async -> Bool {
        guard var atom = atoms[id] else { return false }
        atom.governanceStatus = newStatus
        atoms[id] = atom
        return true
    }

    @discardableResult
    public func remove(
        forID id: String
    ) async -> BASGovernedMemory? {
        atoms.removeValue(forKey: id)
    }
}
