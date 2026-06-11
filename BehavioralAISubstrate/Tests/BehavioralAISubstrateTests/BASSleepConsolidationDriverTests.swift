// MARK: - BASSleepConsolidationDriverTests — 全面进化 T3.1 Phase B gate
//
// The driver's load-bearing claims:
//   1. Flag off ⇒ nil WITHOUT constructing the pass (byte-equal +
//      zero cost;the atomTiers provider must never be consulted)。
//   2. L1 verdict honored: maintenanceAllowed=false or class=.none
//      ⇒ nil even with the flag on。
//   3. Window honored: quarantine/lockdown breath modes zero the
//      window ⇒ nil even when a class was granted。
//   4. Permitted ⇒ the pass runs inside the TURN'S OWN window
//      (checkpoint.windowMs == evolutionSchedulerMaintenanceWindowMs)
//      with the turn's maintenance class。
//   5. Dry-run-first: the driver default is verdict-only — writes
//      require a second explicit opt-in。
//   6. The BGTask identifier is pinned and listed in the DeviceTest
//      app's Info.plist (the OS rejects unlisted identifiers)。

import XCTest
import Foundation
@testable import BASHostKit
@testable import BASMemory
@testable import BASRustCoreBridge

final class BASSleepConsolidationDriverTests: XCTestCase {

    private let referenceNow = Date(timeIntervalSince1970: 1_700_000_000)

    override func tearDown() {
        // Restore the program default — other suites pin it false。
        BASMemorySleepConsolidationPass.sleepConsolidationEnabled = false
        super.tearDown()
    }

    /// Tracks whether the driver ever consulted the corpus provider
    /// (the cheap observable proxy for "constructed the pass")。
    private final class ProviderSpy: @unchecked Sendable {
        private let lock = NSLock()
        private var consultedCount = 0
        func consulted() {
            lock.lock(); defer { lock.unlock() }
            consultedCount += 1
        }
        var count: Int {
            lock.lock(); defer { lock.unlock() }
            return consultedCount
        }
    }

    private func makeDriver(
        spy: ProviderSpy,
        dryRun: Bool = true
    ) throws -> BASSleepConsolidationDriver {
        let store = BASInMemoryMemoryAtomStore()
        let tracker = try BASRustMemoryUsageTrackerActor(useRustCore: true)
        return BASSleepConsolidationDriver(
            tracker: tracker,
            applier: BASMemoryClosedLoopApplier(
                store: store, tracker: BASMemoryUsageTracker()),
            store: store,
            atomTiersProvider: {
                spy.consulted()
                return [:]
            },
            dryRun: dryRun,
            clock: { [referenceNow] in referenceNow })
    }

    /// A real driven turn whose budget frame we then override per
    /// scenario (the result struct is a value — mutation is local)。
    /// @MainActor — the debug-build turn pipeline needs ~550KB of
    /// stack;async XCTest bodies run on 512KB cooperative-pool
    /// threads (the 27e0fcb2e SIGBUS class),so the turn drive hops
    /// to the main thread's 8MB stack。
    @MainActor
    private static func drivenTurn() throws -> BASEBrainTurnResult {
        let runtime = BASHostRuntime(configuration: .fixtureGeneric)
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: "How should I plan tomorrow?",
                title: "t31-phase-b",
                riskLevel: .low))
        guard let turn = result.eBrainTurn else {
            throw XCTSkip("fixture turn unavailable")
        }
        return turn
    }

    /// The fixture turn naturally lands in `.quarantine` run mode
    /// (fresh-session conservatism),whose breath mode zeroes the
    /// maintenance window — correct production behavior,but the
    /// permitted-path tests need a granting mode,so scenarios also
    /// pin `runMode`。
    private func turn(
        maintenanceAllowed: Bool,
        maintenanceClass: BASMaintenanceClass,
        runMode: BASEBrainRunMode = .engage
    ) async throws -> BASEBrainTurnResult {
        var t = try await MainActor.run { try Self.drivenTurn() }
        t.budgetFrame.maintenanceAllowed = maintenanceAllowed
        t.budgetFrame.maintenanceClass = maintenanceClass
        t.budgetFrame.runMode = runMode
        if runMode != .quarantine {
            // The fixture turn naturally carries quarantine signals
            // (fresh-session conservatism: actuation command and/or
            // recovery disposition),which the breath bridge checks
            // BEFORE runMode。 Clear them so the scenario's runMode
            // decides the breath mode。
            t.sovereignActuationCommands.removeAll {
                $0.kind == .quarantine || $0.kind == .deadStop
            }
            if t.recoveryDisposition?.kind == .quarantine {
                t.recoveryDisposition = nil
            }
        }
        return t
    }

    // MARK: - 1. Flag off ⇒ nil without construction

    func testFlagOffReturnsNilWithoutConsultingTheCorpus() async throws {
        BASMemorySleepConsolidationPass.sleepConsolidationEnabled = false
        let spy = ProviderSpy()
        let driver = try makeDriver(spy: spy)
        let permittedTurn = try await turn(
            maintenanceAllowed: true, maintenanceClass: .standard)
        let checkpoint = await driver.runIfPermitted(after: permittedTurn)
        XCTAssertNil(checkpoint)
        XCTAssertEqual(spy.count, 0,
            "flag-off must return nil WITHOUT touching the corpus " +
            "provider (zero cost, ADR-014)")
    }

    // MARK: - 2. L1 verdict honored

    func testL1DenialReturnsNilEvenWithFlagOn() async throws {
        BASMemorySleepConsolidationPass.sleepConsolidationEnabled = true
        let spy = ProviderSpy()
        let driver = try makeDriver(spy: spy)
        let denied = await driver.runIfPermitted(
            after: try await turn(
                maintenanceAllowed: false, maintenanceClass: .standard))
        XCTAssertNil(denied, "maintenanceAllowed=false ⇒ nil")
        let noneClass = await driver.runIfPermitted(
            after: try await turn(
                maintenanceAllowed: true, maintenanceClass: .none))
        XCTAssertNil(noneClass, "class .none ⇒ nil")
        XCTAssertEqual(spy.count, 0)
    }

    // MARK: - 3. Quarantine-zeroed window ⇒ nil even when granted

    func testQuarantineRunModeZeroesWindowAndReturnsNil() async throws {
        BASMemorySleepConsolidationPass.sleepConsolidationEnabled = true
        let spy = ProviderSpy()
        let driver = try makeDriver(spy: spy)
        // L1 grants a class, but quarantine breath mode zeroes the
        // window (EBrainTurnResult+EvolutionPrecisionHotCold) — the
        // driver must honor the ZERO, not the class。 (The fixture
        // turn lands here NATURALLY — fresh-session conservatism。)
        let quarantined = try await turn(
            maintenanceAllowed: true, maintenanceClass: .standard,
            runMode: .quarantine)
        XCTAssertEqual(
            quarantined.evolutionSchedulerMaintenanceWindowMs(), 0)
        let checkpoint = await driver.runIfPermitted(after: quarantined)
        XCTAssertNil(checkpoint,
            "zeroed window ⇒ no pass, even with class granted")
        XCTAssertEqual(spy.count, 0)
    }

    // MARK: - 4. Permitted ⇒ runs inside the turn's own window

    func testPermittedTurnRunsPassWithTurnWindowAndClass() async throws {
        BASMemorySleepConsolidationPass.sleepConsolidationEnabled = true
        let spy = ProviderSpy()
        let driver = try makeDriver(spy: spy)
        let permitted = try await turn(
            maintenanceAllowed: true, maintenanceClass: .standard)
        let expectedWindow =
            permitted.evolutionSchedulerMaintenanceWindowMs()
        XCTAssertGreaterThan(expectedWindow, 0,
            "engage-mode + .standard must grant a window — otherwise " +
            "this test stops testing the permitted path")
        let maybeCheckpoint = await driver.runIfPermitted(after: permitted)
        let checkpoint = try XCTUnwrap(maybeCheckpoint)
        XCTAssertEqual(checkpoint.windowMs, expectedWindow,
            "the pass must run inside the TURN'S OWN maintenance " +
            "window, not an invented budget")
        XCTAssertEqual(checkpoint.maintenanceClass,
                       BASMaintenanceClass.standard.rawValue)
        XCTAssertEqual(spy.count, 1)
        // 5. Dry-run-first default: verdict-only。
        XCTAssertTrue(checkpoint.dryRun,
            "driver default is dry-run — writes need a second " +
            "explicit opt-in (亏的不要 double-key)")
        XCTAssertEqual(checkpoint.preChainHash, checkpoint.postChainHash,
            "dry-run leaves the chain hash still")
    }

    // MARK: - 6. BGTask identifier pinned + listed in Info.plist

    func testBackgroundTaskIdentifierIsPinnedAndPermitted() throws {
        XCTAssertEqual(
            BASSleepConsolidationDriver.backgroundTaskIdentifier,
            "bas.sleep.consolidation")
        // The DeviceTest app must list it — the OS rejects submit
        // for unlisted identifiers (.notPermitted)。
        let plist = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // BehavioralAISubstrateTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // BehavioralAISubstrate
            .appendingPathComponent("DeviceTestApp/Resources/Info.plist")
        guard let data = try? Data(contentsOf: plist) else {
            throw XCTSkip("DeviceTestApp Info.plist not reachable " +
                "(source-stripped environment)")
        }
        let dict = try XCTUnwrap(
            try PropertyListSerialization.propertyList(
                from: data, format: nil) as? [String: Any])
        let permitted = try XCTUnwrap(
            dict["BGTaskSchedulerPermittedIdentifiers"] as? [String])
        XCTAssertTrue(permitted.contains(
            BASSleepConsolidationDriver.backgroundTaskIdentifier),
            "Info.plist must list the consolidation identifier")
    }
}

// MARK: - iOS 27 P3 — continued-task identifier contract (appended gate)

extension BASSleepConsolidationDriverTests {
    func testContinuedTaskIdentifierDerivation() {
        let ids = AppleBGTaskSchedulerBridge.continuedTaskIdentifiers(
            bundleID: "com.foo.App", context: "consolidation",
            unique: "run42")
        XCTAssertEqual(ids?.wildcard, "com.foo.App.consolidation.*")
        XCTAssertEqual(ids?.concrete, "com.foo.App.consolidation.run42")
        // Header contract: wildcard prefix must contain the bundle ID。
        XCTAssertNil(AppleBGTaskSchedulerBridge.continuedTaskIdentifiers(
            bundleID: nil, context: "c", unique: "u"))
        XCTAssertNil(AppleBGTaskSchedulerBridge.continuedTaskIdentifiers(
            bundleID: "b", context: "c*", unique: "u"),
            "wildcard chars in components would corrupt the form")
    }
}
