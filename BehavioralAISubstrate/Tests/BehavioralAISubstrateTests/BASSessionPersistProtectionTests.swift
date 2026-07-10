import XCTest
@testable import BASMLXAdapter
@testable import BASRuntimeCore

/// device-recon id2: Mac teeth for the x-sov #6 SessionPersist protection branch.
/// The atom-store path got invocation-counter teeth (id1); the KV-snapshot path's
/// protect-and-surface fix was uncovered because it lived inside `_persist` (needs
/// a live ChatSessionBox+model). Split into the MLX-free `_protectSnapshot` seam
/// so the session call site is Mac-testable: it invokes the shared protection
/// helper (and, per the branch, forwards a non-nil error to the session hook).
///
/// The helper RETURNING the setAttributes error instead of swallowing it is
/// proven independently in BASSQLiteFileProtectionTests.testApplySurfacesSet
/// AttributesError — the same helper both the atom and the session path route
/// through — so this test focuses on the session-specific wiring.
final class BASSessionPersistProtectionTests: XCTestCase {
#if canImport(MLXLLM)

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("sp-\(UUID().uuidString).kv")
    }

    func testProtectSnapshotInvokesHelperAndFlipsClass() throws {
        // Pre-set the snapshot to .complete; _protectSnapshot must (a) INVOKE the
        // shared helper (the counter advances — `nil error` alone is a false-green,
        // nil even when the call is absent), (b) flip the class to
        // completeUntilFirstUserAuthentication, and (c) NOT fire the failure hook
        // on a clean apply. Reverting _persist to drop _protectSnapshot (swallow)
        // reds (a).
        let u = tempURL()
        defer { try? FileManager.default.removeItem(at: u) }
        try Data("kv".utf8).write(to: u)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete], ofItemAtPath: u.path)

        final class Box: @unchecked Sendable { var fired = false }
        let box = Box()
        let prevHook = MLXOrganAdapter._sessionProtectionFailureHook
        defer { MLXOrganAdapter._sessionProtectionFailureHook = prevHook }
        MLXOrganAdapter._sessionProtectionFailureHook = { _ in box.fired = true }

        let before = BASSQLiteFileProtection._applyInvocationCount
        MLXOrganAdapter._protectSnapshot(at: u)

        XCTAssertGreaterThan(BASSQLiteFileProtection._applyInvocationCount, before,
            "_protectSnapshot must INVOKE the shared protection helper")
        let cls = (try? FileManager.default.attributesOfItem(atPath: u.path))?[.protectionKey]
            as? FileProtectionType
        XCTAssertEqual(cls, .completeUntilFirstUserAuthentication,
            "the KV snapshot's protection class was flipped by the helper")
        XCTAssertFalse(box.fired,
            "a successful protect must NOT fire the failure hook")
    }
#endif
}
