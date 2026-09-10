import XCTest
import BASObservability

/// M298 — pin the contract `QinaoSampleHost --full-stack-demo`
/// relies on after wiring `BASUnifiedStorageLocator.locate(in:)`
/// into Step 2 of the demo.
///
/// `QinaoSampleHost` is an executable, so its `runFullStackDemo()`
/// closure cannot be invoked from XCTest. These tests instead pin
/// the **substrate contract** the demo consumes, so any breaking
/// rename / move / semantic shift in `BASUnifiedStorageLocator`
/// surfaces as a Qinao-side test failure (mirrors how M180 pins
/// `BASOrgan` factory shape from the SDK consumer perspective).
///
/// What this file pins:
///
///   1. Canonical filenames stay byte-equal to what the demo
///      prints in Step 2 (`sovereign-audit.sqlite` /
///      `lifecycle.sqlite`).
///   2. `locate(in:)` returns three URLs that share one parent
///      path — the deployment-root invariant that lets the demo
///      put a JSON file alongside the SQLite stores without
///      crossing roots.
///   3. `ensureRootDirectory(at:)` is idempotent — the demo can
///      re-enter without resetting state.
///   4. The demo's add-on JSON file pattern (`root +
///      "lifecycle.json"`) coexists with the canonical SQLite
///      paths under the same root (M298's lift-without-leak
///      promise).
final class QinaoSampleHostUnifiedLocatorTests: XCTestCase {

    private func makeRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "qinao-m298-test-\(UUID().uuidString)")
    }

    /// 1. Canonical filenames match the strings printed inside
    ///    the demo's Step 2 banner. If either constant drifts,
    ///    the demo's output drifts and downstream audit tooling
    ///    that grep-matches these names breaks.
    func testCanonicalFilenamesMatchDemoBanner() {
        XCTAssertEqual(
            BASUnifiedStorageLocator.auditLedgerFilename,
            "sovereign-audit.sqlite")
        XCTAssertEqual(
            BASUnifiedStorageLocator.lifecycleFilename,
            "lifecycle.sqlite")
    }

    /// 2. Both URLs and the JSON sidecar that the demo writes
    ///    must resolve to the same parent path. Without this,
    ///    the M298 banner ("unified root") is a lie — files
    ///    would scatter across directories.
    func testDemoPathsAllShareUnifiedRoot() throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let locations = try BASUnifiedStorageLocator.locate(
            in: root)
        // Demo's pattern: JSON sidecar inside the unified root.
        let demoJSON = locations.root
            .appendingPathComponent("lifecycle.json")

        XCTAssertEqual(
            locations.root.path, root.path)
        XCTAssertEqual(
            locations.auditLedgerURL
                .deletingLastPathComponent().path,
            root.path)
        XCTAssertEqual(
            locations.lifecycleURL
                .deletingLastPathComponent().path,
            root.path)
        XCTAssertEqual(
            demoJSON.deletingLastPathComponent().path,
            root.path,
            "demo's JSON sidecar must land under the same " +
            "unified root as the canonical SQLite stores")
    }

    /// 3. `ensureRootDirectory(at:)` must be idempotent so the
    ///    demo can be re-entered without crashing on the second
    ///    call. The locator's contract promises this; we pin it
    ///    here so a regression in the substrate is caught from
    ///    the SDK side.
    func testEnsureRootIsIdempotentForDemoReentry() throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try BASUnifiedStorageLocator.ensureRootDirectory(
            at: root)
        // Simulate demo re-run hitting the same root.
        try BASUnifiedStorageLocator.ensureRootDirectory(
            at: root)
        try BASUnifiedStorageLocator.ensureRootDirectory(
            at: root)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: root.path))
    }

    /// 4. `locate(in:)` is a one-shot bundle that creates the
    ///    root directory AND returns the canonical three URLs.
    ///    The demo's Step 2 trusts this single call — if either
    ///    the side-effect (mkdir) or the bundling (3 URLs)
    ///    drifts, the demo breaks.
    func testLocateBundlesAndCreates() throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: root.path))
        let locations = try BASUnifiedStorageLocator.locate(
            in: root)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: root.path),
            "locate must create the root directory as a side " +
            "effect — the demo relies on this single call")
        XCTAssertEqual(
            locations.auditLedgerURL.lastPathComponent,
            BASUnifiedStorageLocator.auditLedgerFilename)
        XCTAssertEqual(
            locations.lifecycleURL.lastPathComponent,
            BASUnifiedStorageLocator.lifecycleFilename)
    }

    /// 5. Two distinct demo runs (different UUID-suffixed roots)
    ///    must not collide. The demo uses
    ///    `temporaryDirectory + "qinao-full-stack-demo-{uuid}"`
    ///    so concurrent runs do not stomp each other's state.
    func testIndependentRootsDoNotShareFiles() throws {
        let r1 = makeRoot()
        let r2 = makeRoot()
        defer {
            try? FileManager.default.removeItem(at: r1)
            try? FileManager.default.removeItem(at: r2)
        }
        let l1 = try BASUnifiedStorageLocator.locate(in: r1)
        let l2 = try BASUnifiedStorageLocator.locate(in: r2)

        XCTAssertNotEqual(
            l1.auditLedgerURL.path, l2.auditLedgerURL.path)
        XCTAssertNotEqual(
            l1.lifecycleURL.path, l2.lifecycleURL.path)
        XCTAssertNotEqual(l1.root.path, l2.root.path)
    }
}
