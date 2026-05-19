-- 010_chapter_doctrine_records_schema — chapter 七百二 第一刀 / M2167
--
-- SQL port of the chapter doctrine record literal block。
-- Per user directive 「不要 json 可以的话 就 sql」,the original
-- Swift literal data lives here as SQL DDL + INSERT statements。
--
-- Original Swift literals are PRESERVED in their source files
-- inside `/* */` block comments per user directive 「目前 千万
-- 不要 删除 只能 commented 代码」。 LOC counter strips the
-- comments before tallying。
--
-- ## Schema layout (5 tables, normalized)
--
--   - chapter_doctrine_records: one row per chapter record
--   - chapter_doctrine_knives:  child table for the `knives`
--                               nested array
--   - chapter_doctrine_entropy_classes / pins / planned_cuts:
--                               3 child tables for the 3 string
--                               arrays inside each record
--
-- ## Collection discriminator
--
-- `collection_tag` partitions rows by which Swift static-let
-- they came from:
--   - 'literals' → BASChapterDoctrineRegistryAllLiterals.all
--                  (61 chapters 403-463)
--   - 'phase2'   → BASChapterDoctrineRegistry phase2 inline
--                  records (registry-native from chapter 464+)
--
-- ## Frozen-hash invariant
--
-- `BASRegistryFrozenHashTests.testRegistryLiteralsHaveStableHash`
-- + `testFullRegistryHasStableHash` assert the SHA256 of
-- `JSONEncoder.encode(...)` (with sortedKeys) against a frozen
-- hex string。 The SQLite loader reconstructs identical
-- `[BASChapterDoctrineRecord]` arrays;Codable round-trip
-- preserves field bytes;SHA256 stays green。

CREATE TABLE IF NOT EXISTS chapter_doctrine_records (
    collection_ordinal     INTEGER NOT NULL,
    chapter_ordinal        INTEGER NOT NULL,
    collection_tag         TEXT    NOT NULL,
    chapter_tag            TEXT    NOT NULL,
    m_number_first         INTEGER NOT NULL,
    m_number_last          INTEGER NOT NULL,
    v1_milestone_m_number  INTEGER NOT NULL,
    v1_milestone_status    TEXT    NOT NULL,
    summary                TEXT    NOT NULL,
    PRIMARY KEY (collection_ordinal, chapter_ordinal)
);

CREATE TABLE IF NOT EXISTS chapter_doctrine_knives (
    collection_ordinal INTEGER NOT NULL,
    chapter_ordinal    INTEGER NOT NULL,
    knife_ordinal      INTEGER NOT NULL,
    m_number           INTEGER NOT NULL,
    knife              TEXT    NOT NULL,
    concept            TEXT    NOT NULL,
    PRIMARY KEY (collection_ordinal, chapter_ordinal, knife_ordinal)
);

CREATE TABLE IF NOT EXISTS chapter_doctrine_entropy_classes (
    collection_ordinal INTEGER NOT NULL,
    chapter_ordinal    INTEGER NOT NULL,
    item_ordinal       INTEGER NOT NULL,
    value              TEXT    NOT NULL,
    PRIMARY KEY (collection_ordinal, chapter_ordinal, item_ordinal)
);

CREATE TABLE IF NOT EXISTS chapter_doctrine_pins (
    collection_ordinal INTEGER NOT NULL,
    chapter_ordinal    INTEGER NOT NULL,
    item_ordinal       INTEGER NOT NULL,
    value              TEXT    NOT NULL,
    PRIMARY KEY (collection_ordinal, chapter_ordinal, item_ordinal)
);

CREATE TABLE IF NOT EXISTS chapter_doctrine_planned_cuts (
    collection_ordinal INTEGER NOT NULL,
    chapter_ordinal    INTEGER NOT NULL,
    item_ordinal       INTEGER NOT NULL,
    value              TEXT    NOT NULL,
    PRIMARY KEY (collection_ordinal, chapter_ordinal, item_ordinal)
);

CREATE INDEX IF NOT EXISTS chapter_doctrine_by_tag
  ON chapter_doctrine_records(chapter_tag);
