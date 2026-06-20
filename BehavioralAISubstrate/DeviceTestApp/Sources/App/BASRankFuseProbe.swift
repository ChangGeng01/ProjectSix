// MARK: - BASRankFuseProbe — 全面进化 T2.1 device-evidence probe (BAS_RANK_FUSE=1)
//
// The LIVE-CORPUS evidence collector the T2.1 gate requires before
// the rerank seam's default could ever flip。 The Mac-side gate
// proved CONSTRUCTION VALIDITY (lane B recovers a recency-informative
// corpus the cosine lane provably misses);what it could NOT prove is
// whether THIS device's durable corpus is recency-informative at all。
//
// ## What this probe measures (and what it honestly cannot)
//
//   1. AGE TRUTH — the decisive premise check: the fraction of
//      durable atoms carrying a REAL `lastConfirmedAt` (vs the
//      epoch-0 placeholder that makes decay a constant factor)。
//      Degenerate ages ⇒ the lane stays nil BY EVIDENCE — running
//      an A/B over them would be measurement theater (T1.3 class)。
//   2. PAIRED BEHAVIOR DELTA — lane A (cosine-only) vs lane B
//      (decay+fuse, 1-day half-life) over the SAME durable corpus +
//      query set: top-K membership overlap, rank displacement, and
//      the age profile of each lane's returned atoms。
//   3. PAIRED LATENCY — seam overhead on real retrieve() calls。
//
//   It CANNOT measure recall@K: no relevance labels exist on-device。
//   The verdict line therefore reports evidence for a HUMAN read —
//   nothing here (or anywhere) flips the seam default。
//
// Observation-only: reads the durable stores the endurance host
// owns;writes nothing;never touches the live turn loop。

import Foundation
import os
import BASHostKit
import BASMemory
import BASRuntimeCore
import BASAppleAdapters

enum BASRankFuseProbe {

    // FileLog consolidated into the shared ProbeFileLog (BASProbeCommon.swift) — Tier-B dedup.

    /// Retrieval-shaped probe queries (distinct lexical neighborhoods —
    /// same spirit as the seam tests' corpus,sized for a real run)。
    private static let probeQueries = [
        "schedule a meeting with the team tomorrow",
        "how do I feel about this difficult decision",
        "remember the plan we discussed yesterday",
        "what went wrong with the last attempt",
        "ideas for the weekend trip",
        "the urgent deadline is approaching fast",
        "something my friend said about trust",
        "notes from the morning reflection",
    ]

    private static let topK = 5
    /// ln2 / 1 day (seconds) — the same half-life the Mac gate used。
    private static let halfLifeRate = 0.693_147 / 86_400.0

    static func run() async {
        let fileLog = ProbeFileLog(filePrefix: "rank-fuse-probe", category: "rank-fuse-probe", alsoPrint: false)
        defer { fileLog.close() }
        fileLog.emit("📊 rank-fuse-probe START topK=\(topK) halfLife=1d")

        guard let embed = BASMiniLMEmbeddingProvider()?.syncEmbedClosure()
        else {
            fileLog.emit("❌ rank-fuse-probe ABORT minilm unavailable")
            return
        }
        let docs = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask).first!
        let atoms: [BASGovernedMemory]
        let entries: [BASVectorIndexEntry]
        do {
            let store = try BASSQLiteMemoryAtomStore(
                databaseURL: docs.appendingPathComponent(
                    BASEnduranceAppController.memoryAtomsDBFilename))
            let vindex = try BASSQLiteVectorIndexStorage(
                databaseURL: docs.appendingPathComponent(
                    BASEnduranceAppController.vectorIndexDBFilename))
            atoms = (try? await store.allAtoms()) ?? []
            entries = await vindex.allEntries()
        } catch {
            fileLog.emit("❌ rank-fuse-probe ABORT store open: \(error)")
            return
        }
        guard !atoms.isEmpty else {
            fileLog.emit("❌ rank-fuse-probe ABORT corpus empty — run the "
                + "endurance host first to accumulate durable atoms")
            return
        }

        // ---- 1. AGE TRUTH (the decisive premise check) ----
        let now = Date()
        let realAges = atoms.compactMap { $0.lastConfirmedAt }
        let realFraction = Double(realAges.count) / Double(atoms.count)
        let ageDays = realAges
            .map { now.timeIntervalSince($0) / 86_400.0 }
            .sorted()
        let medianAgeDays = ageDays.isEmpty
            ? 0 : ageDays[ageDays.count / 2]
        let spreadDays = ageDays.isEmpty
            ? 0 : (ageDays.last! - ageDays.first!)
        fileLog.emit(String(format:
            "📊 rank-fuse-probe AGE-TRUTH corpus=%d real_ts=%d (%.0f%%) "
            + "median_age_days=%.2f spread_days=%.2f",
            atoms.count, realAges.count, realFraction * 100,
            medianAgeDays, spreadDays))
        if realFraction < 0.5 || spreadDays < 0.5 {
            fileLog.emit("📊 rank-fuse-probe VERDICT=AGE-DEGENERATE — "
                + "decay over this corpus is (near-)constant; the seam "
                + "stays nil BY EVIDENCE (an A/B here would be "
                + "measurement theater). Re-run after the corpus "
                + "accumulates timestamp spread.")
            return
        }

        // ---- 2+3. Paired lanes over the SAME durable corpus ----
        let loadAtoms: @Sendable () async -> [BASGovernedMemory] = { atoms }
        let entryByID = Dictionary(
            entries.map { ($0.atomID, $0.normalizedEmbedding.vector) },
            uniquingKeysWith: { a, _ in a })
        let loadEmbedding: @Sendable (String) async -> [Float]? = {
            entryByID[$0]
        }
        let nowMs = Int64(now.timeIntervalSince1970 * 1000)
        let rerank: BASRetrievalRerankSeam = { hits in
            let fused = BASAutoRouteRanker.decayedFuseBatch(
                primaryScores: hits.map { Double($0.score) },
                agesMs: hits.map { nowMs - $0.timestampMs },
                policy: .exponential(rate: halfLifeRate))
            guard let fused else {
                return hits.map { (atomID: $0.atomID, score: $0.score) }
            }
            return zip(hits, fused).map {
                (atomID: $0.atomID, score: Float($1))
            }
        }
        func makeLane(_ seam: BASRetrievalRerankSeam?) async
            -> BASL8RoutedMemoryService {
            let svc = BASL8RoutedMemoryService(
                loadAllAtoms: loadAtoms,
                syncEmbed: embed,
                embeddingDimension: BASMiniLMEmbeddingProvider.embeddingDim,
                topK: topK,
                relevanceFloor: 0.0,
                selfPopulate: false,
                loadEmbedding: loadEmbedding,
                rerank: seam)
            await svc.refresh()
            return svc
        }
        let laneA = await makeLane(nil)
        let laneB = await makeLane(rerank)

        var overlapSum = 0.0
        var latencyANs: UInt64 = 0
        var latencyBNs: UInt64 = 0
        var ageSumA = 0.0; var ageCountA = 0
        var ageSumB = 0.0; var ageCountB = 0
        let atomByID = Dictionary(
            atoms.map { ($0.id.uuidString, $0) },
            uniquingKeysWith: { a, _ in a })
        for query in probeQueries {
            var frame = BASDecomposeFrame()
            frame.mirrorText = query
            let budget = BASBudgetFrame(
                runMode: .engage, maxLoops: 2, maxCandidates: 2,
                maxDecodeTokens: 180, retrievalDepth: 3,
                precisionProfile: .protected, deviceRoute: .hybridLocal,
                thermalGuardLevel: .watch, maintenanceAllowed: false)
            let profile = BASHostProfile(hostID: "rank-fuse-probe")
            let t0 = DispatchTime.now().uptimeNanoseconds
            let idsA = laneA.retrieve(
                decomposeFrame: frame, hostContext: profile,
                budget: budget).atoms.map(\.memoryID)
            let t1 = DispatchTime.now().uptimeNanoseconds
            let idsB = laneB.retrieve(
                decomposeFrame: frame, hostContext: profile,
                budget: budget).atoms.map(\.memoryID)
            let t2 = DispatchTime.now().uptimeNanoseconds
            latencyANs += t1 - t0
            latencyBNs += t2 - t1
            let setA = Set(idsA); let setB = Set(idsB)
            let union = setA.union(setB)
            let overlap = union.isEmpty
                ? 1.0
                : Double(setA.intersection(setB).count) / Double(union.count)
            overlapSum += overlap
            for id in idsA {
                if let at = atomByID[id]?.lastConfirmedAt {
                    ageSumA += now.timeIntervalSince(at) / 86_400.0
                    ageCountA += 1
                }
            }
            for id in idsB {
                if let at = atomByID[id]?.lastConfirmedAt {
                    ageSumB += now.timeIntervalSince(at) / 86_400.0
                    ageCountB += 1
                }
            }
            fileLog.emit("📊 rank-fuse-probe QUERY \"\(query.prefix(32))…\" "
                + "overlap=\(String(format: "%.2f", overlap)) "
                + "a=\(idsA.count) b=\(idsB.count)")
        }
        let n = Double(probeQueries.count)
        let meanAgeA = ageCountA > 0 ? ageSumA / Double(ageCountA) : 0
        let meanAgeB = ageCountB > 0 ? ageSumB / Double(ageCountB) : 0
        fileLog.emit(String(format:
            "📊 rank-fuse-probe RESULT overlap@%d=%.2f "
            + "latency_a_ms=%.3f latency_b_ms=%.3f "
            + "mean_returned_age_days a=%.2f b=%.2f",
            topK, overlapSum / n,
            Double(latencyANs) / n / 1e6,
            Double(latencyBNs) / n / 1e6,
            meanAgeA, meanAgeB))
        fileLog.emit("📊 rank-fuse-probe VERDICT=EVIDENCE-BANKED — "
            + "human reads: ages real, lane B should skew returned-age "
            + "younger at bounded latency cost. The seam default stays "
            + "nil until a reviewed commit flips it (gates never "
            + "auto-promote).")
    }
}
