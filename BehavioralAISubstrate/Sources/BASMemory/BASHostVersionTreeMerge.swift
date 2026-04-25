import Foundation

/// M217 — CRDT-style merge for `BASHostVersionTree` across devices.
///
/// ## Why this exists
///
/// `BASHostConstitution` is a per-device structure: each device
/// holds its own version tree, pending candidates, frozen versions.
/// Pre-M217 there was no Swift-level mechanism to reconcile two
/// device snapshots into a single consistent view. The honesty
/// board's L5 row noted the gap directly:
///
/// > 剩余 = 跨设备一致撤回 + 并行宪法层
///
/// `merging(_:)` is the schema-level resolver. It takes two
/// `BASHostVersionTree` snapshots — typically `local` and
/// `remote` after a network sync — and returns a single tree
/// where:
///
///   - `versions` is the union of both, deduplicated by
///     `versionID`. On collision (same ID, different content) the
///     version with the later `createdAt` wins; this matters when
///     a forge-able field (`approvedByPolicy`, `signature`)
///     differs between snapshots.
///   - `pendingCandidateIDs` is the union of both, deduplicated
///     by ID. Pending is monotonically growing on each side; merge
///     is the natural lattice join.
///   - `frozenVersionIDs` is also union — freezing on either
///     device propagates to both (sovereign safety doctrine: once
///     frozen anywhere, frozen everywhere).
///   - `activeVersionID` resolves to the version whose
///     `createdAt` is later among the two snapshots' actives. Ties
///     break on lexicographic versionID for determinism.
///
/// ## What this is NOT
///
/// `merging(_:)` is the **algorithm**, not the **transport**.
/// Hosts that want network sync write their own transport (CRDT
/// op-log, REST polling, P2P gossip) and apply this merge at the
/// reconciliation point. The pure function is what lets
/// substrate-level tests prove the merge is associative,
/// commutative, and idempotent — the three CRDT properties that
/// matter for "device A then device B" producing the same result
/// as "device B then device A" producing the same result as
/// "device A then device A".
///
/// ## Conflict resolution doctrine
///
/// **Last-write-wins by createdAt** for active version + version
/// content collisions. This is simpler than vector clocks but
/// requires synchronised wall clocks at write time. Hosts that
/// can't trust wall clocks should layer a vector-clock
/// pre-processor on top before calling `merging(_:)`.
public extension BASHostVersionTree {

    /// Merge `other` into `self` and return the resolved tree.
    /// Pure function — neither input is mutated.
    func merging(
        _ other: BASHostVersionTree
    ) -> BASHostVersionTree {
        let mergedVersions = Self.mergeVersions(
            local: self.versions, remote: other.versions)
        let mergedPending = Self.mergeStringSet(
            local: self.pendingCandidateIDs,
            remote: other.pendingCandidateIDs)
        let mergedFrozen = Self.mergeStringSet(
            local: self.frozenVersionIDs,
            remote: other.frozenVersionIDs)
        let resolvedActive = Self.resolveActiveVersion(
            localActiveID: self.activeVersionID,
            remoteActiveID: other.activeVersionID,
            mergedVersions: mergedVersions)

        return BASHostVersionTree(
            schemaVersion: self.schemaVersion,
            activeVersionID: resolvedActive,
            versions: mergedVersions,
            pendingCandidateIDs: mergedPending,
            frozenVersionIDs: mergedFrozen)
    }

    /// Merge two version arrays. Same `versionID` → keep the one
    /// with later `createdAt`. Output is sorted by `createdAt`
    /// (ascending) with `versionID` as the tiebreaker, so two
    /// devices that merge in opposite order get byte-identical
    /// `versions` arrays — required for the commutative property.
    static func mergeVersions(
        local: [BASHostVersion],
        remote: [BASHostVersion]
    ) -> [BASHostVersion] {
        var byID: [String: BASHostVersion] = [:]
        for v in local { byID[v.versionID] = v }
        for v in remote {
            if let existing = byID[v.versionID] {
                // Same versionID, possibly different content.
                // Last-write-wins by createdAt; tiebreak by
                // approvedByPolicy=true preference (a signed
                // version beats an unsigned one).
                if v.createdAt > existing.createdAt {
                    byID[v.versionID] = v
                } else if v.createdAt == existing.createdAt {
                    if v.approvedByPolicy
                        && !existing.approvedByPolicy
                    {
                        byID[v.versionID] = v
                    }
                }
            } else {
                byID[v.versionID] = v
            }
        }
        return byID.values.sorted { a, b in
            if a.createdAt != b.createdAt {
                return a.createdAt < b.createdAt
            }
            return a.versionID < b.versionID
        }
    }

    /// Set-union for `[String]` collections that represent IDs.
    /// Sorted output for deterministic merge regardless of order.
    static func mergeStringSet(
        local: [String], remote: [String]
    ) -> [String] {
        Set(local).union(Set(remote)).sorted()
    }

    /// Pick the active version ID by walking the merged versions
    /// list:
    /// 1. If both `local` and `remote` actives exist in the merged
    ///    set: pick the one with the later `createdAt`. Tie →
    ///    lexicographic versionID order.
    /// 2. If only one exists in merged: pick it.
    /// 3. If neither exists: fall back to the lexicographically
    ///    smallest `versionID` in the merged set (defensive — this
    ///    case shouldn't arise if both inputs were well-formed).
    /// 4. If merged is empty: fall back to `localActiveID` (caller
    ///    is responsible for avoiding empty trees).
    static func resolveActiveVersion(
        localActiveID: String,
        remoteActiveID: String,
        mergedVersions: [BASHostVersion]
    ) -> String {
        if localActiveID == remoteActiveID {
            return localActiveID
        }
        let localVersion = mergedVersions
            .first(where: { $0.versionID == localActiveID })
        let remoteVersion = mergedVersions
            .first(where: { $0.versionID == remoteActiveID })

        switch (localVersion, remoteVersion) {
        case let (lhs?, rhs?):
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
                    ? lhs.versionID
                    : rhs.versionID
            }
            return lhs.versionID < rhs.versionID
                ? lhs.versionID
                : rhs.versionID
        case (.some(let lhs), nil):
            return lhs.versionID
        case (nil, .some(let rhs)):
            return rhs.versionID
        case (nil, nil):
            return mergedVersions
                .min(by: { $0.versionID < $1.versionID })?
                .versionID
                ?? localActiveID
        }
    }
}
