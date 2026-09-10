// MARK: - BASUserStateGraphAwareReducerTests
// chapter 三百七一 / M858
//
// Test coverage for graph-aware composition of M842 reducer +
// M856 cycle detection。Verifies:
//   - No event project → base reducer output unchanged
//   - No delays cycles → base output unchanged
//   - Delays cycle on event project → complexity score bumped
//   - Multi-cycle scaling (clamped at max)
//   - Score clamps at [0, 1] via BASUserState init
//   - End-to-end M841 + M857 + M858 composition
//   - Determinism

import XCTest
@testable import BASRuntimeCore

final class BASUserStateGraphAwareReducerTests:
    XCTestCase
{

    // MARK: - Fixtures

    private func makeEvent(
        eventID: String = "evt-1",
        timestampMs: Int64 = 1_700_000_000_000,
        kind: BASEventLogKind = .chat,
        project: String? = "test-project",
        actions: [String] = []
    ) -> BASEventLogEntry {
        BASEventLogEntry(
            eventID: eventID,
            timestampMs: timestampMs,
            kind: kind,
            sessionID: "test-ssn",
            sequenceNumber: 0,
            project: project,
            actions: actions)
    }

    private func makeNode(
        id: String,
        kind: BASKnowledgeNodeKind = .event
    ) -> BASKnowledgeNode {
        BASKnowledgeNode(
            nodeID: id, kind: kind,
            label: id, createdAtMs: 0)
    }

    private func makeEdge(
        from: String,
        to: String,
        kind: BASKnowledgeEdgeKind = .causes,
        edgeID: String? = nil
    ) -> BASKnowledgeEdge {
        BASKnowledgeEdge(
            edgeID: edgeID ?? "\(from)-\(kind.rawValue)-\(to)",
            fromNodeID: from,
            toNodeID: to,
            kind: kind,
            weight: 0.5,
            createdAtMs: 0)
    }

    /// Construct a simple delays-cycle graph involving project
    /// node。Returns the project node ID for caller convenience。
    private func buildDelaysCycleGraph(
        projectName: String
    ) async throws -> (graph: BASKnowledgeGraph,
                       projectNodeID: String)
    {
        let graph = BASKnowledgeGraph()
        let projectID = "project:\(projectName)"
        try await graph.insert(node: makeNode(
            id: "anxiety-evt"))
        try await graph.insert(node: makeNode(
            id: "tech-evt"))
        try await graph.insert(node: makeNode(
            id: projectID, kind: .project))
        try await graph.insert(edge: makeEdge(
            from: "anxiety-evt", to: "tech-evt",
            kind: .causes))
        try await graph.insert(edge: makeEdge(
            from: "tech-evt", to: projectID,
            kind: .delays))
        try await graph.insert(edge: makeEdge(
            from: projectID, to: "anxiety-evt",
            kind: .causes))
        return (graph, projectID)
    }

    // MARK: - No project → base unchanged

    func testNoProjectYieldsBaseOutput() async throws {
        let graph = BASKnowledgeGraph()
        let event = makeEvent(project: nil)
        let composed = await BASUserStateGraphAwareReducer
            .reduce(
                prior: .zero,
                event: event,
                graph: graph,
                newStateID: "s-1",
                generatedAtMs: 1_000)
        let base = BASUserStateReducer.reduce(
            prior: .zero,
            event: event,
            newStateID: "s-1",
            generatedAtMs: 1_000)
        XCTAssertEqual(
            composed.complexityAddictionScore,
            base.complexityAddictionScore,
            "Event without project tag → no graph lookup → " +
            "base reducer output unchanged")
    }

    // MARK: - No cycles → base unchanged

    func testEmptyGraphYieldsBaseOutput() async {
        let graph = BASKnowledgeGraph()
        let event = makeEvent(project: "alpha")
        let composed = await BASUserStateGraphAwareReducer
            .reduce(
                prior: .zero,
                event: event,
                graph: graph,
                newStateID: "s-1",
                generatedAtMs: 1_000)
        let base = BASUserStateReducer.reduce(
            prior: .zero,
            event: event,
            newStateID: "s-1",
            generatedAtMs: 1_000)
        XCTAssertEqual(
            composed.complexityAddictionScore,
            base.complexityAddictionScore,
            "Empty graph → no cycles → base output")
    }

    func testCausesOnlyCyclesYieldBaseOutput() async throws {
        // Cycle exists but has NO delays edges → not the
        // user-vision §10 signal,base output preserved
        let graph = BASKnowledgeGraph()
        try await graph.insert(node: makeNode(id: "a"))
        try await graph.insert(node: makeNode(id: "b"))
        try await graph.insert(node: makeNode(
            id: "project:alpha", kind: .project))
        try await graph.insert(edge: makeEdge(
            from: "a", to: "b", kind: .causes))
        try await graph.insert(edge: makeEdge(
            from: "b", to: "project:alpha",
            kind: .causes))
        try await graph.insert(edge: makeEdge(
            from: "project:alpha", to: "a",
            kind: .causes))
        let event = makeEvent(project: "alpha")
        let composed = await BASUserStateGraphAwareReducer
            .reduce(
                prior: .zero,
                event: event,
                graph: graph,
                newStateID: "s-1",
                generatedAtMs: 1_000)
        let base = BASUserStateReducer.reduce(
            prior: .zero,
            event: event,
            newStateID: "s-1",
            generatedAtMs: 1_000)
        XCTAssertEqual(
            composed.complexityAddictionScore,
            base.complexityAddictionScore,
            "Cycle without delays edges → no bonus")
    }

    // MARK: - Delays cycle → bonus applied

    func testDelaysCycleAddsBonusToComplexityScore()
        async throws
    {
        let (graph, _) = try await buildDelaysCycleGraph(
            projectName: "alpha")
        let event = makeEvent(project: "alpha")
        let composed = await BASUserStateGraphAwareReducer
            .reduce(
                prior: .zero,
                event: event,
                graph: graph,
                newStateID: "s-1",
                generatedAtMs: 1_000)
        let base = BASUserStateReducer.reduce(
            prior: .zero,
            event: event,
            newStateID: "s-1",
            generatedAtMs: 1_000)
        XCTAssertGreaterThan(
            composed.complexityAddictionScore,
            base.complexityAddictionScore,
            "Delays cycle on event's project → bonus applied")
        // Default cycle count = 1, bonus = 0.15
        XCTAssertEqual(
            composed.complexityAddictionScore,
            base.complexityAddictionScore
                + BASUserStateGraphAwareReducer
                    .cycleDetectionBonusStep,
            accuracy: 1e-9)
    }

    func testDelaysCycleOnDifferentProjectIgnored()
        async throws
    {
        // Graph has delays cycle on project alpha,but event
        // is for project beta → no bonus (project-scoped filter)
        let (graph, _) = try await buildDelaysCycleGraph(
            projectName: "alpha")
        let event = makeEvent(project: "beta")
        let composed = await BASUserStateGraphAwareReducer
            .reduce(
                prior: .zero,
                event: event,
                graph: graph,
                newStateID: "s-1",
                generatedAtMs: 1_000)
        let base = BASUserStateReducer.reduce(
            prior: .zero,
            event: event,
            newStateID: "s-1",
            generatedAtMs: 1_000)
        XCTAssertEqual(
            composed.complexityAddictionScore,
            base.complexityAddictionScore,
            "Delays cycle on different project → no bonus " +
            "(project-scoped filter pin)")
    }

    // MARK: - Multi-cycle scaling

    func testMultipleDelaysCyclesScale() async throws {
        let graph = BASKnowledgeGraph()
        let projectID = "project:alpha"
        try await graph.insert(node: makeNode(
            id: projectID, kind: .project))
        // Build 3 separate paths each forming a delays-cycle
        // through the project node
        for i in 0..<3 {
            let lhs = "lhs-\(i)"
            let rhs = "rhs-\(i)"
            try await graph.insert(node: makeNode(id: lhs))
            try await graph.insert(node: makeNode(id: rhs))
            try await graph.insert(edge: makeEdge(
                from: lhs, to: rhs,
                kind: .causes,
                edgeID: "c-\(i)"))
            try await graph.insert(edge: makeEdge(
                from: rhs, to: projectID,
                kind: .delays,
                edgeID: "d-\(i)"))
            try await graph.insert(edge: makeEdge(
                from: projectID, to: lhs,
                kind: .causes,
                edgeID: "p-\(i)"))
        }
        let event = makeEvent(project: "alpha")
        let composed = await BASUserStateGraphAwareReducer
            .reduce(
                prior: .zero,
                event: event,
                graph: graph,
                newStateID: "s-1",
                generatedAtMs: 1_000)
        let base = BASUserStateReducer.reduce(
            prior: .zero,
            event: event,
            newStateID: "s-1",
            generatedAtMs: 1_000)
        // 3 cycles × 0.15 = 0.45 (= max)
        let bonus = composed.complexityAddictionScore
            - base.complexityAddictionScore
        XCTAssertEqual(
            bonus,
            BASUserStateGraphAwareReducer
                .cycleDetectionMaxBonus,
            accuracy: 1e-9,
            "3 cycles × 0.15 step = 0.45 = max bonus")
    }

    // MARK: - Score clamps at [0, 1]

    func testScoreClampsAtOne() async throws {
        let prior = BASUserState(
            stateID: "p", generatedAtMs: 0,
            emotionalTrend: 0, projectMomentum: 0,
            memoryHeat: 0, riskTrend: 0,
            complexityAddictionScore: 0.9,  // near cap
            agentRouteHistory: [],
            lastNEventKinds: [])
        let (graph, _) = try await buildDelaysCycleGraph(
            projectName: "alpha")
        let event = makeEvent(project: "alpha")
        let composed = await BASUserStateGraphAwareReducer
            .reduce(
                prior: prior,
                event: event,
                graph: graph,
                newStateID: "s-1",
                generatedAtMs: 1_000)
        XCTAssertLessThanOrEqual(
            composed.complexityAddictionScore, 1.0,
            "Score must clamp at 1 even when bonus would " +
            "overflow (BASUserState init clamps)")
    }

    // MARK: - Determinism

    func testReducerIsDeterministic() async throws {
        let (graph, _) = try await buildDelaysCycleGraph(
            projectName: "alpha")
        let event = makeEvent(project: "alpha")
        let a = await BASUserStateGraphAwareReducer.reduce(
            prior: .zero, event: event, graph: graph,
            newStateID: "fixed", generatedAtMs: 1_000)
        let b = await BASUserStateGraphAwareReducer.reduce(
            prior: .zero, event: event, graph: graph,
            newStateID: "fixed", generatedAtMs: 1_000)
        XCTAssertEqual(a, b,
            "Same inputs → same output (replay correctness)")
    }

    // MARK: - End-to-end M841 + M857 + M858

    /// **Architectural pin**: full pipeline composition。
    /// 1. Append events to M841 event log
    /// 2. Run M857 extractor to populate M856 graph
    /// 3. Run M858 composed reducer
    /// 4. Verify complexityAddictionScore reflects detected
    ///    delays-cycle
    func testEndToEndCognitiveOSDataLoop() async throws {
        // 1. Event log seed (user vision §10 simulation)
        let log = BASInMemoryEventLogStorage()
        _ = try await log.append(BASEventLogEntry(
            eventID: "anxious-chat-1",
            timestampMs: 1_000,
            kind: .chat,
            sessionID: "s",
            sequenceNumber: 0,
            project: "stuck-project",
            actions: ["permit:answer"]))
        _ = try await log.append(BASEventLogEntry(
            eventID: "tech-chat-2",
            timestampMs: 2_000,
            kind: .chat,
            sessionID: "s",
            sequenceNumber: 0,
            project: "stuck-project",
            actions: ["skip:thermal-pause"]))
        // 2. M857 extractor populates graph
        let graph = BASKnowledgeGraph()
        let extractResult =
            await BASKnowledgeGraphEventExtractor.extract(
                from: log,
                sessionID: "s",
                into: graph)
        XCTAssertGreaterThan(
            extractResult.addedNodeCount, 0)
        // Manually close the loop (M857 doesn't synthesize
        // closing edges yet — that's heuristic 7+ for a
        // future commit)
        try await graph.insert(edge: makeEdge(
            from: "project:stuck-project",
            to: "anxious-chat-1",
            kind: .causes,
            edgeID: "manual-close"))
        // 3. M858 composed reducer on the next event
        let nextEvent = BASEventLogEntry(
            eventID: "anxious-chat-3",
            timestampMs: 3_000,
            kind: .chat,
            sessionID: "s",
            sequenceNumber: 0,
            project: "stuck-project",
            actions: ["permit:answer"])
        let state = await BASUserStateGraphAwareReducer
            .reduce(
                prior: .zero,
                event: nextEvent,
                graph: graph,
                newStateID: "s-end",
                generatedAtMs: 3_000)
        // 4. Score reflects detected cycle
        let base = BASUserStateReducer.reduce(
            prior: .zero,
            event: nextEvent,
            newStateID: "s-end",
            generatedAtMs: 3_000)
        XCTAssertGreaterThan(
            state.complexityAddictionScore,
            base.complexityAddictionScore,
            "User-vision §10 cognitive OS data loop closed " +
            "end-to-end: event log → graph extractor → cycle " +
            "detection → composed reducer reflects cycle in " +
            "complexity addiction score")
    }

    // MARK: - Constants pin

    func testCycleDetectionBonusStepPin() {
        XCTAssertEqual(
            BASUserStateGraphAwareReducer
                .cycleDetectionBonusStep,
            0.15,
            "Bonus step pin (anti-magic-number)")
    }

    func testCycleDetectionMaxBonusPin() {
        XCTAssertEqual(
            BASUserStateGraphAwareReducer
                .cycleDetectionMaxBonus,
            0.45,
            "Max bonus pin: 3 cycles saturate the score")
    }
}
