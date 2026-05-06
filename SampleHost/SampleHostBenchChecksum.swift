// MARK: - SampleHostBenchChecksum
//
// chapter 二百四十一 / M823 — extracted from SampleHostBenchSafetyKit.swift
// (chapter 一百九十二 / M716-M725 10h-readiness pack split into
// 9 single-responsibility files for navigability + isolated test surface).
//
// This file owns the M716 component invariant.

import Foundation
import CryptoKit

// MARK: - M716 row checksum

/// SHA-256 over the canonical encoded row body (excluding the
/// `rowChecksum` field itself). Lets a downstream validator detect
/// corrupted lines without trusting the JSON parser to fail
/// non-fatally on truncation.
///
/// Doctrine: checksum is OPTIONAL on the row; legacy rows decode
/// fine. Validator script (`scripts/validate_hybrid_jsonl.py`)
/// flags rows with `rowChecksum != null && computed != stored`.
enum SampleHostBenchRowChecksum {
    /// Canonical SHA-256 of a UTF-8 string, lowercase hex.
    static func sha256Hex(of input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
