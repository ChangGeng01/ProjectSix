// MARK: - BASLayerMLHeadRegistryTests — chapter 三百一〇 / M797
//
// Phase Delta 第一刀 测试覆盖:typed slot registry actor。

import XCTest
@testable import BASRuntimeCore

final class BASLayerMLHeadRegistryTests: XCTestCase {

    // MARK: - Stub head

    private struct StubHead: BASLayerMLHead {
        let headID: String
        let kind: BASLayerMLHeadKind

        func infer(
            input: BASLayerInferenceInput
        ) async throws -> BASLayerInferenceOutput {
            BASLayerInferenceOutput(
                layerID: input.layerID,
                confidence: .high,
                reasonCodes: ["stub:processed"],
                inferenceLatencyMs: 0.5)
        }
    }

    // MARK: - Slot record

    func testSlotDefaultSchemaVersion() {
        let slot = BASLayerMLHeadSlot(
            layerID: .l11,
            headID: "h-1",
            kind: .rules,
            priority: 0)
        XCTAssertEqual(slot.schemaVersion, "1.0.0")
        XCTAssertTrue(slot.enabled)
    }

    func testSlotTrimsHeadID() {
        let slot = BASLayerMLHeadSlot(
            layerID: .l4,
            headID: "  trimmed  ",
            kind: .rules,
            priority: 0)
        XCTAssertEqual(slot.headID, "trimmed")
    }

    func testSlotCodableRoundTrip() throws {
        let slot = BASLayerMLHeadSlot(
            layerID: .l9,
            headID: "rt-head",
            kind: .coremlOnDevice,
            priority: 10,
            enabled: false)
        let data = try JSONEncoder().encode(slot)
        let decoded = try JSONDecoder().decode(
            BASLayerMLHeadSlot.self, from: data)
        XCTAssertEqual(decoded, slot)
    }

    // MARK: - Empty registry

    func testEmptyRegistryHasZeroHeads() async {
        let registry = BASLayerMLHeadRegistry()
        let count = await registry.totalHeadCount
        XCTAssertEqual(count, 0)
    }

    func testEmptyRegistryReturnsEmptySlotsForAnyLayer() async {
        let registry = BASLayerMLHeadRegistry()
        for layer in BASMotherboardLayer14.allCases {
            let slots = await registry.slots(forLayer: layer)
            XCTAssertTrue(slots.isEmpty)
        }
    }

    // MARK: - Registration

    func testRegisterIncrementsTotalCount() async throws {
        let registry = BASLayerMLHeadRegistry()
        let head = StubHead(headID: "h-1", kind: .rules)
        try await registry.register(
            head: head, layerID: .l4, priority: 0)
        let count = await registry.totalHeadCount
        XCTAssertEqual(count, 1)
    }

    func testRegisterDuplicateHeadIDThrows() async {
        let registry = BASLayerMLHeadRegistry()
        let head1 = StubHead(headID: "dup", kind: .rules)
        let head2 = StubHead(
            headID: "dup", kind: .coremlOnDevice)
        do {
            try await registry.register(
                head: head1, layerID: .l4, priority: 0)
            try await registry.register(
                head: head2, layerID: .l11, priority: 5)
            XCTFail("expected duplicate to throw")
        } catch let error as BASLayerMLHeadRegistrationError {
            XCTAssertEqual(error, .duplicateHeadID("dup"))
        } catch {
            XCTFail("unexpected error type")
        }
    }

    func testSameHeadCanServeDifferentLayersByDistinctID()
        async throws
    {
        // Distinct headIDs let logically-similar heads serve
        // multiple layers.
        let registry = BASLayerMLHeadRegistry()
        let h1 = StubHead(headID: "h.l4", kind: .rules)
        let h2 = StubHead(headID: "h.l11", kind: .rules)
        try await registry.register(
            head: h1, layerID: .l4, priority: 0)
        try await registry.register(
            head: h2, layerID: .l11, priority: 0)
        let count = await registry.totalHeadCount
        XCTAssertEqual(count, 2)
    }

    // MARK: - Priority ordering

    func testSlotsReturnedInPriorityOrder() async throws {
        let registry = BASLayerMLHeadRegistry()
        let h_high = StubHead(
            headID: "h.high", kind: .rules)
        let h_low = StubHead(
            headID: "h.low", kind: .externalProvider)
        let h_mid = StubHead(
            headID: "h.mid", kind: .coremlOnDevice)

        // Register in OUT-OF-ORDER priority
        try await registry.register(
            head: h_low, layerID: .l4, priority: 40)
        try await registry.register(
            head: h_high, layerID: .l4, priority: 0)
        try await registry.register(
            head: h_mid, layerID: .l4, priority: 10)

        let slots = await registry.slots(forLayer: .l4)
        XCTAssertEqual(slots.map(\.headID),
            ["h.high", "h.mid", "h.low"],
            "slots must return in priority order regardless of " +
            "registration order")
    }

    // MARK: - Enabled flag

    func testSetEnabledFiltersInEnabledSlots() async throws {
        let registry = BASLayerMLHeadRegistry()
        let h1 = StubHead(headID: "h.1", kind: .rules)
        let h2 = StubHead(headID: "h.2", kind: .rules)
        try await registry.register(
            head: h1, layerID: .l4, priority: 0)
        try await registry.register(
            head: h2, layerID: .l4, priority: 10)

        // Disable h.2
        try await registry.setEnabled(
            headID: "h.2", enabled: false)

        let allSlots = await registry.slots(forLayer: .l4)
        let enabledSlots = await registry.enabledSlots(
            forLayer: .l4)
        XCTAssertEqual(allSlots.count, 2)
        XCTAssertEqual(enabledSlots.count, 1)
        XCTAssertEqual(enabledSlots.first?.headID, "h.1")
    }

    func testSetEnabledOnUnknownHeadThrows() async {
        let registry = BASLayerMLHeadRegistry()
        do {
            try await registry.setEnabled(
                headID: "nope", enabled: true)
            XCTFail("expected unknownHead throw")
        } catch let error as BASLayerMLHeadRegistrationError {
            XCTAssertEqual(error, .unknownHead(headID: "nope"))
        } catch {
            XCTFail("unexpected error type")
        }
    }

    // MARK: - Unregister

    func testUnregisterRemovesHead() async throws {
        let registry = BASLayerMLHeadRegistry()
        let head = StubHead(headID: "h-x", kind: .rules)
        try await registry.register(
            head: head, layerID: .l4, priority: 0)
        let removed = await registry.unregister(headID: "h-x")
        XCTAssertTrue(removed)
        let count = await registry.totalHeadCount
        XCTAssertEqual(count, 0)
    }

    func testUnregisterReturnsFalseForUnknown() async {
        let registry = BASLayerMLHeadRegistry()
        let removed = await registry.unregister(headID: "ghost")
        XCTAssertFalse(removed)
    }

    // MARK: - enabledHeads pair query

    func testEnabledHeadsReturnsMatchingSlotPairs() async throws {
        let registry = BASLayerMLHeadRegistry()
        let h1 = StubHead(headID: "p.1", kind: .rules)
        let h2 = StubHead(headID: "p.2", kind: .coremlOnDevice)
        try await registry.register(
            head: h1, layerID: .l11, priority: 0)
        try await registry.register(
            head: h2, layerID: .l11, priority: 10)
        let pairs = await registry.enabledHeads(forLayer: .l11)
        XCTAssertEqual(pairs.count, 2)
        XCTAssertEqual(pairs[0].head.headID, "p.1")
        XCTAssertEqual(pairs[0].slot.priority, 0)
        XCTAssertEqual(pairs[1].head.headID, "p.2")
        XCTAssertEqual(pairs[1].slot.priority, 10)
    }

    // MARK: - All slots

    func testAllSlotsOrderedByLayerThenPriority() async throws {
        let registry = BASLayerMLHeadRegistry()
        // Register out of layer order
        try await registry.register(
            head: StubHead(headID: "l11.h", kind: .rules),
            layerID: .l11, priority: 0)
        try await registry.register(
            head: StubHead(headID: "l4.h.lo", kind: .rules),
            layerID: .l4, priority: 0)
        try await registry.register(
            head: StubHead(
                headID: "l4.h.hi", kind: .coremlOnDevice),
            layerID: .l4, priority: 10)

        let all = await registry.allSlots
        // L4 comes before L11 in BASMotherboardLayer14 enum order
        XCTAssertEqual(all.map(\.headID),
            ["l4.h.lo", "l4.h.hi", "l11.h"])
    }

    // MARK: - Head retrieval

    func testHeadByIDReturnsRegisteredHead() async throws {
        let registry = BASLayerMLHeadRegistry()
        let head = StubHead(headID: "lookup", kind: .rules)
        try await registry.register(
            head: head, layerID: .l9, priority: 0)
        let retrieved = try await registry.head(headID: "lookup")
        XCTAssertEqual(retrieved.headID, "lookup")
    }

    func testHeadByIDForDisabledThrows() async throws {
        let registry = BASLayerMLHeadRegistry()
        let head = StubHead(headID: "off", kind: .rules)
        try await registry.register(
            head: head, layerID: .l4, priority: 0)
        try await registry.setEnabled(
            headID: "off", enabled: false)
        do {
            _ = try await registry.head(headID: "off")
            XCTFail("expected disabled throw")
        } catch let error as BASLayerMLHeadRegistrationError {
            XCTAssertEqual(
                error, .headDisabled(headID: "off"))
        } catch {
            XCTFail("unexpected error type")
        }
    }

    func testHeadByIDForUnknownThrows() async {
        let registry = BASLayerMLHeadRegistry()
        do {
            _ = try await registry.head(headID: "ghost")
            XCTFail("expected unknown throw")
        } catch let error as BASLayerMLHeadRegistrationError {
            XCTAssertEqual(
                error, .unknownHead(headID: "ghost"))
        } catch {
            XCTFail("unexpected error type")
        }
    }
}
