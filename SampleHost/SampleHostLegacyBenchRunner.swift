// MARK: - SampleHostLegacyBenchRunner
//
// chapter 二百十七 / M798 — extracted from SampleHostModel.swift.
//
// Earliest bench-loop infrastructure (chapter 一百四十七 / M573):
// the original single-row bench format used before the AFM and
// hybrid bench paths landed. Still active for the simple
// "iterations.jsonl" output path that pulls cleanly via Apple's
// devicectl 20MB cap.
//
//   - SampleHostBenchRow (chapter 一百四十七, ~20 LOC, legacy
//     bench-row struct with stride / mutationSeed fields added in
//     chapter 一百七十四 M604)
//   - SampleHostBenchRunner actor (chapter 一百五十, ~68 LOC,
//     defect #8 fix: rotate JSONL files at 15 MB so each
//     individual file stays well below the 20 MB devicectl cap;
//     resume-from-disk path seeds currentBytes correctly)
//
// Pre-this-batch: ~88 LOC of legacy persistence inline in the
// god file alongside @Published / orchestrator code.
// Post-this-batch: legacy bench owns its file. Reads
// SampleHostBenchHelpers static helpers (encode + dir paths)
// from the helper enum (still in SampleHostModel.swift for now;
// chapter 二百十九 candidate carve-out).
//
// Doctrine pins (red-line preservation):
//   - chapter 一百五十 defect #8 rotation invariant preserved.
//   - SampleHostBenchHelpers.rotationByteThreshold = 15 MB.
//   - Resume path (chapter 一百五十 + chapter 一百八十) seeds
//     currentBytes from disk on first open of pre-existing file.
//   - 不变量 #1-#3 + Red line 7: ✓ persistence is observability.

import Foundation

struct SampleHostBenchRow: Codable, Sendable, Equatable {
    let timestamp: String
    let iteration: Int
    let seed: Int
    let signature: SampleHostPromptSignature
    let prompt: String
    let auditCodeCount: Int
    let permitMode: String
    let bodyLength: Int
    let durationSeconds: Double
    let status: String
    let errorMessage: String?
    /// **M604 chapter 一百七十四 — procedural generation params**.
    /// Captured per-iter so post-bench analysis can correlate
    /// substrate behavior with stride × mutation combinations.
    /// Goal (user "通过冒烟找到最合适程序化生成"): discover which
    /// stride / mutation combos surface defects.
    let stride: Int?
    let mutationSeed: Int?
}

actor SampleHostBenchRunner {
    private var fileHandle: FileHandle?
    private var currentURL: URL?
    private var currentBytes: Int64 = 0
    private var rotationIndex: Int = 0

    /// Chapter 一百五十 fix for defect #8: when active file exceeds
    /// rotation threshold, close it and start a new file with index
    /// suffix (iterations.jsonl → iterations.1.jsonl → 2.jsonl …).
    /// This ensures Apple's devicectl 20MB cap during active write
    /// affects ONLY the latest file; all rotated-out files pull
    /// cleanly via single-file copy.
    func appendRow(_ row: SampleHostBenchRow) async throws {
        let line = try SampleHostBenchHelpers.encode(row) + "\n"
        guard let data = line.data(using: .utf8) else { return }
        let lineBytes = Int64(data.count)

        // Rotate if active file would exceed threshold AND we've
        // written something already
        if let _ = fileHandle,
           currentBytes + lineBytes
            > SampleHostBenchHelpers.rotationByteThreshold
        {
            try? fileHandle?.synchronize()
            try? fileHandle?.close()
            fileHandle = nil
            rotationIndex += 1
            currentBytes = 0
        }

        if fileHandle == nil {
            let url = SampleHostBenchHelpers.benchOutputURL(
                rotationIndex: rotationIndex)
            currentURL = url
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(
                    atPath: url.path, contents: nil)
            }
            fileHandle = try FileHandle(forWritingTo: url)
            try fileHandle?.seekToEnd()
            // Recompute size in case file already had content
            // (post-relaunch resume path)
            if let attrs = try? FileManager.default
                .attributesOfItem(atPath: url.path),
               let n = attrs[.size] as? Int64
            {
                currentBytes = n
            }
        }

        try fileHandle?.write(contentsOf: data)
        currentBytes += lineBytes
    }

    func flush() async {
        try? fileHandle?.synchronize()
    }

    func close() async {
        try? fileHandle?.close()
        fileHandle = nil
    }

    /// Diagnostic accessor for tests + UI
    func currentRotationIndex() async -> Int {
        rotationIndex
    }
}
