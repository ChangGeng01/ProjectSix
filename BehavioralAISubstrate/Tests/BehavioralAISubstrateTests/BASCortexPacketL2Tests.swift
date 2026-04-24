import XCTest
@testable import BASOrchestration
@testable import BASRuntimeCore
@testable import BASAdmin

/// M107 — L2 whitepaper §7 `CortexPacket` closure tests.
///
/// Pre-M107 the L2 whitepaper §7 listed 8 core objects but only 7
/// had Swift structs — `CortexPacket` was the whitepaper-named
/// gap (the Core Cortex organ's per-turn compact output frame).
/// M107 adds the 6-field struct matching the §7 spec.
///
/// Coverage:
///
/// 1. Schema version stable
/// 2. All 6 fields round-trip with user values
/// 3. Input trim on each String field
/// 4. `structureSlots` dict stays key/value opaque
/// 5. `.empty` baseline all-empty-strings
/// 6. Codable round-trip preserves all 7 fields
final class BASCortexPacketL2Tests: XCTestCase {

    // MARK: - 1. Schema version

    func testSchemaVersionIsOneDotZero() {
        XCTAssertEqual(
            BASCortexPacket.currentSchemaVersion, "1.0.0")
    }

    // MARK: - 2. All 6 fields round-trip

    func testBasicInitCarriesAllFields() {
        let packet = BASCortexPacket(
            semanticFrame: "user wants to send email",
            structureSlots: [
                "subject": "user",
                "verb": "send",
                "object": "email",
                "time": "now",
            ],
            hostModSummary: "boundary-soft",
            riskSummary: "low.reversible",
            candidateSeed: "send.email.primary",
            consistencyChecksum: "sha256:abcd")
        XCTAssertEqual(
            packet.semanticFrame, "user wants to send email")
        XCTAssertEqual(
            packet.structureSlots["subject"], "user")
        XCTAssertEqual(
            packet.structureSlots["verb"], "send")
        XCTAssertEqual(packet.hostModSummary, "boundary-soft")
        XCTAssertEqual(packet.riskSummary, "low.reversible")
        XCTAssertEqual(
            packet.candidateSeed, "send.email.primary")
        XCTAssertEqual(
            packet.consistencyChecksum, "sha256:abcd")
    }

    // MARK: - 3. Whitespace trim on string fields

    func testInitTrimsWhitespaceFromStringFields() {
        let packet = BASCortexPacket(
            semanticFrame: "  semantic  ",
            hostModSummary: "  mod  ",
            riskSummary: "\n risk \t",
            candidateSeed: " seed ",
            consistencyChecksum: " check ")
        XCTAssertEqual(packet.semanticFrame, "semantic")
        XCTAssertEqual(packet.hostModSummary, "mod")
        XCTAssertEqual(packet.riskSummary, "risk")
        XCTAssertEqual(packet.candidateSeed, "seed")
        XCTAssertEqual(packet.consistencyChecksum, "check")
    }

    // MARK: - 4. structureSlots opacity

    func testStructureSlotsPreservesArbitraryKeys() {
        let packet = BASCortexPacket(
            semanticFrame: "x",
            structureSlots: [
                "custom_slot_1": "value 1",
                "custom_slot_2": "value 2",
                "   padded   ": "preserved",
            ],
            hostModSummary: "x",
            riskSummary: "x",
            candidateSeed: "x",
            consistencyChecksum: "x")
        // Dictionary keys are NOT trimmed — the slot vocabulary is
        // opaque to the substrate; callers own the key normalization.
        XCTAssertEqual(
            packet.structureSlots["   padded   "],
            "preserved",
            "arbitrary keys / values are preserved byte-for-byte")
        XCTAssertEqual(packet.structureSlots.count, 3)
    }

    // MARK: - 5. Empty baseline

    func testEmptyBaselineHasAllBlankFields() {
        let e = BASCortexPacket.empty
        XCTAssertEqual(e.semanticFrame, "")
        XCTAssertEqual(e.structureSlots, [:])
        XCTAssertEqual(e.hostModSummary, "")
        XCTAssertEqual(e.riskSummary, "")
        XCTAssertEqual(e.candidateSeed, "")
        XCTAssertEqual(e.consistencyChecksum, "")
    }

    // MARK: - 6. Codable round-trip

    func testCodableRoundTripPreservesAllFields() throws {
        let orig = BASCortexPacket(
            semanticFrame: "rt.frame",
            structureSlots: [
                "a": "1", "b": "2", "c": "3"
            ],
            hostModSummary: "rt.mod",
            riskSummary: "rt.risk",
            candidateSeed: "rt.seed",
            consistencyChecksum: "rt.check")
        let data = try JSONEncoder().encode(orig)
        let decoded = try JSONDecoder().decode(
            BASCortexPacket.self, from: data)
        XCTAssertEqual(decoded, orig)
    }

    // MARK: - 7. Schema governance registry registration

    func testRegisteredInSchemaGovernanceRegistry() {
        let ids = Set(
            BASEBrainSchemaGovernanceRegistry.governedSchemas
                .map(\.objectID))
        XCTAssertTrue(
            ids.contains("CortexPacket"),
            "CortexPacket must appear in governed schema list")
    }
}
