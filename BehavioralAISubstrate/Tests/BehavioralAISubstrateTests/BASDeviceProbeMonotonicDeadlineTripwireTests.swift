import XCTest

/// gaps-reconciliation LOW-6 (2026-07-11): unattended device-probe DEADLINES must use the
/// monotonic clock — a backward NTP step under a wall-clock `while Date() < deadline` loop
/// stalls or silently extends multi-minute runs (the runner's spin was fixed in 3b0a0cd10;
/// BASQwen35MTPProbe's sustain window + cert gap were the named live mirrors). Source-level
/// tripwire: no wall-clock deadline loop pattern under DeviceTestApp/Sources.
final class BASDeviceProbeMonotonicDeadlineTripwireTests: XCTestCase {

    func testNoWallClockDeadlineLoopsUnderDeviceTestApp() throws {
        let pkgRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let sources = pkgRoot.appendingPathComponent("DeviceTestApp/Sources")
        guard FileManager.default.fileExists(atPath: sources.path) else {
            throw XCTSkip("DeviceTestApp/Sources not present")
        }
        var offenders: [String] = []
        let en = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)
        while let f = en?.nextObject() as? URL {
            guard f.pathExtension == "swift" else { continue }
            let src = (try? String(contentsOf: f, encoding: .utf8)) ?? ""
            for (n, line) in src.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
            where (line.contains("while Date() <") || line.contains("while Date()<"))
                && !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                offenders.append("\(f.lastPathComponent):\(n + 1)")
            }
        }
        XCTAssertTrue(offenders.isEmpty,
            "wall-clock deadline loops stall/extend unattended device runs on NTP steps — use "
            + "monoNowNs (DispatchTime.uptimeNanoseconds). Offenders: \(offenders)")
    }
}
