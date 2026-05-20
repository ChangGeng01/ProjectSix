-- 030_knowledge_graph_v2_migration — chapter 七百四十四 第三刀 / M2393
--
-- LAYER-MIGRATION ARC L3 Knowledge Graph storage V2 binary
-- wire-format migration。 Mirrors the chapter 七百三十二 第一刀
-- pattern that added payload_format column to replay_log_events
-- for the event log codec dual-read。
--
-- Per user directive 2026-05-20:
--
--   「真正应该移植的是每层里的 热路径、状态机、持久化、审计、数学计算。」
--   「不要 json 可以的话 就 sql」
--
-- ## What this migration adds
--
-- ALTER existing knowledge_node + knowledge_edge tables to gain
-- two columns enabling DUAL-READ codec dispatch:
--
--   payload_format INTEGER NOT NULL DEFAULT 1
--     1 = legacy Swift Codable JSON path (existing rows)
--     2 = chapter 七百四十四 Rust binary codec (new rows)
--   payload_blob BLOB
--     NULL for v1 rows
--     The V2 binary canonical bytes for v2 rows
--     (encoded by Cargo/bas-event-log-codec/src/
--      knowledge_graph_codec.rs)
--
-- Lazy upgrade-on-read:reader detects payload_format column
-- per row and dispatches to JSON-decode (v1) or binary-decode
-- (v2)。 V1 rows are NEVER migrated — they stay JSON forever。
-- New writes can choose format based on a feature flag。
--
-- ## ADR-014 OPT-IN preserved
--
-- Schema migration lands unconditionally。 The legacy
-- BASSQLiteKnowledgeGraphStorage code path continues to write
-- v1 (payload_json + payload_format default 1)。 The new
-- binary path activates only when chapter 七百四十四 第四刀
-- flag is on。
--
-- ## Statement count: 4
--
--   1. ALTER TABLE knowledge_node ADD payload_format INTEGER
--      NOT NULL DEFAULT 1
--   2. ALTER TABLE knowledge_node ADD payload_blob BLOB
--   3. ALTER TABLE knowledge_edge ADD payload_format INTEGER
--      NOT NULL DEFAULT 1
--   4. ALTER TABLE knowledge_edge ADD payload_blob BLOB
--
-- Generated enum exposes:
--   KnowledgeGraphV2MigrationSchema.allStatementsSQL
--   KnowledgeGraphV2MigrationSchema.statementCount
--
-- ## Doctrine pins held
--
--   - 不变量 #1/#2/#3 — append-only:ALTER ADD COLUMN is
--                       additive,never destructive。 Existing
--                       v1 rows keep their payload_json
--                       intact + gain payload_format = 1
--                       via DEFAULT clause。
--   - 红线 7 — additive on dest;BASSQLiteKnowledgeGraph
--             Storage Swift surface untouched at this knife。
--   - chapter 一百八十五 — payload_format raw values pinned
--                       (1 = JSON, 2 = binary);no CHECK
--                       constraint because SQLite ALTER
--                       can't add CHECK in older versions —
--                       Swift writer enforces。
--   - chapter 392 — boot-and-read produces same row set
--                   regardless of which codec wrote each row
--   - chapter 七百二十四 + 七百三十二 — dual-read codec
--                                     migration pattern reused
--   - 「不要 json 可以的话 就 sql」 — payload_blob is binary
--                       canonical bytes;payload_json column
--                       retained for v1 backward compat per
--                       「依旧 不删除 只 comment」 invariant
--                       (V1 rows never migrate)
--
-- ## Migration safety
--
-- ALTER TABLE ADD COLUMN is non-destructive on SQLite:
--   - O(1) (just metadata change,no row-rewrite)
--   - Atomic (no partial state)
--   - Reversible by dropping/recreating the table (which
--     we never do — chapter 七百二 第二刀 chain-of-custody
--     pin)
--
-- If a DB has been pre-migrated (column already exists),the
-- ALTER will fail with a SQLITE_ERROR。 Hosts running both
-- pre- and post- migration code must catch that error and
-- silently continue。 The chapter 七百三十二 pattern handles
-- this via try/catch around the ALTER。

ALTER TABLE knowledge_node
  ADD COLUMN payload_format INTEGER NOT NULL DEFAULT 1;

ALTER TABLE knowledge_node
  ADD COLUMN payload_blob BLOB;

ALTER TABLE knowledge_edge
  ADD COLUMN payload_format INTEGER NOT NULL DEFAULT 1;

ALTER TABLE knowledge_edge
  ADD COLUMN payload_blob BLOB;
