// MARK: - SampleHostBenchCheckpointStore
//
// chapter 二百四十一 / M823 — extracted from SampleHostBenchSafetyKit.swift
// (chapter 一百九十二 / M716-M725 10h-readiness pack split into
// 9 single-responsibility files for navigability + isolated test surface).
//
// This file owns the M722 component invariant.

import Foundation

// MARK: - M722 crash checkpoint

/// Persisted crash-recovery snapshot. Lets a 10h bench survive an
/// app force-kill / OOM / reboot — on next launch, sample-host can
/// detect the unfinished bench and either resume or surface
/// to operator for review.
///
/// Doctrine: checkpoint is WRITE-ONLY from the runtime side. M722
/// ships the write path; M723 / chapter 一百九十三+ adds resume UI.
struct SampleHostBenchCheckpoint: Codable, Sendable, Equatable {
    let generation: Int
    let iter: Int
    let startTimeIso: String
    let lastUpdatedIso: String
    let outputPath: String
    let smokeMode: String
    let durationHours: Double
    let mutationSeedCount: Int
    let strideCSV: String
    /// AFM ok / Gemma ok / both-failed counters at last checkpoint
    let afmOk: Int
    let gemmaOk: Int
    let bothFailed: Int
    /// Anomaly snapshot for fast triage
    let stuckSubstrates: Int
    let stuckLLMs: Int
}

/// Thread-safe checkpoint store. Single file at
/// `Documents/iphone-hybrid-bench/checkpoint.json`.
actor SampleHostBenchCheckpointStore {
    static let shared = SampleHostBenchCheckpointStore()
    private let url: URL

    init() {
        let docs = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = docs.appendingPathComponent("iphone-hybrid-bench")
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        self.url = dir.appendingPathComponent("checkpoint.json")
    }

    /// Atomic write. Encodes pretty-printed JSON to a tmp path then
    /// renames over the live URL — survives partial-write crashes.
    func write(_ checkpoint: SampleHostBenchCheckpoint) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(checkpoint)
        let tmp = url.appendingPathExtension("tmp")
        try data.write(to: tmp, options: .atomic)
        // Rename atomic — POSIX semantics on iOS are atomic for
        // same-filesystem rename. Replaces existing file.
        if FileManager.default.fileExists(atPath: url.path) {
            _ = try? FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: tmp, to: url)
    }

    /// Read latest checkpoint. Returns nil if no file or unreadable
    /// (treat as no-prior-bench rather than crash on first launch).
    func read() async -> SampleHostBenchCheckpoint? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder()
            .decode(SampleHostBenchCheckpoint.self, from: data)
    }

    /// Clear checkpoint (call on clean bench finish).
    func clear() async {
        _ = try? FileManager.default.removeItem(at: url)
    }

    /// URL for tests / replay tool.
    var checkpointURL: URL { url }
}
