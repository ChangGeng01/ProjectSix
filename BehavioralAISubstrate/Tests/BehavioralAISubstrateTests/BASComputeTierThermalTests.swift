import XCTest
@testable import BASLeaseLife
@testable import BASRuntimeCore

/// M102 — T3 per-tier thermal twin + compute router contract tests.
///
/// Covered invariants:
///
/// 1. `BASComputeTier` raw values stable (cross-layer contract)
/// 2. `BASComputeTierThermalReading` clamps headroom to [0,1]
/// 3. `BASComputeTierThermalSnapshot` reading(for:) / coolestTier /
///    hottestTier helpers
/// 4. `BASComputeRouter` preferred-order behavior (NPU > GPU > CPU)
/// 5. Strict headroom floor filters disqualified tiers
/// 6. Fallback: all preferred tiers below floor → coolest tier wins
/// 7. Empty snapshot returns nil
/// 8. Codable round-trip (schema stability)
final class BASComputeTierThermalTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1000)

    // MARK: - 1. Enum raw values

    func testComputeTierRawValuesAreStable() {
        XCTAssertEqual(BASComputeTier.cpu.rawValue, "cpu")
        XCTAssertEqual(BASComputeTier.gpu.rawValue, "gpu")
        XCTAssertEqual(BASComputeTier.npu.rawValue, "npu")
    }

    // MARK: - 2. Reading clamps headroom

    func testReadingClampsHeadroomAboveOne() {
        let r = BASComputeTierThermalReading(
            tier: .cpu, level: .nominal,
            headroom: 1.5, observedAt: t0)
        XCTAssertEqual(r.headroom, 1.0,
            "values > 1.0 clamped down")
    }

    func testReadingClampsHeadroomBelowZero() {
        let r = BASComputeTierThermalReading(
            tier: .cpu, level: .critical,
            headroom: -0.3, observedAt: t0)
        XCTAssertEqual(r.headroom, 0.0,
            "values < 0.0 clamped up")
    }

    // MARK: - 3. Snapshot helpers

    func testSnapshotReadingForTier() {
        let snap = makeSnapshot(cpu: 0.5, gpu: 0.7, npu: 0.9)
        XCTAssertEqual(
            snap.reading(for: .cpu)?.headroom, 0.5)
        XCTAssertEqual(
            snap.reading(for: .gpu)?.headroom, 0.7)
        XCTAssertEqual(
            snap.reading(for: .npu)?.headroom, 0.9)
    }

    func testSnapshotCoolestAndHottestTiers() {
        let snap = makeSnapshot(cpu: 0.2, gpu: 0.5, npu: 0.9)
        XCTAssertEqual(snap.coolestTier, .npu)
        XCTAssertEqual(snap.hottestTier, .cpu)
    }

    func testEmptySnapshotHasNilCoolestAndHottest() {
        let snap = BASComputeTierThermalSnapshot(
            readings: [], snapshotAt: t0)
        XCTAssertNil(snap.coolestTier)
        XCTAssertNil(snap.hottestTier)
    }

    // MARK: - 4. Router preferred order

    func testRouterPrefersNPUByDefault() {
        let snap = makeSnapshot(cpu: 0.9, gpu: 0.9, npu: 0.9)
        let router = BASComputeRouter()
        XCTAssertEqual(router.route(snapshot: snap), .npu,
            "all cool → NPU wins the default preferred order")
    }

    func testRouterFallsBackToGPUWhenNPUBelowFloor() {
        // NPU too hot (below floor), GPU healthy → GPU wins.
        let snap = makeSnapshot(cpu: 0.9, gpu: 0.8, npu: 0.05)
        let router = BASComputeRouter(minHeadroom: 0.1)
        XCTAssertEqual(router.route(snapshot: snap), .gpu)
    }

    func testRouterFallsBackToCPUWhenNPUAndGPUBelowFloor() {
        let snap = makeSnapshot(cpu: 0.9, gpu: 0.05, npu: 0.05)
        let router = BASComputeRouter(minHeadroom: 0.1)
        XCTAssertEqual(router.route(snapshot: snap), .cpu)
    }

    // MARK: - 5. Strict-floor filter

    func testRouterRespectsStrictFloor() {
        // All three tiers below the floor 0.5 — fallback picks
        // the coolest (highest headroom) tier even below floor.
        let snap = makeSnapshot(cpu: 0.2, gpu: 0.3, npu: 0.4)
        let router = BASComputeRouter(minHeadroom: 0.5)
        XCTAssertEqual(router.route(snapshot: snap), .npu,
            "fallback returns coolest tier when every preferred is below floor")
    }

    // MARK: - 6. Empty snapshot → nil

    func testRouterReturnsNilForEmptySnapshot() {
        let snap = BASComputeTierThermalSnapshot(
            readings: [], snapshotAt: t0)
        XCTAssertNil(BASComputeRouter().route(snapshot: snap))
    }

    // MARK: - 7. Custom preferred order

    func testRouterCustomPreferredOrderCpuFirst() {
        let snap = makeSnapshot(cpu: 0.9, gpu: 0.9, npu: 0.9)
        let router = BASComputeRouter(
            preferredOrder: [.cpu, .gpu, .npu])
        XCTAssertEqual(
            router.route(snapshot: snap), .cpu,
            "custom preferred order flips the tier preference")
    }

    func testRouterPartialSnapshotSkipsMissingTiers() {
        // Snapshot only has GPU reading — NPU preference fails
        // the guard clause and continues to GPU.
        let snap = BASComputeTierThermalSnapshot(
            readings: [
                BASComputeTierThermalReading(
                    tier: .gpu, level: .nominal,
                    headroom: 0.8, observedAt: t0)
            ],
            snapshotAt: t0)
        XCTAssertEqual(
            BASComputeRouter().route(snapshot: snap), .gpu,
            "missing NPU is skipped, first available matches")
    }

    // MARK: - 8. Codable round-trip

    func testSnapshotCodableRoundTrip() throws {
        let snap = makeSnapshot(cpu: 0.4, gpu: 0.6, npu: 0.8)
        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder().decode(
            BASComputeTierThermalSnapshot.self, from: data)
        XCTAssertEqual(decoded, snap)
    }

    // MARK: - Helper

    private func makeSnapshot(
        cpu: Double,
        gpu: Double,
        npu: Double
    ) -> BASComputeTierThermalSnapshot {
        BASComputeTierThermalSnapshot(
            readings: [
                BASComputeTierThermalReading(
                    tier: .cpu, level: .nominal,
                    headroom: cpu, observedAt: t0),
                BASComputeTierThermalReading(
                    tier: .gpu, level: .nominal,
                    headroom: gpu, observedAt: t0),
                BASComputeTierThermalReading(
                    tier: .npu, level: .nominal,
                    headroom: npu, observedAt: t0),
            ],
            snapshotAt: t0)
    }
}
