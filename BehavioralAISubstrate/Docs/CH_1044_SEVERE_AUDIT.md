# CH-1044 最严查 — Adversarial Audit of the Session's Sovereign Work + Fixes

> Operator asked for the most rigorous audit (最严查) of everything this chapter
> built (the parity shadow, verdict kernel, dual Ed25519 sig, consistency check,
> determinism guard, digest fix). Four adversarial review agents each tried to
> BREAK a dimension — correctness, crypto/security, byte-equality/discipline,
> honesty/coverage — rather than confirm it. The headline: the audit found a
> **CRITICAL forgery in code shipped earlier this same chapter**, plus several HIGH
> overclaims and MEDIUM hardening gaps. All are now fixed; the byte-equality
> discipline held everywhere.

## Findings & dispositions

| # | Sev | Finding | Status |
|---|-----|---------|--------|
| 1 | **CRITICAL** | `identityCanonicalBytes()` joined `allowedTargets` with `\u{1E}`; an in-band separator forges a DIFFERENT authorized-target set into byte-identical signed bytes → one Ed25519 sig valid for two tokens (PoC-confirmed scope-expansion forgery). | **FIXED** |
| 2 | HIGH | `canonicalCommitBytes` (authority Ed25519 message) joined `allowedTargets` with `,` inside a `|`-join — same collision class. | **FIXED** |
| 3 | HIGH | `verify` returns `.absent` for a stripped sig; a gate treating `.absent` as acceptable = downgrade bypass. | **FIXED** (`requireValid`) |
| H1 | HIGH | Test framed the sweep's `unexpectedDrift == 0` as a coordinator-regression tripwire; it is true BY ENGINE INVARIANT (the `.unexpectedDrift` branch is unreachable via the live engine). | **FIXED** (honest reword + direct branch test) |
| H2 | HIGH | `softHigh` test comment claimed a soft-signal LEX_ORDER mechanism; it is actually BR-010 (hard rule). | **FIXED** (comment corrected) |
| H3 | HIGH | Determinism guard claimed to cover "the thing that authorizes an action" but omitted `sovereignWarrants` / `sovereignActuationCommands` / receipts / lock / quarantine / recovery. | **FIXED** (fields added + claim narrowed) |
| 4 | MED | Deterministic mint trusted caller `tokenID`/`nonce`: a re-used `tokenID` overwrote the ledger (reset `redeemed:true→false` = double-spend); nonce bypassed dedup. | **FIXED** (one-shot tokenID + nonce guards) |
| 5 | MED | `canonicalInputsDigest` returned `nil` on NaN/Infinity — indistinguishable from "uncovered" (silent audit blind spot). | **FIXED** (stable non-finite sentinels) |
| P | HIGH (deferred) | The PRODUCTION tag `sovereignDigestHex(... + allowedTargets)` joins with `|` — same collision class. Changing its form alters every production `signature` value (a behavior change). | **DEFERRED** — see below |
| — | LOW | `-0.0`/`0.0` digest instability; "healthy" stub is actually `.shadowLock` (missing-lineage); unused sweep histograms; kill-switch lower-bound blind spot (already documented). | NOTED |

## The fix: one injective canonical encoder

`BASSovereignCanonicalBytes.lengthPrefixed([String]) -> Data` emits each field as
`<utf8ByteCount>:<bytes>` (Bernstein netstring, minus the trailing comma). Reading
exactly `count` bytes per field means **no value — even one containing `:`,
`\u{1F}`, or `\u{1E}` — can shift a boundary**; distinct field sequences (including
different arities) always produce distinct bytes. `allowedTargets` are encoded as a
count marker plus one length-prefixed element each. Both `identityCanonicalBytes()`
(dual-sig) and `canonicalCommitBytes` (authority) now use it. Regression test
`testInBandSeparatorCannotForgeDifferentTargets` proves the old `["a␞b","c"]` /
`["a","b␞c"]` collision is gone and a sig minted for one does NOT validate the other.

**This is now the substrate rule: anything signed or hashed for authenticity uses
the injective encoder, never a delimiter-join.**

## Why the production tag (P) is deferred, not rushed

The production `signature` tag has the same `|`-join collision, but:
- Its `allowedTargets` are INTERNAL ids (`foldID`, `ticketID`, mode rawValues) — not
  attacker-controlled — so a separator-bearing element is unlikely.
- The **now-injective Ed25519 dual-sig** (`identityCanonicalBytes`) is the asymmetric
  authority and covers the full identity collision-free when used.
- Changing `sovereignDigestHex`'s form changes EVERY production tag value — a
  behavior change that belongs in its own focused, byte-diffed effort (operator
  ruling 亏的不要上: do not ship a risky production change in an audit pass).

Resume options for P: (a) length-prefix the production tag (changes tag values —
needs a migration/byte-diff proof), or (b) reject control/separator chars in signed
string fields at the mint boundary (byte-equal for legitimate tokens, closes the
collision).

### RESOLUTION (ch1044 — option (b) attempted, rigorously tested, REVERTED)

Option (b) — the "byte-equal" boundary-validation — was implemented and is
**INFEASIBLE for this codebase**. The regression test immediately revealed the bad
assumption behind it: **identity fields legitimately contain `|`**. The production
`sessionID` is the composite `host.primary|task|sentinel`, so rejecting `|` in
signed fields drove the healthy-turn suite to **0 minted tokens** (the `["a","b"]`
vs `["a|b"]` premise — "internal IDs never contain separators" — is simply false
here). The change was reverted.

So the ONLY correct fix is option (a): the injective `BASSovereignCanonicalBytes`
encoder for the production tag — which **changes every tag value** and therefore
needs the stress-sweep baseline re-pin (the same focused effort as the determinism
leaks, D1). Deferred under 亏的不要上.

This also means the existing `|`-join is genuinely ambiguous for real `sessionID`
data *today* — but the tag is an identity/replay/audit marker, **NOT an auth gate**
(nothing verifies its signature value), and real sessionIDs don't collide, so the
live impact is low. The fix is correctness / defense-in-depth, appropriately
deferred. The honest lesson: the audit's "preferred byte-equal path" did not survive
contact with the real data — the test caught it before it shipped.

## What held (clean)

The byte-equality / red-line-7 dimension found **no unclaimed behavior change**: the
`ed25519Signature` optional is byte-equal when nil (synthesized `encodeIfPresent`,
old data decodes fine, SHA256 tag untouched); the `Int?→String?` digest type change
broke no consumer (all already expect `String?`); the `evaluateLevel` extraction is
byte-equal; the runner's shadow parity is env-gated and the always-on consistency
check is pure/observation-only. 1854 tests green across all touched areas.
