// MARK: - BASCognitiveBrainPersistenceCascadeTests
// 持续性 发展: tests for the 3 deepening moves:
//   1. Metal D=8 richer signature (full SHA256 → 8
//      channels → L2 norm)
//   2. topAtoms in healthSnapshot (Rust top-K leaderboard)
//   3. Brain auto-capture every Nth summary

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

#if !os(iOS)  // ch 1022 source-gate
final class BASCognitiveBrainPersistenceCascadeTests:
    XCTestCase
{
    // MARK: - 1. Metal D=8 signature

    func testMetalSignatureUsesFullSHA256() async throws {
        // The signature should be sensitive to even
        // small differences in input (full SHA256 → 8
        // channels gives much higher discrimination than
        // D=2)。
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let sigA = await brain.summary("input-A")
            .metalDerivedSignal
        let sigB = await brain.summary("input-B")
            .metalDerivedSignal
        let sigC = await brain.summary("input-AB")
            .metalDerivedSignal
        XCTAssertNotNil(sigA)
        XCTAssertNotNil(sigB)
        XCTAssertNotNil(sigC)
        // Each pair must differ
        XCTAssertNotEqual(sigA, sigB)
        XCTAssertNotEqual(sigB, sigC)
        XCTAssertNotEqual(sigA, sigC)
    }

    func testMetalSignatureDeterministicAcrossBrains()
        async throws
    {
        // D=8 still preserves deterministic property:
        // same input → identical signature
        let brain1 = try await BASCognitiveBrain
            .makeWithAllPilots()
        let brain2 = try await BASCognitiveBrain
            .makeWithAllPilots()
        await brain2.clearVolatilePilotStorage()
        let s1 = await brain1.summary(
            "deterministic test input")
        let s2 = await brain2.summary(
            "deterministic test input")
        XCTAssertEqual(s1.metalDerivedSignal!,
            s2.metalDerivedSignal!, accuracy: 1e-5,
            "D=8 signature still deterministic across" +
            " brain instances")
    }

    func testMetalSignatureRangeNonNegative() async throws {
        // L2 norm is non-negative by construction。
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let sig = await brain.summary("any input")
            .metalDerivedSignal!
        XCTAssertGreaterThanOrEqual(sig, 0)
    }

    // MARK: - 2. topAtoms in healthSnapshot

    func testHealthSnapshotIncludesTopAtoms()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        _ = await brain.summary("a")
        _ = await brain.summary("a")
        _ = await brain.summary("a")
        _ = await brain.summary("b")
        let snap = await brain.healthSnapshot()
        XCTAssertNotNil(snap.topAtoms,
            "Rust pilot wired → topAtoms populates")
        let atoms = snap.topAtoms!
        XCTAssertGreaterThanOrEqual(atoms.count, 2)
        XCTAssertEqual(atoms[0].count, 3,
            "'a' was seen 3 times → top of leaderboard")
    }

    func testHealthSnapshotTopAtomsLimitedToFive()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        // 10 unique inputs each once → top-5 must
        // return only 5 entries
        for i in 0..<10 {
            _ = await brain.summary("unique-\(i)")
        }
        let snap = await brain.healthSnapshot()
        XCTAssertEqual(snap.topAtoms?.count, 5,
            "healthSnapshot.topAtoms capped at top-5")
    }

    func testHealthSnapshotNoRustPilotNoTopAtoms()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()  // no Rust
        let snap = await brain.healthSnapshot()
        XCTAssertNil(snap.topAtoms,
            "No Rust pilot wired → nil topAtoms")
    }

    func testHealthSnapshotCodableWithTopAtoms()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        _ = await brain.summary("hi")
        let original = await brain.healthSnapshot()
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .millisecondsSince1970
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .millisecondsSince1970
        let data = try enc.encode(original)
        let decoded = try dec.decode(
            BASCognitiveBrainHealthSnapshot.self,
            from: data)
        XCTAssertEqual(decoded.topAtoms,
            original.topAtoms,
            "Codable round-trip preserves topAtoms")
    }

    // MARK: - 3. Auto-capture every Nth summary

    func testAutoCaptureZeroDisabled() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots(
                healthSnapshotHistoryCapacity: 10,
                healthSnapshotAutoCaptureEvery: 0)
        for _ in 0..<5 {
            _ = await brain.summary("test")
        }
        let history = await brain.healthHistory
        let count = await history!.count
        XCTAssertEqual(count, 0,
            "Auto-capture 0 → no captures even after 5" +
            " summaries")
    }

    func testAutoCaptureEvery3rdSummary() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots(
                healthSnapshotHistoryCapacity: 10,
                healthSnapshotAutoCaptureEvery: 3)
        // 10 summaries → captures at call 3, 6, 9 = 3
        for i in 0..<10 {
            _ = await brain.summary("input-\(i)")
        }
        let history = await brain.healthHistory
        let count = await history!.count
        XCTAssertEqual(count, 3,
            "Every 3rd call across 10 → 3 captures")
    }

    func testAutoCaptureNoOpWithoutRingBuffer() async throws {
        // Auto-capture set, but no ring buffer allocated
        // → cadence count still increments but no
        // snapshot appended (no buffer)。
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots(
                healthSnapshotHistoryCapacity: 0,
                healthSnapshotAutoCaptureEvery: 2)
        for _ in 0..<6 {
            _ = await brain.summary("test")
        }
        let history = await brain.healthHistory
        XCTAssertNil(history,
            "Capacity 0 → no ring buffer → no captures" +
            " stored anywhere")
    }

    func testAutoCaptureRingBufferOverflow() async throws {
        // Capacity 2, every 1 = capture every summary。
        // 5 summaries → 5 captures → overflow drops 3
        // oldest → 2 remain。
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots(
                healthSnapshotHistoryCapacity: 2,
                healthSnapshotAutoCaptureEvery: 1)
        for _ in 0..<5 {
            _ = await brain.summary("test")
        }
        let history = await brain.healthHistory
        let count = await history!.count
        XCTAssertEqual(count, 2,
            "Ring buffer caps at capacity 2 — 5 captures" +
            " collapse to newest 2")
    }

    func testAutoCaptureTrendObservable() async throws {
        // Auto-captured snapshots feed the trendSummary。
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots(
                healthSnapshotHistoryCapacity: 10,
                healthSnapshotAutoCaptureEvery: 2)
        for i in 0..<6 {
            _ = await brain.summary("event-\(i)")
        }
        // 6 summaries with cadence 2 → 3 captures at
        // calls 2, 4, 6
        let history = await brain.healthHistory
        let count = await history!.count
        XCTAssertEqual(count, 3)
        let trend = await history!.trendSummary()
        XCTAssertNotNil(trend)
        XCTAssertEqual(trend?.snapshotCount, 3)
    }

    // MARK: - Integration: 3 changes flow together

    func testAutoCapturedSnapshotsIncludeTopAtomsAndMetalSignal()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots(
                healthSnapshotHistoryCapacity: 5,
                healthSnapshotAutoCaptureEvery: 2)
        // Repeat one input twice + others once → top
        // atom is the repeated one
        _ = await brain.summary("popular")
        _ = await brain.summary("popular")
        _ = await brain.summary("unique-1")
        _ = await brain.summary("unique-2")
        let history = await brain.healthHistory
        let snaps = await history!.all
        XCTAssertEqual(snaps.count, 2,
            "4 summaries / cadence 2 = 2 captures")
        for snap in snaps {
            XCTAssertNotNil(snap.topAtoms,
                "Each auto-captured snapshot includes" +
                " topAtoms")
        }
        // Latest snapshot's leaderboard:popular at top
        let latest = snaps.last!
        XCTAssertEqual(latest.topAtoms?.first?.count, 2,
            "'popular' had 2 occurrences at second" +
            " capture time")
    }
}
#endif
