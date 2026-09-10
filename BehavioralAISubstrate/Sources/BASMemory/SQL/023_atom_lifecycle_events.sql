-- 023_atom_lifecycle_events — chapter 七百八十四 / M2571
--
-- L8 atom-lifecycle persistence schema。 Pairs with the
-- chapter 七百八十二 bas-atom-lifecycle Rust state machine to
-- provide append-only event log for memory atom phase
-- transitions。
--
-- ## Why this table
--
-- L8's BASMemoryAtomStore currently keeps atom-phase state
-- in-memory in the Swift actor。 Persisting phase transitions
-- enables:
--   - Cold-restart replay (chapter 392 invariant — actor
--     reconstructs in-memory state from event log)
--   - Per-session audit (which atoms transitioned + when)
--   - Cross-session GC (find atoms tombstoned >7 days ago
--     for hard-delete pass)
--   - Phase distribution telemetry
--
-- ## ADR-014 OPT-IN preserved
--
-- Schema lands unconditionally。 V1 in-memory atom store
-- continues to work without writing to this table。 Hosts
-- opt in to persistence via a future BASSQLiteAtomLifecycleStore
-- adapter (out of scope this chapter)。
--
-- ## Statement count: 5
--
--   1. CREATE TABLE atom_lifecycle_events
--   2. CREATE INDEX ale_atom_idx
--   3. CREATE INDEX ale_session_idx
--   4. CREATE INDEX ale_phase_idx
--   5. CREATE INDEX ale_recorded_at_idx
--
-- ## Column shape
--
--   - event_id TEXT PRIMARY KEY — opaque UUID
--   - atom_id TEXT NOT NULL — the memory atom this event belongs to
--   - session_id TEXT NOT NULL — joins to L14 session
--   - from_phase TEXT NOT NULL CHECK — pre-transition phase
--   - to_phase TEXT NOT NULL CHECK — post-transition phase
--   - action TEXT NOT NULL CHECK — admit/link/archive/tombstone
--   - outcome TEXT NOT NULL CHECK — advanced/rejected_illegal/
--                                    rejected_terminal
--   - recorded_at_ms INTEGER NOT NULL — UNIX epoch ms
--   - actor_ref TEXT — optional FK to the actor that drove
--                      the transition (sovereign / reducer / GC)

CREATE TABLE IF NOT EXISTS atom_lifecycle_events (
    event_id TEXT PRIMARY KEY NOT NULL,
    atom_id TEXT NOT NULL,
    session_id TEXT NOT NULL,
    from_phase TEXT NOT NULL CHECK (from_phase IN
        ('created', 'admitted', 'linked', 'archived', 'tombstoned')),
    to_phase TEXT NOT NULL CHECK (to_phase IN
        ('created', 'admitted', 'linked', 'archived', 'tombstoned')),
    action TEXT NOT NULL CHECK (action IN
        ('admit', 'link', 'archive', 'tombstone')),
    outcome TEXT NOT NULL CHECK (outcome IN
        ('advanced', 'rejected_illegal', 'rejected_terminal')),
    recorded_at_ms INTEGER NOT NULL,
    actor_ref TEXT
);

CREATE INDEX IF NOT EXISTS ale_atom_idx
  ON atom_lifecycle_events(atom_id, recorded_at_ms);

CREATE INDEX IF NOT EXISTS ale_session_idx
  ON atom_lifecycle_events(session_id);

CREATE INDEX IF NOT EXISTS ale_phase_idx
  ON atom_lifecycle_events(to_phase);

CREATE INDEX IF NOT EXISTS ale_recorded_at_idx
  ON atom_lifecycle_events(recorded_at_ms);
