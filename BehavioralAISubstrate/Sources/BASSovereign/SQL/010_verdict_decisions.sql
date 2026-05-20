-- 010_verdict_decisions — chapter 七百四十二 第三刀 / M2383
--
-- LAYER-MIGRATION ARC L14 Verdict Engine provenance schema。
-- Net-new table indexing the (HardObservations, SoftSignals,
-- OperationDomain, evidence_sufficient) inputs alongside the
-- resulting verdict level for each L14 decision。 Additive to
-- the existing audit_entries / audit_chain_tip / audit_segments
-- + chapter 七百四十一 sovereign_tokens tables。
--
-- ## Why this table
--
-- The L14 verdict engine is the substrate's single source of
-- truth on "may this action proceed?"。 Currently V1 emits
-- BASSovereignVerdict records to the audit ledger but the
-- DERIVATION PROVENANCE (which 12 BR observations were set,
-- which 7 soft signals were observed,which domain,whether
-- evidence was sufficient) lives only in the verdict's
-- reasonCodes string list。 This schema PERSISTS the typed
-- derivation provenance so auditors can:
--
--   - Replay a verdict by feeding the persisted (obs, softs,
--     domain, evidence) tuple into the Rust derive function
--     and confirming the persisted verdict_level matches。
--   - Group across sessions:"how often does BR-008 fire
--     during memory_promote?" → indexed query。
--   - Drift detection:if the Rust port disagrees with the
--     Swift implementation on a replay,a row-level mismatch
--     is recoverable。
--
-- ## ADR-014 OPT-IN preserved
--
-- Schema lands unconditionally。 V1 verdict engine continues
-- to write its existing audit_entries rows;the new
-- verdict_decisions table is OPT-IN provenance the engine
-- MAY populate when the chapter 七百四十二 第四刀 flag is on。
-- Hosts can drop the new table without affecting V1 audit
-- integrity。
--
-- ## Statement count: 5
--
--   1. CREATE TABLE verdict_decisions      (12 columns)
--   2. CREATE INDEX vd_session_idx
--   3. CREATE INDEX vd_level_idx
--   4. CREATE INDEX vd_domain_idx
--   5. CREATE INDEX vd_evidence_idx
--
-- Generated enum exposes:
--   VerdictDecisionsSchema.allStatementsSQL
--   VerdictDecisionsSchema.statementCount
--
-- ## Doctrine pins held
--
--   - 不变量 #1/#2/#3 — append-only at row level (verdicts
--                       are issued exactly once per turn,
--                       INSERT only,never UPDATE/DELETE)
--   - 红线 7 — additive on dest;BASSovereignVerdictEngine
--             public surface untouched
--   - chapter 一百八十五 — verdict_level CHECK pins all 8
--                       raw values verbatim
--                       (pass/throttle/shadowLock/toolCut/
--                       memoryFreeze/quarantine/rollback/
--                       deadStop)
--   - chapter 392 replay-determinism — persisted provenance
--                                      tuple replays to the
--                                      same verdict level
--                                      via Rust derive fn
--   - 「不要 json 可以的话 就 sql」 — hard_bits + softs
--                       columns are typed,not JSON。 Only
--                       the variadic pinned_domain string
--                       column stays free-form (it carries
--                       the soft-signal domain that pinned,
--                       e.g。 "integrity" / "selfMod" — a
--                       bounded vocabulary but enumerated
--                       in the Rust port,not in SQL)
--   - 「千万不要 删除 只能 commented 代码」 — engine wire-up
--                       at chapter 七百四十三 preserves Swift
--                       legacy as adjacent commented code
--
-- ## Column shape rationale
--
--   - decision_id TEXT PRIMARY KEY — opaque UUID
--   - session_id TEXT NOT NULL — joins to L14 session
--   - turn_id TEXT — single-turn decisions carry turn ID,
--     warrant-scope decisions span turns (nullable)
--   - decided_at_ms INTEGER NOT NULL — UNIX epoch ms
--   - hard_bits INTEGER NOT NULL — u16 bitfield matching
--     the Rust C ABI encoding (LSB = BR-001 ... bit 11 =
--     BR-012);only 12 bits set,upper 4 always 0
--   - integrity_soft REAL NOT NULL — first soft signal [0,1]
--   - privilege_violation_soft REAL NOT NULL
--   - self_mod_soft REAL NOT NULL
--   - memory_contamination_soft REAL NOT NULL
--   - irreversible_harm_soft REAL NOT NULL
--   - runtime_instability_soft REAL NOT NULL
--   - manipulation_intrusion_soft REAL NOT NULL — 7th soft
--   - domain_raw TEXT NOT NULL CHECK — operation domain raw
--     value (pureInference / toolRead / toolWrite /
--     hostMutate / memoryPromote / rulePromotion)
--   - evidence_sufficient INTEGER NOT NULL CHECK (0,1) —
--     boolean encoded as 0/1
--   - verdict_level TEXT NOT NULL CHECK — final verdict
--     (8 raw values mirroring BASSovereignVerdictLevel)
--   - pinned_domain TEXT — soft-signal domain that pinned
--     the verdict (nullable;nil if all softs low)
--   - audit_entry_ref TEXT — optional FK to audit_entries
--     by audit_id;nullable for verdicts that don't get
--     a separate audit entry。

CREATE TABLE IF NOT EXISTS verdict_decisions (
    decision_id TEXT PRIMARY KEY NOT NULL,
    session_id TEXT NOT NULL,
    turn_id TEXT,
    decided_at_ms INTEGER NOT NULL,
    hard_bits INTEGER NOT NULL,
    integrity_soft REAL NOT NULL,
    privilege_violation_soft REAL NOT NULL,
    self_mod_soft REAL NOT NULL,
    memory_contamination_soft REAL NOT NULL,
    irreversible_harm_soft REAL NOT NULL,
    runtime_instability_soft REAL NOT NULL,
    manipulation_intrusion_soft REAL NOT NULL,
    domain_raw TEXT NOT NULL CHECK (domain_raw IN
        ('pureInference', 'toolRead', 'toolWrite',
         'hostMutate', 'memoryPromote', 'rulePromotion')),
    evidence_sufficient INTEGER NOT NULL
        CHECK (evidence_sufficient IN (0, 1)),
    verdict_level TEXT NOT NULL CHECK (verdict_level IN
        ('pass', 'throttle', 'shadowLock', 'toolCut',
         'memoryFreeze', 'quarantine', 'rollback',
         'deadStop')),
    pinned_domain TEXT,
    audit_entry_ref TEXT
);

CREATE INDEX IF NOT EXISTS vd_session_idx
  ON verdict_decisions(session_id, decided_at_ms);

CREATE INDEX IF NOT EXISTS vd_level_idx
  ON verdict_decisions(verdict_level);

CREATE INDEX IF NOT EXISTS vd_domain_idx
  ON verdict_decisions(domain_raw);

CREATE INDEX IF NOT EXISTS vd_evidence_idx
  ON verdict_decisions(evidence_sufficient);
