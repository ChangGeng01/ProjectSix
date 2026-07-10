import XCTest
@testable import BASSovereign

/// M296.3.zz CRDT — LWW-element-set strategy contract tests.
///
/// Doctrine pinned:
/// - kind == .crdt
/// - Same auditEntryRef, causal-ordered → causal-later wins
/// - Same auditEntryRef, concurrent → origin ASC tiebreak
/// - Different auditEntryRefs → all preserved
/// - Older versions discarded (LWW property)
/// - Empty / single-side scenarios
final class BASSovereignLWWElementSetStrategyTests: XCTestCase {

    private func makeFrame(
        ref: String,
        device: String,
        counters: [String: UInt64]
    ) -> BASSovereignCrossDeviceLedgerFrame {
        BASSovereignCrossDeviceLedgerFrame(
            auditEntryRef: ref,
            originDeviceID: device,
            clock: BASSovereignCrossDeviceClock(
                deviceCounters: counters))
    }

    // MARK: - Kind tag

    func test_kindIsCRDT() {
        let s = BASSovereignLWWElementSetStrategy()
        XCTAssertEqual(s.kind, .crdt)
    }

    // MARK: - Empty / single-side

    func test_emptyEmpty_returnsEmpty() async {
        let s = BASSovereignLWWElementSetStrategy()
        let result = await s.sync(local: [], remote: [])
        XCTAssertEqual(result, [])
    }

    func test_singleFrame_passesThrough() async {
        let s = BASSovereignLWWElementSetStrategy()
        let f = makeFrame(
            ref: "x", device: "A", counters: ["A": 1])
        let result = await s.sync(local: [f], remote: [])
        XCTAssertEqual(result, [f])
    }

    // MARK: - Causal LWW

    func test_sameRef_causalLaterWins() async {
        let s = BASSovereignLWWElementSetStrategy()
        let earlier = makeFrame(
            ref: "x", device: "A", counters: ["A": 1])
        let later = makeFrame(
            ref: "x", device: "A", counters: ["A": 5])
        let result = await s.sync(
            local: [earlier], remote: [later])
        XCTAssertEqual(result, [later])
    }

    func test_sameRef_causalLaterWinsIrrespectiveOfInputOrder()
        async
    {
        let s = BASSovereignLWWElementSetStrategy()
        let earlier = makeFrame(
            ref: "x", device: "A", counters: ["A": 1])
        let later = makeFrame(
            ref: "x", device: "A", counters: ["A": 5])
        let resultA = await s.sync(
            local: [later], remote: [earlier])
        let resultB = await s.sync(
            local: [earlier], remote: [later])
        XCTAssertEqual(resultA, [later])
        XCTAssertEqual(resultB, [later])
    }

    // MARK: - Concurrent tiebreak

    func test_sameRef_concurrent_originAscTiebreak() async {
        let s = BASSovereignLWWElementSetStrategy()
        // A ahead on A, B ahead on B → concurrent.
        let frameA = makeFrame(
            ref: "x", device: "A",
            counters: ["A": 5, "B": 1])
        let frameB = makeFrame(
            ref: "x", device: "B",
            counters: ["A": 1, "B": 5])
        let result = await s.sync(
            local: [frameA], remote: [frameB])
        XCTAssertEqual(result.count, 1)
        // Origin ASC: A < B → A wins.
        XCTAssertEqual(result[0].originDeviceID, "A")
    }

    // MARK: - audit blindspot-CRDT: intransitive-fold winner divergence

    /// The 3-frame group the old single-pass fold could not resolve deterministically: P dominates Q
    /// (causal), R concurrent with both, with an origin-tiebreak cycle. The old fold picked R for
    /// input order [P,Q,R] but P for [Q,R,P] — two devices with the same group chose DIFFERENT LWW
    /// winners (divergence), and P is causally DOMINATED (not even latest). pickLatest must return the
    /// same winner for every input order = the origin-min of the causally-MAXIMAL set (R). Reversal
    /// (restore the single-pass fold) reds.
    func test_intransitiveGroup_sameWinnerRegardlessOfInputOrder() {
        let p = makeFrame(ref: "r1", device: "C", counters: ["A": 1, "C": 1])  // dominates q
        let q = makeFrame(ref: "r1", device: "A", counters: ["A": 1])          // dominated by p
        let r = makeFrame(ref: "r1", device: "B", counters: ["B": 1])          // concurrent with both
        XCTAssertEqual(p.compare(to: q), .after, "sanity: p causally dominates q")
        XCTAssertEqual(r.compare(to: p), .concurrent)
        XCTAssertEqual(r.compare(to: q), .concurrent)

        let perms: [[BASSovereignCrossDeviceLedgerFrame]] = [
            [p, q, r], [q, r, p], [r, p, q], [q, p, r], [r, q, p], [p, r, q],
        ]
        let winners = perms.map { BASSovereignLWWElementSetStrategy.pickLatest(among: $0) }
        for (i, w) in winners.enumerated() {
            XCTAssertEqual(w, winners[0],
                "pickLatest must be a pure function of the group — order \(i) picked a different "
                + "winner, so two devices would diverge on the same ref")
        }
        // The winner is the origin-min of the maximal set {p,r} = r ("B" < "C"); NOT the dominated q.
        XCTAssertEqual(winners[0]?.originDeviceID, "B",
            "winner must be the origin-min of the causally-maximal set (r), never the dominated q")
    }

    // MARK: - Different refs preserved

    func test_differentRefs_allPreserved() async {
        let s = BASSovereignLWWElementSetStrategy()
        let x = makeFrame(
            ref: "x", device: "A", counters: ["A": 1])
        let y = makeFrame(
            ref: "y", device: "B", counters: ["B": 1])
        let z = makeFrame(
            ref: "z", device: "C", counters: ["C": 1])
        let result = await s.sync(
            local: [x, y], remote: [z])
        XCTAssertEqual(Set(result.map(\.auditEntryRef)),
                       ["x", "y", "z"])
    }

    // MARK: - Older versions discarded (LWW property)

    func test_olderVersionsDiscarded() async {
        let s = BASSovereignLWWElementSetStrategy()
        let v1 = makeFrame(
            ref: "x", device: "A", counters: ["A": 1])
        let v2 = makeFrame(
            ref: "x", device: "A", counters: ["A": 2])
        let v3 = makeFrame(
            ref: "x", device: "A", counters: ["A": 3])
        let result = await s.sync(
            local: [v1, v2], remote: [v3])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], v3)
    }

    // MARK: - Mixed scenario

    func test_mixedScenario_perRefLatestWins_othersPreserved()
        async
    {
        let s = BASSovereignLWWElementSetStrategy()
        let xV1 = makeFrame(
            ref: "x", device: "A", counters: ["A": 1])
        let xV2 = makeFrame(
            ref: "x", device: "A", counters: ["A": 5])
        let yOnly = makeFrame(
            ref: "y", device: "B", counters: ["B": 3])
        let zV1 = makeFrame(
            ref: "z", device: "C", counters: ["C": 1])
        let zV2concurrent = makeFrame(
            ref: "z", device: "D", counters: ["D": 1])
        let result = await s.sync(
            local: [xV1, yOnly, zV1],
            remote: [xV2, zV2concurrent])
        // x: V2 wins (causal later)
        // y: only one, kept
        // z: concurrent → origin ASC tiebreak (C < D → C wins)
        XCTAssertEqual(result.count, 3)
        let xWinner = result.first {
            $0.auditEntryRef == "x"
        }
        XCTAssertEqual(xWinner, xV2)
        let zWinner = result.first {
            $0.auditEntryRef == "z"
        }
        XCTAssertEqual(zWinner?.originDeviceID, "C")
    }

    // MARK: - Existential dispatch

    func test_strategyUsableThroughExistential() async {
        let strategy: any BASSovereignFragmentSyncStrategy =
            BASSovereignLWWElementSetStrategy()
        let result = await strategy.sync(
            local: [], remote: [])
        XCTAssertEqual(result, [])
        XCTAssertEqual(strategy.kind, .crdt)
    }
}
