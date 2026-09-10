import XCTest
@testable import BASMemory
@testable import BASOrchestration

/// M61 — L5 宿纹层 main-chain wiring.
///
/// Before M61 the coordinator carried `hostConstitution` /
/// `hostVersionTree` / `hostForgetRequest` as static reference
/// state — threaded into the thought-fold and trace but never
/// surfaced as typed per-subject evidence on the main-chain
/// thought frame. These tests pin the M61 behavior:
///
///   1. `BASHostConstitutionObservationBundle.derive(
///        fromHostConstitution:versionTree:forgetRequest:
///        turnID:sessionID:emittedAt:)` emits a bundle whose
///      contents deterministically mirror the input governance
///      triple (same inputs → same bundle byte-for-byte).
///   2. Exactly one of `.anchorActive` / `.constitutionUnbootstrapped`
///      is always emitted (mutually exclusive, never both,
///      never neither).
///   3. `.versionCommitted` fires once per version in the tree;
///      `.candidatePending` fires once per pending candidate ID;
///      `.versionFrozen` fires once per frozen version ID; all in
///      tree order.
///   4. `.forgetInFlight` fires exactly when a forget request is
///      present (at most one per turn).
///   5. Shape classification follows the 5-phase precedence rule
///      (unbootstrapped > forgetting > frozen > governing > quiet).
///   6. `BASThoughtFrame.withDerivedHostConstitutionObservationBundle(
///      constitution:versionTree:forgetRequest:turnID:sessionID:
///      emittedAt:)` returns a copy with the bundle attached and
///      leaves every other field untouched.
///   7. Budget stays clamped in [0, 1] across realistic governance
///      loads.
final class BASHostConstitutionObservationDerivationTests:
    XCTestCase
{
    // MARK: - Fixtures

    private let fixedDate = Date(timeIntervalSince1970: 2_100_000)
    private let turnID = "turn-l5-1"
    private let sessionID = "session-l5-1"

    private func version(
        id: String,
        rollbackRef: String? = nil,
        approved: Bool = true
    ) -> BASHostVersion {
        BASHostVersion(
            versionID: id,
            changedFields: [],
            reason: "fixture",
            rollbackRef: rollbackRef,
            approvedByPolicy: approved)
    }

    private func constitution(
        active: String = "host.v1",
        hostID: String = "host-1",
        constitutionID: String = "constitution-1"
    ) -> BASHostConstitution {
        BASHostConstitution(
            constitutionID: constitutionID,
            hostID: hostID,
            activeVersion: active)
    }

    private func versionTree(
        active: String = "host.v1",
        versions: [BASHostVersion] = [],
        pending: [String] = [],
        frozen: [String] = []
    ) -> BASHostVersionTree {
        BASHostVersionTree(
            activeVersionID: active,
            versions: versions,
            pendingCandidateIDs: pending,
            frozenVersionIDs: frozen)
    }

    private func forgetRequest(
        id: String = "forget-1",
        targets: [String] = ["atom.a"],
        cascade: [String] = ["atom.b"],
        verified: Bool = false
    ) -> BASForgetRequest {
        BASForgetRequest(
            requestID: id,
            targetRefs: targets,
            cascadeScope: cascade,
            verified: verified)
    }

    private func derive(
        _ c: BASHostConstitution? = nil,
        _ tree: BASHostVersionTree? = nil,
        _ fr: BASForgetRequest? = nil
    ) -> BASHostConstitutionObservationBundle {
        BASHostConstitutionObservationBundle.derive(
            fromHostConstitution: c,
            versionTree: tree,
            forgetRequest: fr,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: fixedDate)
    }

    // MARK: - Path 1: unbootstrapped (nil constitution)

    func testNilConstitutionEmitsUnbootstrappedSignal() {
        let bundle = derive()
        XCTAssertEqual(bundle.turnID, turnID)
        XCTAssertEqual(bundle.sessionID, sessionID)
        XCTAssertEqual(bundle.emittedAt, fixedDate)
        XCTAssertEqual(bundle.observations.count, 1)
        XCTAssertTrue(bundle.isUnbootstrapped)
        XCTAssertFalse(bundle.hasAnyAnchor)
        XCTAssertFalse(bundle.hasCoreSignalCoverage)
        for obs in bundle.observations {
            XCTAssertEqual(obs.shape, .unbootstrapped)
        }
        let unboot = bundle.observations(
            of: .constitutionUnbootstrapped).first
        XCTAssertEqual(unboot?.subjectID, "host.unbootstrapped")
    }

    // MARK: - Path 2: empty activeVersion counts as unbootstrapped

    func testEmptyActiveVersionEmitsUnbootstrappedNotAnchor() {
        let bundle = derive(constitution(active: ""))
        XCTAssertEqual(bundle.observations.count, 1)
        XCTAssertTrue(bundle.isUnbootstrapped)
        XCTAssertFalse(bundle.hasAnyAnchor)
    }

    func testWhitespaceOnlyActiveVersionIsUnbootstrapped() {
        let bundle = derive(constitution(active: "   "))
        XCTAssertTrue(bundle.isUnbootstrapped)
        XCTAssertFalse(bundle.hasAnyAnchor)
    }

    // MARK: - Path 3: quiet (bootstrapped, no tree signals, no forget)

    func testQuietShapeWhenBootstrappedWithoutTree() {
        let bundle = derive(constitution())
        XCTAssertEqual(bundle.observations.count, 1)
        XCTAssertTrue(bundle.hasAnyAnchor)
        XCTAssertFalse(bundle.isUnbootstrapped)
        XCTAssertTrue(bundle.hasCoreSignalCoverage)
        for obs in bundle.observations {
            XCTAssertEqual(obs.shape, .quiet)
        }
        let anchor = bundle.observations(of: .anchorActive).first
        XCTAssertEqual(anchor?.subjectID, "host.v1")
    }

    func testAnchorAndUnbootstrappedAreMutuallyExclusive() {
        let bundleA = derive(constitution())
        XCTAssertTrue(bundleA.hasAnyAnchor)
        XCTAssertFalse(bundleA.isUnbootstrapped)

        let bundleB = derive()
        XCTAssertFalse(bundleB.hasAnyAnchor)
        XCTAssertTrue(bundleB.isUnbootstrapped)
    }

    // MARK: - Path 4: committed versions iterate

    func testCommittedVersionsEmitOnePerVersionInTreeOrder() {
        let tree = versionTree(versions: [
            version(id: "host.v1"),
            version(id: "host.v2", rollbackRef: "host.v1"),
            version(id: "host.v3", rollbackRef: "host.v2")
        ])
        let bundle = derive(constitution(), tree)
        let committed = bundle.observations(of: .versionCommitted)
        XCTAssertEqual(committed.count, 3)
        XCTAssertEqual(
            committed.map { $0.subjectID },
            ["host.v1", "host.v2", "host.v3"])
        XCTAssertTrue(committed[0].content.contains(
            ".rollbackRef:<root>"))
        XCTAssertTrue(committed[1].content.contains(
            ".rollbackRef:host.v1"))
    }

    // MARK: - Path 5: pending candidates → governing shape

    func testPendingCandidatesTriggerGoverningShape() {
        let tree = versionTree(
            versions: [version(id: "host.v1")],
            pending: ["cand-A", "cand-B"])
        let bundle = derive(constitution(), tree)
        XCTAssertTrue(bundle.hasAnyPending)
        for obs in bundle.observations {
            XCTAssertEqual(obs.shape, .governing)
        }
        let pending = bundle.observations(of: .candidatePending)
        XCTAssertEqual(
            pending.map { $0.subjectID }, ["cand-A", "cand-B"])
    }

    // MARK: - Path 6: frozen versions → frozen shape (beats governing)

    func testFrozenVersionsTriggerFrozenShape() {
        let tree = versionTree(
            versions: [version(id: "host.v1")],
            pending: ["cand-A"],
            frozen: ["host.v0-legacy"])
        let bundle = derive(constitution(), tree)
        XCTAssertTrue(bundle.hasAnyFrozen)
        for obs in bundle.observations {
            XCTAssertEqual(obs.shape, .frozen)
        }
        let frozen = bundle.observations(of: .versionFrozen)
        XCTAssertEqual(frozen.first?.subjectID, "host.v0-legacy")
    }

    // MARK: - Path 7: forget request → forgetting shape (highest)

    func testForgetRequestTriggersForgettingShape() {
        let tree = versionTree(
            versions: [version(id: "host.v1")],
            pending: ["cand-A"],
            frozen: ["host.v0-legacy"])
        let bundle = derive(constitution(), tree, forgetRequest())
        XCTAssertTrue(bundle.hasForgetInFlight)
        for obs in bundle.observations {
            XCTAssertEqual(obs.shape, .forgetting)
        }
        let forget = bundle.observations(of: .forgetInFlight).first
        XCTAssertEqual(forget?.subjectID, "forget-1")
    }

    // MARK: - Path 8: unbootstrapped beats forgetting precedence

    func testUnbootstrappedBeatsForgettingShape() {
        let bundle = derive(nil, nil, forgetRequest())
        // Unbootstrapped wins even when a forget request is in
        // flight — a host with no identity front can still have a
        // forget cascade queued (rare but legal).
        for obs in bundle.observations {
            XCTAssertEqual(obs.shape, .unbootstrapped)
        }
        XCTAssertTrue(bundle.isUnbootstrapped)
        XCTAssertTrue(bundle.hasForgetInFlight)
    }

    // MARK: - Path 9: determinism

    func testDeterministicBundleForIdenticalInputs() {
        let c = constitution()
        let tree = versionTree(
            versions: [version(id: "host.v1")],
            pending: ["cand-A"])
        let fr = forgetRequest()
        let first = derive(c, tree, fr)
        let second = derive(c, tree, fr)
        XCTAssertEqual(first, second)
    }

    // MARK: - Path 10: withDerived helper preserves rest of frame

    func testWithDerivedHelperAttachesAndPreservesFrame() {
        let frame = BASThoughtFrame(
            stepIndex: 9,
            decomposeRef: "dcm-l5",
            memoryRefs: ["m-a"],
            stabilityScore: 0.42)
        let c = constitution()
        let tree = versionTree(
            versions: [version(id: "host.v1")],
            pending: ["cand-A"])
        let withBundle = frame
            .withDerivedHostConstitutionObservationBundle(
                constitution: c,
                versionTree: tree,
                forgetRequest: nil,
                turnID: turnID,
                sessionID: sessionID,
                emittedAt: fixedDate)
        XCTAssertEqual(withBundle.stepIndex, 9)
        XCTAssertEqual(withBundle.decomposeRef, "dcm-l5")
        XCTAssertEqual(withBundle.memoryRefs, ["m-a"])
        XCTAssertEqual(withBundle.stabilityScore, 0.42)
        XCTAssertNotNil(withBundle.hostConstitutionObservationBundle)
        XCTAssertTrue(
            withBundle.hostConstitutionObservationBundle!
                .hasAnyAnchor)
        XCTAssertTrue(
            withBundle.hostConstitutionObservationBundle!
                .hasAnyPending)
    }

    func testWithDerivedHelperIsDeterministic() {
        let frame = BASThoughtFrame(
            stepIndex: 1,
            decomposeRef: "dcm-x")
        let c = constitution()
        let tree = versionTree()
        let first = frame
            .withDerivedHostConstitutionObservationBundle(
                constitution: c,
                versionTree: tree,
                forgetRequest: nil,
                turnID: turnID,
                sessionID: sessionID,
                emittedAt: fixedDate)
        let second = frame
            .withDerivedHostConstitutionObservationBundle(
                constitution: c,
                versionTree: tree,
                forgetRequest: nil,
                turnID: turnID,
                sessionID: sessionID,
                emittedAt: fixedDate)
        XCTAssertEqual(
            first.hostConstitutionObservationBundle,
            second.hostConstitutionObservationBundle)
    }

    // MARK: - Path 11: anchor content encodes hostID + constitutionID

    func testAnchorContentEncodesConstitutionFields() {
        let bundle = derive(constitution(
            active: "host.v2",
            hostID: "host-alpha",
            constitutionID: "constitution-xyz"))
        let anchor = bundle.observations(of: .anchorActive).first!
        XCTAssertTrue(anchor.content.contains(
            "l5.anchor.active:host.v2"))
        XCTAssertTrue(anchor.content.contains(
            ".hostID:host-alpha"))
        XCTAssertTrue(anchor.content.contains(
            ".constitutionID:constitution-xyz"))
        XCTAssertEqual(anchor.subjectID, "host.v2")
    }

    // MARK: - Path 12: forget content encodes scope counts

    func testForgetContentEncodesScopeAndVerified() {
        let fr = forgetRequest(
            id: "forget-42",
            targets: ["a", "b", "c"],
            cascade: ["x", "y"],
            verified: true)
        let bundle = derive(constitution(), versionTree(), fr)
        let forget = bundle.observations(of: .forgetInFlight).first!
        XCTAssertTrue(forget.content.contains(
            "l5.forget.request:forget-42"))
        XCTAssertTrue(forget.content.contains(".targetRefs:3"))
        XCTAssertTrue(forget.content.contains(".cascadeScope:2"))
        XCTAssertTrue(forget.content.contains(".verified:true"))
    }

    // MARK: - Path 13: budget cost clamps and totals correctly

    func testBudgetCostTotalSumsSignalsDeterministically() {
        // anchor (0.05) + 1 committed (0.02) + 1 pending (0.10)
        //   + 1 frozen (0.08) + forget (0.25) = 0.50
        let tree = versionTree(
            versions: [version(id: "host.v1")],
            pending: ["cand-A"],
            frozen: ["host.v0"])
        let bundle = derive(
            constitution(), tree, forgetRequest())
        let total = BASHostConstitutionSignalBudget.totalCost(
            for: bundle)
        XCTAssertEqual(total, 0.50, accuracy: 0.0001)
        XCTAssertLessThanOrEqual(total, 1.0)
        XCTAssertGreaterThanOrEqual(total, 0.0)
    }

    func testBudgetClampsUnderHighVolumeTree() {
        // Many committed versions to push budget high — should clamp
        // at 1.0 even as the raw sum exceeds it.
        let versions = (0..<60).map {
            version(id: "host.v\($0)")
        }
        let tree = versionTree(
            active: "host.v0",
            versions: versions)
        let bundle = derive(
            constitution(active: "host.v0"), tree)
        let total = BASHostConstitutionSignalBudget.totalCost(
            for: bundle)
        XCTAssertLessThanOrEqual(total, 1.0)
    }

    // MARK: - Path 14: Codable round trip

    func testBundleCodableRoundTripPreservesSignals() throws {
        let tree = versionTree(
            versions: [version(id: "host.v1")],
            pending: ["cand-A"],
            frozen: ["host.v0"])
        let bundle = derive(
            constitution(), tree, forgetRequest())
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(bundle)
        let decoder = JSONDecoder()
        let roundTrip = try decoder.decode(
            BASHostConstitutionObservationBundle.self, from: data)
        XCTAssertEqual(roundTrip, bundle)
    }

    func testThoughtFrameCodableRoundTripIncludesHostBundle()
    throws {
        var frame = BASThoughtFrame(
            stepIndex: 2,
            decomposeRef: "dcm-y",
            stabilityScore: 0.5)
        frame = frame
            .withDerivedHostConstitutionObservationBundle(
                constitution: constitution(),
                versionTree: versionTree(
                    versions: [version(id: "host.v1")]),
                forgetRequest: nil,
                turnID: "t",
                sessionID: "s",
                emittedAt: fixedDate)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(frame)
        let decoder = JSONDecoder()
        let roundTrip = try decoder.decode(
            BASThoughtFrame.self, from: data)
        XCTAssertEqual(
            roundTrip.hostConstitutionObservationBundle,
            frame.hostConstitutionObservationBundle)
    }

    // MARK: - Path 15: ledger append + bounded ring

    func testLedgerRecordsBundleAndSnapshots() async {
        let ledger = BASHostConstitutionObservationLedger(
            capacity: 2)
        let a = derive(constitution(active: "host.v1"))
        let b = derive(constitution(active: "host.v2"))
        let c = derive(constitution(active: "host.v3"))
        await ledger.record(a)
        await ledger.record(b)
        await ledger.record(c)
        let snap = await ledger.snapshot()
        XCTAssertEqual(snap.count, 2)
        XCTAssertEqual(snap.first, b)
        XCTAssertEqual(snap.last, c)
    }

    func testLedgerFiltersBySessionAndTurn() async {
        let ledger = BASHostConstitutionObservationLedger()
        let a = BASHostConstitutionObservationBundle.derive(
            fromHostConstitution: constitution(),
            versionTree: nil,
            forgetRequest: nil,
            turnID: "tA",
            sessionID: "sA",
            emittedAt: fixedDate)
        let b = BASHostConstitutionObservationBundle.derive(
            fromHostConstitution: constitution(),
            versionTree: nil,
            forgetRequest: nil,
            turnID: "tB",
            sessionID: "sB",
            emittedAt: fixedDate)
        await ledger.record(a)
        await ledger.record(b)
        let bySession = await ledger.bundles(forSession: "sA")
        XCTAssertEqual(bySession.count, 1)
        XCTAssertEqual(bySession.first?.turnID, "tA")
        let byTurn = await ledger.bundle(forTurn: "tB")
        XCTAssertEqual(byTurn?.sessionID, "sB")
    }

    // MARK: - Path 16: filter helpers

    func testObservationsForShapeFiltersBundle() {
        let tree = versionTree(
            versions: [version(id: "host.v1")],
            pending: ["cand-A"])
        let bundle = derive(constitution(), tree)
        let governing = bundle.observations(forShape: .governing)
        XCTAssertEqual(governing.count, bundle.observations.count)
    }

    func testObservationsForSubjectGroupsBundle() {
        // Same subject ID (active version) can hit multiple kinds —
        // in this case just anchor + (no committed because tree is
        // nil) — so we construct a tree where host.v1 is both
        // active and committed.
        let tree = versionTree(
            versions: [version(id: "host.v1")])
        let bundle = derive(constitution(), tree)
        let byV1 = bundle.observations(forSubject: "host.v1")
        XCTAssertEqual(byV1.count, 2)
        let kinds = Set(byV1.map { $0.kind })
        XCTAssertEqual(
            kinds,
            Set([.anchorActive, .versionCommitted]))
    }

    func testObservationsOfKindFiltersBundle() {
        let tree = versionTree(
            versions: [
                version(id: "host.v1"),
                version(id: "host.v2")
            ],
            pending: ["cand-A"],
            frozen: ["host.v0"])
        let bundle = derive(constitution(), tree)
        XCTAssertEqual(
            bundle.observations(of: .anchorActive).count, 1)
        XCTAssertEqual(
            bundle.observations(of: .versionCommitted).count, 2)
        XCTAssertEqual(
            bundle.observations(of: .candidatePending).count, 1)
        XCTAssertEqual(
            bundle.observations(of: .versionFrozen).count, 1)
    }

    // MARK: - Path 17: subjectIDs preserve first-seen order

    func testSubjectIDsPreserveEmissionOrderAndDedup() {
        let tree = versionTree(
            versions: [version(id: "host.v1")],
            pending: ["cand-A"],
            frozen: ["host.v1"])  // duplicate with committed
        let bundle = derive(constitution(), tree)
        let subjects = bundle.subjectIDs
        XCTAssertEqual(subjects.first, "host.v1")  // anchor first
        XCTAssertTrue(subjects.contains("cand-A"))
        // host.v1 is both anchor + committed + frozen but appears
        // once in the dedup'd list.
        XCTAssertEqual(
            subjects.filter { $0 == "host.v1" }.count, 1)
    }
}
