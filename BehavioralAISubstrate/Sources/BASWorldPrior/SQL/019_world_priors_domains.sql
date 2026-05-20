-- 019_world_priors_domains — chapter 七百七十 / M2504
--
-- DEEPER LAYER-MIGRATION ARC L4 world-priors domain registry。
-- The world-prior axioms / templates / bridges all key off a domain
-- name string;this table is the source-of-truth for what domains
-- exist + their lifecycle status (active / sunset / pending)。
--
-- Enables HOSTS to register CUSTOM domains beyond the 8 built-ins
-- shipped by BASWorldPriorBuiltInLibrary。
--
-- ## Statement count: 3
--
--   1. CREATE TABLE world_priors_domains
--   2. CREATE INDEX wpd_status_idx
--   3. CREATE INDEX wpd_horizon_idx
--
-- ## Column shape
--
--   - domain TEXT PRIMARY KEY — domain name (e.g. "physics",
--                                "social", "economics")
--   - horizon_id TEXT NOT NULL — joins to existing temporal
--                                 horizon enum (per BASTemporalHorizon)
--   - status TEXT NOT NULL CHECK (active / sunset / pending) —
--     custom domain lifecycle

CREATE TABLE IF NOT EXISTS world_priors_domains (
    domain TEXT PRIMARY KEY NOT NULL,
    horizon_id TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN
        ('active', 'sunset', 'pending'))
);

CREATE INDEX IF NOT EXISTS wpd_status_idx
  ON world_priors_domains(status);

CREATE INDEX IF NOT EXISTS wpd_horizon_idx
  ON world_priors_domains(horizon_id);
