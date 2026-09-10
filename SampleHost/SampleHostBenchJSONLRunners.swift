// MARK: - SampleHostBenchJSONLRunners
//
// chapter 二百十六 / M797 — extracted from SampleHostModel.swift.
//
// Two JSONL rotation actors + their helper extensions, both
// previously buried in the god file:
//   - SampleHostAFMBenchRow + helpers + SampleHostAFMBenchJSONLRunner
//     (chapter 一百七十六 §176.14, ~82 LOC)
//   - SampleHostHybridBenchHelpers extension + SampleHostHybridBench-
//     JSONLRunner (chapter 一百七十七, ~103 LOC)
//
// Pre-this-batch: ~185 LOC of persistence infrastructure inline
// in the god file alongside @Published / orchestrator code.
// Post-this-batch: persistence infrastructure owns its file.
// Each runner has a single responsibility (rotate-and-append-row
// for one row type). chapter 二百十一 single-source-of-truth
// extended to bench persistence.
//
// Doctrine pins:
//   - Both runners are actors (Swift concurrency: serialized writes
//     to file handle); no shared mutable state cross-runner.
//   - encodeHybrid handles M665 chapter 一百八十四 NaN/Inf
//     stringification (CoreML can yield non-finite Doubles).
//   - encodeHybrid does M716 chapter 一百九十二 SHA-256 row
//     checksum (canonical encoding ex-checksum, then injected).
//   - 不变量 #1-#3 + Red line 7: ✓ persistence is observability,
//     decisions stay at substrate / permit / verdict level.

import Foundation

// MARK: - M610 chapter 一百七十六 §176.14 — AFM bench row + JSONL runner

struct SampleHostAFMBenchRow: Codable, Sendable, Equatable {
    let timestamp: String
    let iteration: Int
    let seed: Int
    let stride: Int
    let mutationSeed: Int
    let signature: SampleHostPromptSignature
    let prompt: String
    let auditCodeCount: Int
    let permitMode: String
    let afmStatus: String  // ok / skipped / afm-error / afm-unavailable-*
    let afmBody: String
    let afmBodyLength: Int
    let afmDurationMs: Double
    let totalDurationSeconds: Double
    let errorMessage: String?
}

extension SampleHostBenchHelpers {
    static func afmBenchOutputDirURL() -> URL {
        let docs = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = docs.appendingPathComponent("iphone-afm-bench")
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func encodeAFM(_ row: SampleHostAFMBenchRow) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(row)
        return String(data: data, encoding: .utf8) ?? ""
    }
}

actor SampleHostAFMBenchJSONLRunner {
    private let rotationBytes: Int
    private var fileHandle: FileHandle?
    private var currentURL: URL?
    private var rotationIndex: Int = 0

    init(rotationBytes: Int) {
        self.rotationBytes = rotationBytes
    }

    func appendRow(_ row: SampleHostAFMBenchRow) async throws {
        let line = try SampleHostBenchHelpers.encodeAFM(row) + "\n"
        guard let data = line.data(using: .utf8) else { return }
        let needNew: Bool
        if let h = fileHandle, let url = currentURL {
            let attrs = try? FileManager.default
                .attributesOfItem(atPath: url.path)
            let size = (attrs?[.size] as? Int) ?? 0
            needNew = size + data.count > rotationBytes
            _ = h
        } else {
            needNew = true
        }
        if needNew {
            await close()
            rotationIndex += 1
            let dir = SampleHostBenchHelpers.afmBenchOutputDirURL()
            let url = dir.appendingPathComponent(
                "afm-iterations.\(rotationIndex).jsonl")
            FileManager.default.createFile(
                atPath: url.path, contents: nil)
            currentURL = url
            fileHandle = try FileHandle(forWritingTo: url)
        }
        try fileHandle?.write(contentsOf: data)
    }

    func close() async {
        try? fileHandle?.close()
        fileHandle = nil
        currentURL = nil
    }
}

// MARK: - M619 chapter 一百七十七 §177 — Hybrid bench helpers + JSONL runner

extension SampleHostBenchHelpers {
    static func hybridBenchOutputDirURL() -> URL {
        let docs = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = docs.appendingPathComponent("iphone-hybrid-bench")
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func encodeHybrid(_ row: SampleHostHybridBenchRow) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        // M665 chapter 一百八十四 deep-review fix B2 (CRITICAL):
        // CoreML model outputs can occasionally yield NaN /
        // ±Infinity (input vector pathological, dropout layer
        // active by mistake, etc.). Default JSONEncoder THROWS on
        // these values. Pre-this-batch a single non-finite Double
        // in any of 11 Double fields (routerProbability,
        // firstTriedDurationMs, fallbackDurationMs,
        // totalDurationSeconds, lengthPredicted, lengthError,
        // latencyPredictedMs, latencyErrorMs,
        // permitPredictBlockProb, verbosityProbability +
        // postLLMAuditCodeCount when nil) would silently drop the
        // ENTIRE iter row from JSONL with only `hybridBenchLastError`
        // as a clue. Now: stringify non-finite as "nan" / "inf" /
        // "-inf" so the row always lands and downstream analysis
        // can grep these markers.
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "inf",
            negativeInfinity: "-inf",
            nan: "nan")
        // M716 chapter 一百九十二 — compute SHA-256 of canonical
        // encoding WITHOUT the rowChecksum field, then inject the
        // hash and re-encode. Two-pass keeps the checksum
        // deterministic across encoder re-orderings (sortedKeys
        // already canonical, but explicit nil in pass 1 makes the
        // doctrine 100%: "checksum covers the row body").
        var bare = row
        bare.rowChecksum = nil
        let bareData = try encoder.encode(bare)
        let bareString = String(data: bareData, encoding: .utf8) ?? ""
        let checksum = SampleHostBenchRowChecksum.sha256Hex(of: bareString)
        var stamped = row
        stamped.rowChecksum = checksum
        let stampedData = try encoder.encode(stamped)
        return String(data: stampedData, encoding: .utf8) ?? ""
    }
}

actor SampleHostHybridBenchJSONLRunner {
    private let rotationBytes: Int
    private var fileHandle: FileHandle?
    private var currentURL: URL?
    private var rotationIndex: Int = 0
    // M627 chapter 177 deep-review fix #9 — track running byte
    // count in-actor instead of querying FileManager.attributesOf.
    // attributesOf may not reflect just-written bytes (FS / OS
    // buffering), causing rotation to miss its window. Running
    // tally is exact + cheap. Pre-existing files (resume case)
    // seed currentBytes from disk on first open.
    private var currentBytes: Int = 0

    init(rotationBytes: Int) {
        self.rotationBytes = rotationBytes
    }

    func appendRow(_ row: SampleHostHybridBenchRow) async throws {
        let line = try SampleHostBenchHelpers.encodeHybrid(row) + "\n"
        guard let data = line.data(using: .utf8) else { return }
        let needNew: Bool
        if fileHandle != nil, currentURL != nil {
            needNew = currentBytes + data.count > rotationBytes
        } else {
            needNew = true
        }
        if needNew {
            await close()
            rotationIndex += 1
            let dir = SampleHostBenchHelpers.hybridBenchOutputDirURL()
            let url = dir.appendingPathComponent(
                "hybrid-iterations.\(rotationIndex).jsonl")
            FileManager.default.createFile(
                atPath: url.path, contents: nil)
            currentURL = url
            fileHandle = try FileHandle(forWritingTo: url)
            // Fresh file → 0 bytes. (For resume: seek-to-end +
            // offset would be the path; we always create a new
            // numbered shard so this is exact.)
            currentBytes = 0
        }
        try fileHandle?.write(contentsOf: data)
        currentBytes += data.count
    }

    func close() async {
        try? fileHandle?.close()
        fileHandle = nil
        currentURL = nil
        currentBytes = 0
    }
}
