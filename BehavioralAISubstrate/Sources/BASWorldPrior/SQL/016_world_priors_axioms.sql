-- 016_world_priors_axioms — chapter 七百七十 / M2501
--
-- DEEPER LAYER-MIGRATION ARC L4 world-priors axiom schema。 Net-new
-- table backing the migration of BASWorldPriorBuiltInLibrary.swift
-- (658 LOC of hardcoded axioms) to SQL-driven storage。
--
-- ## Why this table
--
-- Per chapter 七百七十-七百七十一 plan:
-- L4 world priors today live as hardcoded Swift switch statements。
-- Migrating to SQL enables:
--   - Host-side custom domain registration (chapter 七百七十 schema
--     019 wires up the domain registry)
--   - Cross-language queries (the Rust crate in chapter 七百七十一
--     loads from this table at boot)
--   - Schema evolution without recompilation
--
-- ## Statement count: 4
--
--   1. CREATE TABLE world_priors_axioms
--   2. CREATE INDEX wpa_domain_idx
--   3. CREATE INDEX wpa_evidence_level_idx
--   4. CREATE INDEX wpa_created_at_idx
--
-- ## Column shape
--
--   - axiom_id TEXT PRIMARY KEY — opaque UUID
--   - domain TEXT NOT NULL — joins to world_priors_domains
--   - statement TEXT NOT NULL — the axiom text
--   - evidence_level TEXT NOT NULL CHECK — one of 4 levels
--     (anecdotal / observed / peer_reviewed / mechanistic)
--   - created_at_ms INTEGER NOT NULL

CREATE TABLE IF NOT EXISTS world_priors_axioms (
    axiom_id TEXT PRIMARY KEY NOT NULL,
    domain TEXT NOT NULL,
    statement TEXT NOT NULL,
    evidence_level TEXT NOT NULL CHECK (evidence_level IN
        ('anecdotal', 'observed', 'peer_reviewed', 'mechanistic')),
    created_at_ms INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS wpa_domain_idx
  ON world_priors_axioms(domain);

CREATE INDEX IF NOT EXISTS wpa_evidence_level_idx
  ON world_priors_axioms(evidence_level);

CREATE INDEX IF NOT EXISTS wpa_created_at_idx
  ON world_priors_axioms(created_at_ms);
