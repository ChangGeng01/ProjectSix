// MARK: - BASRankFuseSeamGateTests — 全面进化 T2.1 gate
//
// Three tiers for the decay/fusion ranking lane:
//   1. PARITY — `decayedFuseBatch` (Rust FFI) == `decayedFuseInline`
//      (pure Swift twin) on goldens + 200 seeded-random vectors,
//      all four policies,with/without the secondary signal。
//   2. SEAM FLIP — nil `rerank` is byte-identical to the seam not
//      existing;membership ⊆ branch output;drops honored。
//   3. recall@K A/B — a CONSTRUCTED recency-informative corpus
//      (stale decoys with HIGHER cosine vs recent relevant atoms)
//      where lane A (cosine-only) provably misses and lane B
//      (decay+fuse) provably recovers。 The verdict line is PRINTED
//      for a human;nothing auto-promotes (the seam default stays
//      nil regardless of the outcome)。
//
// Honesty bounds stated up front: tier 3 is CONSTRUCTION VALIDITY —
// it proves the lane does what it claims on a corpus where recency
// IS informative。 It is NOT field evidence that production corpora
// look like this;flipping any default would additionally require
// live-corpus recall evidence (gates never auto-promote)。

import XCTest
import Foundation
@testable import BASHostKit
@testable import BASRuntimeCore
@testable import BASMemory

final class BASRankFuseSeamGateTests: XCTestCase {

    // MARK: - Tier 1: Swift ↔ Rust parity

    func testParityGoldenVectorsAcrossAllPolicies() throws {
        let primary = [1.0, 0.8, 0.5, 0.0]
        let ages: [Int64] = [0, 1000, 86_400_000, -5]  // incl. negative clamp
        let secondary = [0.1, 0.2, 0.3, 0.4]
        let policies: [BASAutoRouteRanker.BASRankDecayPolicy] = [
            .none,
            .exponential(rate: 0.000_008),  // ~1-day half-life
            .linear(horizonMs: 86_400_000),
            .step(thresholdMs: 3_600_000, floorFactor: 0.25),
        ]
        for policy in policies {
            for secondaryCase in [nil, secondary] {
                let rust = BASAutoRouteRanker.decayedFuseBatch(
                    primaryScores: primary, agesMs: ages, policy: policy,
                    secondaryScores: secondaryCase,
                    wPrimary: 0.7, wSecondary: 0.3)
                let swift = BASAutoRouteRanker.decayedFuseInline(
                    primaryScores: primary, agesMs: ages, policy: policy,
                    secondaryScores: secondaryCase,
                    wPrimary: 0.7, wSecondary: 0.3)
                let rustOut = try XCTUnwrap(rust)
                let swiftOut = try XCTUnwrap(swift)
                for (r, s) in zip(rustOut, swiftOut) {
                    XCTAssertEqual(r, s, accuracy: 1e-12,
                        "Rust and the Swift twin must agree (\(policy))")
                }
            }
        }
    }

    func testParityTwoHundredSeededRandomVectors() throws {
        var state: UInt64 = 0xBA5_F00D_21  // deterministic seed
        func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
        func rand01() -> Double { Double(next() % 1_000_000) / 1_000_000 }
        for round in 0..<200 {
            let count = Int(next() % 12)
            let primary = (0..<count).map { _ in rand01() * 2 - 0.5 }
            let ages = (0..<count).map { _ in
                Int64(next() % 200_000_000) - 1000 }
            let secondary: [Double]? = next() % 2 == 0
                ? nil : (0..<count).map { _ in rand01() }
            let policy: BASAutoRouteRanker.BASRankDecayPolicy
            switch next() % 4 {
            case 0: policy = .none
            case 1: policy = .exponential(rate: rand01() / 1000)
            case 2: policy = .linear(
                horizonMs: Int64(next() % 100_000_000))
            default: policy = .step(
                thresholdMs: Int64(next() % 100_000_000),
                floorFactor: rand01())
            }
            let rust = try XCTUnwrap(BASAutoRouteRanker.decayedFuseBatch(
                primaryScores: primary, agesMs: ages, policy: policy,
                secondaryScores: secondary,
                wPrimary: rand01(), wSecondary: rand01()),
                "seeded[\(round)] rust nil")
            let swift = try XCTUnwrap(BASAutoRouteRanker.decayedFuseInline(
                primaryScores: primary, agesMs: ages, policy: policy,
                secondaryScores: secondary,
                wPrimary: rand01() - 1, wSecondary: rand01()))
            // NOTE: weights differ between the two calls above —
            // recompute BOTH with pinned weights for the comparison。
            _ = swift
            let w1 = rand01(); let w2 = rand01()
            let a = try XCTUnwrap(BASAutoRouteRanker.decayedFuseBatch(
                primaryScores: primary, agesMs: ages, policy: policy,
                secondaryScores: secondary, wPrimary: w1, wSecondary: w2))
            let b = try XCTUnwrap(BASAutoRouteRanker.decayedFuseInline(
                primaryScores: primary, agesMs: ages, policy: policy,
                secondaryScores: secondary, wPrimary: w1, wSecondary: w2))
            for (x, y) in zip(a, b) {
                XCTAssertEqual(x, y, accuracy: 1e-12, "seeded[\(round)]")
            }
            _ = rust
        }
    }

    func testShapeMismatchesReturnNilNeverGuess() {
        XCTAssertNil(BASAutoRouteRanker.decayedFuseBatch(
            primaryScores: [1, 2], agesMs: [0], policy: .none))
        XCTAssertNil(BASAutoRouteRanker.decayedFuseBatch(
            primaryScores: [1], agesMs: [0], policy: .none,
            secondaryScores: [1, 2]))
        XCTAssertEqual(BASAutoRouteRanker.decayedFuseBatch(
            primaryScores: [], agesMs: [], policy: .none), [])
    }

    // MARK: - Fixtures for tiers 2+3

    private let fixedNow = Date(timeIntervalSince1970: 1_750_000_000)

    private func governed(
        suffix: String, content: String, confirmedAt: Date?
    ) -> BASGovernedMemory {
        BASGovernedMemory(
            id: UUID(uuidString:
                "00000000-0000-0000-0000-0000000000\(suffix)")!,
            kind: .episodic,
            content: content,
            scope: .session,
            sensitivity: .low,
            tier: .warm,
            confidence: 0.7,
            sourceType: "t21-gate",
            lastConfirmedAt: confirmedAt,
            governanceStatus: .governed,
            provenanceSummary: "t21")
    }

    /// Recency-informative corpus: 3 STALE decoys carrying the EXACT
    /// query text (cosine ≈ max) vs 3 RECENT relevant atoms whose
    /// content is the query plus dilution words (cosine lower)。
    /// Constructed ground truth = the 3 recent atoms。
    private func recencyCorpus() -> (atoms: [BASGovernedMemory],
                                     relevantIDs: Set<String>) {
        let staleAt = fixedNow.addingTimeInterval(-30 * 24 * 3600)
        let recentAt = fixedNow.addingTimeInterval(-3600)
        let decoys = ["D1", "D2", "D3"].map {
            governed(suffix: $0,
                     content: "alpine winter snow mountain",
                     confirmedAt: staleAt)
        }
        let relevant = ["E1", "E2", "E3"].map {
            governed(suffix: $0,
                     content: "alpine winter snow mountain fresh "
                        + "powder weekend trip planning",
                     confirmedAt: recentAt)
        }
        let offTopic = ["F1", "F2"].map {
            governed(suffix: $0,
                     content: "tax invoice ledger accounting deadline",
                     confirmedAt: recentAt)
        }
        return (decoys + relevant + offTopic,
                Set(relevant.map { $0.id.uuidString }))
    }

    private func makeService(
        atoms: [BASGovernedMemory],
        rerank: BASRetrievalRerankSeam?
    ) async -> BASL8RoutedMemoryService {
        let svc = BASL8RoutedMemoryService(
            loadAllAtoms: { atoms },
            syncEmbed: BASL8RoutedMemoryService.lexicalEmbed(),
            embeddingDimension: BASL8RoutedMemoryService.Parameters
                .defaultLexicalDimension,
            topK: 3,
            relevanceFloor: 0.0,
            selfPopulate: false,
            rerank: rerank)
        await svc.refresh()
        return svc
    }

    private func retrievedIDs(
        _ svc: BASL8RoutedMemoryService
    ) -> [String] {
        var frame = BASDecomposeFrame()
        frame.mirrorText = "alpine winter snow mountain"
        return svc.retrieve(
            decomposeFrame: frame,
            hostContext: BASHostProfile(hostID: "t21-gate"),
            budget: BASBudgetFrame(
                runMode: .guard, maxLoops: 2, maxCandidates: 2,
                maxDecodeTokens: 180, retrievalDepth: 3,
                precisionProfile: .protected, deviceRoute: .hybridLocal,
                thermalGuardLevel: .watch, maintenanceAllowed: false)
        ).atoms.map(\.memoryID)
    }

    /// Lane-B closure: exponential decay (1-day half-life) on the
    /// cosine score。 Closes over the FIXED clock — retrieve() stays
    /// clock-free;determinism is the host closure's responsibility。
    private func decayRerank() -> BASRetrievalRerankSeam {
        let nowMs = Int64(fixedNow.timeIntervalSince1970 * 1000)
        let halfLifeRate = 0.693_147 / 86_400.0   // ln2 / 1 day (s)
        return { hits in
            let fused = BASAutoRouteRanker.decayedFuseBatch(
                primaryScores: hits.map { Double($0.score) },
                agesMs: hits.map { nowMs - $0.timestampMs },
                policy: .exponential(rate: halfLifeRate))
                ?? BASAutoRouteRanker.decayedFuseInline(
                    primaryScores: hits.map { Double($0.score) },
                    agesMs: hits.map { nowMs - $0.timestampMs },
                    policy: .exponential(rate: halfLifeRate))!
            return zip(hits, fused).map {
                (atomID: $0.atomID, score: Float($1))
            }
        }
    }

    // MARK: - Tier 2: seam flip (byte-equality + membership contract)

    func testNilSeamIsByteIdenticalToSeamAbsent() async {
        let (atoms, _) = recencyCorpus()
        let withNil = await makeService(atoms: atoms, rerank: nil)
        let identity = await makeService(
            atoms: atoms,
            rerank: { hits in hits.map { (
                atomID: $0.atomID, score: $0.score) } })
        let a = retrievedIDs(withNil)
        let b = retrievedIDs(identity)
        XCTAssertFalse(a.isEmpty)
        XCTAssertEqual(a, b,
            "an identity closure must reproduce the nil-seam bundle " +
            "exactly (same scores ⇒ same tail sort ⇒ same membership)")
    }

    func testSeamCannotInventMembership() async {
        let (atoms, _) = recencyCorpus()
        let inventing: BASRetrievalRerankSeam = { hits in
            hits.map { (atomID: $0.atomID, score: $0.score) }
                + [(atomID: "fabricated-atom", score: 99.0)]
        }
        let svc = await makeService(atoms: atoms, rerank: inventing)
        let ids = retrievedIDs(svc)
        XCTAssertFalse(ids.contains("fabricated-atom"),
            "membership ⊆ branch output — invented IDs are dropped " +
            "by the atomID join")
    }

    func testSeamDropsAreHonored() async {
        let (atoms, _) = recencyCorpus()
        let dropAll: BASRetrievalRerankSeam = { _ in [] }
        let svc = await makeService(atoms: atoms, rerank: dropAll)
        XCTAssertTrue(retrievedIDs(svc).isEmpty,
            "a closure that drops every hit yields an empty bundle")
    }

    // MARK: - Tier 3: recall@K A/B (constructed relevance) + verdict

    func testRecallAtKConstructedRelevanceLaneBBeatsLaneA() async {
        let (atoms, relevantIDs) = recencyCorpus()

        let laneA = await makeService(atoms: atoms, rerank: nil)
        let laneB = await makeService(
            atoms: atoms, rerank: decayRerank())

        let clockA = ContinuousClock(); let t0 = clockA.now
        let idsA = retrievedIDs(laneA)
        let latencyA = clockA.now - t0
        let t1 = clockA.now
        let idsB = retrievedIDs(laneB)
        let latencyB = clockA.now - t1

        let recallA = Double(Set(idsA).intersection(relevantIDs).count)
            / Double(relevantIDs.count)
        let recallB = Double(Set(idsB).intersection(relevantIDs).count)
            / Double(relevantIDs.count)

        // Construction validity: the stale decoys carry the exact
        // query text, so cosine-only MUST prefer them…
        XCTAssertLessThan(recallA, 1.0,
            "decoys outrank on cosine by construction; if lane A is " +
            "perfect the corpus no longer discriminates")
        // …and the decay lane MUST recover the recent relevant set。
        XCTAssertEqual(recallB, 1.0,
            "30-day-old decoys decay to ~2^-30 of their score at a " +
            "1-day half-life; the recent relevant set must win")
        XCTAssertGreaterThan(recallB, recallA)

        // The HUMAN-READ verdict line (gates never auto-promote — the
        // seam default stays nil regardless of this outcome)。
        print("T2.1 RANK-FUSE GATE (constructed relevance, recall@3): "
            + "laneA(cosine-only)=\(recallA) "
            + "laneB(decay+fuse)=\(recallB) "
            + "latencyA=\(latencyA) latencyB=\(latencyB) "
            + "recommendation=LANE-VALID (construction validity only; "
            + "default stays nil — live-corpus evidence required "
            + "before any flip)")
    }
}
