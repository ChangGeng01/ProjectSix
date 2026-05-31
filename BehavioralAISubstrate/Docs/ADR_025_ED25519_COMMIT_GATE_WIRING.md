# ADR-025 — Ed25519 Commit-Gate Wiring (#2 / DEFER-1)

> **Status: DESIGN — first brick landed (ch1044).** Wire the dormant Ed25519
> `BASSovereignTokenAuthority` into the production commit gate, which today mints a
> SHA256 keyed-hash `signature` tag. This is a *strengthening* (asymmetric >
> symmetric) — the safe direction — but the commit gate is the most sovereign path,
> so it is dormant-first / opt-in / byte-equal-off. The investigation surfaced a
> decisive crypto constraint that makes the wiring an operator policy decision, not
> a mechanical swap.

## 1. The gap (verified)

- **Production** (`EBrainRuntimeCoordinator+SovereignCommit.swift:161`):
  `makeCommitToken` mints a `BASSovereignCommitToken` whose `signature` is
  `sovereignDigestHex([...])` — a deterministic **SHA256 keyed-hash tag**
  (replay-safe post-HIGH-1, but **symmetric**: anyone with the inputs reproduces
  it; there is no signing authority / public key).
- **Dormant** (`BASSovereignTokenAuthority.swift`): a COMPLETE Ed25519 authority —
  `issueCommitToken` (Ed25519-signs, single-use), `verifyCommitToken` (verifies +
  redeems, lines 230-284), `verifyingKey` public key, minted-token state. It is
  proper asymmetric crypto, but **not wired** to the production gate.

## 2. The decisive finding: CryptoKit Ed25519 is RANDOMIZED

`issueCommitToken` uses a random `UUID` tokenID + fresh nonce + `now()` — which
conflicts with the deterministic production path (HIGH-1). The obvious fix is a
deterministic-input variant. **But the rigorous test caught a deeper problem:**

> CryptoKit's `Curve25519.Signing.signature(for:)` is a **RANDOMIZED (hedged)**
> Ed25519 — signing the SAME message with the SAME key twice yields **different
> signatures** (verified: `testDeterministicMintHasReproducibleIdentity` asserts
> `a.signature != b.signature`).

So **full-token byte-determinism INCLUDING the signature — the HIGH-1 replay
contract (`testSovereignCommitTokensAreReplayDeterministic` asserts tokens incl.
nonce+signature are bit-identical) — is NOT achievable with a CryptoKit Ed25519
signature.** Ed25519 *can* be deterministic (RFC 8032), but Apple's implementation
is not. This is the crux of #2: you cannot have BOTH a CryptoKit-Ed25519 signature
AND a bit-reproducible token.

## 3. Resolution options (an OPERATOR policy decision)

Like the missing-lineage ruling (ADR-023 §8), this is a sovereign policy call, not
an implementer's:

- **(A) Relax replay-determinism to exclude the signature.** Keep the IDENTITY
  (tokenID/nonce) deterministic (the cross-session-stability purpose of HIGH-1);
  drop the signature from the byte-determinism check. Simplest. Cost: changes the
  HIGH-1 contract (`testSovereignCommitTokensAreReplayDeterministic` would assert
  identity-determinism, not full-token). Acceptable IFF nothing depends on
  signature-byte-determinism.
- **(B) Dual signature (recommended).** Keep the deterministic SHA256 tag (for
  replay) AND add an Ed25519 signature field (for crypto authority). Replay checks
  the tag; crypto verification uses the Ed25519 sig. PRESERVES HIGH-1 unchanged AND
  adds asymmetric authority. Cost: a `BASSovereignCommitToken` field add + dual
  verification. Most work, least disruption to existing contracts.
- **(C) Deterministic Ed25519 impl.** Use RFC-8032 textbook (deterministic) Ed25519
  instead of CryptoKit's randomized one. **Discouraged** — "don't roll your own
  crypto"; loses the platform-audited CryptoKit path.

**Recommendation: (B)** — it adds the asymmetric authority the audit wants without
relaxing HIGH-1 or hand-rolling crypto. But the choice is the operator's.

## 4. Dormant-first wiring (whichever option)

The carrier idiom: the host holds the Ed25519 `BASSovereignTokenAuthority` (key +
single-use state); the commit gate takes an **opt-in signer** (default nil → the
SHA256 path, byte-equal). When provided, the gate mints/verifies via Ed25519. The
coordinator stays a stateless value-type; the authority is host-held (it owns the
key + minted-token ledger, which is the single-use mechanism). Default-OFF →
production is bit-identical; enabling is the operator's, gated on the §3 choice.

## 5. What landed (the safe first brick)

`BASSovereignTokenAuthority.issueDeterministicCommitToken(for:tokenID:nonce:issuedAt:)`
— a deterministic-IDENTITY Ed25519 mint (caller supplies tokenID/nonce/issuedAt;
real Ed25519 single-use token that `verifyCommitToken` validates). Additive —
production `makeCommitToken` is untouched → byte-equal. 4 tests:
reproducible-identity (+ the randomized-signature finding), verifies, tampered
signature rejected, single-use redemption. This is the foundation BOTH options (A
and B) build on; it does NOT wire anything into production.

## 6. Red-line / phased plan

- **Brick (LANDED):** the deterministic-identity Ed25519 mint + tests. Byte-equal
  (additive). No production change.
- **Decision (RESOLVED, ch1044):** operator chose **B — dual signature**. The
  `BASSovereignCommitToken.ed25519Signature: String?` field LANDED (default `nil` →
  byte-equal; 933 sovereign tests green incl. the HIGH-1 replay-determinism test).
  The SHA256 `signature` tag stays the replay-stable identity; the Ed25519 sig is
  the OPTIONAL asymmetric authority carried alongside it.
- **Dual-mint / dual-verify (next, gated):** production `makeCommitToken` populates
  `ed25519Signature` via an OPT-IN host-held Ed25519 signer (default nil →
  byte-equal); a dual-verify checks the SHA256 tag (as now) AND the Ed25519 sig
  (when present, via the authority's public key). The commit gate is the most
  sovereign path — this stays CLOSED until a byte-equal-off proof + the full
  sovereign suite green. (The Ed25519 sig must cover the same canonical bytes the
  SHA256 tag does, incl. the deterministic issuedAt — the threading is the next
  careful step.)
- Honest boundary: design + a safe additive brick; the production gate is NOT
  touched, and the determinism policy is the operator's.
