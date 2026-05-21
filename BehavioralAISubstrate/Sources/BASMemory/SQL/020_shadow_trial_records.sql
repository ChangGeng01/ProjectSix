-- 020_shadow_trial_records — chapter 七百七十五 / M2526
--
-- L13 PHASE 2 SQL persistence — shadow trial records ledger。
-- Mirrors BASShadowTrialLedgerEntry (Sources/BASMemory/
-- ShadowTrialCoordinator.swift line 593-634) for cold-restart
-- replay + cross-session queries。
--
-- ## Why this table
--
-- Phase 1 (chapter 七百七十二) extracted the protocol seam。
-- Phase 2 first cut (chapter 七百七十四) ported the state machine
-- to Rust。 This chapter persists the ledger entries the
-- coordinator emits on every transition,enabling:
--   - Cold-restart replay (chapter 392 invariant)
--   - Per-session audit queries ("show me all shadow trials in
--     session X")
--   - Per-verdict joins to L14 verdict_decisions table
--
-- ## ADR-014 OPT-IN preserved
--
-- Schema lands unconditionally。 V1 BASInMemoryShadowTrialLedger
-- (chapter 七百七十二 line 653) stays the live default。 Hosts opt
-- in to persistence via a future BASSQLiteShadowTrialLedger
-- adapter that conforms to BASShadowTrialLedger protocol。
--
-- ## Statement count: 5
--
--   1. CREATE TABLE shadow_trial_records
--   2. CREATE INDEX str_session_idx
--   3. CREATE INDEX str_turn_idx
--   4. CREATE INDEX str_verdict_ref_idx
--   5. CREATE INDEX str_event_kind_idx
--
-- ## Doctrine pins held
--
--   - 不变量 #1/#2/#3 — append-only (INSERT only,never UPDATE)
--   - 红线 7 — additive on dest;V1 in-memory ledger untouched
--   - chapter 一百八十五 — event_kind CHECK pins the small
--     vocabulary the coordinator emits (5 values per the Swift
--     doc comment + Phase 2 transition outputs)
--   - chapter 392 replay-determinism — appended_at_ms is
--     monotonic within a session,enabling deterministic replay
--   - 「不要 json 可以的话 就 sql」 — rule_ids / signal_refs /
--     action_refs are variadic string lists,kept as JSON
--     columns per the chapter 七百六十八 precedent (variadic
--     cardinality without join-table overhead for a feature
--     only audit-query code consults)
--
-- ## Column shape
--
--   - audit_id TEXT PRIMARY KEY — opaque UUID (caller-generated)
--   - session_id TEXT NOT NULL — joins to L14 session
--   - turn_id TEXT NOT NULL — single-turn provenance
--   - verdict_ref TEXT NOT NULL — joins to verdict_decisions
--   - rule_ids_json TEXT — JSON list of rule_ids referenced
--   - signal_refs_json TEXT — JSON list of signal references
--   - action_refs_json TEXT — JSON list of action references
--   - snapshot_ref TEXT NOT NULL — opaque snapshot reference
--   - signature_payload TEXT NOT NULL — signature/HMAC string
--   - appended_at_ms INTEGER NOT NULL — UNIX epoch ms
--   - event_kind TEXT NOT NULL CHECK — pinned vocabulary

CREATE TABLE IF NOT EXISTS shadow_trial_records (
    audit_id TEXT PRIMARY KEY NOT NULL,
    session_id TEXT NOT NULL,
    turn_id TEXT NOT NULL,
    verdict_ref TEXT NOT NULL,
    rule_ids_json TEXT,
    signal_refs_json TEXT,
    action_refs_json TEXT,
    snapshot_ref TEXT NOT NULL,
    signature_payload TEXT NOT NULL,
    appended_at_ms INTEGER NOT NULL,
    event_kind TEXT NOT NULL CHECK (event_kind IN
        ('shadow_trial_started',
         'shadow_trial_passed',
         'shadow_trial_failed',
         'shadow_trial_blocked',
         'shadow_trial_cancelled'))
);

CREATE INDEX IF NOT EXISTS str_session_idx
  ON shadow_trial_records(session_id, appended_at_ms);

CREATE INDEX IF NOT EXISTS str_turn_idx
  ON shadow_trial_records(turn_id);

CREATE INDEX IF NOT EXISTS str_verdict_ref_idx
  ON shadow_trial_records(verdict_ref);

CREATE INDEX IF NOT EXISTS str_event_kind_idx
  ON shadow_trial_records(event_kind);
