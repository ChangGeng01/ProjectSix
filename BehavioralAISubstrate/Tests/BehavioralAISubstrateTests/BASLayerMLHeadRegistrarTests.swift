// MARK: - BASLayerMLHeadRegistrarTests — chapter 三百四八 / M835
//
// Phase F (附录 X) 第十六刀 测试覆盖:typed registrar value
// type that dedupes the registration ritual between
// `BAS14LayerMeshAssembler` (chapter 三百一七) and
// `BASChengluMeshRegistration` (chapter 三百二一)。
//
// Tests verify:
//   - Default-init starts with 0 registered + empty perLayerCounts
//   - `register(...)` increments tally + delegates to registry
//   - `perLayerCountsByRawValue` matches typed dict shape
//   - Tally counts match registry actor's authoritative count
//   - Errors from registry propagate (don't tally on failure)

import XCTest
@testable import BASRuntimeCore

final class BASLayerMLHeadRegistrarTests: XCTestCase {

    // MARK: - Test fixtures

    private func makeStubHead(
        id: String,
        layerPin: BASMotherboardLayer14
    ) -> BASRulesBasedLayerMLHead {
        BASRulesBasedLayerMLHeadFactory
            .makeAlwaysFallthrough(
                headID: id, layerIDPin: layerPin)
    }

    // MARK: - Default state

    func testDefaultRegistrarHasZeroTally() {
        let registrar = BASLayerMLHeadRegistrar()
        XCTAssertEqual(
            registrar.registeredHeadCount, 0,
            "Fresh registrar must start at 0 registered")
        XCTAssertTrue(
            registrar.perLayerCounts.isEmpty,
            "Fresh registrar must start with empty " +
            "perLayerCounts dict")
        XCTAssertTrue(
            registrar.perLayerCountsByRawValue.isEmpty,
            "Fresh registrar's String-keyed view must " +
            "also start empty")
    }

    // MARK: - Single registration

    func testRegisterOnceUpdatesTally() async throws {
        let registry = BASLayerMLHeadRegistry()
        var registrar = BASLayerMLHeadRegistrar()
        let head = makeStubHead(
            id: "registrar-test-l4-stub",
            layerPin: .l4)

        try await registrar.register(
            head: head,
            into: registry,
            layerID: .l4,
            priority: BAS14LayerMeshMap.rulesTierPriority)

        XCTAssertEqual(
            registrar.registeredHeadCount, 1)
        XCTAssertEqual(
            registrar.perLayerCounts[.l4], 1)
        XCTAssertEqual(
            registrar.perLayerCountsByRawValue["l4"], 1)
        // Cross-check: registry actor reflects the same count
        let total = await registry.totalHeadCount
        XCTAssertEqual(total, 1)
    }

    // MARK: - Multiple registrations

    func testMultipleRegistrationsAggregatePerLayer()
        async throws
    {
        let registry = BASLayerMLHeadRegistry()
        var registrar = BASLayerMLHeadRegistrar()

        // 2 heads at l4, 1 at l11, 0 at l8
        try await registrar.register(
            head: makeStubHead(
                id: "l4-stub-1", layerPin: .l4),
            into: registry,
            layerID: .l4,
            priority: 0)
        try await registrar.register(
            head: makeStubHead(
                id: "l4-stub-2", layerPin: .l4),
            into: registry,
            layerID: .l4,
            priority: 1)
        try await registrar.register(
            head: makeStubHead(
                id: "l11-stub", layerPin: .l11),
            into: registry,
            layerID: .l11,
            priority: 0)

        XCTAssertEqual(
            registrar.registeredHeadCount, 3,
            "Total tally must equal 3 successful registrations")
        XCTAssertEqual(registrar.perLayerCounts[.l4], 2)
        XCTAssertEqual(registrar.perLayerCounts[.l11], 1)
        XCTAssertNil(registrar.perLayerCounts[.l8],
            "Layers without registrations must be absent " +
            "from perLayerCounts (sparse map invariant)")
    }

    // MARK: - Error propagation

    /// Registry rejects duplicate headIDs。Registrar must
    /// propagate the error WITHOUT tallying — the failed
    /// registration didn't happen,so the count stays accurate。
    func testDuplicateHeadIDDoesNotTally() async throws {
        let registry = BASLayerMLHeadRegistry()
        var registrar = BASLayerMLHeadRegistrar()
        let head = makeStubHead(
            id: "dup-id-stub", layerPin: .l4)

        try await registrar.register(
            head: head,
            into: registry,
            layerID: .l4,
            priority: 0)
        XCTAssertEqual(registrar.registeredHeadCount, 1)

        // Try to register a different head with the SAME ID
        let dupHead = makeStubHead(
            id: "dup-id-stub", layerPin: .l8)
        do {
            try await registrar.register(
                head: dupHead,
                into: registry,
                layerID: .l8,
                priority: 0)
            XCTFail(
                "Duplicate headID must throw " +
                "BASLayerMLHeadRegistrationError.duplicateHeadID")
        } catch BASLayerMLHeadRegistrationError
            .duplicateHeadID(let id)
        {
            XCTAssertEqual(id, "dup-id-stub")
        }

        // Tally must NOT have incremented for the failed
        // registration — accuracy invariant
        XCTAssertEqual(
            registrar.registeredHeadCount, 1,
            "Failed registration must not increment tally — " +
            "the head wasn't actually registered")
        XCTAssertEqual(registrar.perLayerCounts[.l4], 1)
        XCTAssertNil(registrar.perLayerCounts[.l8],
            "Failed l8 registration must not appear in " +
            "perLayerCounts")
    }

    // MARK: - perLayerCountsByRawValue conversion

    func testPerLayerCountsByRawValueMatchesTypedDict()
        async throws
    {
        let registry = BASLayerMLHeadRegistry()
        var registrar = BASLayerMLHeadRegistrar()

        try await registrar.register(
            head: makeStubHead(
                id: "raw-test-l1", layerPin: .l1),
            into: registry,
            layerID: .l1,
            priority: 0)
        try await registrar.register(
            head: makeStubHead(
                id: "raw-test-l11", layerPin: .l11),
            into: registry,
            layerID: .l11,
            priority: 0)

        let typedDict = registrar.perLayerCounts
        let rawDict = registrar.perLayerCountsByRawValue

        XCTAssertEqual(typedDict.count, rawDict.count,
            "Typed and raw-keyed dicts must have same size")
        XCTAssertEqual(rawDict["l1"], typedDict[.l1])
        XCTAssertEqual(rawDict["l11"], typedDict[.l11])
    }

    // MARK: - Sendable conformance pin

    /// `BASLayerMLHeadRegistrar` is declared Sendable so it can
    /// be passed across actor boundaries (e.g. from a host's
    /// nonisolated assembly path into actor-isolated registry
    /// methods)。Compile-time pin: the bind-to-Sendable check
    /// fails to compile if the conformance regresses。
    func testRegistrarIsSendable() {
        let registrar = BASLayerMLHeadRegistrar()
        let _: any Sendable = registrar
    }
}
