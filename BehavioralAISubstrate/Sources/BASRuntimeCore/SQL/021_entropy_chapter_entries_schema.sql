-- 021_entropy_chapter_entries_schema — chapter 七百二 第三刀
--
-- SQL port of the entropy chapter index literal block。
-- One-table denormalized schema (BASEntropyChapterEntry has 8
-- scalar fields and no nested arrays,so per-row is sufficient)。
--
-- Original Swift literals are PRESERVED in BASEntropyChapterIndex
-- .swift inside `/* */` block comments per user directive。
--
-- ## Collection discriminator
--
-- `collection_tag`:
--   - 'radical'   → BASEntropyChapterIndex.radicalEvolutionEntries
--   - 'phase2'    → BASEntropyChapterIndex.phase2Entries
--   - 'postSweep' → BASEntropyChapterIndex.postSweepRealExecutionEntries

CREATE TABLE IF NOT EXISTS entropy_chapter_entries (
    collection_tag         TEXT    NOT NULL,
    item_ordinal           INTEGER NOT NULL,
    chapter_tag            TEXT    NOT NULL,
    m_number_first         INTEGER NOT NULL,
    m_number_last          INTEGER NOT NULL,
    knives_count           INTEGER NOT NULL,
    entropy_classes_count  INTEGER NOT NULL,
    pins_count             INTEGER NOT NULL,
    future_cuts_count      INTEGER NOT NULL,
    summary                TEXT    NOT NULL,
    PRIMARY KEY (collection_tag, item_ordinal)
);

CREATE INDEX IF NOT EXISTS entropy_chapter_by_tag
  ON entropy_chapter_entries(chapter_tag);
