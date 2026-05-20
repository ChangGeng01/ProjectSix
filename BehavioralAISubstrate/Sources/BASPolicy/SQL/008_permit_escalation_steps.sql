-- 008_permit_escalation_steps — chapter 七百三十八 第三刀 / M2363
--
-- Third + final SQL persistence layer for L11 Wind Gate at this
-- chapter。 Captures PER-STAGE transitions inside an escalation
-- lifecycle (mirrors the Swift BASPermitEscalationStageRecord
-- value type from Sources/BASPolicy/BASPermitEscalationLedger
-- .swift:84-114)。 Append-only — each stage fire emits exactly
-- one row that is never UPDATED nor DELETED。
--
-- ## Why this table (vs the chapter 七百三十八 第二刀 lifecycle)
--
-- L11 escalations have a 5-stage chain (chapter 四百四 entropy
-- audit):
--
--   .abyssal → .assertionCeiling → .kunlun
--   → .cthulhuAssertionCeiling → .cthulhuEscalation
--
-- The LIFECYCLE table (007_permit_escalation_ledger) is
-- 1-row-per-escalation:open + close timestamps + final mode。
-- This STEPS table is N-rows-per-escalation:one row per stage
-- that fired (or was visited)。 Different cardinality → separate
-- table per Codd-normal-form discipline。
--
-- ## What this enables (substack for chapter 七百三十九)
--
--   - "Full transition trace for escalation E" — single index
--     scan on escalation_id ordered by step_ms。
--   - "How often does .kunlun fire?" — single index scan on
--     stage filtered by ON stage = 'kunlun'。
--   - "Which escalations had .cthulhuEscalation fire?" —
--     EXISTS subquery against this table。
--   - Audit reconciliation:auditor can replay every stage
--     transition for any past escalation across process
--     restarts (chapter 392 replay-determinism extended)。
--
-- ## ADR-014 OPT-IN preserved
--
-- Schema lands unconditionally。 V1 in-memory ledger
-- (BASPermitEscalationLedger.records: [Record]) stays the
-- live path until chapter 七百三十九 routes through the
-- SQL store。 Swift legacy preserved as comments per the
-- 「依旧 不删除 只 comment」 invariant。
--
-- ## Statement count: 5
--
--   1. CREATE TABLE permit_escalation_steps      (8 columns)
--   2. CREATE INDEX permit_escalation_steps_escalation_time_idx
--   3. CREATE INDEX permit_escalation_steps_stage_idx
--   4. CREATE INDEX permit_escalation_steps_fired_idx
--   5. CREATE INDEX permit_escalation_steps_session_idx
--
-- Generated enum exposes:
--   PermitEscalationStepsSchema.allStatementsSQL
--   PermitEscalationStepsSchema.statementCount
--
-- ## Doctrine pins held
--
--   - 不变量 #1/#2/#3 — STRICTLY append-only at the row level。
--                       SQLite does not enforce this at the DDL
--                       layer (no WITHOUT-DELETE clause exists)
--                       so the discipline is upheld by:
--                       1) chapter 392 replay-determinism test
--                          that asserts no DELETE on this table
--                       2) chapter 七百三十九 producer code
--                          path that only INSERTs,never
--                          UPDATEs or DELETEs
--   - 红线 7 — additive on dest;BASPermitEscalationStageRecord
--             Swift surface untouched
--   - chapter 一百八十五 — CHECK constraint on stage matches
--                       BASPermitEscalationStage raw values
--                       verbatim (5 cases)。 CHECK on
--                       input_mode / output_mode matches
--                       BASActionPermitMode (9 cases)。 Single
--                       source of truth pinned。
--   - chapter 392 replay-determinism — append-only invariant
--                       means same escalation trajectory →
--                       byte-identical row set after restart
--   - chapter 七百十二 第一刀 — evidence_digest_b64 carries the
--                              SHA256 over the canonical step
--                              payload (input_mode + output_mode
--                              + reason_codes + stage + step_ms)
--                              so audit reconcile can verify
--                              no step was injected post-hoc。
--   - 「不要 json 可以的话 就 sql」 — stage / modes are first-
--                       class TEXT with CHECK。 ONLY the
--                       variable-length reason_codes array
--                       stays JSON (TEXT column carrying
--                       JSON array — same shape as chapter
--                       四百四 reasonCodes)。
--   - 「千万不要 删除 只能 commented 代码」 — Swift legacy
--                       preserved as comments at chapter 七百三十九。
--   - FK pin — escalation_id REFERENCES permit_escalation_ledger
--             (escalation_id) keeps step→lifecycle integrity at
--             the DB layer。 NOT enforced strictly because
--             SQLite requires PRAGMA foreign_keys = ON;the
--             chapter 七百三十九 producer adds the PRAGMA at
--             connection open。
--
-- ## Column shape rationale
--
--   - step_id TEXT PRIMARY KEY — opaque UUID;unique per
--     emitted step。
--   - escalation_id TEXT NOT NULL — FK to
--     permit_escalation_ledger(escalation_id)。 Composite
--     index pairs with step_ms。
--   - session_id TEXT NOT NULL — denormalized from the
--     escalation_ledger parent row for fast session-scoped
--     scans without a JOIN。
--   - step_ms INTEGER NOT NULL — UNIX epoch ms when the stage
--     fired or was visited。 Composite index pairs with
--     escalation_id。
--   - stage TEXT NOT NULL CHECK — BASPermitEscalationStage
--     raw value (5 cases)。 Indexed for cross-escalation
--     aggregation queries。
--   - input_mode TEXT NOT NULL CHECK — BASActionPermit.mode
--     BEFORE the stage fired (input to this transition)。
--   - output_mode TEXT NOT NULL CHECK — BASActionPermit.mode
--     AFTER the stage fired (output of this transition)。
--   - fired INTEGER NOT NULL CHECK (0,1) — denormalized
--     derived field matching BASPermitEscalationStageRecord
--     .fired (true when output ≠ input OR reasonCodes
--     non-empty)。 Indexed for "fired-only" queries。
--   - reason_codes_json TEXT — JSON-encoded array of String
--     reason codes (variadic by signal-kind)。 Per-array-
--     element CHECK is not practical at the SQL layer;the
--     application enforces the typed prefix
--     (BASPermitEscalationLedger.ledgerReasonCodePrefix)
--     before insert。
--   - evidence_digest_b64 TEXT — chapter 七百十二 第一刀 pin。
--                                Nullable at this knife;
--                                chapter 七百三十九 promotes
--                                to NOT NULL after the Rust
--                                step-seal lands。

CREATE TABLE IF NOT EXISTS permit_escalation_steps (
    step_id TEXT PRIMARY KEY NOT NULL,
    escalation_id TEXT NOT NULL,
    session_id TEXT NOT NULL,
    step_ms INTEGER NOT NULL,
    stage TEXT NOT NULL CHECK (stage IN
        ('abyssal',
         'assertion-ceiling',
         'kunlun',
         'cthulhu-assertion-ceiling',
         'cthulhu-escalation')),
    input_mode TEXT NOT NULL CHECK (input_mode IN
        ('answer', 'mirror', 'compare', 'delay',
         'draft_only', 'local_only',
         'block', 'replace', 'escalate')),
    output_mode TEXT NOT NULL CHECK (output_mode IN
        ('answer', 'mirror', 'compare', 'delay',
         'draft_only', 'local_only',
         'block', 'replace', 'escalate')),
    fired INTEGER NOT NULL CHECK (fired IN (0, 1)),
    reason_codes_json TEXT,
    evidence_digest_b64 TEXT,
    FOREIGN KEY (escalation_id)
        REFERENCES permit_escalation_ledger(escalation_id)
);

CREATE INDEX IF NOT EXISTS
  permit_escalation_steps_escalation_time_idx
  ON permit_escalation_steps(escalation_id, step_ms);

CREATE INDEX IF NOT EXISTS
  permit_escalation_steps_stage_idx
  ON permit_escalation_steps(stage);

CREATE INDEX IF NOT EXISTS
  permit_escalation_steps_fired_idx
  ON permit_escalation_steps(fired);

CREATE INDEX IF NOT EXISTS
  permit_escalation_steps_session_idx
  ON permit_escalation_steps(session_id);
