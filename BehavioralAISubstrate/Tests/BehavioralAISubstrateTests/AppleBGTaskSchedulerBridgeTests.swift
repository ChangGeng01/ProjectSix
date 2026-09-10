import XCTest
@testable import BASAppleAdapters
@testable import BASLeaseLife
@testable import BASRuntimeCore

/// M16 / L1 — coverage for `AppleBGTaskSchedulerBridge`.
///
/// `BGTaskScheduler.shared` is `API_UNAVAILABLE(macos)`. On
/// native macOS (where these tests run) the bridge's
/// platform-call code path is compiled out — `register` returns
/// `false` (no OS scheduling occurred) and `cancel` is a no-op.
/// These tests verify the cross-platform-safe surface:
///
/// - protocol conformance compiles
/// - bridge handles `.none` maintenance class as a no-op success
/// - bridge integrates with `BASBreathScheduler` (records the
///   request locally even when the OS layer rejects)
/// - cancel doesn't crash
///
/// Real OS integration testing requires running on iOS / iPadOS
/// / tvOS / visionOS / Mac Catalyst — out of scope for this
/// XCTest target. Hosts on those platforms exercise the bridge
/// via their own integration tests / running in BGTaskScheduler
/// debug mode.
final class AppleBGTaskSchedulerBridgeTests: XCTestCase {

    func testBridgeConformsToPlatformBridge() {
        // Type-level check: bridge is usable as the actor's
        // platform bridge dependency.
        let bridge: any BASBreathScheduler.PlatformBridge =
            AppleBGTaskSchedulerBridge()
        _ = bridge  // silence unused
    }

    func testRegisterNoneClassReturnsTrueAsNoOp() async {
        // `.none` maintenance class means the caller didn't
        // actually want a wakeup — bridge returns true as a
        // success-no-op without touching the OS.
        let bridge = AppleBGTaskSchedulerBridge()
        let req = BASBreathScheduler.Request(
            id: "test.none.\(UUID().uuidString)",
            maintenanceClass: .none,
            earliestFireAt: Date().addingTimeInterval(60))
        let result = await bridge.register(req)
        XCTAssertTrue(
            result,
            ".none class is a no-op success (no OS call)")
    }

    func testRegisterLightOnNativeMacOSReturnsFalse() async {
        // Native macOS doesn't have BGTaskScheduler. Bridge
        // gracefully returns false; substrate caller stays
        // honest about what's actually scheduled.
        let bridge = AppleBGTaskSchedulerBridge()
        let req = BASBreathScheduler.Request(
            id: "test.light.\(UUID().uuidString)",
            maintenanceClass: .light,
            earliestFireAt: Date().addingTimeInterval(60))
        let result = await bridge.register(req)
        #if os(macOS) && !targetEnvironment(macCatalyst)
        XCTAssertFalse(
            result,
            "Native macOS has no BGTaskScheduler; bridge must " +
            "return false")
        #else
        // On platforms where BGTaskScheduler IS available, the
        // result depends on whether the test bundle's
        // Info.plist registered the identifier. We don't assert
        // a specific value here — just that the call didn't
        // crash.
        _ = result
        #endif
    }

    func testCancelDoesNotCrashOnUnknownID() async {
        // Cancelling an ID that was never registered is a no-op
        // on every platform. This is a defensive contract:
        // hosts shouldn't have to track which IDs got accepted
        // by the OS to cancel safely.
        let bridge = AppleBGTaskSchedulerBridge()
        await bridge.cancel(
            id: "never-registered-\(UUID().uuidString)")
        // Reaching here means no crash.
    }

    func testBreathSchedulerRecordsRequestEvenWhenBridgeRejects()
    async throws {
        // The contract `BASBreathScheduler` documents: even when
        // the OS rejects the submission, the actor still records
        // the breath so foreground-fire / cancel logic works.
        // On native macOS the AppleBGTaskSchedulerBridge always
        // returns false; the scheduler still tracks the request.
        let bridge = AppleBGTaskSchedulerBridge()
        let scheduler = BASBreathScheduler(bridge: bridge)
        let req = BASBreathScheduler.Request(
            id: "test.recorded.\(UUID().uuidString)",
            maintenanceClass: .light,
            earliestFireAt: Date().addingTimeInterval(60))
        let breath = try await scheduler.schedule(
            req, guardLevel: .nominal)
        let count = await scheduler.count()
        XCTAssertEqual(
            count, 1,
            "scheduler records breath even when bridge " +
            "couldn't reach the OS layer")
        XCTAssertEqual(breath.request.id, req.id)
    }

    func testBreathSchedulerCancelsCleanlyAfterBridgeReject()
    async throws {
        // After the bridge rejected (false return), the
        // scheduler still has bookkeeping for the request, so
        // cancel must clean it up without throwing.
        let bridge = AppleBGTaskSchedulerBridge()
        let scheduler = BASBreathScheduler(bridge: bridge)
        let req = BASBreathScheduler.Request(
            id: "test.cancel.\(UUID().uuidString)",
            maintenanceClass: .light,
            earliestFireAt: Date().addingTimeInterval(60))
        _ = try await scheduler.schedule(
            req, guardLevel: .nominal)
        try await scheduler.cancel(id: req.id)
        let count = await scheduler.count()
        XCTAssertEqual(
            count, 0,
            "cancel must remove the recorded breath")
    }
}
