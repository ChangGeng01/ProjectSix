-- 014_host_constitution_version_tree — chapter 七百六十八 / M2491
--
-- DEEPER LAYER-MIGRATION ARC L5 host-constitution version tree
-- schema。 Extends the existing BASHostConstitutionSQLiteStorage
-- (live since chapter 二百四十九) with explicit version lineage +
-- merge provenance。
--
-- ## Why this table
--
-- L5 host-constitution mutations currently flow through the SQLite
-- store as full-row updates。 The version lineage (parent → child,
-- which version was a rollback,which was merged from N branches)
-- lives only in the host-supplied `BASHostVersionTreeMerge` Swift
-- struct,not in the storage layer。 Persisting it as a typed table
-- enables:
--   - Deterministic merge replay (chapter 392 invariant)
--   - Rollback-point queries:「show me all versions where
--     is_rollback_point = 1」
--   - Lineage walk:「what was the parent of this version?」
--
-- ## ADR-014 OPT-IN preserved
--
-- Schema lands unconditionally。 V1 single-row update path stays
-- the live default。 Hosts opt in to lineage tracking by enabling
-- the chapter 七百六十八 第三刀 routedMergeVersions flag。
--
-- ## Statement count: 5
--
--   1. CREATE TABLE host_constitution_version_tree
--   2. CREATE INDEX hcvt_vault_idx
--   3. CREATE INDEX hcvt_parent_idx
--   4. CREATE INDEX hcvt_rollback_idx
--   5. CREATE INDEX hcvt_created_at_idx
--
-- ## Column shape rationale
--
--   - version_id TEXT PRIMARY KEY — opaque UUID
--   - vault_id TEXT NOT NULL — joins to vault
--   - parent_version_id TEXT — nullable for genesis;FK convention
--                              (not enforced via FK constraint to
--                              avoid bootstrap cycles)
--   - created_at_ms INTEGER NOT NULL — UNIX epoch ms
--   - signature_hash BLOB NOT NULL — 32-byte SHA-256 of the
--                                     version's canonical bytes
--   - is_rollback_point INTEGER NOT NULL DEFAULT 0 CHECK (0,1) —
--                                    1 = host explicitly marked
--                                    this version as a recoverable
--                                    rollback anchor
--   - merged_from_json TEXT — JSON array of source version_ids when
--                              this version was a merge;NULL for
--                              ordinary edits。 (Exception to the
--                              「不要 json」 rule because the array
--                              cardinality varies 0..N and a
--                              relational normalisation would
--                              require a separate join table for
--                              a feature only host-merge code
--                              consults。)

CREATE TABLE IF NOT EXISTS host_constitution_version_tree (
    version_id TEXT PRIMARY KEY NOT NULL,
    vault_id TEXT NOT NULL,
    parent_version_id TEXT,
    created_at_ms INTEGER NOT NULL,
    signature_hash BLOB NOT NULL,
    is_rollback_point INTEGER NOT NULL DEFAULT 0
        CHECK (is_rollback_point IN (0, 1)),
    merged_from_json TEXT
);

CREATE INDEX IF NOT EXISTS hcvt_vault_idx
  ON host_constitution_version_tree(vault_id, created_at_ms);

CREATE INDEX IF NOT EXISTS hcvt_parent_idx
  ON host_constitution_version_tree(parent_version_id);

CREATE INDEX IF NOT EXISTS hcvt_rollback_idx
  ON host_constitution_version_tree(is_rollback_point);

CREATE INDEX IF NOT EXISTS hcvt_created_at_idx
  ON host_constitution_version_tree(created_at_ms);
