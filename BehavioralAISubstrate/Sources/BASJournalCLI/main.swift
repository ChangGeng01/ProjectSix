// MARK: - BASJournalCLI — "The Ledger": the first real daily workload (#20)
//
// The mega-audit's four systemic diseases (comment-lies / fail-open / loaded-gun
// dormancy / corrupt==empty) share ONE root: no LIVE application runs the substrate, so
// the dormant HIGH paths are never fired and the L3-L14 organs are never truth-checked.
// This is the operator-chosen first daily workload — a SOVEREIGN decision & thread journal
// that drives the event-sourced memory + deletion doctrine + (later) the adjudication
// chain onto the live path, one entry per day, entirely on-device.
//
// INCREMENT 1 (this file): the sovereignty MEMORY loop over the real
// BASEventSourcedMemoryAtomStore — add / recall / forget — which fires:
//   - L8 event-sourced memory admission (BASMemoryAtomEventPayload → append)
//   - the H14 cursor-paginated session read (recall reads the FULL history)
//   - the deletion doctrine (forget → remove → tombstone; recall no longer returns it)
// INCREMENT 2 (next): route `add` through runTurnAndIngest for the L2 verdict + the
//   Ed25519 sovereign-ledger hash chain; INCREMENT 3: the "was I right?" ShadowTrial loop.
//
// Framing (per the design panel): a MIRROR, not an oracle. The 4B L2 abstains; the moat is
// sovereign-forever-memory + tamper-evident recall, never confident answers.
//
// Usage:
//   swift run BASJournalCLI add "DROP sampling-spec: 0.88x end-to-end, free-form wall"
//   swift run BASJournalCLI recall              # every entry, oldest→newest
//   swift run BASJournalCLI recall spec         # entries containing "spec"
//   swift run BASJournalCLI forget <id-prefix>  # tombstone + verify gone
//   swift run BASJournalCLI count

import Foundation
import BASMemory
import BASRuntimeCore

// MARK: - Store location (persistent, on-device, single continuous journal)

// Persistent store root. Defaults to ~/.qinao-journal; QINAO_JOURNAL_DIR overrides it
// (used by the integration test to point at a throwaway temp dir).
// `journalDir` / `journalSessionID` are module-internal (not file-private) so the sovereign
// ledger (Ledger.swift) can site `ledger.sqlite` + `identity.key` in the same journal root
// and stamp seals with the same session id.
let journalDir: URL = {
    if let override = ProcessInfo.processInfo.environment["QINAO_JOURNAL_DIR"], !override.isEmpty {
        return URL(fileURLWithPath: override, isDirectory: true)
    }
    return FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".qinao-journal", isDirectory: true)
}()
private let journalDBURL = journalDir.appendingPathComponent("journal.sqlite")
let journalSessionID = "qinao-journal"

private func makeStore() throws -> BASEventSourcedMemoryAtomStore {
    try FileManager.default.createDirectory(
        at: journalDir, withIntermediateDirectories: true)
    let eventLog = try BASRoutedEventLogStorage(databaseURL: journalDBURL)
    return BASEventSourcedMemoryAtomStore(
        eventLog: eventLog,
        sessionID: journalSessionID,
        source: "qinao-journal")
}

// MARK: - Content store (the substrate stores DIGEST only — privacy doctrine)
//
// BASMemoryAtomReducer projects atom *state* but leaves content empty on replay: the event log
// persists only a SHA256 contentDigest, never the raw text (L8 privacy doctrine). So the journal
// — which must recall the actual entry across reboots — owns raw content itself.
//
// Increment 4: content lives in a secure_delete-ON SQLite store (ContentStore), NOT per-atom
// *.txt files. On APFS a file overwrite-in-place is copy-on-write and can leave the old plaintext
// in freed blocks, so the increment-1 file "secure delete" under-delivered. SQLite secure_delete
// zeroes freed pages on DELETE, matching the #16 doctrine used across the 18 substrate stores.

private let contentDir = journalDir.appendingPathComponent("content", isDirectory: true)  // legacy
private let contentDBURL = journalDir.appendingPathComponent("content.sqlite")

private func contentURL(_ id: UUID) -> URL {   // legacy-file path (migration + belt-and-suspenders)
    contentDir.appendingPathComponent(id.uuidString + ".txt")
}

// Memoized per-process so recall of N entries opens the DB once (and migrates once). The CLI is
// single-threaded — one command, sequential awaits — so unsynchronized global state is safe.
nonisolated(unsafe) private var _contentStore: ContentStore?

private func contentStore() throws -> ContentStore {
    if let s = _contentStore { return s }
    try FileManager.default.createDirectory(at: journalDir, withIntermediateDirectories: true)
    let store = try ContentStore(path: contentDBURL.path)
    migrateLegacyContentFiles(into: store)   // one-time; a no-op once the legacy dir is drained
    _contentStore = store
    return store
}

/// One-time migration of the increment-1 content/*.txt sidecar into the secure store. For each
/// legacy file: import its text, VERIFY the round-trip, then retire the plaintext file. A MOVE
/// (content preserved in the store), not a destroy — fail-safe per file.
///
/// Concurrency-safe against a second CLI process migrating the same file: a file being
/// secure-deleted is zeroed (all-NUL) before it is unlinked, so a racing read can see an
/// all-NUL / empty buffer. We NEVER import an empty or NUL-bearing read (it would clobber a
/// correct row), and migration is NON-CLOBBERING — if the store already holds this atom we just
/// retire the file rather than overwrite.
private func migrateLegacyContentFiles(into store: ContentStore) {
    let fm = FileManager.default
    guard let files = try? fm.contentsOfDirectory(
        at: contentDir, includingPropertiesForKeys: nil), !files.isEmpty else { return }
    for file in files where file.pathExtension == "txt" {
        guard let id = UUID(uuidString: file.deletingPathExtension().lastPathComponent),
              let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
        // Skip a file a concurrent process may be mid-zeroing (all-NUL/empty read).
        guard !text.isEmpty, !text.contains("\u{0}") else { continue }
        do {
            if try store.has(id) { retireLegacyFile(file); continue }   // idempotent, non-clobbering
            try store.put(id, text)
            guard try store.get(id) == text else { continue }   // verify BEFORE retiring the source
            retireLegacyFile(file)
        } catch {
            FileHandle.standardError.write(Data(
                ("WARNING: could not migrate legacy content \(file.lastPathComponent): \(error)\n").utf8))
        }
    }
}

private func writeContent(_ id: UUID, _ text: String) throws {
    try contentStore().put(id, text)
}

private func readContent(_ id: UUID) -> String {
    do {
        if let text = try contentStore().get(id) { return text }   // genuinely present
        // Genuinely ABSENT in the store → a pre-migration legacy file is the only other source.
        if let legacy = try? String(contentsOf: contentURL(id), encoding: .utf8) { return legacy }
        return "(content unavailable)"
    } catch {
        // A real store error must NOT silently fall back to a legacy file — that file could be
        // forgotten plaintext the store already deleted. Surface the error instead of resurrecting.
        return "(content unavailable — store error)"
    }
}

/// Secure-delete the content: remove the SQLite row (secure_delete=ON + verified WAL truncate) AND
/// retire any lingering legacy plaintext file, so a forgotten entry is gone from both surfaces.
/// A checkpoint that could not truncate the WAL throws — surface it (plaintext may linger); the
/// forget verification (`contentIsGone`) will then correctly report the entry as NOT gone.
private func secureDeleteContent(_ id: UUID) {
    do {
        try contentStore().delete(id)
    } catch {
        FileHandle.standardError.write(Data(
            ("WARNING: content secure-delete incomplete (plaintext may linger): \(error)\n").utf8))
    }
    retireLegacyFile(contentURL(id))
}

/// True iff the content is gone from BOTH the store and any legacy file — the forget verification.
/// Fail-closed: if the store lookup errors we cannot confirm removal, so we report NOT gone.
private func contentIsGone(_ id: UUID) -> Bool {
    let inStore: Bool
    do { inStore = try contentStore().has(id) } catch { return false }
    return !inStore && !FileManager.default.fileExists(atPath: contentURL(id).path)
}

/// Retire a legacy plaintext file: best-effort secure-delete, then VERIFY it is gone. If it
/// somehow survives, warn — the increment-4 goal is that no weak-secure-delete plaintext lingers,
/// so a silent survival must be surfaced, not assumed away.
private func retireLegacyFile(_ file: URL) {
    secureDeleteLegacyFile(file)
    if FileManager.default.fileExists(atPath: file.path) {
        FileHandle.standardError.write(Data(
            ("WARNING: legacy content file \(file.lastPathComponent) survived secure-delete\n").utf8))
    }
}

/// Overwrite a legacy plaintext file's bytes then unlink it (best-effort; APFS COW makes this
/// imperfect, which is exactly why content moved into the secure_delete SQLite store).
private func secureDeleteLegacyFile(_ url: URL) {
    if let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int,
       size > 0,
       let handle = try? FileHandle(forWritingTo: url) {
        try? handle.write(contentsOf: Data(count: size))
        try? handle.synchronize()
        try? handle.close()
    }
    try? FileManager.default.removeItem(at: url)
}

// MARK: - Seed content (the marathon domain is self-grounding — the operator's own bets)

private let seedEntries: [String] = [
    "KEEP fused-MTP take-5 after device endurance cert (1.20x, thermal-tiered adaptive K)",
    "DROP sampling-spec draft: 0.88x end-to-end — free-form acceptance wall is the killer",
    "secure_delete default-on across all 18 SQLite stores (deletion doctrine closure)",
]

/// One journal entry as a governed memory atom. `lastConfirmedAt` doubles as the "logged
/// at" time so recall can read chronologically; provenance marks it operator-authored.
private func makeEntry(_ text: String, tag: String) -> BASGovernedMemory {
    BASGovernedMemory(
        id: UUID(),
        kind: .episodic,
        content: text,
        scope: .user,
        sensitivity: .low,
        tier: .warm,
        confidence: 1.0,
        sourceType: "qinao-journal",
        lastConfirmedAt: Date(),
        governanceStatus: .governed,
        provenanceSummary: "operator journal entry (\(tag))")
}

private func seedIfEmpty(_ store: BASEventSourcedMemoryAtomStore) async throws {
    if await store.count > 0 { return }
    for text in seedEntries {
        let atom = makeEntry(text, tag: "seed")
        if try await store.admit(atom) { try writeContent(atom.id, text) }
    }
    FileHandle.standardError.write(Data(
        "qinao-journal: seeded \(seedEntries.count) marathon threads on first run\n".utf8))
}

// MARK: - Commands

private func sortedAtoms(_ store: BASEventSourcedMemoryAtomStore) async -> [BASGovernedMemory] {
    // Oldest → newest by the logged-at time (lastConfirmedAt) so the journal reads
    // chronologically; ties break on id for deterministic output.
    let atoms = await store.allAtoms()
    return atoms.sorted(by: { a, b in
        let ta = a.lastConfirmedAt ?? .distantPast
        let tb = b.lastConfirmedAt ?? .distantPast
        if ta != tb { return ta < tb }
        return a.id.uuidString < b.id.uuidString
    })
}

/// Log a decision into event-sourced memory + seal it into the Ed25519 ledger. Shared by `add`
/// and (increment 3) `bet`. Returns the atom id on success, nil if not admitted. Fails-loud
/// (exit 1) on a seal failure — the entry is logged but the operator must know it went unsealed.
func logDecision(_ text: String, tag: String, deliberate: Bool = false) async throws -> UUID? {
    let store = try makeStore()
    try await seedIfEmpty(store)
    let atom = makeEntry(text, tag: tag)
    guard try await store.admit(atom) else {
        // admit returns false only on an event-ID collision with an already-admitted atom
        // (each call mints a fresh UUID, so this is effectively unreachable, not a content dedup).
        print("(not admitted — event-id collision with an existing entry; retry)")
        return nil
    }
    try writeContent(atom.id, text)
    print("logged \(String(atom.id.uuidString.prefix(8)))  \(text)")
    // Increment 2b — run the entry through the L1–L14 spine for a real GOVERNANCE verdict and fold
    // it into the seal's verdictRef (replacing the hardcoded "admit:governed" assertion). Increment
    // 3c — `deliberate` opts the turn into extra deliberation passes (namespace gov2d:). Degrade
    // HONESTLY: if the spine can't construct (model missing / non-Apple host) we seal a labeled
    // "…:unavailable" — never a fabricated pass. The add must not be held hostage to the verdict
    // organ, so a spine miss still logs + seals the entry.
    let verdictRef = await governanceVerdictRef(action: "admit", for: text, deliberate: deliberate)
        ?? "admit:governed|\(deliberate ? "gov2d" : "gov2"):unavailable"
    // Increment 2 — seal the sovereign action into the Ed25519 audit ledger (append-only,
    // tamper-evident, cross-boot). Integrity-over-availability: surface a seal failure LOUDLY
    // and DISTINCTLY — the atom is already logged, so the operator must be able to tell a
    // logged-but-UNSEALED partial success from a total failure.
    do {
        let sealID = try await sealAdmit(atomID: atom.id, contentText: text, verdictRef: verdictRef)
        print("sealed \(String(sealID.prefix(8)))  \(verdictRef)  (Ed25519 sovereign ledger)")
    } catch {
        FileHandle.standardError.write(Data(
            ("SEAL FAILED — the entry is LOGGED to memory but NOT sealed into the sovereign "
             + "ledger: \(error)\n").utf8))
        exit(1)
    }
    return atom.id
}

private func cmdAdd(_ text: String, deliberate: Bool) async throws {
    _ = try await logDecision(text, tag: "decision", deliberate: deliberate)
}

/// Increment 5 — convene the multi-agent deliberation fabric on a decision. Fires the dormant
/// state-fabric HIGH path (H8 single-writer + H17 merge applier + the L-layer seat organs), records
/// the honest multi-seat deliberation, and seals it into the Ed25519 ledger. Fail-closed: a fabric
/// that did not genuinely fire (some accepted delta unapplied / refs collapsed) is NOT sealed.
private func cmdCouncil(_ decision: String) async throws {
    let outcome: CouncilOutcome
    do {
        outcome = try await fireCouncil(on: decision)
    } catch let CouncilError.fireIncomplete(why) {
        FileHandle.standardError.write(Data(
            ("council: FABRIC FIRE INCOMPLETE — refusing to seal a non-fire: \(why)\n").utf8))
        exit(1)
    }
    print("council: 4-of-9 mandatory-seat deliberation (scout · planner · risk · surface)")
    for line in outcome.lines { print(line) }
    print("  merged: \(outcome.appliedCount)/\(outcome.emittedCount) deltas accepted + applied · "
        + "\(outcome.distinctDomains.count) distinct domains written · \(outcome.traceEventCount) trace events")
    print("  surface disposition: \(outcome.surfaceMode)  — a disposition toward rendering, "
        + "NOT a verdict on whether the decision is right")
    // Integrity-over-availability: a council that fired but could not be sealed is surfaced loudly.
    do {
        let sealID = try await sealCouncil(
            deliberationID: UUID(), decisionText: decision, fabricRef: outcome.fabricRef)
        print("sealed \(String(sealID.prefix(8)))  \(outcome.fabricRef)  (Ed25519 sovereign ledger)")
    } catch {
        FileHandle.standardError.write(Data(
            ("council: the deliberation RAN but was NOT sealed into the sovereign ledger: \(error)\n").utf8))
        exit(1)
    }
}

private func cmdRecall(_ query: String?) async throws {
    let store = try makeStore()
    try await seedIfEmpty(store)
    let atoms = await sortedAtoms(store)
    let shown = atoms.filter { a in
        guard let q = query, !q.isEmpty else { return true }
        return readContent(a.id).range(of: q, options: .caseInsensitive) != nil
    }
    if shown.isEmpty {
        print(query.map { "no entries match \"\($0)\"" } ?? "the journal is empty")
        return
    }
    for a in shown {
        let id = String(a.id.uuidString.prefix(8))
        print("\(id)  \(readContent(a.id))")
    }
    print("— \(shown.count) of \(atoms.count) entries —")
}

private func cmdForget(_ prefix: String) async throws {
    let store = try makeStore()
    let atoms = await store.allAtoms()
    let matches = atoms.filter { $0.id.uuidString.lowercased().hasPrefix(prefix.lowercased()) }
    guard matches.count == 1, let target = matches.first else {
        print(matches.isEmpty
            ? "no entry with id prefix \"\(prefix)\""
            : "ambiguous: \(matches.count) entries match \"\(prefix)\" — use more characters")
        return
    }
    // Capture the content digest source BEFORE secure-delete so the forget-seal records
    // WHAT was forgotten (by digest) — after the delete the raw text is unrecoverable.
    let forgottenText = readContent(target.id)
    let removed = await store.remove(forID: target.id.uuidString)
    guard removed != nil else {
        print("forget failed for \(prefix)")
        return
    }
    secureDeleteContent(target.id)   // raw text overwritten + unlinked
    // Deletion doctrine: verify the projection no longer returns it (H11 tombstone path)
    // AND the raw content is gone from disk.
    let stillThere = await store.allAtoms().contains { $0.id == target.id }
    let contentGone = contentIsGone(target.id)
    if stillThere || !contentGone {
        FileHandle.standardError.write(Data(
            "WARNING: forgotten entry still projects — deletion doctrine VIOLATED\n".utf8))
        return
    }
    print("forgotten \(String(target.id.uuidString.prefix(8)))  (verified gone from projection)")
    // Increment 3 — the deletion doctrine extends to the trials index: purge any bet rows for
    // this decision so a forgotten bet's operator-readable text is secure-deleted too.
    purgeTrialsForAtom(target.id)
    // Increment 2 — seal the forget as an append-only tombstone in the sovereign ledger. The
    // seal survives even though the content is gone: a deleted sovereign entry is provably
    // deleted, not silently vanished. A seal failure is surfaced distinctly (the content is
    // already gone, so the operator must know the deletion went UNSEALED).
    do {
        let sealID = try await sealForget(atomID: target.id, contentText: forgottenText)
        print("sealed \(String(sealID.prefix(8)))  forget:tombstoned  (Ed25519 sovereign ledger)")
    } catch {
        FileHandle.standardError.write(Data(
            ("SEAL FAILED — the entry is FORGOTTEN (content secure-deleted) but the deletion "
             + "was NOT sealed into the sovereign ledger: \(error)\n").utf8))
        exit(1)
    }
}

private func cmdCount() async throws {
    let store = try makeStore()
    try await seedIfEmpty(store)
    print("\(await store.count) entries")
}

private func printHelp() {
    print("""
    qinao-journal — sovereign decision & thread journal (#20 first daily workload)

      add [--deliberate] "<text>"   log a decision/thread into event-sourced memory + seal it
      recall [query]      list entries (optionally filtered), oldest→newest
      forget <id-prefix>  tombstone an entry + verify it is gone (deletion doctrine) + seal it
      count               how many entries
      council "<decision>"  convene the multi-agent deliberation fabric on a decision + seal it
      ledger              verify the Ed25519 sovereign chain + show every sealed action

    "Was I right?" — track ship/drop bets and resolve them with the real outcome:
      bet "<text>" [-q "<question>"]  log a decision AND open it as a shadow trial
      review              re-surface open bets, oldest first (the morning check-in)
      right <trial-id>    you judge the bet right → finalize the trial (seal issued)
      wrong <trial-id> [reason]   you judge it wrong → finalize (seal denied, retraction queued)
      verdict <trial-id>  your recorded outcome + the fail-closed promotion gate for a bet

    council "<decision>" convenes the sovereign deliberation fabric: a 4-of-9 mandatory-seat pass
    (scout=pressure, planner=a framed candidate, risk=reversibility, surface=a disposition), merged
    into the single-writer state graph and sealed as council|4of9|emitted:…|surface:<mode>. It is a
    DELIBERATION record — what each seat surfaced — never a judgment that the decision is right; the
    surface mode is a rendering disposition, not a correctness verdict. It runs entirely on-device
    (no model), and refuses to seal unless the fabric genuinely fired (every accepted delta applied,
    distinct domains written). Only the 4 mandatory seats run; the 5 optional seats are a follow-up.

    Stored on-device at ~/.qinao-journal/. Zero egress. A mirror, not an oracle.
    Every add/forget/bet + trial outcome is sealed into an append-only Ed25519 audit ledger (the
    3 first-run seed threads are unsealed sample data). Tamper-evident against edits to
    ledger.sqlite by anyone who lacks identity.key — the private key (0600) sits beside it, so
    this is CLI-grade, not Secure-Enclave-bound: an attacker who can read the key can forge it.

    Each add runs the entry through the L1–L14 governance spine and seals the verdict, e.g.
    "admit|gov2:shadowLock|permit:answer|risk:low|abstain". gov2:shadowLock|abstain is the NORMAL,
    expected disposition for a private note — the lattice cannot sovereignly GROUND an ungrounded
    write, so it abstains (it is NOT flagging your note as dangerous). The useful signal is the
    ESCALATION band: a manipulation-cued entry rises to gov2:memoryFreeze|risk:high. It is a
    governance disposition proving the lattice ran — never a judgment that your decision is right.

    --deliberate (a LEADING option; use "--" to end options if your text itself starts with "--")
    runs extra (cheap) deliberation passes and seals the verdict under gov2d: instead of
    gov2:. Honest scope: this is a RE-ASSESSMENT, not a safety raise — measured, it changes the
    verdict for only a small minority of entries and can lower OR raise the risk band (e.g. it
    re-rated "maybe delete the whole thing, not sure it matters" from risk:high to risk:medium).
    The re-rating only moves the risk BAND; it never flips the sealed disposition — a protective
    abstain/permit stays protective (that example keeps permit:delay|abstain), so a lower band is
    a calmer re-read, never a green light. Off by default so the baseline verdict stays
    byte-stable; use it when you want a second look.
    """)
}

/// Consume a LEADING `--deliberate` option (increment 3c), returning the remaining args + whether
/// it was present. Parsing stops at the first non-`--`-prefixed token or an explicit `--`
/// end-of-options sentinel — so a `--deliberate` that appears INSIDE the entry text is left
/// intact. A prior version filtered every `--deliberate` token anywhere, which silently deleted
/// that word from the stored content AND the sealed SHA-256 digest (e.g. `add "pass --deliberate
/// to the harness"`) — a tamper-evident ledger must never rewrite the content it attests to.
private func extractDeliberate(_ rest: [String]) -> (rest: [String], deliberate: Bool) {
    var deliberate = false
    var i = 0
    loop: while i < rest.count {
        switch rest[i] {
        case "--deliberate": deliberate = true; i += 1
        case "--": i += 1; break loop            // end-of-options: rest is literal text
        default: break loop                       // first content token → stop stripping
        }
    }
    return (Array(rest[i...]), deliberate)
}

/// Parse `bet` args: everything before a `-q` / `--open-question` flag is the decision text; the
/// tokens after it are the open question. No flag ⇒ all tokens are the text, no question.
private func parseBetArgs(_ rest: [String]) -> (text: String, question: String?) {
    if let flagIdx = rest.firstIndex(where: { $0 == "-q" || $0 == "--open-question" }) {
        let text = rest[..<flagIdx].joined(separator: " ").trimmingCharacters(in: .whitespaces)
        let q = rest[(flagIdx + 1)...].joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return (text, q.isEmpty ? nil : q)
    }
    return (rest.joined(separator: " ").trimmingCharacters(in: .whitespaces), nil)
}

// MARK: - Dispatch

func runJournal() async {
    let argv = CommandLine.arguments
    guard argv.count >= 2 else { printHelp(); return }
    let cmd = argv[1]
    let rest = Array(argv.dropFirst(2))
    do {
        switch cmd {
        case "add":
            let (args, deliberate) = extractDeliberate(rest)
            let text = args.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { print("usage: add [--deliberate] \"<text>\""); return }
            try await cmdAdd(text, deliberate: deliberate)
        case "recall":
            try await cmdRecall(rest.joined(separator: " "))
        case "forget":
            guard let prefix = rest.first, !prefix.isEmpty else { print("usage: forget <id-prefix>"); return }
            try await cmdForget(prefix)
        case "count":
            try await cmdCount()
        case "council":
            let decision = rest.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !decision.isEmpty else { print("usage: council \"<decision>\""); return }
            try await cmdCouncil(decision)
        case "ledger":
            try await cmdLedger()
        case "bet":
            let (betArgs, deliberate) = extractDeliberate(rest)
            let (text, question) = parseBetArgs(betArgs)
            guard !text.isEmpty else { print("usage: bet [--deliberate] \"<text>\" [-q \"<question>\"]"); return }
            try await cmdBet(text, question: question, deliberate: deliberate)
        case "review":
            try await cmdReview()
        case "right":
            guard let prefix = rest.first, !prefix.isEmpty else { print("usage: right <trial-id>"); return }
            try await cmdRight(prefix)
        case "wrong":
            guard let prefix = rest.first, !prefix.isEmpty else { print("usage: wrong <trial-id> [reason]"); return }
            let reason = rest.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespaces)
            try await cmdWrong(prefix, reason: reason.isEmpty ? nil : reason)
        case "verdict":
            guard let prefix = rest.first, !prefix.isEmpty else { print("usage: verdict <trial-id>"); return }
            try await cmdVerdict(prefix)
        case "--help", "-h", "help":
            printHelp()
        default:
            print("unknown command \"\(cmd)\" — try --help")
        }
    } catch {
        FileHandle.standardError.write(Data("qinao-journal: error: \(error)\n".utf8))
        exit(1)
    }
}

await runJournal()
