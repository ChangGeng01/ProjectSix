// MARK: - SampleHostBenchHelpers + gcd
//
// chapter 二百十九 / M800 — extracted from SampleHostModel.swift.
//
// Foundation helpers used across all bench paths:
//   - SampleHostBenchHelpers static enum (~50 LOC):
//       - rotationByteThreshold (15 MB; chapter 一百五十 defect
//         #8 fix for devicectl 20 MB cap)
//       - iso8601(_:) timestamp formatting (canonical ISO8601 +
//         fractional seconds)
//       - encode(_:) Codable JSON encoding for legacy bench row
//       - documentsDirectory() / benchOutputDir() / benchOutputURL
//         (legacy bench output path resolution)
//   - gcd(_:_:) pure helper (~5 LOC; used by SampleHostModel
//     stride-rotation parser at 2 sites to filter out non-coprime
//     strides per chapter 一百五十 defect #2 fix doctrine)
//
// Pre-this-batch: helpers + gcd inline in god file. gcd was
// `private func` so call sites enforced same-file access.
// Post-this-batch: dedicated foundation file. gcd is now
// module-internal (no `private`) so cross-file callers can
// share it without duplicating the doctrine.
//
// Doctrine pins:
//   - chapter 一百五十 defect #8: 15 MB rotation threshold pinned
//     in `rotationByteThreshold` constant (anti-magic-number).
//   - ISO8601 with fractional seconds + .withInternetDateTime so
//     downstream timestamp parse is deterministic across locales.
//   - documentsDirectory()'s force-unwrap is preserved verbatim:
//     iOS document directory is guaranteed to exist; failing
//     would mean the OS is broken.
//   - benchOutputDir() defensively creates dir tree
//     (createDirectory withIntermediateDirectories:true).
//   - 不变量 #1-#3 + Red line 7: ✓ pure foundation helpers,
//     no decision-making.
//   - chapter 二百十一 single-source-of-truth: helper invariant
//     owned by one file (other extension methods in carved-out
//     files extend this enum).

import Foundation

enum SampleHostBenchHelpers {
    /// Chapter 一百五十 fix for defect #8 (devicectl 20MB cap during
    /// active write): rotate JSONL files at 15MB so each individual
    /// file stays well below 20MB cap. Pulls during active write get
    /// the most recent rotated-out file complete; only the active file
    /// is potentially truncated. After bench finishes, all rotated
    /// files + final file pull cleanly.
    static let rotationByteThreshold: Int64 = 15 * 1024 * 1024

    static func iso8601(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }

    static func encode(_ row: SampleHostBenchRow) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(row)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    static func documentsDirectory() -> URL {
        FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask).first!
    }

    static func benchOutputDir() -> URL {
        let dir = documentsDirectory()
            .appendingPathComponent(
                "iphone-bench", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func benchOutputURL(rotationIndex: Int = 0) -> URL {
        let dir = benchOutputDir()
        if rotationIndex == 0 {
            return dir.appendingPathComponent(
                "iterations.jsonl", isDirectory: false)
        } else {
            return dir.appendingPathComponent(
                "iterations.\(rotationIndex).jsonl",
                isDirectory: false)
        }
    }
}

/// Pure gcd helper (no external dep). Used by the bench's stride-
/// rotation parser to filter out non-coprime strides — chapter
/// 一百五十 fix for defect #2: stride must be coprime with the
/// 40,320-combination signature space (gcd(stride, 40_320) == 1)
/// so the scatter walk visits all combinations without cycling.
///
/// chapter 二百十九 / M800: was `private func` in SampleHostModel.
/// swift; promoted to module-internal so cross-file callers share
/// the doctrine without duplicating.
func gcd(_ a: Int, _ b: Int) -> Int {
    var (x, y) = (abs(a), abs(b))
    while y != 0 { (x, y) = (y, x % y) }
    return x
}
