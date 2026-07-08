# The Ledger — Qinao's first real daily workload (#20)

**2026-07-08.** The strategic pivot: after the mega-audit closed every fixable finding
(week-tier + immediate-tier + project-tier H23/#13/#14/#15/#16/#18/#19), the four systemic
diseases it exposed — comment-lies, fail-open, **loaded-gun dormancy** (7 of 11 HIGHs had
no production caller), corrupt==empty — all shared ONE root: **no live application ran the
substrate.** An audit can only find un-fired chambers; only a real daily workload fires them
and truth-checks the ~300 never-deep-read L3–L14 organ files.

A 6-proposer / 2-judge Opus design panel (repo-verified) chose, and the operator confirmed:
**The Ledger — a sovereign decision & thread journal.** The moat is exactly what no cloud
LLM can be: on-device, zero-egress, cross-boot forever-memory, calibrated-abstention, a
tamper-evident record. Framing rule (non-negotiable): **a mirror, not an oracle** — the 4B
L2 abstains and the FactBank is empty, so the value is sovereign memory + honest recall,
never confident answers.

## Increment 1 — the sovereignty MEMORY loop (SHIPPED)

`Sources/BASJournalCLI/main.swift` + `BASJournalCLI` executable target.

```
swift run BASJournalCLI add "DROP sampling-spec: 0.88x, free-form wall"
swift run BASJournalCLI recall [query]
swift run BASJournalCLI forget <id-prefix>
swift run BASJournalCLI count
```

Fires, on a live daily path, the chambers the audit only inspected:
- **L8 event-sourced memory admission** — `BASEventSourcedMemoryAtomStore.admit` over the
  routed Rust event log.
- **H14 cursor-paginated recall** — `recall` reads the FULL session history (the pagination +
  fail-closed fix from #14).
- **Deletion doctrine (H11 tombstone)** — `forget` removes the atom and verifies it no longer
  projects; plus a secure-deleted content file.

Verified end-to-end by `BASJournalCLIIntegrationTests` (spawns the real binary against a
throwaway `QINAO_JOURNAL_DIR`): seed → add → cross-process recall → forget → gone.

### Key finding — the workload truth-checked the substrate

The design panel assumed "forever memory." The substrate's actual contract is narrower and
by design: **`BASMemoryAtomReducer` persists atom STATE + a SHA256 content DIGEST, never the
raw text** (L8 privacy doctrine — "replay produces empty content; hosts cache content
separately if needed"). So a journal that must recall real entries owns its own content
store. Increment 1 uses a per-atom content sidecar under `content/<id>.txt`, and on `forget`
**overwrites the bytes then unlinks** — the file-level analogue of the SQLite `secure_delete`
the stores now default to (#16), so a sovereign journal's deleted entry is truly gone. This
is precisely the kind of contract-vs-assumption gap that only a live workload surfaces.

## Increment 2 — the Ed25519 sovereign audit ledger (SHIPPED)

`Sources/BASJournalCLI/Ledger.swift` + the `ledger` command.

```
swift run BASJournalCLI ledger    # verify the Ed25519 chain + show every sealed action
```

Every `add` and every `forget` is now **sealed** into a persistent, append-only,
Ed25519-signed, hash-chained `BASSovereignAuditLedger` (`ledger.sqlite`), keyed by an on-device
sovereign identity (`identity.key`, minted `0600` at creation). This fires, on the live daily
path, the chambers the mega-audit only inspected:

- **M87 Ed25519 signing** — public-key-verifiable seals (a verifier needs no secret).
- **M91 SQLite persistence** — the chain survives process restart (cross-boot forever).
- **H13 atomic append rollback** — a persist failure leaves memory == disk (the #13 fix).
- **ch1044 verify-on-reload / H14 truncation cross-check** — a tampered or truncated chain
  fails closed (`ledger` exits 1) rather than serving forged history.

**Scope, stated honestly (mirror, not oracle).** The seal records WHAT the sovereign did —
`admit:governed` / `forget:tombstoned` plus a SHA-256 content digest — **NOT a cognitive
verdict.** The L2 adjudication (routing `add` through the verified public `runTurnAndIngest`,
`EBrainRuntimeCoordinator+RunTurn.swift:2200` = full L1–L14 spine + ingest, for a calibrated
verdict/abstention) is **deferred to a device increment (2b)** because it needs the heavy
on-device 4B; sealing a confident answer here would be dishonest. The 3 first-run seed threads
are unsealed sample data; the ledger is the record of operator actions taken through the CLI.

**Threat-model boundary (honest).** `identity.key` (the 32-byte private key, `0600`) sits beside
`ledger.sqlite`, so this is **CLI-grade** tamper-evidence: it defends against an attacker who can
edit the DB but not read the key. An attacker who reads the key can forge a valid replacement
chain. A production *device* build binds the seed to the Secure Enclave / keychain
(`BASSovereignKeychainBinding`) and keeps the public half in a separate manifest — deliberately
not wired into a Mac CLI. A count-consistent truncation that also rewrites the segment
high-water mark is likewise out of scope (would need the tail hash bound into a signed rotation
marker). What is guaranteed: signature/link tamper, naive tail truncation (partial and
truncation-to-empty), key loss, and a corrupt store all **fail closed**.

Verified end-to-end by `BASJournalCLIIntegrationTests`: add→ledger verifies intact, forget seals
a tombstone, out-of-band signature tamper exits 1, and out-of-band tail truncation (partial +
to-empty) exits 1.

## Increment 3 — the "was I right?" ShadowTrial loop (SHIPPED)

`Sources/BASJournalCLI/Trials.swift` + `TrialIndexStore.swift` + the `bet`/`review`/`right`/
`wrong`/`verdict` commands.

```
swift run BASJournalCLI bet "DROP sampling-spec: 0.88x" -q "did latency actually regress?"
swift run BASJournalCLI review                 # open bets, oldest first (the morning check-in)
swift run BASJournalCLI right <trial-id>       # you judge it right → finalize .passed
swift run BASJournalCLI wrong <trial-id> [why] # you judge it wrong → finalize .failed
swift run BASJournalCLI verdict <trial-id>     # your recorded outcome + the promotion gate
```

A journal DECISION is opened as a shadow TRIAL. Open bets are re-surfaced by `review`; the
operator records the REAL outcome, fed back through the substrate's **CORRECT public
`BASShadowTrialCoordinator.finalize()`** (NOT the private `advanceOpenTrial`), firing the
H9-fixed optimistic-concurrency paths and sealing every event into increment-2's SAME Ed25519
`ledger.sqlite` (under `journalSessionID`, so `ledger` displays them and the truncation
high-water check stays correct).

**Key finding — the workload truth-checked the substrate again.** The coordinator holds trial
state **in memory only**; it appends to the ledger but never reads it back, so a fresh process
starts blank. That is the digest-only contract from increment 1, one layer up. So (a) the CLI
owns a `TrialIndexStore` (a `secure_delete`-ON SQLite index of open bets) for cross-boot
`review`, and (b) the substrate gained a small **opt-in `resumeTrial(candidate:record:)`** seam
(purely additive, byte-equal for consumers that don't call it) so a later process can re-inject
a persisted open trial and drive it through the real `finalize()`.

**Honest framing (findings from the adversarial panel, all fixed).** The `verdict` is NOT an
independent judgment of whether the bet was truly right — the substrate has no window onto the
world. The OPERATOR records the outcome; the substrate faithfully records + gates it. The
promotion gate is fail-closed and follows deterministically from the recorded outcome. The
resolve path is a **single atomic `finalize`** (the reason is a sidecar note, not a second
ledger append) with a **ledger-authoritative idempotency guard** — a retry after a torn
finalize/index write reconciles from the chain instead of double-sealing. `forget` now also
purges the trials index (deletion doctrine).

Verified by `BASShadowTrialCoordinatorTests` (resume + guards) and `BASJournalCLIIntegrationTests`
(bet→review cross-process, right/wrong fail-closed verdicts, and idempotent-retry-does-not-double-seal).

## Increment 2b — the L1–L14 governance verdict (SHIPPED)

`Sources/BASJournalCLI/Verdict.swift`.

Each `add` now runs the entry through the verified public spine (`BASCognitiveBrain.process` →
`EBrainRuntimeCoordinator.runTurn`) and folds the sovereign **governance** verdict into the seal's
`verdictRef` — replacing increment 2's hardcoded `"admit:governed"` assertion with an earned,
tamper-evidently proven disposition, e.g. `admit|gov2:shadowLock|permit:answer|risk:low|abstain`.

**Feasibility surprise — it is fully Mac-runnable, no 4B.** The grounding panel (and an empirical
run: exit 0, ~14 ms) confirmed `runTurn`'s synchronous spine touches only the small in-tree 68 KB
`BASContextClassifier.mlmodel`, never the 4B MLX. The sealed governance verdict is byte-identical
Mac-side and device-side (a device's neural core feeds prose/organ artifacts only, never the
risk→permit→verdict lattice), so there was **nothing to device-defer** after all. Added deps:
`BASHostKit` + `BASPolicy`; the seal stays hardened 1.2.0 (the injective canonical form is exactly
what makes the richer `|`/`:` verdictRef collision-safe); all truncation/verify gates untouched.

**Honest reality (verified by running, then corrected in the comments — mirror, not oracle).** The
sovereign lattice does NOT rubber-stamp a private journal write: a benign entry seals
`gov2:shadowLock|…|abstain` (it abstains because it can't sovereignly GROUND an ungrounded write —
`gov2:pass/allow` effectively never occurs here), and a manipulation-cued entry ESCALATES to
`gov2:memoryFreeze|permit:delay|risk:high`. The value over the old string: that string *asserted*
governance with nothing behind it; `gov2:<level>` is the lattice's real, deterministic, sealed
disposition, and `gov2:unavailable` honestly marks a spine that couldn't run. It is a governance
disposition proving the lattice ran — never a judgment that the logged decision is *right*.

**Hardened by an adversarial refute panel (find→verify) — 8 findings, all fixed:** the `ledger`
display truncated the honesty-critical `|abstain` disposition (fixed → dynamic width); the
abstention predicate omitted `.draftOnly`/`.localOnly` (fixed → uses the substrate's own
`isProtective`, now public); a `BrainBox` actor-reentrancy early-nil (fixed → shared in-flight
Task); and comment/example/legend honesty (a docstring showed a never-occurring `pass/allow`; help
now explains `shadowLock/abstain` is the expected normal disposition, not a danger flag). One
finding — a pre-existing `.mlmodelc` temp-compile leak in the shared `BASContextClassifierMLAdapter`
that the workload now fires per `add` — was **spawned as its own task** (critical shared substrate,
deserves a focused tested session), not rushed into this increment.

Verified by `BASJournalCLIIntegrationTests`: add seals a `gov2:` verdict (not the hardcoded
string) and the chain still verifies; the verdict is deterministic; and it escalates the risk band
on manipulation cues.

## Next increments (planned, not yet built)

- **Increment 3b — the deliberation-loop toggles. VERDICT: NOT SHIPPED — substrate gap, not a
  deferral.** The envisioned feature was: wire `setDeliberationLoopEnabled` /
  `setShadowTrialFeedback` so a live EBrain add-turn CONSUMES the journal's recorded ShadowTrial
  bet outcomes into the sealed governance verdict. A two-report grounding audit (source-verified,
  2026-07-08) found **the channel from the journal's bets to a future add's sealed verdict does
  not exist in the substrate.** Building the toggle-wiring would ship a no-op dressed as a loop —
  exactly the dormant-feature pretense this workload exists to kill. So 3b-as-envisioned is
  **classified VACUOUS and is NOT built.** The precise reasons, each verified in source:

  1. **The two systems are disjoint.** The journal's bet loop (`Trials.swift`) drives
     `BASShadowTrialCoordinator.submit/resumeTrial/finalize/promotionVerdict`, which is memory-only
     and **never calls `runTurn`**; its outcomes influence only its own `promotionVerdict` and the
     SQLite trial-index sidecar. `grep` of `Sources/BASJournalCLI/` confirms **zero** references to
     `pendingTrialLedgerIn`, `resolvedTrialSink`, `shadowTrialFeedbackEnabled`, or
     `BASShadowTrialFeedbackLedger` — the coordinator and the in-turn feedback carrier are
     different types with no wiring between them.

  2. **The in-turn feedback block is OBSERVATION-ONLY by design.** The only trial-consumption block
     in `EBrainRuntimeCoordinator+RunTurn.swift` (lines 145-153) reads a *host-supplied*
     `BASShadowTrialFeedbackLedger` (NOT the journal's coordinator) and its sole effect is
     `resolvedTrialSink(evaluated)`. The header comment (132-153) states it verbatim: feeds
     `resolvedTrialSink` ONLY — *gates nothing; NOT in any render / seal / verdict / governance /
     canonical-bytes / hash path.* Nothing reads `evaluated` back into `riskCard` / `permit` /
     `thoughtFrame`.

  3. **The verdict core has no trial parameter.** `computeVerdictDecision` /
     `buildSovereignVerdict` (`EBrainRuntimeCoordinator+SovereignVerdict.swift`) are pure functions
     of `budgetFrame` / `riskCard` / `actionPermit` / `emergencyBrake` / `activeKillSwitches` /
     `policyLineage`. There is **no trial-state input at all** — trial outcomes structurally cannot
     enter the sealed lattice.

  4. **The feedback ledger is DORMANT and structurally identity.**
     `BASShadowTrialFeedbackLedger.evaluate` (`BASMemory`, lines 60-113) is documented DORMANT: it
     carries, never learns (pending-state vocab and terminal-verdict vocab are disjoint), and no
     real `actualOutcome` signal source exists (ADR-021 prereq absent). Even the host-side carrier
     it would read has nothing to learn from yet.

  5. **The journal never turns the flags on.** The add path is `BASCognitiveBrain.makeWithDefaults()
     → brain.process(text, …)`; both `deliberationLoopEnabled` and `shadowTrialFeedbackEnabled`
     default `false` (constructor) and are never set on the journal route, so the sealed verdict is
     **byte-identical** (红线 7 / ADR-014) to the flag-off pipeline. The flags are a real substrate
     *capability* for a host that populates the carriers — they are simply not a journal-bet loop.

  **What IS possible today (and is honestly just observation, if ever built):** flipping the toggle
  on the journal add would, at most, fire `resolvedTrialSink` with the *host-owned* carrier's
  records — an observation side-channel the CLI could print as "trials the substrate observed this
  turn." That would be legitimate **only if labeled as observation** and **never** as a
  verdict-influencing or bet-consuming loop. It is not built here because on the journal route the
  carrier is empty (nil), so the sink would fire on nothing — a print with no content is not a
  feature.

  **What would have to exist in the substrate for the envisioned loop to become real** (so this is
  a precise gap, not defeatism):
  - a signal source that turns a resolved `promotionVerdict` / finalized trial completionState into
    a real `actualOutcome` (the ADR-021 prereq that is currently absent), so
    `BASShadowTrialFeedbackLedger.evaluate` stops being structural identity and actually *learns*;
  - a bridge type that adapts the journal's `BASShadowTrialCoordinator` state into a
    `pendingTrialLedgerIn` carrier keyed to the PRIOR turn (respecting the
    NEVER-EFFECTIVE-SAME-TURN doctrine at RunTurn lines 132-141);
  - a genuine consumption edge: a trial-state parameter threaded into `computeVerdictDecision` (or
    a documented `riskCard`/`policyLineage` write-back from the evaluated outcomes), which today
    does not exist and would itself need an ADR + byte-equality re-baselining under 红线 7.

  Until those three exist, 3b remains a **documented substrate gap**. This is the strictest honest
  outcome: the workload did its job by exposing that the "close the loop" feature has no substrate
  channel, and we refuse to ship theater in its place.

## Increment 3c — opt-in deliberation on the add turn (SHIPPED)

`Sources/BASJournalCLI/Verdict.swift` + `add [--deliberate]` / `bet [--deliberate]`.

3b established that `setShadowTrialFeedback` is vacuous for the journal. `setDeliberationLoopEnabled`
is the OTHER toggle — and unlike 3b's, it is a **real** capability: enabling it on the add turn runs
extra (cheap, CPU) deliberation passes + a caution block that can change the sealed governance
verdict. 3c wires it as an **opt-in** `--deliberate` flag.

**Why opt-in + a distinct namespace.** Two facts were established EMPIRICALLY (not just read), which
is exactly why 3c is real where 3b was theater:
- It is **deterministic** and **genuinely changes the verdict** — the anti-theater teeth: for
  `maybe delete the whole thing, not sure it matters` the baseline seals `gov2:…|risk:high` and
  `--deliberate` seals `gov2d:…|risk:medium`. The `gov2d:` namespace records that deliberation ran,
  so the sealed record distinguishes a deliberated verdict from a baseline one.
- It is a **RE-ASSESSMENT, not a safety raise.** Measured, it changes only a small minority of
  entries and can LOWER or raise the risk BAND — so forcing it on could *under*-caution. Hence
  opt-in and default-OFF (the baseline stays byte-equal to increment 2b: the coordinator's flag
  defaults false and setting it false is a no-op). Critically, the re-rating only moves the risk
  BAND; it never flips the sealed disposition — a protective `abstain`/`permit:delay` stays
  protective (the delete-everything example keeps `permit:delay|abstain`), so a lower band is a
  calmer re-read, never a green light.

**Hardened by an adversarial refute panel (find→verify) — the confirmed defects, fixed:**
- **MEDIUM (content integrity):** the first `--deliberate` parser stripped the token from ANYWHERE
  in the args, so a decision note whose text contained `--deliberate` (e.g. `add remember to pass
  --deliberate to the harness`) had that word silently deleted from the stored content AND the
  sealed SHA-256 digest — a tamper-evident ledger rewriting the content it attests to. Fixed:
  `--deliberate` is now a **leading option only** (parsing stops at the first content token; `--`
  is an end-of-options sentinel), so a text-internal `--deliberate` is preserved byte-faithfully.
- **LOW (honesty):** the help now states the re-rating never flips the protective disposition, so a
  lower risk band is not read as a green light.

Verified by `BASJournalCLIIntegrationTests`: `--deliberate` seals `gov2d:` (baseline stays `gov2:`)
and the chain verifies; the verdict is deterministic; it genuinely differs from baseline beyond the
namespace (anti-theater); and a text-internal `--deliberate` is not stripped from the sealed
content. (Note: `bet`'s pre-existing `-q` mid-stream delimiter has the same class of edge for
unquoted text containing a standalone `-q` token; quoting protects it — left as-is, out of 3c scope.)

## Increment 4 — content-store hardening (SHIPPED)

`Sources/BASJournalCLI/ContentStore.swift`.

Content moved from increment 1's per-atom `content/*.txt` files into a `secure_delete`-ON SQLite
store (`content.sqlite`). This is a real fix, not polish: on **APFS (copy-on-write)** the old
in-place-overwrite secure-delete could land on new blocks and leave the old plaintext in the
freed region — the "truly gone" guarantee under-delivered. SQLite `secure_delete` zeroes freed
pages, matching the #16 doctrine across the 18 substrate stores. A one-time, verify-before-delete
migration moves any legacy `*.txt` into the store (a MOVE, content preserved), and `forget`
removes the row.

**Hardened by an adversarial refute panel (find→verify) that confirmed 7 findings, all fixed:**
- **WAL secure-delete gap** (found by my own smoke test first): under WAL, the plaintext INSERT
  frame lives in `content.sqlite-wal`, which `secure_delete` (main-DB-only) never touches — so a
  forgotten entry's plaintext lingered in the WAL. `delete()` now runs a **verified**
  `wal_checkpoint(TRUNCATE)` (`sqlite3_wal_checkpoint_v2`, asserting `framesLeftInWAL == 0`); a
  busy/blocked checkpoint throws rather than reporting a clean delete, and the store checkpoints
  on open to scrub a WAL orphaned by a crash between a delete and its checkpoint.
- **Concurrent-migration data loss**: a file being secure-deleted is zeroed (all-NUL) before
  unlink, so a racing second process could read the all-NUL buffer and (via `bind_text(-1)`)
  overwrite the correct row with an empty string. Migration now skips empty/NUL reads and is
  **non-clobbering** (retire, don't re-import, if the store already holds the atom).
- **Embedded-NUL truncation**: `bind_text(-1)` truncated content at the first NUL. Now binds by
  explicit UTF-8 byte length and reads back by `column_bytes` (defense-in-depth — CLI argv can't
  carry a NUL, but a file/stream path could).
- **Unverified legacy retirement** + **error-vs-absent confusion**: `retireLegacyFile` now
  verifies the file is gone; `get()` THROWS on a real DB error (vs `nil` for genuine absence) so
  `readContent` never resurrects a forgotten legacy file on a transient error, and `contentIsGone`
  is fail-closed.

Verified by `BASJournalCLIIntegrationTests`: content in SQLite not files; the forgotten
plaintext is absent from EVERY `content.sqlite*` file (incl. the `-wal`); legacy files migrate +
retire; and migration does not clobber existing store content.

## Honest limits (from the panel, kept)

1. **Mirror, not oracle.** Empty FactBank + 4B ceiling ⇒ "grounded verdict" is aspirational.
2. **Does NOT fire the Metal HIGHs (H2/H3).** Those live below decode — they need a separate
   GPU-kernel probe. The journal's success must not create a false all-clear.
3. **Retention is the real risk.** A journal that isn't opened fires nothing. The marathon
   domain (ship/drop micro-bets, auto-ingestable `fix(#N/HX)` commits) is the seed because it
   is behavior the operator already produces daily — and it is self-grounding (the git log IS
   the fact source), which partly answers the empty-FactBank problem.
