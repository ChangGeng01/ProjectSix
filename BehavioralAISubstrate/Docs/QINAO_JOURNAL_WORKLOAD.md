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

## Next increments (planned, not yet built)

- **Increment 2 — the L2 verdict + Ed25519 ledger.** Route `add` through the verified public
  `runTurnAndIngest` (`EBrainRuntimeCoordinator+RunTurn.swift:2200` = full L1–L14 spine +
  ingest) so each entry gets a calibrated verdict/abstention, and seal it into the
  `BASSovereignAuditLedger` hash chain (`verifyChainIntegrity`). Fires L10/L11/L14 + the
  sovereign audit ledger. Heavy: needs the on-device 4B — run on device, one call per entry.
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
