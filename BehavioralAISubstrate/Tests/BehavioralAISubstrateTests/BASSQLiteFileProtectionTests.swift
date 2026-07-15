import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASMemory

/// audit x-sov #5/#6 — the memory-atom DB (highest-sensitivity on-disk point)
/// now gets file Data Protection like the session-KV snapshot does (缝2),
/// killing the same-repo double standard; the shared BASSQLiteFileProtection
/// helper surfaces its error (x-sov #6) instead of the old `try?`-swallow.
///
/// TEETH DESIGN NOTE (important). On macOS the `.protectionKey` attribute is
/// stored but at-rest encryption is INERT (macOS uses FileVault). Worse for
/// testing: a freshly-created macOS file ALREADY reads back
/// `completeUntilFirstUserAuthentication` by default — so a bare "reads back as
/// X" assertion is a FALSE-GREEN (it passes even with the fix reverted; an
/// adversarial reversal caught exactly this). macOS does, however, faithfully
/// STORE `.complete`. So these teeth pre-set the file to `.complete` and prove
/// the helper FLIPS it to `.completeUntilFirstUserAuthentication` — an
/// assertion that reds when `setAttributes` is skipped. The at-rest
/// pre-first-unlock unreadability itself is verified on an iOS device.
final class BASSQLiteFileProtectionTests: XCTestCase {

    // complete-class read-backs EPERM while the console is locked (macOS 27 enforces the
    // protection class on lock) — loud environmental skip, see BASScreenLockSkip
    override func setUpWithError() throws {
        try BASScreenLockSkip.skipIfScreenLocked()
    }

    // The console can LOCK MID-RUN (idle timeout during long suites) — protection flips
    // silently no-op in the lock transition window. Re-check before asserting so a mid-run
    // lock reads as the environmental skip it is, not a red (observed 2026-07-12 11:39).
    override func tearDownWithError() throws {
        try BASScreenLockSkip.skipIfScreenLocked()
    }

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("fp-\(UUID().uuidString).sqlite")
    }
    private func cleanup(_ u: URL) {
        for s in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: u.path + s))
        }
    }
    private func protectionOf(_ path: String) -> FileProtectionType? {
        (try? FileManager.default.attributesOfItem(atPath: path))?[.protectionKey]
            as? FileProtectionType
    }
    private func writeProtected(_ path: String, _ cls: FileProtectionType) throws {
        try Data("x".utf8).write(to: URL(fileURLWithPath: path))
        try FileManager.default.setAttributes([.protectionKey: cls], ofItemAtPath: path)
    }

    /// DISTINGUISHING: pre-set DB + -wal to `.complete`; the helper must flip
    /// BOTH to `.completeUntilFirstUserAuthentication`. Reverting the
    /// setAttributes call leaves them `.complete` ⇒ this reds.
    func testApplyFlipsProtectionClassOnDbAndSidecar() throws {
        let u = tempURL(); defer { cleanup(u) }
        try writeProtected(u.path, .complete)
        try writeProtected(u.path + "-wal", .complete)
        // sanity: the pre-set actually took (guards against the .none-floor trap)
        XCTAssertEqual(protectionOf(u.path), .complete)

        let err = BASSQLiteFileProtection.apply(toDatabaseAt: u.path)
        XCTAssertNil(err, "protection must apply without surfacing an error")
        XCTAssertEqual(protectionOf(u.path), .completeUntilFirstUserAuthentication,
            "the DB file's protection class was flipped by the helper")
        XCTAssertEqual(protectionOf(u.path + "-wal"), .completeUntilFirstUserAuthentication,
            "the -wal sidecar was flipped too")
    }

    /// DISTINGUISHING (id1 / x-sov #6 surfacing arm): force setAttributes to
    /// throw by making the DB file user-immutable (UF_IMMUTABLE), then `apply`
    /// MUST RETURN that error — not swallow it. Every other test asserts the
    /// nil happy-path, so reverting line 51 `return error` → `return nil` stays
    /// green everywhere EXCEPT here — this closes that false-green.
    func testApplySurfacesSetAttributesError() throws {
        let u = tempURL()
        defer {
            // Clear the immutable flag before cleanup can remove the file.
            try? FileManager.default.setAttributes(
                [.immutable: false], ofItemAtPath: u.path)
            cleanup(u)
        }
        try writeProtected(u.path, .complete)
        // Owner-settable user-immutable flag: subsequent setAttributes
        // (incl. .protectionKey) fails with EPERM.
        try FileManager.default.setAttributes(
            [.immutable: true], ofItemAtPath: u.path)

        let err = BASSQLiteFileProtection.apply(toDatabaseAt: u.path)
        XCTAssertNotNil(err,
            "apply must RETURN the setAttributes error — x-sov #6 surfaces "
            + "the failure to the caller's diagnostic channel, never swallows it")
    }

    /// DISTINGUISHING: a missing `-shm` sidecar must be SKIPPED (fileExists
    /// guard), not error — DB flips, absent sidecar is a clean no-op.
    func testApplySkipsMissingSidecarWithoutError() throws {
        let u = tempURL(); defer { cleanup(u) }
        try writeProtected(u.path, .complete) // DB only; no -wal / -shm
        XCTAssertNil(BASSQLiteFileProtection.apply(toDatabaseAt: u.path),
            "absent sidecars are skipped, not errored")
        XCTAssertEqual(protectionOf(u.path), .completeUntilFirstUserAuthentication)
    }

    /// DISTINGUISHING: kill-switch (BAS_FILE_PROTECTION=0) ⇒ the helper returns
    /// early WITHOUT touching the file, so a pre-set `.complete` survives
    /// unchanged. If the switch were ignored it would flip to `.cUFUA` ⇒ reds.
    func testKillSwitchLeavesFileUntouched() throws {
        setenv("BAS_FILE_PROTECTION", "0", 1)
        defer { unsetenv("BAS_FILE_PROTECTION") }
        XCTAssertFalse(BASSQLiteFileProtection.isEnabled)
        let u = tempURL(); defer { cleanup(u) }
        try writeProtected(u.path, .complete)
        XCTAssertNil(BASSQLiteFileProtection.apply(toDatabaseAt: u.path),
            "kill-switch ⇒ clean no-op")
        XCTAssertEqual(protectionOf(u.path), .complete,
            "kill-switch must NOT touch the file's existing protection class")
    }

    /// DISTINGUISHING call-site wiring: the store must actually INVOKE the helper
    /// at open. `fileProtectionError == nil` alone is a FALSE-GREEN (nil both when
    /// protection succeeds AND when the call was never made), so this asserts the
    /// helper's invocation counter advanced — that reds if the store stops calling
    /// it, unlike the nil-error check.
    func testAtomStoreInvokesProtectionHelperAtOpen() async throws {
        let u = tempURL(); defer { cleanup(u) }
        let seed = BASGovernedMemory(
            id: UUID(), kind: .episodic, content: "sensitive", scope: .session,
            sensitivity: .high, tier: .warm, confidence: 0.9, sourceType: "test",
            governanceStatus: .governed, provenanceSummary: "t")
        let before = BASSQLiteFileProtection._applyInvocationCount
        let store = try BASSQLiteMemoryAtomStore(databaseURL: u, initial: [seed])
        let err = await store.fileProtectionError
        XCTAssertNil(err, "the memory-atom DB protection wiring must run clean at open")
        XCTAssertGreaterThan(BASSQLiteFileProtection._applyInvocationCount, before,
            "opening the store must INVOKE the protection helper (not just leave "
            + "fileProtectionError nil, which is nil even when the call is absent)")
        _ = store
    }
}
