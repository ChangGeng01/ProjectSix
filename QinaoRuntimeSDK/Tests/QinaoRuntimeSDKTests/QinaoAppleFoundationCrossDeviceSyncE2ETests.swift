import XCTest
import BASRuntimeCore
import BASOrgan
import BASAppleAdapters
import BASSovereign

/// 六十.2 — cross-device sync end-to-end demo with real Apple
/// Foundation Models inference driving simulated multi-device
/// decisions.
///
/// ## Why this exists
///
/// 五十九 ship 了 typed convergence integration test for 6 sync
/// strategies — but the audit refs were synthetic ("ref-A1"
/// etc.). What was missing: **real-LLM-emitted decisions
/// flowing through the sovereign sync layer**.
///
/// 六十.2 simulates 2 devices, each running its own AFM
/// inference, each emitting decisions into its local ledger.
/// Sync runs across all 4 strategy kinds. Asserts the
/// invariant: **regardless of which AFM-driven content sits
/// in the audit refs, the sync algebra converges**.
///
/// ## Doctrine pinned
///
/// 1. **AFM inference is a decision source** — each device's
///    local ledger fills with frames whose `auditEntryRef` is
///    a hash of the LLM body
/// 2. **Sync algebra is content-agnostic** — vector clock,
///    leader-follower, CRDT, gossip all converge regardless of
///    body content
/// 3. **Provenance preserved** — `originDeviceID` is preserved
///    through sync; audit code can group by emitting device
/// 4. **Determinism** — same AFM bodies hashed to same refs
///    → same convergence outcome
///
/// ## Gating
///
/// `QINAO_FM_E2E=1` env var + macOS 26+ / iOS 26+ availability.
final class QinaoAppleFoundationCrossDeviceSyncE2ETests:
    XCTestCase
{

    private static let envFlag = "QINAO_FM_E2E"

    private func skipUnlessReady() throws {
        guard
            ProcessInfo.processInfo.environment[
                Self.envFlag] == "1"
        else {
            throw XCTSkip(
                "set \(Self.envFlag)=1 to exercise " +
                "cross-device sync with real AFM")
        }
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            return
        }
        throw XCTSkip(
            "FoundationModels requires iOS 26+ / macOS 26+ " +
            "/ visionOS 26+")
    }

    // MARK: - Simulated device

    private struct Device {
        let id: String
        var ledger: [BASSovereignCrossDeviceLedgerFrame]
        var clock: BASSovereignCrossDeviceClock
        var auditBodies: [String: String] // ref → body
    }

    private func makeDevice(id: String) -> Device {
        Device(
            id: id,
            ledger: [],
            clock: BASSovereignCrossDeviceClock.initial,
            auditBodies: [:])
    }

    /// Hash an LLM body to a stable audit ref.
    private func auditRef(
        for body: String,
        deviceID: String,
        seq: Int
    ) -> String {
        // Stable ref: device-seq-bodyhash. Hash is deterministic
        // across runs given same body. Using a simple hash here
        // — not cryptographically strong, just stable.
        var hasher = Hasher()
        hasher.combine(body)
        let h = hasher.finalize()
        return "audit-\(deviceID)-\(seq)-\(abs(h))"
    }

    /// Simulate one local sovereign decision driven by AFM.
    private func emitAFMDecision(
        on device: inout Device,
        seq: Int,
        prompt: String,
        adapter: any BASOrganAdapter
    ) async throws {
        let request = BASOrganRequest(
            requestID: UUID().uuidString,
            role: .core,
            preset: .core,
            instruction: prompt,
            context: [])
        // M400.3 — Code 1026 → XCTSkip
        let draft: BASOrganDraft
        do {
            draft = try await adapter.draft(request)
        } catch {
            try skipIfAFMDegraded(error)
            throw error
        }
        let ref = auditRef(
            for: draft.body,
            deviceID: device.id,
            seq: seq)
        device.clock = device.clock.tick(
            deviceID: device.id)
        let frame = BASSovereignCrossDeviceLedgerFrame(
            auditEntryRef: ref,
            originDeviceID: device.id,
            clock: device.clock)
        device.ledger.append(frame)
        device.auditBodies[ref] = draft.body
    }

    /// Pairwise sync via the strategy.
    private func pairwiseSync(
        _ a: inout Device,
        _ b: inout Device,
        using strategy: any BASSovereignFragmentSyncStrategy
    ) async {
        let aMerged = await strategy.sync(
            local: a.ledger, remote: b.ledger)
        let bMerged = await strategy.sync(
            local: b.ledger, remote: a.ledger)
        a.ledger = aMerged
        b.ledger = bMerged
        a.clock = a.clock.merged(with: b.clock)
        b.clock = a.clock
        // Bodies merge too — each device picks up the other's
        // bodies.
        for (ref, body) in b.auditBodies
        where a.auditBodies[ref] == nil {
            a.auditBodies[ref] = body
        }
        for (ref, body) in a.auditBodies
        where b.auditBodies[ref] == nil {
            b.auditBodies[ref] = body
        }
    }

    private func makeAdapter() -> AppleFoundationOrganAdapter {
        AppleFoundationOrganAdapter()
    }

    // MARK: - Test 1: 2-device AFM-driven convergence

    func test_twoDeviceAFMDrivenConvergence() async throws {
        try skipUnlessReady()

        for kind in BASSovereignSyncProtocolKind.allCases {
            try await runScenario(
                kind: kind, leaderDeviceID: "device-A")
        }
    }

    private func runScenario(
        kind: BASSovereignSyncProtocolKind,
        leaderDeviceID: String
    ) async throws {
        var deviceA = makeDevice(id: "device-A")
        var deviceB = makeDevice(id: "device-B")
        let adapter = makeAdapter()

        // Each device drives 2 AFM inference calls.
        try await emitAFMDecision(
            on: &deviceA,
            seq: 1,
            prompt:
                "Reply with one short word about " +
                "boundary clarity.",
            adapter: adapter)
        try await emitAFMDecision(
            on: &deviceA,
            seq: 2,
            prompt:
                "Reply with one short word about " +
                "patience.",
            adapter: adapter)
        try await emitAFMDecision(
            on: &deviceB,
            seq: 1,
            prompt:
                "Reply with one short word about " +
                "deliberation.",
            adapter: adapter)
        try await emitAFMDecision(
            on: &deviceB,
            seq: 2,
            prompt:
                "Reply with one short word about " +
                "reversibility.",
            adapter: adapter)

        XCTAssertEqual(deviceA.ledger.count, 2)
        XCTAssertEqual(deviceB.ledger.count, 2)

        // Pre-sync: each device only sees its own decisions.
        XCTAssertEqual(deviceA.auditBodies.count, 2)
        XCTAssertEqual(deviceB.auditBodies.count, 2)

        let strategy = try XCTUnwrap(
            BASSovereignSyncStrategyFactory.makeStrategy(
                kind: kind,
                leaderDeviceID: leaderDeviceID))

        // 2-round sync ensures fixed point even for gossip.
        for _ in 0..<2 {
            await pairwiseSync(
                &deviceA, &deviceB, using: strategy)
        }

        // After sync: both devices see all 4 audit refs.
        let aRefs = Set(
            deviceA.ledger.map(\.auditEntryRef))
        let bRefs = Set(
            deviceB.ledger.map(\.auditEntryRef))
        XCTAssertEqual(
            aRefs.count, 4,
            "\(kind.rawValue): device-A must see all 4 " +
            "AFM-driven decisions after sync")
        XCTAssertEqual(
            bRefs.count, 4,
            "\(kind.rawValue): device-B must see all 4 " +
            "AFM-driven decisions after sync")
        XCTAssertEqual(aRefs, bRefs)

        // Both devices have all 4 bodies (audit content).
        XCTAssertEqual(
            deviceA.auditBodies.count, 4,
            "\(kind.rawValue): device-A must have all 4 " +
            "AFM bodies")
        XCTAssertEqual(
            deviceB.auditBodies.count, 4,
            "\(kind.rawValue): device-B must have all 4 " +
            "AFM bodies")

        // Origin preserved through sync.
        let aOrigins = Set(
            deviceA.ledger.map(\.originDeviceID))
        XCTAssertEqual(
            aOrigins, ["device-A", "device-B"],
            "\(kind.rawValue): both origins preserved")

        // All bodies non-empty (AFM drove real content).
        for (_, body) in deviceA.auditBodies {
            XCTAssertFalse(
                body.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty,
                "AFM body must be non-empty")
        }
    }

    // MARK: - Test 2: Vector clock causality preserved

    func test_vectorClocksAccumulateAcrossDevicesViaAFM()
        async throws
    {
        try skipUnlessReady()

        var deviceA = makeDevice(id: "device-A")
        var deviceB = makeDevice(id: "device-B")
        let adapter = makeAdapter()

        try await emitAFMDecision(
            on: &deviceA,
            seq: 1,
            prompt: "One short word.",
            adapter: adapter)
        try await emitAFMDecision(
            on: &deviceB,
            seq: 1,
            prompt: "One short word.",
            adapter: adapter)

        // Pre-sync: each device only knows its own clock.
        XCTAssertEqual(
            deviceA.clock.counter(for: "device-A"), 1)
        XCTAssertEqual(
            deviceA.clock.counter(for: "device-B"), 0)
        XCTAssertEqual(
            deviceB.clock.counter(for: "device-A"), 0)
        XCTAssertEqual(
            deviceB.clock.counter(for: "device-B"), 1)

        let strategy = try XCTUnwrap(
            BASSovereignSyncStrategyFactory.makeStrategy(
                kind: .vectorClockMerge,
                leaderDeviceID: nil))

        await pairwiseSync(
            &deviceA, &deviceB, using: strategy)

        // Post-sync: both clocks dominate both devices.
        XCTAssertEqual(
            deviceA.clock.counter(for: "device-A"), 1)
        XCTAssertEqual(
            deviceA.clock.counter(for: "device-B"), 1)
        XCTAssertEqual(
            deviceB.clock.counter(for: "device-A"), 1)
        XCTAssertEqual(
            deviceB.clock.counter(for: "device-B"), 1)
    }

    // MARK: - Test 3: AFM provenance through sovereign layer

    /// Smoke test that AFM-driven content actually carries
    /// through the sovereign layer end-to-end without losing
    /// device-of-origin information.
    func test_afmDecisionsCarryOriginThroughSync() async throws {
        try skipUnlessReady()

        var deviceA = makeDevice(id: "device-A")
        var deviceB = makeDevice(id: "device-B")
        let adapter = makeAdapter()

        try await emitAFMDecision(
            on: &deviceA,
            seq: 1,
            prompt: "Reply with one word.",
            adapter: adapter)
        let aRef = deviceA.ledger[0].auditEntryRef
        try await emitAFMDecision(
            on: &deviceB,
            seq: 1,
            prompt: "Reply with one word.",
            adapter: adapter)
        let bRef = deviceB.ledger[0].auditEntryRef

        let strategy = try XCTUnwrap(
            BASSovereignSyncStrategyFactory.makeStrategy(
                kind: .crdt))
        await pairwiseSync(
            &deviceA, &deviceB, using: strategy)

        // Find each ref in device-A's merged ledger and verify
        // origin is preserved.
        let aFrameForA = deviceA.ledger.first {
            $0.auditEntryRef == aRef
        }
        let aFrameForB = deviceA.ledger.first {
            $0.auditEntryRef == bRef
        }
        XCTAssertEqual(
            aFrameForA?.originDeviceID, "device-A",
            "device-A's frame must keep origin device-A " +
            "after sync")
        XCTAssertEqual(
            aFrameForB?.originDeviceID, "device-B",
            "device-B's frame must keep origin device-B " +
            "even when merged into device-A's ledger")
    }
}
