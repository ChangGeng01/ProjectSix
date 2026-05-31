# CH-1044 全面 Audit — Whole-Substrate Adversarial Review

> Second, BROADER pass (the first was scoped to this chapter's deltas). Six
> adversarial agents swept the whole substrate — crypto/canonical, sovereign safety
> lattice, system-wide determinism, boundaries/FFI, concurrency, honesty/errors —
> each trying to BREAK its dimension. Discipline: 亏的不要上 — land only SAFE /
> byte-equal fixes; document + defer anything that changes persisted values or
> behavior. The lattice itself, the TokenAuthority single-use path, and the
> coordinator value-type were all verified CLEAN.

## Landed this pass (SAFE / byte-equal)

| Finding | Sev | Fix |
|---------|-----|-----|
| `canonicalWarrantBytes` delimiter-join forgery (dormant) | CRIT-class | injective `lengthPrefixed` + count-prefixed witnessRefs |
| `canonicalManifestBytes` trust-anchor forgery + **arity** forgery (dormant) | CRIT-class | length-prefixed + count-prefixed fingerprints |
| `Int(Double)` trap in manifest load (unauth crash pre-verify) | HIGH | `safeEpochMs` clamp (byte-equal for valid dates) |
| Audit-ledger HMAC verify timing side-channel | MED | constant-time `isValidAuthenticationCode` |
| Audit-ledger Ed25519 sign swallowed failure (H1) | HIGH | log to stderr, no empty-sig-into-chain; comment H2 corrected |
| Context-classifier LRU cache race (concurrent double-miss) | MED | dedup before append (byte-equal single-threaded) |
| Rust `Vec::with_capacity(count)` OOM (2 FFI sites) | MED | cap to `buf.len()/N` (byte-equal for valid input) |
| Consistency-check "fail-closed halt signal" overclaim (M2) | MED | reworded: observation-only today, not a production halt |

All compile; 1050 sovereign/ledger/fingerprint/classifier tests green; both Rust
crates build.

## DEFERRED (RISKY — change persisted values or behavior; 亏的不要上)

> **UPDATE (ch1044 continued — on explicit operator request):**
> - **D6 RESOLVED** (`877548fc5`): internal `NSLock` (scoped `withLock` around sync
>   `perform*` helpers) serializes the off-actor SQLite transactions; concurrency test
>   added. Behavior-preserving.
> - **D3 RESOLVED** (`cbb27f846`): production commit-token/warrant digests now use
>   `sovereignDigestHexInjective` (SHA256 over length-prefixed canonical bytes) instead
>   of the `"|"`-join. Option (a) boundary-validation was proven INFEASIBLE (sessionID
>   legitimately contains `"|"`), so this is option (b) — byte-changing but
>   deterministic, no golden re-pin (no test pins the coordinator's computed tag). 3
>   tests; closes the allowedTargets + rendered-content boundary collisions.
> - **D2 — step-1 REVERTED, infeasible** (`dcbac9f74`+`06cdf849d` → reverted
>   `faccc38e4`): the "reject canonical separators at append" validation cannot be
>   byte-equal — the substrate LEGITIMATELY uses BOTH U+001F and U+001E as composite
>   delimiters in audit content (verdictRef `shadow_trial\u{1F}<id>`, warrant
>   witnessRefs→signalRefs U+001F array elements, `BASAgentObservationAuditEmitter`
>   U+001E records). 4 confirmations of the same lesson. The genuine fix is the
>   INJECTIVE re-encode (step-2): length-prefix the audit canonical under a NEW
>   schemaVersion gate (old entries verify under their form, new under injective) —
>   a version-gated, chain-affecting migration with byte-equality re-pinning. Genuinely
>   deferred as a focused migration; the canonical ambiguity is pre-existing and
>   low-exploitability (the composite refs are system-generated, not attacker-controlled,
>   and the ledger is Ed25519-signed + hash-chained).
> - **D4 — latent, not gated:** the constitution `versionSignature` is NEVER recompared
>   as a tamper gate (verified), so its delimiter-join forgery is UNREACHABLE. Pure
>   hygiene; left as-is to avoid churning a persisted never-gated field.
> - **D5 — operator-policy (flag-not-patch):** allowedTargets-not-enforced,
>   `revokeAllTokens(forSession:)` global-nuke, fail-soft store reads — each is a
>   behavior change needing an operator ruling (R1 discipline: don't change sovereign
>   behavior on a hunch). Documented, not auto-patched.
> - **D1 RESOLVED** (`f95ee7394`): evolution-service IDs/cooldowns now derive from the
>   injected turn clock + turn-stable content (was UUID/Date). Surprise: NO golden
>   re-pin was needed — the stress/canonical suites assert structure, not pinned ID
>   values. The determinism guard was extended with a non-empty evolution fixture so
>   the updateTickets→commit-token path is actually exercised.
>
> **Net remaining:** only **D2 step-2** (the injective audit-canonical migration) is a
> real deferred work item; D4 is unreachable/hygiene, D5 is operator-gated by design.


### D1 — 3 CRITICAL determinism leaks: `UUID()`/`Date()` ticketIDs reach commit-token signature bytes
The two PRODUCTION evolution services mint `ticketID`/`candidateID`/`cooldownUntil`
from `UUID()`/`Date()`/`.now` instead of the injected `request.recordedAt`:
- `EBrainHostRuntime+EvolutionService.swift:37` (ticketID), `:117,121,176,180`
  (candidateID + cooldown).
- `BASMLEvolutionService.swift:182-184` (the `BASCognitiveBrain` runTurn path).
That ID flows `updateTickets → commit-token actionDigest/nonce/signature → warrant →
audit actionRefs` — all CONSEQUENTIAL, so the turn is NOT replay-stable (fires on
essentially every production turn). The `BASCoordinatorTurnDeterminismTests` guard
misses it because its `StubEvolution` returns no tickets.
**Why deferred:** the fix (derive the ID from `request.recordedAt`) CHANGES output
bytes vs today's random output, so the stress-sweep baseline must be re-pinned — a
focused effort. (Today's output IS the bug; re-pinning is the point.) **Companion:**
extend the determinism guard with a non-empty evolution-service fixture.

### D2 — audit-ledger entry signing pre-image delimiter-join (live + hash-chained)
`basSovereignAuditCanonicalBytes` (BASSovereignEd25519Signing.swift:135-170) joins
`ruleIDs/signalRefs/actionRefs` with U+001F/U+001E and `fields` with a field-sep,
asserting (NOT enforcing) those control chars are absent. `signalRefs` embeds
`allowedTargets`. A control char in a ref forges/mutates an audit entry.
**Why deferred:** selfHashes + signatures are hash-chained + persisted; a layout
change breaks the chain. **SAFE interim (do first):** reject U+001F/U+001E in those
arrays at `append()` — byte-equal for legitimate content, closes the boundary shift.

### D3 — production commit-tag `sovereignDigestHex` `|`-join (resolved: option-(b) infeasible → injective + re-pin)
The byte-equal boundary-validation (reject separators at mint) was attempted and
REVERTED — a regression test proved identity fields legitimately contain `|`
(production `sessionID` = `host.primary|task|sentinel`), so it drove the healthy
turn to 0 tokens. The only correct fix is the injective encoder, which changes tag
values → stress-baseline re-pin (fold into D1's re-pin effort). The tag is not an
auth gate, so live impact is low. See CH_1044_SEVERE_AUDIT.md finding P RESOLUTION.

### D4 — constitution vault `versionSignature` (latent): multi-list flatten forgery + 64-bit truncation
`HostConstitutionCore.swift:1066-1094` (+ `basStableSignature` `prefix(16)`). Never
recompared as a tamper gate today → latent; persisted to SQLite → layout change
risky. Closes when a count-prefixed re-encode + full-width hash lands.

### D5 — behavior-changing safety/clarity items (flag-not-patch, per R1 discipline)
- **allowedTargets signed but not enforced** in `verifyCommitToken` — add a target
  membership check (could reject previously-accepted tokens → operator decision).
- **`revokeAllTokens(forSession:)` ignores `sessionID`** (global nuke) — rename or
  filter per-session (behavior change). At minimum a doc-warning (SAFE).
- **Fail-soft reads** (~20 sovereign/compliance stores) return `[]`/`nil`/`false` on
  a DB/FFI error, indistinguishable from "empty" — make them `throws` or log
  (behavior/signature change). The deletion-manifest read is the most compliance-
  sensitive.

### D6 — `BASUpdateTicketLifecycleSQLiteStorage.save` off-actor SQLite race (HIGH; SAFE fix available, deferred for care)
`save` runs on the global executor (nonisolated async on a `Sendable` class) and can
overlap its own transactions + lost-update `savesSinceCheckpoint`. Fix: an internal
lock across `BEGIN…COMMIT`. Spawned as its own task to verify no actor/lock deadlock.

## Verified CLEAN (checked, no finding)
Verdict lattice total-order + most-severe-wins + fail-closed FFI fallback;
TokenAuthority single-use (synchronous check-and-redeem, no TOCTOU); coordinator
value-type carries no shared mutable state; the Rust `bas-substrate-core` C-ABI
null/len/bounds handling; the injective `BASSovereignCanonicalBytes` (ch1044 fix);
the `.hashValue→SHA256` digest (#4); Set→Array ordering discipline (sorted or
order-preserving dedup); `SCAFFOLD_VS_WIRED.md` honesty ledger.
