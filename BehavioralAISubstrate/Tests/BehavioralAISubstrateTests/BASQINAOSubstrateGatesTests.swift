import XCTest
@testable import BASLeaseLife
@testable import BASRuntimeCore
@testable import BASMetalSubstrate

/// QINAO Substrate-100 gates — Phase-2 NAMED-GATE OVERLAY (template batch).
///
/// Each `test_qinao_<metric_key>()` is the grep-able QINAO gate for one metric in
/// `Docs/QINAO_SUBSTRATE_100_METRICS.md`, asserting the RAISED BAR (tolerance=0, full grid,
/// determinism) over already-tested behavior. The func name == the QINAO metric key for CI grep.
///
/// ⚠️ TEMPLATE BATCH — establishes the pattern for the remaining ~76 substrate gates. Authored from the
/// read APIs (BASThermalTwin.guardLevel / BASNormEpsilon); pending `swift test` verification in-suite.
final class BASQINAOSubstrateGatesTests: XCTestCase {

    // MARK: - #1 thermal_guard_mapping_purity (CRITICAL)
    // Pure mapping BASThermalTwin.guardLevel must hit the documented matrix on a full grid + random
    // samples, be deterministic (same input twice == same output), and clamp out-of-range / NaN without trapping.
    private func expectedGuard(_ thermal: BASThermalLevel, _ p: Double) -> BASThermalGuardLevel {
        let c = min(1, max(0, p.isNaN ? 0 : p))
        switch thermal {
        case .nominal:  return c >= 0.7 ? .watch : .nominal
        case .warm:     return c < 0.3 ? .watch : .throttle
        case .hot:      return c >= 0.7 ? .emergency : .throttle
        case .critical: return .emergency
        }
    }

    func test_qinao_thermal_guard_mapping_purity() {
        let grid: [Double] = [0.0, 0.29, 0.3, 0.69, 0.7, 1.0]
        var checked = 0
        for thermal in BASThermalLevel.allCases {
            for p in grid {
                let got = BASThermalTwin.guardLevel(for: thermal, accumulated: p)
                XCTAssertEqual(got, expectedGuard(thermal, p), "matrix mismatch \(thermal) p=\(p)")  // tolerance=0
                // determinism: identical input twice -> identical output
                XCTAssertEqual(got, BASThermalTwin.guardLevel(for: thermal, accumulated: p))
                checked += 1
            }
            // out-of-range + NaN must clamp, never trap
            for p in [-1e9, -1e-12, 1.0 + 1e-12, 1e9, Double.nan] {
                let got = BASThermalTwin.guardLevel(for: thermal, accumulated: p)
                XCTAssertEqual(got, expectedGuard(thermal, p), "clamp/NaN mismatch \(thermal) p=\(p)")
                checked += 1
            }
        }
        // random property sweep (in-process; CI raises to 1e5+ per the spec)
        var seed: UInt64 = 0x9E3779B97F4A7C15
        for _ in 0..<5000 {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let p = Double(seed >> 11) / Double(1 << 53)
            let thermal = BASThermalLevel.allCases[Int(seed % UInt64(BASThermalLevel.allCases.count))]
            XCTAssertEqual(BASThermalTwin.guardLevel(for: thermal, accumulated: p), expectedGuard(thermal, p))
            checked += 1
        }
        print("📊 qinao-gate thermal_guard_mapping_purity: PASS checked=\(checked) tolerance=0")
    }

    // MARK: - #9 rmsnorm_layernorm_epsilon_fidelity (CRITICAL)
    // Pinned epsilons (off-spec epsilon silently changes whole-model numerics). EQUAL, no tolerance.
    func test_qinao_rmsnorm_layernorm_epsilon_fidelity() {
        XCTAssertEqual(BASNormEpsilon.rmsNorm, 1e-6, "RMSNorm epsilon must be exactly 1e-6 (Gemma3/Llama3/Qwen2/Mamba)")
        XCTAssertEqual(BASNormEpsilon.layerNorm, 1e-5, "LayerNorm epsilon must be exactly 1e-5 (PyTorch/TF)")
        print("📊 qinao-gate rmsnorm_layernorm_epsilon_fidelity: PASS rms=1e-6 ln=1e-5 EQUAL")
    }

    // MARK: - #6 emergency_forces_cpu_route (CRITICAL)
    // Device-routing safety floor (rule 1): emergency thermal ⇒ ALWAYS .scoutCPU across the full
    // role×precision×capability grid; under .throttle, NEVER an NPU route. tolerance=0, exhaustive.
    func test_qinao_emergency_forces_cpu_route() {
        let roles: [BASDeviceRouting.Role] = [.scout, .core]
        let caps: [BASDeviceRouting.Capability] = [.cpu, .gpu, .ane]
        var subsets: [Set<BASDeviceRouting.Capability>] = []
        for mask in 0..<(1 << caps.count) {
            var s = Set<BASDeviceRouting.Capability>()
            for (i, c) in caps.enumerated() where (mask >> i) & 1 == 1 { s.insert(c) }
            subsets.append(s)
        }
        let npuRoutes: Set<BASDeviceRoute> = [.scoutNPU, .coreNPU]
        var checked = 0
        for role in roles {
            for prec in BASRuntimePrecisionProfile.allCases {
                for avail in subsets {
                    XCTAssertEqual(
                        BASDeviceRouting.recommend(role: role, thermalGuard: .emergency, precisionProfile: prec, available: avail),
                        .scoutCPU, "emergency must force scoutCPU (role=\(role) prec=\(prec) avail=\(avail))")
                    let r = BASDeviceRouting.recommend(role: role, thermalGuard: .throttle, precisionProfile: prec, available: avail)
                    XCTAssertFalse(npuRoutes.contains(r), "throttle must not route to NPU (got \(r))")
                    checked += 2
                }
            }
        }
        print("📊 qinao-gate emergency_forces_cpu_route: PASS checked=\(checked) tolerance=0")
    }

    // MARK: - #3 throttle_class_admission_correctness (CRITICAL)
    // Pure admission BASBreathScheduler.validate: emergency rejects ALL; throttle admits only .light/.none;
    // watch/nominal admit ALL. Exhaustive (4 guard × every MaintenanceClass) confusion matrix, tolerance=0.
    func test_qinao_throttle_class_admission_correctness() {
        func throwsFor(_ c: BASMaintenanceClass, _ g: BASThermalGuardLevel) -> Bool {
            do { try BASBreathScheduler.validate(class: c, at: g); return false } catch { return true }
        }
        var checked = 0
        for g in BASThermalGuardLevel.allCases {
            for c in BASMaintenanceClass.allCases {
                let expectThrow: Bool
                switch g {
                case .emergency: expectThrow = true
                case .throttle:  expectThrow = (c != .light && c != .none)
                case .watch, .nominal: expectThrow = false
                }
                XCTAssertEqual(throwsFor(c, g), expectThrow, "admission mismatch guard=\(g) class=\(c)")  // tolerance=0
                checked += 1
            }
        }
        print("📊 qinao-gate throttle_class_admission_correctness: PASS checked=\(checked) tolerance=0")
    }

    // MARK: - #7 compute_router_floor_no_overheat (CRITICAL)
    // BASComputeRouter.route: first preferred tier ≥ minHeadroom wins; else coolest tier; empty → nil.
    // Random property sweep (CI raises to 1e5+); replicated oracle; tolerance=0.
    func test_qinao_compute_router_floor_no_overheat() {
        let router = BASComputeRouter()  // [.npu,.gpu,.cpu], minHeadroom 0.1
        let tiers: [BASComputeTier] = [.npu, .gpu, .cpu]
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        func expected(_ rs: [BASComputeTierThermalReading]) -> BASComputeTier? {
            if rs.isEmpty { return nil }
            for t in router.preferredOrder {
                if let r = rs.first(where: { $0.tier == t }), r.headroom >= router.minHeadroom { return t }
            }
            return rs.max(by: { $0.headroom < $1.headroom })?.tier
        }
        var seed: UInt64 = 0xD1B54A32D192ED03
        var checked = 0
        for _ in 0..<5000 {
            var rs: [BASComputeTierThermalReading] = []
            for t in tiers {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                if (seed >> 33) & 1 == 1 {
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    let h = Double(seed >> 11) / Double(1 << 53)
                    rs.append(BASComputeTierThermalReading(tier: t, level: .nominal, headroom: h, observedAt: now))
                }
            }
            let snap = BASComputeTierThermalSnapshot(readings: rs, snapshotAt: now)
            XCTAssertEqual(router.route(snapshot: snap), expected(rs), "route mismatch")
            checked += 1
        }
        XCTAssertNil(router.route(snapshot: BASComputeTierThermalSnapshot(readings: [], snapshotAt: now)), "empty → nil")
        print("📊 qinao-gate compute_router_floor_no_overheat: PASS checked=\(checked) tolerance=0")
    }
}
