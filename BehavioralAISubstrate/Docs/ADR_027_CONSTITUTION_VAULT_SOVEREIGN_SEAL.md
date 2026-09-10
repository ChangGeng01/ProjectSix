# ADR-027 — Constitution Vault Sovereign Seal (A3 a+c+b, A2)

> **Status: CORE + INTEGRATION BUILT + TESTED (ch1044, opt-in / byte-equal-off).** Closes the
> deep-audit finding that the host constitution vault's integrity field is a *decorative
> checksum*, not an authenticator: a tamperer who edits the persisted vault — most
> dangerously by SHRINKING `boundaryVeil.hardNoGo` to disable a sovereign block — simply
> recomputes `versionSignature` and nothing detects it. Per ADR-014 this is OPT-IN and
> byte-equal when unconfigured. §2-4 are the authenticator core; §5 is the integration layer
> (persisted seal + verify-on-load gate, the A3b dual-key approval gate, the A2 append-floor);
> §6 is the honest remaining per-host wiring.

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

The seal core (§2) added a **new file + new tests only**. The integration layer (§5) adds an
OPTIONAL `sovereignSeal: String?` to the vault, but it is byte-equal-off: synthesized Codable
OMITS a nil Optional, so an unsealed vault's persisted `payload_json` is byte-identical to
before the field existed, `PRAGMA user_version` is unchanged, and a host that never seals
sees no behavior change. `versionSignature` is untouched.

## 5. The integration layer — now BUILT (ch1044 A3 integration session)

The earlier draft of this section deferred the persist + verify-on-load wiring and the
dual-key gate as "needs a schema migration / a sovereign-flow change." A key discovery
removed the migration risk: **both constitution stores persist the vault as a Codable
`payload_json` blob** (`JSONDecoder().decode(BASHostConstitutionVault.self)`), so the seal
rides in the blob with **no column migration** and old blobs decode the missing key as nil.
With that, the following are built + tested:

- **Persisted seal + verify-on-load.** `sovereignSeal: String?` on the vault (byte-equal-off,
  §4). Lifecycle in `BASHostConstitutionVaultSovereignSeal`: `sealed()` sets the field;
  `verifySealed()` → `{unsealed, valid, invalid}`; `requireValidSeal()` is the fail-closed
  gate a host calls after loading from storage. Verification lives in BASHostKit (a wrapper
  around the BASMemory store's load), because the store's module cannot import Ed25519.
  `allowUnsealed: false` also rejects a STRIPPED seal, so deleting the field is not a bypass.
  Proven by a real routed-store round-trip (sign → persist → reload → verify) + tamper +
  strip + wrong-key tests.
- **A3b dual-key on shrink** — `BASConstitutionApprovalGate` (BASHostKit): classifies an
  approval and requires a valid `BASSovereignDualKeyCommit` (two principals, over a digest
  binding the exact transition) for a hardNoGo/confirmRequired SHRINK, via the existing
  `BASSovereignHighConsequenceGate`. Opt-in; routine approvals pass without a commit; a
  commit for one transition cannot be replayed onto another. 9 tests.
- **A2 append-floor** — `BASSovereignAuditLedger(minimumSchemaVersion:)`: opt-in rejection of
  sub-hardened (non-injective) audit appends; nil default = byte-equal-off. 4 tests.

**Key provenance** is codebase-determined: `BASSovereignKeychainBinding` (BASSovereign) is
the established store/load for an Ed25519 keypair — the seal/verify and the two approver keys
come from there, NOT a per-process random key, NOT `fromSeed("constant")` (test-only).

## 6. What genuinely remains (the honest layer-2, like A1/ADR-026)

Every reusable sovereign primitive now exists, is opt-in/byte-equal-off, and is tested:
authenticator, verifier, persisted seal, fail-closed verify-on-load gate, dual-key approval
gate, approval audit-entry builder, ledger append-floor. What remains is purely the **per-host
call sites**: a host that, with a `BASSovereignKeychainBinding`-bound key, seals-on-write,
calls `requireValidSeal` on load, calls `BASConstitutionApprovalGate.requireAuthorized` at
the approval seam (today a pure value transform with no key/ledger), appends the approval
audit entry, and enables the ledger floor. That wiring awaits a host that actually persists +
approves constitution with a sovereign key — the same two-layer honesty as A1: the gates
exist and are one-call invocations; no current host executes that flow.
