// MARK: - BASHostStorageWireBuilderM947Tests
// chapter 四百二 / M947
//
// Test coverage for Phase 1 第七刀:event-sourced atom store
// opt-in via BASHostStorageOptions + BASHostStorageWireBuilder。
//
// Targets per the M947 plan spec (14 tests):
//   - Defaults preserve legacy behavior (3)
//   - useEventSourcedAtomStore: true returns event-sourced store (2)
//   - Wire reason codes emitted (3)
//   - Bundle field surface (3)
//   - Error propagation from event-log construction (3)

import Foundation
import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASRuntimeCore

final class BASHostStorageWireBuilderM947Tests: XCTestCase {

    // MARK: - Defaults preserve legacy behavior (3)

    func testLegacyDefaultUseEventSourcedFalse() {
        let opts = BASHostStorageOptions()
        XCTAssertFalse(opts.useEventSourcedAtomStore,
            "M947:default useEventSourcedAtomStore must be false")
    }

    func testLegacyDefaultEventLogURLNil() {
        let opts = BASHostStorageOptions()
        XCTAssertNil(opts.eventLogURL)
        XCTAssertNil(opts.effectiveEventLogURL)
    }

    func testLegacyDefaultMakeAtomStoreReturnsLegacy()
        async throws
    {
        let opts = BASHostStorageOptions()
        let store = try BASHostStorageWireBuilder
            .makeAtomStore(options: opts)
        // Type check: legacy in-memory or SQLite store —
        // NOT BASEventSourcedMemoryAtomStore
        XCTAssertFalse(
            store is BASEventSourcedMemoryAtomStore,
            "M947:default must NOT return event-sourced store")
    }

    // MARK: - useEventSourcedAtomStore: true (2)

    func testEventSourcedFlagTrueReturnsEventSourcedStore()
        async throws
    {
        let opts = BASHostStorageOptions(
            useEventSourcedAtomStore: true)
        let store = try BASHostStorageWireBuilder
            .makeAtomStore(
                options: opts,
                eventSourcedSessionID: "test-sess")
        XCTAssertTrue(
            store is BASEventSourcedMemoryAtomStore,
            "M947:useEventSourcedAtomStore:true returns event-sourced")
    }

    func testEventSourcedDefaultUsesInMemoryEventLog()
        async throws
    {
        // No eventLogURL + .inMemoryDefault → in-memory event log
        let opts = BASHostStorageOptions(
            useEventSourcedAtomStore: true)
        let log = try BASHostStorageWireBuilder.makeEventLog(
            options: opts)
        XCTAssertTrue(log is BASInMemoryEventLogStorage)
    }

    // MARK: - Wire reason codes emitted (3)

    func testEventLogWireReasonCodesIncludeFlag() {
        let opts = BASHostStorageOptions(
            useEventSourcedAtomStore: true)
        let codes = BASHostStorageWireBuilder
            .eventLogWireReasonCodes(options: opts)
        XCTAssertTrue(
            codes.contains(
                "event-sourced-atom-store:enabled"),
            "M947:reason code must reflect event-sourced flag")
    }

    func testEventLogWireReasonCodesDisabledByDefault() {
        let opts = BASHostStorageOptions()
        let codes = BASHostStorageWireBuilder
            .eventLogWireReasonCodes(options: opts)
        XCTAssertTrue(
            codes.contains(
                "event-sourced-atom-store:disabled"))
    }

    func testEventLogWireReasonCodesIncludePreference() {
        let opts = BASHostStorageOptions(
            preference: .sqliteWhenURLProvided)
        let codes = BASHostStorageWireBuilder
            .eventLogWireReasonCodes(options: opts)
        XCTAssertTrue(
            codes.contains {
                $0.contains("sqlite-when-url-provided")
            })
    }

    // MARK: - Bundle field surface (3)

    func testBundleEventLogNilByDefault() async throws {
        let opts = BASHostStorageOptions()
        let bundle = try await BASHostStorageWireBuilder
            .makeBundle(options: opts)
        XCTAssertNil(bundle.eventLog,
            "M947:legacy bundle has no event log")
    }

    func testBundleEventLogPresentWhenFlagOn() async throws {
        let opts = BASHostStorageOptions(
            useEventSourcedAtomStore: true)
        let bundle = try await BASHostStorageWireBuilder
            .makeBundle(options: opts)
        XCTAssertNotNil(bundle.eventLog,
            "M947:event-sourced bundle exposes event log")
        XCTAssertTrue(
            bundle.atomStore
                is BASEventSourcedMemoryAtomStore)
    }

    func testBundleEventLogIsSharedWithAtomStore()
        async throws
    {
        // Atom store + bundle.eventLog should share the same
        // log instance — not two parallel logs。Verify via
        // appending an event through the store and reading it
        // out via the bundle's eventLog reference。
        let opts = BASHostStorageOptions(
            useEventSourcedAtomStore: true)
        let bundle = try await BASHostStorageWireBuilder
            .makeBundle(
                options: opts,
                eventSourcedSessionID: "shared")
        guard let evStore = bundle.atomStore
            as? BASEventSourcedMemoryAtomStore else {
            XCTFail("Expected event-sourced store")
            return
        }
        let atom = BASGovernedMemory(
            id: UUID(uuidString:
                "00000000-0000-4000-8000-000000000007")!,
            kind: .semantic,
            content: "x",
            scope: .user,
            sensitivity: .low,
            tier: .warm,
            confidence: 0.5,
            sourceType: "src",
            lastConfirmedAt: nil,
            decayScore: 0.0,
            governanceStatus: .governed,
            provenanceSummary: "p")
        try await evStore.admit(atom)
        let bundleEvents = await bundle.eventLog!.events(
            forSession: "shared")
        XCTAssertEqual(bundleEvents.count, 1,
            "M947:bundle.eventLog must share with atomStore")
    }

    // MARK: - Error propagation (3)

    func testSqliteRequiredMissingEventLogURLThrows() {
        let opts = BASHostStorageOptions(
            preference: .sqliteRequired)
        XCTAssertThrowsError(
            try BASHostStorageWireBuilder.makeEventLog(
                options: opts)
        ) { error in
            guard let we = error as?
                BASHostStorageWireError else {
                XCTFail("wrong error type")
                return
            }
            switch we {
            case .missingSQLiteURL(let component):
                XCTAssertEqual(component, "event-log")
            default:
                XCTFail("wrong case")
            }
        }
    }

    func testEventSourcedAtomStoreRequiringSQLiteThrowsWithoutURL() {
        let opts = BASHostStorageOptions(
            preference: .sqliteRequired,
            useEventSourcedAtomStore: true)
        XCTAssertThrowsError(
            try BASHostStorageWireBuilder.makeAtomStore(
                options: opts)
        ) { error in
            // The error originates from makeEventLog
            // (event-sourced path requires event log) which
            // throws .missingSQLiteURL(component: "event-log")
            guard let we = error as?
                BASHostStorageWireError else {
                XCTFail("wrong error type")
                return
            }
            switch we {
            case .missingSQLiteURL(let component):
                XCTAssertEqual(component, "event-log")
            default:
                XCTFail("wrong case")
            }
        }
    }

    func testSqliteWhenURLProvidedFallsBackToInMemory()
        async throws
    {
        // sqliteWhenURLProvided + nil URL → in-memory event log
        // (not error)
        let opts = BASHostStorageOptions(
            preference: .sqliteWhenURLProvided,
            useEventSourcedAtomStore: true)
        let log = try BASHostStorageWireBuilder
            .makeEventLog(options: opts)
        XCTAssertTrue(log is BASInMemoryEventLogStorage)
    }
}
