import XCTest
import BASRuntimeCore
import BASLeaseLife
@testable import QinaoRuntime

/// M16 — `QinaoBGMaintenanceBridge` → `BGTaskScheduler` plumbing.
///
/// These tests exercise the bridge's contract using an injected
/// submitter/canceller pair so they run deterministically on any
/// platform (including CI) without needing
/// `BGTaskSchedulerPermittedIdentifiers` in the test host's
/// Info.plist. The `system()` factory's connection to the real
/// `BGTaskScheduler.shared` is covered by build-time compilation
/// under `#if canImport(BackgroundTasks)` — running it here would
/// throw `BGTaskSchedulerErrorCode.unrecognized` for unregistered
/// identifiers, which is exactly what production hosts must avoid.
final class QinaoBGMaintenanceBridgeTests: XCTestCase {

    /// Thread-safe recorder actor for submitted / cancelled calls.
    actor Recorder {
        var submitted: [(identifier: String, date: Date)] = []
        var cancelled: [String] = []
        var submitResult: Bool = true

        func record(identifier: String, date: Date) -> Bool {
            submitted.append((identifier: identifier, date: date))
            return submitResult
        }
        func record(cancel identifier: String) {
            cancelled.append(identifier)
        }
        func setSubmitResult(_ v: Bool) { submitResult = v }
    }

    private func makeBridge(
        prefix: String = "qinao.breath",
        recorder: Recorder
    ) -> QinaoBGMaintenanceBridge {
        QinaoBGMaintenanceBridge(
            taskIdentifierPrefix: prefix,
            submitter: { id, date in
                await recorder.record(identifier: id, date: date)
            },
            canceller: { id in
                await recorder.record(cancel: id)
            })
    }

    private func request(
        id: String = "breath-1",
        at: Date = Date(timeIntervalSince1970: 1_700_000_000),
        `class`: BASMaintenanceClass = .light
    ) -> BASBreathScheduler.Request {
        BASBreathScheduler.Request(
            id: id,
            maintenanceClass: `class`,
            earliestFireAt: at,
            reasonCodes: ["test"])
    }

    // MARK: - Identifier formatting

    func testIdentifierFormatIsPrefixDotID() {
        XCTAssertEqual(
            QinaoBGMaintenanceBridge.identifier(
                prefix: "qinao.breath", id: "b-1"),
            "qinao.breath.b-1")
    }

    // MARK: - Register forwards identifier + earliestFireAt

    func testRegisterSubmitsWithNamespacedIdentifierAndDate() async {
        let recorder = Recorder()
        let bridge = makeBridge(recorder: recorder)
        let when = Date(timeIntervalSince1970: 1_700_000_042)
        let req = request(id: "abc", at: when)

        let ok = await bridge.register(req)

        XCTAssertTrue(ok)
        let s = await recorder.submitted
        XCTAssertEqual(s.count, 1)
        XCTAssertEqual(s.first?.identifier, "qinao.breath.abc")
        XCTAssertEqual(s.first?.date, when)
    }

    // MARK: - Register propagates submitter failure

    func testRegisterReturnsFalseWhenSubmitterRejects() async {
        let recorder = Recorder()
        await recorder.setSubmitResult(false)
        let bridge = makeBridge(recorder: recorder)

        let ok = await bridge.register(request())

        XCTAssertFalse(ok)
        let s = await recorder.submitted
        XCTAssertEqual(s.count, 1, "call still observed")
    }

    // MARK: - Cancel uses the same identifier formatter

    func testCancelForwardsNamespacedIdentifier() async {
        let recorder = Recorder()
        let bridge = makeBridge(recorder: recorder)
        await bridge.cancel(id: "xyz")
        let c = await recorder.cancelled
        XCTAssertEqual(c, ["qinao.breath.xyz"])
    }

    // MARK: - Custom prefix is honoured

    func testCustomPrefixIsUsedForBothRegisterAndCancel() async {
        let recorder = Recorder()
        let bridge = makeBridge(prefix: "app.ble", recorder: recorder)
        _ = await bridge.register(request(id: "one"))
        await bridge.cancel(id: "one")
        let s = await recorder.submitted
        let c = await recorder.cancelled
        XCTAssertEqual(s.first?.identifier, "app.ble.one")
        XCTAssertEqual(c, ["app.ble.one"])
    }

    // MARK: - End-to-end with the real scheduler actor

    func testSchedulerAcceptsAtNominalAndHitsBridgeOnce() async throws {
        let recorder = Recorder()
        let bridge = makeBridge(recorder: recorder)
        let scheduler = BASBreathScheduler(bridge: bridge)
        let req = request(id: "breath.sched-1")

        _ = try await scheduler.schedule(req, guardLevel: .nominal)

        let s = await recorder.submitted
        XCTAssertEqual(s.count, 1)
        XCTAssertEqual(s.first?.identifier, "qinao.breath.breath.sched-1")
        let count = await scheduler.count()
        XCTAssertEqual(count, 1)
    }

    func testSchedulerCancelInvokesBridgeCancel() async throws {
        let recorder = Recorder()
        let bridge = makeBridge(recorder: recorder)
        let scheduler = BASBreathScheduler(bridge: bridge)
        let req = request(id: "breath.sched-2")
        _ = try await scheduler.schedule(req, guardLevel: .nominal)
        try await scheduler.cancel(id: req.id)

        let c = await recorder.cancelled
        XCTAssertEqual(c, ["qinao.breath.breath.sched-2"])
    }

    // MARK: - System factory is constructible on every target

    func testSystemFactoryConstructs() {
        // Pure smoke test — the factory returns a bridge on every
        // supported platform. The actual submit/cancel behaviour
        // against BGTaskScheduler.shared requires entitlements
        // the test host lacks, so we don't invoke it here.
        let bridge = QinaoBGMaintenanceBridge.system(
            taskIdentifierPrefix: "qinao.breath")
        XCTAssertEqual(bridge.taskIdentifierPrefix, "qinao.breath")
    }
}
