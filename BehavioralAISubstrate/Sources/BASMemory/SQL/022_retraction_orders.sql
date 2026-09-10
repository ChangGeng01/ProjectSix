-- 022_retraction_orders — chapter 七百七十五 / M2528
--
-- L13 PHASE 2 SQL persistence — retraction order records。 A
-- retraction order is queued by `BASShadowTrialCoordinator` when
-- a trial reaches the `retracted` phase (Phase 2
-- ShadowTrialPhase=3,via failed/blocked verdict)。 The order
-- binds the candidate evolution to its failing-verdict audit
-- trail + the retraction reason。
--
-- Pairs with 021_evolution_seals to provide the complete
-- success+failure persistence for L13 trial outcomes。
--
-- ## Why this table
--
-- Mirrors the coordinator's in-memory `retractionsByCandidate:
-- [String: BASRetractionOrder]` (Sources/BASMemory/
-- ShadowTrialCoordinator.swift line 137)。 Persisting it enables
-- cold-restart recovery + per-session retraction queries +
-- joins to verdict_decisions for full failure provenance。
--
-- ## Statement count: 4
--
--   1. CREATE TABLE retraction_orders
--   2. CREATE INDEX ro_candidate_idx
--   3. CREATE INDEX ro_session_idx
--   4. CREATE INDEX ro_reason_kind_idx
--
-- ## Column shape
--
--   - retraction_id TEXT PRIMARY KEY — opaque UUID
--   - candidate_id TEXT NOT NULL — the evolution candidate
--   - session_id TEXT NOT NULL — joins to L14 session
--   - trial_ref TEXT NOT NULL — joins to shadow_trial_records
--     by audit_id (the trial that triggered this retraction)
--   - reason_kind TEXT NOT NULL CHECK — 'failed' / 'blocked'
--     (matches BASBreathPhase Failed/Blocked verdict outputs)
--   - reason_text TEXT — optional free-form retraction note
--   - queued_at_ms INTEGER NOT NULL — UNIX epoch ms

CREATE TABLE IF NOT EXISTS retraction_orders (
    retraction_id TEXT PRIMARY KEY NOT NULL,
    candidate_id TEXT NOT NULL,
    session_id TEXT NOT NULL,
    trial_ref TEXT NOT NULL,
    reason_kind TEXT NOT NULL CHECK (reason_kind IN
        ('failed', 'blocked')),
    reason_text TEXT,
    queued_at_ms INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS ro_candidate_idx
  ON retraction_orders(candidate_id, queued_at_ms);

CREATE INDEX IF NOT EXISTS ro_session_idx
  ON retraction_orders(session_id);

CREATE INDEX IF NOT EXISTS ro_reason_kind_idx
  ON retraction_orders(reason_kind);
