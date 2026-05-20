-- 012_contradiction_ledger_records — chapter 七百六十五 / M2477
--
-- DEEPER LAYER-MIGRATION ARC L7 contradiction-ledger persistence schema。
-- Net-new table for the contradiction signals the L7 Mirror Blade
-- decomposition pipeline emits when a tense relation pattern is
-- detected (mirrors Swift line 127-130 + chapter 七百六十四 bas-mirror-
-- blade DecomposeState::Contradiction)。
--
-- Pairs with 011_unknown_ledger_records.sql to provide the complete
-- per-turn signal persistence layer for L7。
--
-- ## ADR-014 OPT-IN preserved
--
-- Schema lands unconditionally。 V1 in-memory path stays the live
-- default;hosts opt in by wiring a SQLite storage adapter。
--
-- ## Statement count: 5
--
--   1. CREATE TABLE contradiction_ledger_records
--   2. CREATE INDEX cl_session_idx
--   3. CREATE INDEX cl_turn_idx
--   4. CREATE INDEX cl_salience_idx
--   5. CREATE INDEX cl_resolved_idx
--
-- ## Column shape rationale
--
--   - event_id TEXT PRIMARY KEY — opaque UUID
--   - session_id TEXT NOT NULL — joins to L14 session
--   - turn_id TEXT NOT NULL — single-turn provenance
--   - contradiction_text TEXT NOT NULL — the contradiction signal ID
--                                         (mirrors
--                                         `BASMLDecomposeService.Signals
--                                          .conflictPattern`
--                                         = "decompose.conflict_pattern")
--   - salience REAL NOT NULL CHECK [0, 1] — how strong the
--                                            contradiction reading was
--   - confidence REAL NOT NULL CHECK [0, 1] — classifier confidence
--   - resolved INTEGER NOT NULL CHECK (0, 1) — boolean encoded as
--                                              0/1。 Default 0;flipped
--                                              to 1 when a follow-up
--                                              turn observes the
--                                              contradiction resolved
--   - resolved_at_ms INTEGER — UNIX epoch ms when resolved;NULL when
--                              still open

CREATE TABLE IF NOT EXISTS contradiction_ledger_records (
    event_id TEXT PRIMARY KEY NOT NULL,
    session_id TEXT NOT NULL,
    turn_id TEXT NOT NULL,
    contradiction_text TEXT NOT NULL,
    salience REAL NOT NULL CHECK (salience >= 0.0 AND salience <= 1.0),
    confidence REAL NOT NULL CHECK (confidence >= 0.0 AND confidence <= 1.0),
    resolved INTEGER NOT NULL DEFAULT 0
        CHECK (resolved IN (0, 1)),
    resolved_at_ms INTEGER
);

CREATE INDEX IF NOT EXISTS cl_session_idx
  ON contradiction_ledger_records(session_id, turn_id);

CREATE INDEX IF NOT EXISTS cl_turn_idx
  ON contradiction_ledger_records(turn_id);

CREATE INDEX IF NOT EXISTS cl_salience_idx
  ON contradiction_ledger_records(salience);

CREATE INDEX IF NOT EXISTS cl_resolved_idx
  ON contradiction_ledger_records(resolved);
