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

    // MARK: - Heuristic 7 (M860): closing-edge synthesis

    func testHeuristic7ClosingEdgeConstantsPin() {
        XCTAssertEqual(
            BASKnowledgeGraphEventExtractor
                .closingEdgeDelaysThreshold, 2,
            "Default threshold pin: 2 delays edges trigger " +
            "closing-edge synthesis")
        XCTAssertEqual(
            BASKnowledgeGraphEventExtractor
                .closingEdgeWeight, 0.4,
            "Closing edge weight is lower than direct " +
            "causes (inferred not observed)")
    }

    func testHeuristic7AnchorCodePin() {
        XCTAssertEqual(
            BASKnowledgeGraphEventExtractor
                .closingEdgeAnchorCode,
            "knowledge-graph-extract:heuristic-7:" +
            "closing-edge-synthesized")
    }

    func testHeuristic7DoesNotFireOnSingleDelaysEdge()
        async throws
    {
        // Below threshold → no closing edge synthesized
        let log = BASInMemoryEventLogStorage()
        _ = try await log.append(makeEvent(
            eventID: "e1", project: "alpha"))
        _ = try await log.append(makeEvent(
            eventID: "e2",
            timestampMs: 2_000,
            project: "alpha",
            actions: ["skip:thermal-pause"]))
        let graph = BASKnowledgeGraph()
        let result = await BASKnowledgeGraphEventExtractor
            .extract(
                from: log,
                sessionID: "test-ssn",
                into: graph)
        // Closing edge ID would be
        // "h7-closing:project:alpha→e1"
        let outgoingFromProject = await graph.outgoing(
            from: "project:alpha")
        let hasClosingEdge = outgoingFromProject.contains {
            $0.edgeID.hasPrefix("h7-closing:")
        }
        XCTAssertFalse(
            hasClosingEdge,
            "Single delays edge below threshold (2) → no " +
            "closing edge synthesized")
        XCTAssertFalse(
            result.reasonCodes.contains(
                BASKnowledgeGraphEventExtractor
                    .closingEdgeAnchorCode))
    }

    func testHeuristic7FiresOnTwoDelaysEdges() async throws {
        let log = BASInMemoryEventLogStorage()
        _ = try await log.append(makeEvent(
            eventID: "first-evt",
            timestampMs: 1_000,
            project: "alpha",
            actions: ["permit:answer"]))
        _ = try await log.append(makeEvent(
            eventID: "skip-evt-1",
            timestampMs: 2_000,
            project: "alpha",
            actions: ["skip:thermal-pause"]))
        _ = try await log.append(makeEvent(
            eventID: "skip-evt-2",
            timestampMs: 3_000,
            project: "alpha",
            actions: ["skip:cooling"]))
        let graph = BASKnowledgeGraph()
        let result = await BASKnowledgeGraphEventExtractor
            .extract(
                from: log,
                sessionID: "test-ssn",
                into: graph)
        // 2 delays edges met the threshold → closing edge
        // synthesized from project:alpha → first-evt
        let outgoingFromProject = await graph.outgoing(
            from: "project:alpha")
        let closingEdge = outgoingFromProject.first {
            $0.edgeID.hasPrefix("h7-closing:")
        }
        XCTAssertNotNil(
            closingEdge,
            "2 delays edges triggers heuristic 7 closing edge")
        XCTAssertEqual(
            closingEdge?.toNodeID, "first-evt",
            "Closing edge points from project to FIRST " +
            "event of that project (deterministic)")
        XCTAssertEqual(
            closingEdge?.kind, .causes,
            "Closing edge kind is causes")
        XCTAssertEqual(
            closingEdge?.weight,
            BASKnowledgeGraphEventExtractor
                .closingEdgeWeight,
            "Closing edge weight uses dedicated typed constant")
        // Anchor reason code emitted
        XCTAssertTrue(
            result.reasonCodes.contains(
                BASKnowledgeGraphEventExtractor
                    .closingEdgeAnchorCode))
        XCTAssertTrue(
            result.reasonCodes.contains(where: { code in
                code.contains(
                    "heuristic-7:closing-edges-synthesized:1")
            }))
    }

    // MARK: - M888 / M890 cycle-feedback event

    func testM888CycleEventEmittedToFeedbackLog()
        async throws
    {
        let log = BASInMemoryEventLogStorage()
        _ = try await log.append(makeEvent(
            eventID: "first-evt",
            timestampMs: 1_000,
            project: "alpha",
            actions: ["permit:answer"]))
        _ = try await log.append(makeEvent(
            eventID: "skip-1",
            timestampMs: 2_000,
            project: "alpha",
            actions: ["skip:thermal-pause"]))
        _ = try await log.append(makeEvent(
            eventID: "skip-2",
            timestampMs: 3_000,
            project: "alpha",
            actions: ["skip:cooling"]))
        let graph = BASKnowledgeGraph()
        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log,
            sessionID: "test-ssn",
            into: graph,
            feedbackLog: log)

        // Event log must now contain the cycle event
        let total = await log.totalCount
        XCTAssertEqual(total, 4,
            "3 input events + 1 cycle feedback event = 4")
        let events = await log.events(
            forSession: "test-ssn")
        let cycleEvent = events.first { $0.eventID
            .hasPrefix("cycle:") }
        XCTAssertNotNil(cycleEvent,
            "Cycle feedback event must be appended")
        XCTAssertEqual(cycleEvent?.kind, .internalSignal)
        XCTAssertEqual(cycleEvent?.project, "alpha")
        XCTAssertEqual(
            cycleEvent?.actions.first,
            "cycle-detected:project:alpha")
    }

    func testM890CycleEventTimestampIncludedInNextScan()
        async throws
    {
        // M890 fix:cycle event timestamp must be strictly
        // greater than events.last.timestampMs so that the next
        // incremental extract's `since: hwm+1` filter includes
        // the cycle event in its scan window。Pre-M890 the
        // timestamp equaled events.last → cycle event silently
        // dropped from subsequent extracts。
        let log = BASInMemoryEventLogStorage()
        _ = try await log.append(makeEvent(
            eventID: "evt-1",
            timestampMs: 1_000,
            project: "alpha",
            actions: ["skip:overload"]))
        _ = try await log.append(makeEvent(
            eventID: "evt-2",
            timestampMs: 2_000,
            project: "alpha",
            actions: ["skip:thermal"]))
        let graph = BASKnowledgeGraph()
        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log,
            sessionID: "test-ssn",
            into: graph,
            feedbackLog: log)

        let events = await log.events(forSession: "test-ssn")
        guard let cycleEvent = events.first(where: {
            $0.eventID.hasPrefix("cycle:")
        }) else {
            XCTFail("Cycle event not emitted")
            return
        }
        XCTAssertEqual(
            cycleEvent.timestampMs, 2_001,
            "M890 pin:cycle event timestamp must be " +
            "events.last.timestampMs + 1 (=2001),NOT == " +
            "events.last (=2000)。If pre-M890 logic regresses " +
            "back to ==events.last,a hwm-advance to 2000 + " +
            "scan-since 2001 would silently drop the cycle " +
            "event from next extract。")

        // Simulate next extract with `since: 2001`
        // (i.e. events.last + 1) — must INCLUDE the cycle event
        let scanSince: Int64 = 2_001
        let scanned = await log.events(
            sinceTimestampMs: scanSince, limit: Int.max)
        XCTAssertTrue(
            scanned.contains { $0.eventID == cycleEvent.eventID },
            "Cycle event with timestamp 2001 must fall " +
            "inside `>= 2001` scan window")
    }

    func testM892IncrementalExtractDoesNotEmitDuplicateCycleEvents()
        async throws
    {
        // M892 fix:cycle eventID is `cycle:<sessionID>:project:
        // <name>` — same project in same session always produces
        // the same cycle-eventID,so re-detection across multiple
        // incremental extracts is a no-op append (wasNew=false)。
        //
        // Pre-M892 the eventID embedded firstEventID,which is
        // local-per-extract,so each scan window with the same
        // project produced a DIFFERENT closing-edge-ID →
        // DIFFERENT cycle-eventID → unbounded growth on long
        // sessions。
        let log = BASInMemoryEventLogStorage()

        // Window 1:events 1-3 form a delays cycle on alpha
        _ = try await log.append(makeEvent(
            eventID: "ev-1",
            timestampMs: 1_000,
            project: "alpha",
            actions: ["permit:answer"]))
        _ = try await log.append(makeEvent(
            eventID: "ev-2",
            timestampMs: 1_500,
            project: "alpha",
            actions: ["skip:thermal"]))
        _ = try await log.append(makeEvent(
            eventID: "ev-3",
            timestampMs: 2_000,
            project: "alpha",
            actions: ["skip:overload"]))

        let graph = BASKnowledgeGraph()

        // First extract:full walk (no since)
        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log,
            sessionID: "test-ssn",
            into: graph,
            feedbackLog: log)
        let count1 = await log.totalCount
        XCTAssertEqual(count1, 4,
            "3 events + 1 cycle event = 4")

        // Window 2:add 3 more events,extract incrementally
        // with `since: 2_500`。`projectToFirstEventID` re-
        // initializes locally → captures a NEW firstEvent
        // (ev-100) different from window 1's firstEvent (ev-1)。
        // Pre-M892 this would emit a SECOND cycle event with
        // different eventID。Post-M892 the eventID is stable
        // per (sessionID, project) → idempotent append。
        _ = try await log.append(makeEvent(
            eventID: "ev-100",
            timestampMs: 3_000,
            project: "alpha",
            actions: ["permit:answer"]))
        _ = try await log.append(makeEvent(
            eventID: "ev-101",
            timestampMs: 3_500,
            project: "alpha",
            actions: ["skip:thermal"]))
        _ = try await log.append(makeEvent(
            eventID: "ev-102",
            timestampMs: 4_000,
            project: "alpha",
            actions: ["skip:overload"]))

        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log,
            sessionID: "test-ssn",
            into: graph,
            sinceTimestampMs: 2_500,
            feedbackLog: log)

        let count2 = await log.totalCount
        XCTAssertEqual(count2, 7,
            "Window 2 added 3 real events + 0 new cycle " +
            "events (idempotent on cycle:test-ssn:project:alpha) = 7。" +
            "Pre-M892 this would have been 8 (one new cycle " +
            "event per window) → unbounded growth。")

        // Verify there's exactly ONE cycle event in the log
        let allEvents = await log.events(
            forSession: "test-ssn")
        let cycleEvents = allEvents.filter {
            $0.eventID.hasPrefix("cycle:")
        }
        XCTAssertEqual(cycleEvents.count, 1,
            "Exactly one cycle event per (session, project)")
        XCTAssertEqual(
            cycleEvents.first?.eventID,
            "cycle:test-ssn:project:alpha",
            "M892 stable eventID format pin")
    }

    func testHeuristic7CycleDetectableWithoutManualEdge()
        async throws
    {
        // **Architectural pin**: heuristic 7 closes the loop
        // automatically so cycle detection finds the user-vision
        // §10 'complexity addiction loop' WITHOUT manual closing
        // edge wiring (vs M857 testEndToEndExtractPlusCycle
        // Detection which required manual closing edge)。
        let log = BASInMemoryEventLogStorage()
        _ = try await log.append(makeEvent(
            eventID: "anxiety-evt",
            timestampMs: 1_000,
            project: "stuck-project",
            actions: ["permit:answer"]))
        _ = try await log.append(makeEvent(
            eventID: "tech-evt-1",
            timestampMs: 2_000,
            project: "stuck-project",
            actions: ["skip:thermal-pause"]))
        _ = try await log.append(makeEvent(
            eventID: "tech-evt-2",
            timestampMs: 3_000,
            project: "stuck-project",
            actions: ["skip:cooling"]))
        let graph = BASKnowledgeGraph()
        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log,
            sessionID: "test-ssn",
            into: graph)
        // No manual closing edge — heuristic 7 must close
        let cycles = await graph.detectCycles(
            filter: { $0.containsEdgeKind(.delays) })
        XCTAssertGreaterThanOrEqual(
            cycles.count, 1,
            "Heuristic 7 must close the loop so cycle " +
            "detection finds user-vision §10 cycle WITHOUT " +
            "manual edge wiring")
    }

    func testHeuristic7Disabled() async throws {
        // Pass closingEdgeThreshold: 0 to disable heuristic 7
        let log = BASInMemoryEventLogStorage()
        for i in 0..<3 {
            _ = try await log.append(makeEvent(
                eventID: "e\(i)",
                timestampMs: 1_000 + Int64(i),
                project: "alpha",
                actions: ["skip:thermal-pause"]))
        }
        let graph = BASKnowledgeGraph()
        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log,
            sessionID: "test-ssn",
            into: graph,
            closingEdgeThreshold: 0)
        let outgoingFromProject = await graph.outgoing(
            from: "project:alpha")
        let hasClosingEdge = outgoingFromProject.contains {
            $0.edgeID.hasPrefix("h7-closing:")
        }
        XCTAssertFalse(
            hasClosingEdge,
            "closingEdgeThreshold=0 disables heuristic 7 " +
            "(conservative replay mode)")
    }

    func testHeuristic7CustomThreshold() async throws {
        // Custom threshold = 3 → 3 delays edges needed
        let log = BASInMemoryEventLogStorage()
        for i in 0..<3 {
            _ = try await log.append(makeEvent(
                eventID: "e\(i)",
                timestampMs: 1_000 + Int64(i),
                project: "alpha",
                actions: ["skip:thermal-pause"]))
        }
        // First, run with threshold=3 → should fire
        let graphMet = BASKnowledgeGraph()
        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log,
            sessionID: "test-ssn",
            into: graphMet,
            closingEdgeThreshold: 3)
        let outgoingMet = await graphMet.outgoing(
            from: "project:alpha")
        XCTAssertTrue(
            outgoingMet.contains {
                $0.edgeID.hasPrefix("h7-closing:")
            },
            "3 delays + threshold=3 → fires")
        // Same input + threshold=4 → should NOT fire
        let graphUnmet = BASKnowledgeGraph()
        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log,
            sessionID: "test-ssn",
            into: graphUnmet,
            closingEdgeThreshold: 4)
        let outgoingUnmet = await graphUnmet.outgoing(
            from: "project:alpha")
        XCTAssertFalse(
            outgoingUnmet.contains {
                $0.edgeID.hasPrefix("h7-closing:")
            },
            "3 delays + threshold=4 → does not fire")
    }

    func testHeuristic7IsIdempotent() async throws {
        let log = BASInMemoryEventLogStorage()
        _ = try await log.append(makeEvent(
            eventID: "e1", project: "alpha"))
        _ = try await log.append(makeEvent(
            eventID: "e2", timestampMs: 2_000,
            project: "alpha",
            actions: ["skip:a"]))
        _ = try await log.append(makeEvent(
            eventID: "e3", timestampMs: 3_000,
            project: "alpha",
            actions: ["skip:b"]))
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
            first.addedEdgeCount, 0)
        XCTAssertEqual(
            second.addedEdgeCount, 0,
            "Re-extraction is idempotent — heuristic 7 " +
            "closing edge has stable ID, duplicate skipped")
    }

    func testHeuristic7CrossProjectsIndependent()
        async throws
    {
        // Two projects, each with 2 delays → both get
        // closing edges
        let log = BASInMemoryEventLogStorage()
        _ = try await log.append(makeEvent(
            eventID: "alpha-1",
            timestampMs: 1_000,
            project: "alpha"))
        _ = try await log.append(makeEvent(
            eventID: "beta-1",
            timestampMs: 2_000,
            project: "beta"))
        _ = try await log.append(makeEvent(
            eventID: "alpha-2",
            timestampMs: 3_000,
            project: "alpha",
            actions: ["skip:a"]))
        _ = try await log.append(makeEvent(
            eventID: "beta-2",
            timestampMs: 4_000,
            project: "beta",
            actions: ["skip:b"]))
        _ = try await log.append(makeEvent(
            eventID: "alpha-3",
            timestampMs: 5_000,
            project: "alpha",
            actions: ["skip:c"]))
        _ = try await log.append(makeEvent(
            eventID: "beta-3",
            timestampMs: 6_000,
            project: "beta",
            actions: ["skip:d"]))
        let graph = BASKnowledgeGraph()
        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log,
            sessionID: "test-ssn",
            into: graph)
        let outAlpha = await graph.outgoing(
            from: "project:alpha")
        let outBeta = await graph.outgoing(
            from: "project:beta")
        // M894 fix:closing edge ID is now stable per project
        // (no firstEventID suffix)。toNodeID still points to
        // the first event observed for that project — which is
        // what we verify here。
        XCTAssertTrue(
            outAlpha.contains {
                $0.edgeID == "h7-closing:project:alpha"
                    && $0.toNodeID == "alpha-1"
            },
            "Alpha closing edge fires (M894 stable edgeID) + " +
            "points to alpha-1 (first event for alpha)")
        XCTAssertTrue(
            outBeta.contains {
                $0.edgeID == "h7-closing:project:beta"
                    && $0.toNodeID == "beta-1"
            },
            "Beta closing edge fires (M894 stable edgeID) + " +
            "points to beta-1 (first event for beta)")
    }

    // MARK: - M894 graph edge stability across incremental extracts

    func testM894ClosingEdgeIDStableAcrossIncrementalExtracts()
        async throws
    {
        // M894 fix:closing edge ID = "h7-closing:project:<name>"
        // is stable per project,NOT per (project, firstEvent)。
        // Pre-M894 each incremental scan window saw a different
        // firstEvent → different closingEdgeID → graph
        // accumulated unbounded closing edges。Post-M894 the
        // first extract's closing edge wins,subsequent extracts
        // hit duplicateEdgeID + skip。
        let log = BASInMemoryEventLogStorage()
        // Window 1: events ts 1000-2000,delays cycle on alpha
        _ = try await log.append(makeEvent(
            eventID: "ev-w1-1",
            timestampMs: 1_000,
            project: "alpha",
            actions: ["permit:answer"]))
        _ = try await log.append(makeEvent(
            eventID: "ev-w1-2",
            timestampMs: 1_500,
            project: "alpha",
            actions: ["skip:thermal"]))
        _ = try await log.append(makeEvent(
            eventID: "ev-w1-3",
            timestampMs: 2_000,
            project: "alpha",
            actions: ["skip:overload"]))
        let graph = BASKnowledgeGraph()
        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log,
            sessionID: "test-ssn",
            into: graph)
        let edgeCountAfterW1 = await graph.edgeCount

        // Window 2: more events with delays cycle on alpha,
        // incremental extract → new firstEvent observed
        _ = try await log.append(makeEvent(
            eventID: "ev-w2-1",
            timestampMs: 3_000,
            project: "alpha",
            actions: ["permit:answer"]))
        _ = try await log.append(makeEvent(
            eventID: "ev-w2-2",
            timestampMs: 3_500,
            project: "alpha",
            actions: ["skip:thermal"]))
        _ = try await log.append(makeEvent(
            eventID: "ev-w2-3",
            timestampMs: 4_000,
            project: "alpha",
            actions: ["skip:overload"]))
        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log,
            sessionID: "test-ssn",
            into: graph,
            sinceTimestampMs: 2_500)
        let edgeCountAfterW2 = await graph.edgeCount

        // Pre-M894:graph would have 2 closing edges (one per
        // window with different toNode)。Post-M894:graph has
        // exactly 1 closing edge (first wins,second skipped
        // via duplicateEdgeID)。
        let outAlpha = await graph.outgoing(
            from: "project:alpha")
        let closingEdges = outAlpha.filter {
            $0.edgeID.hasPrefix("h7-closing:")
        }
        XCTAssertEqual(closingEdges.count, 1,
            "M894 pin:exactly one closing edge per project, " +
            "not one per scan window。Pre-M894 this would be 2.")
        XCTAssertEqual(
            closingEdges.first?.edgeID,
            "h7-closing:project:alpha",
            "M894 stable edgeID format (no firstEventID suffix)")

        // Edge count growth bounded by # of NEW non-closing
        // edges across windows,NOT growing per window for
        // closing edges
        XCTAssertGreaterThan(
            edgeCountAfterW2, edgeCountAfterW1,
            "Window 2 added some new mentions/causes/delays " +
            "edges from its 3 events")
    }
}
