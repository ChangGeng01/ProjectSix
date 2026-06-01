# ADR-026 — Sovereign Commit-Token Enforcement Seam (A1)

> **Status: BUILT + TESTED (ch1044 A1, opt-in).** Closes the deep-audit finding that the
> sovereign commit-token verifier was test-only: the substrate emitted tokens whose
> `signature` is a KEYLESS SHA256 tag that NO production code verified before an
> irreversible op. This ADR adds the real (non-test) verification component + the
> independent-digest discipline. Per ADR-014 it is OPT-IN / byte-equal-off.

## 1. The gap

- `makeCommitToken` signs each token with `sovereignDigestHexInjective` — a keyless
  SHA256 (a checksum anyone can recompute, not an authenticator) — and leaves
  `ed25519Signature == nil`.
- `BASSovereignTokenAuthority.verifyCommitToken` + `BASSovereignCommitTokenEd25519` were
  referenced ONLY by tests; the authority was never constructed in `Sources/`.
- The only code that recomputed `expectedActionDigest` from the approved render and
  verified was the test-only `Gate`. So D3's injective digest + the dual-sig guarded a
  comparison that never ran in production.

## 2. The seam

Two production components (no test-only):

- **`BASSovereignActionDigest.compute(...)`** (BASRuntimeCore) — the canonical
  action-digest, now the SINGLE source of truth that `makeCommitToken` uses (byte-equal
  to the prior inline digest). A verifier recomputes it from the ACTUALLY-APPROVED
  artifact and compares to the token's signed `actionDigest` — never reading the digest
  off the token.
- **`BASSovereignCommitEnforcer`** (BASSovereign, an actor) — a host holds one, built
  with its sovereign keyring (`BASSovereignTokenAuthority`):
  - `register(brainToken)` → mints the AUTHORITATIVE Ed25519 token into the single-use
    ledger (identity preserved; a real keyed signature + ledger tracking added).
  - `authorize(token, scope, target, expectedActionDigest, expectedPolicyHash)` →
    THROWS unless: `target ∈ token.allowedTargets` (closes the deep-audit
    allowedTargets-not-enforced gap), AND the authority verifies the Ed25519 signature,
    burns the nonce (single-use), checks TTL + scope + policyHash, AND
    `token.actionDigest == expectedActionDigest`.

The host MUST NOT execute the op on a throw.

## 3. Why this is sound

The `expectedActionDigest` is recomputed by the caller from the exact artifact it is
about to act on (the render body, the ticket set, the fold). A render body tampered (or
prompt-injected) between authorization and execution yields a different recomputed
digest → mismatch → deny. An aliased target (a token for A used to act on B) is rejected
by the `allowedTargets` membership check. Replay is rejected by the single-use burn;
staleness by TTL. The keyless SHA256 tag is NO LONGER the sole integrity field — the
Ed25519 authority signature is.

## 4. Proof (end-to-end tests)

`BASSovereignCommitEnforcerTests` (5): valid token authorizes; a tampered render body →
`actionDigestMismatch`; an aliased target → `targetNotAllowed`; a replay → `alreadyUsed`;
an expired token → `expired`. The actionDigest extraction is byte-equal (1301
commit/sovereign tests green).

## 5. Opt-in / byte-equal (ADR-014) + the remaining host-integration

- **Default OFF = byte-equal.** Nothing in the turn path constructs or calls the
  enforcer; `makeCommitToken` is unchanged (the digest extraction is byte-equal). A host
  that never builds an enforcer sees zero behavior change.
- **Enabling is the operator's.** A host constructs `BASSovereignCommitEnforcer(authority:
  <keyring-backed authority>)`, calls `register(...)` on each emitted token at turn end,
  and calls `authorize(...)` immediately before each irreversible op (renderHighRisk,
  memoryWrite, checkpointCommit, toolWrite, hostMutate) with the digest recomputed from
  the approved artifact for that scope.
- **What remains (honest):** the per-op-site invocation lives in the HOST's
  op-execution code (the substrate cannot gate an op it does not execute). This ADR
  ships the *seam* — the production verification API + the independent-digest discipline
  — so that wiring is now a one-call gate per op site, not a from-scratch build. The
  keyring source for the authority is `BASSovereignKeychainBinding` (NOT a per-process
  random key, NOT `withSeed("constant")`).
