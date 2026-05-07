// MARK: - SampleHostBenchShardManifest
//
// chapter 二百四十一 / M823 — extracted from SampleHostBenchSafetyKit.swift
// (chapter 一百九十二 / M716-M725 10h-readiness pack split into
// 9 single-responsibility files for navigability + isolated test surface).
//
// This file owns the M733 component invariant.

import Foundation

// MARK: - M733 chapter 一百九十四 — JSONL shard manifest

/// Per-bench manifest written at bench end. Lets replay tool know
/// total shard count + total iters + anomaly summary + bench config
/// without scanning all rows. JSON file at
/// `Documents/iphone-hybrid-bench/manifest.json`.
///
/// Doctrine: manifest is OBSERVABILITY only — replay tool reads it
/// for fast summary; actual ground truth still lives in JSONL rows
/// (manifest may be stale / missing on crash; replay tool falls
/// back to scanning).
struct SampleHostBenchShardManifest: Codable, Sendable, Equatable {
    let benchID: String          // start time iso as identifier
    let startTimeIso: String
    let endTimeIso: String
    let totalIters: Int
    let totalShards: Int          // count of *.jsonl files
    let smokeMode: String
    let durationHours: Double
    let mutationSeedCount: Int
    let strideCSV: String
    /// Captured at bench end for fast summary
    let afmOk: Int
    let gemmaOk: Int
    let bothFailed: Int
    let routerHits: Int
    let routerMisses: Int
    let stuckSubstrates: Int
    let stuckLLMs: Int
    let pauseSkipped: Int
    let adversarialFired: Int
    let driftAlarms: Int
    /// Chapter-192 flex constants in effect for this bench
    let anomalyWindowSize: Int
    let driftSigmaThreshold: Double
    let mutationProbability: Double
    let checkpointEveryNIters: Int

    // MARK: - Chapter 三百五二 / M839 additions
    //
    // Optional for backwards-compat: pre-M839 manifests (yesterday's
    // 2h run, all the iphone-hybrid-bench/manifest.json files in the
    // wild) decode with these as nil。Newer readers can still summarize
    // legacy data by treating nil phase as `.completed`。

    /// Phase at the moment manifest was written:
    ///   - `"completed"` = clean 8h finish
    ///   - `"cancelled"` = user pressed Stop mid-run
    ///   - nil = legacy (pre-M839) manifest
    let phase: String?

    /// Chapter / M-number tag of the build that produced this run。
    /// Helps cross-reference manifest data against commit SHAs。
    /// nil = legacy manifest written before this field existed。
    let buildChapter: String?

    /// `true` if the run was cancelled mid-loop。Convenience for
    /// quick filtering — same info as `phase == "cancelled"`。
    /// nil = legacy manifest written before this field existed。
    let cancelled: Bool?

    /// Chapter 三百五二 / M839: explicit init with default-nil
    /// values for the new fields。Lets pre-M839 call sites
    /// continue working without naming the new fields,while
    /// the M839 hybrid bench end-of-run path explicitly passes
    /// `phase` / `buildChapter` / `cancelled`。
    init(
        benchID: String,
        startTimeIso: String,
        endTimeIso: String,
        totalIters: Int,
        totalShards: Int,
        smokeMode: String,
        durationHours: Double,
        mutationSeedCount: Int,
        strideCSV: String,
        afmOk: Int,
        gemmaOk: Int,
        bothFailed: Int,
        routerHits: Int,
        routerMisses: Int,
        stuckSubstrates: Int,
        stuckLLMs: Int,
        pauseSkipped: Int,
        adversarialFired: Int,
        driftAlarms: Int,
        anomalyWindowSize: Int,
        driftSigmaThreshold: Double,
        mutationProbability: Double,
        checkpointEveryNIters: Int,
        phase: String? = nil,
        buildChapter: String? = nil,
        cancelled: Bool? = nil
    ) {
        self.benchID = benchID
        self.startTimeIso = startTimeIso
        self.endTimeIso = endTimeIso
        self.totalIters = totalIters
        self.totalShards = totalShards
        self.smokeMode = smokeMode
        self.durationHours = durationHours
        self.mutationSeedCount = mutationSeedCount
        self.strideCSV = strideCSV
        self.afmOk = afmOk
        self.gemmaOk = gemmaOk
        self.bothFailed = bothFailed
        self.routerHits = routerHits
        self.routerMisses = routerMisses
        self.stuckSubstrates = stuckSubstrates
        self.stuckLLMs = stuckLLMs
        self.pauseSkipped = pauseSkipped
        self.adversarialFired = adversarialFired
        self.driftAlarms = driftAlarms
        self.anomalyWindowSize = anomalyWindowSize
        self.driftSigmaThreshold = driftSigmaThreshold
        self.mutationProbability = mutationProbability
        self.checkpointEveryNIters = checkpointEveryNIters
        self.phase = phase
        self.buildChapter = buildChapter
        self.cancelled = cancelled
    }
}

actor SampleHostBenchShardManifestStore {
    static let shared = SampleHostBenchShardManifestStore()
    private let url: URL

    init() {
        let docs = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = docs.appendingPathComponent("iphone-hybrid-bench")
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        self.url = dir.appendingPathComponent("manifest.json")
    }

    /// Atomic write — same pattern as checkpoint store.
    func write(_ manifest: SampleHostBenchShardManifest) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        let tmp = url.appendingPathExtension("tmp")
        try data.write(to: tmp, options: .atomic)
        if FileManager.default.fileExists(atPath: url.path) {
            _ = try? FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: tmp, to: url)
    }

    func read() async -> SampleHostBenchShardManifest? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder()
            .decode(SampleHostBenchShardManifest.self, from: data)
    }

    var manifestURL: URL { url }
}

/// Count `*.jsonl` shards in the bench output directory.
/// Called at bench end to populate manifest.
func sampleHostBenchCountShards(in directory: URL) -> Int {
    let fm = FileManager.default
    guard let contents = try? fm.contentsOfDirectory(
        at: directory, includingPropertiesForKeys: nil)
    else { return 0 }
    return contents.filter { $0.pathExtension == "jsonl" }.count
}

// M794 chapter 二百十三 — `profile(forLayerIndex:)` consolidated
// into `SampleHostFourteenLayerSmokeProfile.swift` along with the
// rest of the type (single-source-of-truth doctrine).
