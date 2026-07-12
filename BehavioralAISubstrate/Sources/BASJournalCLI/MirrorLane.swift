// MARK: - MirrorLane — The Ledger increment 2: the mirror lane (2026-07-12)
//
// Operator rulings ①②③ (Docs/MIRROR_LANE_CHARTER_2026-07-12.md). This file is the THIN
// CLI shell over the BASHostKit convergence library (BASMirrorLaneConvergence /
// BASMirrorLaneIngestGate) — all decision logic lives there, tested library-side.
//
//   mirror-dispose  — build an UNTRUSTED candidate from CLI args, run the deterministic
//                     accept/reject/reduce gate, print the signed canonical envelope
//                     JSON (or the typed rejection, exit 1). No ledger contact.
//   mirror-ingest   — read an envelope JSON (file or '-' stdin), verify-then-append via
//                     the ingest gate. Unsigned / tampered / schema-invalid → typed
//                     reject, exit 1, ZERO writes.
//   mirror          — the OUT-OF-BOUNDARY producer: Apple FoundationModels reflects on
//                     the most recent journal entries (镜子非神谕), and its output
//                     re-enters as an untrusted ANNOTATION candidate through the same
//                     dispose → ingest lane as everything else. Model unavailable →
//                     typed refusal, exit 2 — never a fake mirror.
//
// The mirror-tag key (HMAC, 32 random bytes) lives beside identity.key with the same
// 0600 O_CREAT|O_EXCL discipline; envelope tag and Ed25519 chain seal remain two
// signatures with two jobs.

import Foundation
import CryptoKit
import Darwin
import BASRuntimeCore
import BASSovereign
import BASHostKit
import BASOrgan
import BASAppleAdapters

private let mirrorTagKeyURL = journalDir.appendingPathComponent("mirror-tag.key")

// MARK: - Key custody (mirrors Ledger.swift identity-key discipline)

private func loadOrCreateMirrorTagKey() throws -> SymmetricKey {
    let fm = FileManager.default
    try fm.createDirectory(at: journalDir, withIntermediateDirectories: true)
    if fm.fileExists(atPath: mirrorTagKeyURL.path) {
        let raw = try Data(contentsOf: mirrorTagKeyURL)
        guard raw.count == 32 else {
            throw MirrorLaneCLIError.tagKeyCorrupt(size: raw.count)
        }
        return SymmetricKey(data: raw)
    }
    var bytes = [UInt8](repeating: 0, count: 32)
    for i in bytes.indices { bytes[i] = UInt8.random(in: .min ... .max) }
    let raw = Data(bytes)
    // 0600 at creation via O_CREAT|O_EXCL — same rationale as writeIdentityKey0600
    // (no world-readable window, no permanent-0644 hazard, refuses to overwrite).
    let fd = mirrorTagKeyURL.path.withCString {
        open($0, O_WRONLY | O_CREAT | O_EXCL, 0o600)
    }
    guard fd >= 0 else { throw MirrorLaneCLIError.tagKeyWriteFailed(code: errno) }
    defer { close(fd) }
    let wrote: Int = raw.withUnsafeBytes { buf -> Int in
        guard let base = buf.baseAddress else { return -1 }
        var off = 0
        while off < buf.count {
            let n = write(fd, base.advanced(by: off), buf.count - off)
            if n <= 0 { return -1 }
            off += n
        }
        return off
    }
    guard wrote == raw.count else {
        throw MirrorLaneCLIError.tagKeyWriteFailed(code: errno)
    }
    return SymmetricKey(data: raw)
}

enum MirrorLaneCLIError: Error {
    case tagKeyCorrupt(size: Int)
    case tagKeyWriteFailed(code: Int32)
    case envelopeUnreadable(path: String)
}

// MARK: - mirror-dispose

/// Parse: [--kind proposal|warrant-request|annotation] [--model <id>]
///        [--evidence id1,id2,...] <content text...>
/// promptDigest for a MANUAL candidate is the SHA256 of the content itself — the CLI
/// arg IS the prompt; an LLM producer supplies its real prompt digest instead.
func cmdMirrorDispose(_ rest: [String]) async throws {
    var kind = BASMirrorLaneKind.annotation
    var model = "operator.manual"
    var evidence: [String] = []
    var i = 0
    loop: while i < rest.count {
        switch rest[i] {
        case "--kind":
            guard i + 1 < rest.count,
                  let parsed = BASMirrorLaneKind(rawValue: rest[i + 1]) else {
                print("usage: mirror-dispose [--kind proposal|warrant-request|annotation] "
                    + "[--model <id>] [--evidence a,b] \"<text>\"")
                exit(1)
            }
            kind = parsed; i += 2
        case "--model":
            guard i + 1 < rest.count else { exit(1) }
            model = rest[i + 1]; i += 2
        case "--evidence":
            guard i + 1 < rest.count else { exit(1) }
            evidence = rest[i + 1].split(separator: ",").map(String.init); i += 2
        case "--": i += 1; break loop
        default: break loop
        }
    }
    let text = rest[i...].joined(separator: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    let candidate = BASMirrorLaneCandidate(
        claimedKind: kind,
        content: text,
        evidenceIDs: evidence,
        modelID: model,
        promptDigest: BASConvergedProposalEnvelope.sha256Hex(text),
        claimedPolicyHash: BASSovereignTrustConstants.builtInPolicyHash,
        provenance: "qinao-journal-cli")
    let disposition = BASMirrorLaneDisposer.dispose(
        candidate,
        policy: BASMirrorLanePolicy(
            trustedPolicyHash: BASSovereignTrustConstants.builtInPolicyHash),
        key: try loadOrCreateMirrorTagKey(),
        envelopeID: UUID().uuidString.lowercased(),
        now: Date())

    switch disposition {
    case .rejected(let reason):
        FileHandle.standardError.write(
            Data("mirror-dispose: REJECTED (\(reason.rawValue))\n".utf8))
        exit(1)
    case .reduced(let envelope, let dropped):
        let note = "mirror-dispose: REDUCED \(dropped.rawValue) → annotation "
            + "(no evidence — opinion may annotate, not propose)\n"
        FileHandle.standardError.write(Data(note.utf8))
        try printEnvelopeJSON(envelope)
    case .accepted(let envelope):
        try printEnvelopeJSON(envelope)
    }
}

private func printEnvelopeJSON(_ envelope: BASConvergedProposalEnvelope) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    print(String(decoding: try encoder.encode(envelope), as: UTF8.self))
}

// MARK: - mirror-ingest

func cmdMirrorIngest(_ path: String) async throws {
    let data: Data
    if path == "-" {
        data = FileHandle.standardInput.readDataToEndOfFile()
    } else {
        guard let read = FileManager.default.contents(atPath: path) else {
            throw MirrorLaneCLIError.envelopeUnreadable(path: path)
        }
        data = read
    }
    let envelope: BASConvergedProposalEnvelope
    do {
        envelope = try JSONDecoder().decode(
            BASConvergedProposalEnvelope.self, from: data)
    } catch {
        FileHandle.standardError.write(
            Data("mirror-ingest: REJECTED (schema-invalid: \(error))\n".utf8))
        exit(1)
    }
    let ledger = try makeLedger()
    let outcome = await BASMirrorLaneIngestGate.ingest(
        envelope,
        key: try loadOrCreateMirrorTagKey(),
        ledger: ledger,
        sessionID: journalSessionID,
        turnID: "mirror-\(Int(Date().timeIntervalSince1970))")
    if outcome.appended, let auditID = outcome.auditID {
        print("ingested \(String(auditID.prefix(24)))  kind:\(envelope.kind.rawValue) "
            + "digest:\(String(envelope.contentDigest.prefix(8)))  (Ed25519 sovereign ledger)")
    } else {
        let note = "mirror-ingest: REJECTED (\(outcome.reason?.rawValue ?? "unknown")) "
            + "— zero writes\n"
        FileHandle.standardError.write(Data(note.utf8))
        exit(1)
    }
}

// MARK: - mirror (the out-of-boundary producer)

/// Reflect on the most recent K entries with Apple FoundationModels, then feed the
/// output back through the SAME untrusted-candidate lane as everything else. The model
/// is a MIRROR: its output is an annotation proposal with the reflected entries as
/// evidence — it never touches the ledger except through dispose → ingest.
func cmdMirror(recentCount: Int = 5) async throws {
    let store = try makeStore()
    let atoms = await sortedAtoms(store)
    guard !atoms.isEmpty else {
        print("the journal is empty — nothing to mirror")
        return
    }
    let recent = atoms.suffix(recentCount)
    let entries = recent.map { "- \(readContent($0.id))" }.joined(separator: "\n")
    let instruction = """
        You are a MIRROR for a private decision journal — never an oracle. In at most \
        three sentences, reflect one honest observation about the recent entries below: \
        a pattern, a tension, or a question worth sitting with. Do not advise, do not \
        flatter, do not invent facts.
        """

    let adapter = AppleFoundationOrganAdapter()
    let draft: BASOrganDraft
    do {
        draft = try await adapter.draft(BASOrganRequest(
            requestID: "mirror-\(UUID().uuidString.prefix(8))",
            role: .scout,
            preset: .scout,
            instruction: instruction,
            context: [entries],
            maxOutputTokens: 220,
            stopSequences: []))
    } catch {
        let note = "mirror: model unavailable — the lane stays honest, no fake mirror. "
            + "(\(error))\n"
        FileHandle.standardError.write(Data(note.utf8))
        exit(2)
    }

    let candidate = BASMirrorLaneCandidate(
        claimedKind: .annotation,
        content: draft.body,
        evidenceIDs: recent.map { "atom:\($0.id.uuidString.lowercased())" },
        modelID: adapter.descriptor.providerID,
        promptDigest: BASConvergedProposalEnvelope.sha256Hex(
            instruction + "\n" + entries),
        claimedPolicyHash: BASSovereignTrustConstants.builtInPolicyHash,
        provenance: "qinao-journal-mirror")
    let key = try loadOrCreateMirrorTagKey()
    let disposition = BASMirrorLaneDisposer.dispose(
        candidate,
        policy: BASMirrorLanePolicy(
            trustedPolicyHash: BASSovereignTrustConstants.builtInPolicyHash),
        key: key,
        envelopeID: UUID().uuidString.lowercased(),
        now: Date())

    guard case .accepted(let envelope) = disposition else {
        if case .rejected(let reason) = disposition {
            let note = "mirror: model output REJECTED by the deterministic gate "
                + "(\(reason.rawValue)) — nothing enters the ledger\n"
            FileHandle.standardError.write(Data(note.utf8))
            exit(1)
        }
        return  // .reduced impossible: annotation is already the floor
    }

    let ledger = try makeLedger()
    let outcome = await BASMirrorLaneIngestGate.ingest(
        envelope, key: key, ledger: ledger,
        sessionID: journalSessionID,
        turnID: "mirror-\(Int(Date().timeIntervalSince1970))")
    guard outcome.appended else {
        FileHandle.standardError.write(
            Data("mirror: ingest REJECTED (\(outcome.reason?.rawValue ?? "unknown"))\n".utf8))
        exit(1)
    }
    print("🪞 \(draft.body)")
    print("sealed \(String((outcome.auditID ?? "").prefix(24)))  "
        + "annotation over \(recent.count) entries  (mirror lane, Ed25519 chain)")
}
