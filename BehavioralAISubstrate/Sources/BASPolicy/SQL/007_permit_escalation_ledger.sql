-- 007_permit_escalation_ledger — chapter 七百三十八 第二刀 / M2362
--
-- Layer-migration arc continuation。 Second SQL persistence layer
-- for L11 Wind Gate。 Where chapter 七百三十八 第一刀 lands the
-- BASRiskObservation per-signal log,this knife lands the
-- PERMIT-ESCALATION LIFECYCLE table — one row per opened
-- escalation,closed when the gate stabilizes (or remains open
-- when an escalation is still active mid-session)。
--
-- ## Why a lifecycle table (not just step-records)
--
-- L11 escalations have lifecycle semantics:
--
--   1. A risk signal triggers a `.escalate` permit mode。
--   2. The gate opens an escalation (row inserted,
--      closed_at_ms = NULL)。
--   3. Per-stage transitions happen via 5-stage chain
--      (.abyssal → .assertionCeiling → .kunlun →
--       .cthulhuAssertionCeiling → .cthulhuEscalation per
--       chapter 四百四 ledger)。 Steps are recorded in
--       permit_escalation_steps (knife 3)。
--   4. The escalation closes when the gate settles back to a
--      non-escalate mode (closed_at_ms = stamped)。
--
-- This table captures step 2 + step 4 (the lifecycle bookends),
-- WHILE per-stage transitions inside the lifecycle go to the
-- chapter 七百三十八 第三刀 permit_escalation_steps table。
--
-- ## SINGLETON open-escalation invariant
--
-- A session may have AT MOST ONE open escalation at a time。
-- This is enforced via PARTIAL UNIQUE INDEX:
--
--   CREATE UNIQUE INDEX ... ON permit_escalation_ledger(session_id)
--     WHERE closed_at_ms IS NULL
--
-- SQLite has supported partial indexes since 3.8.0 (2013)。
-- Multiple closed escalations per session are fine;at most
-- one open escalation is enforced at the DB layer (cannot be
-- bypassed by application bug)。
--
-- ## What this enables (substack for chapter 七百三十九)
--
--   - "Is session S currently in escalation?" — single
--     indexed query against the partial unique index。
--   - "All escalations for session S ordered by opened_at_ms"
--     — single index scan via the secondary composite index。
--   - "Average escalation duration in last 24h" — closed_at_ms
--     - opened_at_ms,filterable by time range。
--
-- ## ADR-014 OPT-IN preserved
--
-- Schema lands unconditionally。 V1 in-memory escalation
-- tracking (Sources/BASPolicy/BASPermitEscalationLedger.swift)
-- stays the live path until chapter 七百三十九 routes through
-- the SQL store。 At that point the Swift ledger body is
-- COMMENTED-OUT adjacent to the routed-SQL call site per
-- the 「依旧 不删除 只 comment」 invariant。
--
-- ## Statement count: 4
--
--   1. CREATE TABLE permit_escalation_ledger     (10 columns)
--   2. CREATE UNIQUE INDEX permit_escalation_open_singleton_idx
--      (partial,WHERE closed_at_ms IS NULL)
--   3. CREATE INDEX permit_escalation_session_time_idx
--   4. CREATE INDEX permit_escalation_current_mode_idx
--
-- Generated enum exposes:
--   PermitEscalationLedgerSchema.allStatementsSQL
--   PermitEscalationLedgerSchema.statementCount
--
-- ## Doctrine pins held
--
--   - 不变量 #1/#2/#3 — append-only LIFECYCLE (rows are
--                       inserted on open + UPDATEd once on
--                       close + never deleted)。 Closing is
--                       an UPDATE because the escalation_id
--                       must stay stable across the lifecycle
--                       for step-records to link back。
--   - 红线 7 — additive on dest;BASPermitEscalationLedger
--             Swift surface untouched。
--   - chapter 一百八十五 anti-magic-number — CHECK constraint
--                       on current_mode + prior_mode pins
--                       all 9 BASActionPermitMode raw values
--                       verbatim。 Single source of truth。
--   - chapter 392 replay-determinism — same escalation
--                       trajectory → same row set after
--                       boot-and-read。
--   - chapter 七百十二 第一刀 — ledger_self_hash_b64 OPTIONAL;
--                              chapter 七百三十九 may flip it
--                              NOT NULL once the Rust port
--                              produces per-escalation seal
--                              hashes via the chain primitives。
--                              At this knife it stays nullable
--                              to permit V1 → V2 migration
--                              without backfill。
--   - 「不要 json 可以的话 就 sql」 — current_mode + prior_mode
--                       are first-class TEXT columns with
--                       CHECK,not JSON-encoded payloads。
--   - 「千万不要 删除 只能 commented 代码」 — chapter 七百三十九
--                       Swift legacy preserved as comments。
--   - 不变量 #1 (open-singleton) — partial UNIQUE INDEX
--                       enforces at most one open escalation
--                       per session at the DB layer。
--
-- ## Column shape rationale
--
--   - escalation_id TEXT PRIMARY KEY — opaque UUID;stable
--     across the lifecycle so step-records can FK-link back。
--   - session_id TEXT NOT NULL — joins to the L11 session
--     scope。 Composite index pairs with opened_at_ms。
--   - opened_at_ms INTEGER NOT NULL — UNIX epoch ms when the
--     escalation opened (the moment the gate flipped to
--     `.escalate`)。
--   - closed_at_ms INTEGER — NULL while escalation is open;
--     stamped when the gate settles back to a non-escalate
--     mode。 Partial unique index keys off this NULL state。
--   - opening_mode TEXT NOT NULL CHECK — the BASActionPermit
--     mode that triggered the open (usually `.escalate`,
--     occasionally `.block` if the gate jumped two levels)。
--   - current_mode TEXT NOT NULL CHECK — the mode AS OF the
--     latest UPDATE。 Equals opening_mode initially;may
--     advance through the 5-stage escalation chain。
--   - prior_mode TEXT CHECK — the mode BEFORE the current_mode
--     advancement。 NULL on initial insert。
--   - reason TEXT NOT NULL — typed reason string for the
--     CURRENT mode。 Aggregated from per-stage reason codes
--     (chapter 四百四 ledger aggregateReasonCodes pattern)。
--   - assertion_ceiling TEXT NOT NULL — the assertion ceiling
--     in force at lifecycle close (mirrors
--     BASActionPermit.assertionCeiling for replay reconcile)。
--   - ledger_self_hash_b64 TEXT — chapter 七百三十九 may flip
--     this NOT NULL once the Rust seal lands;at this knife
--     it stays nullable to permit V1 escalations to migrate
--     without backfill。

CREATE TABLE IF NOT EXISTS permit_escalation_ledger (
    escalation_id TEXT PRIMARY KEY NOT NULL,
    session_id TEXT NOT NULL,
    opened_at_ms INTEGER NOT NULL,
    closed_at_ms INTEGER,
    opening_mode TEXT NOT NULL CHECK (opening_mode IN
        ('answer', 'mirror', 'compare', 'delay',
         'draft_only', 'local_only',
         'block', 'replace', 'escalate')),
    current_mode TEXT NOT NULL CHECK (current_mode IN
        ('answer', 'mirror', 'compare', 'delay',
         'draft_only', 'local_only',
         'block', 'replace', 'escalate')),
    prior_mode TEXT CHECK (prior_mode IS NULL OR prior_mode IN
        ('answer', 'mirror', 'compare', 'delay',
         'draft_only', 'local_only',
         'block', 'replace', 'escalate')),
    reason TEXT NOT NULL,
    assertion_ceiling TEXT NOT NULL,
    ledger_self_hash_b64 TEXT
);

-- SINGLETON open-escalation invariant:at most one open
-- escalation per session at any moment。 Closed escalations
-- (closed_at_ms NOT NULL) are excluded from the uniqueness
-- check via the partial-index WHERE clause。
CREATE UNIQUE INDEX IF NOT EXISTS
  permit_escalation_open_singleton_idx
  ON permit_escalation_ledger(session_id)
  WHERE closed_at_ms IS NULL;

CREATE INDEX IF NOT EXISTS
  permit_escalation_session_time_idx
  ON permit_escalation_ledger(session_id, opened_at_ms);

CREATE INDEX IF NOT EXISTS
  permit_escalation_current_mode_idx
  ON permit_escalation_ledger(current_mode);
