import XCTest
import Foundation
@testable import BASRuntimeCore

/// audit runtimecore-b MED-5 — the v2 binary decode must (a) SURFACE a corrupt
/// payload envelope instead of silently stripping every field to defaults, and
/// (b) round-trip memoryRefs delimiter-safely (the legacy comma-join corrupted
/// any ref containing a comma).
final class BASEventLogBinaryDecodeSafetyTests: XCTestCase {

    // (A) — envelope decode surfaces corruption
    func testCorruptEnvelopeThrows() {
        XCTAssertThrowsError(try BASSQLiteEventLogStorage.decodePayloadEnvelope("{not json"),
            "malformed JSON must throw, not silently yield an empty dict")
        XCTAssertThrowsError(try BASSQLiteEventLogStorage.decodePayloadEnvelope("[1,2,3]"),
            "a wrong-shape payload must throw")
    }
    func testValidEnvelopeDecodes() throws {
        let env = try BASSQLiteEventLogStorage.decodePayloadEnvelope(#"{"source":"x","intent":"y"}"#)
        XCTAssertEqual(env["source"], "x")
        XCTAssertEqual(env["intent"], "y")
    }

    // (B) — memoryRefs delimiter-safe round-trip through the real binary path
    private var dir: URL!
    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("binref-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        BASSQLiteEventLogStorage.useBinaryPayload = false
        try? FileManager.default.removeItem(at: dir)
    }

    func testMemoryRefsWithCommasSurviveBinaryRoundTrip() async throws {
        BASSQLiteEventLogStorage.useBinaryPayload = true
        let store = try BASSQLiteEventLogStorage(
            databaseURL: dir.appendingPathComponent("e.sqlite"))
        let refs = ["atom,with,commas", "plain", "a=1,b=2"]
        let entry = BASEventLogEntry(
            eventID: "e0", timestampMs: 1000, kind: .substrateAudit,
            sessionID: "s", sequenceNumber: 0, memoryRefs: refs, actions: ["x"])
        _ = try await store.append(entry)

        let read = try await store.eventsOrThrow(forSession: "s")
        XCTAssertEqual(read.count, 1)
        XCTAssertEqual(read.first?.memoryRefs, refs,
            "memoryRefs containing commas must survive the binary round-trip "
            + "(the legacy comma-join split them into wrong pieces)")
    }
}
