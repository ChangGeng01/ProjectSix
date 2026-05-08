// MARK: - BASFrameContextTests — chapter 四百三 / M953
//
// Test coverage for the typed frame-context value type that
// collapses (sessionID, turnID, emittedAt) threading entropy
// in the runTurn coordinator。
//
// Targets:
//   - Direct init shape (3 tests)
//   - Canonical derivation formula matches runTurn's L756-762
//     verbatim (5 tests)
//   - Codable round-trip (2 tests)
//   - chapter 三百九二 replay-determinism (3 tests)
//   - chapter 一百八十五 anti-magic-number constants pinned (2 tests)
//   - Convenience accessors (3 tests)

import Foundation
import XCTest
@testable import BASRuntimeCore

final class BASFrameContextTests: XCTestCase {

    // MARK: - Direct init shape (3)

    func testDirectInitPreservesFields() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let ctx = BASFrameContext(
            sessionID: "host|chat|normal",
            turnID: "host|chat|normal#777.0",
            emittedAt: date)
        XCTAssertEqual(ctx.sessionID, "host|chat|normal")
        XCTAssertEqual(ctx.turnID, "host|chat|normal#777.0")
        XCTAssertEqual(ctx.emittedAt, date)
    }

    func testDirectInitAcceptsEmptyStrings() {
        // Empty fields permitted (cross-session system events
        // analogue to BASEventLogEntry)
        let ctx = BASFrameContext(
            sessionID: "",
            turnID: "",
            emittedAt: Date(timeIntervalSince1970: 0))
        XCTAssertTrue(ctx.sessionID.isEmpty)
        XCTAssertTrue(ctx.turnID.isEmpty)
    }

    func testTwoContextsWithSameFieldsAreEqual() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let a = BASFrameContext(
            sessionID: "s", turnID: "t", emittedAt: date)
        let b = BASFrameContext(
            sessionID: "s", turnID: "t", emittedAt: date)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    // MARK: - Canonical derivation formula (5)

    func testCanonicalSessionIDFormula() {
        let ctx = BASFrameContext(
            hostID: "host.primary",
            taskTypeRaw: "conflict",
            runModeRaw: "guard",
            recordedAt: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(
            ctx.sessionID,
            "host.primary|conflict|guard",
            "M953:sessionID = hostID|taskType|runMode")
    }

    func testCanonicalTurnIDFormula() {
        // turnID = sessionID + "#" +
        // recordedAt.timeIntervalSinceReferenceDate
        let date = Date(timeIntervalSinceReferenceDate: 12345.0)
        let ctx = BASFrameContext(
            hostID: "h",
            taskTypeRaw: "ask",
            runModeRaw: "normal",
            recordedAt: date)
        XCTAssertEqual(
            ctx.turnID,
            "h|ask|normal#12345.0",
            "M953:turnID matches runTurn L756-762 derivation")
    }

    func testEmptyHostIDStillProducesValidIDs() {
        let ctx = BASFrameContext(
            hostID: "",
            taskTypeRaw: "x",
            runModeRaw: "y",
            recordedAt: Date(timeIntervalSinceReferenceDate: 0))
        XCTAssertEqual(ctx.sessionID, "|x|y")
        XCTAssertEqual(ctx.turnID, "|x|y#0.0")
    }

    func testTurnIDIsSessionIDPlusTimestamp() {
        let date = Date(timeIntervalSinceReferenceDate: 99.5)
        let ctx = BASFrameContext(
            hostID: "h",
            taskTypeRaw: "t",
            runModeRaw: "m",
            recordedAt: date)
        XCTAssertTrue(
            ctx.turnID.hasPrefix(ctx.sessionID),
            "M953:turnID prefix must equal sessionID")
        XCTAssertTrue(
            ctx.turnID.hasSuffix("#99.5"))
    }

    func testCanonicalDerivationMatchesRunTurnVerbatim() {
        // Mirror the literal formula from
        // EBrainRuntimeCoordinator.runTurn L756-762
        let hostID = "host.alice"
        let taskTypeRaw = "ask"
        let runModeRaw = "guard"
        let recordedAt =
            Date(timeIntervalSince1970: 1_705_000_000)
        // Manual replication of runTurn's formula:
        let manualSID = [
            hostID, taskTypeRaw, runModeRaw
        ].joined(separator: "|")
        let manualTID =
            "\(manualSID)#\(recordedAt.timeIntervalSinceReferenceDate)"
        // Canonical init
        let ctx = BASFrameContext(
            hostID: hostID,
            taskTypeRaw: taskTypeRaw,
            runModeRaw: runModeRaw,
            recordedAt: recordedAt)
        XCTAssertEqual(ctx.sessionID, manualSID,
            "M953:canonical init mirrors runTurn formula")
        XCTAssertEqual(ctx.turnID, manualTID,
            "M953:canonical init mirrors runTurn turnID formula")
    }

    // MARK: - Codable round-trip (2)

    func testCodableRoundTrip() throws {
        let ctx = BASFrameContext(
            hostID: "h",
            taskTypeRaw: "t",
            runModeRaw: "m",
            recordedAt: Date(timeIntervalSinceReferenceDate: 1.5))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(ctx)
        let decoded = try JSONDecoder().decode(
            BASFrameContext.self, from: data)
        XCTAssertEqual(decoded, ctx)
    }

    func testEncodedJSONByteStable() throws {
        let ctx1 = BASFrameContext(
            hostID: "h", taskTypeRaw: "t", runModeRaw: "m",
            recordedAt: Date(timeIntervalSinceReferenceDate: 0))
        let ctx2 = BASFrameContext(
            hostID: "h", taskTypeRaw: "t", runModeRaw: "m",
            recordedAt: Date(timeIntervalSinceReferenceDate: 0))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let d1 = try encoder.encode(ctx1)
        let d2 = try encoder.encode(ctx2)
        XCTAssertEqual(d1, d2,
            "M953:M892 byte-stable encoded representation")
    }

    // MARK: - Replay determinism (3) — chapter 三百九二

    func testSameInputProducesByteEqualContext() {
        let ctx1 = BASFrameContext(
            hostID: "h",
            taskTypeRaw: "t",
            runModeRaw: "m",
            recordedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let ctx2 = BASFrameContext(
            hostID: "h",
            taskTypeRaw: "t",
            runModeRaw: "m",
            recordedAt: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(ctx1, ctx2,
            "M953:replay-determinism — same input → same context")
    }

    func testDifferentRecordedAtProducesDifferentTurnID() {
        let ctx1 = BASFrameContext(
            hostID: "h", taskTypeRaw: "t", runModeRaw: "m",
            recordedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let ctx2 = BASFrameContext(
            hostID: "h", taskTypeRaw: "t", runModeRaw: "m",
            recordedAt: Date(timeIntervalSince1970: 1_700_000_001))
        XCTAssertNotEqual(ctx1.turnID, ctx2.turnID)
        XCTAssertEqual(ctx1.sessionID, ctx2.sessionID,
            "Same session,different turn → same sessionID")
    }

    func testDifferentHostIDProducesDifferentSessionID() {
        let ctx1 = BASFrameContext(
            hostID: "alice", taskTypeRaw: "t", runModeRaw: "m",
            recordedAt: Date(timeIntervalSince1970: 0))
        let ctx2 = BASFrameContext(
            hostID: "bob", taskTypeRaw: "t", runModeRaw: "m",
            recordedAt: Date(timeIntervalSince1970: 0))
        XCTAssertNotEqual(ctx1.sessionID, ctx2.sessionID)
    }

    // MARK: - Anti-magic-number constants (2)

    func testSessionIDSeparatorPinned() {
        XCTAssertEqual(
            BASFrameContext.sessionIDSeparator, "|",
            "M953:sessionID separator pinned;drift detection")
    }

    func testTurnIDSeparatorPinned() {
        XCTAssertEqual(
            BASFrameContext.turnIDSeparator, "#",
            "M953:turnID separator pinned;drift detection")
    }

    // MARK: - Convenience accessors (3)

    func testRecordedAtMsAccessor() {
        let ctx = BASFrameContext(
            sessionID: "s",
            turnID: "t",
            emittedAt: Date(
                timeIntervalSince1970: 1_700_000_000.5))
        XCTAssertEqual(
            ctx.recordedAtMs,
            1_700_000_000_500)
    }

    func testRecordedAtTimeIntervalSinceReferenceDateAccessor() {
        let ctx = BASFrameContext(
            sessionID: "s", turnID: "t",
            emittedAt: Date(
                timeIntervalSinceReferenceDate: 42.5))
        XCTAssertEqual(
            ctx.recordedAtTimeIntervalSinceReferenceDate,
            42.5)
    }

    func testRecordedAtAccessorMatchesEmittedAt() {
        let date = Date(timeIntervalSince1970: 12345.5)
        let ctx = BASFrameContext(
            sessionID: "s", turnID: "t", emittedAt: date)
        XCTAssertEqual(ctx.emittedAt, date)
    }
}
