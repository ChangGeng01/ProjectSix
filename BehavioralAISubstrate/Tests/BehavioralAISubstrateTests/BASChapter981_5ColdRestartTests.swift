// MARK: - BASChapter981_5ColdRestartTests
// chapter 九百八十一.5 / M3610.5 — USER-PASS-7 deferred item DI3
// regression tests
//
// Per ARC_SEAL_953_981.md deferred item #3 (app-suspension state
// persistence) — Codable snapshot + validation tests。

import XCTest
@testable import BASMemory

final class BASChapter981_5ColdRestartTests: XCTestCase {

    // MARK: - 1. Snapshot Codable round-trip

    func testSnapshotCodableRoundTrip() throws {
        let snap = BASAgentFabricSessionSnapshot(
            snapshotID: "snap-1",
            sessionID: "session-1",
            sdkVersion: "v1",
            agentRoster: [
                BASAgentSpec(
                    agentID: "planner.1",
                    role: .planner,
                    writeDomains: [.candidateFrontier],
                    defaultLeaseProfile: .coldSeat,
                    visibility: .high),
            ],
            userPersonas: [],
            hostPersonas: [],
            warrants: [
                BASAgentPersonaSovereignWarrant(
                    warrantID: "w1",
                    grantedFields: ["tone"]),
            ],
            watcherCounters: ["anomaly.alert": 3],
            createdAtNanos: 1_234_567_890)
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let data = try enc.encode(snap)
        let back = try JSONDecoder().decode(
            BASAgentFabricSessionSnapshot.self, from: data)
        XCTAssertEqual(snap, back)
    }

    func testSnapshotSortsRoster() {
        let snap = BASAgentFabricSessionSnapshot(
            snapshotID: "snap-1",
            sessionID: "session-1",
            agentRoster: [
                BASAgentSpec(
                    agentID: "z",
                    role: .planner,
                    defaultLeaseProfile: .coldSeat,
                    visibility: .high),
                BASAgentSpec(
                    agentID: "a",
                    role: .planner,
                    defaultLeaseProfile: .coldSeat,
                    visibility: .high),
            ])
        XCTAssertEqual(
            snap.agentRoster.map { $0.agentID },
            ["a", "z"],
            "ch 981.5 DI3: roster auto-sorted by agentID")
    }

    // MARK: - 2. SDK version validation

    func testValidate_SdkVersionMismatch() {
        let snap = BASAgentFabricSessionSnapshot(
            snapshotID: "s1",
            sessionID: "x",
            sdkVersion: "v2")  // future version
        let result =
            BASAgentFabricColdRestart.validate(
                snap, sdkVersion: "v1")
        XCTAssertFalse(result.valid)
        XCTAssertTrue(result.findings.contains { f in
            f.contains("sdk-mismatch")
        })
    }

    func testValidate_SdkVersionMatchPasses() {
        let snap = BASAgentFabricSessionSnapshot(
            snapshotID: "s1",
            sessionID: "x",
            sdkVersion: "v1")
        let result =
            BASAgentFabricColdRestart.validate(
                snap, sdkVersion: "v1")
        XCTAssertTrue(result.valid)
    }

    // MARK: - 3. Snapshot age validation

    func testValidate_SnapshotTooOldFails() {
        let snap = BASAgentFabricSessionSnapshot(
            snapshotID: "s1",
            sessionID: "x",
            sdkVersion: "v1",
            createdAtNanos: 1)
        let twentyDaysNanos: Int64 =
            20 * 24 * 60 * 60 * 1_000_000_000
        let result =
            BASAgentFabricColdRestart.validate(
                snap,
                currentNanos: twentyDaysNanos,
                maxAgeNanos:
                    BASAgentFabricColdRestart
                        .defaultMaxAgeNanos)
        XCTAssertFalse(result.valid)
        XCTAssertTrue(result.findings.contains { f in
            f.contains("snapshot-too-old")
        })
    }

    func testValidate_SnapshotZeroNanosSkipsAgeCheck() {
        // Caller passes currentNanos = 0 → skip age check
        let snap = BASAgentFabricSessionSnapshot(
            snapshotID: "s1",
            sessionID: "x",
            sdkVersion: "v1",
            createdAtNanos: 1)
        let result =
            BASAgentFabricColdRestart.validate(
                snap,
                currentNanos: 0,
                sdkVersion: "v1")
        XCTAssertTrue(result.valid,
            "ch 981.5 DI3: currentNanos=0 → skip age check")
    }

    // MARK: - 4. Forbidden persona detection

    func testValidate_ForbiddenPersonaRejected() {
        let forbiddenShame = BASAgentPersonaSpec(
            personaID: "p-shame",
            agentID: "x",
            tone: "cool",
            warmth: 0.10, directness: 0.5,
            skepticism: 0.5, structureBias: 0.5,
            creativityBias: 0.5,
            challengeIntensity: 0.85,
            comparisonBias: 0.5,
            guardBias: 0.10,
            visibility: .high,
            hostConstraintsRef: "",
            riskConstraintsRef: "",
            sovereignConstraintsRef: "",
            versionRef: "")
        let snap = BASAgentFabricSessionSnapshot(
            snapshotID: "s1",
            sessionID: "x",
            sdkVersion: "v1",
            userPersonas: [forbiddenShame])
        let result =
            BASAgentFabricColdRestart.validate(
                snap, sdkVersion: "v1")
        // Validation stays valid — forbidden persona just
        // dropped, not session-killing
        XCTAssertTrue(result.valid,
            "ch 981.5 DI3: forbidden persona drop does NOT " +
            "fail the snapshot — host may restore the session " +
            "with non-forbidden personas")
        XCTAssertEqual(
            result.rejectedPersonaIDs, ["p-shame"])
        XCTAssertTrue(result.findings.contains { f in
            f.contains("forbidden-persona") &&
            f.contains("shame")
        })
    }

    // MARK: - 5. Warrant ID corruption

    func testValidate_EmptyWarrantIDFails() {
        let snap = BASAgentFabricSessionSnapshot(
            snapshotID: "s1",
            sessionID: "x",
            sdkVersion: "v1",
            warrants: [
                BASAgentPersonaSovereignWarrant(
                    warrantID: ""),
            ])
        let result =
            BASAgentFabricColdRestart.validate(
                snap, sdkVersion: "v1")
        XCTAssertFalse(result.valid,
            "ch 981.5 DI3: empty warrant ID = corrupted " +
            "snapshot → fail")
    }

    // MARK: - 6. Orphan persona detection (warning only)

    func testValidate_OrphanPersonaFlaggedNotFailed() {
        // Persona references agentID not in roster
        let orphan = BASAgentPersonaSpec(
            personaID: "p-orphan",
            agentID: "missing.agent",
            tone: "neutral",
            warmth: 0.5, directness: 0.5,
            skepticism: 0.5, structureBias: 0.5,
            creativityBias: 0.5,
            challengeIntensity: 0.5,
            comparisonBias: 0.5,
            guardBias: 0.5,
            visibility: .high,
            hostConstraintsRef: "",
            riskConstraintsRef: "",
            sovereignConstraintsRef: "",
            versionRef: "")
        let snap = BASAgentFabricSessionSnapshot(
            snapshotID: "s1",
            sessionID: "x",
            sdkVersion: "v1",
            agentRoster: [],
            userPersonas: [orphan])
        let result =
            BASAgentFabricColdRestart.validate(
                snap, sdkVersion: "v1")
        XCTAssertTrue(result.valid,
            "ch 981.5 DI3: orphan persona is warning only")
        XCTAssertTrue(result.findings.contains { f in
            f.contains("orphan-persona")
        })
    }

    // MARK: - 7. Empty snapshot passes

    func testValidate_EmptySnapshotPasses() {
        let snap = BASAgentFabricSessionSnapshot(
            snapshotID: "s1",
            sessionID: "x",
            sdkVersion: "v1")
        let result =
            BASAgentFabricColdRestart.validate(
                snap, sdkVersion: "v1")
        XCTAssertTrue(result.valid)
        XCTAssertTrue(result.findings.isEmpty)
        XCTAssertTrue(result.rejectedPersonaIDs.isEmpty)
    }

    // MARK: - 8. Findings sorted deterministically

    func testValidate_FindingsSortedForReplay() {
        let snap = BASAgentFabricSessionSnapshot(
            snapshotID: "s1",
            sessionID: "x",
            sdkVersion: "v2",  // mismatch
            warrants: [
                BASAgentPersonaSovereignWarrant(
                    warrantID: ""),  // corrupted
            ])
        let r1 = BASAgentFabricColdRestart.validate(
            snap, sdkVersion: "v1")
        let r2 = BASAgentFabricColdRestart.validate(
            snap, sdkVersion: "v1")
        XCTAssertEqual(r1, r2,
            "ch 981.5 DI3: validation deterministic for " +
            "same input")
        XCTAssertEqual(
            r1.findings, r1.findings.sorted())
    }
}
