// MARK: - SampleHostBenchSinking protocol
//
// chapter 二百四十六 / M828 — protocol contract for bench-loop JSONL
// row persistence.
//
// Doctrine: chapter 二百十六 (M797) shipped the JSONL persistence as
// `SampleHostHybridBenchJSONLRunner` actor (15 MB rotation +
// SHA-256 row checksum + NaN/Inf-safe encoder). This file extracts
// the contract as a typed protocol so future chapters can inject
// alternative sinks (e.g. MockBenchSink for unit tests, OSLogSink
// for telemetry-only mode, MultiSink for fan-out).
//
// Why protocol-marker without changing call sites: the bench loop
// currently calls `runner.appendRow(row)` on the concrete actor.
// Adding the protocol conformance is doctrine-only — no behavior
// change, no test break. Future chapters that want injection can:
//   1. Change `SampleHostHybridBenchJSONLRunner` instances to
//      `any SampleHostBenchSinking` references at construction.
//   2. Tests pass `RecordingMockSink()` which captures rows in
//      memory for assertions.
//
// Doctrine pins:
//   - 不变量 #1-#3 + Red line 7: ✓ protocol is contract only
//   - chapter 二百十一 single-source-of-truth: sink contract owned
//     by one file
//   - chapter 二百十六 / M797: existing JSONL runner satisfies
//     this protocol verbatim
//   - chapter 一百九十二 / M716 row checksum + chapter 一百八十四 /
//     M665 NaN/Inf encoder doctrine remain in the concrete sink

import Foundation

/// Protocol contract for hybrid bench row persistence. The
/// production conformer is `SampleHostHybridBenchJSONLRunner` actor
/// (chapter 二百十六 / M797). Mock conformers for tests can append
/// rows to in-memory arrays without touching FS, useful for
/// testing the bench loop's iter logic in isolation.
protocol SampleHostBenchSinking: Actor {
    /// Append one row to the underlying sink. Production
    /// implementation rotates JSONL files at 15 MB
    /// (chapter 一百五十 defect #8 fix); test mocks can no-op or
    /// capture in array.
    func appendRow(_ row: SampleHostHybridBenchRow) async throws

    /// Close the sink. Production implementation closes the file
    /// handle; test mocks can no-op.
    func close() async
}

// SampleHostHybridBenchJSONLRunner is the production conformer.
// Existing chapter 二百十六 (M797) actor methods satisfy the
// protocol verbatim; this is a doctrine-only marker.
extension SampleHostHybridBenchJSONLRunner: SampleHostBenchSinking {}
