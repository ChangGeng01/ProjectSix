-- 021_evolution_seals — chapter 七百七十五 / M2527
--
-- L13 PHASE 2 SQL persistence — evolution seal records。 An
-- evolution seal is issued by `BASShadowTrialCoordinator` when a
-- trial reaches the `sealed` phase (Phase 2 ShadowTrialPhase=2)。
-- The seal binds the candidate evolution to its passing-verdict
-- audit trail。
--
-- ## Why this table
--
-- The coordinator currently keeps `sealsByCandidate: [String:
-- BASEvolutionSeal]` in-memory (Sources/BASMemory/
-- ShadowTrialCoordinator.swift line 135)。 Persisting it enables:
--   - Cold-restart recovery (a host running across process
--     restarts sees its prior seals)
--   - Audit queries ("which evolutions sealed during session X?")
--   - Cross-mirror with shadow_trial_records for end-to-end
--     trial → seal traceability
--
-- ## Statement count: 4
--
--   1. CREATE TABLE evolution_seals
--   2. CREATE INDEX es_candidate_idx
--   3. CREATE INDEX es_session_idx
--   4. CREATE INDEX es_trial_ref_idx
--
-- ## Column shape
--
--   - seal_id TEXT PRIMARY KEY — opaque UUID
--   - candidate_id TEXT NOT NULL — the evolution candidate
--   - session_id TEXT NOT NULL — joins to L14 session
--   - trial_ref TEXT NOT NULL — joins to shadow_trial_records
--     by audit_id (the trial that produced this seal)
--   - issued_at_ms INTEGER NOT NULL — UNIX epoch ms
--   - seal_signature TEXT NOT NULL — HMAC / signature payload
--     binding the seal to the candidate + trial

CREATE TABLE IF NOT EXISTS evolution_seals (
    seal_id TEXT PRIMARY KEY NOT NULL,
    candidate_id TEXT NOT NULL,
    session_id TEXT NOT NULL,
    trial_ref TEXT NOT NULL,
    issued_at_ms INTEGER NOT NULL,
    seal_signature TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS es_candidate_idx
  ON evolution_seals(candidate_id, issued_at_ms);

CREATE INDEX IF NOT EXISTS es_session_idx
  ON evolution_seals(session_id);

CREATE INDEX IF NOT EXISTS es_trial_ref_idx
  ON evolution_seals(trial_ref);
