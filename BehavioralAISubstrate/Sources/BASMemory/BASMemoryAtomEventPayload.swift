// MARK: - BASMemoryAtomEventPayload — chapter 四百二 / M941
//
// Phase 1 第一刀: typed payload that lets memory-atom mutations
// ride the existing BASEventLog as canonical source-of-truth。
// Closes the parallel-source-of-truth gap surfaced by the M941
// architecture audit (chapter 二百一一 single-source-of-truth)。
//
// ## Why this exists
//
// Pre-M941 `BASMemoryAtomStore` conformers (`BASInMemoryMemoryAtomStore`
// + `BASSQLiteMemoryAtomStore`) own atom rows directly。
// `BASMemoryMutationWriter.apply(outcome:)` mutates rows in place
// via `updateTier` / `updateGovernanceStatus` / `remove`。NONE of
// these mutations append to the event log first。A reducer rebuilt
// today on the same event log cannot reconstruct the atom set —
// disk and event log can diverge。
//
// M941 ships the typed payload that lets every atom mutation be
// expressed as a `BASEventLogEntry` with `kind: .internalSignal` +
// a typed `BASMemoryAtomEventPayload` encoded inside `payloadJson`。
// M942 ships the reducer that folds these events back into atoms。
// M943 ships the event-sourced store conformer that uses both。
// M944 ships the emitter that bridges existing
// `BASMemoryMutationWriter.apply(outcome:)` outcomes into events。
//
// ## What this file ships (M941)
//
//   - `BASMemoryAtomEventOp` — typed operation enum
//     (admitted / tier-changed / governance-changed / removed)
//   - `BASMemoryAtomEventPayload` — typed Codable payload struct
//     that encodes the full new-state for `.admitted` and only the
//     mutation delta for the other ops。
//   - Convenience initializers (`init(admitted:)`,
//     `init(tierChange:)`, `init(governanceChange:)`,
//     `init(remove:)`)
//   - `BASEventLogEntry` extension factory `memoryAtomEvent(...)` +
//     accessor `memoryAtomEventPayload`(round-trip JSON via
//     `payloadJson`)
//   - Discriminator action tag (`memory-atom-event`) that lets
//     readers cheaply filter the event stream without decoding
//     payloads
//
// ## Why this lives in BASMemory (not BASRuntimeCore)
//
// The plan's M941 spec named `BASRuntimeCore/...` as the file's
// home,but the typed payload references `BASMemoryKind`,
// `BASMemoryScope`, `BASMemorySensitivity`, `BASMemoryTier`,
// `BASMemoryGovernanceStatus` — all of which live in `BASMemory`,
// which depends on `BASRuntimeCore`。Putting the payload in
// `BASRuntimeCore` would either force a circular dependency or
// downgrade the typed enums to raw `String` fields。Neither is
// acceptable per chapter 一百八十五 anti-magic-number。Pragmatic
// resolution: the payload + extension live in `BASMemory`,which
// already imports `BASRuntimeCore` and can extend
// `BASEventLogEntry` from there。Doctrine intent is preserved。
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — payload is observation plumbing
//   - 红线 7 hint-only — events are append-only audit records
//   - chapter 二百一一 single-source-of-truth — load-bearing
//     pin。This file is the typed payload that the unification
//     hangs off。
//   - chapter 一百八十五 anti-magic-number — typed enums everywhere,
//     discriminator action tag is a `static let` constant
//   - chapter 三百九二 (M892) replay-determinism — payload field
//     ordering is fixed via Codable derived keys;encoded JSON is
//     byte-stable for fixed input
//   - ADR-014 OPT-IN → PROD — no existing API breaks;legacy
//     stores never see this payload
//   - ADR-016 substrate completion — Phase 1 entry point

import CryptoKit
import Foundation
import BASRuntimeCore
// chapter 七百二 native-port — Rust SHA256 primitive。 Legacy
// CryptoKit body preserved as `/* ... */` per 全comment 不要删除。
import BASRustHashCore

// MARK: - Operation enum

/// Typed enum naming canonical memory-atom mutation operations。
/// Raw values pinned for wire stability (chapter 八十七 raw value
/// stability — bumping requires audit migration)。
public enum BASMemoryAtomEventOp:
    String, Codable, Sendable, Equatable, Hashable, CaseIterable
{
    /// Atom admitted into the store。Payload carries the full
    /// initial atom shape (kind / scope / sensitivity / tier /
    /// confidence / sourceType / governanceStatus / provenanceSummary
    /// / contentDigest)。
    case admitted = "admitted"

    /// Atom's `tier` field changed。Payload carries the new tier。
    case tierChanged = "tier-changed"

    /// Atom's `governanceStatus` field changed。Payload carries
    /// the new status。
    case governanceChanged = "governance-changed"

    /// Atom removed from the store。Payload carries only the
    /// `atomID` (no other fields)。
    case removed = "removed"
}

// MARK: - Payload

/// Typed Codable payload encoded inside `BASEventLogEntry.payloadJson`
/// when the event represents a memory-atom mutation。
///
/// Only fields relevant to the operation are populated:
/// - `.admitted` → all fields populated (full initial snapshot)
/// - `.tierChanged` → `atomID` + `tier` only
/// - `.governanceChanged` → `atomID` + `governanceStatus` only
/// - `.removed` → `atomID` only
public struct BASMemoryAtomEventPayload:
    Codable, Equatable, Sendable, Hashable
{

    // MARK: - Required identity

    /// Typed operation discriminator。
    public let op: BASMemoryAtomEventOp

    /// Atom ID — `BASGovernedMemory.id.uuidString`。
    public let atomID: String

    // MARK: - .admitted full snapshot (nil otherwise)

    /// Atom kind (semantic / episodic / etc.)。Populated only for
    /// `.admitted`。
    public let kind: BASMemoryKind?

    /// Atom scope。Populated only for `.admitted`。
    public let scope: BASMemoryScope?

    /// Atom sensitivity。Populated only for `.admitted`。
    public let sensitivity: BASMemorySensitivity?

    /// Atom tier。Populated for `.admitted` (initial tier) and
    /// `.tierChanged` (new tier)。
    public let tier: BASMemoryTier?

    /// Confidence 0..1。Populated only for `.admitted`。
    public let confidence: Double?

    /// Atom sourceType (string identifier of producer)。Populated
    /// only for `.admitted`。
    public let sourceType: String?

    /// `lastConfirmedAt` as UNIX millis。Populated only for
    /// `.admitted`。Nil if the atom had no confirmation。
    public let lastConfirmedAtMs: Int64?

    /// Atom governance status。Populated for `.admitted` (initial
    /// status) and `.governanceChanged` (new status)。
    public let governanceStatus: BASMemoryGovernanceStatus?

    /// Atom provenance summary。Populated only for `.admitted`。
    public let provenanceSummary: String?

    /// SHA256 digest of atom `content` field (hex-encoded)。
    /// Privacy: never the raw content。Populated only for
    /// `.admitted`。
    public let contentDigest: String?

    // MARK: - Init

    public init(
        op: BASMemoryAtomEventOp,
        atomID: String,
        kind: BASMemoryKind? = nil,
        scope: BASMemoryScope? = nil,
        sensitivity: BASMemorySensitivity? = nil,
        tier: BASMemoryTier? = nil,
        confidence: Double? = nil,
        sourceType: String? = nil,
        lastConfirmedAtMs: Int64? = nil,
        governanceStatus: BASMemoryGovernanceStatus? = nil,
        provenanceSummary: String? = nil,
        contentDigest: String? = nil
    ) {
        self.op = op
        self.atomID = atomID
        self.kind = kind
        self.scope = scope
        self.sensitivity = sensitivity
        self.tier = tier
        // Confidence clamp matches BASEventLogEntry policy
        // (chapter 一百八十五:clamp at boundary)。
        if let c = confidence {
            self.confidence = max(0, min(1, c))
        } else {
            self.confidence = nil
        }
        self.sourceType = sourceType
        self.lastConfirmedAtMs = lastConfirmedAtMs
        self.governanceStatus = governanceStatus
        self.provenanceSummary = provenanceSummary
        self.contentDigest = contentDigest
    }

    // MARK: - Convenience inits per op

    /// Admitted: full initial snapshot of the atom。Computes the
    /// SHA256 contentDigest from the atom's `content` field。
    public init(admitted atom: BASGovernedMemory) {
        let digest = BASMemoryAtomEventPayload.sha256Hex(atom.content)
        self.init(
            op: .admitted,
            atomID: atom.id.uuidString,
            kind: atom.kind,
            scope: atom.scope,
            sensitivity: atom.sensitivity,
            tier: atom.tier,
            confidence: atom.confidence,
            sourceType: atom.sourceType,
            lastConfirmedAtMs: atom.lastConfirmedAt.map {
                Int64($0.timeIntervalSince1970 * 1000)
            },
            governanceStatus: atom.governanceStatus,
            provenanceSummary: atom.provenanceSummary,
            contentDigest: digest)
    }

    /// Tier change: only atomID + new tier carried。
    public init(
        tierChange atomID: String,
        newTier: BASMemoryTier
    ) {
        self.init(
            op: .tierChanged,
            atomID: atomID,
            tier: newTier)
    }

    /// Governance change: only atomID + new status carried。
    public init(
        governanceChange atomID: String,
        newStatus: BASMemoryGovernanceStatus
    ) {
        self.init(
            op: .governanceChanged,
            atomID: atomID,
            governanceStatus: newStatus)
    }

    /// Removal: only atomID carried。
    public init(remove atomID: String) {
        self.init(
            op: .removed,
            atomID: atomID)
    }

    // MARK: - Hashing helper

    /// SHA256 of UTF-8 bytes,hex-encoded lowercase。Used for the
    /// content digest field。Same hash same input → byte-stable
    /// (chapter 三百九二 replay-determinism)。
    ///
    /// chapter 七百二 native-port — NIST-pinned: this surface is
    /// asserted by `BASMemoryAtomEventPayloadTests` against the
    /// canonical NIST FIPS 180-4 reference vector for SHA256("abc")。
    /// The Rust-sourced `BASRustLedgerCore.sha256(_:)` helper uses a
    /// length-prefixed-chain formula (SHA256(0x00*32 || u32_be(len)
    /// || data)) which does NOT equal pure SHA256(data)。 Until a
    /// pure-SHA256 FFI lands in the XCFramework,this site KEEPS the
    /// CryptoKit body (no port)。 Documented here so future migration
    /// commits don't re-attempt the swap blindly。
    public static func sha256Hex(_ s: String) -> String {
        // NIST-pinned — stays on CryptoKit. See port-status note above.
        let bytes = Array(s.utf8)
        let digest = SHA256.hash(data: bytes)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - BASEventLogEntry extension

extension BASEventLogEntry {

    /// Discriminator tag appended to `actions` so readers can
    /// cheaply filter the event stream for memory-atom events
    /// without decoding `payloadJson`。chapter 一百八十五:typed
    /// constant,not inline string。
    public static let memoryAtomEventActionTag: String =
        "memory-atom-event"

    /// Build a `BASEventLogEntry` carrying a memory-atom mutation
    /// payload。Caller passes 0 for `sequenceNumber` — the storage
    /// layer assigns the actual sequence on append。
    ///
    /// Encodes the typed payload into `payloadJson` via JSONEncoder
    /// with sorted-keys output (M892 byte-stability)。
    public static func memoryAtomEvent(
        eventID: String,
        timestampMs: Int64,
        sessionID: String,
        sequenceNumber: Int64 = 0,
        payload: BASMemoryAtomEventPayload,
        source: String? = "memory-atom-store",
        turnRef: String? = nil
    ) -> BASEventLogEntry {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json: String?
        if let data = try? encoder.encode(payload) {
            json = String(data: data, encoding: .utf8)
        } else {
            json = nil
        }
        return BASEventLogEntry(
            eventID: eventID,
            timestampMs: timestampMs,
            kind: .internalSignal,
            sessionID: sessionID,
            sequenceNumber: sequenceNumber,
            source: source,
            turnRef: turnRef,
            rawInputDigest: nil,
            intent: nil,
            emotion: nil,
            riskBand: .unknown,
            project: nil,
            memoryRefs: [payload.atomID],
            stateBeforeID: nil,
            stateAfterID: nil,
            actions: [memoryAtomEventActionTag],
            confidence: 0,
            payloadJson: json)
    }

    /// Decode the `BASMemoryAtomEventPayload` if this entry is a
    /// memory-atom event。Returns nil for entries that aren't
    /// memory-atom events or whose payload is malformed (forward-
    /// compat: unknown payloads decode silently to nil)。
    public var memoryAtomEventPayload:
        BASMemoryAtomEventPayload?
    {
        guard kind == .internalSignal else { return nil }
        guard actions.contains(
            BASEventLogEntry.memoryAtomEventActionTag
        ) else {
            return nil
        }
        guard let json = payloadJson,
              let data = json.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(
            BASMemoryAtomEventPayload.self, from: data)
    }
}
