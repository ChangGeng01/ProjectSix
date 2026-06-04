// ADR-033 follow-up — CROSS-RESTART DURABLE memory. The routed MiniLM memory, when its persistence
// is wired to a FILE-BACKED `BASSQLiteMemoryAtomStore`, survives a genuine process restart: a brand-new
// store + service over the SAME sqlite file reload the self-populated atoms WITH content and reproduce
// semantic recall. This is the real-restart proof the in-process event-store test could not give
// (`BASRoutedMemoryFlipTests.testRoutedMemoryAdmitsToEventStoreAndReloadsInProcess` shares one actor +
// its content cache; the event log replays content empty per the privacy doctrine). Here the durable
// content lives in the SQLite memory store (built to hold it), so a fresh process recalls it.

import XCTest
import Foundation
@testable import BASHostKit
@testable import BASAppleAdapters
@testable import BASMemory
@testable import BASOrchestration
@testable import BASRuntimeCore

#if canImport(CoreML) && !os(iOS)
final class BASL8RoutedMemoryServiceCrossRestartTests: XCTestCase {

    private var tempURL: URL!

    override func setUpWithError() throws {
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("bas-xrestart-\(UUID().uuidString).sqlite")
    }

    override func tearDownWithError() throws {
        guard let url = tempURL else { return }
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-wal"))
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-shm"))
    }

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

    /// A genuine restart: process-1's store + service deallocate (SQLite closed/checkpointed) before
    /// process-2 opens a NEW store + service over the SAME file. Recall can only succeed if the atom
    /// CONTENT was written to disk — proving cross-restart durability (not an in-process cache).
    func testSelfPopAtomsSurviveRealProcessRestartViaSQLiteFile() async throws {
        let mini = try XCTUnwrap(BASMiniLMEmbeddingProvider())

        // ── "Process 1": write self-populated atoms to the file-backed store, then RELEASE ──────────
        do {
            let store1 = try BASSQLiteMemoryAtomStore(databaseURL: tempURL)
            let svc1 = BASL8RoutedMemoryService(
                loadAllAtoms: { (try? await store1.allAtoms()) ?? [] },
                syncEmbed: mini.syncEmbedClosure(),
                embeddingDimension: 384,
                atomStore: store1,
                selfPopulate: true,
                admitAtom: { _ = try? await store1.admit($0) })

            _ = svc1.retrieve(decomposeFrame: frame("alpine skiing in deep winter snow"),
                              hostContext: profile(), budget: budget())
            _ = svc1.retrieve(decomposeFrame: frame("ocean scuba diving on the coral reef"),
                              hostContext: profile(), budget: budget())

            let drained = await svc1.drainIntents()
            XCTAssertEqual(drained.admitted, 2,
                "both self-populated atoms admitted to the durable SQLite store")
            let written = await store1.count
            XCTAssertEqual(written, 2, "two atom rows persisted to the sqlite file")
        }   // store1 + svc1 deallocate here → sqlite closed/checkpointed (the "process restart")

        // ── "Process 2": NEW store + NEW service over the SAME file (process-1 objects are gone) ────
        let store2 = try BASSQLiteMemoryAtomStore(databaseURL: tempURL)
        let reopened = await store2.count
        XCTAssertEqual(reopened, 2, "atom rows (with content) survived the file close/reopen")

        let svc2 = BASL8RoutedMemoryService(
            loadAllAtoms: { (try? await store2.allAtoms()) ?? [] },
            syncEmbed: mini.syncEmbedClosure(),
            embeddingDimension: 384)
        await svc2.refresh()
        XCTAssertEqual(svc2.snapshotCount, 2,
            "the reborn service reloaded both persisted atoms from disk")

        // Recall proves CONTENT (not just IDs) survived → semantic recall reproduces after restart.
        let recalled = svc2.retrieve(
            decomposeFrame: frame("winter mountain snow sports"),
            hostContext: profile(), budget: budget())
        XCTAssertEqual(recalled.atoms.first?.summary, "alpine skiing in deep winter snow",
            "reloaded MiniLM memory recalls the skiing atom — content survived a real restart")
        XCTAssertFalse(recalled.atoms.contains { $0.summary == "ocean scuba diving on the coral reef" },
            "the unrelated diving atom stays below the relevance floor")
    }
}
#endif
