-- 017_world_priors_templates — chapter 七百七十 / M2502
--
-- DEEPER LAYER-MIGRATION ARC L4 world-priors template schema。
-- Net-new table backing the migration of
-- BASWorldPriorBuiltInLibrary.swift template (action-effect) data
-- to SQL-driven storage。
--
-- ## Statement count: 5
--
--   1. CREATE TABLE world_priors_templates
--   2. CREATE INDEX wpt_domain_idx
--   3. CREATE INDEX wpt_reversibility_idx
--   4. CREATE INDEX wpt_latency_idx
--   5. CREATE INDEX wpt_evidence_level_idx
--
-- ## Column shape
--
--   - template_id TEXT PRIMARY KEY — opaque UUID
--   - domain TEXT NOT NULL — joins to world_priors_domains
--   - preconditions_json TEXT — JSON list of preconditions
--                                (variadic — JSON exception per
--                                chapter 七百六十八 pattern)
--   - effect TEXT NOT NULL — observable effect string
--   - reversibility INTEGER NOT NULL CHECK (0..3)
--     0=irreversible / 1=hard / 2=medium / 3=easy
--   - latency_ms INTEGER NOT NULL — expected effect latency
--   - evidence_level TEXT NOT NULL CHECK — matches axioms schema

CREATE TABLE IF NOT EXISTS world_priors_templates (
    template_id TEXT PRIMARY KEY NOT NULL,
    domain TEXT NOT NULL,
    preconditions_json TEXT,
    effect TEXT NOT NULL,
    reversibility INTEGER NOT NULL
        CHECK (reversibility IN (0, 1, 2, 3)),
    latency_ms INTEGER NOT NULL CHECK (latency_ms >= 0),
    evidence_level TEXT NOT NULL CHECK (evidence_level IN
        ('anecdotal', 'observed', 'peer_reviewed', 'mechanistic'))
);

CREATE INDEX IF NOT EXISTS wpt_domain_idx
  ON world_priors_templates(domain);

CREATE INDEX IF NOT EXISTS wpt_reversibility_idx
  ON world_priors_templates(reversibility);

CREATE INDEX IF NOT EXISTS wpt_latency_idx
  ON world_priors_templates(latency_ms);

CREATE INDEX IF NOT EXISTS wpt_evidence_level_idx
  ON world_priors_templates(evidence_level);
