// ADR-033 Step-2 flip — the brain's default L8 memory becomes a self-populating routed VECTOR
// backend (MiniLM, on-device) when a sync embedder is injected; legacy BASMLMemoryService when not
// (byte-equal-off / R1). The test target is the "host" (it sees both BASHostKit + BASAppleAdapters),
// so it wires MiniLM exactly as a real app would.

import XCTest
import Foundation
@testable import BASHostKit
@testable import BASAppleAdapters
@testable import BASMemory
@testable import BASOrchestration
@testable import BASRuntimeCore

#if canImport(CoreML) && !os(iOS)
final class BASRoutedMemoryFlipTests: XCTestCase {

    private func budget() -> BASBudgetFrame {
        BASBudgetFrame(
            runMode: .guard, maxLoops: 2, maxCandidates: 2, maxDecodeTokens: 180,
            retrievalDepth: 3, precisionProfile: .protected, deviceRoute: .hybridLocal,
            thermalGuardLevel: .watch, maintenanceAllowed: false)
    }
    private func profile() -> BASHostProfile { BASHostProfile(hostID: "test") }
    private func frame(_ text: String) -> BASDecomposeFrame {
        var f = BASDecomposeFrame(); f.mirrorText = text; return f
    }

    // MARK: - byte-equal-off: no embedder ⇒ legacy memory (R1)

    func testResolveMemoryServiceDefaultsToLegacyWhenNoEmbedder() {
        XCTAssertTrue(
            BASCognitiveBrain.resolveMemoryService(memoryEmbed: nil, dim: 384) is BASMLMemoryService,
            "no embedder ⇒ legacy in-memory Jaccard (byte-equal-off)")
        XCTAssertTrue(
            BASCognitiveBrain.resolveMemoryService(memoryEmbed: { _ in [0, 1, 2] }, dim: 3)
                is BASL8RoutedMemoryService,
            "a sync embedder ⇒ routed vector backend (the flip)")
    }

    // MARK: - self-population + MiniLM semantic recall

    func testRoutedMiniLMSelfPopulatesAndRecallsSemanticNeighbor() throws {
        let mini = try XCTUnwrap(BASMiniLMEmbeddingProvider())
        let svc = BASL8RoutedMemoryService(
            loadAllAtoms: { [] }, syncEmbed: mini.syncEmbedClosure(),
            embeddingDimension: 384, selfPopulate: true)

        // turn 1: fresh ⇒ nothing to recall; self-populates the frame.
        let r1 = svc.retrieve(
            decomposeFrame: frame("mountains hiking trails"),
            hostContext: profile(), budget: budget())
        XCTAssertTrue(r1.atoms.isEmpty, "turn 1 has nothing to recall yet")
        XCTAssertEqual(svc.snapshotCount, 1)

        // turn 2: a SEMANTICALLY RELATED frame ⇒ recalls turn 1 (vector cosine ≥ floor).
        let r2 = svc.retrieve(
            decomposeFrame: frame("hiking in the mountains"),
            hostContext: profile(), budget: budget())
        XCTAssertEqual(svc.snapshotCount, 2)
        XCTAssertFalse(r2.atoms.isEmpty, "turn 2 recalls the semantically-related turn-1 frame")
        XCTAssertEqual(r2.atoms.first?.summary, "mountains hiking trails")
    }

    func testRoutedMiniLMDropsUnrelatedMemory() throws {
        let mini = try XCTUnwrap(BASMiniLMEmbeddingProvider())
        let svc = BASL8RoutedMemoryService(
            loadAllAtoms: { [] }, syncEmbed: mini.syncEmbedClosure(),
            embeddingDimension: 384, selfPopulate: true)
        _ = svc.retrieve(decomposeFrame: frame("mountains hiking trails"),
                         hostContext: profile(), budget: budget())
        let r = svc.retrieve(decomposeFrame: frame("quarterly stock market earnings report"),
                             hostContext: profile(), budget: budget())
        XCTAssertTrue(r.atoms.isEmpty,
            "an unrelated frame must fall below the relevance floor (no false recall)")
    }

    // MARK: - the flip wired end-to-end through the brain

    func testMiniLMBackedBrainConstructsAndProcesses() async throws {
        let mini = try XCTUnwrap(BASMiniLMEmbeddingProvider())
        let brain = try await BASCognitiveBrain.makeWithDefaults(
            memoryEmbed: mini.syncEmbedClosure())
        // a couple of turns through the real cascade — the routed memory runs + self-populates;
        // the turn completes with a sovereign verdict (the flip didn't break the main chain).
        _ = await brain.process("I love hiking in the mountains")
        let result = await brain.process("tell me about mountain trails")
        XCTAssertNotNil(result.sovereignVerdict,
            "the MiniLM-routed brain still produces a sovereign verdict")
    }

    // MARK: - #1 persistence: self-pop → admit → an event-sourced store persists + emits a
    //         provenance event per atom, and a fresh service reloads it IN-PROCESS.
    //   HONEST SCOPE: this proves admit → persist → provenance-events → reload → recall WITHIN one
    //   process. It is NOT cross-restart durability: the `reborn` service reads the SAME `store`
    //   actor, whose in-process `contentCache` still holds the atom content. A genuine new process
    //   projecting from the event log alone would get empty content (the reducer hard-codes
    //   `content: ""` — privacy doctrine) and would NOT recall. True restart durability needs the
    //   host to persist content out-of-band.

    func testRoutedMemoryAdmitsToEventStoreAndReloadsInProcess() async throws {
        let mini = try XCTUnwrap(BASMiniLMEmbeddingProvider())
        let eventLog = BASInMemoryEventLogStorage()
        let store = BASEventSourcedMemoryAtomStore(
            eventLog: eventLog, sessionID: "routed-persist")

        let svc = BASL8RoutedMemoryService(
            loadAllAtoms: { await store.allAtoms() },
            syncEmbed: mini.syncEmbedClosure(),
            embeddingDimension: 384,
            atomStore: store,
            selfPopulate: true,
            admitAtom: { _ = try? await store.admit($0) })

        // two self-populating turns — each queues a durable-admit intent (NOT yet flushed).
        _ = svc.retrieve(decomposeFrame: frame("alpine skiing in deep winter snow"),
                         hostContext: profile(), budget: budget())
        _ = svc.retrieve(decomposeFrame: frame("ocean scuba diving on the coral reef"),
                         hostContext: profile(), budget: budget())

        // flush → durable admit; each admit appends a replayable provenance event to the store.
        let drained = await svc.drainIntents()
        XCTAssertEqual(drained.admitted, 2,
            "both self-populated atoms are admitted to the durable store at drain")

        let persisted = await store.allAtoms()
        XCTAssertEqual(persisted.count, 2, "the event-sourced store persisted both atoms")
        let events = await eventLog.events(forSession: "routed-persist")
        XCTAssertGreaterThanOrEqual(events.count, 2,
            "each admit emitted a replayable provenance event (the event/log/provenance trail)")

        // a FRESH service reloads the persisted atoms via loadAllAtoms (IN-PROCESS — same store
        // actor, whose content cache is still warm; this is NOT a cross-process restart)…
        let reborn = BASL8RoutedMemoryService(
            loadAllAtoms: { await store.allAtoms() },
            syncEmbed: mini.syncEmbedClosure(), embeddingDimension: 384)
        await reborn.refresh()
        XCTAssertEqual(reborn.snapshotCount, 2, "the fresh service reloaded both persisted atoms")

        // …and still recalls the semantically-related one (content survived in-process).
        let recalled = reborn.retrieve(
            decomposeFrame: frame("winter mountain snow sports"),
            hostContext: profile(), budget: budget())
        XCTAssertEqual(recalled.atoms.first?.summary, "alpine skiing in deep winter snow",
            "the reloaded MiniLM memory recalls the skiing atom (not the diving atom)")
    }

    // MARK: - #2 the routed + self-populate path is itself deterministic. The byte-equal/replay
    //         suites only exercise the stub coordinator, never this backend's own state machine,
    //         so this pins the self-pop counter IDs + cosine ordering directly (hermetic: lexical).

    func testRoutedSelfPopulatePathIsDeterministic() {
        func recallSequence() -> [[String]] {
            let svc = BASL8RoutedMemoryService(
                loadAllAtoms: { [] },
                syncEmbed: BASL8RoutedMemoryService.lexicalEmbed(),
                embeddingDimension: BASL8RoutedMemoryService.Parameters.defaultLexicalDimension,
                selfPopulate: true)
            let frames = ["weather is sunny today", "the weather forecast looks sunny",
                          "quarterly stock market earnings", "sunny weather again tomorrow"]
            return frames.map { text in
                svc.retrieve(decomposeFrame: frame(text), hostContext: profile(), budget: budget())
                    .atoms.map(\.memoryID)
            }
        }
        let a = recallSequence()
        let b = recallSequence()
        XCTAssertEqual(a, b,
            "the routed self-populate path (counter IDs + cosine ordering) is deterministic")
        XCTAssertTrue(a.contains { !$0.isEmpty },
            "the sequence actually recalls something — the determinism check is non-vacuous")
    }

    // MARK: - HOST-DRIVEN persistence through the brain's public API (closes the audit gap that
    //         persistence was an unconsumed API unreachable from `brain.process()`).
    //   A real host wires `memoryPersistence` into `makeWithDefaults`, runs turns, then drives the
    //   brain's `drainMemoryIntents()` seam at a session boundary → self-populated atoms genuinely
    //   persist to a `BASEventSourcedMemoryAtomStore` (one provenance event each). This exercises
    //   the WHOLE public path (brain hook → routed service → store), not the service in isolation.
    //   (Durability is still in-process — the event log replays content empty; that is a separate
    //   item. This test proves REACHABILITY + host-driven flush, the thing that was missing.)

    func testBrainHostDrivenPersistenceDrainsToEventStore() async throws {
        let mini = try XCTUnwrap(BASMiniLMEmbeddingProvider())
        let eventLog = BASInMemoryEventLogStorage()
        let store = BASEventSourcedMemoryAtomStore(
            eventLog: eventLog, sessionID: "brain-host-persist")
        let persistence = BASRoutedMemoryPersistence(
            loadAllAtoms: { await store.allAtoms() },
            admitAtom: { _ = try? await store.admit($0) },
            atomStore: store)

        // real host wiring: MiniLM embedder + the durable persistence hook, through makeWithDefaults.
        let brain = try await BASCognitiveBrain.makeWithDefaults(
            memoryEmbed: mini.syncEmbedClosure(),
            memoryPersistence: persistence)

        // a few turns — each self-populates the routed memory (queued for a durable admit).
        _ = await brain.process("I love hiking in the mountains")
        _ = await brain.process("tell me about alpine ski trails")
        _ = await brain.process("the ocean is calm today")

        // PERSISTENCE IS HOST-DRIVEN: process() only QUEUES — nothing is in the store yet.
        let beforeDrain = await store.allAtoms()
        XCTAssertTrue(beforeDrain.isEmpty,
            "process() queues but does not persist — the brain never auto-drives drainIntents()")

        // the host drives the session-boundary flush through the brain's PUBLIC API.
        let drained = await brain.drainMemoryIntents()
        XCTAssertGreaterThan(drained.admitted, 0,
            "the brain hook admitted the self-populated atoms to the durable store")

        let persisted = await store.allAtoms()
        XCTAssertEqual(persisted.count, drained.admitted,
            "every atom the brain admitted is in the event-sourced store's projection")
        let events = await eventLog.events(forSession: "brain-host-persist")
        XCTAssertGreaterThanOrEqual(events.count, drained.admitted,
            "each admit emitted a replayable provenance event (the event/log/provenance trail)")

        // a default brain (no embedder) has no routed backend → the hook is a safe no-op (R1).
        let legacyBrain = try await BASCognitiveBrain.makeWithDefaults()
        _ = await legacyBrain.process("hello")
        let legacyDrain = await legacyBrain.drainMemoryIntents()
        XCTAssertEqual(legacyDrain.admitted, 0,
            "the legacy/byte-equal-off brain has no routed memory — drainMemoryIntents is a no-op")
    }
}
#endif
