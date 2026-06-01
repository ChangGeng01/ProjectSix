# ADR-027 — Constitution Vault Sovereign Seal (A3 a+c)

> **Status: CORE BUILT + TESTED (ch1044 A3 a+c, opt-in / byte-equal-off).** Closes the
> deep-audit finding that the host constitution vault's integrity field is a *decorative
> checksum*, not an authenticator: a tamperer who edits the persisted vault — most
> dangerously by SHRINKING `boundaryVeil.hardNoGo` to disable a sovereign block — simply
> recomputes `versionSignature` and nothing detects it. Per ADR-014 this is OPT-IN and
> byte-equal when unconfigured.

## 1. The gap (three weaknesses in one field)

`BASHostConstitutionVault.versionSignature` is `basStableSignature` (HostConstitutionCore.swift):

```swift
private func basStableSignature(_ material: String) -> String {
    let digest = SHA256.hash(data: Data(material.utf8))
    return String(BASAutoRouteRanker.bytesToHexLower(Array(digest)).prefix(16))  // 64 bits
}
// material = [hostID, …, hardNoGo.joined("|"), rollbackLineage.joined("|"), …].joined("::")
```

1. **Unkeyed.** Plain SHA256 is a checksum *anyone* recomputes — not an authenticator. The
   field proves nothing about *who* produced the vault.
2. **Truncated to 64 bits.** Collision-weak even as a checksum.
3. **Delimiter-join material.** `hardNoGo.joined("|")` + `…joined("::")` is the forgery
   class fixed everywhere else this chapter — `["a","b"]` and `["a|b"]` collide.

The net effect: the boundary veil — the sovereign block-list — has **no real integrity
protection** against an attacker with write access to the persisted vault.

## 2. What was built

`BASHostConstitutionVaultSovereignSeal` (BASHostKit — the only module that sees both the
BASMemory vault type and BASSovereign Ed25519; they are sibling modules):

- **`canonicalBytes(for:)`** — the INJECTIVE canonical byte layout of the vault's
  safety-critical material. Every array is length-counted (`BASSovereignCanonicalBytes.list`)
  and the record is netstring-framed (`.lengthPrefixed`), so no in-band byte can shift a
  field boundary (closes weakness 3). Authenticates the **full** boundary veil (hardNoGo,
  softCaution, confirmRequired, restricted{Memory,Tool}Domains) — strictly more than the
  legacy checksum — plus identity, goals, rollback/export lineage, deletion + sync-revocation
  refs, device-consistency state, and the migration contract. A domain-separation tag
  (`bas.host.constitution.vault.seal/1.0.0`) is prefixed.
- **`seal(_:with:)`** — a detached Ed25519 signature (hex) over those bytes (closes
  weaknesses 1 + 2: keyed, full-length).
- **`verify(_:sealHex:publicKey:)`** — fail-closed verification: a malformed hex string, a
  tampered field (a shrunk hardNoGo, an aliased identity), or a wrong key all return `false`.
- **`approvalAuditEntry(…)`** *(A3c)* — builds the hardened (`1.2.0`, injective)
  `BASSovereignAuditEntry` for a constitution approval, capturing the hardNoGo diff
  (`hardNoGo.removed:<x>` / `hardNoGo.added:<x>`) so a SHRINK is permanently attested in the
  hash-chained ledger. Unsigned by construction — the ledger signs + chains it on `append`.
- **`shrinksHardNoGo(…)`** — the single-sourced predicate for "does this approval weaken the
  block-list" (the A3b dual-key trigger, defined here so the policy has one home when that
  wiring lands).

## 3. Why this is sound

The seal is a true authenticator: it cannot be produced without the private key, and the
injective encoding means two distinct vaults never share a signed pre-image. A tamperer who
removes `no_exfiltration` from hardNoGo changes the canonical bytes → the original seal no
longer validates → fail-closed. This is proven end-to-end:
`testTamperedHardNoGoShrinkBreaksSeal`, `testTamperedSoftCautionBreaksSeal` (more than the
legacy field covered), `testWrongKeyFailsVerification`, `testMalformedSealHexFailsClosed`,
`testCanonicalBytesAreInjectiveAcrossDelimiterJoin`, plus the approval-entry diff capture —
10 tests, all green.

## 4. Opt-in / byte-equal (ADR-014, 红线 7)

This pass adds a **new file + new tests only** — it does not touch the vault struct, the
SQLite schema, or any turn-path code. `versionSignature` is unchanged; a host that never
constructs a seal sees a byte-identical vault. The seal is detached (returned as hex), not
persisted.

## 5. What is honestly deferred (A3 a+c — one level deeper)

Parallel to A1/ADR-026: the cryptographic core + verifier exist and are tested; two
**integration** pieces are deliberately NOT done at session tail, under 亏的不要上 / 小心翼翼 / R1
(do not rush a persisted-format migration or invent a sovereign key-management scheme on a
hunch):

- **Key provenance.** `seal`/`verify` take the keypair / public key as a parameter. A host
  must supply a `BASSovereignEd25519KeyPair` from its keyring — NOT a per-process random
  key, NOT `fromSeed("constant")` (test-only). Where the constitution signing key lives
  (keychain / enclave / per-host / cross-device-synced) is a sovereign-security design
  decision, not a code detail to guess.
- **Persist + verify-on-load.** Making verification actually run in the storage load path
  needs the seal to round-trip through SQLite — a nullable `sovereign_seal` column (legacy
  rows decode to NULL → nil → load unaffected, the migration-safe shape) — and the storage
  constructor to receive the public key, then quarantine on mismatch (the A2 pattern applied
  to the vault). Wiring verify-on-load *without* also wiring sign-on-write would buy a
  dormant code path at the cost of a schema migration, so both land together with the key
  decision above.
- **A3b (dual-key on shrink)** remains its own session: `shrinksHardNoGo` is the trigger
  predicate; routing a shrinking approval through `BASSovereignHighConsequenceGate` is a new
  sovereign gate inserted into the constitution staging flow (`EBrainHostRuntime+HostConstitutionService`,
  currently a pure value-type with no key/ledger) — exactly the R1 class, not a tail-of-session change.

So the deep-audit gap is two-layered, like A1: (1) **no authenticator / verifier** — *closed
by this ADR* (real, keyed, injective, tested); and (2) **no production writer/loader that
holds the key** — which awaits the key-provenance decision + the nullable-column migration,
both bounded and documented above.
