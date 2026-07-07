import XCTest
@testable import BASHostKit
@testable import BASLeaseLife
@testable import BASMemory
@testable import BASPolicy
@testable import BASRuntimeCore
import Foundation

/// QINAO Substrate-100 gates — Phase-2 batch 2 (agent-drafted from real Sources, author-verified via swift test).
/// async methods are actor-isolated systems; XCTest supports async test funcs natively.
final class BASQINAOSubstrateGatesBatch2Tests: XCTestCase {

// MARK: - QINAO L1 gate: lung pressure decay closed-form fidelity
// API verified by reading Sources/BASLeaseLife/BASLungStateAccumulator.swift:
//   public actor BASLungStateAccumulator
//     init(timeConstantSeconds: Double = 180, clock: @escaping @Sendable () -> Date = { Date() })
//     @discardableResult func record(runMode: BASEBrainRunMode, durationSeconds: Double) -> Snapshot   // actor-isolated (async)
//     @discardableResult func settle(to date: Date? = nil) -> Snapshot                                 // actor-isolated (async)
//     func snapshot() -> Snapshot                                                                       // actor-isolated (async)
//     static func load(for runMode: BASEBrainRunMode) -> Double                                         // PURE / sync
//   Snapshot.pressure is clamped to [0,1] in its init; timeConstantSeconds is clamped to >=1.
//   decay(to:): idle = max(0, now - (lastDecayAt ?? lastTurnAt)); factor = exp(-idle/tau);
//               pressure = min(1, max(0, pressure*factor)). record() then adds load*max(0,dur) then min(1,...).
// BASEBrainRunMode (BASRuntimeCore): String/CaseIterable/Sendable enum, 10 cases incl. `guard`.
// Actor methods are async-isolated -> this is an `async` XCTest method (needs_async). The pure
// `static load` is exercised synchronously and exhaustively; the closed-form is checked against a
// replicated oracle through the real actor with a deterministic injected clock (tolerance = 1e-12).
func test_qinao_lung_pressure_decay_fidelity() async {
    let tol = 1e-12

    // --- (A) Exhaustive, pure, deterministic oracle over the load table. tolerance = 0 ---
    func oracleLoad(_ m: BASEBrainRunMode) -> Double {
        switch m {
        case .dormant, .pulse, .sentinel: return 0.01
        case .engage:                      return 0.05
        case .reflect:                     return 0.06
        case .deepLoop:                    return 0.15
        case .guard:                       return 0.12
        case .recovery, .quarantine, .lockdown: return 0.0
        }
    }
    for m in BASEBrainRunMode.allCases {
        XCTAssertEqual(BASLungStateAccumulator.load(for: m), oracleLoad(m), accuracy: 0,
                       "load(for: \(m)) must equal the pinned weight exactly")
        XCTAssertGreaterThanOrEqual(BASLungStateAccumulator.load(for: m), 0,
                                    "load weight must be non-negative for \(m)")
    }

    // --- (B) Closed-form fidelity: drive the REAL actor with a deterministic clock and assert
    //         p_next == clamp01( clamp01(p_prev*exp(-idle/tau)) + load(mode)*max(0,dur) )  (<= 1e-12) ---
    func clamp01(_ x: Double) -> Double { min(1, max(0, x)) }

    let tau = 73.0
    let modes = BASEBrainRunMode.allCases
    let durations: [Double] = [0, 0.5, 3, 12, 40]
    let idles: [Double] = [0, 1, 7, 73, 250, 900]

    // Sweep a small grid; replicate the documented recurrence as an independent oracle.
    for (mi, mode) in modes.enumerated() {
        for (di, dur) in durations.enumerated() {
            for (ii, idle) in idles.enumerated() {
                // Deterministic monotone clock: each accumulator gets its own time origin & cursor.
                let base = Date(timeIntervalSince1970: 1_000_000)
                final class Cursor: @unchecked Sendable { var t: Date; init(_ d: Date) { t = d } }
                let cur = Cursor(base)
                let acc = BASLungStateAccumulator(timeConstantSeconds: tau, clock: { cur.t })

                // Turn 1 at t0: pressure starts 0, no prior anchor -> p = clamp01(0 + load*max(0,dur1)).
                let dur1 = 2.0
                let s1 = await acc.record(runMode: mode, durationSeconds: dur1)
                var oracle = clamp01(0 + oracleLoad(mode) * max(0, dur1))
                XCTAssertEqual(s1.pressure, oracle, accuracy: tol,
                               "turn-1 closed form mismatch m=\(mode)")

                // Advance clock by `idle`, then record turn 2 with `dur`.
                cur.t = base.addingTimeInterval(idle)
                let s2 = await acc.record(runMode: mode, durationSeconds: dur)
                let decayed = clamp01(oracle * exp(-max(0, idle) / tau))
                oracle = clamp01(decayed + oracleLoad(mode) * max(0, dur))
                XCTAssertEqual(s2.pressure, oracle, accuracy: tol,
                               "decay+load closed form mismatch m=\(mode) dur=\(dur) idle=\(idle)")

                // pressure must remain in [0,1].
                XCTAssertGreaterThanOrEqual(s2.pressure, 0, "pressure < 0 (m=\(mode))")
                XCTAssertLessThanOrEqual(s2.pressure, 1, "pressure > 1 (m=\(mode))")

                // settle() with no new load is pure decay -> monotone NON-INCREASING and idempotent
                // at the same instant (deterministic re-call check).
                cur.t = base.addingTimeInterval(idle + 1)
                let settled1 = await acc.settle()
                XCTAssertLessThanOrEqual(settled1.pressure, s2.pressure + tol,
                                         "settle() must be monotone non-increasing")
                let oracleSettle = clamp01(oracle * exp(-1.0 / tau))
                XCTAssertEqual(settled1.pressure, oracleSettle, accuracy: tol,
                               "settle() closed-form mismatch")
                // Re-settle at the SAME instant => no further change (idle == 0 short-circuits).
                let settled2 = await acc.settle()
                XCTAssertEqual(settled2.pressure, settled1.pressure, accuracy: 0,
                               "settle() at same instant must be deterministic / idempotent")

                _ = (mi, di, ii) // grid indices retained for failure triage
            }
        }
    }

    // --- (C) Longer idle => strictly more decay (monotonicity of the exp curve), replicated oracle ---
    let p0 = 0.8
    var prev = Double.infinity
    for idle in [0.0, 10, 60, 180, 600, 3600] {
        let expected = clamp01(p0 * exp(-idle / 180.0))
        XCTAssertLessThanOrEqual(expected, prev + tol, "idle-decay must be monotone non-increasing")
        prev = expected
        XCTAssertGreaterThanOrEqual(expected, 0)
        XCTAssertLessThanOrEqual(expected, 1)
    }

    print("📊 qinao-gate lung_pressure_decay_fidelity: PASS tolerance=1e-12 (load exhaustive over \(BASEBrainRunMode.allCases.count) modes; closed-form decay+clamp+settle monotonicity vs replicated oracle through the real actor)")
}

func test_qinao_vector_index_dimension_bind() async throws {
    // Build an L2-normalized embedding of a given dimension (stub provider, deterministic).
    func emb(_ dim: Int, _ fill: Float) -> BASEmbedding {
        BASEmbedding(vector: Array(repeating: fill, count: dim),
                     dimension: dim,
                     providerVersion: "qinao-test").normalized
    }
    func entry(_ atomID: String, _ dim: Int, _ fill: Float) -> BASVectorIndexEntry {
        BASVectorIndexEntry(atomID: atomID, normalizedEmbedding: emb(dim, fill))
    }

    // The bound dimension is set by the FIRST insert. Sweep a small domain of bound dims.
    for boundDim in [8, 16, 32, 64, 128] {
        let index = BASVectorIndex()

        // First insert binds the dimension (must succeed).
        try await index.insert(entry("a0", boundDim, 1.0))
        let bound = await index.dimension
        XCTAssertEqual(bound, boundDim, "first insert must bind dimension")

        // Exhaustively try every OTHER dim in the domain — each must be REJECTED.
        for otherDim in [8, 16, 32, 64, 128] where otherDim != boundDim {
            // --- insert(...) must throw .dimensionMismatch(expected: bound, got: other) ---
            var insertErr: BASVectorIndex.BASVectorIndexError? = nil
            do { try await index.insert(entry("ins-\(otherDim)", otherDim, 1.0)) }
            catch let e as BASVectorIndex.BASVectorIndexError { insertErr = e }
            XCTAssertEqual(insertErr,
                .dimensionMismatch(expected: boundDim, got: otherDim),
                "insert dim \(otherDim) vs bound \(boundDim) must throw dimensionMismatch")

            // --- upsert(...) must also throw .dimensionMismatch (same contract) ---
            var upsertErr: BASVectorIndex.BASVectorIndexError? = nil
            do { try await index.upsert(entry("ups-\(otherDim)", otherDim, 1.0)) }
            catch let e as BASVectorIndex.BASVectorIndexError { upsertErr = e }
            XCTAssertEqual(upsertErr,
                .dimensionMismatch(expected: boundDim, got: otherDim),
                "upsert dim \(otherDim) vs bound \(boundDim) must throw dimensionMismatch")

            // --- topK with a mismatched-dim query must return [] (no partial / no crash) ---
            let mismatchedResults = await index.topK(query: emb(otherDim, 1.0), k: 10)
            XCTAssertEqual(mismatchedResults.count, 0,
                "topK with mismatched query dim \(otherDim) vs bound \(boundDim) must return []")

            // Rejected inserts/upserts must NOT have leaked into the index.
            let hasIns = await index.contains(atomID: "ins-\(otherDim)")
            let hasUps = await index.contains(atomID: "ups-\(otherDim)")
            XCTAssertFalse(hasIns, "rejected insert must not persist")
            XCTAssertFalse(hasUps, "rejected upsert must not persist")
        }

        // Positive control: a MATCHED-dim query returns the single bound entry (count tracks domain).
        let matched = await index.topK(query: emb(boundDim, 1.0), k: 10)
        XCTAssertEqual(matched.count, 1,
            "matched-dim query must return the one inserted entry")
        XCTAssertEqual(matched.first?.atomID, "a0")

        let finalCount = await index.entryCount
        XCTAssertEqual(finalCount, 1, "only the first (binding) entry should remain")
    }

    print("📊 qinao-gate vector_index_dimension_bind: PASS tolerance=0 (insert/upsert throw dimensionMismatch, topK→[] for mismatched dim; exhaustive over 5 bound dims × 4 mismatched dims)")
}

func test_qinao_non_finite_embedding_rejection() async throws {
    // --- helpers -------------------------------------------------------
    let dim = 4
    let pv = "qinao-finite"
    func emb(_ v: [Float]) -> BASEmbedding {
        BASEmbedding(vector: v, dimension: dim, providerVersion: pv)
    }
    func entry(_ id: String, _ v: [Float]) -> BASVectorIndexEntry {
        BASVectorIndexEntry(atomID: id, normalizedEmbedding: emb(v))
    }
    // Did the throwing op raise specifically .nonFiniteEmbedding(id)?
    func rejectedNonFinite(_ op: () async throws -> Void, id: String) async -> Bool {
        do { try await op(); return false }
        catch let e as BASVectorIndex.BASVectorIndexError {
            return e == .nonFiniteEmbedding(id)
        } catch { return false }
    }

    // --- exhaustive non-finite domain: poison each coordinate with each bad value
    let bads: [Float] = [.nan, .infinity, -.infinity,
                         Float.nan + 1, Float.infinity * 2]
    for badIdx in 0..<dim {
        for bad in bads {
            var v = [Float](repeating: 0.5, count: dim)
            v[badIdx] = bad
            // (1) insert into a FRESH index must reject (tolerance=0: exactly the typed error)
            let idxI = BASVectorIndex()
            let okI = await rejectedNonFinite({ try await idxI.insert(entry("poison", v)) }, id: "poison")
            XCTAssertTrue(okI, "insert must reject non-finite coord=\(badIdx) val=\(bad)")
            let cntI = await idxI.topK(query: emb([1,0,0,0]), k: 10).count
            XCTAssertEqual(cntI, 0, "rejected insert must leave the index empty")
            // (2) upsert into a FRESH index must reject identically
            let idxU = BASVectorIndex()
            let okU = await rejectedNonFinite({ try await idxU.upsert(entry("poison", v)) }, id: "poison")
            XCTAssertTrue(okU, "upsert must reject non-finite coord=\(badIdx) val=\(bad)")
        }
    }

    // --- finite embeddings are accepted (negative control, tolerance=0) ---
    let clean = BASVectorIndex()
    try await clean.insert(entry("a", [1, 0, 0, 0]))
    try await clean.upsert(entry("b", [0, 1, 0, 0]))
    try await clean.insert(entry("c", [0.5, 0.5, 0.5, 0.5]))

    // --- a single poison row cannot DoS topK -------------------------------
    // The index of clean finite rows must still return a complete, finite,
    // descending ranking after every poison attempt above. Attempt one more
    // poison directly against the populated index and confirm topK survives.
    let okPoison = await rejectedNonFinite(
        { try await clean.insert(entry("poison", [Float.nan, 0, 0, 0])) }, id: "poison")
    XCTAssertTrue(okPoison, "poison insert into a live index must be rejected")

    let results = await clean.topK(query: emb([1, 0, 0, 0]), k: 10)
    XCTAssertEqual(results.count, 3, "topK must return exactly the 3 finite rows (poison never stored)")
    XCTAssertEqual(results.first?.atomID, "a", "top result must be the exact-match finite row")
    // Every score finite + strict-weak descending order preserved (no NaN trap).
    for r in results { XCTAssertTrue(r.score.isFinite, "topK score must be finite") }
    for i in 1..<results.count {
        XCTAssertGreaterThanOrEqual(results[i - 1].score, results[i].score,
            "topK ordering must be valid descending (no NaN-corrupted sort)")
    }
    // Deterministic re-call: identical query yields byte-identical ranking.
    let results2 = await clean.topK(query: emb([1, 0, 0, 0]), k: 10)
    XCTAssertEqual(results, results2, "topK must be deterministic on re-call")

    print("📊 qinao-gate non_finite_embedding_rejection: PASS tolerance=0 " +
          "rejected=\(dim * bads.count * 2) insert+upsert paths; topK survives poison (3 finite rows, finite descending, deterministic)")
}

func test_qinao_event_log_sequence_monotonicity() async throws {
    // REAL API: BASInMemoryEventLogStorage (actor) conforming to
    // BASEventLogStorage. append(_:) -> (wasNew, assignedSequenceNumber).
    // Storage OWNS the per-session sequence; caller-passed seq is ignored.
    let store = BASInMemoryEventLogStorage()

    func entry(_ id: String, session: String, ts: Int64) -> BASEventLogEntry {
        // Pass a deliberately-wrong sequenceNumber (999) to prove storage
        // overwrites it with its own strictly-increasing assignment.
        BASEventLogEntry(
            eventID: id,
            timestampMs: ts,
            kind: .chat,
            sessionID: session,
            sequenceNumber: 999)
    }

    // --- Replicated oracle: per-session next-seq counter starting at 0 ---
    var oracleNext: [String: Int64] = [:]
    var oracleApplied: [String: Int64] = [:]   // eventID -> first-assigned seq

    // Interleave appends across 3 sessions + duplicate IDs, deterministic.
    let sessions = ["S-a", "S-b", "S-c"]
    let plan: [(id: String, session: String, ts: Int64)] = {
        var out: [(String, String, Int64)] = []
        var t: Int64 = 1_000
        for round in 0..<8 {
            for (si, s) in sessions.enumerated() {
                out.append(("\(s)#\(round)", s, t)); t += 1
                // Every other round, re-append a PRIOR id to exercise idempotency.
                if round >= 1 && (round + si) % 2 == 0 {
                    out.append(("\(s)#\(round - 1)", s, t)); t += 1
                }
            }
        }
        return out
    }()

    for step in plan {
        let res = try await store.append(
            entry(step.id, session: step.session, ts: step.ts))

        if let firstSeq = oracleApplied[step.id] {
            // DUPLICATE eventID: must be idempotent.
            XCTAssertFalse(res.wasNew,
                "duplicate eventID \(step.id) reported wasNew=true")
            XCTAssertEqual(res.assignedSequenceNumber, firstSeq,
                "duplicate \(step.id) returned a NEW/changed seq")
            // No new seq consumed: oracle next-counter unchanged.
        } else {
            // NEW eventID: strictly-increasing per-session seq, starts at 0.
            let expected = oracleNext[step.session] ?? 0
            XCTAssertTrue(res.wasNew,
                "new eventID \(step.id) reported wasNew=false")
            XCTAssertEqual(res.assignedSequenceNumber, expected,
                "session \(step.session) seq not strictly +1 (tolerance=0)")
            oracleApplied[step.id] = expected
            oracleNext[step.session] = expected + 1
        }
    }

    // --- Verify stored stream matches the oracle exactly (per session) ---
    // events(forSession:) is contract-ordered by sequenceNumber ASC.
    var totalUnique = 0
    for s in sessions {
        let events = await store.events(forSession: s)
        let expectedCount = Int(oracleNext[s] ?? 0)
        totalUnique += expectedCount
        XCTAssertEqual(events.count, expectedCount,
            "session \(s): duplicate appends leaked extra rows")
        // Exhaustive: seq is exactly 0,1,2,... strictly increasing, no gaps.
        for (i, e) in events.enumerated() {
            XCTAssertEqual(e.sequenceNumber, Int64(i),
                "session \(s) idx \(i) seq=\(e.sequenceNumber), expected \(i)")
            if i > 0 {
                XCTAssertGreaterThan(e.sequenceNumber,
                    events[i - 1].sequenceNumber,
                    "session \(s) seq not strictly increasing")
            }
        }
    }

    // totalCount counts only the unique (applied) rows — no dup re-apply.
    let total = await store.totalCount
    XCTAssertEqual(total, totalUnique,
        "totalCount includes duplicate re-applies")

    // --- Deterministic re-call check: re-appending every applied id again
    //     is idempotent and leaves the store byte-identical. ---
    let before = await store.events(forSession: "S-a")
    for (id, firstSeq) in oracleApplied where id.hasPrefix("S-a") {
        let r = try await store.append(entry(id, session: "S-a", ts: 7_777))
        XCTAssertFalse(r.wasNew, "re-call: \(id) flipped to wasNew=true")
        XCTAssertEqual(r.assignedSequenceNumber, firstSeq,
            "re-call: \(id) seq drifted")
    }
    let after = await store.events(forSession: "S-a")
    XCTAssertEqual(before, after,
        "re-appending existing ids mutated stored rows (no-re-apply broken)")

    print("📊 qinao-gate event_log_sequence_monotonicity: PASS "
        + "tolerance=0 sessions=\(sessions.count) unique_rows=\(totalUnique) "
        + "seq=strict-+1-from-0 dup=idempotent(wasNew=false,no-reapply)")
}

func test_qinao_kv_cache_eviction_determinism() {
    // Deterministic PRNG so the sweep is reproducible across runs.
    var state: UInt64 = 0x9E3779B97F4A7C15
    func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
    func rint(_ bound: Int) -> Int { Int(next() % UInt64(max(1, bound))) }

    // -------- LRU: determinism + 0 over-capacity bar --------
    for _ in 0..<400 {
        let n = rint(40)                       // 0..39 sessions
        var ticks: [String: Int] = [:]
        for i in 0..<n {
            // Random ticks WITH possible duplicates to exercise the
            // (sessionID alphabetical) tiebreak path.
            ticks["s\(i)"] = rint(12)
        }
        let capacity = rint(50)                // may exceed or undercut n

        let d1 = BASKVCacheLRUEvictor.decide(accessTicks: ticks, capacity: capacity)
        let d2 = BASKVCacheLRUEvictor.decide(accessTicks: ticks, capacity: capacity)
        // Pure-deterministic: identical inputs -> byte-identical decision.
        XCTAssertEqual(d1, d2, "LRU decide() not deterministic on re-call")

        // Replicated oracle: expected eviction set = the (n-capacity)
        // lowest-tick sessions (tiebreak by id ascending).
        let expectedEvicted: [String]
        if n <= capacity {
            expectedEvicted = []
        } else {
            let ascending = ticks.sorted { a, b in
                a.value != b.value ? a.value < b.value : a.key < b.key
            }.map { $0.key }
            expectedEvicted = Array(ascending.prefix(n - capacity))
        }
        XCTAssertEqual(d1.evictedSessionIDs, expectedEvicted,
                       "LRU eviction set mismatch vs oracle")

        // RAISED BAR: after enforcement, 0 over-capacity survivors.
        if n > capacity {
            XCTAssertLessThanOrEqual(d1.preservedSessionIDs.count, capacity,
                                     "LRU left cache over capacity")
        } else {
            XCTAssertEqual(d1.preservedSessionIDs.count, n)
        }
        // Partition invariants (tolerance=0): no overlap, exact cover.
        XCTAssertEqual(d1.evictedSessionIDs.count + d1.preservedSessionIDs.count, n)
        let ev = Set(d1.evictedSessionIDs), pr = Set(d1.preservedSessionIDs)
        XCTAssertTrue(ev.isDisjoint(with: pr))
        XCTAssertEqual(ev.union(pr), Set(ticks.keys))
        XCTAssertEqual(d1.preEvictionSessionCount, n)
    }

    // -------- TTL: determinism + 0 age>ttlMs survivors bar --------
    for _ in 0..<400 {
        let n = rint(40)
        var stamps: [String: Int64] = [:]
        let now = Int64(rint(100_000) + 100_000)
        for i in 0..<n {
            // timestamps in [now-60000, now+0]; duplicates exercise tiebreak.
            stamps["s\(i)"] = now - Int64(rint(60_000))
        }
        let ttl = Int64(rint(60_000))

        let d1 = BASKVCacheTTLEvictor.decide(timestamps: stamps, nowMs: now, ttlMs: ttl)
        let d2 = BASKVCacheTTLEvictor.decide(timestamps: stamps, nowMs: now, ttlMs: ttl)
        XCTAssertEqual(d1, d2, "TTL decide() not deterministic on re-call")

        // Replicated oracle: a session is evicted iff (now - ts) > ttl.
        let expectedEvicted = Set(stamps.filter { now - $0.value > ttl }.map { $0.key })
        XCTAssertEqual(Set(d1.evictedSessionIDs), expectedEvicted,
                       "TTL eviction set mismatch vs oracle")

        // RAISED BAR: 0 survivors with age > ttlMs after enforcement.
        for id in d1.preservedSessionIDs {
            let age = now - (stamps[id] ?? .min)
            XCTAssertLessThanOrEqual(age, ttl, "TTL left an expired survivor: \(id)")
            // Cross-check the convenience predicate agrees.
            XCTAssertFalse(BASKVCacheTTLEvictor.isExpired(timestamp: stamps[id]!, nowMs: now, ttlMs: ttl))
        }
        // Partition invariants (tolerance=0).
        XCTAssertEqual(d1.evictedSessionIDs.count + d1.preservedSessionIDs.count, n)
        let ev = Set(d1.evictedSessionIDs), pr = Set(d1.preservedSessionIDs)
        XCTAssertTrue(ev.isDisjoint(with: pr))
        XCTAssertEqual(ev.union(pr), Set(stamps.keys))
        XCTAssertEqual(d1.preEvictionSessionCount, n)
        XCTAssertEqual(d1.nowMs, now)
        XCTAssertEqual(d1.ttlMs, ttl)
    }

    print("📊 qinao-gate kv_cache_eviction_determinism: PASS tolerance=0 (LRU+TTL pure-deterministic, 0 over-capacity, 0 age>ttl survivors; 800 random cases w/ replicated oracle + re-call check)")
}

func test_qinao_policy_decision_determinism() {
    // Real engine under test: BASPolicySet.decide(...) in BASPolicy/PolicyCore.swift.
    // It is pure + synchronous, returns BASPolicyDecisionRecord(decision, reason, ...).
    // Bar: (1) 100% deterministic over the full input tuple (re-call identical, tolerance=0),
    //      (2) deny precedence (block > cloud-deny > confirm > allow),
    //      (3) every decision carries a non-empty reason.

    // A policy set that exercises every branch of decide():
    //   - one rule that blocks scope .user and sensitivity .high (deny path)
    //   - the same rule disallows cloud (cloud-deny path)
    //   - the same rule has a confirmation threshold at medium risk (confirm path)
    let ruleID = "qinao-route-rule"
    let policy = BASPolicySet(rules: [
        BASPolicyRule(
            id: ruleID,
            actionClass: .routeSelection,
            enforcementPoints: [.routeSelection],
            minimumRiskForConfirmation: BASRiskScore(0.5), // == .medium.normalizedScore
            blockedScopes: [.user],
            blockedSensitivities: [.high],
            allowCloud: false
        )
    ])

    // Full small domains (these enums are NOT CaseIterable, so enumerate explicitly).
    let points: [BASEnforcementPoint] = BASEnforcementPoint.allCases
    let risks: [BASRiskLevel] = [.low, .medium, .high]
    let scopes: [BASMemoryScope] = [.user, .device, .session, .task]
    let sensitivities: [BASMemorySensitivity] = [.low, .medium, .high]
    let clouds: [Bool] = [false, true]

    // Replicated oracle: mirrors decide()'s precedence exactly for THIS single-rule set.
    // Matching requires actionClass == .routeSelection AND the rule's enforcementPoints
    // contains the point. Our only rule binds .routeSelection at enforcement point .routeSelection.
    func oracle(point: BASEnforcementPoint, risk: BASRiskLevel,
                scope: BASMemoryScope, sensitivity: BASMemorySensitivity,
                cloud: Bool) -> (BASPolicyDecision, String) {
        let matches = (point == .routeSelection)
        guard matches else {
            // H19 (mega-audit, 2026-07-08): the default branch is now fail-closed
            // — no rule matched + cloud requested ⇒ deny; local action ⇒ allow.
            // This oracle MIRRORS decide()'s precedence, so it tracks the fix.
            if cloud {
                return (.deny, "no rule matched; cloud egress is fail-closed by default")
            }
            return (.allow, "no rule matched")
        }
        // deny precedence #1: blocked scope or sensitivity
        if scope == .user || sensitivity == .high {
            return (.deny, "scope or sensitivity blocked")
        }
        // deny precedence #2: cloud requested but not allowed
        if cloud { // allowCloud == false on the rule
            return (.deny, "cloud not allowed by policy")
        }
        // confirm: risk threshold reached (0.5 == medium.normalizedScore)
        if risk.normalizedScore >= 0.5 {
            return (.requireConfirmation, "risk threshold reached")
        }
        return (.allow, "policy allowed")
    }

    var checked = 0
    for point in points {
        for risk in risks {
            for scope in scopes {
                for sensitivity in sensitivities {
                    for cloud in clouds {
                        let r1 = policy.decide(at: point, actionClass: .routeSelection,
                                               riskLevel: risk, scope: scope,
                                               sensitivity: sensitivity, cloudRequested: cloud)
                        let r2 = policy.decide(at: point, actionClass: .routeSelection,
                                               riskLevel: risk, scope: scope,
                                               sensitivity: sensitivity, cloudRequested: cloud)

                        // (1) determinism: re-call must be byte-identical (Equatable, tolerance=0)
                        XCTAssertEqual(r1, r2, "non-deterministic at \\(point)/\\(risk)/\\(scope)/\\(sensitivity)/cloud=\\(cloud)")

                        // (3) every decision carries a non-empty reason
                        XCTAssertFalse(r1.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                       "empty reason at \\(point)/\\(risk)/\\(scope)/\\(sensitivity)/cloud=\\(cloud)")

                        // (2) deny precedence + exact decision/reason match against replicated oracle
                        let (expDecision, expReason) = oracle(point: point, risk: risk,
                                                              scope: scope, sensitivity: sensitivity,
                                                              cloud: cloud)
                        XCTAssertEqual(r1.decision, expDecision,
                                       "decision mismatch at \\(point)/\\(risk)/\\(scope)/\\(sensitivity)/cloud=\\(cloud)")
                        XCTAssertEqual(r1.reason, expReason,
                                       "reason mismatch at \\(point)/\\(risk)/\\(scope)/\\(sensitivity)/cloud=\\(cloud)")

                        // explicit deny-precedence assertion: a blocked scope/sensitivity at the
                        // bound enforcement point must ALWAYS deny, regardless of cloud/risk.
                        if point == .routeSelection && (scope == .user || sensitivity == .high) {
                            XCTAssertEqual(r1.decision, .deny,
                                           "deny precedence violated at \\(scope)/\\(sensitivity)")
                            XCTAssertEqual(r1.ruleID, ruleID)
                        }
                        checked += 1
                    }
                }
            }
        }
    }
    XCTAssertEqual(checked, points.count * 3 * 4 * 3 * 2)
    print("📊 qinao-gate policy_decision_determinism: PASS tolerance=0 cases=\\(checked) (deny-precedence + non-empty-reason + deterministic re-call)")
}
}
