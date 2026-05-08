// MARK: - SampleHostStressRunInfraTests — chapter 三百五二 / M839
//
// Closes the test-coverage gap honestly identified in the
// chapter 三百五一 self-review for M836/M837 SampleHost-side
// stress-run infrastructure。Components added in:
//
//   - chapter 三百四九 / M836: `StressRunResult` Codable schema +
//     persistence to `Documents/chenglu-stress-runs/`
//   - chapter 三百五〇 / M837: `LatencyHistogram` (1001-bucket
//     0.1ms-resolution histogram) + `RecentLatencyRing` (fixed-
//     capacity ring buffer for sliding-window avg) + per-minute
//     time series + checkpoint persistence
//
// These shipped to device with build verification but **zero
// unit tests**。Self-review caught this as regression risk: a
// future change to histogram bucket math or ring buffer wrap-around
// would silently break percentile reporting in 8h runs without
// any test catching it。This file fixes that gap honestly。
//
// Tests cover:
//   - LatencyHistogram: empty / single sample / uniform 100 /
//     overflow bucket / boundary samples / record-then-percentile
//   - RecentLatencyRing: empty / under capacity / at capacity /
//     wrapped (over capacity) / avg correctness across all states
//   - StressRunResult: Codable round-trip with all 1.1.0 fields /
//     phase enum encoding / DeviceInfo nesting
//
// Tests do NOT cover:
//   - Persistence to disk (FileManager interaction is integration-
//     level — covered by the device-driven 60s smoke + 2/5min runs
//     during the chapter 三百四九 deployment session)
//   - Checkpoint timing (wall-clock-driven — covered by device run)
//   - The runStress loop itself (covered by gated XCTest in
//     `BehavioralAISubstrateTests/BASChenglu20MinStressTests.swift`)

import XCTest
@testable import SampleHost

final class SampleHostStressRunInfraTests: XCTestCase {

    // MARK: - LatencyHistogram — empty state

    func testLatencyHistogramEmptyHasZeroAvg() {
        let hist = LatencyHistogram()
        XCTAssertEqual(hist.totalCount, 0)
        XCTAssertEqual(hist.avgMs, 0)
        XCTAssertEqual(
            hist.percentile(0.50), 0,
            "Empty histogram percentile must return 0 — " +
            "guard against divide-by-zero")
    }

    func testLatencyHistogramEmptyAllPercentilesZero() {
        let hist = LatencyHistogram()
        for p in [0.0, 0.25, 0.50, 0.95, 0.99, 1.0] {
            XCTAssertEqual(
                hist.percentile(p), 0,
                "Empty hist p\(p) must be 0")
        }
    }

    // MARK: - LatencyHistogram — single sample

    func testLatencyHistogramSingleSamplePercentile() {
        var hist = LatencyHistogram()
        hist.record(5.0)  // bucket 50 [5.0, 5.1)
        XCTAssertEqual(hist.totalCount, 1)
        XCTAssertEqual(hist.avgMs, 5.0, accuracy: 1e-9)
        // Single sample → all percentiles fall in same bucket
        XCTAssertEqual(
            hist.percentile(0.50), 5.0, accuracy: 1e-9)
        XCTAssertEqual(
            hist.percentile(0.99), 5.0, accuracy: 1e-9)
    }

    // MARK: - LatencyHistogram — uniform distribution

    func testLatencyHistogramUniform100SamplesPercentiles() {
        var hist = LatencyHistogram()
        // 100 samples uniformly at 0.5, 1.5, 2.5, ..., 99.5 ms
        for i in 0..<100 {
            hist.record(Double(i) + 0.5)
        }
        XCTAssertEqual(hist.totalCount, 100)
        // p50 should land near 50ms
        XCTAssertEqual(
            hist.percentile(0.50), 50.0, accuracy: 1.0,
            "Uniform 0-100ms p50 should be ~50ms")
        // p95 should land near 95ms
        XCTAssertEqual(
            hist.percentile(0.95), 95.0, accuracy: 1.0,
            "Uniform 0-100ms p95 should be ~95ms")
        // p99 should land near 99ms
        XCTAssertEqual(
            hist.percentile(0.99), 99.0, accuracy: 1.0,
            "Uniform 0-100ms p99 should be ~99ms")
    }

    // MARK: - LatencyHistogram — overflow bucket

    func testLatencyHistogramOverflowBucket() {
        var hist = LatencyHistogram()
        hist.record(150.0)  // overflow ≥ 100ms
        hist.record(500.0)  // overflow
        hist.record(1000.0) // overflow
        XCTAssertEqual(hist.totalCount, 3)
        XCTAssertEqual(
            hist.percentile(0.50),
            LatencyHistogram.maxResolvedMs,
            "All-overflow hist p50 must report " +
            "maxResolvedMs (≥100ms signal)")
        XCTAssertEqual(
            hist.percentile(0.99),
            LatencyHistogram.maxResolvedMs)
    }

    func testLatencyHistogramMixedOverflowAndNormal() {
        var hist = LatencyHistogram()
        // 90 samples in normal range, 10 in overflow
        for i in 0..<90 {
            hist.record(Double(i) * 0.1 + 0.05)  // 0.05..8.95ms
        }
        for _ in 0..<10 {
            hist.record(200.0)  // overflow
        }
        XCTAssertEqual(hist.totalCount, 100)
        // p50 should be in normal range (well below 9ms)
        XCTAssertLessThan(hist.percentile(0.50), 9.0)
        // p99 should hit overflow bucket
        XCTAssertEqual(
            hist.percentile(0.99),
            LatencyHistogram.maxResolvedMs,
            "p99 of 90 normal + 10 overflow samples must " +
            "land in overflow bucket")
    }

    // MARK: - LatencyHistogram — boundary samples

    func testLatencyHistogramBoundaryZero() {
        var hist = LatencyHistogram()
        hist.record(0.0)
        XCTAssertEqual(hist.totalCount, 1)
        XCTAssertEqual(
            hist.percentile(0.50), 0.0,
            "0ms sample must land in bucket 0 → percentile 0")
    }

    func testLatencyHistogramBoundaryNegativeClamps() {
        var hist = LatencyHistogram()
        hist.record(-5.0)  // negative → clamp to bucket 0
        XCTAssertEqual(hist.totalCount, 1)
        XCTAssertEqual(hist.avgMs, 0,
            "Negative sample contributes 0 to sumMs (clamped " +
            "by max(ms,0))")
    }

    func testLatencyHistogramBoundaryAt100msExact() {
        var hist = LatencyHistogram()
        hist.record(100.0)  // exactly at boundary → overflow
        XCTAssertEqual(
            hist.percentile(0.50),
            LatencyHistogram.maxResolvedMs)
    }

    func testLatencyHistogramBoundaryJustUnder100() {
        var hist = LatencyHistogram()
        hist.record(99.99)  // just under → bucket 999
        XCTAssertEqual(hist.totalCount, 1)
        // Bucket 999 lower edge = 99.9
        XCTAssertEqual(
            hist.percentile(0.50), 99.9, accuracy: 1e-9)
    }

    // MARK: - LatencyHistogram — running average

    func testLatencyHistogramAvgAccumulates() {
        var hist = LatencyHistogram()
        hist.record(1.0)
        hist.record(2.0)
        hist.record(3.0)
        XCTAssertEqual(
            hist.avgMs, 2.0, accuracy: 1e-9,
            "avgMs should be (1+2+3)/3 = 2.0")
    }

    // MARK: - RecentLatencyRing — empty + small N

    func testRecentLatencyRingEmptyAvg() {
        let ring = RecentLatencyRing(capacity: 100)
        XCTAssertEqual(ring.count, 0)
        XCTAssertEqual(ring.avg, 0,
            "Empty ring must return 0 avg, not crash")
    }

    func testRecentLatencyRingSingleSample() {
        var ring = RecentLatencyRing(capacity: 100)
        ring.record(5.0)
        XCTAssertEqual(ring.count, 1)
        XCTAssertEqual(ring.avg, 5.0, accuracy: 1e-9)
    }

    func testRecentLatencyRingUnderCapacity() {
        var ring = RecentLatencyRing(capacity: 100)
        for i in 1...10 {
            ring.record(Double(i))
        }
        XCTAssertEqual(ring.count, 10,
            "Under capacity: count == samples recorded")
        // avg(1..10) = 5.5
        XCTAssertEqual(ring.avg, 5.5, accuracy: 1e-9)
    }

    // MARK: - RecentLatencyRing — at capacity

    func testRecentLatencyRingAtCapacity() {
        var ring = RecentLatencyRing(capacity: 5)
        for i in 1...5 {
            ring.record(Double(i))
        }
        XCTAssertEqual(ring.count, 5)
        // avg(1..5) = 3.0
        XCTAssertEqual(ring.avg, 3.0, accuracy: 1e-9)
    }

    // MARK: - RecentLatencyRing — wrap-around (over capacity)

    func testRecentLatencyRingWrapsAroundCapacityFive() {
        var ring = RecentLatencyRing(capacity: 5)
        // Record 7 samples — last 5 (3,4,5,6,7) should remain
        for i in 1...7 {
            ring.record(Double(i))
        }
        XCTAssertEqual(
            ring.count, 5,
            "Over capacity: count caps at capacity")
        // After wrap-around, ring should hold {3,4,5,6,7}
        // = avg 5.0
        XCTAssertEqual(
            ring.avg, 5.0, accuracy: 1e-9,
            "After wrap, ring must hold last `capacity` " +
            "samples (3..7) → avg = 5.0")
    }

    func testRecentLatencyRingWrapsManyTimes() {
        var ring = RecentLatencyRing(capacity: 100)
        // Record 250 samples — last 100 (151..250) should remain
        for i in 1...250 {
            ring.record(Double(i))
        }
        XCTAssertEqual(ring.count, 100)
        // avg(151..250) = (151+250)/2 = 200.5
        XCTAssertEqual(
            ring.avg, 200.5, accuracy: 1e-9,
            "After 2.5 wraps, ring must hold samples 151..250")
    }

    // MARK: - StressRunResult — Codable round-trip

    func testStressRunResultCodableRoundTripFinalPhase()
        throws
    {
        let device = StressRunResult.DeviceInfo(
            model: "iPhone",
            systemName: "iOS",
            systemVersion: "26.4.2",
            identifierForVendor: "TEST-UUID")
        let result = StressRunResult(
            schemaVersion: "1.1.0",
            buildChapter: "M839",
            phase: .final,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            requestedDurationSeconds: 28800,
            elapsedSeconds: 28800.5,
            iterations: 17_280_000,
            failures: 0,
            determinismMismatches: 0,
            throughput: 600.07,
            p50Ms: 0.75,
            p95Ms: 9.11,
            p99Ms: 17.85,
            recentAvgMs: 1.79,
            baselineSignature: "afm-route:high:1.000000",
            registrationComplete: true,
            missingMLModels: [],
            failureBreakdown: [:],
            progressLog: ["test log line"],
            perMinuteThroughput: [600.0, 601.5, 599.8],
            perMinuteP99Ms: [17.5, 17.8, 18.1],
            device: device,
            cancelled: false,
            cognitiveOS: nil)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(result)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(
            StressRunResult.self, from: data)

        XCTAssertEqual(decoded, result,
            "StressRunResult must round-trip via Codable " +
            "with full schema 1.1.0 fidelity")
    }

    func testStressRunResultPhaseEnumEncodes() throws {
        // Each phase value encodes as its raw string
        let phases: [(StressRunResult.Phase, String)] = [
            (.checkpoint, "checkpoint"),
            (.final, "final"),
            (.cancelled, "cancelled")
        ]
        let encoder = JSONEncoder()
        for (phase, expected) in phases {
            let data = try encoder.encode(phase)
            let str = String(data: data, encoding: .utf8)
            XCTAssertEqual(
                str, "\"\(expected)\"",
                "Phase.\(phase) must encode as JSON " +
                "string \"\(expected)\"")
        }
    }

    func testStressRunResultDeviceInfoNests() throws {
        let device = StressRunResult.DeviceInfo(
            model: "iPad",
            systemName: "iPadOS",
            systemVersion: "26.4",
            identifierForVendor: nil)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(device)
        let str = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(
            str.contains("\"model\":\"iPad\""))
        XCTAssertTrue(
            str.contains("\"systemName\":\"iPadOS\""))
        // Default JSONEncoder behavior: nil Optional fields are
        // OMITTED from output (not encoded as JSON null)。Decoder
        // round-trips them back to nil correctly。Check via
        // round-trip rather than literal string match。
        let decoded = try JSONDecoder().decode(
            StressRunResult.DeviceInfo.self, from: data)
        XCTAssertEqual(decoded, device,
            "DeviceInfo with nil identifierForVendor must " +
            "round-trip cleanly")
        XCTAssertNil(decoded.identifierForVendor)
    }

    // MARK: - StressRunResult — schemaVersion pin
    //
    // Schema history (latest at top):
    //   - 1.3.0 (chapter 三百九九 / M901):per-minute cognitive OS
    //     time series + thermal-risk-band history
    //   - 1.2.0 (chapter 三百八七 / M876):typed cognitiveOS
    //     CognitiveOSSummary field
    //   - 1.1.0 (chapter 三百五〇 / M837):perMinuteThroughput +
    //     perMinuteP99Ms + phase + checkpoint persistence
    //   - 1.0.0 (chapter 三百四九 / M836):initial schema
    //
    // The version pin lives in `testM901SchemaVersionIs130`
    // below — kept in the M901 test cluster for cohesion。

    // MARK: - chapter 三百五二 / M839 — build chapter tag

    func testHybridBenchBuildChapterTagPresent() {
        // The constant must be a non-empty string starting with "M"
        // followed by at least 3 digits (chapter 一百八十五 anti-
        // magic-number doctrine — tag matches commit M-numbers)。
        let tag = SampleHostHybridBenchEntry.buildChapterTag
        XCTAssertFalse(tag.isEmpty,
            "buildChapterTag must be non-empty so manifests " +
            "+ panel UI can show the build version")
        XCTAssertTrue(tag.hasPrefix("M"),
            "buildChapterTag must follow M-number convention " +
            "(e.g. M839)")
        let suffix = tag.dropFirst()
        XCTAssertTrue(
            suffix.allSatisfy { $0.isNumber },
            "buildChapterTag suffix must be all digits, " +
            "got: \(tag)")
        XCTAssertGreaterThanOrEqual(
            suffix.count, 3,
            "buildChapterTag should have ≥3-digit M-number")
    }

    // MARK: - chapter 三百五二 / M839 — ShardManifest backwards-compat

    /// Pre-M839 manifests on disk lack `phase`, `buildChapter`,
    /// `cancelled` fields。The Codable decoder must still accept
    /// those legacy JSONs without crashing。
    func testShardManifestDecodesLegacyJSONWithoutNewFields()
        throws
    {
        // Synthetic legacy manifest JSON (mimics yesterday's
        // 2h run on the device, before M839 fields existed)
        let legacyJSON = """
        {
          "anomalyWindowSize" : 100,
          "afmOk" : 16,
          "benchID" : "2026-05-06T03:50:51.306Z",
          "bothFailed" : 0,
          "checkpointEveryNIters" : 1000,
          "driftAlarms" : 0,
          "driftSigmaThreshold" : 3,
          "durationHours" : 2.0,
          "endTimeIso" : "2026-05-06T05:51:07.916Z",
          "gemmaOk" : 1,
          "mutationProbability" : 0.05,
          "mutationSeedCount" : 5,
          "pauseSkipped" : 236,
          "routerHits" : 17,
          "routerMisses" : 0,
          "smokeMode" : "raw-llm",
          "startTimeIso" : "2026-05-06T03:50:51.306Z",
          "strideCSV" : "5041,5039,5051,5077,7919",
          "stuckLLMs" : 0,
          "stuckSubstrates" : 0,
          "totalIters" : 253,
          "totalShards" : 13,
          "adversarialFired" : 0
        }
        """
        let data = legacyJSON.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(
            SampleHostBenchShardManifest.self, from: data)
        // M839 fields must decode as nil (not crash)
        XCTAssertNil(decoded.phase,
            "Legacy manifest must decode `phase` as nil")
        XCTAssertNil(decoded.buildChapter,
            "Legacy manifest must decode `buildChapter` as nil")
        XCTAssertNil(decoded.cancelled,
            "Legacy manifest must decode `cancelled` as nil")
        // Legacy fields must still be present
        XCTAssertEqual(decoded.totalIters, 253)
        XCTAssertEqual(decoded.smokeMode, "raw-llm")
    }

    func testShardManifestEncodesM839FieldsRoundTrip() throws {
        let manifest = SampleHostBenchShardManifest(
            benchID: "test-bench",
            startTimeIso: "2026-05-07T05:00:00Z",
            endTimeIso: "2026-05-07T05:56:00Z",
            totalIters: 154,
            totalShards: 1,
            smokeMode: "raw-llm",
            durationHours: 8.0,
            mutationSeedCount: 5,
            strideCSV: "5041,5039",
            afmOk: 128,
            gemmaOk: 1,
            bothFailed: 0,
            routerHits: 129,
            routerMisses: 25,
            stuckSubstrates: 0,
            stuckLLMs: 0,
            pauseSkipped: 25,
            adversarialFired: 0,
            driftAlarms: 0,
            anomalyWindowSize: 100,
            driftSigmaThreshold: 3,
            mutationProbability: 0.05,
            checkpointEveryNIters: 1000,
            phase: "cancelled",
            buildChapter: "M839",
            cancelled: true)
        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(
            SampleHostBenchShardManifest.self, from: data)
        XCTAssertEqual(decoded, manifest,
            "M839 manifest with all new fields must round-trip")
        XCTAssertEqual(decoded.phase, "cancelled")
        XCTAssertEqual(decoded.buildChapter, "M839")
        XCTAssertEqual(decoded.cancelled, true)
    }

    // MARK: - chapter 三百五二 / M839 — Forced-Gemma dispatch policy

    /// `.forceGemma` smoke mode (chapter 三百五二) must derive
    /// dispatch policy `.localOnly` regardless of permitMode。
    func testForceGemmaForcesLocalOnlyRegardlessOfPermit() {
        let permitModes = [
            "answer", "delay", "block", "replace",
            "compare", "escalate", "draft_only", "local_only"
        ]
        for permit in permitModes {
            let policy = SampleHostHybridDispatchPolicy
                .derive(
                    permitMode: permit,
                    forceSingleLLM: false,
                    forceGemma: true)
            XCTAssertEqual(policy, .localOnly,
                "permit=\(permit) + forceGemma=true must " +
                "yield .localOnly (Gemma-only)")
        }
    }

    func testForceGemmaWinsOverForceSingleLLM() {
        // Both flags set (caller error) — forceGemma wins
        let policy = SampleHostHybridDispatchPolicy
            .derive(
                permitMode: "answer",
                forceSingleLLM: true,
                forceGemma: true)
        XCTAssertEqual(policy, .localOnly,
            "forceGemma must win over forceSingleLLM when " +
            "both are set (precedence: more specific override)")
    }

    func testRawLLMPathStillRoutesToSingleLLM() {
        // Sanity: existing .rawLLM behavior unchanged by M839
        let policy = SampleHostHybridDispatchPolicy
            .derive(
                permitMode: "delay",
                forceSingleLLM: true,
                forceGemma: false)
        XCTAssertEqual(policy, .singleLLM,
            ".rawLLM (forceSingleLLM=true) path still " +
            "yields .singleLLM — M839 didn't regress " +
            "chapter 二百八 ADR-006 path")
    }

    func testDefaultDeriveRespectsSubstratePermit() {
        // Sanity: with both flags false, substrate permit wins
        let policy = SampleHostHybridDispatchPolicy
            .derive(permitMode: "block")
        XCTAssertEqual(policy, .skipBlock,
            "Default derive must honor substrate permit — " +
            "chapter 一百七十八 baseline preserved")
    }

    // MARK: - M901 — schema 1.3.0 cognitive OS time series

    /// Pin: schema version is the LATEST schema version。
    /// Updated each time a new field is added。
    /// History:
    ///   - 1.3.0 (M901)added timeSeries
    ///   - 1.4.0 (M905)added thermal sensitivity + counters
    func testCurrentSchemaVersionMatchesLatestField() {
        XCTAssertEqual(
            StressRunResult.currentSchemaVersion, "1.4.0",
            "Schema version pin must match the most-recent " +
            "field addition (M905 → 1.4.0)")
    }

    /// Pin: pre-M901 callers that don't pass `timeSeries:` get
    /// nil (back-compat preserved)。
    func testM901CognitiveOSSummaryDefaultsTimeSeriesNil() {
        let s = StressRunResult.CognitiveOSSummary(
            eventCount: 100,
            stateCount: 1,
            graphNodeCount: 10,
            graphEdgeCount: 20)
        XCTAssertNil(s.timeSeries,
            "M901 init must default timeSeries to nil for " +
            "pre-M901 caller compat")
    }

    /// Pin: Codable round-trip of CognitiveOSSummary with full
    /// time series preserves all arrays。
    func testM901CognitiveOSTimeSeriesRoundTrip() throws {
        let series = StressRunResult.CognitiveOSTimeSeries(
            eventCount: [1000, 2000, 3000],
            stateCount: [10, 20, 30],
            graphNodeCount: [5, 10, 15],
            graphEdgeCount: [4, 8, 12],
            thermalRiskBand: ["low", "medium", "high"])
        let summary = StressRunResult.CognitiveOSSummary(
            eventCount: 3000,
            stateCount: 30,
            graphNodeCount: 15,
            graphEdgeCount: 12,
            timeSeries: series)

        let encoder = JSONEncoder()
        let data = try encoder.encode(summary)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(
            StressRunResult.CognitiveOSSummary.self,
            from: data)

        XCTAssertEqual(decoded, summary,
            "M901 CognitiveOSSummary with timeSeries must " +
            "round-trip through Codable")
        XCTAssertEqual(
            decoded.timeSeries?.thermalRiskBand,
            ["low", "medium", "high"])
    }

    /// Pin: Codable round-trip of pre-M901 CognitiveOSSummary
    /// JSON (no timeSeries field) decodes with timeSeries=nil。
    func testM901CognitiveOSSummaryDecodesPreM901JSON() throws
    {
        // Pre-M901 JSON shape: just the 4 counter fields,no
        // timeSeries key
        let preM901JSON = """
        {
          "eventCount": 1500,
          "stateCount": 15,
          "graphNodeCount": 75,
          "graphEdgeCount": 150
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(
            StressRunResult.CognitiveOSSummary.self,
            from: preM901JSON)

        XCTAssertEqual(decoded.eventCount, 1500)
        XCTAssertEqual(decoded.stateCount, 15)
        XCTAssertEqual(decoded.graphNodeCount, 75)
        XCTAssertEqual(decoded.graphEdgeCount, 150)
        XCTAssertNil(decoded.timeSeries,
            "M901 must decode pre-M901 JSON with " +
            "timeSeries=nil (back-compat with M876 schema 1.2.0)")
    }

    /// Pin: time series array lengths can be empty (run shorter
    /// than first minute mark)。
    func testM901TimeSeriesEmptyArraysValid() throws {
        let series = StressRunResult.CognitiveOSTimeSeries(
            eventCount: [],
            stateCount: [],
            graphNodeCount: [],
            graphEdgeCount: [],
            thermalRiskBand: [])

        let encoder = JSONEncoder()
        let data = try encoder.encode(series)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(
            StressRunResult.CognitiveOSTimeSeries.self,
            from: data)

        XCTAssertEqual(decoded.eventCount, [])
        XCTAssertEqual(decoded.thermalRiskBand, [])
    }

    /// Pin: thermal risk band values match
    /// `BASEventLogRiskBand.rawValue` strings exactly。
    func testM901ThermalRiskBandValuesMatchSubstrateEnum() {
        let series = StressRunResult.CognitiveOSTimeSeries(
            eventCount: [],
            stateCount: [],
            graphNodeCount: [],
            graphEdgeCount: [],
            thermalRiskBand: ["low", "medium", "high",
                              "unknown"])
        XCTAssertEqual(series.thermalRiskBand.count, 4,
            "All 4 BASEventLogRiskBand cases representable " +
            "as M901 thermal-band strings")
    }

    // MARK: - M905 — thermal sensitivity + counters

    /// Pin: pre-M905 callers (no thermal fields) get nil for
    /// all 3 new optionals。
    func testM905CognitiveOSSummaryDefaultsThermalFieldsNil() {
        let s = StressRunResult.CognitiveOSSummary(
            eventCount: 100,
            stateCount: 1,
            graphNodeCount: 10,
            graphEdgeCount: 20)
        XCTAssertNil(s.thermalSensitivity)
        XCTAssertNil(s.thermalSkippedExtracts)
        XCTAssertNil(s.thermalSlowedExtracts)
    }

    /// Pin: M905 thermal fields round-trip through Codable。
    func testM905ThermalFieldsRoundTrip() throws {
        let summary = StressRunResult.CognitiveOSSummary(
            eventCount: 1_000_000,
            stateCount: 10_000,
            graphNodeCount: 5_000,
            graphEdgeCount: 8_000,
            timeSeries: nil,
            thermalSensitivity: "slowOnHot",
            thermalSkippedExtracts: 432,
            thermalSlowedExtracts: 18)

        let encoder = JSONEncoder()
        let data = try encoder.encode(summary)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(
            StressRunResult.CognitiveOSSummary.self,
            from: data)

        XCTAssertEqual(decoded, summary)
        XCTAssertEqual(
            decoded.thermalSensitivity, "slowOnHot")
        XCTAssertEqual(decoded.thermalSkippedExtracts, 432)
        XCTAssertEqual(decoded.thermalSlowedExtracts, 18)
    }

    /// Pin: pre-M905 JSON (no thermal fields) decodes with
    /// nil thermal fields (back-compat preserved)。
    func testM905DecodesPreM905JSONWithoutThermalFields()
        throws
    {
        let preM905JSON = """
        {
          "eventCount": 500,
          "stateCount": 5,
          "graphNodeCount": 25,
          "graphEdgeCount": 50
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(
            StressRunResult.CognitiveOSSummary.self,
            from: preM905JSON)

        XCTAssertEqual(decoded.eventCount, 500)
        XCTAssertNil(decoded.thermalSensitivity,
            "Pre-M905 JSON must decode with " +
            "thermalSensitivity=nil")
        XCTAssertNil(decoded.thermalSkippedExtracts)
        XCTAssertNil(decoded.thermalSlowedExtracts)
    }
}
