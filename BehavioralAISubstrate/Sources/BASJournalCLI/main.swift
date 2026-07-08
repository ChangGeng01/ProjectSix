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

// MARK: - Content sidecar (the substrate stores DIGEST only — privacy doctrine)
//
// BASMemoryAtomReducer projects atom *state* but leaves content empty on replay: the event
// log persists only a SHA256 contentDigest, never the raw text (L8 privacy doctrine). So the
// journal — which must recall the actual entry across reboots — owns raw content itself, in
// a per-atom file. On forget we SECURE-DELETE it (overwrite the bytes, then unlink), so a
// sovereign journal's deleted entry is truly gone, matching the substrate's deletion doctrine.

private let contentDir = journalDir.appendingPathComponent("content", isDirectory: true)

private func contentURL(_ id: UUID) -> URL {
    contentDir.appendingPathComponent(id.uuidString + ".txt")
}

private func writeContent(_ id: UUID, _ text: String) throws {
    try FileManager.default.createDirectory(at: contentDir, withIntermediateDirectories: true)
    try Data(text.utf8).write(to: contentURL(id), options: .atomic)
}

private func readContent(_ id: UUID) -> String {
    (try? String(contentsOf: contentURL(id), encoding: .utf8)) ?? "(content unavailable)"
}

/// Secure-delete: overwrite the file's bytes with zeros before unlinking so the plaintext
/// entry can't be recovered from the freed disk region — the file-level analogue of the
/// SQLite secure_delete the stores now default to.
private func secureDeleteContent(_ id: UUID) {
    let url = contentURL(id)
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

private func cmdAdd(_ text: String) async throws {
    let store = try makeStore()
    try await seedIfEmpty(store)
    let atom = makeEntry(text, tag: "decision")
    let admitted = try await store.admit(atom)
    guard admitted else {
        // admit returns false only on an event-ID collision with an already-admitted atom
        // (each add mints a fresh UUID, so this is effectively unreachable, not a content dedup).
        print("(not admitted — event-id collision with an existing entry; retry)")
        return
    }
    try writeContent(atom.id, text)
    print("logged \(String(atom.id.uuidString.prefix(8)))  \(text)")
    // Increment 2 — seal the sovereign action into the Ed25519 audit ledger (append-only,
    // tamper-evident, cross-boot). Integrity-over-availability: surface a seal failure LOUDLY
    // and DISTINCTLY — the atom is already logged, so the operator must be able to tell a
    // logged-but-UNSEALED partial success from a total failure.
    do {
        let sealID = try await sealAdmit(atomID: atom.id, contentText: text)
        print("sealed \(String(sealID.prefix(8)))  admit:governed  (Ed25519 sovereign ledger)")
    } catch {
        FileHandle.standardError.write(Data(
            ("SEAL FAILED — the entry is LOGGED to memory but NOT sealed into the sovereign "
             + "ledger: \(error)\n").utf8))
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
    let contentGone = !FileManager.default.fileExists(atPath: contentURL(target.id).path)
    if stillThere || !contentGone {
        FileHandle.standardError.write(Data(
            "WARNING: forgotten entry still projects — deletion doctrine VIOLATED\n".utf8))
        return
    }
    print("forgotten \(String(target.id.uuidString.prefix(8)))  (verified gone from projection)")
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

      add "<text>"       log a decision/thread into event-sourced memory + seal it
      recall [query]     list entries (optionally filtered), oldest→newest
      forget <id-prefix> tombstone an entry + verify it is gone (deletion doctrine) + seal it
      count              how many entries
      ledger             verify the Ed25519 sovereign chain + show every sealed action

    Stored on-device at ~/.qinao-journal/. Zero egress. A mirror, not an oracle.
    Every add/forget is sealed into an append-only Ed25519 audit ledger (the 3 first-run seed
    threads are unsealed sample data). Tamper-evident against edits to ledger.sqlite by anyone
    who lacks identity.key — the private key (0600) sits beside it, so this is CLI-grade, not
    Secure-Enclave-bound: an attacker who can read the key can forge the chain.
    """)
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
            let text = rest.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { print("usage: add \"<text>\""); return }
            try await cmdAdd(text)
        case "recall":
            try await cmdRecall(rest.joined(separator: " "))
        case "forget":
            guard let prefix = rest.first, !prefix.isEmpty else { print("usage: forget <id-prefix>"); return }
            try await cmdForget(prefix)
        case "count":
            try await cmdCount()
        case "ledger":
            try await cmdLedger()
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
