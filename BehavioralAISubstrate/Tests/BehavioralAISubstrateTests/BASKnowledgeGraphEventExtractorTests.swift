// MARK: - BASKnowledgeGraphEventExtractorTests
// chapter 三百七十 / M857
//
// Test coverage for the M841 event log → M856 graph extractor。
// Verifies all 6 heuristics + idempotency + end-to-end
// composition with cycle detection。

import XCTest
@testable import BASRuntimeCore

final class BASKnowledgeGraphEventExtractorTests:
    XCTestCase
{

    // MARK: - Fixtures

    private func makeEvent(
        eventID: String = UUID().uuidString,
        timestampMs: Int64 = 1_700_000_000_000,
        kind: BASEventLogKind = .chat,
        sessionID: String = "test-ssn",
        project: String? = "test-project",
        actions: [String] = ["permit:answer"],
        intent: String? = nil
    ) -> BASEventLogEntry {
        BASEventLogEntry(
            eventID: eventID,
            timestampMs: timestampMs,
            kind: kind,
            sessionID: sessionID,
            sequenceNumber: 0,
            intent: intent,
            project: project,
            actions: actions)
    }

    // MARK: - Heuristic 1: each event → event node

    func testEachEventBecomesNode() async throws {
        let log = BASInMemoryEventLogStorage()
        for i in 0..<3 {
            _ = try await log.append(makeEvent(
                eventID: "evt-\(i)",
                timestampMs: 1_000 + Int64(i)))
        }
        let graph = BASKnowledgeGraph()
        let result = await BASKnowledgeGraphEventExtractor
            .extract(
                from: log,
                sessionID: "test-ssn",
                into: graph)
        XCTAssertEqual(result.totalEventsRead, 3)
        // 3 event nodes + 1 project node = 4 nodes
        XCTAssertEqual(result.addedNodeCount, 4)
        let nodeCount = await graph.nodeCount
        XCTAssertEqual(nodeCount, 4)
        for i in 0..<3 {
            let node = await graph.node(forID: "evt-\(i)")
            XCTAssertNotNil(node)
            XCTAssertEqual(node?.kind, .event)
        }
    }

    // MARK: - Heuristic 2 + 3: project node + mentions edge

    func testProjectNodeAndMentionsEdge() async throws {
        let log = BASInMemoryEventLogStorage()
        _ = try await log.append(makeEvent(
            eventID: "e1", project: "alpha"))
        let graph = BASKnowledgeGraph()
        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log, sessionID: "test-ssn",
            into: graph)
        let projectNode = await graph.node(
            forID: "project:alpha")
        XCTAssertNotNil(projectNode)
        XCTAssertEqual(projectNode?.kind, .project)
        let outgoing = await graph.outgoing(from: "e1")
        XCTAssertTrue(outgoing.contains { edge in
            edge.toNodeID == "project:alpha"
                && edge.kind == .mentions
        })
        // Mentions weight pin
        let mentionsEdge = outgoing.first {
            $0.kind == .mentions
        }
        XCTAssertEqual(
            mentionsEdge?.weight,
            BASKnowledgeGraphEventExtractor
                .mentionsEdgeWeight)
    }

    // MARK: - Heuristic 4: sequential causes

    func testSequentialCausesEdgesOnSameProject() async throws {
        let log = BASInMemoryEventLogStorage()
        _ = try await log.append(makeEvent(
            eventID: "e1",
            timestampMs: 1_000,
            project: "alpha"))
        _ = try await log.append(makeEvent(
            eventID: "e2",
            timestampMs: 2_000,
            project: "alpha"))
        _ = try await log.append(makeEvent(
            eventID: "e3",
            timestampMs: 3_000,
            project: "alpha"))
        let graph = BASKnowledgeGraph()
        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log, sessionID: "test-ssn",
            into: graph)
        // Sequential causes: e1 → e2, e2 → e3
        let e1Out = await graph.outgoing(from: "e1")
        let e2Out = await graph.outgoing(from: "e2")
        XCTAssertTrue(e1Out.contains { edge in
            edge.toNodeID == "e2"
                && edge.kind == .causes
        }, "e1 → causes → e2 (sequential same project)")
        XCTAssertTrue(e2Out.contains { edge in
            edge.toNodeID == "e3"
                && edge.kind == .causes
        }, "e2 → causes → e3 (sequential same project)")
    }

    func testSequentialCausesNotEmittedAcrossProjects()
        async throws
    {
        let log = BASInMemoryEventLogStorage()
        _ = try await log.append(makeEvent(
            eventID: "alpha-1",
            timestampMs: 1_000,
            project: "alpha"))
        _ = try await log.append(makeEvent(
            eventID: "beta-1",
            timestampMs: 2_000,
            project: "beta"))
        let graph = BASKnowledgeGraph()
        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log, sessionID: "test-ssn",
            into: graph)
        let outgoing = await graph.outgoing(from: "alpha-1")
        XCTAssertFalse(outgoing.contains { edge in
            edge.toNodeID == "beta-1"
                && edge.kind == .causes
        }, "Causes edges only between events sharing project")
    }

    // MARK: - Heuristic 5: skip:* → delays

    func testSkipActionEmitsDelaysEdge() async throws {
        let log = BASInMemoryEventLogStorage()
        _ = try await log.append(makeEvent(
            eventID: "skipped",
            project: "alpha",
            actions: ["skip:thermal-pause"]))
        let graph = BASKnowledgeGraph()
        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log, sessionID: "test-ssn",
            into: graph)
        let outgoing = await graph.outgoing(from: "skipped")
        let delaysEdge = outgoing.first {
            $0.kind == .delays
        }
        XCTAssertNotNil(delaysEdge)
        XCTAssertEqual(
            delaysEdge?.toNodeID, "project:alpha")
        XCTAssertEqual(
            delaysEdge?.weight,
            BASKnowledgeGraphEventExtractor
                .delaysEdgeWeight)
    }

    // MARK: - Heuristic 6: permit:block / replace → contradicts

    func testPermitBlockEmitsContradictsEdge() async throws {
        let log = BASInMemoryEventLogStorage()
        _ = try await log.append(makeEvent(
            eventID: "blocked",
            project: "alpha",
            actions: ["permit:block"]))
        let graph = BASKnowledgeGraph()
        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log, sessionID: "test-ssn",
            into: graph)
        let outgoing = await graph.outgoing(from: "blocked")
        let contradictsEdge = outgoing.first {
            $0.kind == .contradicts
        }
        XCTAssertNotNil(contradictsEdge)
        XCTAssertEqual(
            contradictsEdge?.toNodeID, "project:alpha")
    }

    func testPermitReplaceEmitsContradictsEdge()
        async throws
    {
        let log = BASInMemoryEventLogStorage()
        _ = try await log.append(makeEvent(
            eventID: "replaced",
            project: "alpha",
            actions: ["permit:replace"]))
        let graph = BASKnowledgeGraph()
        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log, sessionID: "test-ssn",
            into: graph)
        let outgoing = await graph.outgoing(from: "replaced")
        XCTAssertTrue(outgoing.contains {
            $0.kind == .contradicts
        })
    }

    // MARK: - Idempotent extraction

    func testIdempotentExtraction() async throws {
        let log = BASInMemoryEventLogStorage()
        _ = try await log.append(makeEvent(
            eventID: "e1", project: "alpha"))
        _ = try await log.append(makeEvent(
            eventID: "e2",
            timestampMs: 2_000, project: "alpha"))
        let graph = BASKnowledgeGraph()
        let first = await BASKnowledgeGraphEventExtractor
            .extract(
                from: log, sessionID: "test-ssn",
                into: graph)
        let second = await BASKnowledgeGraphEventExtractor
            .extract(
                from: log, sessionID: "test-ssn",
                into: graph)
        XCTAssertGreaterThan(
            first.addedNodeCount, 0,
            "First extraction adds nodes")
        XCTAssertEqual(
            second.addedNodeCount, 0,
            "Second extraction is idempotent — no new nodes")
        XCTAssertEqual(
            second.addedEdgeCount, 0,
            "Second extraction is idempotent — no new edges")
    }

    // MARK: - Empty session

    func testEmptySessionReturnsZeroResult() async {
        let log = BASInMemoryEventLogStorage()
        let graph = BASKnowledgeGraph()
        let result = await BASKnowledgeGraphEventExtractor
            .extract(
                from: log, sessionID: "ghost",
                into: graph)
        XCTAssertEqual(result.totalEventsRead, 0)
        XCTAssertEqual(result.addedNodeCount, 0)
        XCTAssertEqual(result.addedEdgeCount, 0)
    }

    // MARK: - Reason codes

    func testReasonCodesEmittedForAuditTrail()
        async throws
    {
        let log = BASInMemoryEventLogStorage()
        for i in 0..<3 {
            _ = try await log.append(makeEvent(
                eventID: "e\(i)",
                timestampMs: 1_000 + Int64(i)))
        }
        let graph = BASKnowledgeGraph()
        let result = await BASKnowledgeGraphEventExtractor
            .extract(
                from: log, sessionID: "test-ssn",
                into: graph)
        XCTAssertTrue(
            result.reasonCodes.contains(
                "knowledge-graph-extract:session:test-ssn"))
        XCTAssertTrue(
            result.reasonCodes.contains(
                "knowledge-graph-extract:events-read:3"))
        XCTAssertTrue(
            result.reasonCodes.contains(where: {
                $0.hasPrefix(
                    "knowledge-graph-extract:nodes-added:")
            }))
    }

    // MARK: - End-to-end: extractor + cycle detection

    /// **Architectural pin** — extractor + cycle detection
    /// compose end-to-end。Synthetic event sequence representing
    /// user-vision §10 "complexity addiction loop":
    ///   - event A: anxious chat about project
    ///   - event B: skip:thermal-pause on same project
    ///     (delays)
    /// Then we MANUALLY add the closing causes edge from project
    /// back to a third event (representing the loop coming
    /// back around to anxiety)。
    /// Cycle detection finds the loop。
    func testEndToEndExtractPlusCycleDetection()
        async throws
    {
        let log = BASInMemoryEventLogStorage()
        _ = try await log.append(makeEvent(
            eventID: "anxiety-event",
            timestampMs: 1_000,
            project: "stuck-loop",
            actions: ["permit:answer"]))
        _ = try await log.append(makeEvent(
            eventID: "tech-event",
            timestampMs: 2_000,
            project: "stuck-loop",
            actions: ["skip:thermal-pause"]))  // delays
        let graph = BASKnowledgeGraph()
        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log, sessionID: "test-ssn",
            into: graph)
        // Add the closing edge: project loops back to anxiety
        // (this would be heuristic 7+ in a future commit;
        // for now manually wire to verify end-to-end cycle
        // detection works on the extracted graph)
        try await graph.insert(edge: BASKnowledgeEdge(
            edgeID: "manual-closing",
            fromNodeID: "project:stuck-loop",
            toNodeID: "anxiety-event",
            kind: .causes,
            weight: 0.5,
            createdAtMs: 3_000))
        // Cycle detection should find the loop
        let cycles = await graph.detectCycles(
            filter: { $0.containsEdgeKind(.delays) })
        XCTAssertGreaterThanOrEqual(cycles.count, 1,
            "Extracted graph + manually-closed loop must " +
            "be detected by cycle finder filtered for delays")
    }

    // MARK: - Constants pins

    func testEdgeWeightConstantsPin() {
        XCTAssertEqual(
            BASKnowledgeGraphEventExtractor
                .mentionsEdgeWeight, 0.3)
        XCTAssertEqual(
            BASKnowledgeGraphEventExtractor
                .sequentialCausesEdgeWeight, 0.5)
        XCTAssertEqual(
            BASKnowledgeGraphEventExtractor
                .delaysEdgeWeight, 0.7)
        XCTAssertEqual(
            BASKnowledgeGraphEventExtractor
                .contradictsEdgeWeight, 0.8)
    }

    func testReasonCodePrefixPin() {
        XCTAssertEqual(
            BASKnowledgeGraphEventExtractor
                .reasonCodePrefix,
            "knowledge-graph-extract")
    }
}
