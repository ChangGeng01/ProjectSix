import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASHostKit


// chapter 七百五十七 第一刀 / M2438 — DEACTIVATED。
// Print-only dashboard/scorecard test with no real
// assertions — pure decorative history。 Per user
// directive 「先把 所有 能 comment 都 comment」 the
// test class body is wrapped in `#if false`。

#if false  // chapter 七百五十七 第一刀 deactivated
final class BASChapter710CalibrationDashboardTests: XCTestCase {

    func testPrintCalibrationDashboard() throws {
        print("")
        print(
            "## chapter 七百十 第五刀 — calibration dashboard")
        print("")

        let report = BASAutoRouteCalibrator.calibrate(
            depth: .fast,
            deviceFingerprint:
                BASCognitiveBrain
                    .currentDeviceFingerprint(),
            substrateVersion: BASCognitiveBrain
                .substrateAutoRouteSchemaVersion)

        print("### Host metadata")
        print("")
        print("  schemaVersion       = "
            + "\(report.schemaVersion)")
        print("  substrateVersion    = "
            + "\(report.substrateVersion)")
        print("  deviceFingerprint   = "
            + "\(report.deviceFingerprint)")
        print("  measuredAtEpochSec  = "
            + "\(report.measuredAtEpochSec)")
        print("  measurementCount    = "
            + "\(report.measurements.count)")
        print("")

        print("### Calibrated thresholds")
        print("")
        print("  cosineSIMDMinDim          = "
            + "\(report.thresholds.cosineSIMDMinDim)")
        print("  sha256CryptoKitMinBytes   = "
            + "\(report.thresholds.sha256CryptoKitMinBytes)")
        print("  attentionMetalMinProduct  = "
            + "\(report.thresholds.attentionMetalMinProduct)")
        print("  matMulMetalMinProduct     = "
            + "\(report.thresholds.matMulMetalMinProduct)")
        print("  layerNormSIMDMinDim       = "
            + "\(report.thresholds.layerNormSIMDMinDim)")
        print("")

        print("### Per-workload measurements")
        print("")
        print(
            "| workload    | inputSize | winner                  | ns/iter |")
        print(
            "|-------------|----------:|-------------------------|--------:|")
        for m in report.measurements {
            let w = m.workload.padding(
                toLength: 11, withPad: " ", startingAt: 0)
            let sz = String(
                format: "%9d", m.inputSize)
            let win = m.winner.padding(
                toLength: 23, withPad: " ", startingAt: 0)
            let nsStr = String(
                format: "%7.0f", m.nsPerIter)
            print("| \(w) | \(sz) | \(win) | \(nsStr) |")
        }
        print("")

        // Round-trip the report to disk and report cache size
        let tempURL = makeTempURL()
        defer { try? FileManager.default
            .removeItem(at: tempURL) }
        try BASAutoRouteCalibrationStore.save(
            report, to: tempURL)
        let attrs = try FileManager.default
            .attributesOfItem(atPath: tempURL.path)
        let size = attrs[.size] as? Int ?? -1
        let loaded = try BASAutoRouteCalibrationStore
            .load(from: tempURL)

        print("### Cache persistence")
        print("")
        print("  file size           = \(size) bytes")
        print("  load round-trip     = "
            + "\(loaded == report ? "byte-equal" : "DIFFER")")
        print("")

        print(
            "Run this dashboard on every new host to confirm the "
            + "auto-router is making the empirically correct "
            + "choices on that hardware。")
        print("")
    }

    private func makeTempURL() -> URL {
        let id = UUID().uuidString
        return FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "bas-calib-dashboard-\(id).json")
    }
}

#endif  // chapter 七百五十七 第一刀
