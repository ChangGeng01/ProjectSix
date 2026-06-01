# CH-1044 深入 Audit — Depth Pass

> A third, DEEPER audit (5 adversarial agents) after the breadth passes (最严查 4-agent,
> 全面 6-agent). Focus: re-verify the FRESH fixes adversarially (R1 lesson — my own code
> had a CRITICAL forgery this session, and a "fix" was later proven infeasible), and probe
> dimensions the breadth passes treated as trusted: downgrade/version-gate, end-to-end
> attacker dataflow, crypto SOUNDNESS (not just collisions), and a completeness critic.
> It found real things the breadth passes missed.

## Fixed this pass (safe, concrete) — `0bbe14d78`

1. **CRITICAL — single-use replay bypass.** `verifyCommitToken`/`verifyWarrant` gated
   replay on `record.redeemed && token.singleUse`; `singleUse` is attacker-mutable and
   NOT in `canonicalCommitBytes` → flip to `false`, replay a redeemed token (Ed25519 sig
   still verifies). **Fixed:** enforce from the server record (`if record.redeemed`).
   This contradicted the register's "Verified CLEAN" (that pass checked concurrency, not
   authentication of the flag). Lesson: "no TOCTOU" ≠ "the control is sound."
2. **D3 was incomplete.** Two `sovereignDigestHex` `|`-join sites were missed —
   `buildSovereignAuditEntry` signature (proven-collidable over 3 adjacent lists) and
   `sovereignPolicyHash`. Fixed via `sovereignDigestHexInjective`; the audit-entry one
   needs per-list `.list()` count markers (a FLAT length-prefix of 3 adjacent lists is
   STILL arity-ambiguous — the re-verify agent proved it).
3. **Poisoned-atom NaN DoS.** `BASVectorIndex` validated dimension but not finiteness; a
   NaN cosine score violates strict-weak-ordering in `sort(by:)` → trap (one-atom DoS).
   Fixed: reject non-finite at insert + NaN-safe sort key at all 3 sort sites.

## Verified SOUND under deep probing (no fix needed)
The injective `lengthPrefixed` encoder (round-tripped 22k adversarial inputs);
D1 determinism (seeds turn-stable, truncation >>birthday bound); D6 lock (never across
`await`, covers the transaction paths); the D2 1.2.0 canonical (injective + per-entry-
version chain verify, cross-version forgery impossible); the risk model is monotonic-up
(prompt text can only RAISE risk → no prompt→verdict-downgrade); kill-switches are
escalation-only; default evolution service review-gates every ticket; HMAC↔Ed25519 mode
confusion fails closed; the deterministic-mint guards (tokenID + nonce) hold.

## ARCHITECTURAL findings — feature-gaps / operator-policy, tracked not auto-patched

These are NOT code bugs to patch in an audit pass — they are unbuilt/ungated seams. The
honest framing (matching `SCAFFOLD_VS_WIRED.md`): the SOVEREIGN ENFORCEMENT LAYER is
largely SCAFFOLD — built + tested, NOT wired into production. The breadth passes audited
the scaffold's correctness; the deep pass names the consequence.

- **A1 — The sovereign commit-token / Ed25519 verifier is entirely UNWIRED in production**
  (converged across the dataflow + crypto agents). Production tokens carry a keyless
  SHA256 tag that NOTHING verifies; `BASSovereignTokenAuthority` is never constructed
  outside tests. So D3 + the dual-sig guard a comparison that never runs in production.
  This is the single load-bearing item: there must be a real (non-test) verification seam
  that authenticates the token against an INDEPENDENTLY-recomputed action digest before
  any irreversible op. **→ spawn-task.**
- **A2 — No verify-on-reload for the audit ledger.** `rehydrate` copies persisted entries
  into state with NO signature/chain check; `verifyChainIntegrity`/`auditChainFull` exist
  but have ZERO `Sources/` callers. A tampered SQLite file (e.g. `schemaVersion`
  downgraded to the forgeable 1.0.0 form) is accepted unverified. **→ spawn-task.**
- **A3 — Constitution `hardNoGo` is unauthenticated, ungated, and unlogged.** The L1
  boundary the whole lattice assumes fixed can be weakened with no dual-key/verdict/audit;
  its "signature" is an unkeyed 64-bit TRUNCATED hash (`basStableSignature`). The
  `BASSovereignHighConsequenceGate` (whose doc names "change sovereign policy" as the
  canonical dual-key action) is never invoked by the constitution-mutation path. **→
  spawn-task.**
- **A4 — Secondary hardening (documented):** the audit-entry DEFAULT `schemaVersion` is
  the forgeable "1.0.0" (all prod producers opt into 1.2.0, but the default is a footgun —
  flip it / add an append-floor); the SQLite ledger joins array fields with a literal `,`
  so a comma-bearing ref desyncs the canonical on reload; the `hardNoGo` matcher has no
  NFKC/zero-width normalization (Unicode-evadable); the shadow-trial `finalize` takes the
  pass/fail outcome as a caller parameter (not derived from observed effects);
  `verifyCommitToken` signs but does NOT enforce `allowedTargets` membership (D5).

The A4 items are individually small but several are behavior-changing (operator-policy,
R1 discipline) — they belong in a focused sovereign-wiring effort alongside A1–A3, not an
audit pass.
