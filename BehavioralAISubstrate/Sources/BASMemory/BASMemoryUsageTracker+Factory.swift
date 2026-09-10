// MARK: - BASMemoryUsageTracker flag-aware factory (M2173)
// chapter 一千〇四十 / WS-backlog-decomp — relocated extension cluster (god-object split). byte-equal.

import Foundation
import SQLite3
import BASRuntimeCore

extension BASMemoryUsageTracker {
    // MARK: - Flag-aware factory (M2173 chapter 七百二 第三刀)

    /// Async factory that consults
    /// `BASLanguageAugmentationFeatureFlags.sqlMigratorEnabled`
    /// to choose between V1 inline schema (flag off) +
    /// V2 plugin-generated schema (flag on)。
    ///
    /// Hosts that don't care about the SQL pilot keep using
    /// `init(databaseURL:)` directly — that constructor
    /// defaults `useGeneratedSchema: false`,so behavior is
    /// unchanged。
    ///
    /// - Parameters:
    ///   - databaseURL:SQLite file URL,as for `init`。
    ///   - flags:the language-augmentation feature flags
    ///     actor。 The `sqlMigratorEnabled` flag is read
    ///     once here at construction time。 Flipping the
    ///     flag after a tracker is constructed has no
    ///     effect on that tracker — flag state is sampled
    ///     once。 New trackers re-sample。
    public static func make(
        databaseURL: URL,
        flags: BASLanguageAugmentationFeatureFlags
    ) async throws -> BASMemoryUsageTracker {
        let useGenerated = await flags.isEnabled(
            .sqlMigratorEnabled)
        return try BASMemoryUsageTracker(
            databaseURL: databaseURL,
            useGeneratedSchema: useGenerated)
    }

    /// M2205 chapter 七百十三 第一刀 — host adoption
    /// convenience factory。 Constructs a fresh default-
    /// init `BASLanguageAugmentationFeatureFlags` actor
    /// and routes through `make(databaseURL:flags:)`,
    /// returning the V2-generated-schema path because
    /// chapter 七百十一 production wire-in flipped
    /// `sqlMigratorEnabled` to default-true。
    ///
    /// Hosts that want flag control should use
    /// `make(databaseURL:flags:)` directly。 Hosts that
    /// want "just give me the recommended SQL pilot
    /// configuration" use this。
    public static func makeWithDefaults(
        databaseURL: URL
    ) async throws -> BASMemoryUsageTracker {
        let flags = BASLanguageAugmentationFeatureFlags()
        return try await make(
            databaseURL: databaseURL, flags: flags)
    }

    static func verifySchemaVersion(
        db: OpaquePointer
    ) throws {
        let version = try readUserVersion(db: db)
        guard version == schemaVersion else {
            throw TrackerError.schemaVersionMismatch(
                found: version, expected: schemaVersion)
        }
    }

    /// M886 backport (M882 audit fix):read PRAGMA user_version
    /// without setting。Returns 0 for fresh DBs。
    static func readUserVersion(
        db: OpaquePointer
    ) throws -> Int {
        var stmt: OpaquePointer?
        let sql = "PRAGMA user_version;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw TrackerError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw TrackerError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        return Int(sqlite3_column_int64(stmt, 0))
    }

}
