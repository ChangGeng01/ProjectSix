// MARK: - BASAutoRouteCalibrationStore
// chapter 七百十 第二刀 / M2222
//
// Codable JSON cache of BASAutoRouteCalibrationReport on disk。
// Hosts that have already calibrated don't repay the ~2-10 sec
// calibration cost on every launch — the store loads from disk
// if a recent + fingerprint-matching cache exists,otherwise
// calibration runs + writes a fresh cache。
//
// ## Cache file format
//
// Single JSON file at the path the caller chooses,e.g.:
//   ~/.bas-substrate/autoroute-calibration.json
//
// File contents:
//   {
//     "schemaVersion": 1,
//     "measuredAtEpochSec": 1747641231,
//     "substrateVersion": "0.0.0",
//     "deviceFingerprint": "host::cores=8::os=14.5",
//     "measurements": [...],
//     "thresholds": {
//       "cosineSIMDMinDim": 64,
//       "sha256CryptoKitMinBytes": 1024,
//       ...
//     }
//   }
//
// ## Invalidation
//
// Cache invalidates when:
//   1. Schema version on disk < current code's expected version
//   2. Substrate version on disk != current expected
//   3. Device fingerprint on disk != current host
//   4. measuredAtEpochSec older than `maxAgeSec` parameter
//      (default 30 days — covers OS / firmware updates that
//      change CPU performance characteristics)
//
// All four checks are independent — any failure forces a fresh
// calibration on the next `loadOrCalibrate(...)` call。

import Foundation

public enum BASAutoRouteCalibrationStoreError:
    Error, Equatable, Sendable, Codable
{
    /// File exists but JSON decode failed。 Usually a schema
    /// mismatch from an old substrate version。
    case decodeFailed(message: String)
    /// Write failed (disk full, permission denied, etc.)。
    case writeFailed(message: String)
    /// File doesn't exist。 Not actually an error in the
    /// normal flow — `loadOrCalibrate` treats this as the
    /// "first launch, no cache yet" path。
    case noCacheFound
    /// Cache exists but its schema / version / device /
    /// freshness check rejected it。 Caller can choose to
    /// recalibrate or accept stale-cache risks。
    case staleCache(reason: String)

    public var caseIdentifier: String {
        switch self {
        case .decodeFailed:    return "decodeFailed"
        case .writeFailed:     return "writeFailed"
        case .noCacheFound:    return "noCacheFound"
        case .staleCache:      return "staleCache"
        }
    }
}

public actor BASAutoRouteCalibrationStore {

    /// 30-day default freshness window — long enough that the
    /// 2-10 sec calibration doesn't run more than once a month,
    /// short enough that major OS / firmware updates eventually
    /// trigger re-measurement。
    public static let defaultMaxAgeSec: Int64 =
        30 * 24 * 60 * 60

    /// Decode a calibration report from a JSON file。 Throws
    /// `.noCacheFound` if the file doesn't exist,
    /// `.decodeFailed` on parse error。
    public static func load(
        from url: URL
    ) throws -> BASAutoRouteCalibrationReport {
        guard FileManager.default.fileExists(
            atPath: url.path)
        else {
            throw BASAutoRouteCalibrationStoreError
                .noCacheFound
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(
                BASAutoRouteCalibrationReport.self,
                from: data)
        } catch {
            throw BASAutoRouteCalibrationStoreError
                .decodeFailed(
                    message: String(describing: error))
        }
    }

    /// Encode + write a calibration report to a JSON file。
    /// Atomically replaces the existing file (write-temp +
    /// rename)。 Throws `.writeFailed` on disk error。
    public static func save(
        _ report: BASAutoRouteCalibrationReport,
        to url: URL
    ) throws {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [
                .prettyPrinted, .sortedKeys]
            let data = try encoder.encode(report)
            // Ensure parent directory exists
            let parent = url.deletingLastPathComponent()
            try FileManager.default
                .createDirectory(
                    at: parent,
                    withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            throw BASAutoRouteCalibrationStoreError
                .writeFailed(
                    message: String(describing: error))
        }
    }

    /// Validate a loaded report against the current host's
    /// fingerprint + freshness window + schema version。
    /// Returns nil on validation success;throws `.staleCache`
    /// with a specific reason on any failed check。
    public static func validate(
        _ report: BASAutoRouteCalibrationReport,
        expectedSchemaVersion: Int,
        expectedSubstrateVersion: String,
        expectedDeviceFingerprint: String,
        maxAgeSec: Int64,
        now: Int64
    ) throws {
        if report.schemaVersion != expectedSchemaVersion {
            throw BASAutoRouteCalibrationStoreError
                .staleCache(
                    reason:
                        "schema version mismatch: " +
                        "cache=\(report.schemaVersion) " +
                        "expected=\(expectedSchemaVersion)")
        }
        if report.substrateVersion
            != expectedSubstrateVersion
        {
            throw BASAutoRouteCalibrationStoreError
                .staleCache(
                    reason:
                        "substrate version mismatch: " +
                        "cache=\(report.substrateVersion)" +
                        " expected=" +
                        expectedSubstrateVersion)
        }
        if report.deviceFingerprint
            != expectedDeviceFingerprint
        {
            throw BASAutoRouteCalibrationStoreError
                .staleCache(
                    reason:
                        "device fingerprint mismatch")
        }
        let age = now - report.measuredAtEpochSec
        if age > maxAgeSec {
            throw BASAutoRouteCalibrationStoreError
                .staleCache(
                    reason:
                        "cache age \(age)s > maxAge " +
                        "\(maxAgeSec)s")
        }
    }

    /// Load-or-calibrate convenience flow:
    ///   1. Attempt to load from `cacheURL`
    ///   2. Validate against current host + freshness
    ///   3. On any failure, run calibration + save fresh cache
    ///
    /// Returns the validated (or freshly-measured) report。
    /// `calibrateFn` lets callers inject test doubles。
    /// chapter 七百三十 第三刀 / M2323 — bumped from 1 → 2
    /// so existing host caches calibrated against chapter
    /// 七百二十's threshold set re-tune on next launch。 The
    /// chapter 七百二十一-七百二十九 arc added new auto-router
    /// families (BPE / int8 / PQ) whose thresholds aren't
    /// represented in v1 caches。 Re-calibration on next launch
    /// captures them honestly per the chapter 七百十 measurement
    /// -first discipline。
    public static let currentSchemaVersion: Int = 2

    public static func loadOrCalibrate(
        cacheURL: URL,
        expectedSchemaVersion: Int =
            BASAutoRouteCalibrationStore
                .currentSchemaVersion,
        expectedSubstrateVersion: String,
        expectedDeviceFingerprint: String,
        maxAgeSec: Int64 = defaultMaxAgeSec,
        depth: BASAutoRouteCalibrationDepth = .fast,
        now: Int64 = Int64(Date()
            .timeIntervalSince1970),
        calibrateFn: () -> BASAutoRouteCalibrationReport =
            { BASAutoRouteCalibrator.calibrate() }
    ) -> BASAutoRouteCalibrationReport {
        // Try loading + validating
        if let report = try? load(from: cacheURL) {
            do {
                try validate(
                    report,
                    expectedSchemaVersion:
                        expectedSchemaVersion,
                    expectedSubstrateVersion:
                        expectedSubstrateVersion,
                    expectedDeviceFingerprint:
                        expectedDeviceFingerprint,
                    maxAgeSec: maxAgeSec,
                    now: now)
                return report
            } catch {
                // Stale → re-calibrate below
            }
        }
        // Calibrate fresh
        let fresh = calibrateFn()
        try? save(fresh, to: cacheURL)
        return fresh
    }
}
