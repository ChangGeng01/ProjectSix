import XCTest

/// gaps-reconciliation x-sovereignty #7 (2026-07-11): the SampleHost stress-run report used to
/// persist UIDevice.identifierForVendor — a PERSISTENT device identifier — into shareable run
/// JSON. Fixed to a per-run random UUID. This tripwire pins the sovereignty doctrine at the
/// SOURCE level (SampleHost is an iOS-only package whose tests don't run on this Mac bundle):
/// no code under SampleHost/ may read a persistent device identifier into a persisted artifact.
final class BASSampleHostDeviceIdentifierTripwireTests: XCTestCase {

    func testNoPersistentDeviceIdentifierUnderSampleHost() throws {
        // …/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/<this> → repo root is 3 up,
        // SampleHost is a sibling of BehavioralAISubstrate inside the same git repo.
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let sampleHost = repoRoot.appendingPathComponent("SampleHost")
        guard FileManager.default.fileExists(atPath: sampleHost.path) else {
            throw XCTSkip("SampleHost sibling not present (source-stripped checkout)")
        }
        var offenders: [String] = []
        let fm = FileManager.default
        let en = fm.enumerator(at: sampleHost, includingPropertiesForKeys: nil)
        while let f = en?.nextObject() as? URL {
            guard f.pathExtension == "swift" else { continue }
            let src = (try? String(contentsOf: f, encoding: .utf8)) ?? ""
            for (n, line) in src.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
            where line.contains(".identifierForVendor?")
                && !line.trimmingCharacters(in: .whitespaces).hasPrefix("//")
                && !line.trimmingCharacters(in: .whitespaces).hasPrefix("///") {
                offenders.append("\(f.lastPathComponent):\(n + 1)  \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        XCTAssertTrue(offenders.isEmpty,
            "sovereignty doctrine: no persistent device identifier may be read into SampleHost "
            + "artifacts (use a per-run UUID). Offenders:\n" + offenders.joined(separator: "\n"))
    }
}
