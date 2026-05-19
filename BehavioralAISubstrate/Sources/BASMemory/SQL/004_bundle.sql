-- 004_bundle — chapter 七百十四 第二刀 / M2242
--
-- Per architectural matrix「SQL:... Bundle ...」 — moves the
-- substrate's bundle (= named set of memory atoms grouped
-- under one episode for retrieval/projection) wire format
-- from Swift Codable JSON into a first-class SQL schema fed
-- through BASSQLSchemaGen。
--
-- ## What a "bundle" is
--
-- A typed collection of memory atoms grouped for downstream
-- retrieval / projection。 Each bundle:
--   - belongs to exactly one episode (episode_id FK)
--   - has a canonical SHA256 hash over its ordered atom-id
--     set (`canonical_hash_hex`)
--   - carries a typed kind (e.g。 "retrieval-context",
--     "projection-snapshot",etc) for routing
--   - is closed under atom membership at seal time (no
--     post-seal mutation of the membership list)
--
-- Membership is normalized into a separate `bundle_atoms`
-- table so atom-set queries can use B-tree indexes instead
-- of parsing a JSON blob inside the row。
--
-- ## Statement count: 8
--
--   1. CREATE TABLE bundle_records              (7 columns)
--   2. CREATE TABLE bundle_atoms                (3 columns + PK)
--   3. CREATE INDEX bundle_episode_idx
--   4. CREATE INDEX bundle_kind_idx
--   5. CREATE INDEX bundle_atoms_atom_idx
--   6. CREATE INDEX bundle_atoms_bundle_idx
--   7. CREATE VIRTUAL TABLE bundle_fts (FTS5)
--   8. (note:1 trigger SKIPPED — sealed-bundle immutability
--             enforced at the application layer for now;
--             schema-level trigger added in a future knife
--             once the Codable migration sequence is locked)
--
-- Updated count:7 statements
--
-- Generated enum exposes:
--   BundleSchema.allStatementsSQL
--   BundleSchema.statementCount
--
-- ## Doctrine pins held
--
--   - 不变量 #1/#2/#3 — append-only at bundle-records level;
--                       bundle_atoms is monotonic per bundle
--                       (members only added during open state)
--   - chapter 七百十二 第一刀 — `canonical_hash_hex` carries the
--                              SHA256 over the ordered atom-id
--                              sequence,used as the integrity
--                              gate for downstream retrieval
--   - chapter 二百四十八 SQLite idiom — same `runExec` driver

CREATE TABLE IF NOT EXISTS bundle_records (
    bundle_id TEXT PRIMARY KEY NOT NULL,
    episode_id TEXT NOT NULL,
    kind TEXT NOT NULL,
    sealed_at_ms INTEGER,
    state TEXT NOT NULL CHECK (state IN ('open', 'sealed')),
    summary_text TEXT,
    canonical_hash_hex TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS bundle_atoms (
    bundle_id TEXT NOT NULL,
    atom_id TEXT NOT NULL,
    sequence_index INTEGER NOT NULL,
    PRIMARY KEY (bundle_id, sequence_index)
);

CREATE INDEX IF NOT EXISTS bundle_episode_idx
  ON bundle_records(episode_id);

CREATE INDEX IF NOT EXISTS bundle_kind_idx
  ON bundle_records(kind);

CREATE INDEX IF NOT EXISTS bundle_atoms_atom_idx
  ON bundle_atoms(atom_id);

CREATE INDEX IF NOT EXISTS bundle_atoms_bundle_idx
  ON bundle_atoms(bundle_id);

CREATE VIRTUAL TABLE IF NOT EXISTS bundle_fts
  USING fts5(
    summary_text,
    content='bundle_records',
    content_rowid='rowid',
    tokenize='unicode61 remove_diacritics 1'
  );
