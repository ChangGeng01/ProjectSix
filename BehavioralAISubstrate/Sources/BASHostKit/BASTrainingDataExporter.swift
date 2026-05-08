// MARK: - BASTrainingDataExporter — chapter 三百九九 / M903
//
// Typed substrate primitive for exporting accumulated cognitive
// OS event corpus to a streaming JSONL file suitable for offline
// ML training pipelines (P2 G8 Mamba SSM training,ChengluMemory
// retraining,future P3 G12 auto eval baseline)。
//
// ## Why this exists (10h iPhone run data drives this)
//
// The 10h chenglu mesh stress run produced a 2,734,001-event
// SQLite corpus on iPhone that's too valuable to leave dormant。
// Future training paths need this data exported in a streaming
// format suitable for Python / MLX ingestion:
//
//   - JSONL (one record per line)— streamable parsing,line-
//     oriented for sharded distributed training
//   - includes optional state context per event (S_{t-1} / S_t
//     state vectors via M842 reducer trail)
//   - filterable by session / time / kind / risk band so callers
//     can sample slices without materializing the full corpus
//
// ## What this ships
//
//   - `BASTrainingDataExportFilter` typed filter selector
//   - `BASTrainingDatum` typed Codable record (event + optional
//     state context)
//   - `BASTrainingDataExporter` actor that walks the event log
//     in pages and writes JSONL to a URL
//   - `BASTrainingDataExportSummary` typed Codable result
//
// ## Doctrine pins held
//
// - 不变量 #1 / #2 / #3 全保 — export is observation;does NOT
//   mutate event log,state store,or graph
// - 红线 7 hint-only — exported corpus is training input,NOT
//   gating signal — gate at L11 unchanged
// - chapter 二百一一 single-source-of-truth — ONE typed exporter,
//   all consumers (G8 SSM / ChengluMemory / G12 eval) route
//   through this
// - chapter 一百八十五 anti-magic-number — page size + batch
//   limit named typed constants
// - chapter 三百四七 (M834) bundle-lifecycle pin — exporter
//   owns its file handle for the duration of the export,
//   defers close on any exit path
// - ADR-014 OPT-IN — primitive only fires when caller invokes
//
// ## Non-goals
//
//   - CSV / Parquet / TFRecord export — JSONL ships first,other
//     formats are future extensions if pipelines require
//   - Streaming (AsyncStream-style) export — caller reads back
//     the file via standard file I/O after export completes
//   - Compression — caller wraps the resulting file in gzip /
//     zstd if needed (Foundation's CompressedByteStream available
//     to consumers)
//   - Privacy redaction — caller's responsibility to filter
//     sensitive fields before export (e.g. `rawInputDigest` is
//     already digest-only by event log design)

import Foundation
import BASMemory
import BASRuntimeCore

// **Module placement**: BASHostKit (not BASRuntimeCore) because
// `BASUserStateStorage` lives in BASMemory and the exporter
// optionally reads state context — BASHostKit is the natural
// composition point that already imports both via @_exported,
// matching the M865 BASCognitiveOSConvenience placement decision。

// MARK: - Export filter

/// Typed selector for which events the exporter emits。
public struct BASTrainingDataExportFilter:
    Sendable, Equatable, Hashable
{
    /// Optional session ID filter — if set,only events from
    /// this session are emitted。Default nil = all sessions。
    public let sessionID: String?

    /// Optional starting timestamp (inclusive)。Default nil = 0
    /// (export from beginning of corpus)。
    public let sinceMs: Int64?

    /// Optional ending timestamp (exclusive)。Default nil = no
    /// upper bound (export to end of corpus)。
    public let untilMs: Int64?

    /// Optional event-kind filter — if non-nil and non-empty,
    /// only events whose `kind` is in this set are emitted。
    /// Default nil = all kinds。
    public let kinds: Set<BASEventLogKind>?

    /// Optional risk-band filter — if non-nil and non-empty,
    /// only events whose `riskBand` is in this set are emitted。
    /// Default nil = all risk bands。
    public let riskBands: Set<BASEventLogRiskBand>?

    /// Optional row limit — exporter stops after this many
    /// events have been written。Default nil = no limit。
    public let limit: Int?

    /// When true,the exporter resolves `stateBeforeID` /
    /// `stateAfterID` against the user state store and inlines
    /// the full `BASUserState` snapshots in each datum。
    /// Increases output size ~5-10x but provides full S_t
    /// context to downstream training。Default false。
    public let includeStateContext: Bool

    public init(
        sessionID: String? = nil,
        sinceMs: Int64? = nil,
        untilMs: Int64? = nil,
        kinds: Set<BASEventLogKind>? = nil,
        riskBands: Set<BASEventLogRiskBand>? = nil,
        limit: Int? = nil,
        includeStateContext: Bool = false
    ) {
        self.sessionID = sessionID
        self.sinceMs = sinceMs
        self.untilMs = untilMs
        self.kinds = kinds
        self.riskBands = riskBands
        self.limit = limit
        self.includeStateContext = includeStateContext
    }

    /// Convenience:export everything (no filter)。
    public static let all = BASTrainingDataExportFilter()
}

// MARK: - Per-row training datum

/// Typed Codable record representing one event in the exported
/// training corpus。One JSONL line per datum。
public struct BASTrainingDatum: Codable, Equatable, Sendable {
    /// The full event log entry。
    public let event: BASEventLogEntry

    /// Optional state vector at event start (S_{t-1})。Populated
    /// when the exporter's filter has `includeStateContext: true`
    /// AND the event's `stateBeforeID` resolved against the
    /// user state store。Nil when state context disabled or the
    /// referenced state ID was missing。
    public let stateBefore: BASUserState?

    /// Optional state vector after event reducer ran (S_t)。
    /// Same nullability semantics as `stateBefore`。
    public let stateAfter: BASUserState?

    /// Wall-clock timestamp at export time (millis since UNIX
    /// epoch)。Useful for tracking when a corpus was generated。
    public let exportedAtMs: Int64

    public init(
        event: BASEventLogEntry,
        stateBefore: BASUserState? = nil,
        stateAfter: BASUserState? = nil,
        exportedAtMs: Int64
    ) {
        self.event = event
        self.stateBefore = stateBefore
        self.stateAfter = stateAfter
        self.exportedAtMs = exportedAtMs
    }
}

// MARK: - Export summary

/// Typed Codable result returned by `export(...)`。Useful for
/// host UI / log surfaces and for chained pipeline stages。
public struct BASTrainingDataExportSummary:
    Codable, Equatable, Sendable
{
    /// Number of `BASTrainingDatum` rows actually written。
    public let recordsWritten: Int

    /// Number of events read from storage but FILTERED OUT
    /// before write (didn't match filter)。
    public let recordsFilteredOut: Int

    /// Total bytes written to output file (post-encoding,
    /// post-newline)。
    public let bytesWritten: Int64

    /// Wall-clock duration of the export operation in
    /// milliseconds。
    public let durationMs: Int64

    /// Smallest `timestampMs` across all written rows,or nil
    /// if zero rows were written。
    public let firstEventTimestampMs: Int64?

    /// Largest `timestampMs` across all written rows,or nil
    /// if zero rows were written。
    public let lastEventTimestampMs: Int64?

    /// M906 audit-finding fix:count of events whose
    /// `stateBeforeID` / `stateAfterID` was non-nil but the
    /// state store returned nil on lookup (state was pruned,
    /// ID was corrupt,or store wasn't wired)。Pre-M906 this
    /// was silently swallowed → a corpus with 30% missing
    /// state context looked fine to consumers。Post-M906
    /// callers see the count + can warn / abort if too high。
    /// Always 0 when `filter.includeStateContext == false`。
    public let stateContextMissingCount: Int

    public init(
        recordsWritten: Int,
        recordsFilteredOut: Int,
        bytesWritten: Int64,
        durationMs: Int64,
        firstEventTimestampMs: Int64?,
        lastEventTimestampMs: Int64?,
        stateContextMissingCount: Int = 0
    ) {
        self.recordsWritten = recordsWritten
        self.recordsFilteredOut = recordsFilteredOut
        self.bytesWritten = bytesWritten
        self.durationMs = durationMs
        self.firstEventTimestampMs = firstEventTimestampMs
        self.lastEventTimestampMs = lastEventTimestampMs
        self.stateContextMissingCount =
            stateContextMissingCount
    }
}

// MARK: - Errors

public enum BASTrainingDataExportError: Error, Sendable {
    case fileCreateFailed(URL, underlyingError: String)
    case fileWriteFailed(URL, underlyingError: String)
    case stateContextRequestedButNoStore
}

// MARK: - Exporter

/// Actor that walks the event log in pages and writes a JSONL
/// training corpus to a URL。Single-shot — caller constructs,
/// runs `export(...)` once,reads result,discards。
public actor BASTrainingDataExporter {

    /// chapter 一百八十五 anti-magic-number — page size for
    /// SQLite fetch。10_000 balances memory (one batch ~1-5MB
    /// peak) against fetch round-trips。
    public static let defaultPageSize: Int = 10_000

    private let eventLog: any BASEventLogStorage
    private let userStateStore: (any BASUserStateStorage)?
    private let pageSize: Int

    public init(
        eventLog: any BASEventLogStorage,
        userStateStore: (any BASUserStateStorage)? = nil,
        pageSize: Int = BASTrainingDataExporter.defaultPageSize
    ) {
        precondition(pageSize > 0,
            "pageSize must be > 0")
        self.eventLog = eventLog
        self.userStateStore = userStateStore
        self.pageSize = pageSize
    }

    /// Export the filtered event corpus as JSONL to `url`。
    /// Atomic temp-file-rename pattern:writes to `url + ".tmp"`
    /// first,then renames to `url` on success。Partial state on
    /// any failure cleans up the temp file。
    ///
    /// One JSON object per line,UTF-8 encoded,LF terminator
    /// (no CRLF)。Caller's pipeline can stream-parse via any
    /// JSONL-aware reader (jq,Python json.loads per line,
    /// MLX Datum loaders)。
    ///
    /// ## M906 determinism contract
    ///
    /// Pass `exportedAtMs:` explicitly to get byte-stable output
    /// across re-runs of the same corpus + filter (M892 replay
    /// determinism doctrine)。Default reads wall-clock,which
    /// produces different bytes per call — useful for ergonomic
    /// single-shot use,but breaks G8 SSM training cache keys
    /// + G12 eval baselines that hash the corpus。
    public func exportToJSONL(
        filter: BASTrainingDataExportFilter,
        to url: URL,
        exportedAtMs: Int64? = nil
    ) async throws -> BASTrainingDataExportSummary {
        if filter.includeStateContext && userStateStore == nil
        {
            throw BASTrainingDataExportError
                .stateContextRequestedButNoStore
        }

        let startMs = Int64(
            Date().timeIntervalSince1970 * 1000)
        // M906:reset per-export so consecutive exportToJSONL
        // calls on the same actor see fresh counts。
        stateContextMissingCount = 0

        // Atomic temp-file-rename pattern。
        let tempURL = url.appendingPathExtension("tmp")
        // Defensive cleanup of stale temp file from prior run。
        try? FileManager.default.removeItem(at: tempURL)

        guard FileManager.default.createFile(
            atPath: tempURL.path,
            contents: nil)
        else {
            throw BASTrainingDataExportError.fileCreateFailed(
                tempURL,
                underlyingError: "createFile returned false")
        }

        let handle: FileHandle
        do {
            handle = try FileHandle(forWritingTo: tempURL)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw BASTrainingDataExportError.fileCreateFailed(
                tempURL,
                underlyingError: "\(error)")
        }
        defer {
            try? handle.close()
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys,
                                    .withoutEscapingSlashes]

        var recordsWritten = 0
        var recordsFilteredOut = 0
        var bytesWritten: Int64 = 0
        var firstTs: Int64? = nil
        var lastTs: Int64? = nil

        // M910 (audit-the-fix re-fix):track the LAST-SEEN
        // (ts, seq) for dedup purposes,not last-EMITTED。
        //
        // M906 used `lastEmittedTs/Seq` which only advanced on
        // writes,not on filter-rejects。An all-filter-rejected
        // same-ts cluster bigger than pageSize would re-fetch
        // forever:
        //   - Page N filter-rejects 10 same-ts events;
        //     lastEmitted unchanged (no writes)
        //   - Page N+1 fetches `>= cursor`,gets the SAME 10
        //     events,each passes dedup (lastEmittedTs still
        //     stale),each filter-rejects again,
        //     newEventsThisPage = 10 → cursor doesn't bump
        //   - Repeat forever
        // Post-M910 we advance `lastSeenTs/Seq` on EVERY event
        // that passes dedup,whether it's emitted or filter-
        // rejected,so the dedup pointer moves through the
        // cluster regardless of filter outcome。Then the cursor-
        // bump escape can correctly fire on a stuck page。
        var lastSeenTs: Int64 = .min
        var lastSeenSeq: Int64 = .min

        var cursorMs: Int64 = filter.sinceMs ?? 0
        let untilMs: Int64 = filter.untilMs ?? .max
        // M906:caller-supplied or wall-clock fallback。Wall-clock
        // breaks byte-stable determinism;explicit value preserves
        // M892 replay-determinism doctrine for downstream caches。
        // M910 hardening:precondition guards against
        // arithmetically-impossible exportedAtMs values。
        if let pinned = exportedAtMs {
            precondition(pinned >= 0,
                "exportedAtMs must be non-negative; " +
                "caller passed \(pinned)")
        }
        let resolvedExportedAtMs: Int64 = exportedAtMs
            ?? Int64(Date().timeIntervalSince1970 * 1000)

        pageLoop: while true {
            let batch = await eventLog.events(
                sinceTimestampMs: cursorMs, limit: pageSize)
            if batch.isEmpty { break }

            // M910:track WRITES this page (not "events seen")
            // so the cursor-bump escape correctly fires when a
            // full-size page makes no FORWARD progress (every
            // row was a dedup repeat,regardless of filter)。
            var advancedThisPage = 0

            for event in batch {
                if event.timestampMs >= untilMs {
                    break pageLoop
                }
                // M910:dedup uses lastSeenTs/Seq which advance
                // on EVERY event that we've already processed
                // (emitted or filter-rejected),so an all-
                // filter-rejected same-ts cluster correctly
                // signals "no new events this page" once we've
                // walked the entire cluster。
                if event.timestampMs < lastSeenTs ||
                    (event.timestampMs == lastSeenTs
                     && event.sequenceNumber <= lastSeenSeq)
                {
                    continue
                }
                // Past this point the event is NEW vs. prior
                // pages,so it counts as forward progress for
                // cursor advancement regardless of filter
                // outcome。
                advancedThisPage += 1
                lastSeenTs = event.timestampMs
                lastSeenSeq = event.sequenceNumber

                if !passesFilter(event, filter: filter) {
                    recordsFilteredOut += 1
                    continue
                }

                let datum = await makeDatum(
                    event: event,
                    includeStateContext:
                        filter.includeStateContext,
                    exportedAtMs: resolvedExportedAtMs)

                let line: Data
                do {
                    let json = try encoder.encode(datum)
                    line = json + Data([0x0A])  // LF
                } catch {
                    try? FileManager.default
                        .removeItem(at: tempURL)
                    throw BASTrainingDataExportError
                        .fileWriteFailed(
                            tempURL,
                            underlyingError:
                                "encode failed: \(error)")
                }

                do {
                    try handle.write(contentsOf: line)
                } catch {
                    try? FileManager.default
                        .removeItem(at: tempURL)
                    throw BASTrainingDataExportError
                        .fileWriteFailed(
                            tempURL,
                            underlyingError: "\(error)")
                }

                recordsWritten += 1
                bytesWritten += Int64(line.count)
                if firstTs == nil
                    || event.timestampMs < (firstTs ?? .max)
                {
                    firstTs = event.timestampMs
                }
                if lastTs == nil
                    || event.timestampMs > (lastTs ?? .min)
                {
                    lastTs = event.timestampMs
                }

                if let cap = filter.limit,
                   recordsWritten >= cap
                {
                    break pageLoop
                }
            }

            // If batch came back smaller than page size,we've
            // hit the tail of the log。
            if batch.count < pageSize { break }

            // M906/M910:advance cursor with infinite-loop guard。
            // If a full-size page made zero forward progress
            // (every row was a dedup repeat from prior page,
            // i.e. all rows share the same timestampMs as the
            // cursor),we MUST bump cursor by 1ms to escape the
            // cluster — otherwise we re-fetch the same rows
            // forever。
            //
            // ## Documented trade-off
            //
            // The storage protocol's `events(sinceTimestampMs:
            // limit:)` has NO per-row offset。So when a same-ts
            // cluster is bigger than pageSize,we walk the
            // FIRST `pageSize` rows of the cluster and then
            // bump past `cursorMs` — necessarily LOSING the
            // cluster's tail (rows with seq >= pageSize at the
            // same ts)。This is preferable to an infinite loop
            // but it IS a corpus-completeness gap。Hosts that
            // need full coverage of pathological clusters
            // should:
            //   1. configure a pageSize >= max-expected-cluster-
            //      size,or
            //   2. extend the storage protocol with a
            //      `(ts, seq)` cursor in a future M-number
            //
            // M910 wraparound fix:use `addingReportingOverflow`
            // instead of `&+`。If the cursor is already at
            // Int64.max,wrapping to Int64.min would re-fetch
            // the entire log forever。Instead we break out
            // cleanly。
            if let last = batch.last {
                let candidate = last.timestampMs
                if candidate <= cursorMs
                    && advancedThisPage == 0
                {
                    let (next, ovf) = candidate
                        .addingReportingOverflow(1)
                    if ovf {
                        // At Int64.max — no further events
                        // possible,exit cleanly。
                        break
                    }
                    cursorMs = next
                } else {
                    cursorMs = candidate
                }
            } else {
                break
            }
        }

        // Close before rename (some filesystems want the
        // handle released first)。
        try? handle.close()

        // Atomic rename。
        do {
            // Remove existing destination (if any) to allow
            // overwrite — `replaceItemAt` would also work but
            // is more I/O on iOS where temp dir may be on a
            // different volume。
            if FileManager.default.fileExists(atPath: url.path)
            {
                try FileManager.default.removeItem(at: url)
            }
            try FileManager.default.moveItem(
                at: tempURL, to: url)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw BASTrainingDataExportError.fileWriteFailed(
                url, underlyingError:
                    "rename failed: \(error)")
        }

        let endMs = Int64(
            Date().timeIntervalSince1970 * 1000)

        return BASTrainingDataExportSummary(
            recordsWritten: recordsWritten,
            recordsFilteredOut: recordsFilteredOut,
            bytesWritten: bytesWritten,
            durationMs: endMs - startMs,
            firstEventTimestampMs: firstTs,
            lastEventTimestampMs: lastTs,
            stateContextMissingCount:
                stateContextMissingCount)
    }

    // MARK: - Private helpers

    private nonisolated func passesFilter(
        _ event: BASEventLogEntry,
        filter: BASTrainingDataExportFilter
    ) -> Bool {
        if let sid = filter.sessionID,
           event.sessionID != sid
        {
            return false
        }
        // M906 fix:empty Set means "no constraint" not "match
        // nothing"。Pre-M906 a caller that built a filter set
        // dynamically and ended with an empty Set (e.g. UI
        // selection cleared) would silently get zero rows
        // instead of all rows。Post-M906 only NON-EMPTY sets
        // act as constraints。
        if let kinds = filter.kinds,
           !kinds.isEmpty,
           !kinds.contains(event.kind)
        {
            return false
        }
        if let bands = filter.riskBands,
           !bands.isEmpty,
           !bands.contains(event.riskBand)
        {
            return false
        }
        return true
    }

    /// M906 audit fix:counter incremented inside `makeDatum`
    /// whenever a non-nil state ID failed to resolve in the
    /// store。Read by `exportToJSONL(...)` on completion to
    /// surface in the summary。Reset per-export at the start
    /// of `exportToJSONL`。
    private var stateContextMissingCount: Int = 0

    private func makeDatum(
        event: BASEventLogEntry,
        includeStateContext: Bool,
        exportedAtMs: Int64
    ) async -> BASTrainingDatum {
        guard includeStateContext,
              let store = userStateStore
        else {
            return BASTrainingDatum(
                event: event,
                stateBefore: nil,
                stateAfter: nil,
                exportedAtMs: exportedAtMs)
        }
        let stateBefore: BASUserState?
        if let id = event.stateBeforeID {
            let resolved = await store.state(forID: id)
            if resolved == nil {
                stateContextMissingCount += 1
            }
            stateBefore = resolved
        } else {
            stateBefore = nil
        }
        let stateAfter: BASUserState?
        if let id = event.stateAfterID {
            let resolved = await store.state(forID: id)
            if resolved == nil {
                stateContextMissingCount += 1
            }
            stateAfter = resolved
        } else {
            stateAfter = nil
        }
        return BASTrainingDatum(
            event: event,
            stateBefore: stateBefore,
            stateAfter: stateAfter,
            exportedAtMs: exportedAtMs)
    }
}
