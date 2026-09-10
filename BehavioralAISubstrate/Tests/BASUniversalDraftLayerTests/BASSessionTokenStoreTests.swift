import XCTest
@testable import BASOrgan

/// `BASSessionTokenStore` pools one `BASSuffixAutomaton` per conversation. These tests pin: per-session
/// accumulation + cross-turn proposal, isolation between conversations, unknown-session safety, explicit
/// clearing, and LRU bounding of the live-conversation count.
final class BASSessionTokenStoreTests: XCTestCase {

    func testCrossTurnProposalWithinASession() {
        var store = BASSessionTokenStore(ngramMin: 2, ngramMax: 3, numDraftTokens: 2, capacityPerSession: 1000)
        store.append(session: "conv-1", contentsOf: [10, 11, 12, 13, 99])  // turn 1
        store.append(session: "conv-1", contentsOf: [10, 11])              // turn 2 ends on [10,11]
        XCTAssertEqual(store.propose(session: "conv-1"), [12, 13],
            "the suffix [10,11] recurs from turn 1 → its continuation [12,13] proposed across turns")
    }

    func testSessionsAreIsolated() {
        var store = BASSessionTokenStore(ngramMin: 2, ngramMax: 2, numDraftTokens: 2, capacityPerSession: 1000)
        store.append(session: "a", contentsOf: [1, 2, 7, 1, 2])  // 'a': suffix [1,2] → [7,1]
        store.append(session: "b", contentsOf: [1, 2, 8, 1, 2])  // 'b': suffix [1,2] → [8,1]
        XCTAssertEqual(store.propose(session: "a"), [7, 1])
        XCTAssertEqual(store.propose(session: "b"), [8, 1], "conversations must not bleed into each other")
    }

    func testUnknownSessionProposesEmpty() {
        let store = BASSessionTokenStore()
        XCTAssertEqual(store.propose(session: "nope"), [])
        XCTAssertEqual(store.tokens(session: "nope"), [])
    }

    func testClearAndClearAll() {
        var store = BASSessionTokenStore(ngramMin: 2, ngramMax: 2, numDraftTokens: 2, capacityPerSession: 1000)
        store.append(session: "a", contentsOf: [1, 2, 7, 1, 2])
        store.append(session: "b", contentsOf: [3, 4, 9, 3, 4])
        store.clear(session: "a")
        XCTAssertEqual(store.propose(session: "a"), [])
        XCTAssertEqual(store.sessionCount, 1)
        store.clearAll()
        XCTAssertEqual(store.sessionCount, 0)
        XCTAssertEqual(store.propose(session: "b"), [])
    }

    func testLRUEvictionBoundsSessionCount() {
        var store = BASSessionTokenStore(ngramMin: 1, ngramMax: 2, numDraftTokens: 2,
                                         capacityPerSession: 1000, maxSessions: 2)
        store.append(session: "s1", contentsOf: [1, 2, 1, 2])
        store.append(session: "s2", contentsOf: [3, 4, 3, 4])
        store.append(session: "s3", contentsOf: [5, 6, 5, 6])  // exceeds maxSessions → evict LRU (s1)
        XCTAssertEqual(store.sessionCount, 2, "live conversations bounded by maxSessions")
        XCTAssertEqual(store.propose(session: "s1"), [], "s1 (least-recently-used) was evicted")
        XCTAssertFalse(store.propose(session: "s2").isEmpty, "s2 retained")
        XCTAssertFalse(store.propose(session: "s3").isEmpty, "s3 retained")
    }

    func testAppendingTouchesRecencySoActiveSessionSurvives() {
        var store = BASSessionTokenStore(ngramMin: 1, ngramMax: 2, numDraftTokens: 2,
                                         capacityPerSession: 1000, maxSessions: 2)
        store.append(session: "s1", contentsOf: [1, 2, 1, 2])
        store.append(session: "s2", contentsOf: [3, 4, 3, 4])
        store.append(session: "s1", contentsOf: [1, 2])         // re-activate s1 → s2 is now LRU
        store.append(session: "s3", contentsOf: [5, 6, 5, 6])   // evict LRU (s2), not s1
        XCTAssertFalse(store.propose(session: "s1").isEmpty, "recently-active s1 survives")
        XCTAssertEqual(store.propose(session: "s2"), [], "s2 became LRU and was evicted")
    }
}
