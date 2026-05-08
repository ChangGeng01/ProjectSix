// MARK: - BASMemoryAtomEventPayloadTests — chapter 四百二 / M941
//
// Test coverage for Phase 1 第一刀:typed memory-atom mutation
// event payload。
//
// Targets per the M941 plan spec:
//   - Codable round-trip per op variant (4)
//   - Per-op required field invariants (4)
//   - eventID determinism for replay (3)
//   - payload digest hashing (3)
//   - memoryAtomEventPayload accessor round-trip on
//     BASEventLogEntry (4)
//
// Total: 18 tests。

import Foundation
import XCTest
@testable import BASMemory
@testable import BASRuntimeCore

final class BASMemoryAtomEventPayloadTests: XCTestCase {

    // MARK: - Test fixtures

    private func makeAtom(
        id: UUID = UUID(uuidString:
            "00000000-0000-4000-8000-000000000001")!,
        content: String = "fixture-content",
        kind: BASMemoryKind = .semantic,
        scope: BASMemoryScope = .user,
        sensitivity: BASMemorySensitivity = .low,
        tier: BASMemoryTier = .warm,
        confidence: Double = 0.6,
        sourceType: String = "test-source",
        lastConfirmedAt: Date? = Date(timeIntervalSince1970: 1_700_000),
        governanceStatus: BASMemoryGovernanceStatus = .governed,
        provenanceSummary: String = "test-provenance"
    ) -> BASGovernedMemory {
        BASGovernedMemory(
            id: id,
            kind: kind,
            content: content,
            scope: scope,
            sensitivity: sensitivity,
            tier: tier,
            confidence: confidence,
            sourceType: sourceType,
            lastConfirmedAt: lastConfirmedAt,
            decayScore: 0.0,
            governanceStatus: governanceStatus,
            provenanceSummary: provenanceSummary)
    }

    // MARK: - Codable round-trip per op variant (4)

    func testAdmittedRoundTrip() throws {
        let atom = makeAtom()
        let payload = BASMemoryAtomEventPayload(admitted: atom)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(payload)
        let decoded = try JSONDecoder().decode(
            BASMemoryAtomEventPayload.self, from: data)
        XCTAssertEqual(decoded, payload,
            "M941:.admitted Codable round-trip must preserve all fields")
    }

    func testTierChangedRoundTrip() throws {
        let payload = BASMemoryAtomEventPayload(
            tierChange: "atom-123",
            newTier: .hot)
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(
            BASMemoryAtomEventPayload.self, from: data)
        XCTAssertEqual(decoded, payload,
            "M941:.tierChanged Codable round-trip preserves atomID + tier")
    }

    func testGovernanceChangedRoundTrip() throws {
        let payload = BASMemoryAtomEventPayload(
            governanceChange: "atom-456",
            newStatus: .quarantined)
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(
            BASMemoryAtomEventPayload.self, from: data)
        XCTAssertEqual(decoded, payload,
            "M941:.governanceChanged Codable round-trip preserves atomID + status")
    }

    func testRemovedRoundTrip() throws {
        let payload = BASMemoryAtomEventPayload(
            remove: "atom-789")
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(
            BASMemoryAtomEventPayload.self, from: data)
        XCTAssertEqual(decoded, payload,
            "M941:.removed Codable round-trip preserves atomID")
    }

    // MARK: - Per-op required field invariants (4)

    func testAdmittedPopulatesAllSnapshotFields() {
        let atom = makeAtom()
        let payload = BASMemoryAtomEventPayload(admitted: atom)
        XCTAssertEqual(payload.op, .admitted)
        XCTAssertEqual(payload.atomID, atom.id.uuidString)
        XCTAssertNotNil(payload.kind)
        XCTAssertNotNil(payload.scope)
        XCTAssertNotNil(payload.sensitivity)
        XCTAssertNotNil(payload.tier)
        XCTAssertNotNil(payload.confidence)
        XCTAssertNotNil(payload.sourceType)
        XCTAssertNotNil(payload.governanceStatus)
        XCTAssertNotNil(payload.provenanceSummary)
        XCTAssertNotNil(payload.contentDigest)
    }

    func testTierChangedOnlyPopulatesAtomIDAndTier() {
        let payload = BASMemoryAtomEventPayload(
            tierChange: "abc",
            newTier: .cold)
        XCTAssertEqual(payload.op, .tierChanged)
        XCTAssertEqual(payload.atomID, "abc")
        XCTAssertEqual(payload.tier, .cold)
        XCTAssertNil(payload.kind)
        XCTAssertNil(payload.scope)
        XCTAssertNil(payload.sensitivity)
        XCTAssertNil(payload.confidence)
        XCTAssertNil(payload.sourceType)
        XCTAssertNil(payload.governanceStatus)
        XCTAssertNil(payload.provenanceSummary)
        XCTAssertNil(payload.contentDigest)
    }

    func testGovernanceChangedOnlyPopulatesAtomIDAndStatus() {
        let payload = BASMemoryAtomEventPayload(
            governanceChange: "xyz",
            newStatus: .archived)
        XCTAssertEqual(payload.op, .governanceChanged)
        XCTAssertEqual(payload.atomID, "xyz")
        XCTAssertEqual(payload.governanceStatus, .archived)
        XCTAssertNil(payload.kind)
        XCTAssertNil(payload.tier)
        XCTAssertNil(payload.confidence)
        XCTAssertNil(payload.contentDigest)
    }

    func testRemovedOnlyPopulatesAtomID() {
        let payload = BASMemoryAtomEventPayload(remove: "rm-1")
        XCTAssertEqual(payload.op, .removed)
        XCTAssertEqual(payload.atomID, "rm-1")
        XCTAssertNil(payload.kind)
        XCTAssertNil(payload.tier)
        XCTAssertNil(payload.governanceStatus)
        XCTAssertNil(payload.contentDigest)
    }

    // MARK: - Replay determinism (3) — chapter 三百九二

    func testEncodedPayloadByteStableAcrossRuns() throws {
        let atom = makeAtom()
        let p1 = BASMemoryAtomEventPayload(admitted: atom)
        let p2 = BASMemoryAtomEventPayload(admitted: atom)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let d1 = try encoder.encode(p1)
        let d2 = try encoder.encode(p2)
        XCTAssertEqual(d1, d2,
            "M941:same atom → byte-stable encoded payload (M892)")
    }

    func testConfidenceClampHonored() {
        let p1 = BASMemoryAtomEventPayload(
            op: .admitted,
            atomID: "a",
            confidence: 1.5)
        XCTAssertEqual(p1.confidence, 1.0,
            "M941:confidence > 1 must clamp")
        let p2 = BASMemoryAtomEventPayload(
            op: .admitted,
            atomID: "a",
            confidence: -0.3)
        XCTAssertEqual(p2.confidence, 0.0,
            "M941:confidence < 0 must clamp")
    }

    func testContentDigestStableForSameContent() {
        let atom1 = makeAtom(content: "hello world")
        let atom2 = makeAtom(content: "hello world")
        let p1 = BASMemoryAtomEventPayload(admitted: atom1)
        let p2 = BASMemoryAtomEventPayload(admitted: atom2)
        XCTAssertEqual(p1.contentDigest, p2.contentDigest,
            "M941:same content → same SHA256 digest (M892)")
    }

    // MARK: - Payload digest hashing (3)

    func testContentDigestDiffersForDifferentContent() {
        let p1 = BASMemoryAtomEventPayload(
            admitted: makeAtom(content: "alpha"))
        let p2 = BASMemoryAtomEventPayload(
            admitted: makeAtom(content: "beta"))
        XCTAssertNotEqual(p1.contentDigest, p2.contentDigest,
            "M941:different content → different digest")
    }

    func testContentDigestIsLowercaseHex() {
        let payload = BASMemoryAtomEventPayload(
            admitted: makeAtom(content: "x"))
        let digest = payload.contentDigest ?? ""
        XCTAssertEqual(digest.count, 64,
            "SHA256 hex must be 64 chars")
        let allowed = CharacterSet(charactersIn: "0123456789abcdef")
        XCTAssertTrue(
            digest.unicodeScalars.allSatisfy { allowed.contains($0) },
            "M941:digest must be lowercase hex only")
    }

    func testSha256HexHelperKnownVector() {
        // "abc" SHA-256 = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
        let digest = BASMemoryAtomEventPayload.sha256Hex("abc")
        XCTAssertEqual(
            digest,
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
            "M941:SHA-256 helper matches NIST test vector for 'abc'")
    }

    // MARK: - BASEventLogEntry round-trip (4)

    func testMemoryAtomEventFactoryRoundTripsThroughPayloadJson() {
        let atom = makeAtom()
        let payload = BASMemoryAtomEventPayload(admitted: atom)
        let entry = BASEventLogEntry.memoryAtomEvent(
            eventID: "evt-1",
            timestampMs: 1_700_000_000_000,
            sessionID: "sess-A",
            sequenceNumber: 0,
            payload: payload)
        XCTAssertEqual(entry.kind, .internalSignal)
        XCTAssertEqual(entry.sessionID, "sess-A")
        XCTAssertTrue(
            entry.actions.contains(
                BASEventLogEntry.memoryAtomEventActionTag),
            "M941:discriminator action tag must be present")
        let decoded = entry.memoryAtomEventPayload
        XCTAssertEqual(decoded, payload,
            "M941:round-trip via payloadJson preserves payload")
    }

    func testNonMemoryAtomEntryDecodesToNilPayload() {
        // Plain chat event — no memory-atom payload。
        let entry = BASEventLogEntry(
            eventID: "evt-2",
            timestampMs: 0,
            kind: .chat,
            sessionID: "s",
            sequenceNumber: 0)
        XCTAssertNil(entry.memoryAtomEventPayload,
            "M941:non-memory-atom entries return nil payload")
    }

    func testInternalSignalWithoutTagDecodesToNil() {
        // Pure internal signal but no memory-atom action tag。
        let entry = BASEventLogEntry(
            eventID: "evt-3",
            timestampMs: 0,
            kind: .internalSignal,
            sessionID: "s",
            sequenceNumber: 0,
            actions: ["other-tag"],
            payloadJson: "{\"unrelated\": true}")
        XCTAssertNil(entry.memoryAtomEventPayload,
            "M941:internalSignal lacking discriminator tag → nil payload")
    }

    func testMemoryAtomEntryRecordsAtomIDAsMemoryRef() {
        let payload = BASMemoryAtomEventPayload(
            remove: "atom-removed")
        let entry = BASEventLogEntry.memoryAtomEvent(
            eventID: "evt-4",
            timestampMs: 0,
            sessionID: "s",
            payload: payload)
        XCTAssertEqual(entry.memoryRefs, ["atom-removed"],
            "M941:atomID must surface in memoryRefs for cheap filter")
    }
}
