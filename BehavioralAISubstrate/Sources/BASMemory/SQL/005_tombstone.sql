-- 005_tombstone — chapter 七百十四 第三刀 / M2243
--
-- Per architectural matrix「SQL:... Tombstone ...」 — moves
-- the substrate's tombstone (= soft-delete marker for redacted
-- memory atoms / episodes / bundles) wire format from Swift
-- Codable JSON into a first-class SQL schema fed through
-- BASSQLSchemaGen。
--
-- ## What a "tombstone" is
--
-- An append-only marker that a memory record (atom/episode/
-- bundle) has been redacted。 Tombstones are NEVER deleted
-- themselves — redaction is monotonic。 Each tombstone:
--   - has an opaque tombstone_id
--   - points to a target via (target_kind, target_ref) pair
--   - carries a typed redaction_reason
--   - is sealed under a ledger_self_hash linking it to the
--     chapter 七百十二 audit chain
--   - has an immutable sealed_at_ms timestamp
--
-- ## Why "monotonic" matters
--
-- The substrate-level invariant is:once tombstoned,a record
-- stays tombstoned forever。 A future "un-tombstone" operation
-- is itself a new event,not a row mutation。 This means:
--   - tombstone_records is append-only at the SQLite level
--   - the (target_kind, target_ref) tuple is unique — every
--     target can be tombstoned at most once
--   - audit replay can derive "is X redacted?" as a single
--     INDEXED EXISTS query rather than a Codable scan
--
-- ## Statement count: 7
--
--   1. CREATE TABLE tombstone_records           (7 columns)
--   2. CREATE UNIQUE INDEX tombstone_target_idx
--   3. CREATE INDEX tombstone_target_kind_idx
--   4. CREATE INDEX tombstone_sealed_at_idx
--   5. CREATE INDEX tombstone_ledger_idx
--   6. CREATE VIRTUAL TABLE tombstone_fts (FTS5)
--   7. (the unique-on-target invariant is enforced via
--       UNIQUE INDEX rather than a separate constraint)
--
-- Generated enum exposes:
--   TombstoneSchema.allStatementsSQL
--   TombstoneSchema.statementCount
--
-- ## Doctrine pins held
--
--   - 不变量 #1/#2/#3 — append-only at row level + monotonic
--                       redaction state
--   - chapter 七百十二 第一刀 — ledger_self_hash_b64 links every
--                              tombstone to the audit chain
--                              so replay can verify no
--                              tombstone was injected post-hoc
--   - chapter 一百八十五 anti-magic-number — target_kind
--                       enumerable as TEXT with CHECK

CREATE TABLE IF NOT EXISTS tombstone_records (
    tombstone_id TEXT PRIMARY KEY NOT NULL,
    target_kind TEXT NOT NULL CHECK (target_kind IN
        ('atom', 'episode', 'bundle')),
    target_ref TEXT NOT NULL,
    redaction_reason TEXT NOT NULL,
    redaction_detail_text TEXT,
    sealed_at_ms INTEGER NOT NULL,
    ledger_self_hash_b64 TEXT NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS tombstone_target_idx
  ON tombstone_records(target_kind, target_ref);

CREATE INDEX IF NOT EXISTS tombstone_target_kind_idx
  ON tombstone_records(target_kind);

CREATE INDEX IF NOT EXISTS tombstone_sealed_at_idx
  ON tombstone_records(sealed_at_ms);

CREATE INDEX IF NOT EXISTS tombstone_ledger_idx
  ON tombstone_records(ledger_self_hash_b64);

CREATE VIRTUAL TABLE IF NOT EXISTS tombstone_fts
  USING fts5(
    redaction_detail_text,
    content='tombstone_records',
    content_rowid='rowid',
    tokenize='unicode61 remove_diacritics 1'
  );
