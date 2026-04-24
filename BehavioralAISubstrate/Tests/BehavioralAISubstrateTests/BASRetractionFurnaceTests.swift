import XCTest
@testable import BASMemory
@testable import BASRuntimeCore

/// M94 — Unit tests for `BASRetractionFurnace` schema + queue
/// walker surface.
///
/// Coverage:
/// 1. Enum raw values stable
/// 2. isTerminal semantics
/// 3. Init trims whitespace
/// 4. Codable round-trip
/// 5. enqueue returns new furnace
/// 6. markInFlight / markCompleted / markFailed / markSkipped
///    lifecycle guards
/// 7. Transitions refuse re-entry into terminal states
/// 8. Query APIs: pending / inFlight / finished / entries(forTarget:)
final class BASRetractionFurnaceTests: XCTestCase {

    // MARK: - Helpers

    private let t0 = Date(timeIntervalSince1970: 0)
    private let t1 = Date(timeIntervalSince1970: 100)
    private let t2 = Date(timeIntervalSince1970: 200)

    private func makeEntry(
        orderID: String,
        targetRefs: [String] = [],
        cascadeRefs: [String] = [],
        state: BASRetractionExecutionState = .queued,
        enqueuedAt: Date? = nil
    ) -> BASRetractionFurnaceEntry {
        BASRetractionFurnaceEntry(
            orderID: orderID,
            targetRefs: targetRefs,
            cascadeRefs: cascadeRefs,
            reasonCodes: [],
            state: state,
            enqueuedAt: enqueuedAt ?? t0)
    }

    // MARK: - 1. Enum raw values stable

    func testExecutionStateRawValuesAreStable() {
        XCTAssertEqual(
            BASRetractionExecutionState.queued.rawValue,
            "queued")
        XCTAssertEqual(
            BASRetractionExecutionState.inFlight.rawValue,
            "in-flight")
        XCTAssertEqual(
            BASRetractionExecutionState.completed.rawValue,
            "completed")
        XCTAssertEqual(
            BASRetractionExecutionState.failed.rawValue,
            "failed")
        XCTAssertEqual(
            BASRetractionExecutionState.skipped.rawValue,
            "skipped")
    }

    // MARK: - 2. isTerminal semantics

    func testIsTerminalFlagsTerminalStates() {
        XCTAssertFalse(BASRetractionExecutionState.queued.isTerminal)
        XCTAssertFalse(
            BASRetractionExecutionState.inFlight.isTerminal)
        XCTAssertTrue(
            BASRetractionExecutionState.completed.isTerminal)
        XCTAssertTrue(
            BASRetractionExecutionState.failed.isTerminal)
        XCTAssertTrue(
            BASRetractionExecutionState.skipped.isTerminal)
    }

    // MARK: - 3. Init trims

    func testEntryInitTrimsOrderID() {
        let e = BASRetractionFurnaceEntry(
            orderID: "  order-1  ",
            enqueuedAt: t0)
        XCTAssertEqual(e.orderID, "order-1")
    }

    func testFurnaceInitTrimsID() {
        let f = BASRetractionFurnace(furnaceID: "  furnace-1  ")
        XCTAssertEqual(f.furnaceID, "furnace-1")
    }

    // MARK: - 4. Codable round-trip

    func testCodableRoundTripPreservesAllFields() throws {
        let original = BASRetractionFurnace(
            furnaceID: "furnace-rt",
            entries: [
                BASRetractionFurnaceEntry(
                    orderID: "o1",
                    targetRefs: ["v1", "v2"],
                    cascadeRefs: ["v3"],
                    reasonCodes: ["host-rejected"],
                    state: .inFlight,
                    enqueuedAt: t0,
                    startedAt: t1),
                BASRetractionFurnaceEntry(
                    orderID: "o2",
                    targetRefs: ["v4"],
                    state: .failed,
                    enqueuedAt: t0,
                    startedAt: t1,
                    finishedAt: t2,
                    failureReason: "network-fail"),
            ])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASRetractionFurnace.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - 5. Enqueue is pure

    func testEnqueueReturnsNewFurnace() {
        let f = BASRetractionFurnace(furnaceID: "f")
        let g = f.enqueue(makeEntry(orderID: "o1"))
        XCTAssertEqual(f.entries.count, 0, "original unchanged")
        XCTAssertEqual(g.entries.count, 1)
        XCTAssertEqual(g.entries.first?.orderID, "o1")
    }

    // MARK: - 6. Lifecycle transitions

    func testMarkInFlightMovesQueuedToInFlight() {
        let f = BASRetractionFurnace(furnaceID: "f")
            .enqueue(makeEntry(orderID: "o1"))
            .markInFlight(orderID: "o1", at: t1)
        let e = f.entry(orderID: "o1")
        XCTAssertEqual(e?.state, .inFlight)
        XCTAssertEqual(e?.startedAt, t1)
    }

    func testMarkCompletedMovesInFlightToCompleted() {
        let f = BASRetractionFurnace(furnaceID: "f")
            .enqueue(makeEntry(orderID: "o1"))
            .markInFlight(orderID: "o1", at: t1)
            .markCompleted(orderID: "o1", at: t2)
        let e = f.entry(orderID: "o1")
        XCTAssertEqual(e?.state, .completed)
        XCTAssertEqual(e?.finishedAt, t2)
    }

    func testMarkFailedStoresReason() {
        let f = BASRetractionFurnace(furnaceID: "f")
            .enqueue(makeEntry(orderID: "o1"))
            .markInFlight(orderID: "o1", at: t1)
            .markFailed(
                orderID: "o1",
                reason: "  boundary-violation  ",
                at: t2)
        let e = f.entry(orderID: "o1")
        XCTAssertEqual(e?.state, .failed)
        XCTAssertEqual(e?.finishedAt, t2)
        XCTAssertEqual(e?.failureReason, "boundary-violation")
    }

    func testMarkSkippedClearsFailureReason() {
        let f = BASRetractionFurnace(furnaceID: "f")
            .enqueue(makeEntry(orderID: "o1"))
            .markSkipped(orderID: "o1", at: t1)
        let e = f.entry(orderID: "o1")
        XCTAssertEqual(e?.state, .skipped)
        XCTAssertNil(e?.failureReason)
    }

    // MARK: - 7. Terminal re-entry refused

    func testMarkCompletedFromTerminalIsNoOp() {
        // A completed entry should not be overwritten by another
        // transition call.
        let f = BASRetractionFurnace(furnaceID: "f")
            .enqueue(makeEntry(orderID: "o1"))
            .markInFlight(orderID: "o1", at: t1)
            .markCompleted(orderID: "o1", at: t2)
            // Try to fail a completed order — must be no-op.
            .markFailed(orderID: "o1", reason: "late", at: t2)
        let e = f.entry(orderID: "o1")
        XCTAssertEqual(e?.state, .completed)
        XCTAssertNil(e?.failureReason,
                     "terminal state cannot pick up new reason")
    }

    func testMarkInFlightFromInFlightIsNoOp() {
        // markInFlight requires .queued as the starting state.
        let f = BASRetractionFurnace(furnaceID: "f")
            .enqueue(makeEntry(orderID: "o1"))
            .markInFlight(orderID: "o1", at: t1)
            .markInFlight(orderID: "o1", at: t2)
        let e = f.entry(orderID: "o1")
        XCTAssertEqual(e?.startedAt, t1,
                       "second markInFlight must not overwrite")
    }

    func testMarkUnknownOrderIsSilentNoOp() {
        let f = BASRetractionFurnace(furnaceID: "f")
            .markInFlight(orderID: "nonexistent", at: t1)
            .markCompleted(orderID: "nonexistent", at: t1)
        XCTAssertEqual(f.entries.count, 0)
    }

    // MARK: - 8. Query APIs

    func testPendingInFlightFinishedSegmentation() {
        let f = BASRetractionFurnace(furnaceID: "f")
            .enqueue(makeEntry(orderID: "o1"))
            .enqueue(makeEntry(orderID: "o2"))
            .enqueue(makeEntry(orderID: "o3"))
            .enqueue(makeEntry(orderID: "o4"))
            .markInFlight(orderID: "o2", at: t1)
            .markInFlight(orderID: "o3", at: t1)
            .markCompleted(orderID: "o3", at: t2)
            .markSkipped(orderID: "o4", at: t1)

        XCTAssertEqual(f.pending.map(\.orderID), ["o1"])
        XCTAssertEqual(f.inFlight.map(\.orderID), ["o2"])
        XCTAssertEqual(
            Set(f.finished.map(\.orderID)),
            Set(["o3", "o4"]))
    }

    func testEntriesForTargetMatchesTargetAndCascade() {
        let f = BASRetractionFurnace(furnaceID: "f")
            .enqueue(makeEntry(
                orderID: "o1", targetRefs: ["v1"]))
            .enqueue(makeEntry(
                orderID: "o2", cascadeRefs: ["v1"]))
            .enqueue(makeEntry(
                orderID: "o3", targetRefs: ["v2"]))
        let hits = f.entries(forTarget: "v1")
        XCTAssertEqual(
            Set(hits.map(\.orderID)),
            Set(["o1", "o2"]))
    }

    func testEntriesInStateFiltersByLifecycle() {
        let f = BASRetractionFurnace(furnaceID: "f")
            .enqueue(makeEntry(orderID: "o1"))
            .enqueue(makeEntry(orderID: "o2"))
            .markInFlight(orderID: "o1", at: t1)
            .markFailed(orderID: "o1", reason: "x", at: t2)

        XCTAssertEqual(
            f.entries(inState: .failed).map(\.orderID), ["o1"])
        XCTAssertEqual(
            f.entries(inState: .queued).map(\.orderID), ["o2"])
    }
}
