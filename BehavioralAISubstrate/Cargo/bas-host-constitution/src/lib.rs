// MARK: - bas-host-constitution — L5 host-constitution merge logic
// chapter 七百六十八 / M2491-M2495 — DEEPER LAYER-MIGRATION ARC
//
// Pure-Rust port of the L5 Host Constitution merge decision tree。
// SQLite storage stays Swift (BASHostConstitutionSQLiteStorage,
// chapter 二百四十九 + 七百六十八 第二刀 extension)。 Rust owns the
// deterministic per-field merge resolution。
//
// ## Scope
//
// Mirrors `BASHostVersionTreeMerge.swift`:
//   - Per-field merge strategies (KeepLeft / KeepRight / Union /
//     Numeric Min / Numeric Max / FailOnConflict)
//   - Conflict detection + last-writer-wins by timestamp
//   - Rollback-point preservation across merges
//
// The orchestrator (which row to read,which row to write) stays
// Swift on the actor side。 Rust just classifies each per-field
// conflict deterministically。

#![allow(clippy::missing_safety_doc)]

// MARK: - MergeStrategy enum

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[repr(u8)]
pub enum MergeStrategy {
    /// Keep the left (older / base) version's value。
    KeepLeft         = 0,
    /// Keep the right (newer / incoming) version's value。
    KeepRight        = 1,
    /// Take the union (for set-valued fields)。 Caller post-processes。
    Union            = 2,
    /// Numeric:keep the minimum value。
    NumericMin       = 3,
    /// Numeric:keep the maximum value。
    NumericMax       = 4,
    /// Reject the merge — incompatible values。
    FailOnConflict   = 5,
}

impl MergeStrategy {
    pub const fn from_u8(b: u8) -> Option<Self> {
        match b {
            0 => Some(Self::KeepLeft),
            1 => Some(Self::KeepRight),
            2 => Some(Self::Union),
            3 => Some(Self::NumericMin),
            4 => Some(Self::NumericMax),
            5 => Some(Self::FailOnConflict),
            _ => None,
        }
    }
    pub const ALL: [MergeStrategy; 6] = [
        MergeStrategy::KeepLeft,
        MergeStrategy::KeepRight,
        MergeStrategy::Union,
        MergeStrategy::NumericMin,
        MergeStrategy::NumericMax,
        MergeStrategy::FailOnConflict,
    ];
}

// MARK: - FieldKind enum (mirrors BASHostConstitutionFieldKind)

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[repr(u8)]
pub enum FieldKind {
    IdentityTags        = 0,
    TonePreference      = 1,
    LongTermGoals       = 2,
    NoGoZones           = 3,
    RiskThresholds      = 4,
    MemoryPermissions   = 5,
    WorkRoutines        = 6,
    RelationshipRefs    = 7,
    StyleConstraints    = 8,
    UpdatePolicy        = 9,
    ActiveVersion       = 10,
}

impl FieldKind {
    pub const fn from_u8(b: u8) -> Option<Self> {
        match b {
            0 => Some(Self::IdentityTags),
            1 => Some(Self::TonePreference),
            2 => Some(Self::LongTermGoals),
            3 => Some(Self::NoGoZones),
            4 => Some(Self::RiskThresholds),
            5 => Some(Self::MemoryPermissions),
            6 => Some(Self::WorkRoutines),
            7 => Some(Self::RelationshipRefs),
            8 => Some(Self::StyleConstraints),
            9 => Some(Self::UpdatePolicy),
            10 => Some(Self::ActiveVersion),
            _ => None,
        }
    }
    pub const ALL: [FieldKind; 11] = [
        FieldKind::IdentityTags, FieldKind::TonePreference,
        FieldKind::LongTermGoals, FieldKind::NoGoZones,
        FieldKind::RiskThresholds, FieldKind::MemoryPermissions,
        FieldKind::WorkRoutines, FieldKind::RelationshipRefs,
        FieldKind::StyleConstraints, FieldKind::UpdatePolicy,
        FieldKind::ActiveVersion,
    ];

    /// Per-field default merge strategy。 Hosts can override per
    /// vault;this is the doctrine-pinned default。
    pub const fn default_merge_strategy(self) -> MergeStrategy {
        match self {
            // Set-valued fields → union
            FieldKind::IdentityTags
            | FieldKind::LongTermGoals
            | FieldKind::NoGoZones
            | FieldKind::WorkRoutines
            | FieldKind::RelationshipRefs
            | FieldKind::StyleConstraints
                => MergeStrategy::Union,
            // Single-value, latest-wins
            FieldKind::TonePreference
            | FieldKind::ActiveVersion
                => MergeStrategy::KeepRight,
            // Risk thresholds: conservative — take min (lower
            // threshold = more cautious)
            FieldKind::RiskThresholds
                => MergeStrategy::NumericMin,
            // Memory permissions: conservative — restrictive
            // settings win (take the more restrictive set)
            FieldKind::MemoryPermissions
                => MergeStrategy::FailOnConflict,
            // Update policy: review-required wins,allow-flags
            // require explicit reconciliation
            FieldKind::UpdatePolicy
                => MergeStrategy::FailOnConflict,
        }
    }
}

// MARK: - MergeOutcome

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[repr(i32)]
pub enum MergeOutcome {
    /// Merge succeeded;result is computable per the strategy。
    Success           = 0,
    /// Values incompatible;caller must escalate to host review。
    ConflictEscalated = 1,
    /// Either side was rolled back;merge cancelled per L5
    /// rollback-preservation contract。
    RollbackBlocked   = 2,
}

// MARK: - resolve_field pure fn

/// Classify the outcome of merging field `kind` from left + right。
/// Pure function;no I/O。
///
/// Inputs encode the BOOLEAN「are these values equal?」 + the side
/// rollback flags。 The caller (Swift actor) already knows the
/// concrete values;it just needs the per-field merge DECISION。
///
/// Returns:
///   - Success           : strategy applies cleanly
///   - ConflictEscalated : FailOnConflict strategy + values differ
///   - RollbackBlocked   : either side has rolled_back == true
pub fn resolve_field(
    kind: FieldKind,
    values_equal: bool,
    left_rolled_back: bool,
    right_rolled_back: bool,
) -> MergeOutcome {
    // Rollback-preservation contract:if either side is a rollback,
    // the merge is cancelled to preserve the rollback anchor。
    if left_rolled_back || right_rolled_back {
        return MergeOutcome::RollbackBlocked;
    }
    // Values equal → trivially successful。
    if values_equal {
        return MergeOutcome::Success;
    }
    // Values differ → consult per-field strategy。
    match kind.default_merge_strategy() {
        MergeStrategy::FailOnConflict => MergeOutcome::ConflictEscalated,
        _ => MergeOutcome::Success,
    }
}

// MARK: - C ABI exports

/// C ABI for resolve_field。 Returns:
///   0 — Success
///   1 — ConflictEscalated
///   2 — RollbackBlocked
///  -1 — invalid field_kind byte
#[no_mangle]
pub extern "C" fn bas_host_constitution_resolve_field(
    field_kind_byte: u8,
    values_equal: u8,        // 0 or 1
    left_rolled_back: u8,    // 0 or 1
    right_rolled_back: u8,   // 0 or 1
) -> i32 {
    let kind = match FieldKind::from_u8(field_kind_byte) {
        Some(k) => k,
        None => return -1,
    };
    let outcome = resolve_field(
        kind,
        values_equal != 0,
        left_rolled_back != 0,
        right_rolled_back != 0,
    );
    outcome as i32
}

/// C ABI:return the default merge strategy for a field kind。
/// Returns the MergeStrategy u8 discriminant,or -1 on invalid input。
#[no_mangle]
pub extern "C" fn bas_host_constitution_default_strategy(
    field_kind_byte: u8,
) -> i32 {
    match FieldKind::from_u8(field_kind_byte) {
        Some(k) => k.default_merge_strategy() as i32,
        None => -1,
    }
}

// MARK: - ABI version

pub const ABI_VERSION: i32 = 1;

#[no_mangle]
pub extern "C" fn bas_host_constitution_abi_version() -> i32 {
    ABI_VERSION
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_abi_version_pinned() {
        assert_eq!(bas_host_constitution_abi_version(), 1);
    }

    #[test]
    fn test_merge_strategy_cardinality_and_discriminants() {
        assert_eq!(MergeStrategy::ALL.len(), 6);
        assert_eq!(MergeStrategy::KeepLeft as u8, 0);
        assert_eq!(MergeStrategy::KeepRight as u8, 1);
        assert_eq!(MergeStrategy::Union as u8, 2);
        assert_eq!(MergeStrategy::NumericMin as u8, 3);
        assert_eq!(MergeStrategy::NumericMax as u8, 4);
        assert_eq!(MergeStrategy::FailOnConflict as u8, 5);
    }

    #[test]
    fn test_field_kind_cardinality_and_discriminants() {
        assert_eq!(FieldKind::ALL.len(), 11);
        assert_eq!(FieldKind::IdentityTags as u8, 0);
        assert_eq!(FieldKind::ActiveVersion as u8, 10);
    }

    #[test]
    fn test_field_default_strategies() {
        // Set-valued → Union
        assert_eq!(FieldKind::IdentityTags.default_merge_strategy(),
            MergeStrategy::Union);
        assert_eq!(FieldKind::NoGoZones.default_merge_strategy(),
            MergeStrategy::Union);
        // Single-value latest-wins → KeepRight
        assert_eq!(FieldKind::TonePreference.default_merge_strategy(),
            MergeStrategy::KeepRight);
        assert_eq!(FieldKind::ActiveVersion.default_merge_strategy(),
            MergeStrategy::KeepRight);
        // Risk thresholds → NumericMin (conservative)
        assert_eq!(FieldKind::RiskThresholds.default_merge_strategy(),
            MergeStrategy::NumericMin);
        // Memory perms + update policy → FailOnConflict
        assert_eq!(FieldKind::MemoryPermissions.default_merge_strategy(),
            MergeStrategy::FailOnConflict);
        assert_eq!(FieldKind::UpdatePolicy.default_merge_strategy(),
            MergeStrategy::FailOnConflict);
    }

    #[test]
    fn test_resolve_field_equal_values_succeed() {
        let out = resolve_field(
            FieldKind::IdentityTags, true, false, false);
        assert_eq!(out, MergeOutcome::Success);
    }

    #[test]
    fn test_resolve_field_left_rolled_back_blocks() {
        let out = resolve_field(
            FieldKind::IdentityTags, true, true, false);
        assert_eq!(out, MergeOutcome::RollbackBlocked);
    }

    #[test]
    fn test_resolve_field_right_rolled_back_blocks() {
        let out = resolve_field(
            FieldKind::IdentityTags, true, false, true);
        assert_eq!(out, MergeOutcome::RollbackBlocked);
    }

    #[test]
    fn test_resolve_field_union_field_succeeds_on_diff() {
        let out = resolve_field(
            FieldKind::IdentityTags, false, false, false);
        // Union strategy → Success even on diff (Swift unions)
        assert_eq!(out, MergeOutcome::Success);
    }

    #[test]
    fn test_resolve_field_memory_perms_escalates_on_diff() {
        let out = resolve_field(
            FieldKind::MemoryPermissions, false, false, false);
        // FailOnConflict → ConflictEscalated when values differ
        assert_eq!(out, MergeOutcome::ConflictEscalated);
    }

    #[test]
    fn test_resolve_field_update_policy_escalates_on_diff() {
        let out = resolve_field(
            FieldKind::UpdatePolicy, false, false, false);
        assert_eq!(out, MergeOutcome::ConflictEscalated);
    }

    #[test]
    fn test_c_abi_resolve_field_equal_returns_0() {
        assert_eq!(
            bas_host_constitution_resolve_field(0, 1, 0, 0),
            0);
    }

    #[test]
    fn test_c_abi_resolve_field_rollback_returns_2() {
        assert_eq!(
            bas_host_constitution_resolve_field(0, 1, 1, 0),
            2);
    }

    #[test]
    fn test_c_abi_resolve_field_memory_perms_conflict_returns_1() {
        assert_eq!(
            bas_host_constitution_resolve_field(
                FieldKind::MemoryPermissions as u8, 0, 0, 0),
            1);
    }

    #[test]
    fn test_c_abi_resolve_field_invalid_kind_returns_minus_1() {
        assert_eq!(
            bas_host_constitution_resolve_field(99, 0, 0, 0),
            -1);
    }

    #[test]
    fn test_c_abi_default_strategy_per_field() {
        // Identity tags → Union (2)
        assert_eq!(
            bas_host_constitution_default_strategy(0), 2);
        // Memory perms → FailOnConflict (5)
        assert_eq!(
            bas_host_constitution_default_strategy(5), 5);
    }

    #[test]
    fn test_c_abi_default_strategy_invalid_kind_returns_minus_1() {
        assert_eq!(
            bas_host_constitution_default_strategy(99), -1);
    }
}
