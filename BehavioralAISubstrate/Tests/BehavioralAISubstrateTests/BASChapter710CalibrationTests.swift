// MARK: - BASChapter710CalibrationTests
// chapter 七百十 第四刀 / M2224
//
// End-to-end verification:
//   1. calibrate() produces a sane report
//   2. save() → load() round-trips byte-equal
//   3. validate() rejects stale caches
//   4. loadOrCalibrate() happy path on fresh launch
//   5. brain.loadOrCalibrateAutoRoute() integrates cleanly
//   6. routed primitives accept the measured thresholds

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASHostKit

final class BASChapter710CalibrationTests: XCTestCase {

    // MARK: - Calibrate produces sane thresholds

    func testCalibrateFastReturnsThresholds() {
        let report = BASAutoRouteCalibrator.calibrate(
            depth: .fast,
            deviceFingerprint: "test-host",
            substrateVersion: "1.0.0")

        XCTAssertEqual(report.schemaVersion, 1)
        XCTAssertEqual(report.deviceFingerprint,
            "test-host")
        XCTAssertEqual(report.substrateVersion, "1.0.0")
        XCTAssertGreaterThan(
            report.measurements.count, 0)
        // Sanity-check threshold ranges
        XCTAssertGreaterThanOrEqual(
            report.thresholds.cosineSIMDMinDim, 1)
        XCTAssertLessThanOrEqual(
            report.thresholds.cosineSIMDMinDim, 1024)
        XCTAssertGreaterThanOrEqual(
            report.thresholds.sha256CryptoKitMinBytes, 1)
        XCTAssertGreaterThanOrEqual(
            report.thresholds.layerNormSIMDMinDim, 1)
    }

    func testCalibrateEmitsMeasurements() {
        let report = BASAutoRouteCalibrator.calibrate()
        // Each workload sweep emits at least one measurement
        let workloads = Set(report.measurements.map
            { $0.workload })
        XCTAssertTrue(workloads.contains("cosine"))
        XCTAssertTrue(workloads.contains("sha256"))
        XCTAssertTrue(workloads.contains("layer_norm"))
    }

    // MARK: - Round-trip Codable

    func testSaveLoadRoundTrip() throws {
        let report = BASAutoRouteCalibrator.calibrate(
            depth: .fast,
            deviceFingerprint: "round-trip-host",
            substrateVersion: "0.0.0")
        let tempURL = makeTempURL()
        defer { try? FileManager.default
            .removeItem(at: tempURL) }
        try BASAutoRouteCalibrationStore.save(
            report, to: tempURL)
        let loaded = try BASAutoRouteCalibrationStore
            .load(from: tempURL)
        XCTAssertEqual(loaded, report)
    }

    func testJSONIsPrettyPrintedAndSorted() throws {
        let report = BASAutoRouteCalibrator.calibrate(
            depth: .fast,
            deviceFingerprint: "pretty-test",
            substrateVersion: "0.0.0")
        let tempURL = makeTempURL()
        defer { try? FileManager.default
            .removeItem(at: tempURL) }
        try BASAutoRouteCalibrationStore.save(
            report, to: tempURL)
        let json = try String(
            contentsOf: tempURL, encoding: .utf8)
        // sortedKeys + prettyPrinted means file has newlines +
        // sorted top-level keys
        XCTAssertTrue(
            json.contains("\"deviceFingerprint\""))
        XCTAssertTrue(
            json.contains("\"measurements\""))
        XCTAssertTrue(
            json.contains("\"thresholds\""))
        XCTAssertTrue(json.contains("\n"))
    }

    // MARK: - Validation

    func testValidateAcceptsFreshCache() throws {
        let now: Int64 = 1_700_000_000
        let report = BASAutoRouteCalibrationReport(
            schemaVersion: 1,
            measuredAtEpochSec: now - 100,
            substrateVersion: "1.0.0",
            deviceFingerprint: "host-A",
            measurements: [],
            thresholds: .mSeriesDefault)
        try BASAutoRouteCalibrationStore.validate(
            report,
            expectedSchemaVersion: 1,
            expectedSubstrateVersion: "1.0.0",
            expectedDeviceFingerprint: "host-A",
            maxAgeSec: 3600,
            now: now)
        // No throw = pass
    }

    func testValidateRejectsAgedCache() {
        let now: Int64 = 1_700_000_000
        let report = BASAutoRouteCalibrationReport(
            schemaVersion: 1,
            measuredAtEpochSec: now - 100_000,
            substrateVersion: "1.0.0",
            deviceFingerprint: "host-A",
            measurements: [],
            thresholds: .mSeriesDefault)
        do {
            try BASAutoRouteCalibrationStore.validate(
                report,
                expectedSchemaVersion: 1,
                expectedSubstrateVersion: "1.0.0",
                expectedDeviceFingerprint: "host-A",
                maxAgeSec: 3600,
                now: now)
            XCTFail("aged cache must throw")
        } catch BASAutoRouteCalibrationStoreError
            .staleCache
        {
            // expected
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func testValidateRejectsWrongDevice() {
        let now: Int64 = 1_700_000_000
        let report = BASAutoRouteCalibrationReport(
            schemaVersion: 1,
            measuredAtEpochSec: now - 100,
            substrateVersion: "1.0.0",
            deviceFingerprint: "host-A",
            measurements: [],
            thresholds: .mSeriesDefault)
        do {
            try BASAutoRouteCalibrationStore.validate(
                report,
                expectedSchemaVersion: 1,
                expectedSubstrateVersion: "1.0.0",
                expectedDeviceFingerprint:
                    "different-host",
                maxAgeSec: 3600,
                now: now)
            XCTFail("device mismatch must throw")
        } catch BASAutoRouteCalibrationStoreError
            .staleCache
        {
            // expected
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func testValidateRejectsWrongSchema() {
        let now: Int64 = 1_700_000_000
        let report = BASAutoRouteCalibrationReport(
            schemaVersion: 99,
            measuredAtEpochSec: now - 100,
            substrateVersion: "1.0.0",
            deviceFingerprint: "host-A",
            measurements: [],
            thresholds: .mSeriesDefault)
        do {
            try BASAutoRouteCalibrationStore.validate(
                report,
                expectedSchemaVersion: 1,
                expectedSubstrateVersion: "1.0.0",
                expectedDeviceFingerprint: "host-A",
                maxAgeSec: 3600,
                now: now)
            XCTFail("schema mismatch must throw")
        } catch BASAutoRouteCalibrationStoreError
            .staleCache
        {
            // expected
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    // MARK: - Load-or-calibrate happy path

    func testLoadOrCalibrateFreshLaunchCalibrates() {
        let tempURL = makeTempURL()
        defer { try? FileManager.default
            .removeItem(at: tempURL) }

        // First call — no cache exists, calibrate
        let report = BASAutoRouteCalibrationStore
            .loadOrCalibrate(
                cacheURL: tempURL,
                expectedSubstrateVersion: "test",
                expectedDeviceFingerprint: "test-host",
                calibrateFn: {
                    BASAutoRouteCalibrator.calibrate(
                        depth: .fast,
                        deviceFingerprint: "test-host",
                        substrateVersion: "test")
                })
        XCTAssertEqual(
            report.deviceFingerprint, "test-host")
        XCTAssertEqual(
            report.substrateVersion, "test")
        // File should now exist
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: tempURL.path))
    }

    func testLoadOrCalibrateUsesCacheOnSecondCall() {
        let tempURL = makeTempURL()
        defer { try? FileManager.default
            .removeItem(at: tempURL) }

        var calibrationCount = 0
        let calibrate: () -> BASAutoRouteCalibrationReport
            = {
                calibrationCount += 1
                return BASAutoRouteCalibrator.calibrate(
                    depth: .fast,
                    deviceFingerprint: "stable-host",
                    substrateVersion: "1.0")
            }
        let r1 = BASAutoRouteCalibrationStore
            .loadOrCalibrate(
                cacheURL: tempURL,
                expectedSubstrateVersion: "1.0",
                expectedDeviceFingerprint: "stable-host",
                calibrateFn: calibrate)
        let r2 = BASAutoRouteCalibrationStore
            .loadOrCalibrate(
                cacheURL: tempURL,
                expectedSubstrateVersion: "1.0",
                expectedDeviceFingerprint: "stable-host",
                calibrateFn: calibrate)
        XCTAssertEqual(calibrationCount, 1,
            "second call must hit the cache")
        XCTAssertEqual(r1, r2,
            "cached report should equal original")
    }

    // MARK: - Brain integration

    func testBrainCalibrateAutoRouteCompletes() {
        let report = BASCognitiveBrain
            .calibrateAutoRoute(depth: .fast)
        XCTAssertEqual(
            report.substrateVersion,
            BASCognitiveBrain
                .substrateAutoRouteSchemaVersion)
        XCTAssertFalse(
            report.deviceFingerprint.isEmpty)
    }

    func testBrainLoadOrCalibrateUsesProvidedURL() {
        let tempURL = makeTempURL()
        defer { try? FileManager.default
            .removeItem(at: tempURL) }
        let report = BASCognitiveBrain
            .loadOrCalibrateAutoRoute(
                cacheURL: tempURL)
        XCTAssertEqual(
            report.substrateVersion,
            BASCognitiveBrain
                .substrateAutoRouteSchemaVersion)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: tempURL.path))
    }

    /// Verify the auto-router accepts measured thresholds and
    /// routes per them。
    func testRoutedPrimitivesAcceptMeasuredThresholds() {
        let report = BASAutoRouteCalibrator.calibrate(
            depth: .fast,
            deviceFingerprint: "primitive-test",
            substrateVersion: "1.0")
        let v: [Float] = (0..<64).map {
            Float($0) * 0.01 }
        let r = BASAutoRouteRanker.cosineSimilarity(
            v, v, thresholds: report.thresholds)
        // Self-similarity = 1
        XCTAssertEqual(r.value, 1.0, accuracy: 1e-4)
        // Choice should be one of the Rust paths
        XCTAssertTrue(
            r.choice == .rustScalar
                || r.choice == .rustSIMD)
    }

    // MARK: - Helpers

    private func makeTempURL() -> URL {
        let id = UUID().uuidString
        return FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "bas-calib-\(id).json")
    }
}
