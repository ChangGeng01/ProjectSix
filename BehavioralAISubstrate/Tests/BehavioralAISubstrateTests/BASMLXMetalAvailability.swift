import MLX
import XCTest

/// Headless-session guard for suites that run REAL MLX compute without a model/env gate.
///
/// MLX's first Metal touch loads the Cmlx `default.metallib`; when that load fails (a no-Aqua
/// `swift test` session where the bundle lookup / Metal service is unavailable) the mlx-c
/// DEFAULT error handler prints `MLX error: Failed to load the default metallib.` and
/// `exit(-1)`s the WHOLE xctest process — the headless gate dies at the tail with one line and
/// thousands of unrelated tests never run.
///
/// This probe makes the same first touch inside `withError { }`, which scopes an error handler
/// that converts the C++ error into a Swift `throw` (catchable) instead of a process exit, so
/// the affected suites can skip LOUDLY and the rest of the gate survives.
enum BASMLXMetalAvailability {
    /// nil ⇒ MLX Metal is usable in this process; else the human-readable reason.
    /// Probed once per process (static-let memoization) — the outcome cannot change mid-run.
    static let unavailableReason: String? = {
        do {
            try withError {
                let x = MLXArray([Float(1), 2, 3])
                eval(x + x)
            }
            return nil
        } catch {
            return "MLX Metal unavailable in this session: \(error)"
        }
    }()

    /// Call from `setUpWithError()` of any suite doing ungated MLX compute.
    /// The `reason` parameter exists so the skip seam itself is unit-testable in a GUI session.
    static func skipIfUnavailable(_ reason: String? = unavailableReason) throws {
        if let reason {
            throw XCTSkip(reason)
        }
    }
}

final class BASMLXMetalAvailabilityTests: XCTestCase {

    // The skip seam: a non-nil reason must skip, a nil reason must not.
    func testSkipSeamThrowsSkipForReasonAndPassesForNil() throws {
        XCTAssertNoThrow(try BASMLXMetalAvailability.skipIfUnavailable(nil))
        XCTAssertThrowsError(try BASMLXMetalAvailability.skipIfUnavailable("metallib gone")) {
            XCTAssertTrue($0 is XCTSkip, "the seam must skip, not fail; got \($0)")
        }
    }

    // Wiring lint: every suite known to run MLX compute WITHOUT a model/env gate must call the
    // probe — otherwise a headless metallib failure exit(-1)s the whole gate again. Source-tree
    // lint ⇒ macOS host only (device bundles carry no source checkout).
    func testUngatedMLXSuitesCallTheHeadlessProbe() throws {
        #if os(macOS)
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: dir.path) else {
            throw XCTSkip("source tree not present (built bundle) — host-only lint")
        }
        let ungatedMLXSuites = [
            "BASMTPSamplingLosslessTests.swift",
            "BASSessionKVStoreQuantizeTests.swift",
            "BASSessionKVStoreModelIDTests.swift",
        ]
        for file in ungatedMLXSuites {
            let source = try String(contentsOf: dir.appendingPathComponent(file), encoding: .utf8)
            XCTAssertTrue(
                source.contains("BASMLXMetalAvailability.skipIfUnavailable"),
                "\(file) runs ungated MLX compute — it must probe-skip or it kills headless runs")
        }
        #else
        throw XCTSkip("source-tree lint is host-only")
        #endif
    }
}
