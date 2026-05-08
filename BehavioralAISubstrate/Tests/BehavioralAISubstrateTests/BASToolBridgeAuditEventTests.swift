// MARK: - BASToolBridgeAuditEventTests — chapter 四百 / M924

import XCTest
@testable import BASOrgan
@testable import BASRuntimeCore

final class BASToolBridgeAuditEventTests: XCTestCase {

    private func makeRequest(
        tools: [BASTool],
        sessionID: String = "s-1"
    ) -> BASOrganRequest {
        BASOrganRequest(
            requestID: "req-test",
            role: .scout,
            preset: .scout,
            instruction: "test",
            tools: tools)
    }

    func testActionPrefixPinned() {
        XCTAssertEqual(
            BASFoundationModelsToolBridge
                .auditEventActionPrefix,
            "afm:tools:dropped")
    }

    func testSourcePinned() {
        XCTAssertEqual(
            BASFoundationModelsToolBridge
                .auditEventSource,
            "afm-bridge:audit")
    }

    func testEmptyToolsAuditedStatusReturnsNil() {
        // Empty tools[] resolves as `.audited(traceID:base)`
        // (no suffix) — nothing was dropped → no event。
        let status = BASFoundationModelsToolBridge.resolve(
            strategy: .audit,
            tools: [],
            baseTraceID: "base")
        let event = BASFoundationModelsToolBridge
            .makeAuditEvent(
                for: status,
                request: makeRequest(tools: []),
                timestampMs: 1_000,
                sessionID: "s-1")
        XCTAssertNil(event,
            "Empty tools[] = nothing dropped = no event")
    }

    func testAuditedNonEmptyProducesEvent() {
        let tools = [
            BASTool(name: "search", description: "",
                parameters: []),
            BASTool(name: "calc", description: "",
                parameters: [])
        ]
        let req = makeRequest(tools: tools)
        let status = BASFoundationModelsToolBridge.resolve(
            strategy: .audit,
            tools: tools,
            baseTraceID: "base-id")
        let event = BASFoundationModelsToolBridge
            .makeAuditEvent(
                for: status,
                request: req,
                timestampMs: 1_700_000_000_000,
                sessionID: "session-A")

        XCTAssertNotNil(event)
        XCTAssertEqual(event?.kind, .substrateAudit)
        XCTAssertEqual(event?.sessionID, "session-A")
        XCTAssertEqual(event?.timestampMs,
            1_700_000_000_000)
        XCTAssertEqual(event?.source, "afm-bridge:audit")
        XCTAssertEqual(event?.turnRef, "req-test")
        XCTAssertEqual(event?.riskBand, .medium,
            "Tool drop is non-trivial → medium risk")

        // Action contains tool count
        XCTAssertEqual(event?.actions.count, 1)
        XCTAssertTrue(
            event?.actions.first?.hasPrefix(
                "afm:tools:dropped:") ?? false)
        XCTAssertTrue(
            event?.actions.first?.hasSuffix(":2") ?? false,
            "Action suffix encodes the dropped tool count")

        // Payload contains tool names + trace ID
        XCTAssertNotNil(event?.payloadJson)
        XCTAssertTrue(
            event?.payloadJson?.contains("search") ?? false)
        XCTAssertTrue(
            event?.payloadJson?.contains("calc") ?? false)
        XCTAssertTrue(
            event?.payloadJson?.contains(
                BASFoundationModelsToolBridge
                    .auditTraceSuffix) ?? false)
    }

    func testBridgedRuntimeSchemaProducesNoEvent() {
        let tools = [
            BASTool(name: "x", description: "",
                parameters: [])
        ]
        let status = BASFoundationModelsToolBridge.resolve(
            strategy: .runtimeSchema,
            tools: tools,
            baseTraceID: "base")
        let event = BASFoundationModelsToolBridge
            .makeAuditEvent(
                for: status,
                request: makeRequest(tools: tools),
                timestampMs: 1_000,
                sessionID: "s")
        XCTAssertNil(event,
            "Bridged status = no drop = no audit event")
    }

    func testBridgedCompiledGenerableProducesNoEvent() {
        let tools = [
            BASTool(name: "x", description: "",
                parameters: [])
        ]
        let status = BASFoundationModelsToolBridge.resolve(
            strategy: .compiledGenerable,
            tools: tools,
            baseTraceID: "base")
        let event = BASFoundationModelsToolBridge
            .makeAuditEvent(
                for: status,
                request: makeRequest(tools: tools),
                timestampMs: 1_000,
                sessionID: "s")
        XCTAssertNil(event)
    }

    func testEventIDIsDeterministicFromRequestID() {
        // Same request → same eventID (M892 replay
        // determinism doctrine)
        let tools = [BASTool(
            name: "x", description: "", parameters: [])]
        let status = BASFoundationModelsToolBridge.resolve(
            strategy: .audit,
            tools: tools,
            baseTraceID: "base")
        let req = makeRequest(tools: tools)

        let event1 = BASFoundationModelsToolBridge
            .makeAuditEvent(
                for: status, request: req,
                timestampMs: 1_000, sessionID: "s")
        let event2 = BASFoundationModelsToolBridge
            .makeAuditEvent(
                for: status, request: req,
                timestampMs: 2_000, sessionID: "s")

        XCTAssertEqual(
            event1?.eventID, event2?.eventID,
            "EventID derived from requestID is deterministic")
    }
}
