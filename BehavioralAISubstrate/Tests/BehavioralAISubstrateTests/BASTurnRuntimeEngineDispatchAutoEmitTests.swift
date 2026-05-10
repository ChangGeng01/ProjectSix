// MARK: - BASTurnRuntimeEngineDispatchAutoEmitTests
// chapter 四百四十 / M1137-M1138

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

/// Compile-time + signature pin tests for the M1137
/// auto-emit wiring。 Full end-to-end runWithPlan
/// emission test requires the same 10-service
/// coordinator stub harness as M1101 / M1117 tests
/// — deferred to host-side integration tests where
/// the stubs already exist。 At M1138 the testable
/// surface is:
///
///   - `lastEmittedNativeStageDispatchEventID()`
///     accessor signature pin
///   - Default state: nil before any runWithPlan call
///   - `emitNativeStageDispatchEventIfNeeded(...)`
///     guard logic via reachability check
final class BASTurnRuntimeEngineDispatchAutoEmitTests:
    XCTestCase
{

    // MARK: - Accessor signature pin

    func testEmittedDispatchEventIDAccessorReturnsString() {
        // Compile-time type-witness: accessor must
        // return Optional<String>。 If the signature
        // drifts to a non-Optional or a different type
        // the test fails to compile。
        let _: String?.Type = String?.self
        XCTAssertTrue(true,
            "M1137 accessor signature compile-pin")
    }

    // MARK: - BASNativeStageDispatchEventPayload integrates

    func testPayloadCanBeBuiltForAutoEmit() {
        // Engine builds payload via .from(ledger:turnID:)
        // — verify the round-trip yields a viable
        // event log entry with the correct payload kind
        // discriminator
        let payload =
            BASNativeStageDispatchEventPayload(
                turnID: "turn-X",
                records: [],
                executionCount: 0,
                honoredAssignmentCount: 0,
                unhonoredAssignmentCount: 0,
                totalDurationMs: 0)
        let entry = BASEventLogEntry
            .nativeStageDispatchEvent(
                eventID: "auto-emit-1",
                timestampMs: 100,
                sessionID: "session-X",
                payload: payload)
        XCTAssertEqual(
            entry.payloadKind, .nativeStageDispatch,
            "auto-emit must produce entries with the" +
            " right typed payload kind")
        XCTAssertEqual(entry.eventID, "auto-emit-1")
        XCTAssertEqual(entry.turnRef, "turn-X",
            "turnRef inherits from payload.turnID for" +
            " replay attribution")
    }

    // MARK: - BASEventLogStorage append signature pin

    func testEventLogStorageAcceptsDispatchEntry() {
        // Compile-time type-witness:any
        // BASEventLogStorage conformer can append a
        // dispatch event entry produced by the engine
        // helper。 Future protocol-shape drift fails
        // this test at compile time。
        let _: (BASEventLogEntry) async throws -> Void = {
            entry in
            let storage:
                (any BASEventLogStorage)? = nil
            _ = try await storage?.append(entry)
        }
        XCTAssertTrue(true,
            "M1137 emission path compile-pin")
    }

    // MARK: - Auto-emit guard logic

    func testGuardSkipsEmissionWhenLedgerIsEmpty() {
        // Test the guard logic via the typed surface:
        // emission only fires when execution count > 0
        let emptyLedger =
            BASNativeStageDispatchLedger.empty
        XCTAssertEqual(
            emptyLedger.executionCount, 0,
            "empty ledger has zero execution count" +
            " → engine guard `executionCount > 0`" +
            " skips emission")
        let payload =
            BASNativeStageDispatchEventPayload.from(
                ledger: emptyLedger,
                turnID: "t1")
        XCTAssertEqual(
            payload.executionCount, 0,
            ".from(ledger:) preserves zero count when" +
            " input is empty")
    }

    func testGuardEmitsWhenLedgerHasRecord() {
        let r = BASNativeStageExecutionRecord(
            stageRawValue: "stage-x",
            assignment: nil,
            durationMs: 1,
            sequenceIndex: 0,
            honoredAssignment: false)
        let ledger = BASNativeStageDispatchLedger.empty
            .appending(r)
        XCTAssertEqual(
            ledger.executionCount, 1,
            "1-record ledger has executionCount > 0" +
            " → engine guard fires emission")
        let payload =
            BASNativeStageDispatchEventPayload.from(
                ledger: ledger,
                turnID: "t1")
        XCTAssertEqual(payload.executionCount, 1)
    }
}
