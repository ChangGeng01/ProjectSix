-- 011_unknown_ledger_records — chapter 七百六十五 / M2476
--
-- DEEPER LAYER-MIGRATION ARC L7 unknown-ledger persistence schema。
-- Net-new table for the「known unknown」 records the L7 Mirror Blade
-- decomposition pipeline accumulates per turn。 Additive to the existing
-- BASSovereign / BASPolicy / BASMemory schema family (chapter 七百四十二
-- 第三刀 / M2383 pattern)。
--
-- ## Why this table
--
-- Per chapter 七百六十四 (bas-mirror-blade) the L7 decomposition pipeline
-- emits `DecomposeState::Unknown` whenever the classifier flags low-
-- confidence ambiguity (ambiguity_score >= 0.6)。 The Swift actor
-- (BASMLDecomposeService) currently emits these signals into an
-- in-memory string array;they don't survive process restart and aren't
-- queryable for cross-session pattern detection。
--
-- This schema PERSISTS each unknown record so:
--   - Replay determinism:re-running a session reproduces the same
--     unknown set (chapter 392 invariant)
--   - Cross-session queries:「how often does「ambiguity > 0.6」 fire
--     during memory_promote tasks?」 → indexed query
--   - Audit trail:auditors can replay a verdict's input arrays from
--     persisted rows
--
-- ## ADR-014 OPT-IN preserved
--
-- Schema lands unconditionally。 V1 in-memory path stays the live
-- default;hosts opt in by wiring a SQLite storage adapter that
-- writes rows to this table per turn。 Dropping the table doesn't
-- affect V1 behavior。
--
-- ## Statement count: 4
--
--   1. CREATE TABLE unknown_ledger_records
--   2. CREATE INDEX ul_session_idx
--   3. CREATE INDEX ul_turn_idx
--   4. CREATE INDEX ul_confidence_idx
--
-- ## Doctrine pins held
--
--   - 不变量 #1/#2/#3 — append-only (INSERT-only)
--   - 红线 7 — additive on dest;Swift in-memory path untouched
--   - chapter 一百八十五 — confidence stored as REAL [0,1],pinned by
--                     CHECK constraint
--   - chapter 392 replay-determinism — discovered_at_ms is monotonic
--                     within a session
--   - 「不要 json 可以的话 就 sql」 — unknown_text TEXT,confidence
--                     REAL,discovered_at_ms INTEGER — no JSON columns
--
-- ## Column shape rationale
--
--   - event_id TEXT PRIMARY KEY — opaque UUID
--   - session_id TEXT NOT NULL — joins to L14 session
--   - turn_id TEXT NOT NULL — single-turn provenance
--   - unknown_text TEXT NOT NULL — the「unknown」 signal ID (mirrors
--                                   `BASMLDecomposeService.Signals.lowConfidenceClassification`
--                                   = "decompose.low_confidence_classification")
--   - confidence REAL NOT NULL CHECK [0, 1] — classifier confidence at
--                                              the moment the unknown
--                                              was flagged
--   - discovered_at_ms INTEGER NOT NULL — UNIX epoch ms timestamp

CREATE TABLE IF NOT EXISTS unknown_ledger_records (
    event_id TEXT PRIMARY KEY NOT NULL,
    session_id TEXT NOT NULL,
    turn_id TEXT NOT NULL,
    unknown_text TEXT NOT NULL,
    confidence REAL NOT NULL CHECK (confidence >= 0.0 AND confidence <= 1.0),
    discovered_at_ms INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS ul_session_idx
  ON unknown_ledger_records(session_id, discovered_at_ms);

CREATE INDEX IF NOT EXISTS ul_turn_idx
  ON unknown_ledger_records(turn_id);

CREATE INDEX IF NOT EXISTS ul_confidence_idx
  ON unknown_ledger_records(confidence);
