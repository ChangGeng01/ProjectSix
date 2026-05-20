-- 009_sovereign_tokens — chapter 七百四十一 第三刀 / M2378
--
-- LAYER-MIGRATION ARC L14 token authority persistence schema。
-- Net-new table indexing the issued CommitTokens + Warrants
-- from BASSovereignTokenAuthority (BASSovereignTokenAuthority
-- .swift)。 Additive to the existing audit_entries +
-- audit_chain_tip + audit_segments tables。
--
-- Per user directive 2026-05-20:
--
--   「Swift 仍然应该保留为 façade / Apple glue / public API。
--    真正应该移植的是每层里的 热路径、状态机、持久化、审计、
--    数学计算。」
--
-- AND「如果 完全 移植后 整体 会 更好 那就 移植 进行 对比
--      最极致 最优雅 依旧 不删除 只 comment」
--
-- ## What this table indexes
--
-- L14 issues two credential types per the Black Ring spec:
--   - CommitToken — single-turn,bound to session+turn+
--                   action_digest+snapshot_ref
--   - Warrant     — multi-turn,extended-scope,jurisdiction-
--                   bound
--
-- Both share a common identity + lifecycle + signature shape
-- → single unified table with a typed `token_kind` column。
--
-- ## What this enables (chapter 七百四十三 sub-arc close-out)
--
--   - Replay determinism across process restarts:V1 in-memory
--     actor loses issued/revoked state on reset。 SQL layer is
--     durable;auditors reconcile "what tokens were live at
--     turn T" across runs。
--   - Cross-session expiry sweep:WHERE expires_at_ms < ?
--     indexed → single-pass scan of all-expired-tokens for
--     periodic cleanup。
--   - Revocation broadcast:UPDATE WHERE token_id = ? sets
--     revoked_at_ms;subsequent verifies catch the revoked
--     state in O(1)。
--   - Token-authority drift detection:replay-verify by
--     re-deriving expected signatures from indexed claims
--     and checking they match the persisted signature_b64。
--
-- ## ADR-014 OPT-IN preserved
--
-- Schema lands unconditionally。 V1 in-memory token authority
-- actor stays the live path until chapter 七百四十三 第一刀
-- wires the SQL persistence consumer behind a flag。 Swift
-- legacy preserved as commented-out adjacent code per
-- 「依旧 不删除 只 comment」 invariant when the wire-up lands。
--
-- ## Statement count: 5
--
--   1. CREATE TABLE sovereign_tokens         (13 columns)
--   2. CREATE INDEX sovereign_tokens_session_idx
--   3. CREATE INDEX sovereign_tokens_expires_idx
--   4. CREATE INDEX sovereign_tokens_revoked_at_idx
--   5. CREATE INDEX sovereign_tokens_kind_idx
--
-- Generated enum exposes:
--   SovereignTokensSchema.allStatementsSQL
--   SovereignTokensSchema.statementCount
--
-- ## Doctrine pins held
--
--   - 不变量 #1/#2/#3 — token issuance is APPEND-ONLY (rows
--                       INSERT once, UPDATE once on revoke,
--                       never DELETE)
--   - 红线 7 — additive on dest;BASSovereignTokenAuthority
--             public surface untouched
--   - chapter 一百八十五 — CHECK constraint on token_kind
--                       pins both raw values verbatim
--                       ('commit' / 'warrant')
--   - chapter 392 replay-determinism — same issuance trajectory
--                                      → same row set after
--                                      boot-and-read
--   - chapter 七百十二 第一刀 — signature_b64 carries the
--                              Ed25519 signature over the
--                              canonical claim bytes;replay
--                              verify can independently
--                              re-derive + match
--   - chapter 七百四十一 第一刀 — chain primitives extended;
--                                this knife adds the
--                                PERSISTENCE layer that lets
--                                the L14 chain survive
--                                process restarts
--   - 「不要 json 可以的话 就 sql」 — claim fields are typed
--                       columns;only the variadic
--                       allowed_targets_json stays JSON
--                       (since the array has unbounded length
--                       per warrant scope)
--   - 「千万不要 删除 只能 commented 代码」 — chapter
--                       七百四十三 wire-up preserves Swift
--                       legacy as comments
--
-- ## Column shape rationale
--
--   - token_id TEXT PRIMARY KEY — opaque UUID;unique per
--     issued credential。
--   - token_kind TEXT NOT NULL CHECK — 'commit' or 'warrant'
--     verbatim raw values mirroring Swift enum cases。
--   - session_id TEXT NOT NULL — joins to L14 session scope。
--   - turn_id TEXT — non-null for commit tokens,nullable for
--     warrants (which span multiple turns)。
--   - scope_raw TEXT NOT NULL — e.g。 "host_mutation",
--     "memory_promotion",etc。 (BASSovereignCommitScope
--     rawValue)。
--   - action_digest_b64 TEXT NOT NULL — Base64-encoded
--     SHA256 of the canonical action bytes (the "what is
--     being authorized" hash)。
--   - snapshot_ref TEXT NOT NULL — ARK snapshot reference at
--     issuance time。
--   - issued_at_ms INTEGER NOT NULL — UNIX epoch ms。
--   - expires_at_ms INTEGER NOT NULL — issued_at + ttl_ms。
--   - revoked_at_ms INTEGER — NULL while live;stamped on
--     revocation。
--   - policy_hash_hex TEXT NOT NULL — current policy version
--     hash at issuance (drift detection)。
--   - allowed_targets_json TEXT — JSON-array of allowed
--     resource refs (variable length per scope)。 Single
--     ALLOWED non-SQL column per the「不要 json」 rationale
--     above。
--   - signature_b64 TEXT NOT NULL — Ed25519 signature over
--     the canonical claim bytes。

CREATE TABLE IF NOT EXISTS sovereign_tokens (
    token_id TEXT PRIMARY KEY NOT NULL,
    token_kind TEXT NOT NULL CHECK (token_kind IN
        ('commit', 'warrant')),
    session_id TEXT NOT NULL,
    turn_id TEXT,
    scope_raw TEXT NOT NULL,
    action_digest_b64 TEXT NOT NULL,
    snapshot_ref TEXT NOT NULL,
    issued_at_ms INTEGER NOT NULL,
    expires_at_ms INTEGER NOT NULL,
    revoked_at_ms INTEGER,
    policy_hash_hex TEXT NOT NULL,
    allowed_targets_json TEXT,
    signature_b64 TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS sovereign_tokens_session_idx
  ON sovereign_tokens(session_id, issued_at_ms);

-- Composite expires_at index for periodic sweep of
-- expired-but-live tokens (revoked_at_ms IS NULL AND
-- expires_at_ms < ?)
CREATE INDEX IF NOT EXISTS sovereign_tokens_expires_idx
  ON sovereign_tokens(expires_at_ms)
  WHERE revoked_at_ms IS NULL;

CREATE INDEX IF NOT EXISTS sovereign_tokens_revoked_at_idx
  ON sovereign_tokens(revoked_at_ms);

CREATE INDEX IF NOT EXISTS sovereign_tokens_kind_idx
  ON sovereign_tokens(token_kind);
