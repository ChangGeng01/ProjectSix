-- 006_risk_observations_schema — chapter 七百三十八 第一刀 / M2361
--
-- LAYER-MIGRATION ARC opener。 First SQL persistence layer for
-- L11 Wind Gate (BASRiskObservation / BASRiskObservationBundle /
-- BASRiskObservationLedger)。 Pre-this-chapter,risk observations
-- lived ONLY as a 128-entry in-memory ring actor
-- (BASRiskObservationLedger,Sources/BASPolicy/BASRiskObservation
-- .swift:233)。 Per user directive 2026-05-20:
--
--   「Swift 仍然应该保留为 façade / Apple glue / public API。
--    真正应该移植的是每层里的 热路径、状态机、持久化、审计、数学计算。」
--
-- AND the strengthening directive:
--
--   「如果 完全 移植后 整体 会 更好 那就 移植 进行 对比
--    最极致 最优雅 依旧 不删除 只 comment」
--
-- This file is the FIRST knife of chapter 七百三十八。 Lands the
-- net-new SQL persistence layer unconditionally (Schema-First
-- pattern from chapter 七百十三 第三刀 + 七百十四 三-knife)。
-- The Rust state-machine port lands at chapter 七百三十九。
--
-- ## Why SQL (not JSON)
--
-- Per user invariant 「不要 json 可以的话 就 sql」 — every
-- structured field that has SQL-typeable shape gets a typed
-- column。 Only the per-signal opaque `content` field (which
-- varies per BASRiskSignalKind — hazard description /
-- reversibility rationale / gate-pressure direction) carries
-- a JSON-encoded payload。 The structured fields (kind,
-- intent_id, salience, confidence, observed_at_ms,
-- session_id, turn_id) are first-class columns。
--
-- ## What this enables (the substack for chapter 七百三十九)
--
--   - Replay determinism across process restarts:the in-memory
--     ring loses risk observations on actor reset。 The SQL
--     persistence layer is durable;auditors can reconcile
--     "what risk signals were emitted before turn T" against
--     "what permit was issued at turn T" across runs。
--   - Cross-session analytics:`session_id` + `observed_at_ms`
--     indexed → "show me all hazardReading observations in
--     session S between t1 and t2" is a single indexed query。
--   - Band-bucket aggregation:`risk_band` indexed → "how many
--     high-band observations in the last 24h?" is a single
--     indexed COUNT。
--
-- ## ADR-014 OPT-IN preserved
--
-- At this knife the plugin runs and the generated enum is
-- built。 Production wiring (the BASRiskObservationLedger
-- gains a SQL persistence option) is deferred to chapter
-- 七百三十九 (Rust state machine + SQL persistence wiring
-- together) gated by a `useRoutedRiskPlane: Bool = false`
-- flag per the chapter 七百二十三 第三刀 pattern。 The in-memory
-- ring stays the V1 path until measurement on the 5-axis
-- comparison test supports a default flip。
--
-- ## Statement count: 4
--
--   1. CREATE TABLE risk_observations             (11 columns)
--   2. CREATE INDEX risk_observations_session_time_idx
--   3. CREATE INDEX risk_observations_band_idx
--   4. CREATE INDEX risk_observations_kind_idx
--
-- Generated enum exposes:
--   RiskObservationsSchema.allStatementsSQL
--   RiskObservationsSchema.statementCount
--
-- ## Doctrine pins held
--
--   - 不变量 #1/#2/#3 — append-only at the row level;risk
--                       observations are observation plumbing,
--                       never decision rebinding。 CREATE TABLE
--                       IF NOT EXISTS is idempotent so the
--                       on-disk database is preserved across
--                       both V1 (in-memory) and V2 (SQL) paths
--                       once V2 lands。
--   - 红线 7 — additive on dest;the Swift ledger actor's
--             public surface is untouched at this knife。 The
--             SQL persistence is opt-in plumbing,not a
--             decision-path rewrite。
--   - chapter 一百八十五 anti-magic-number — column types
--                       + CHECK constraints pinned in this SQL
--                       file are the single source of truth
--                       for the wire shape。 The CHECK on
--                       observation_kind matches the 6 cases
--                       of BASRiskSignalKind verbatim。
--   - chapter 392 replay-determinism — same (session_id,
--                                      turn_id) → same row set
--                                      on append + boot-and-read。
--   - chapter 二百四十八 SQLite idiom — same `runExec` driver
--                                      consumes the generated
--                                      enum or inline literal。
--   - chapter 七百十二 第一刀 — risk observations carry no
--                              audit-chain hash at this knife
--                              (they are observation plumbing,
--                              not sealed decisions)。 Chapter
--                              七百四十二 verdict_decisions
--                              schema is where audit-chain
--                              integration lives。
--   - 「千万不要 删除 只能 commented 代码」 — when chapter
--                       七百三十九 wires the SQL path,the
--                       Swift in-memory ledger body stays as
--                       commented-out adjacent code per the
--                       「依旧 不删除 只 comment」 invariant。
--   - ADR-014 OPT-IN — schema lands unconditionally;consumer
--                      wiring stays opt-in (default-OFF flag)。
--
-- ## Column shape rationale
--
--   - event_id TEXT PRIMARY KEY — opaque UUID/ULID;unique
--     per emitted observation。 Mirror of chapter 七百十三
--     第三刀 replay_log_events event_id。
--   - session_id TEXT NOT NULL — joins to L11 session context;
--     indexed with observed_at_ms for time-range scans。
--   - turn_id TEXT NOT NULL — joins to the L11 turn within a
--     session;mirrors the BASRiskObservationBundle.turnID
--     field。
--   - intent_id TEXT NOT NULL — joins to the upstream intent
--     the observation pertains to (per BASRiskObservation
--     .intentID)。 Permits the "all observations for intent I"
--     query that L14 audit reconciler needs。
--   - observed_at_ms INTEGER NOT NULL — UNIX epoch ms;same
--     resolution as chapter 七百十四 episode_started_at_ms。
--   - risk_band TEXT NOT NULL CHECK — categorical bucket
--     ('low','medium','high','critical');indexed for
--     aggregation queries。
--   - risk_score REAL NOT NULL — bounded numeric measure in
--     [0,1] derived from the underlying salience × confidence
--     × signal-kind-weight at emission time。
--   - observation_kind TEXT NOT NULL CHECK — matches
--     BASRiskSignalKind raw values verbatim (6 cases)。
--   - salience REAL NOT NULL — BASRiskObservation.salience,
--     clamped [0,1] per the actor's clamp(_:)。
--   - confidence REAL NOT NULL — BASRiskObservation.confidence,
--     clamped [0,1] per the actor's clamp(_:)。
--   - payload_json TEXT — opaque per-signal content (hazard
--     description / reversibility rationale / etc)。 Nullable
--     because some observation_kinds (noveltyReading,
--     gatePressure) may carry empty content。

CREATE TABLE IF NOT EXISTS risk_observations (
    event_id TEXT PRIMARY KEY NOT NULL,
    session_id TEXT NOT NULL,
    turn_id TEXT NOT NULL,
    intent_id TEXT NOT NULL,
    observed_at_ms INTEGER NOT NULL,
    risk_band TEXT NOT NULL CHECK (risk_band IN
        ('low', 'medium', 'high', 'critical')),
    risk_score REAL NOT NULL,
    observation_kind TEXT NOT NULL CHECK (observation_kind IN
        ('hazardReading',
         'irreversibilityReading',
         'harmPotentialReading',
         'consequenceHorizonReading',
         'noveltyReading',
         'gatePressure')),
    salience REAL NOT NULL,
    confidence REAL NOT NULL,
    payload_json TEXT
);

CREATE INDEX IF NOT EXISTS risk_observations_session_time_idx
  ON risk_observations(session_id, observed_at_ms);

CREATE INDEX IF NOT EXISTS risk_observations_band_idx
  ON risk_observations(risk_band);

CREATE INDEX IF NOT EXISTS risk_observations_kind_idx
  ON risk_observations(observation_kind);
