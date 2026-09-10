import XCTest
@testable import BASRuntimeCore
@testable import BASSovereign

/// Tests for `BR-04` SnapshotManager.
///
/// The manager is what makes the third signature of the three-signature
/// gate (SnapshotContinuityProof) verifiable. A bug here means either
/// (a) tampered payloads silently pass verification, or (b) legitimate
/// restores falsely fail. Each test pins one edge of that contract.
final class BASSovereignSnapshotManagerTests: XCTestCase {
    private typealias Anchor = BASSovereignSnapshotManager.SnapshotAnchor

    private func payload(_ body: String) -> Data {
        Data(body.utf8)
    }

    private func anchor(
        id: String = "anchor-1",
        payload: Data,
        foldRefs: [String] = [],
        hostVersionRef: String? = nil
    ) -> Anchor {
        Anchor(
            anchorID: id,
            safeSnapshotRef: "snap-\(id)",
            foldRefs: foldRefs,
            hostVersionRef: hostVersionRef,
            integrityHash: BASSovereignSnapshotManager.hash(payload)
        )
    }

    // MARK: - Registration

    func testRegisterAcceptsMatchingHash() async throws {
        let mgr = BASSovereignSnapshotManager()
        let data = payload("weights-v1")
        let entry = try await mgr.register(anchor: anchor(payload: data), sealedPayload: data)

        XCTAssertEqual(entry.payloadHash, BASSovereignSnapshotManager.hash(data))
        let count = await mgr.registeredCount()
        XCTAssertEqual(count, 1)
    }

    func testRegisterRejectsMismatchedDeclaredHash() async {
        let mgr = BASSovereignSnapshotManager()
        let sealed = payload("v1")
        let liar = Anchor(
            anchorID: "liar",
            safeSnapshotRef: "s",
            integrityHash: BASSovereignSnapshotManager.hash(payload("v2")) // wrong
        )

        do {
            _ = try await mgr.register(anchor: liar, sealedPayload: sealed)
            XCTFail("expected hashBindingMismatch")
        } catch let error as BASSovereignSnapshotManager.ManagerError {
            if case .hashBindingMismatch(let id, _, _) = error {
                XCTAssertEqual(id, "liar")
            } else {
                XCTFail("unexpected error case: \(error)")
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        let count = await mgr.registeredCount()
        XCTAssertEqual(count, 0, "rejected anchor must not be stored")
    }

    func testRegisterRejectsDuplicateWithoutReplace() async throws {
        let mgr = BASSovereignSnapshotManager()
        let data = payload("p")
        _ = try await mgr.register(anchor: anchor(payload: data), sealedPayload: data)

        do {
            _ = try await mgr.register(anchor: anchor(payload: data), sealedPayload: data)
            XCTFail("expected anchorAlreadyRegistered")
        } catch let error as BASSovereignSnapshotManager.ManagerError {
            if case .anchorAlreadyRegistered = error { /* ok */ } else {
                XCTFail("wrong case: \(error)")
            }
        }
    }

    func testRegisterReplaceAllowsOverwrite() async throws {
        let mgr = BASSovereignSnapshotManager()
        let d1 = payload("v1"), d2 = payload("v2")
        _ = try await mgr.register(anchor: anchor(payload: d1), sealedPayload: d1)
        _ = try await mgr.register(
            anchor: anchor(payload: d2),
            sealedPayload: d2,
            replaceExisting: true
        )
        let entry = await mgr.registeredSnapshot(anchorID: "anchor-1")
        XCTAssertEqual(entry?.payloadHash, BASSovereignSnapshotManager.hash(d2))
    }

    // MARK: - Verify restore

    func testVerifyRestoreAcceptsIdenticalPayload() async throws {
        let mgr = BASSovereignSnapshotManager()
        let data = payload("state")
        _ = try await mgr.register(anchor: anchor(payload: data), sealedPayload: data)

        try await mgr.verifyRestore(anchorID: "anchor-1", presentedPayload: data)
    }

    func testVerifyRestoreRejectsTamperedPayload() async throws {
        let mgr = BASSovereignSnapshotManager()
        let original = payload("state")
        _ = try await mgr.register(anchor: anchor(payload: original), sealedPayload: original)

        do {
            try await mgr.verifyRestore(anchorID: "anchor-1", presentedPayload: payload("TAMPER"))
            XCTFail("expected payloadHashMismatch")
        } catch let error as BASSovereignSnapshotManager.ManagerError {
            if case .payloadHashMismatch(let id, _, _) = error {
                XCTAssertEqual(id, "anchor-1")
            } else {
                XCTFail("wrong case: \(error)")
            }
        }
    }

    func testVerifyRestoreRejectsUnknownAnchor() async {
        let mgr = BASSovereignSnapshotManager()
        do {
            try await mgr.verifyRestore(anchorID: "ghost", presentedPayload: payload("x"))
            XCTFail("expected unknownAnchor")
        } catch let error as BASSovereignSnapshotManager.ManagerError {
            if case .unknownAnchor(let id) = error {
                XCTAssertEqual(id, "ghost")
            } else {
                XCTFail("wrong case: \(error)")
            }
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    // MARK: - Fold / host ref binding

    func testVerifyFoldRefAcceptsBoundRef() async throws {
        let mgr = BASSovereignSnapshotManager()
        let data = payload("p")
        _ = try await mgr.register(
            anchor: anchor(payload: data, foldRefs: ["fold-1", "fold-2"]),
            sealedPayload: data
        )
        try await mgr.verifyFoldRef("fold-2", in: "anchor-1")
    }

    func testVerifyFoldRefRejectsUnboundRef() async throws {
        let mgr = BASSovereignSnapshotManager()
        let data = payload("p")
        _ = try await mgr.register(
            anchor: anchor(payload: data, foldRefs: ["fold-1"]),
            sealedPayload: data
        )
        do {
            try await mgr.verifyFoldRef("fold-ghost", in: "anchor-1")
            XCTFail("expected referenceNotBound")
        } catch let error as BASSovereignSnapshotManager.ManagerError {
            if case .referenceNotBound = error { /* ok */ } else {
                XCTFail("wrong case: \(error)")
            }
        }
    }

    func testVerifyHostVersionRefBindingExact() async throws {
        let mgr = BASSovereignSnapshotManager()
        let data = payload("p")
        _ = try await mgr.register(
            anchor: anchor(payload: data, hostVersionRef: "hv-42"),
            sealedPayload: data
        )
        try await mgr.verifyHostVersion("hv-42", in: "anchor-1")

        do {
            try await mgr.verifyHostVersion("hv-99", in: "anchor-1")
            XCTFail("mismatched hostVersionRef must fail")
        } catch let error as BASSovereignSnapshotManager.ManagerError {
            if case .referenceNotBound = error { /* ok */ } else {
                XCTFail("wrong case: \(error)")
            }
        }
    }

    // MARK: - BR-004 observation helper

    func testMarkBrokenOnMismatchFlipsBR004() async throws {
        let mgr = BASSovereignSnapshotManager()
        let original = payload("state")
        _ = try await mgr.register(anchor: anchor(payload: original), sealedPayload: original)

        var obs = BASSovereignVerdictEngine.HardObservations.clean
        let flipped = await mgr.markBrokenIfNeeded(
            anchorID: "anchor-1",
            presentedPayload: payload("TAMPER"),
            in: &obs
        )
        XCTAssertTrue(flipped)
        XCTAssertTrue(obs.memoryOrHostWriteBypass,
                      "tampered restore must set BR-004")
    }

    func testMarkBrokenOnCleanRestoreLeavesObservationsClean() async throws {
        let mgr = BASSovereignSnapshotManager()
        let original = payload("state")
        _ = try await mgr.register(anchor: anchor(payload: original), sealedPayload: original)

        var obs = BASSovereignVerdictEngine.HardObservations.clean
        let flipped = await mgr.markBrokenIfNeeded(
            anchorID: "anchor-1",
            presentedPayload: original,
            in: &obs
        )
        XCTAssertFalse(flipped)
        XCTAssertEqual(obs, .clean)
    }

    func testMarkBrokenOnUnknownAnchorFlipsBR004() async {
        let mgr = BASSovereignSnapshotManager()
        var obs = BASSovereignVerdictEngine.HardObservations.clean
        let flipped = await mgr.markBrokenIfNeeded(
            anchorID: "ghost",
            presentedPayload: payload("x"),
            in: &obs
        )
        XCTAssertTrue(flipped, "unknown anchor must fail closed and raise BR-004")
        XCTAssertTrue(obs.memoryOrHostWriteBypass)
    }

    // MARK: - Lifecycle

    func testUnregisterRemovesAnchor() async throws {
        let mgr = BASSovereignSnapshotManager()
        let data = payload("p")
        _ = try await mgr.register(anchor: anchor(payload: data), sealedPayload: data)

        await mgr.unregister(anchorID: "anchor-1")
        let isReg = await mgr.isRegistered(anchorID: "anchor-1")
        XCTAssertFalse(isReg)
    }
}
