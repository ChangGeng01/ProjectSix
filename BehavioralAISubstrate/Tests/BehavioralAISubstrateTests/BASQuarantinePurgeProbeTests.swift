import XCTest
import Foundation
import BASOrgan
import BASMemory
import BASRuntimeCore
@testable import BASMLXAdapter

/// 可解释性章程③ — the quarantine-purge integration probe. DELIBERATELY EXPECTED TO FAIL on the
/// purge legs: the interpretability audit found that when an atom is quarantined, NOTHING
/// downstream observes it — usage records stay live, the cross-turn token corpus keeps the
/// content, KV spill snapshots keep the conversation. Per the charter these assertions are
/// wrapped in XCTExpectFailure: the suite stays green, the gap stays LOUD, and the day someone
/// builds the purge, the "expected failure never occurred" flip forces this file to be updated
/// consciously (never silently). Do NOT "fix" this test with a partial purge that cannot reach
/// the KV files — the red legs ARE the honest finding about the forgetting story.
final class BASQuarantinePurgeProbeTests: XCTestCase {

    func testQuarantineChainAdmitUseQuarantinePurge() async throws {
        // ── admit ──────────────────────────────────────────────────────────────────────
        let store = BASEventSourcedMemoryAtomStore(
            eventLog: BASInMemoryEventLogStorage(), sessionID: "purge-probe")
        let atom = BASGovernedMemory(
            kind: .semantic, content: "The codeword is MERIDIAN-7.",
            scope: .session, sensitivity: .high, tier: .hot,
            confidence: 0.9, sourceType: "probe",
            governanceStatus: .governed, provenanceSummary: "purge-probe fixture")
        let admitted = try await store.admit(atom)
        XCTAssertTrue(admitted, "fixture atom must admit cleanly")

        // ── use ────────────────────────────────────────────────────────────────────────
        // (1) L8 usage trail (SQLite-backed, the production shape).
        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("purge_probe_\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: dbURL) }
        let tracker = try BASMemoryUsageTracker(databaseURL: dbURL)
        let recordID = try await tracker.record(
            atomID: atom.id.uuidString, sessionRef: "probe-session",
            turnRef: "turn-1", permitMode: "grant")
        // (2) the content reaches the decode-adjacent stores, as it would in a real turn:
        var crossTurn = BASSessionTokenStore()
        crossTurn.append(session: "probe-session", contentsOf: [101, 202, 303, 404]) // content tokens
        let spillURL = MLXOrganAdapter._spillURL(forKey: "probe-session#core")
        try Data("opaque-kv-carrying-MERIDIAN-7".utf8).write(to: spillURL)
        defer { try? FileManager.default.removeItem(at: spillURL) }

        // ── quarantine ────────────────────────────────────────────────────────────────
        let changed = await store.updateGovernanceStatus(
            forID: atom.id.uuidString, to: .quarantined)
        XCTAssertTrue(changed, "governance transition must apply")
        let after = await store.atom(forID: atom.id.uuidString)
        XCTAssertEqual(after?.governanceStatus, .quarantined,
                       "the event-sourced projection DOES fold quarantine — this leg is healthy")

        // ── purge (THE GAP — every leg below is the audit's honest finding) ──────────
        // Gather the post-quarantine world state (async reads happen OUTSIDE the
        // XCTExpectFailure closure, which must stay synchronous).
        let usageRecord = await tracker.record(forID: recordID)
        let corpusTokens = crossTurn.tokens(session: "probe-session")
        let spillExists = FileManager.default.fileExists(atPath: spillURL.path)
        XCTExpectFailure(
            "已知缺口(可解释性审计③): 隔离事件没有任何下游观察者 — 使用记录不墓碑、"
            + "跨轮语料不清除、KV spill 快照不清除。修复清除链时必须有意识地更新本探针。")
        {
            // (a) the atom's usage trail should have been tombstoned on quarantine.
            XCTAssertNil(usageRecord, "quarantined atom's usage record must be tombstoned/expunged")
            // (b) the cross-turn corpus that carried the content should be purged.
            XCTAssertTrue(corpusTokens.isEmpty,
                          "cross-turn corpus still carries the quarantined content's tokens")
            // (c) the KV snapshot of the conversation should be purged.
            XCTAssertFalse(spillExists,
                           "KV spill snapshot survives quarantine — the conversation is still on disk")
        }
    }
}
