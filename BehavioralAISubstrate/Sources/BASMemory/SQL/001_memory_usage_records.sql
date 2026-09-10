-- 001_memory_usage_records — chapter 七百二 / M2172 第二刀
--
-- L8 memory retrieval usage log schema。 Extracted verbatim
-- from BASMemoryUsageTracker.swift:321-341 (chapter 二百五十一
-- / M738)。 Schema version pinned at BASMemoryUsageTracker
-- .schemaVersion = 1。
--
-- ## Why this file exists
--
-- chapter 七百二 SQL pilot (per MULTI-LANGUAGE AUGMENTATION
-- ARC at chapter 七百一)takes ONE embedded SQL block out of
-- the inline `runExec` call sites and makes it a first-class
-- `.sql` file driven by the BASSQLSchemaGen build plugin
-- (M2171 第一刀)。 At build time the plugin emits
-- `001_memory_usage_records.generated.swift` containing
-- `public enum MemoryUsageRecordsSchema { ... }`。
--
-- ## ADR-014 OPT-IN preserved
--
-- At M2172 (this commit)the plugin runs but
-- BASMemoryUsageTracker.swift is UNCHANGED — the inline
-- `let` strings inside `ensureSchema(db:)` are still the
-- live path。 The generated enum is built but unused。
--
-- M2173 第三刀 wires BASMemoryUsageTracker behind
-- `BASLanguageAugmentationFeatureFlags.sqlMigratorEnabled`
-- (default false → V1 inline path)。
--
-- ## Doctrine pins held
--
--   - 不变量 #1 / #2 / #3 — schema is observability storage;
--     CREATE statements with IF NOT EXISTS are idempotent
--     so byte-equality of the on-disk database is preserved
--     across both code paths。
--   - chapter 二百四十八 SQLite idiom — same `runExec` driver
--     consumes either the inline string or the GENERATED
--     `allStatementsSQL` (M2173 chooses)。
--   - chapter 一百八十五 anti-magic-number — column types
--     pinned in this SQL file are the single source of
--     truth for the schema's wire shape。
--
-- ## Statement count: 3
--
--   1. CREATE TABLE memory_usage_records (7 columns)
--   2. CREATE INDEX memory_usage_atom_idx
--   3. CREATE INDEX memory_usage_session_idx
--
-- Generated enum exposes:
--   MemoryUsageRecordsSchema.allStatementsSQL — concatenated SQL
--   MemoryUsageRecordsSchema.statementCount  — 3

CREATE TABLE IF NOT EXISTS memory_usage_records (
    record_id TEXT PRIMARY KEY NOT NULL,
    atom_id TEXT NOT NULL,
    retrieved_at_ms INTEGER NOT NULL,
    session_ref TEXT NOT NULL,
    turn_ref TEXT NOT NULL,
    permit_mode TEXT NOT NULL,
    helped_state TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS memory_usage_atom_idx
  ON memory_usage_records(atom_id);

CREATE INDEX IF NOT EXISTS memory_usage_session_idx
  ON memory_usage_records(session_ref);
