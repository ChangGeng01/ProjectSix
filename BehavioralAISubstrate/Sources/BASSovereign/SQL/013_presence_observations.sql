-- 013_presence_observations — chapter 七百六十七 / M2486
--
-- DEEPER LAYER-MIGRATION ARC L6 presence-observations persistence
-- schema。 Net-new table for the multi-channel presence signals
-- emitted by the L6 Presence Eye classifier (chapter 七百六十六
-- bas-presence-eye)。
--
-- ## Why this table
--
-- Per chapter 七百六十六 the L6 fusion classifier emits a unified
-- presence confidence per turn from 5 PresenceChannel
-- observations (task / risk / manipulation / environment /
-- bodyRhythm)。 The Swift actor currently keeps these in memory
-- only;persistence enables:
--   - Cross-turn drift detection (is manipulation rising over the
--     session?)
--   - Cold-restart replay (chapter 392 invariant)
--   - Per-channel aggregation queries
--
-- ## ADR-014 OPT-IN preserved
--
-- Schema lands unconditionally。 V1 in-memory path stays the live
-- default。 Hosts opt in by supplying a SQLite storage adapter
-- (per chapter 七百五十四 sharedStorage slot pattern)。
--
-- ## Statement count: 5
--
--   1. CREATE TABLE presence_observations
--   2. CREATE INDEX po_session_idx
--   3. CREATE INDEX po_turn_idx
--   4. CREATE INDEX po_channel_idx
--   5. CREATE INDEX po_confidence_idx
--
-- ## Column shape rationale
--
--   - event_id TEXT PRIMARY KEY — opaque UUID
--   - session_id TEXT NOT NULL
--   - turn_id TEXT NOT NULL
--   - channel_kind TEXT NOT NULL CHECK — one of the 5
--     PresenceChannel raw strings (mirrors Rust enum case names)
--   - salience REAL NOT NULL CHECK [0, 1] — channel-emitted strength
--   - confidence REAL NOT NULL CHECK [0, 1] — classifier confidence
--   - observed_at_ms INTEGER NOT NULL — UNIX epoch ms

CREATE TABLE IF NOT EXISTS presence_observations (
    event_id TEXT PRIMARY KEY NOT NULL,
    session_id TEXT NOT NULL,
    turn_id TEXT NOT NULL,
    channel_kind TEXT NOT NULL
        CHECK (channel_kind IN
            ('task', 'risk', 'manipulation',
             'environment', 'bodyRhythm')),
    salience REAL NOT NULL CHECK (salience >= 0.0 AND salience <= 1.0),
    confidence REAL NOT NULL CHECK (confidence >= 0.0 AND confidence <= 1.0),
    observed_at_ms INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS po_session_idx
  ON presence_observations(session_id, observed_at_ms);

CREATE INDEX IF NOT EXISTS po_turn_idx
  ON presence_observations(turn_id);

CREATE INDEX IF NOT EXISTS po_channel_idx
  ON presence_observations(channel_kind);

CREATE INDEX IF NOT EXISTS po_confidence_idx
  ON presence_observations(confidence);
