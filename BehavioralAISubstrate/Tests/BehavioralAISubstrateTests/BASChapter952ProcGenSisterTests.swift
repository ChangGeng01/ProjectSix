// MARK: - BASChapter952ProcGenSisterTests
// chapter 九百五十二 / M3465
//
// User directive (verbatim): 「我希望 大部分 固定 数值 都可以 改成
// 完全 flexible 程序化 生成 而不是 死数值」 — most hardcoded values
// should be procedurally generated,not dead-value literals。
//
// Approach:rather than mutating ch 934-938 tests (which serve as
// PINNING regression guards for ch 933 USER-PASS finding — they
// pin specific byte values to prove the bridge isn't reverted to
// a stub),this file ADDS sister tests that exercise the SAME
// routed bridges with PROCEDURALLY-GENERATED inputs across N
// seeded iterations。
//
// Coverage strategy:
//   - 50 iter per bridge by default (5 routed stores × 50 iter
//     = 250 fuzz inputs per macOS run)
//   - Scaling via BAS_FUZZ_ITER for device run (e.g. 500 iter
//     = 2500 inputs in 2-hour budget)
//   - Each iter uses `testSeed(iteration: i)` for reproducibility
//
// Sister-bridge coverage:
//   - L8 AtomLifecycle (ch 934)            → BASFuzzL8.atomLifecycleEvent
//   - DeletionManifest (ch 935)            → ad-hoc proc-gen here
//   - UserState (ch 936)                   → BASFuzzL8.userState
//   - VersionTree (ch 937)                 → ad-hoc proc-gen here
//   - EventLog (ch 938)                    → BASFuzzL8.eventLogEntry

import XCTest
import BASRuntimeCore
@testable import BASMemory

final class BASChapter952ProcGenSisterTests: XCTestCase {

    /// Number of proc-gen fuzz iterations per bridge。 Default 50
    /// (~5s per bridge);device run sets via `BAS_FUZZ_ITER=N`。
    private var iterCount: Int {
        if let env = ProcessInfo.processInfo
            .environment["BAS_FUZZ_ITER"],
           let n = Int(env), n > 0
        {
            return n
        }
        return 50
    }

    private func tempURL(_ tag: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ch952-procgen-\(tag)-\(UUID().uuidString).sqlite")
    }

    private func cleanup(_ url: URL) {
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let p = url.path + suffix
            if fm.fileExists(atPath: p) {
                try? fm.removeItem(atPath: p)
            }
        }
    }

    // MARK: - ch 934 sister: AtomLifecycle proc-gen fuzz

    /// Fuzz AtomLifecycle round-trip with N seeded proc-gen events。
    /// Each iter generates a different event shape (phase × action ×
    /// outcome combination + actorRef optionality)。 Augments ch 934
    /// fixed-byte regression guards with broad shape coverage。
    func testL8AtomLifecycleProcGenFuzzRoundTrip() async throws {
        let url = tempURL("atom-procgen")
        defer { cleanup(url) }
        let store = try BASRoutedAtomLifecycleStore(databaseURL: url)
        for i in 0..<iterCount {
            var rng = BASFuzzRng(seed: testSeed(iteration: i))
            let event = BASFuzzL8.atomLifecycleEvent(rng: &rng)
            let appended = try await store.appendEvent(event)
            XCTAssertEqual(appended.eventID, event.eventID,
                "ch952 ProcGen iter=\(i) eventID drift")
            // Full-row read-back via forAtom
            let read = await store.events(forAtom: event.atomID)
            let matched = read.first { $0.eventID == event.eventID }
            XCTAssertNotNil(matched,
                "ch952 ProcGen iter=\(i) seed=\(rng.state) " +
                "atom round-trip drop")
            // Full-field assertions
            XCTAssertEqual(matched?.atomID, event.atomID)
            XCTAssertEqual(matched?.sessionID, event.sessionID)
            XCTAssertEqual(matched?.fromPhaseByte, event.fromPhaseByte)
            XCTAssertEqual(matched?.toPhaseByte, event.toPhaseByte)
            XCTAssertEqual(matched?.actionByte, event.actionByte)
            XCTAssertEqual(matched?.outcome, event.outcome)
            XCTAssertEqual(matched?.recordedAtMs, event.recordedAtMs)
            XCTAssertEqual(matched?.actorRef, event.actorRef)
        }
    }

    /// Fuzz events(forSession:) round-trip。 Pre-seeds N events
    /// into shared session,reads them back,asserts count matches。
    func testL8AtomLifecycleProcGenForSessionFuzz() async throws {
        let url = tempURL("atom-session-procgen")
        defer { cleanup(url) }
        let store = try BASRoutedAtomLifecycleStore(databaseURL: url)
        let sharedSession = "ch952-shared-session"
        var expectedIDs: Set<String> = []
        for i in 0..<iterCount {
            var rng = BASFuzzRng(seed: testSeed(iteration: i))
            let event = BASFuzzL8.atomLifecycleEvent(
                rng: &rng, sessionID: sharedSession)
            _ = try await store.appendEvent(event)
            expectedIDs.insert(event.eventID)
        }
        let read = await store.events(forSession: sharedSession)
        let readIDs = Set(read.map { $0.eventID })
        XCTAssertEqual(readIDs, expectedIDs,
            "ch952 forSession ID-set drift: " +
            "missing=\(expectedIDs.subtracting(readIDs)) " +
            "extra=\(readIDs.subtracting(expectedIDs))")
    }

    // MARK: - ch 935 sister: DeletionManifest proc-gen fuzz

    /// Proc-gen DeletionManifest for fuzz coverage of the bridge。
    private func procGenManifest(
        rng: inout BASFuzzRng
    ) -> BASHostConstitutionDeletionRecord {
        let types = ["cascade", "selective", "rollback"]
        let targetCount = rng.nextInt(in: 0...5)
        let targets = (0..<targetCount)
            .map { "\"atom-\($0)-\(rng.next())\"" }
            .joined(separator: ",")
        let targetsJson = "[\(targets)]"
        let hasCascade = rng.nextBool(p: 0.6)
        let cascadeJson: String? = hasCascade
            ? "[\"cascade-\(rng.next())\"]"
            : nil
        let hasVersion = rng.nextBool(p: 0.5)
        let versionRef: String? = hasVersion
            ? "v-\(rng.next())"
            : nil
        return BASHostConstitutionDeletionRecord(
            manifestID: "m-\(rng.next())",
            vaultID: "vault-\(rng.nextInt(upTo: 10))",
            targetRefsJson: targetsJson,
            deletionType: rng.pick(types),
            appliedAtMs: Int64(rng.nextInt(in: 1...10_000_000)),
            cascadedRefsJson: cascadeJson,
            versionRef: versionRef)
    }

    /// Fuzz DeletionManifest forVault round-trip。 Each iter generates
    /// a unique vault + appends a manifest + reads back + verifies。
    func testDeletionManifestProcGenForVaultFuzz() async throws {
        let url = tempURL("manifest-procgen")
        defer { cleanup(url) }
        let store = try BASRoutedHostConstitutionDeletionManifestStore(
            databaseURL: url)
        for i in 0..<iterCount {
            var rng = BASFuzzRng(seed: testSeed(iteration: i))
            let m = procGenManifest(rng: &rng)
            _ = try await store.appendManifest(m)
            let read = await store.manifests(forVault: m.vaultID)
            let matched = read.first { $0.manifestID == m.manifestID }
            XCTAssertNotNil(matched,
                "ch952 DeletionManifest iter=\(i) " +
                "vault round-trip drop")
            XCTAssertEqual(matched?.deletionType, m.deletionType)
            XCTAssertEqual(matched?.targetRefsJson, m.targetRefsJson)
            XCTAssertEqual(matched?.cascadedRefsJson, m.cascadedRefsJson)
            XCTAssertEqual(matched?.versionRef, m.versionRef)
            XCTAssertEqual(matched?.appliedAtMs, m.appliedAtMs)
        }
    }

    // MARK: - ch 936 sister: UserState proc-gen fuzz

    /// Fuzz UserState round-trip with proc-gen states across N
    /// iterations。 Each iter generates random emotional / momentum /
    /// risk / complexity trends + variable agent route + event kind
    /// arrays。 Augments ch 936 hardcoded-value pinning tests。
    func testUserStateProcGenRoundTripFuzz() async throws {
        let url = tempURL("userstate-procgen")
        defer { cleanup(url) }
        let store = try BASRoutedUserStateStore(databaseURL: url)
        for i in 0..<iterCount {
            var rng = BASFuzzRng(seed: testSeed(iteration: i))
            let state = BASFuzzL8.userState(rng: &rng)
            let sessID = "sess-procgen-\(rng.next())"
            _ = try await store.append(state, sessionID: sessID)
            let read = await store.state(forID: state.stateID)
            XCTAssertNotNil(read,
                "ch952 UserState iter=\(i) state(forID:) nil")
            XCTAssertEqual(read?.stateID, state.stateID)
            XCTAssertEqual(read?.generatedAtMs, state.generatedAtMs)
            // Float equality with accuracy because Codable may
            // double-round-trip through JSON
            XCTAssertEqual(read?.emotionalTrend ?? -999,
                           state.emotionalTrend, accuracy: 1e-6)
            XCTAssertEqual(read?.projectMomentum ?? -999,
                           state.projectMomentum, accuracy: 1e-6)
            XCTAssertEqual(read?.memoryHeat ?? -999,
                           state.memoryHeat, accuracy: 1e-6)
            XCTAssertEqual(read?.riskTrend ?? -999,
                           state.riskTrend, accuracy: 1e-6)
            XCTAssertEqual(read?.complexityAddictionScore ?? -999,
                           state.complexityAddictionScore,
                           accuracy: 1e-6)
            XCTAssertEqual(read?.agentRouteHistory,
                           state.agentRouteHistory)
            XCTAssertEqual(read?.lastNEventKinds,
                           state.lastNEventKinds)
        }
    }

    // MARK: - ch 937 sister: VersionTree proc-gen fuzz

    /// Proc-gen VersionRecord for fuzz coverage of the bridge。
    private func procGenVersion(
        rng: inout BASFuzzRng,
        vaultID: String
    ) -> BASHostConstitutionVersionRecord {
        let parentExists = rng.nextBool(p: 0.5)
        let parentVersionID: String? = parentExists
            ? "parent-\(rng.next())"
            : nil
        let signatureBytes = Data((0..<32).map { _ in
            UInt8(rng.nextInt(upTo: 256))
        })
        let mergedJson: String? = rng.nextBool(p: 0.3)
            ? "[\"v-merge-\(rng.next())\"]"
            : nil
        return BASHostConstitutionVersionRecord(
            versionID: "v-\(rng.next())",
            vaultID: vaultID,
            parentVersionID: parentVersionID,
            createdAtMs: Int64(rng.nextInt(in: 1...10_000_000)),
            signatureHash: signatureBytes,
            isRollbackPoint: rng.nextBool(),
            mergedFromJson: mergedJson)
    }

    /// Fuzz VersionTree forVault round-trip。
    func testVersionTreeProcGenForVaultFuzz() async throws {
        let url = tempURL("versiontree-procgen")
        defer { cleanup(url) }
        let store = try BASRoutedHostConstitutionVersionTreeStore(
            databaseURL: url)
        for i in 0..<iterCount {
            var rng = BASFuzzRng(seed: testSeed(iteration: i))
            let vaultID = "vault-procgen-\(rng.next())"
            let v = procGenVersion(rng: &rng, vaultID: vaultID)
            _ = try await store.appendVersion(v)
            let read = await store.versions(forVault: vaultID)
            let matched = read.first { $0.versionID == v.versionID }
            XCTAssertNotNil(matched,
                "ch952 VersionTree iter=\(i) " +
                "vault round-trip drop")
            XCTAssertEqual(matched?.parentVersionID, v.parentVersionID)
            XCTAssertEqual(matched?.createdAtMs, v.createdAtMs)
            XCTAssertEqual(matched?.signatureHash, v.signatureHash,
                "ch952 VersionTree iter=\(i) signature BLOB drift")
            XCTAssertEqual(matched?.isRollbackPoint, v.isRollbackPoint)
            XCTAssertEqual(matched?.mergedFromJson, v.mergedFromJson)
        }
    }

    // MARK: - ch 938 sister: EventLog proc-gen fuzz

    /// Fuzz EventLog forSession round-trip。 Each iter appends entry
    /// with proc-gen kind/risk/refs,reads back,verifies presence。
    func testEventLogProcGenForSessionFuzz() async throws {
        let url = tempURL("eventlog-procgen")
        defer { cleanup(url) }
        let store = try BASRoutedEventLogStorage(databaseURL: url)
        let sharedSession = "ch952-eventlog-shared"
        var expectedIDs: Set<String> = []
        for i in 0..<iterCount {
            var rng = BASFuzzRng(seed: testSeed(iteration: i))
            let entry = BASFuzzL8.eventLogEntry(
                rng: &rng, sessionID: sharedSession)
            _ = try await store.append(entry)
            expectedIDs.insert(entry.eventID)
        }
        let read = await store.events(forSession: sharedSession)
        let readIDs = Set(read.map { $0.eventID })
        XCTAssertEqual(readIDs.count, expectedIDs.count,
            "ch952 EventLog forSession iter=\(iterCount) " +
            "count drift: read=\(readIDs.count) " +
            "expected=\(expectedIDs.count)")
        XCTAssertTrue(expectedIDs.isSubset(of: readIDs),
            "ch952 EventLog forSession missing: " +
            "\(expectedIDs.subtracting(readIDs))")
        // Verify sequenceNumber assignment monotonicity (chapter
        // 944 LIMIT clause invariant)
        let sortedBySeq = read
            .sorted { $0.sequenceNumber < $1.sequenceNumber }
        for i in 1..<sortedBySeq.count {
            XCTAssertGreaterThan(
                sortedBySeq[i].sequenceNumber,
                sortedBySeq[i - 1].sequenceNumber,
                "ch952 EventLog sequenceNumber not strictly " +
                "monotonic at idx=\(i)")
        }
    }
}
