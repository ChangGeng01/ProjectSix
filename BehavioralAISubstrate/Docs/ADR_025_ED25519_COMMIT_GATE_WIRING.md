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
- **Dual sign/verify — LANDED (ch1044, POST-HOC):** `BASSovereignCommitTokenEd25519`
  `.signed(token, with: key)` returns a copy with `ed25519Signature` populated — an
  Ed25519 sig over the token's `identityCanonicalBytes()` (every stored field except
  the two signatures) — and `.verify(token, with: publicKey)` →
  `{ absent / valid / invalid }`. The SHA256 tag is untouched (replay-stable
  identity); the Ed25519 sig is verifiable from the token ALONE. Crucially this is
  **post-hoc** — the host signs the FINISHED token (whose identity fields already
  encode the mint-time `issuedAt`), so **NO threading** of a signer through the
  sovereign commit-token call chain is needed, and production `makeCommitToken` is
  **untouched → byte-equal by construction** (no opt-in flag required). 8 tests
  (sign→verify, absent, tampered-identity→invalid, wrong-key→invalid); 937
  sovereign tests green. This avoided the most invasive option (threading an opt-in
  signer into the production gate) entirely.
- **Remaining (optional, host integration):** a host turn loop that opts in — takes
  the coordinator's commit token, calls `.signed(...)` with its key, re-injects the
  dual-signed token, and verifies at the pre-commit gate via the public key (the
  carrier/sink idiom). That is host wiring, not a substrate change. The deterministic
  SHA256 tag remains the replay identity; the Ed25519 sig is the asymmetric authority
  the audit (#2 / DEFER-1) wanted — now real and verifiable.
- Honest boundary: design + a safe additive brick; the production gate is NOT
  touched, and the determinism policy is the operator's.

## Gated-execution seam LANDED — option B is now FUNCTIONAL end-to-end (`BASSovereignGatedCommit`)

The operator chose **B (dual signature)**. Beyond the primitives above, the piece that was missing is
the one-call composition that ties the enforcer path (register → authorize) into a foot-gun-free
gated-execution call. **Shipped `Sources/BASSovereign/BASSovereignGatedCommit.swift`** (the ADR-034
pattern — a host-callable composition that turns primitives into a usable seam):
- `register(brainToken, issuedAt:)` → mints the authoritative Ed25519 token + single-use ledger entry
  (identity preserved).
- `executeGated(token, scope, target, approvedArtifactParts, …, op:)` → recomputes the
  `expectedActionDigest` HERE from the approved artifact (NEVER off the token) via
  `BASSovereignActionDigest.compute`, calls `enforcer.authorize`, and runs `op` **only if** authorize did
  not throw. Any gate failure (aliased target / tampered digest / replay / TTL / scope / policy / invalid
  signature) propagates and `op` is NEVER invoked.
- OPT-IN / byte-equal-off (红线 7): nothing constructs it by default → the turn path is byte-equal;
  production `makeCommitToken` untouched. 6 XCTest cases (op runs once on valid + returns value; tampered
  → `actionDigestMismatch` + op not run; aliased → `targetNotAllowed` + op not run; replay → op runs
  EXACTLY once; expired → op not run; register preserves identity). 50 commit/authority tests green.
- **Still deferred (host integration):** a live host that holds a keyring-backed authority and routes its
  REAL renderHighRisk / memoryWrite / checkpointCommit ops through `executeGated`. The seam is ready; no
  host currently executes gated irreversible ops, so default-on wiring is a separate, deliberate step
  (亏的不要上 — don't claim a live gate that nothing routes through).
