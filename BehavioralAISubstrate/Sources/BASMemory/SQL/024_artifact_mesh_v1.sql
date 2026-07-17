-- 024_artifact_mesh_v1
-- Immutable keyed Artifact Mesh records, typed CAS heads, and the
-- ordinary-attestation target projection. Runtime migration ownership
-- remains exclusively in BASArtifactSQLiteStore.

CREATE TABLE artifact_mesh_records (
    artifact_id TEXT PRIMARY KEY NOT NULL,
    record_bytes BLOB NOT NULL,
    payload_ref TEXT NOT NULL UNIQUE,
    commitment_key_epoch TEXT NOT NULL
        CHECK (length(commitment_key_epoch) > 0)
);

CREATE TABLE artifact_mesh_heads (
    scope_tag TEXT NOT NULL
        CHECK (scope_tag IN ('workspace-authority', 'attempt')),
    scope_artifact_id TEXT NOT NULL,
    purpose TEXT NOT NULL
        CHECK (purpose IN (
            'workspaceRoot',
            'attemptRoot',
            'semanticSnapshot',
            'projectionCheckpoint'
        )),
    artifact_id TEXT NOT NULL,
    revision TEXT NOT NULL CHECK (length(revision) > 0),
    PRIMARY KEY (scope_tag, scope_artifact_id, purpose),
    FOREIGN KEY (artifact_id)
        REFERENCES artifact_mesh_records(artifact_id)
        ON DELETE RESTRICT
);

CREATE TABLE artifact_mesh_attestation_targets (
    attestation_artifact_id TEXT PRIMARY KEY NOT NULL,
    target_artifact_id TEXT NOT NULL,
    FOREIGN KEY (attestation_artifact_id)
        REFERENCES artifact_mesh_records(artifact_id)
        ON DELETE RESTRICT,
    FOREIGN KEY (target_artifact_id)
        REFERENCES artifact_mesh_records(artifact_id)
        ON DELETE RESTRICT
);

CREATE INDEX artifact_mesh_attestation_target_idx
    ON artifact_mesh_attestation_targets(
        target_artifact_id,
        attestation_artifact_id
    );

CREATE INDEX artifact_mesh_head_artifact_idx
    ON artifact_mesh_heads(artifact_id);
