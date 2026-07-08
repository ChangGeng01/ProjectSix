// MARK: - BASJournalCLI · the sovereign audit ledger (increment 2)
//
// Increment 1 gave the journal a MEMORY loop (event-sourced admit / paginated recall /
// tombstone forget). Increment 2 gives it a SOVEREIGN RECORD: every add and every forget is
// sealed into an Ed25519-signed, append-only, hash-chained audit ledger — the on-device,
// zero-egress, tamper-evident record no cloud LLM can be.
//
// This fires, on the live daily path, the chambers the mega-audit only inspected:
//   - M87 Ed25519 signing        — public-key-verifiable seals (verifier needs no secret)
//   - M91 SQLite persistence      — the chain survives process restart (cross-boot forever)
//   - H13 atomic append rollback  — a persist failure leaves memory == disk (my #13-adjacent fix)
//   - ch1044 verify-on-reload     — a tampered chain QUARANTINES rather than serve forged history
//
// Framing (per the design panel): a MIRROR, not an oracle. The seal records WHAT the sovereign
// did (admit / forget) + a content digest — NOT a cognitive judgment. The heavy 4B L2 verdict
// stays deferred to device increment 2b; sealing a confident answer here would be dishonest.

import Foundation
import CryptoKit
import Darwin           // POSIX open/write/close + O_EXCL for atomic 0600 key creation
import BASRuntimeCore
import BASSovereign

// MARK: - Ledger + identity location (on-device, single continuous chain)

private let ledgerDBURL = journalDir.appendingPathComponent("ledger.sqlite")
private let identityKeyURL = journalDir.appendingPathComponent("identity.key")

/// The injective, length-prefixed canonical form (`basSovereignAuditCanonicalBytes` "1.2.0"
/// branch). The substrate's default "1.0.0" delimiter-join is NON-injective for content
/// containing "," / "|"; a brand-new producer with no legacy entries must sign at the project's
/// hardened security floor so a future free-text field can't collide two entries onto one
/// signed pre-image.
private let hardenedAuditSchemaVersion = "1.2.0"

// MARK: - Errors (rendered as clean fail-closed exits, never a trap or a misdiagnosis)

enum JournalLedgerError: Error, CustomStringConvertible {
    case identityKeyCorrupt(size: Int)
    case identityKeyMissingWithHistory
    case identityKeyWriteFailed(code: Int32)
    case ledgerTruncated(entries: Int, expected: Int)

    var description: String {
        switch self {
        case .identityKeyCorrupt(let size):
            return "identity.key exists but is \(size) bytes (expected 32). Refusing to mint a "
                + "new identity that would orphan the existing ledger — restore the real key."
        case .identityKeyMissingWithHistory:
            return "identity.key is MISSING but the ledger has prior entries. This is KEY "
                + "MISSING, not tamper: minting a new key would sign under an identity that "
                + "cannot verify the existing chain, mislabeling real history as forged. "
                + "Restore identity.key to read/append the sovereign record."
        case .identityKeyWriteFailed(let code):
            return "failed to create identity.key with 0600 perms (errno \(code))"
        case .ledgerTruncated(let entries, let expected):
            return "TAIL TRUNCATION — \(entries) audit rows survive but the segment high-water "
                + "mark records \(expected). Rows were deleted from ledger.sqlite; the "
                + "append-only sovereign record has been tampered with."
        }
    }
}

/// Load the sovereign identity key pair; mint one ONLY on a genuine first run.
///
/// Threat-model boundary (stated honestly): this is a CLI-grade identity — the 32-byte private
/// key lives in `identity.key` next to `ledger.sqlite`, so an attacker with filesystem write to
/// tamper the DB can equally read the key and forge a fully valid replacement chain. The ledger
/// is therefore tamper-evident against an attacker with DB write but WITHOUT key read, not
/// against one who holds the key. A production *device* build binds the seed to the Secure
/// Enclave / keychain (`BASSovereignKeychainBinding`, ThisDeviceOnly) and keeps the public half
/// in a separate manifest — deliberately NOT wired into a Mac CLI. `fromSeed(_:)` (low-entropy,
/// test-only) is never used; `generate()` is a real CSPRNG.
///
/// `ledgerHasEntries` gates minting: a missing key with existing history is KEY MISSING (refuse,
/// don't mint), so key loss can never silently orphan the chain or masquerade as tamper.
private func loadOrCreateSovereignKeyPair(ledgerHasEntries: Bool) throws -> BASSovereignEd25519KeyPair {
    let fm = FileManager.default
    try fm.createDirectory(at: journalDir, withIntermediateDirectories: true)

    if fm.fileExists(atPath: identityKeyURL.path) {
        // Unreadable ⇒ Data(contentsOf:) throws ⇒ clean fail-closed (not a silent re-mint).
        let raw = try Data(contentsOf: identityKeyURL)
        guard raw.count == 32 else { throw JournalLedgerError.identityKeyCorrupt(size: raw.count) }
        let key = try Curve25519.Signing.PrivateKey(rawRepresentation: raw)
        return BASSovereignEd25519KeyPair(privateKey: key)
    }
    // No key file. Minting is safe ONLY when there is no prior history to orphan.
    guard !ledgerHasEntries else { throw JournalLedgerError.identityKeyMissingWithHistory }

    let pair = BASSovereignEd25519KeyPair.generate()
    try writeIdentityKey0600(pair.privateKey.rawRepresentation)
    return pair
}

/// Persist the 32 raw private-key bytes with mode 0600 established AT CREATION.
///
/// `Data.write(.atomic)` would create the file 0644 (under umask 022) and only narrow it with a
/// later `chmod` — a world-readable window for the private key, PLUS a permanent-0644 hazard if
/// the process dies between the two syscalls (the next run takes the "key exists" branch and
/// never re-narrows). `.completeFileProtection` is a no-op on macOS, so it cannot be relied on.
/// Instead: `open(O_CREAT|O_EXCL, 0o600)` so the key is never visible at any wider mode, and
/// O_EXCL refuses to follow/overwrite an existing file.
private func writeIdentityKey0600(_ raw: Data) throws {
    let fd = identityKeyURL.path.withCString { open($0, O_WRONLY | O_CREAT | O_EXCL, 0o600) }
    guard fd >= 0 else { throw JournalLedgerError.identityKeyWriteFailed(code: errno) }
    defer { close(fd) }
    let wrote: Int = raw.withUnsafeBytes { buf -> Int in
        guard let base = buf.baseAddress else { return raw.isEmpty ? 0 : -1 }
        var off = 0
        while off < buf.count {
            let n = write(fd, base.advanced(by: off), buf.count - off)
            if n <= 0 { return -1 }
            off += n
        }
        return off
    }
    guard wrote == raw.count else { throw JournalLedgerError.identityKeyWriteFailed(code: errno) }
}

/// Construct the persistent, Ed25519-signed sovereign audit ledger. Rehydrates the prior
/// chain from `ledger.sqlite` (M91) and re-verifies it on first write (ch1044). Internal so
/// increment 3 (Trials.swift) can hand the SAME ledger to the ShadowTrial coordinator, so
/// trial seals share the one Ed25519 chain.
func makeLedger() throws -> BASSovereignAuditLedger {
    try FileManager.default.createDirectory(at: journalDir, withIntermediateDirectories: true)
    let storage = try BASSovereignLedgerSQLiteStorage(path: ledgerDBURL.path)
    // Probe the persisted chain BEFORE constructing the ledger, for two reasons:
    //  (1) BASSovereignAuditLedger.rehydrate() TRAPS (fatalError, integrity-over-availability) if
    //      loadState() throws on a corrupt row (tampered `actor` cell, schema mismatch). Probing
    //      here turns that would-be process trap (SIGILL + stack dump) into a throwable error
    //      that cmdLedger renders as a clean fail-closed exit.
    //  (2) We must know whether prior history EXISTS before deciding key handling — a missing key
    //      with existing history is KEY MISSING (refuse), not a first-run mint.
    let prior = try storage.loadState()
    // Tail-truncation gate covering EVERY case, including truncation-to-empty. The substrate's
    // in-ledger check (isIntegrityQuarantined → ensureReloadVerified) early-returns when
    // entries.isEmpty, so a single-entry ledger truncated to zero rows would otherwise look
    // like a cold start. The segment `entryCount` high-water mark is a monotonic count the
    // append path persists but audit_entries deletion doesn't touch: a healthy chain always has
    // Σ segment.entryCount == entries.count, so any shortfall means rows were deleted. Refuse.
    let segmentHighWater = prior.segments.reduce(0) { $0 + $1.entryCount }
    if segmentHighWater != prior.entries.count {
        throw JournalLedgerError.ledgerTruncated(
            entries: prior.entries.count, expected: segmentHighWater)
    }
    let keyPair = try loadOrCreateSovereignKeyPair(ledgerHasEntries: !prior.entries.isEmpty)
    // minimumSchemaVersion floor: reject any sub-hardened append (defense-in-depth around the
    // 1.2.0 entries sealAction produces).
    return BASSovereignAuditLedger(
        ed25519KeyPair: keyPair,
        storage: storage,
        minimumSchemaVersion: hardenedAuditSchemaVersion)
}

// MARK: - Sealing (one signed entry per sovereign action)

/// The content digest that ties a ledger entry to the entry's text WITHOUT persisting the raw
/// text into the audit record — the L8 privacy doctrine the event store follows (digest, not
/// content). Same content ⇒ same digest, so the seal is verifiable against the content sidecar.
func contentDigestHex(_ text: String) -> String {
    SHA256.hash(data: Data(text.utf8))
        .map { String(format: "%02x", $0) }.joined()
}

/// Seal one sovereign action about an atom into the ledger. `verdict` is an honest ACTION
/// marker ("admit:governed" / "forget:tombstoned"), never a confident answer. `turnID` is the
/// atom id so an add-seal and its later forget-seal are linked to the same atom. Returns the
/// appended entry's auditID for display; throws on any signing / persist / integrity failure
/// (integrity-over-availability — an unsealed sovereign action must be surfaced, not swallowed).
@discardableResult
private func sealAction(
    ledger: BASSovereignAuditLedger,
    atomID: UUID,
    verdict: String,
    contentText: String
) async throws -> String {
    let draft = BASSovereignAuditEntry(
        schemaVersion: hardenedAuditSchemaVersion,   // injective canonical form (see constant)
        auditID: UUID().uuidString,
        sessionID: journalSessionID,
        turnID: atomID.uuidString,
        verdictRef: verdict,
        ruleIDs: [],
        signalRefs: [],
        actionRefs: [],
        snapshotRef: contentDigestHex(contentText),
        actor: .operator,
        signature: "",                 // empty ⇒ the ledger signs it (Ed25519)
        appendedAt: Date())
    let appended = try await ledger.append(draft)
    return appended.entry.auditID
}

/// Seal an `add` (the atom was admitted to governed memory). `verdictRef` carries the increment-2b
/// governance verdict from the L1–L14 spine — for a private journal write this is observed to be
/// "admit|gov2:shadowLock|permit:answer|risk:low|abstain" (the lattice abstains on an ungrounded
/// write; it escalates the band on risk cues). When nil the caller hasn't run the spine, so we
/// fall back to the honest legacy marker. Returns the seal's auditID.
@discardableResult
func sealAdmit(atomID: UUID, contentText: String, verdictRef: String? = nil) async throws -> String {
    let ledger = try makeLedger()
    return try await sealAction(
        ledger: ledger, atomID: atomID,
        verdict: verdictRef ?? "admit:governed", contentText: contentText)
}

/// Seal a `forget` (the atom was tombstoned + its content secure-deleted). `contentText` MUST
/// be captured BEFORE the secure-delete so the seal records the forgotten entry's digest —
/// the append-only record proves WHAT was forgotten (by digest) without keeping the raw text.
@discardableResult
func sealForget(atomID: UUID, contentText: String) async throws -> String {
    let ledger = try makeLedger()
    return try await sealAction(
        ledger: ledger, atomID: atomID, verdict: "forget:tombstoned", contentText: contentText)
}

// MARK: - `ledger` command (verify + display, fail-closed on tamper)

/// Verify the whole Ed25519 hash chain and display the sealed sovereign record. Fail-closed:
/// on any integrity break (a tampered / truncated / forged entry) this prints a loud failure
/// and the caller exits non-zero — the tamper-evidence is REAL, not decorative.
func cmdLedger() async throws {
    // Constructing the ledger probes + rehydrates the persisted chain. A corrupt/tampered DB
    // (unknown actor cell, schema mismatch, unreadable file) throws here — render it as a clean
    // fail-closed rather than letting the substrate trap or a raw error escape.
    let ledger: BASSovereignAuditLedger
    do {
        ledger = try makeLedger()
    } catch {
        FileHandle.standardError.write(Data(
            ("ledger: INTEGRITY BROKEN — the sovereign record could not be loaded (corrupt or "
             + "tampered store): \(error)\n").utf8))
        exit(1)
    }
    let entries = await ledger.entries(forSession: journalSessionID)

    // Fail-closed gate #1 — TAIL TRUNCATION. `isIntegrityQuarantined` triggers the substrate's
    // verify-on-reload (ch1044/H14): the segment↔entry COUNT cross-check that catches deleted
    // tail rows. This matters because `verifyChainIntegrity()`'s priorHash+signature walk
    // CANNOT detect truncation on its own — a truncated prefix is internally consistent (every
    // surviving link + signature still verifies). A read-only verifier must run this check too,
    // not only the appender.
    //
    // Residual limit (stated honestly): the segment entryCount is unsigned data in the same
    // SQLite, so an attacker who edits BOTH the audit_entries rows AND the matching segment
    // entryCount stays count-consistent and evades this check. Binding the tail hash into a
    // signed rotation marker would close it; that is out of increment-2 scope. What this DOES
    // guarantee is that naive truncation and any signature/link tamper fail closed.
    if await ledger.isIntegrityQuarantined {
        FileHandle.standardError.write(Data(
            ("ledger: INTEGRITY BROKEN — reloaded chain QUARANTINED (tail truncation or tamper "
             + "detected via segment/entry count mismatch); refusing to serve forged history.\n").utf8))
        exit(1)
    }
    // Fail-closed gate #2 — link + Ed25519 signature walk (precise pointed error). Catches
    // in-place field/signature tamper and broken priorHash linkage (reorder, mid-chain delete).
    do {
        try await ledger.verifyChainIntegrity()
    } catch {
        FileHandle.standardError.write(Data(
            ("ledger: INTEGRITY BROKEN — Ed25519 chain verification failed: \(error)\n"
             + "The persisted sovereign record has been tampered with (link or signature "
             + "mismatch).\n").utf8))
        exit(1)
    }

    if entries.isEmpty {
        print("ledger: 0 sealed entries — the sovereign record is empty (add something first)")
        return
    }

    print("ledger: \(entries.count) sealed entries · chain INTACT (Ed25519, cross-process)")
    let iso = ISO8601DateFormatter()
    // DYNAMIC width = the longest sanitized verdictRef (min 30). `padding(toLength:)` TRUNCATES a
    // string longer than the target, so a fixed width would silently drop the honesty-critical
    // trailing "|abstain"/"|allow" disposition on every non-pass 2b verdict (they run 48–60 chars).
    let verdictWidth = max(30, entries.map { ledgerSanitize($0.entry.verdictRef).count }.max() ?? 30)
    for appended in entries {
        let e = appended.entry
        // Actor distinguishes the operator's DECISION seals — the admit:governed / forget:tombstoned
        // rows for add/forget/bet (.operator) — from the shadow-trial machinery the coordinator
        // appends (.system: shadow_trial open/observe/finalize, evolution_seal, retraction). Note a
        // right/wrong resolve emits ONLY .system rows (no .operator seal). verdictRef is sanitized:
        // the coordinator packs trial refs with a U+001F unit separator ("shadow_trial\u{1F}<id>")
        // that renders invisibly — surface it as ":" so the record is human-readable.
        let id = ledgerDisplayID(e.auditID).padding(toLength: 12, withPad: " ", startingAt: 0)
        let who = e.actor.rawValue.padding(toLength: 8, withPad: " ", startingAt: 0)
        let what = ledgerSanitize(e.verdictRef).padding(toLength: verdictWidth, withPad: " ", startingAt: 0)
        print("  \(id)  \(who)  \(what)  \(iso.string(from: e.appendedAt))")
    }
}

/// Trial events use `"audit-"+UUID` ids while journal seals use a bare UUID; show 12 chars so
/// the `"audit-"` prefix still leaves visible entropy instead of colliding at `prefix(8)`.
private func ledgerDisplayID(_ auditID: String) -> String {
    auditID.hasPrefix("audit-") ? String(auditID.dropFirst(6).prefix(12)) : String(auditID.prefix(12))
}

/// Replace the ASCII control separators the coordinator uses in composite refs (U+001F unit,
/// U+001E record) with a printable ":" so `ledger` never emits invisible/garbled bytes.
private func ledgerSanitize(_ s: String) -> String {
    String(s.map { ($0 == "\u{001F}" || $0 == "\u{001E}") ? ":" : $0 })
}
