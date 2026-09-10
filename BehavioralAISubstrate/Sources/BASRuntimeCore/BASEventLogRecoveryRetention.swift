import Foundation

/// Package-local physical-retention rules shared by the shipped event-log
/// stores. Event timestamps remain caller-owned semantic data; this floor is
/// evaluated only against storage-owned ingestion metadata.
enum BASEventLogRecoveryRetention {
    static let minimumIngestionAgeMs: Int64 = 259_200_000

    static let systemNowMs: @Sendable () -> Int64 = {
        let milliseconds = Date().timeIntervalSince1970 * 1_000
        guard milliseconds.isFinite,
              milliseconds >= 0,
              milliseconds <= Double(Int64.max)
        else { return 0 }
        return Int64(milliseconds)
    }

    /// A non-positive result means retain all. Subtraction is checked so a
    /// compromised or regressed clock cannot turn into an unexpectedly large
    /// deletion cutoff.
    static func ingestionCutoff(nowMs: Int64) -> Int64? {
        guard nowMs >= 0 else { return nil }
        let (cutoff, overflow) = nowMs.subtractingReportingOverflow(
            minimumIngestionAgeMs)
        guard !overflow, cutoff > 0 else { return nil }
        return cutoff
    }

    static func clampedStamp(nowMs: Int64, maximumValidStamp: Int64?) -> Int64 {
        let validNow = max(0, nowMs)
        return max(validNow, maximumValidStamp ?? 0)
    }
}
