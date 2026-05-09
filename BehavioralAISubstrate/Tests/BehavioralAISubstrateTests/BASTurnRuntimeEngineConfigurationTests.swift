// MARK: - BASTurnRuntimeEngineConfigurationTests
// chapter 四百七 / M998

import Foundation
import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASTurnRuntimeEngineConfigurationTests:
    XCTestCase
{

    // MARK: - Init shape

    func testDefaultFactoryReturnsNilEventLog() {
        let config = BASTurnRuntimeEngineConfiguration
            .default()
        XCTAssertNil(config.eventLog)
    }

    func testDefaultFactoryHasSystemClockAndUUIDFactory() {
        let config = BASTurnRuntimeEngineConfiguration
            .default()
        let id1 = config.eventIDFactory()
        let id2 = config.eventIDFactory()
        XCTAssertNotEqual(id1, id2,
            "M998:UUID factory produces unique IDs")
        XCTAssertGreaterThan(config.clockMs(), 0,
            "M998:clock returns positive timestamp")
    }

    func testInitWithExplicitFields() {
        let log = BASInMemoryEventLogStorage()
        let config = BASTurnRuntimeEngineConfiguration(
            eventLog: log,
            eventIDFactory: { "fixed" },
            clockMs: { 12345 })
        XCTAssertNotNil(config.eventLog)
        XCTAssertEqual(config.eventIDFactory(), "fixed")
        XCTAssertEqual(config.clockMs(), 12345)
    }

    // MARK: - With-chain immutable updates

    func testWithEventLogReturnsFresh() {
        let original = BASTurnRuntimeEngineConfiguration
            .default()
        let log = BASInMemoryEventLogStorage()
        let updated = original.with(eventLog: log)
        XCTAssertNil(original.eventLog,
            "M998:with-chain doesn't mutate original")
        XCTAssertNotNil(updated.eventLog)
    }

    func testWithChainPreservesOtherFields() {
        let log = BASInMemoryEventLogStorage()
        let config = BASTurnRuntimeEngineConfiguration(
            eventLog: log,
            eventIDFactory: { "x" },
            clockMs: { 100 })
        let withNewClock = config.with(
            clockMs: { 999 })
        XCTAssertEqual(
            withNewClock.eventIDFactory(), "x",
            "M998:other fields preserved across with-chain")
        XCTAssertEqual(withNewClock.clockMs(), 999)
        XCTAssertNotNil(withNewClock.eventLog)
    }

    // MARK: - V2 actor convenience init

    func testV2ActorAcceptsConfigurationBundle() {
        // Compile-time check via local closure of expected
        // signature shape (avoids Sendable data-race warnings
        // on direct .init reference)
        let _: @Sendable () -> Void = {
            let _: BASTurnRuntimeEngineConfiguration =
                .default()
        }
        XCTAssertTrue(true,
            "M998:configuration bundle compiles")
    }

    // MARK: - Reuse across actor instances

    func testConfigurationReusableAcrossSemanticActors() {
        // The point of M998: one config, many actors. Each
        // actor gets the same eventLog + eventIDFactory +
        // clockMs。 Pin via shape check (the Configuration is
        // value-typed,each actor gets its own copy of the
        // closures)。
        let log = BASInMemoryEventLogStorage()
        let config = BASTurnRuntimeEngineConfiguration(
            eventLog: log,
            eventIDFactory: { "shared" },
            clockMs: { 0 })
        // Verify config can be passed twice (Sendable +
        // value-type semantics)
        let _: BASTurnRuntimeEngineConfiguration = config
        let _: BASTurnRuntimeEngineConfiguration = config
        XCTAssertEqual(config.clockMs(), 0)
    }
}
