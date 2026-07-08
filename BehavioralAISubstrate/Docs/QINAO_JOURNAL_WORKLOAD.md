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

## Next increments (planned, not yet built)

- **Increment 2b — the L2 verdict (device).** Route `add` through `runTurnAndIngest` for a
  calibrated verdict/abstention and fold it into the seal's `verdictRef`. Heavy: needs the
  on-device 4B — run on device, one call per entry.
- **Increment 3 — the "was I right?" loop.** Morning re-surfacing of open decisions feeds
  real outcomes back via the CORRECT public `observe()`/`finalize()` (NOT the private
  `advanceOpenTrial`), flipping `setDeliberationLoopEnabled` / `setShadowTrialFeedback` ON —
  firing ShadowTrial (H9) with real stakes.
- **Content store hardening.** Move the content sidecar into a `secure_delete`-ON SQLite
  table (via `BASSQLiteSecureDelete`) for uniform deletion-doctrine coverage.

## Honest limits (from the panel, kept)

1. **Mirror, not oracle.** Empty FactBank + 4B ceiling ⇒ "grounded verdict" is aspirational.
2. **Does NOT fire the Metal HIGHs (H2/H3).** Those live below decode — they need a separate
   GPU-kernel probe. The journal's success must not create a false all-clear.
3. **Retention is the real risk.** A journal that isn't opened fires nothing. The marathon
   domain (ship/drop micro-bets, auto-ingestable `fix(#N/HX)` commits) is the seed because it
   is behavior the operator already produces daily — and it is self-grounding (the git log IS
   the fact source), which partly answers the empty-FactBank problem.
