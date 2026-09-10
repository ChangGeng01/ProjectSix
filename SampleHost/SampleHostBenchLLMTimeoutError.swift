// MARK: - SampleHostBenchLLMTimeoutError
//
// chapter 二百四十一 / M823 — extracted from SampleHostBenchSafetyKit.swift
// (chapter 一百九十二 / M716-M725 10h-readiness pack split into
// 9 single-responsibility files for navigability + isolated test surface).
//
// This file owns the M735 component invariant.

import Foundation

// MARK: - M735 chapter 一百九十五 — per-iter LLM timeout

/// Errors thrown by `withLLMTimeout` when the underlying LLM call
/// exceeds the deadline. Doctrine: timeout is a HINT to bail out
/// of a single iter, NOT a session-killer; bench loop catches and
/// records "timeout" as the firstStatus.
enum SampleHostBenchLLMTimeoutError: Error, Equatable {
    case timeoutExceeded(seconds: Double)
}

/// Run an async LLM call with a per-iter deadline. If the call
/// completes first → return its result. If the deadline fires
/// first → cancel the call's task and throw `.timeoutExceeded`.
///
/// Doctrine: LLM hangs are a known failure mode (network stalls,
/// model loading races, MLX state corruption). Pre-this-batch a
/// hung call would block the bench loop forever (no progress, no
/// JSONL row, no thermal-gate check). This wrapper ensures every
/// iter terminates within `seconds` even if the LLM never returns.
func withLLMTimeout<T: Sendable>(
    _ seconds: Double,
    _ work: @escaping @Sendable () async throws -> T
) async throws -> T {
    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            return try await work()
        }
        group.addTask {
            let nanos = UInt64(max(0.001, seconds) * 1_000_000_000)
            try await Task.sleep(nanoseconds: nanos)
            throw SampleHostBenchLLMTimeoutError
                .timeoutExceeded(seconds: seconds)
        }
        // Whichever finishes first wins; cancel the other.
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
