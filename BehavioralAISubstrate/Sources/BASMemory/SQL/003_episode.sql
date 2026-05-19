-- 003_episode — chapter 七百十四 第一刀 / M2241
--
-- Per architectural matrix「SQL:MemoryAtom + Episode + Bundle
-- + ReplayLog + AuditLog + Tombstone + FTS + indexes」 — moves
-- the substrate's episode (= temporally-bounded sequence of
-- related memory events) wire format from Swift Codable JSON
-- into a first-class SQL schema fed through BASSQLSchemaGen
-- (chapter 七百二 第一刀)。
--
-- ## Why this file exists
--
-- Pre-chapter-七百十四,episodes were carried in Swift Codable
-- structs serialized to JSON blobs。 Per the matrix,SQL should
-- own the on-disk wire format for the structured Memory
-- hierarchy (Atom → Episode → Bundle)。
--
-- An "episode" is a coherent sequence of memory events with:
--   - opaque ID
--   - originating session
--   - clock-bounded interval [started_at_ms,ended_at_ms]
--   - a `summary_text` projection for FTS5 lookup
--   - an integrity hash carrying the chapter-七百十二 chain link
--   - a closure state (open / sealed / abandoned)
--
-- ## Statement count: 5
--
--   1. CREATE TABLE episode_records          (8 columns)
--   2. CREATE INDEX episode_session_idx
--   3. CREATE INDEX episode_state_idx
--   4. CREATE INDEX episode_started_at_idx
--   5. CREATE VIRTUAL TABLE episode_fts (FTS5)
--
-- Generated enum exposes:
--   EpisodeSchema.allStatementsSQL
--   EpisodeSchema.statementCount
--
-- ## Doctrine pins held
--
--   - 不变量 #1/#2/#3 — append-only at the row level (rows are
--                       updated only by state transitions
--                       open→sealed/abandoned)
--   - chapter 二百四十八 SQLite idiom — same `runExec` driver
--   - chapter 七百十二 第一刀 — `chain_self_hash_b64` carries the
--                              SHA256 head over the canonical
--                              episode payload for replay verify
--   - chapter 一百八十五 anti-magic-number — column shapes pinned

CREATE TABLE IF NOT EXISTS episode_records (
    episode_id TEXT PRIMARY KEY NOT NULL,
    session_id TEXT NOT NULL,
    started_at_ms INTEGER NOT NULL,
    ended_at_ms INTEGER,
    state TEXT NOT NULL CHECK (state IN ('open', 'sealed', 'abandoned')),
    summary_text TEXT,
    canonical_payload_blob BLOB,
    chain_self_hash_b64 TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS episode_session_idx
  ON episode_records(session_id);

CREATE INDEX IF NOT EXISTS episode_state_idx
  ON episode_records(state);

CREATE INDEX IF NOT EXISTS episode_started_at_idx
  ON episode_records(started_at_ms);

CREATE VIRTUAL TABLE IF NOT EXISTS episode_fts
  USING fts5(
    summary_text,
    content='episode_records',
    content_rowid='rowid',
    tokenize='unicode61 remove_diacritics 1'
  );
