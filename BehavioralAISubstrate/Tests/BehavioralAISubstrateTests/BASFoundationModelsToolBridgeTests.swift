// MARK: - BASFoundationModelsToolBridgeTests — chapter 四百 / M916

import XCTest
@testable import BASOrgan
@testable import BASRuntimeCore

final class BASFoundationModelsToolBridgeTests: XCTestCase {

    // MARK: - Audit-mode pin (M870 suffix)

    func testAuditTraceSuffixIsM870StablePin() {
        // Pin the exact string downstream parsers grep for。
        // A change here is a SCHEMA-class break and must be
        // explicit。
        XCTAssertEqual(
            BASFoundationModelsToolBridge.auditTraceSuffix,
            "#afm-tools-dropped-no-sdk-bridge")
    }

    func testIsAuditedTraceIDDetectsSuffix() {
        XCTAssertTrue(
            BASFoundationModelsToolBridge.isAuditedTraceID(
                "abc123#afm-tools-dropped-no-sdk-bridge"))
        XCTAssertFalse(
            BASFoundationModelsToolBridge.isAuditedTraceID(
                "plain-trace-id"))
        XCTAssertFalse(
            BASFoundationModelsToolBridge.isAuditedTraceID(
                "afm-tools-dropped-no-sdk-bridge"),
            "suffix detection requires the # prefix")
    }

    // MARK: - Strategy enum contract

    func testStrategyHasExactlyThreeCases() {
        XCTAssertEqual(
            BASFoundationModelsToolBridgeStrategy
                .allCases.count, 3)
    }

    func testStrategyRawValuesPinned() {
        XCTAssertEqual(
            BASFoundationModelsToolBridgeStrategy
                .runtimeSchema.rawValue,
            "runtimeSchema")
        XCTAssertEqual(
            BASFoundationModelsToolBridgeStrategy
                .compiledGenerable.rawValue,
            "compiledGenerable")
        XCTAssertEqual(
            BASFoundationModelsToolBridgeStrategy
                .audit.rawValue,
            "audit")
    }

    func testStrategyCodableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for strategy in
            BASFoundationModelsToolBridgeStrategy.allCases
        {
            let data = try encoder.encode(strategy)
            let decoded = try decoder.decode(
                BASFoundationModelsToolBridgeStrategy.self,
                from: data)
            XCTAssertEqual(decoded, strategy)
        }
    }

    // MARK: - Resolution

    func testEmptyToolsAlwaysResolvesAsAuditedNoSuffix() {
        // Even with `.runtimeSchema` strategy,empty tools[]
        // means there's NOTHING to bridge → audited mode
        // (no trace suffix needed — nothing was dropped)。
        let allStrategies =
            BASFoundationModelsToolBridgeStrategy.allCases
        for strategy in allStrategies {
            let status = BASFoundationModelsToolBridge
                .resolve(
                    strategy: strategy,
                    tools: [],
                    baseTraceID: "base-id")
            XCTAssertEqual(status,
                .audited(traceID: "base-id"))
            XCTAssertFalse(status.didBridgeTools)
        }
    }

    func testAuditStrategyAppendsM870Suffix() {
        let tools = [
            BASTool(name: "search",
                description: "memory search",
                parameters: [])
        ]
        let status = BASFoundationModelsToolBridge.resolve(
            strategy: .audit,
            tools: tools,
            baseTraceID: "base-trace")

        guard case .audited(let traceID) = status else {
            XCTFail("Expected .audited")
            return
        }
        XCTAssertEqual(
            traceID,
            "base-trace#afm-tools-dropped-no-sdk-bridge")
        XCTAssertFalse(status.didBridgeTools)
    }

    func testRuntimeSchemaResolvesAsBridged() {
        let tools = [
            BASTool(name: "a", description: "", parameters: []),
            BASTool(name: "b", description: "", parameters: [])
        ]
        let status = BASFoundationModelsToolBridge.resolve(
            strategy: .runtimeSchema,
            tools: tools,
            baseTraceID: "base")

        XCTAssertEqual(status,
            .bridgedRuntimeSchema(toolCount: 2))
        XCTAssertTrue(status.didBridgeTools)
    }

    func testCompiledGenerableResolvesAsBridged() {
        let tools = [
            BASTool(name: "a", description: "", parameters: [])
        ]
        let status = BASFoundationModelsToolBridge.resolve(
            strategy: .compiledGenerable,
            tools: tools,
            baseTraceID: "base")

        XCTAssertEqual(status,
            .bridgedCompiledGenerable(toolCount: 1))
        XCTAssertTrue(status.didBridgeTools)
    }
}
