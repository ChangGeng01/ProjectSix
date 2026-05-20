-- 015_host_constitution_deletion_manifest — chapter 七百六十九 / M2496
--
-- DEEPER LAYER-MIGRATION ARC L5 host-constitution deletion manifest
-- schema。 Pairs with 014_host_constitution_version_tree to provide
-- the cascading-delete + selective-delete + rollback audit trail
-- for the 11 host-profile domain fields。
--
-- ## Why this table
--
-- L5 host-profile deletes today flow as full-row DELETE statements
-- through BASHostConstitutionSQLiteStorage。 The DELETION INTENT
-- (which subset was targeted,which related rows cascaded,whether
-- it was a rollback or a destroy) lives only in the host actor's
-- in-memory delete log。 Persisting it enables:
--   - Cross-session audit of「what was deleted and when?」
--   - Cascading-delete replay (chapter 392 invariant)
--   - Forensic recovery:reconstruct the「pre-delete」 row set
--     from the manifest + the prior version snapshot
--
-- ## Statement count: 5
--
--   1. CREATE TABLE host_constitution_deletion_manifest
--   2. CREATE INDEX hcdm_vault_idx
--   3. CREATE INDEX hcdm_applied_at_idx
--   4. CREATE INDEX hcdm_deletion_type_idx
--   5. CREATE INDEX hcdm_version_ref_idx

CREATE TABLE IF NOT EXISTS host_constitution_deletion_manifest (
    manifest_id TEXT PRIMARY KEY NOT NULL,
    vault_id TEXT NOT NULL,
    target_refs_json TEXT NOT NULL,
    deletion_type TEXT NOT NULL CHECK (deletion_type IN
        ('cascade', 'selective', 'rollback')),
    applied_at_ms INTEGER NOT NULL,
    cascaded_refs_json TEXT,
    version_ref TEXT
);

CREATE INDEX IF NOT EXISTS hcdm_vault_idx
  ON host_constitution_deletion_manifest(vault_id, applied_at_ms);

CREATE INDEX IF NOT EXISTS hcdm_applied_at_idx
  ON host_constitution_deletion_manifest(applied_at_ms);

CREATE INDEX IF NOT EXISTS hcdm_deletion_type_idx
  ON host_constitution_deletion_manifest(deletion_type);

CREATE INDEX IF NOT EXISTS hcdm_version_ref_idx
  ON host_constitution_deletion_manifest(version_ref);
