-- 002_replay_log — chapter 七百十三 第三刀 / M2238
--
-- Per architectural matrix「SQL:ReplayLog + AuditLog + FTS +
-- indexes」 — append-only event store for the substrate's
-- replay log。 Mirrors the chapter 七百二 第二刀 pattern:
-- canonical SQL file fed to the BASSQLSchemaGen build plugin
-- which emits a Swift Schema enum with `allStatementsSQL` +
-- `statementCount`。
--
-- ## Why this file exists
--
-- Pre-chapter-七百十三,the substrate's replay-event sequence
-- was carried in BASEventLogReplayBundle (Swift Codable
-- struct serialized to JSON blob on append)。 Per the user's
-- language-ownership matrix,SQL should own the on-disk wire
-- format for ReplayLog + AuditLog + FTS + indexes — JSON
-- blobs in Swift are precisely the wrong owner。
--
-- This schema files the typed shape:
--
--   - replay_log_events    : the append-only event table
--   - replay_log_chain_tip : singleton row holding the last
--                            sealed integrity-chain hash
--                            (chapter 七百十二 第一刀 hash chain)
--   - replay_log_fts       : FTS5 virtual table over the event
--                            payload_text column for keyword
--                            search across replay history
--
-- ADR-014 OPT-IN preserved:at this knife the plugin runs and
-- the generated enum is built。 Production wiring (replacing
-- BASEventLogReplayBundle's JSON path with this schema) is
-- deferred to a future knife — the chain-of-custody
-- byte-equality across all existing event-log archives must
-- be verified entry-by-entry before flipping the default。
--
-- ## Statement count: 5
--
--   1. CREATE TABLE replay_log_events           (8 columns)
--   2. CREATE TABLE replay_log_chain_tip        (3 columns)
--   3. CREATE INDEX replay_log_turn_idx
--   4. CREATE INDEX replay_log_session_idx
--   5. CREATE INDEX replay_log_lane_idx
--   6. CREATE VIRTUAL TABLE replay_log_fts (FTS5)
--
-- Updated count: 6
--
-- Generated enum exposes:
--   ReplayLogSchema.allStatementsSQL
--   ReplayLogSchema.statementCount
--
-- ## Doctrine pins held
--
--   - 不变量 #1/#2/#3 — append-only,IF NOT EXISTS idempotent,
--                       chain-tip is invariant under restart
--   - chapter 二百四十八 SQLite idiom — same `runExec` driver
--   - chapter 七百十二 第一刀 — the chain_tip row carries the
--                              SHA256 head over event payloads
--                              so a future verify pass can
--                              call bas_ranker_ledger_verify_chain
--                              and match against this tip
--   - chapter 一百八十五 anti-magic-number — columns + types
--                       pinned in this file are the single
--                       source of truth

CREATE TABLE IF NOT EXISTS replay_log_events (
    event_id TEXT PRIMARY KEY NOT NULL,
    turn_id TEXT NOT NULL,
    session_id TEXT NOT NULL,
    lane TEXT NOT NULL,
    recorded_at_ms INTEGER NOT NULL,
    payload_blob BLOB,
    payload_text TEXT,
    self_hash_b64 TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS replay_log_chain_tip (
    rowid INTEGER PRIMARY KEY CHECK (rowid = 1),
    last_event_id TEXT NOT NULL,
    last_self_hash_b64 TEXT NOT NULL,
    sealed_at_ms INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS replay_log_turn_idx
  ON replay_log_events(turn_id);

CREATE INDEX IF NOT EXISTS replay_log_session_idx
  ON replay_log_events(session_id);

CREATE INDEX IF NOT EXISTS replay_log_lane_idx
  ON replay_log_events(lane);

CREATE VIRTUAL TABLE IF NOT EXISTS replay_log_fts
  USING fts5(
    payload_text,
    content='replay_log_events',
    content_rowid='rowid',
    tokenize='unicode61 remove_diacritics 1'
  );
