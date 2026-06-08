# ADR-040 — Event-log tamper-evidence (red-team finding + contiguity verifier + opt-in hash chain)

- **Status:** Accepted (Phase 7, red-team arc). Contiguity verifier SHIPPED; per-row hash CHAIN SHIPPED as an
  OPT-IN, default-off, byte-equal-off feature (sidecar table — no change to the byte-deterministic `event_log`
  write path when off). A KEYED-HMAC upgrade (full tamper-evidence against a fully-capable attacker) remains
  the documented follow-up.
- **Context:** the adversarial "red-team the walls" arc (Wall 3 — tamper / replay-digest / commit-gate).
- **Related:** ADR-023 (missing-lineage ≠ tampering → shadowLock), ADR-025 (Ed25519 commit-token authority),
  ADR-032 (live crypto commit-gate), ADR-039 §10 (the determinism + governance walls).

## 1. The finding (what the red-team confirmed)

`BASSQLiteEventLogStorage` is the sovereign **audit trail** — append-only by contract (五级删除 doctrine: no
runtime DELETE except `pruneEventsBefore`). The red-team probed what an out-of-band attacker (raw `sqlite3`
access to the DB file — forensic tamper, or a compromised process holding the app's own file handle) can do
**undetected** at replay. Two classes, both confirmed by `BASEventLogTamperRedTeamTests`:

1. **Middle-row deletion / sequence gap (GAP-3b).** `fetchEventsForSession` orders by `sequence_number ASC`
   and returns whatever rows survive, with **no read-time contiguity check**. Deleting a committed middle row
   silently yields a gapped replay (`[0,2,3]`) with no signal.
2. **Semantic payload edit (GAP-3a).** `payload_json` is the source of truth and carries **no per-row
   integrity tag** (no HMAC, no hash chain). An `UPDATE … SET payload_json = REPLACE(…)` that preserves the
   `sequence_number` column produces a well-formed, fully-decodable, **forged** entry that the store returns
   verbatim — **fail-OPEN**.

Threat model: the OS sandbox protects the file from *other* apps; this ADR is about tamper-**evidence**
(detect after the fact) for the on-device sovereign audit log, not tamper-**prevention**.

## 2. Decision

### 2a. SHIPPED — read-side contiguity verifier (spine-safe)

Added `BASSQLiteEventLogStorage.eventsVerifyingContiguity(forSession:)`: fetches a session's events in sequence
order and throws `StorageError.corruptedRow` on the first discontinuity (each seq must equal previous + 1).

- **Detects:** middle-row deletion (a sequence gap) and duplicated sequence numbers — i.e. any tamper that
  breaks contiguity of the `sequence_number` *column values*. Because the fetch re-sorts `ORDER BY
  sequence_number ASC`, a genuine reordering manifests only as a gap or a duplicate; it is **not** a separate
  detection class. Contiguity is checked on the authoritative column (read directly from SQL), not the
  payload_json-decoded value, so a column-only `sequence_number` edit is in-scope.
- **Does NOT detect:** a seq-preserving semantic payload edit (GAP-3a); a tail-row deletion (the surviving
  prefix stays contiguous); nor a value-set-preserving SWAP of two rows' `sequence_number` (the multiset
  stays contiguous after the ASC sort).
- **No false positive** on legitimate front-pruning (`pruneEventsBefore`): the surviving rows remain
  contiguous, just starting at a sequence number > 0.
- **Spine-safe:** read-only + Metal-free ⇒ no change to the byte-deterministic write path or stored bytes; it
  does not appear in the determinism-boundary tripwire as a violation and does not affect replay digests.

A replay/audit caller that needs tamper-evidence calls `eventsVerifyingContiguity` instead of the plain
`eventsOrThrow`. The default reads are unchanged (byte-equal-off).

### 2b. SHIPPED — per-row hash chain (OPT-IN, byte-equal-off, sidecar table)

Catches the seq-preserving SEMANTIC payload edit (GAP-3a) + deletion + reorder that contiguity cannot, via a
per-row hash chain. Built the way everything else in this codebase ships: opt-in, default-off, byte-equal-off.

- **Flag:** `BASSQLiteEventLogStorage.rowIntegrityChainEnabled` (default `false`).
- **Sidecar, not a schema bump.** The chain lives in a SEPARATE `event_log_integrity` table
  (`event_id, session_id, sequence_number, row_hash, prev_hash`) created LAZILY only when the flag is ON. With
  the flag OFF the sidecar is never created → the `event_log` table + its write path are byte-identical to
  today (no v2→v3 migration forced on flag-off stores). This is why the sidecar design was chosen over an
  `ALTER TABLE event_log ADD COLUMN`.
- **Chain:** on each NEW append (idempotent re-appends skip it), INSIDE the existing `BEGIN IMMEDIATE` txn
  (atomic with the event row), `row_hash = SHA256( canonical(entry as sorted-keys JSON) || prev_hash )` where
  `prev_hash` is the session's current chain tail (`""` genesis for the first). Deterministic ⇒ compatible with
  the byte-determinism doctrine.
- **Chained rows force the JSON write path.** When the chain is on, an event row is stored as JSON (format=1)
  even if `useBinaryPayload` is also on, so the hash (over the in-memory entry at append) matches the
  re-decoded entry at verify. Enabling the chain therefore forfeits binary storage savings for event rows —
  an accepted tradeoff (the binary v2 envelope is also faithful now, but JSON keeps the hash domain exact).
- **Verify:** `verifyIntegrityChain(forSession:)` walks the event rows, recomputes each hash + chain link, and
  throws `corruptedRow` (fail-closed). It seeds from the SURVIVING head's recorded `prev_hash`, so it is
  prune-safe (a legitimate `pruneEventsBefore` front-removal does not false-trip) while still catching every
  interior tamper.
  - **Detects:** a semantic payload edit (hash mismatch); an INTERIOR/middle row deletion or a reorder (broken
    `prev_hash` link); and a TOTAL-session erasure (event rows gone while the chain remains).
  - **Does NOT detect:** a pure TAIL deletion (the surviving prefix is still a valid chain) or a legitimate
    front-prune — both tolerated by design — and the keyless-recompute attacker below.
- **Honest limit (KEYLESS chain).** The hash is keyless, so an attacker with full DB write who ALSO recomputes
  the whole chain is undetected. The chain still defeats naïve tampering (the attacker must recompute every
  SHA256 link). FULL tamper-evidence against a fully-capable attacker needs a **keyed HMAC** (key stored
  OUTSIDE the DB, e.g. Keychain) — the remaining follow-up. The keyed variant slots into the same sidecar +
  verify shape (swap `SHA256` for `HMAC<SHA256>`), so it is an incremental upgrade, not a redesign.

Tests: `BASEventLogTamperRedTeamTests` — chain detects the semantic edit (which contiguity does NOT) +
deletion; verifies an untampered log; and proves flag-OFF creates NO sidecar (byte-equal-off).

## 3. Why this is enough for now

The **consequential** path — irreversible commits — is already fail-closed via the Ed25519 commit-token
authority (ADR-025/032): a forged or tampered artifact cannot authorize an op regardless of what the event log
says (`BASCommitGateRedTeamTests` proves a keyless/cross-authority token is rejected). The event log is an
*audit/replay* surface, not the commit authenticator. Contiguity (always-on, read-side) closes deletion / gap
/ column tamper; the opt-in hash chain closes the seq-preserving SEMANTIC edit + reorder. The only remaining
residual is a fully-capable attacker who recomputes the entire keyless chain — closed by the keyed-HMAC
follow-up (§2b).

## 4. Tests

- `BASEventLogTamperRedTeamTests` (contiguity) — middle-row deletion detected; duplicate seq detected;
  column-only seq tamper detected; untampered + front-pruned logs pass (no false positive); empty + single
  sessions pass; semantic payload edit documented as undetected by contiguity (GAP-3a).
- `BASEventLogTamperRedTeamTests` (hash chain, opt-in) — semantic payload edit detected (the GAP-3a case
  contiguity cannot catch); row deletion detected (broken prev_hash link); untampered log verifies; flag-OFF
  creates no sidecar (byte-equal-off proof).
