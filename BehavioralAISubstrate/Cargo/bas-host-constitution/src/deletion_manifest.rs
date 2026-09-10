// MARK: - bas-host-constitution::deletion_manifest
// chapter 七百六十九 / M2496-M2500 — DEEPER LAYER-MIGRATION ARC
//
// Pure-Rust port of the L5 deletion-manifest decision tree。 Pairs
// with the SQL schema 015_host_constitution_deletion_manifest。
//
// ## Scope
//
// The Swift actor (BASHostConstitutionSQLiteStorage) owns the
// SQLite transaction that applies cascading deletes。 Rust owns
// the deterministic「which cascade type applies?」 classifier +
// the per-field cascade-eligibility check。
//
// ## Cascade types (mirror BASHostConstitutionDeletionType Swift enum)
//
// - Cascade   : delete this version + all descendants (subtree)
// - Selective : delete a specific subset of fields only (no
//               cascade to descendant versions)
// - Rollback  : restore an earlier version,deleting the
//               intervening lineage

#![allow(clippy::missing_safety_doc)]

// MARK: - DeletionType enum

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[repr(u8)]
pub enum DeletionType {
    Cascade   = 0,
    Selective = 1,
    Rollback  = 2,
}

impl DeletionType {
    pub const fn from_u8(b: u8) -> Option<Self> {
        match b {
            0 => Some(Self::Cascade),
            1 => Some(Self::Selective),
            2 => Some(Self::Rollback),
            _ => None,
        }
    }
    pub const ALL: [DeletionType; 3] = [
        DeletionType::Cascade,
        DeletionType::Selective,
        DeletionType::Rollback,
    ];
}

// MARK: - DeletionEligibility classifier

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[repr(i32)]
pub enum DeletionEligibility {
    /// Deletion may proceed。
    Allowed                  = 0,
    /// Target is a rollback anchor — deletion blocks per the
    /// rollback-preservation contract (chapter 七百六十八 +
    /// chapter 392 replay-determinism)。
    BlockedByRollbackAnchor  = 1,
    /// Target has no parent (genesis) — Cascade DELETE would
    /// destroy the vault completely。 Caller must escalate to
    /// host review。
    BlockedByVaultGenesis    = 2,
    /// Selective delete attempted on an immutable field (e.g。
    /// active_version)。 Caller must escalate or use Rollback。
    BlockedByImmutableField  = 3,
}

/// Classify whether a deletion is allowed against the given anchors。
/// Pure function;no I/O。
///
/// Inputs encode key boolean state — actual concrete values
/// (vault_id strings,version_id strings) live on the Swift actor。
/// This Rust fn just provides the deterministic permit decision。
///
/// Logic mirrors the「early reject」 cases the Swift actor would
/// otherwise discover after starting a transaction。 Centralising
/// the decision here means rollback recovery is cheap + Rust's
/// exhaustive match catches future cascade type additions。
pub fn classify_deletion_eligibility(
    deletion_type: DeletionType,
    is_rollback_anchor: bool,
    is_vault_genesis: bool,
    targets_immutable_field: bool,
) -> DeletionEligibility {
    // Rollback anchors are NEVER deletable through ordinary cascade。
    // The host must Restore-then-Delete (use the Rollback path itself
    // to reposition the anchor)。
    if is_rollback_anchor && deletion_type != DeletionType::Rollback {
        return DeletionEligibility::BlockedByRollbackAnchor;
    }

    // Vault-genesis cascade would empty the vault。 Block unless the
    // caller explicitly uses Rollback (which is structurally
    // safe — it restores a different version)。
    if is_vault_genesis && deletion_type == DeletionType::Cascade {
        return DeletionEligibility::BlockedByVaultGenesis;
    }

    // Selective deletes can't touch immutable fields (active_version
    // for example)。
    if targets_immutable_field
        && deletion_type == DeletionType::Selective {
        return DeletionEligibility::BlockedByImmutableField;
    }

    DeletionEligibility::Allowed
}

// MARK: - C ABI

/// C ABI:classify deletion eligibility。 Returns:
///   0 — Allowed
///   1 — BlockedByRollbackAnchor
///   2 — BlockedByVaultGenesis
///   3 — BlockedByImmutableField
///  -1 — invalid deletion_type byte
#[no_mangle]
pub extern "C" fn bas_host_constitution_classify_deletion(
    deletion_type_byte: u8,
    is_rollback_anchor: u8,
    is_vault_genesis: u8,
    targets_immutable_field: u8,
) -> i32 {
    let dt = match DeletionType::from_u8(deletion_type_byte) {
        Some(t) => t,
        None => return -1,
    };
    classify_deletion_eligibility(
        dt,
        is_rollback_anchor != 0,
        is_vault_genesis != 0,
        targets_immutable_field != 0,
    ) as i32
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_deletion_type_cardinality_and_discriminants() {
        assert_eq!(DeletionType::ALL.len(), 3);
        assert_eq!(DeletionType::Cascade as u8, 0);
        assert_eq!(DeletionType::Selective as u8, 1);
        assert_eq!(DeletionType::Rollback as u8, 2);
    }

    #[test]
    fn test_deletion_type_from_u8_round_trip() {
        for &t in &DeletionType::ALL {
            assert_eq!(DeletionType::from_u8(t as u8), Some(t));
        }
        assert_eq!(DeletionType::from_u8(3), None);
    }

    #[test]
    fn test_clean_cascade_allowed() {
        let r = classify_deletion_eligibility(
            DeletionType::Cascade, false, false, false);
        assert_eq!(r, DeletionEligibility::Allowed);
    }

    #[test]
    fn test_clean_selective_allowed() {
        let r = classify_deletion_eligibility(
            DeletionType::Selective, false, false, false);
        assert_eq!(r, DeletionEligibility::Allowed);
    }

    #[test]
    fn test_clean_rollback_allowed() {
        let r = classify_deletion_eligibility(
            DeletionType::Rollback, false, false, false);
        assert_eq!(r, DeletionEligibility::Allowed);
    }

    #[test]
    fn test_rollback_anchor_blocks_cascade() {
        let r = classify_deletion_eligibility(
            DeletionType::Cascade, true, false, false);
        assert_eq!(r, DeletionEligibility::BlockedByRollbackAnchor);
    }

    #[test]
    fn test_rollback_anchor_blocks_selective() {
        let r = classify_deletion_eligibility(
            DeletionType::Selective, true, false, false);
        assert_eq!(r, DeletionEligibility::BlockedByRollbackAnchor);
    }

    #[test]
    fn test_rollback_anchor_allows_rollback_op() {
        // The Rollback op itself can reposition the anchor — so
        // anchor flag doesn't block Rollback type。
        let r = classify_deletion_eligibility(
            DeletionType::Rollback, true, false, false);
        assert_eq!(r, DeletionEligibility::Allowed);
    }

    #[test]
    fn test_vault_genesis_blocks_cascade() {
        let r = classify_deletion_eligibility(
            DeletionType::Cascade, false, true, false);
        assert_eq!(r, DeletionEligibility::BlockedByVaultGenesis);
    }

    #[test]
    fn test_vault_genesis_allows_selective() {
        // Selective delete on genesis is fine (preserves the
        // version,just removes some fields)。
        let r = classify_deletion_eligibility(
            DeletionType::Selective, false, true, false);
        assert_eq!(r, DeletionEligibility::Allowed);
    }

    #[test]
    fn test_immutable_field_blocks_selective() {
        let r = classify_deletion_eligibility(
            DeletionType::Selective, false, false, true);
        assert_eq!(r, DeletionEligibility::BlockedByImmutableField);
    }

    #[test]
    fn test_immutable_field_does_not_block_cascade() {
        // Cascade overrides per-field immutability (the row is
        // gone anyway,nothing to「mutate」)。
        let r = classify_deletion_eligibility(
            DeletionType::Cascade, false, false, true);
        assert_eq!(r, DeletionEligibility::Allowed);
    }

    #[test]
    fn test_c_abi_clean_returns_0() {
        assert_eq!(
            bas_host_constitution_classify_deletion(0, 0, 0, 0),
            0);
    }

    #[test]
    fn test_c_abi_rollback_anchor_blocks_cascade_returns_1() {
        assert_eq!(
            bas_host_constitution_classify_deletion(0, 1, 0, 0),
            1);
    }

    #[test]
    fn test_c_abi_invalid_deletion_type_returns_minus_1() {
        assert_eq!(
            bas_host_constitution_classify_deletion(99, 0, 0, 0),
            -1);
    }
}
