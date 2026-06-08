# ADR-040 — Event-log tamper-evidence (red-team finding + contiguity verifier; hash-chain follow-up)

- **Status:** Accepted (Phase 7, red-team arc). Contiguity verifier SHIPPED; hash-chain is a documented,
  operator-gated follow-up (NOT yet built — per 亏的不要上, the spine write path is not rewritten on spec).
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

### 2b. FOLLOW-UP (operator-gated, NOT built) — per-row hash chain

Full tamper-evidence (catching the seq-preserving semantic edit + tail deletion) requires a per-row integrity
tag. The proper design is a **hash chain**: a new schema column `row_hash = SHA256(canonical(entry) ||
prev_row_hash_for_session)`, computed under the existing `BEGIN IMMEDIATE` writer lock (so it is race-safe and
deterministic), with a verify pass that recomputes + chains on replay.

This is **deliberately not implemented in this arc** because it is a write-path + schema change (v2 → v3
migration) to a *spine* file, with determinism + concurrency implications that warrant their own focused arc
and operator sign-off (R1 / 亏的不要上 — do not rewrite the deterministic spine on spec). The hash is a
deterministic function of entry bytes, so it is compatible with the byte-determinism doctrine; the cost is the
migration + the added per-append hash compute. Recommended when the threat model elevates audit-log integrity
above "contiguity + Ed25519 commit-token authority" (which already protect the consequential commit path).

## 3. Why this is enough for now

The **consequential** path — irreversible commits — is already fail-closed via the Ed25519 commit-token
authority (ADR-025/032): a forged or tampered artifact cannot authorize an op regardless of what the event log
says (`BASCommitGateRedTeamTests` proves a keyless/cross-authority token is rejected). The event log is an
*audit/replay* surface, not the commit authenticator. Contiguity closes the cheapest, highest-signal tamper
(deletion); the residual (seq-preserving payload edit) is documented + has a clear remediation path.

## 4. Tests

- `BASEventLogTamperRedTeamTests` — middle-row deletion detected; duplicate seq detected; untampered +
  front-pruned logs pass (no false positive); semantic payload edit documented as undetected (GAP-3a).
