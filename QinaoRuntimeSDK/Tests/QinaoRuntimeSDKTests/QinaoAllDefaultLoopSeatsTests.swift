import XCTest
@testable import QinaoSeats
@testable import QinaoLoopSeats
@testable import QinaoLoop

/// M308 — pin the `allDefaultLoopSeats(loop:)` one-call factory.
///
/// Pre-M308 hosts wanting all 9 default seats had to compose two
/// factories (`standardLoopSeats(loop:)` for 6 seats +
/// `adapterBoundSeats(loop:)` for 3 seats) and merge two
/// registries by hand. M308 folds them into one factory so the
/// "first-day integration" path is a single `await`.
///
/// What this file pins:
///
///   1. `allDefaultLoopSeats(loop:)` returns a registry with
///      exactly all 9 manifest v2 seats — none missing, none
///      duplicated.
///   2. The registered seats are in canonical ASC order on
///      lookup (registry semantics, not factory order).
///   3. Existing factories (`standardLoopSeats` / `adapterBound
///      Seats`) still work and produce 6 / 3 seat splits — the
///      new factory is additive, not a replacement.
///   4. Calling the factory twice is idempotent (last-write-wins
///      replaces 9 seats with 9 fresh instances).
final class QinaoAllDefaultLoopSeatsTests: XCTestCase {

    /// 1. `allDefaultLoopSeats(loop:)` registers exactly 9 seats
    ///    matching the manifest v2 enum cardinality.
    func testAllDefaultLoopSeatsRegistersAllNine() async {
        let loop = QinaoLoop(organEndpoint: StubEndpoint())
        let registry = await QinaoSeatRegistry
            .allDefaultLoopSeats(loop: loop)
        let seats = await registry.registeredSeats()
        XCTAssertEqual(
            seats.count, 9,
            "manifest v2 第八节 — exactly 9 seats")
        // Set comparison so order doesn't pin the test
        // (registry orders by raw-value ASC — pinned in test 2).
        XCTAssertEqual(
            Set(seats), Set(QinaoSeat.allCases),
            "every QinaoSeat case must be registered")
    }

    /// 2. Registry returns seats in raw-value ASC order regardless
    ///    of register sequence (registry contract from M292.2).
    func testRegisteredSeatsAreSortedAscByRawValue() async {
        let loop = QinaoLoop(organEndpoint: StubEndpoint())
        let registry = await QinaoSeatRegistry
            .allDefaultLoopSeats(loop: loop)
        let seats = await registry.registeredSeats()
        let rawValues = seats.map(\.rawValue)
        let sorted = rawValues.sorted()
        XCTAssertEqual(
            rawValues, sorted,
            "registry must return seats in raw-value ASC order")
    }

    /// 3a. `standardLoopSeats` still ships exactly 6 seats so
    ///     existing M292.5 + M292.6a callers keep their split.
    func testStandardLoopSeatsStillRegistersSix() async {
        let loop = QinaoLoop(organEndpoint: StubEndpoint())
        let registry = await QinaoSeatRegistry
            .standardLoopSeats(loop: loop)
        let seats = await registry.registeredSeats()
        XCTAssertEqual(seats.count, 6)
        let standard: Set<QinaoSeat> = [
            .scout, .critic, .risk, .planner,
            .surface, .sovereignSentinel,
        ]
        XCTAssertEqual(Set(seats), standard)
    }

    /// 3b. `adapterBoundSeats` still ships exactly 3 seats so
    ///     existing M292.6d callers keep their split.
    func testAdapterBoundSeatsStillRegistersThree() async {
        let loop = QinaoLoop(organEndpoint: StubEndpoint())
        let registry = await QinaoSeatRegistry
            .adapterBoundSeats(loop: loop)
        let seats = await registry.registeredSeats()
        XCTAssertEqual(seats.count, 3)
        let adapterBound: Set<QinaoSeat> = [
            .memory, .hostAlignment, .evolutionShadow,
        ]
        XCTAssertEqual(Set(seats), adapterBound)
    }

    /// 3c. Standard ∪ adapter-bound = all 9 (no gaps, no overlap).
    ///     Pin the doctrine that the two existing factories
    ///     partition the 9 seats exactly — the new
    ///     `allDefaultLoopSeats` is just their union.
    func testStandardAndAdapterBoundPartitionAllNine() {
        let standard: Set<QinaoSeat> = [
            .scout, .critic, .risk, .planner,
            .surface, .sovereignSentinel,
        ]
        let adapterBound: Set<QinaoSeat> = [
            .memory, .hostAlignment, .evolutionShadow,
        ]
        XCTAssertTrue(
            standard.isDisjoint(with: adapterBound),
            "standard and adapter-bound must not overlap")
        XCTAssertEqual(
            standard.union(adapterBound),
            Set(QinaoSeat.allCases),
            "standard ∪ adapter-bound must equal all 9 seats")
    }

    /// 4. Calling `allDefaultLoopSeats(loop:)` twice produces
    ///    registries that each carry all 9 — last-write-wins
    ///    semantics confirmed (no leakage between instances).
    func testAllDefaultLoopSeatsIsIdempotentAcrossInstances()
        async
    {
        let loop = QinaoLoop(organEndpoint: StubEndpoint())
        let r1 = await QinaoSeatRegistry
            .allDefaultLoopSeats(loop: loop)
        let r2 = await QinaoSeatRegistry
            .allDefaultLoopSeats(loop: loop)
        let seats1 = await r1.registeredSeats()
        let seats2 = await r2.registeredSeats()
        XCTAssertEqual(seats1.count, 9)
        XCTAssertEqual(seats2.count, 9)
        XCTAssertEqual(seats1, seats2)
    }
}

/// Minimal stub endpoint for tests. Default seats only need a
/// `QinaoLoop` to construct against; their `contribute(snapshotID:)`
/// methods are not exercised here (M308 only pins registration
/// shape, not seat behaviour — that's M292.5 / M292.6a / M292.6d
/// territory). Same shape as `InertEndpoint` in
/// `QinaoDefaultsTests` so existing test conventions are reused.
private actor StubEndpoint: QinaoOrganEndpoint {
    func produceBody(
        prompt _: String,
        context _: [String],
        role _: QinaoLoop.OrganRole,
        sessionID _: String
    ) async throws -> QinaoLoop.OrganResponse {
        QinaoLoop.OrganResponse(
            body: "",
            providerID: "stub",
            traceID: "stub")
    }
}
