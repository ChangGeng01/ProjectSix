// MARK: - BASKnowledgeGraphMemoryAtomExtractionTests
// chapter 四百二 / M945
//
// Test coverage for Phase 1 第五刀:knowledge-graph extractor
// extension that recognizes memory-atom events and emits atom
// nodes + mentions/causes edges。
//
// Targets per the M945 plan spec (14 tests):
//   - Atom node creation per op variant (4)
//   - mentions edge from caller event → atom node (3)
//   - causes edge across two memory-touch events on same atom (3)
//   - Idempotent re-extraction (2)
//   - Legacy event-only extraction unchanged when no memory
//     events are present (2)

import Foundation
import XCTest
@testable import BASMemory
@testable import BASRuntimeCore

final class BASKnowledgeGraphMemoryAtomExtractionTests:
    XCTestCase
{

    // MARK: - Fixtures

    private func makeAtom(
        idString: String =
            "00000000-0000-4000-8000-000000000001",
        tier: BASMemoryTier = .warm,
        confidence: Double = 0.5
    ) -> BASGovernedMemory {
        BASGovernedMemory(
            id: UUID(uuidString: idString)!,
            kind: .semantic,
            content: "x",
            scope: .user,
            sensitivity: .low,
            tier: tier,
            confidence: confidence,
            sourceType: "t",
            lastConfirmedAt: nil,
            decayScore: 0.0,
            governanceStatus: .governed,
            provenanceSummary: "p")
    }

    // MARK: - Atom node creation per op (4)

    func testAdmittedEventCreatesAtomNode() async throws {
        let log = BASInMemoryEventLogStorage()
        let atom = makeAtom()
        _ = try? await log.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "e1",
                timestampMs: 1,
                sessionID: "s",
                payload: BASMemoryAtomEventPayload(
                    admitted: atom)))
        let graph = BASKnowledgeGraph()
        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log, sessionID: "s", into: graph)
        let atomNodeID = "atom:\(atom.id.uuidString)"
        let node = await graph.node(forID: atomNodeID)
        XCTAssertNotNil(node)
        XCTAssertEqual(node?.kind, .atom)
    }

    func testTierChangeEventCreatesAtomNode() async throws {
        let log = BASInMemoryEventLogStorage()
        _ = try? await log.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "e1",
                timestampMs: 1,
                sessionID: "s",
                payload: BASMemoryAtomEventPayload(
                    tierChange: "atom-tier",
                    newTier: .hot)))
        let graph = BASKnowledgeGraph()
        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log, sessionID: "s", into: graph)
        let node = await graph.node(forID: "atom:atom-tier")
        XCTAssertNotNil(node)
        XCTAssertEqual(node?.kind, .atom)
    }

    func testGovernanceChangeEventCreatesAtomNode() async throws {
        let log = BASInMemoryEventLogStorage()
        _ = try? await log.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "e1",
                timestampMs: 1,
                sessionID: "s",
                payload: BASMemoryAtomEventPayload(
                    governanceChange: "atom-gov",
                    newStatus: .quarantined)))
        let graph = BASKnowledgeGraph()
        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log, sessionID: "s", into: graph)
        let node = await graph.node(forID: "atom:atom-gov")
        XCTAssertNotNil(node)
    }

    func testRemoveEventCreatesAtomNode() async throws {
        // Even .remove creates the atom node (graph records the
        // touch);downstream consumers who care can filter
        let log = BASInMemoryEventLogStorage()
        _ = try? await log.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "e1",
                timestampMs: 1,
                sessionID: "s",
                payload: BASMemoryAtomEventPayload(
                    remove: "atom-rm")))
        let graph = BASKnowledgeGraph()
        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log, sessionID: "s", into: graph)
        let node = await graph.node(forID: "atom:atom-rm")
        XCTAssertNotNil(node)
    }

    // MARK: - Mentions edge (3)

    func testMentionsEdgeFromEventToAtom() async throws {
        let log = BASInMemoryEventLogStorage()
        _ = try? await log.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "e-mentions",
                timestampMs: 1,
                sessionID: "s",
                payload: BASMemoryAtomEventPayload(
                    remove: "atom-x")))
        let graph = BASKnowledgeGraph()
        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log, sessionID: "s", into: graph)
        let edge = (await graph.allEdges()).first { $0.edgeID == "mentions:e-mentions→atom:atom-x" }
        XCTAssertNotNil(edge)
        XCTAssertEqual(edge?.kind, .mentions)
        XCTAssertEqual(
            edge?.weight,
            BASKnowledgeGraphEventExtractor
                .memoryAtomTouchesEdgeWeight)
    }

    func testMentionsEdgeUsesMemoryAtomTouchesWeight() async {
        let log = BASInMemoryEventLogStorage()
        _ = try? await log.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "e",
                timestampMs: 1,
                sessionID: "s",
                payload: BASMemoryAtomEventPayload(
                    remove: "a")))
        let graph = BASKnowledgeGraph()
        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log, sessionID: "s", into: graph)
        let edge = (await graph.allEdges()).first { $0.edgeID == "mentions:e→atom:a" }
        // Memory-atom touches use specific weight (not the
        // generic mentionsEdgeWeight)
        XCTAssertEqual(
            edge?.weight,
            BASKnowledgeGraphEventExtractor
                .memoryAtomTouchesEdgeWeight)
        XCTAssertNotEqual(
            edge?.weight,
            BASKnowledgeGraphEventExtractor.mentionsEdgeWeight,
            "M945:typed memory-atom weight,not the generic one")
    }

    func testMentionsEdgeOneEdgePerMemoryEvent() async {
        let log = BASInMemoryEventLogStorage()
        for i in 0..<3 {
            _ = try? await log.append(
                BASEventLogEntry.memoryAtomEvent(
                    eventID: "e\(i)",
                    timestampMs: Int64(i),
                    sessionID: "s",
                    payload: BASMemoryAtomEventPayload(
                        remove: "shared-atom")))
        }
        let graph = BASKnowledgeGraph()
        let result = await BASKnowledgeGraphEventExtractor
            .extract(
                from: log, sessionID: "s", into: graph)
        // 3 mentions edges (one per event) + 2 causes edges
        // (between consecutive events on same atom) + 1 atom
        // node + 3 event nodes
        let atomNode = await graph.node(
            forID: "atom:shared-atom")
        XCTAssertNotNil(atomNode)
        XCTAssertGreaterThanOrEqual(result.addedEdgeCount, 3)
    }

    // MARK: - Causes edge across same-atom events (3)

    func testCausesEdgeBetweenSequentialAtomEvents() async {
        let log = BASInMemoryEventLogStorage()
        _ = try? await log.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "first",
                timestampMs: 1,
                sessionID: "s",
                payload: BASMemoryAtomEventPayload(
                    remove: "a")))
        _ = try? await log.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "second",
                timestampMs: 2,
                sessionID: "s",
                payload: BASMemoryAtomEventPayload(
                    remove: "a")))
        let graph = BASKnowledgeGraph()
        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log, sessionID: "s", into: graph)
        let causes = (await graph.allEdges()).first { $0.edgeID == "causes:first→second" }
        XCTAssertNotNil(causes)
        XCTAssertEqual(causes?.kind, .causes)
        XCTAssertEqual(
            causes?.weight,
            BASKnowledgeGraphEventExtractor
                .memoryAtomCausesEdgeWeight)
    }

    func testNoCausesEdgeAcrossDifferentAtoms() async {
        let log = BASInMemoryEventLogStorage()
        _ = try? await log.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "ax",
                timestampMs: 1,
                sessionID: "s",
                payload: BASMemoryAtomEventPayload(
                    remove: "atom-x")))
        _ = try? await log.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "ay",
                timestampMs: 2,
                sessionID: "s",
                payload: BASMemoryAtomEventPayload(
                    remove: "atom-y")))
        let graph = BASKnowledgeGraph()
        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log, sessionID: "s", into: graph)
        let causes = (await graph.allEdges()).first { $0.edgeID == "causes:ax→ay" }
        XCTAssertNil(causes,
            "M945:no causes edge across different atoms")
    }

    func testCausesChainCoversAllConsecutivePairs() async {
        let log = BASInMemoryEventLogStorage()
        for i in 0..<4 {
            _ = try? await log.append(
                BASEventLogEntry.memoryAtomEvent(
                    eventID: "e\(i)",
                    timestampMs: Int64(i),
                    sessionID: "s",
                    payload: BASMemoryAtomEventPayload(
                        tierChange: "atom-c",
                        newTier:
                            [.hot, .warm, .cold, .hot][i])))
        }
        let graph = BASKnowledgeGraph()
        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log, sessionID: "s", into: graph)
        // Expect 3 causes edges: 0→1, 1→2, 2→3
        for (a, b) in [(0, 1), (1, 2), (2, 3)] {
            let edge = (await graph.allEdges()).first { $0.edgeID == "causes:e\(a)→e\(b)" }
            XCTAssertNotNil(
                edge,
                "Expected causes edge e\(a)→e\(b)")
        }
    }

    // MARK: - Idempotent re-extraction (2)

    func testReExtractionIsIdempotent() async {
        let log = BASInMemoryEventLogStorage()
        _ = try? await log.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "e1",
                timestampMs: 1,
                sessionID: "s",
                payload: BASMemoryAtomEventPayload(
                    remove: "a")))
        let graph = BASKnowledgeGraph()
        let r1 = await BASKnowledgeGraphEventExtractor.extract(
            from: log, sessionID: "s", into: graph)
        let r2 = await BASKnowledgeGraphEventExtractor.extract(
            from: log, sessionID: "s", into: graph)
        // Second run sees same events but graph already has
        // nodes/edges → addedNodeCount + addedEdgeCount should
        // be 0 on the second run。
        XCTAssertGreaterThan(r1.addedNodeCount, 0)
        XCTAssertEqual(r2.addedNodeCount, 0)
        XCTAssertEqual(r2.addedEdgeCount, 0)
    }

    func testReasonCodeEmittedOnlyWhenAtomEventsPresent() async {
        let log = BASInMemoryEventLogStorage()
        _ = try? await log.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "e1",
                timestampMs: 1,
                sessionID: "s",
                payload: BASMemoryAtomEventPayload(
                    remove: "a")))
        let graph = BASKnowledgeGraph()
        let r = await BASKnowledgeGraphEventExtractor.extract(
            from: log, sessionID: "s", into: graph)
        let codes = r.reasonCodes
        XCTAssertTrue(
            codes.contains { $0.contains(
                "memory-atom:events-extracted:1") },
            "M945:reason code emitted with atom event count")
    }

    // MARK: - Legacy events unchanged (2)

    func testLegacyChatEventsHaveNoAtomNodes() async {
        let log = BASInMemoryEventLogStorage()
        _ = try? await log.append(
            BASEventLogEntry(
                eventID: "c1",
                timestampMs: 1,
                kind: .chat,
                sessionID: "s",
                sequenceNumber: 0,
                project: "proj1"))
        let graph = BASKnowledgeGraph()
        let r = await BASKnowledgeGraphEventExtractor.extract(
            from: log, sessionID: "s", into: graph)
        // Should produce event node + project node + project
        // mentions edge — no atom nodes
        let codes = r.reasonCodes
        XCTAssertFalse(
            codes.contains {
                $0.contains("memory-atom:events-extracted")
            },
            "M945:no memory-atom reason code when none extracted")
    }

    func testMixedMemoryAndChatEventsExtractIndependently()
        async
    {
        let log = BASInMemoryEventLogStorage()
        _ = try? await log.append(
            BASEventLogEntry(
                eventID: "c1",
                timestampMs: 1,
                kind: .chat,
                sessionID: "s",
                sequenceNumber: 0,
                project: "px"))
        _ = try? await log.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "m1",
                timestampMs: 2,
                sessionID: "s",
                payload: BASMemoryAtomEventPayload(
                    remove: "a")))
        let graph = BASKnowledgeGraph()
        let r = await BASKnowledgeGraphEventExtractor.extract(
            from: log, sessionID: "s", into: graph)
        let projNode = await graph.node(forID: "project:px")
        let atomNode = await graph.node(forID: "atom:a")
        XCTAssertNotNil(projNode,
            "Legacy project extraction still works")
        XCTAssertNotNil(atomNode,
            "Memory-atom extraction also fired")
        XCTAssertTrue(
            r.reasonCodes.contains {
                $0.contains("memory-atom:events-extracted:1")
            })
    }
}
