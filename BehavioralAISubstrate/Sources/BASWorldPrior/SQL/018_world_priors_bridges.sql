-- 018_world_priors_bridges — chapter 七百七十 / M2503
--
-- DEEPER LAYER-MIGRATION ARC L4 world-priors bridge schema。 Net-
-- new table for cross-domain analogies (source_domain → target_domain
-- mappings via template pairings)。
--
-- ## Statement count: 4
--
--   1. CREATE TABLE world_priors_bridges
--   2. CREATE INDEX wpb_source_idx
--   3. CREATE INDEX wpb_target_idx
--   4. CREATE INDEX wpb_evidence_level_idx
--
-- ## Column shape
--
--   - bridge_id TEXT PRIMARY KEY — opaque UUID
--   - source_domain TEXT NOT NULL
--   - target_domain TEXT NOT NULL
--   - analogy TEXT NOT NULL — natural-language analogy text
--   - template_pairings_json TEXT — JSON list of
--                                    (source_template_id,
--                                     target_template_id) pairs
--   - evidence_level TEXT NOT NULL CHECK

CREATE TABLE IF NOT EXISTS world_priors_bridges (
    bridge_id TEXT PRIMARY KEY NOT NULL,
    source_domain TEXT NOT NULL,
    target_domain TEXT NOT NULL,
    analogy TEXT NOT NULL,
    template_pairings_json TEXT,
    evidence_level TEXT NOT NULL CHECK (evidence_level IN
        ('anecdotal', 'observed', 'peer_reviewed', 'mechanistic'))
);

CREATE INDEX IF NOT EXISTS wpb_source_idx
  ON world_priors_bridges(source_domain);

CREATE INDEX IF NOT EXISTS wpb_target_idx
  ON world_priors_bridges(target_domain);

CREATE INDEX IF NOT EXISTS wpb_evidence_level_idx
  ON world_priors_bridges(evidence_level);
