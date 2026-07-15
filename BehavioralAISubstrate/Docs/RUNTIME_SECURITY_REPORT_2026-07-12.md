# Runtime-Security Report — 14 findings verified & dispositioned (2026-07-12)

Operator submitted a 14-item runtime/security/integrity report ("这些是 真的吗") →
42-agent adversarial verification (confirmer + refuter + adjudicator per finding,
majority reconcile) → operator said "all" → every confirmed/partial finding fixed,
each with TDD teeth + adversarial reversal (file-backup, never git checkout) +
individual commit/push. F13 refuted, no action.

## Verification verdict (42-agent workflow)

| # | Claim | Verdict | Severity held |
|---|-------|---------|---------------|
| F1 | Tool action not bound to approved intent | PARTIAL | MEDIUM |
| F2 | Three-signature chain not unforgeable (docs claim crypto) | PARTIAL (doc-lie) | MEDIUM |
| F3 | Ledger entry/segment not atomic | **CONFIRMED** | HIGH |
| F4 | Ledger reads treat SQLite errors as EOF | **CONFIRMED** | HIGH |
| F5 | Quarantine not a complete purge chain | PARTIAL | LOW (design boundary) |
| F6 | WAL physical delete leaves plaintext | **CONFIRMED** | HIGH |
| F7 | Learning bundle digest not bound to full entry | PARTIAL | MEDIUM |
| F8 | Candidate numeric contract mismatch (no clamp) | **CONFIRMED** | HIGH |
| F9 | Outer stream cancel doesn't cancel producer | **CONFIRMED** | HIGH |
| F10 | Thermal emergency BGTask reentrancy race | PARTIAL | LOW |
| F11 | Model tool safety gate depends on host wiring | **CONFIRMED** | MEDIUM |
| F12 | Proposal/lease boundary trusts seat self-report, fail-open | PARTIAL | LOW |
| F13 | Learning export mints warrant after privacy rejection | **REFUTED** — Stage C approver is a pure UUID mint, result discarded before any bundle built | — |
| F14 | clearHalt doesn't clear old reason | PARTIAL | LOW |

Severity downgrades vs. the report (~8 claimed HIGH → 5 held): most
"confused-deputy / unforgeable-chain" HIGHs assume an untrusted party at a boundary
that doesn't exist yet — QinaoRuntimeSDK has **zero production callers** (operator
decision B: adoption-ready scaffold, NOT live). Dormant-scaffold findings were still
fixed, fail-closed, so the gate is safe *before* first adoption.

## Fixes (8 commits, oldest→newest)

### 档1 — live-substrate HIGH
- **`45e8c9ecc` F3+F4** — `BASSovereignLedgerStorage`: entry+segment persisted in one
  `BEGIN IMMEDIATE…COMMIT/ROLLBACK` (new protocol method `persistAppendedEntryAndSegment`,
  SQLite override transactional); ledger + knowledge-graph reads capture the final
  `sqlite3_step` rc and `guard rc == SQLITE_DONE else throw` (BUSY/IOERR/CORRUPT no
  longer read as clean EOF); `ensureReloadVerified` segment cross-check moved BEFORE the
  empty-entries early-return (0-entries + non-empty-segments now quarantines).
  Teeth: drop-segments-table mid-append → throws, reopen count==1, not quarantined;
  stub with 0 entries + segment claiming 3 → quarantined.
- **`0a8103dca` F6** — `BASSQLiteSecureDelete.checkpointTruncateAfterSecureDelete(db:)`:
  verified `wal_checkpoint(TRUNCATE)` that THROWS `walNotTruncated` if frames remain;
  wired into `BASSQLiteMemoryAtomStore.remove(forID:)` (explicit forget path, NOT the
  hot tiering-evict loop). secure_delete=ON zeroes only MAIN-DB pages; the INSERT frame
  in `-wal` was recoverable. Mirrors ContentStore.delete(). Tooth: removed atom's
  sensitive string absent from on-disk `-wal` (reversal-proven red).
  Shared helper now available for the other ~20 pragma-only stores.
- **`1593e61ce` F8+F9** — `CandidateInput` NaN-safe clamp01 on all 8 [0,1] fields
  (docstring promised clamp-on-receive; stored raw — +∞ tops frontier forever, NaN
  breaks strict-weak sort). TDD caught the fix's own bug: first guard sent +∞→0;
  corrected (+∞→1, NaN/−∞→0). `QinaoLoop.streamBody` + `BASOrganRegistryEndpoint
  .streamBody`: pump Task captured + `onTermination → task.cancel()` +
  `checkCancellation` in yield loop (consumer break/cancel now tears down the GPU
  decode; H18 pattern). Cancellation tooth reversal-proven.

### 档2 — false claims / dead fields / floor
- **`0c0972bd7` F1+F2+F7** — F1: `guard toolName == intent.toolName else throw
  .toolMismatch` in `QinaoRuntime.execute()` (field existed, never read → approval-for-A
  ran B). F2: Warrant/isWarrantValid/runtime-header docs corrected to HONEST scope —
  field-binding + TTL, NOT cryptographic (tokenAuthority configured but unwired; public
  memberwise inits); concrete pre-adoption signing recipe pinned in the docstring.
  F7: learning bundleDigest binds the FULL entry incl. confidence via injective
  length-prefixed `canonicalJoin` + lossless `canonicalConfidence` (confidence flip was
  digest-invisible; "|"-join collided ["a|b","c"]≡["a","b|c"]).
- **`104567331` F11** — `BASToolCallingPlanner(restrictedToolDomains:)` runtime floor:
  invocations on the set are dropped BEFORE dispatchBatch regardless of what the
  host-supplied policy returned (default nil = byte-equal). Tooth: policy that allows a
  restricted tool → 0 dispatches (reversal-proven).

### 档3 — hygiene + adjudication
- **`b4fbd4b9d` F10** — `BASBreathScheduler` tracks `currentGuardLevel` (set FIRST in
  reconcile); `schedule()` re-validates after the `bridge.register` await and fails
  closed (cancels its own now-illegal OS registration) if an emergency/throttle
  reconcile ran during the suspension. Gate-bridge tooth reversal-proven.
- **`f67c63f2b` F12+F14** — F12: `dispatchProposals` keeps (emitter, proposal)
  association; rejects `proposal.agent != emitter` (`.seatIdentityMismatch`) and
  leaseRef-with-no-enforcer (`.leaseUnverifiable`, was fail-open). A pre-existing test
  PINNED the fail-open and was consciously updated to the fail-closed contract.
  F14: `clearHalt` also removes `haltReasons[sessionID]` ("nil when not halted"
  contract; stale-reason inheritance closed).
- **`376c033e2` F5** — adjudication recorded in the quarantine-purge probe header:
  the XCTExpectFailure legs are a DESIGN BOUNDARY, not a leak (quarantine = reversible
  suppression; recall gate blocks quarantined atoms from L2; KV-spill/corpus legs are
  clearSession's job; the true complete-purge is remove()+secure-delete — hardened same
  day by F6). No scrub-on-quarantine: would contradict digest-storage doctrine.

## Regression certification (post-batch, all three arms)

- beta `swift test`: **16,574 / 0 failures** (196 skips = known tax classes)
- stable `scripts/swift-test-headless.sh`: **PASSED** (XCTest gate + @Test batches green)
- QinaoRuntimeSDK `swift test`: **1,462 / 0 failures** (39 skips = real-LLM gates)

## Craft lessons

1. **TDD caught the fix's own bug twice**: F8's first clamp guard (`guard isFinite`)
   sent +Infinity to 0 — min/max DO order ±∞ correctly; only NaN needs the guard.
   F9's first test held the stream variable so outer onTermination never fired —
   cancel-the-consumer-Task is the correct probe shape.
2. **A pre-existing green can pin a vulnerability**: `test_validProposalAccepted`
   asserted the F12 fail-open (leaseRef with no enforcer passing). Fixing fail-closed
   *requires* consciously rewriting such tests — a reminder that "don't touch green
   tests" is not a security invariant.
3. **Doc-lies are first-class defects** (F2): the dangerous artifact wasn't code — it
   was a docstring claiming BASSovereignTokenAuthority verification that would make a
   future adopter skip signing. Honest-scope docstrings with a concrete pre-adoption
   recipe are the fix.
4. **Severity is boundary-relative**: the same finding is HIGH on a live IPC surface
   and LOW on a zero-caller scaffold — but fixing dormant scaffold fail-closed is cheap
   NOW and impossible to retrofit reliably later.
