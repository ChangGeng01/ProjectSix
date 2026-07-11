import XCTest
@testable import BASLeaseLife
@testable import BASMLXAdapter
@testable import BASRuntimeCore
import CryptoKit
import Foundation

/// QINAO Substrate-100 gates — Phase-2 batch 10 (HIGH: coordinator/MLX-mem/decode-stall/calibration/routing).
final class BASQINAOSubstrateGatesBatch10Tests: XCTestCase {

    func test_qinao_coordinator_turn_ordering_invariant() async {
    // Fixed clock at epoch 0 → lung never decays on its first turn
    // (no prior anchor), so the recorded pressure is exact and the
    // whole turn is deterministic.
    let epoch0: @Sendable () -> Date = { Date(timeIntervalSince1970: 0) }

    // Local pure oracle mirroring BASThermalTwin.guardLevel(for:accumulated:).
    func oracleGuard(
        _ thermal: BASThermalLevel, _ p: Double
    ) -> BASThermalGuardLevel {
        let c = min(1, max(0, p))
        switch thermal {
        case .nominal:  return c >= 0.7 ? .watch : .nominal
        case .warm:     return c < 0.3 ? .watch : .throttle
        case .hot:      return c >= 0.7 ? .emergency : .throttle
        case .critical: return .emergency
        }
    }

    func makeCoord() -> BASLeaseLifeCoordinator {
        BASLeaseLifeCoordinator(
            lung: BASLungStateAccumulator(
                timeConstantSeconds: 180, clock: epoch0),
            // .fair → thermalLevel .warm (stable across the turn).
            thermal: BASThermalTwin(reader: { .fair }, clock: epoch0),
            scheduler: BASBreathScheduler(clock: epoch0))
    }

    let coord = makeCoord()

    // Seed two breaths while the guard is benign. Pre-turn the twin
    // has accumulatedPressure 0 and nil currentReading → scheduleBreath
    // samples (.warm, p<0.3) → .watch, which accepts BOTH classes.
    _ = try? await coord.scheduleBreath(
        BASBreathScheduler.Request(
            id: "standard-1",
            maintenanceClass: .standard,
            earliestFireAt: Date(timeIntervalSince1970: 600)))
    _ = try? await coord.scheduleBreath(
        BASBreathScheduler.Request(
            id: "light-1",
            maintenanceClass: .light,
            earliestFireAt: Date(timeIntervalSince1970: 120)))

    // One turn of deepLoop for 3s → fresh load 0.15*3 = 0.45 pressure,
    // which is ≥0.3 so on .warm the NEW guard is .throttle. .throttle
    // reconcile drops .standard but keeps .light — but ONLY if the
    // scheduler reconciled with THIS turn's guard.
    let result = await coord.recordTurn(
        runMode: .deepLoop, durationSeconds: 3)

    // (1) LUNG DECAYS/ACCUMULATES FIRST. No prior anchor on turn 1, so
    // pressure is the exact fresh contribution and crosses the 0.3 band.
    let expectedPressure = BASLungStateAccumulator.load(for: .deepLoop) * 3
    XCTAssertEqual(result.lung.pressure, expectedPressure, accuracy: 0,
        "turn-1 lung pressure must be the exact fresh load (no decay)")
    XCTAssertGreaterThanOrEqual(result.lung.pressure, 0.3,
        "scenario requires pressure to cross the .warm→.throttle band")
    XCTAssertEqual(result.lung.turnCount, 1)

    // (2) TWIN READS THE LUNG'S PRESSURE SECOND. The twin's reading
    // carries EXACTLY the pressure the lung just recorded — tolerance 0.
    // If the twin had been read BEFORE the lung recorded, it would carry
    // the stale 0.0. Identical Double ⇒ exact ==.
    XCTAssertEqual(
        result.thermal.accumulatedPressure, result.lung.pressure,
        accuracy: 0,
        "twin must read the lung's freshly-recorded pressure (lung-before-twin)")
    XCTAssertEqual(result.thermal.thermalLevel, .warm)

    // (3) THE NEW GUARD IS COMPUTED FROM THE NEW PRESSURE. Equals the
    // pure oracle over (warm, fresh pressure) — and that is .throttle.
    let expectedGuard = oracleGuard(.warm, result.lung.pressure)
    XCTAssertEqual(result.thermal.guardLevel, expectedGuard, "tolerance=0 guard derivation")
    XCTAssertEqual(result.thermal.guardLevel, .throttle,
        "fresh 0.45 pressure on .warm must yield .throttle")

    // (4) THE SCHEDULER RECONCILES ONLY AFTER THE NEW GUARD. The cancelled
    // set is EXACTLY what reconcile(.throttle) drops: .standard goes,
    // .light stays. A stale-guard reconcile (.watch) would cancel NOTHING,
    // so this set is a direct witness that reconcile ran on the NEW guard.
    XCTAssertEqual(result.cancelledBreathIDs, ["standard-1"],
        "reconcile must use the post-pressure guard → drops standard, keeps light")
    let survivorBreaths = await coord.schedulerActor().scheduledBreaths()
    let survivors = Set(survivorBreaths.map(\.request.id))
    XCTAssertEqual(survivors, ["light-1"],
        "only the .light breath survives a .throttle reconcile")

    // DETERMINISM — an identical fresh coordinator yields a byte-equal
    // TurnRecorded over the same ordered turn.
    let coord2 = makeCoord()
    _ = try? await coord2.scheduleBreath(
        BASBreathScheduler.Request(
            id: "standard-1", maintenanceClass: .standard,
            earliestFireAt: Date(timeIntervalSince1970: 600)))
    _ = try? await coord2.scheduleBreath(
        BASBreathScheduler.Request(
            id: "light-1", maintenanceClass: .light,
            earliestFireAt: Date(timeIntervalSince1970: 120)))
    let result2 = await coord2.recordTurn(
        runMode: .deepLoop, durationSeconds: 3)
    XCTAssertEqual(result, result2,
        "ordered turn must be deterministic (TurnRecorded is Equatable)")

    // SAFETY MUTATION — escalate the OS thermal state to .critical BETWEEN
    // scheduling and the next turn, then assert the ordering holds at the
    // emergency band: the twin reads .critical → .emergency AFTER the lung
    // settles, and reconcile(.emergency) cancels EVERYTHING — but ONLY if
    // reconcile ran on the post-escalation guard.
    final class QINAOOSStateBox: @unchecked Sendable {
        private let lock = NSLock()
        private var value: BASThermalTwin.OSThermalState
        init(_ v: BASThermalTwin.OSThermalState) { value = v }
        func set(_ v: BASThermalTwin.OSThermalState) {
            lock.lock(); value = v; lock.unlock()
        }
        func get() -> BASThermalTwin.OSThermalState {
            lock.lock(); defer { lock.unlock() }; return value
        }
    }
    let osBox = QINAOOSStateBox(.nominal)
    let hotCoord = BASLeaseLifeCoordinator(
        lung: BASLungStateAccumulator(
            timeConstantSeconds: 180, clock: epoch0),
        thermal: BASThermalTwin(reader: { osBox.get() }, clock: epoch0),
        scheduler: BASBreathScheduler(clock: epoch0))
    // Schedule while nominal (guard .nominal accepts .light).
    _ = try? await hotCoord.scheduleBreath(
        BASBreathScheduler.Request(
            id: "x", maintenanceClass: .light,
            earliestFireAt: Date(timeIntervalSince1970: 50)))
    let hotCountBefore = await hotCoord.schedulerActor().count()
    XCTAssertEqual(hotCountBefore, 1, "light breath scheduled while nominal")
    // MUTATE the OS state, then drive a turn.
    osBox.set(.critical)
    let hot = await hotCoord.recordTurn(runMode: .engage, durationSeconds: 1)
    XCTAssertEqual(hot.thermal.guardLevel, .emergency)
    let hotCountAfter = await hotCoord.schedulerActor().count()
    XCTAssertEqual(hotCountAfter, 0,
        "emergency reconcile (post-guard) cancels every breath")

    print("QINAO-GATE coordinator_turn_ordering_invariant: PASS "
        + "(lung→twin→reconcile order witnessed: p=\(result.lung.pressure) "
        + "guard=\(result.thermal.guardLevel.rawValue) "
        + "cancelled=\(result.cancelledBreathIDs))")
}

    /// QINAO #11 HIGH — mlx_cache_pool_ceiling. On `loadModel` the MLX idle free-buffer pool is bounded by the
    /// configured `cacheLimitBytes` (default 512 MB, `BASMLXMemoryModel.defaultCacheLimitBytes`) routed through the
    /// `MLXRuntimeConfig` seam. Asserts (tolerance=0) that the configured ceiling is APPLIED verbatim on the
    /// single-model path and CLAMPED up to the dual-residency floor on the speculative path — exactly the chain
    /// `MLXOrganAdapter.loadModel` executes (BASMLXMemoryBudget.resolve → MLXRuntimeConfig.applyCacheLimit).
    /// Host-side, MLX-free: the real `MLX.Memory.cacheLimit =` side effect is injected as a recording sink (the
    /// doc-mandated pattern; touching MLX.Memory on the macOS host forces a metallib load that aborts).
    func test_qinao_mlx_cache_pool_ceiling() {
        // Recording box for the runtime sink — final class @unchecked Sendable (mirrors MLXRuntimeConfigTests).
        final class QINAOCacheRecorder: @unchecked Sendable {
            private let lock = NSLock()
            private(set) var sinks: [Int] = []
            private(set) var logs: [String] = []
            func sink(_ b: Int) { lock.lock(); sinks.append(b); lock.unlock() }
            func log(_ s: String) { lock.lock(); logs.append(s); lock.unlock() }
        }
        let mib = 1024 * 1024

        // 1) The canonical configured ceiling is EXACTLY the documented 512 MB (single source of truth).
        let defaultCeiling = BASMLXMemoryModel.defaultCacheLimitBytes
        XCTAssertEqual(defaultCeiling, 512 * mib, "configured cache-pool ceiling must be exactly 512 MB")

        // 2) The default memory policy carries that ceiling verbatim (byte-equal-off init default).
        let policy = MLXMemoryPolicy()
        XCTAssertEqual(policy.cacheLimitBytes, defaultCeiling,
                       "MLXMemoryPolicy() default cacheLimitBytes must equal the 512 MB canonical ceiling")

        // 3) SINGLE-MODEL load path: resolve passes the configured ceiling through UNCHANGED (no draft).
        let single = BASMLXMemoryBudget.resolve(
            targetProviderID: "llama3_2.3b",
            draftProviderID: nil,
            singleCacheLimitBytes: policy.cacheLimitBytes,
            singleMemoryLimitBytes: policy.memoryLimitBytes)
        XCTAssertFalse(single.isSpeculativeUnion, "no draft ⇒ single-model budget")
        XCTAssertEqual(single.cacheLimitBytes, defaultCeiling,
                       "single-model budget must carry the configured 512 MB ceiling verbatim")

        // 4) Apply that ceiling through the REAL seam (the exact call MLXOrganAdapter.loadModel makes). The
        //    configured ceiling must reach the runtime sink, in force, with no clamping on the single path.
        let rec = QINAOCacheRecorder()
        let cfg = MLXRuntimeConfig(sink: { rec.sink($0) }, logger: { rec.log($0) })
        guard let singleCache = single.cacheLimitBytes else {
            return XCTFail("single-model budget must define a cache ceiling")
        }
        let applied = cfg.applyCacheLimit(bytes: singleCache, precedence: .adapterDefault)
        XCTAssertEqual(applied, .applied(bytes: defaultCeiling))
        XCTAssertEqual(cfg.currentCacheLimitBytes, defaultCeiling, "the 512 MB ceiling must be in force on the runtime")
        XCTAssertEqual(rec.sinks, [defaultCeiling], "exactly the configured ceiling reached the real cacheLimit sink")
        XCTAssertTrue(rec.logs.isEmpty, "first default apply is not a conflict — no diagnostic")

        // 5) The pool is BOUNDED, not unbounded: a SECOND conflicting adapter-default is REJECTED (first wins) so
        //    the in-force ceiling can never be quietly lifted out from under the load (process-global hazard).
        let conflict = cfg.applyCacheLimit(bytes: 4096 * mib, precedence: .adapterDefault)
        XCTAssertEqual(conflict, .rejectedConflict(kept: defaultCeiling, ignored: 4096 * mib))
        XCTAssertEqual(cfg.currentCacheLimitBytes, defaultCeiling, "the configured ceiling must HOLD against a conflict")
        XCTAssertEqual(rec.sinks, [defaultCeiling], "the rejected larger ceiling must NOT reach the runtime")

        // 6) Deterministic re-resolve: pure function ⇒ identical budget on a re-call (no hidden state).
        let single2 = BASMLXMemoryBudget.resolve(
            targetProviderID: "llama3_2.3b",
            draftProviderID: nil,
            singleCacheLimitBytes: policy.cacheLimitBytes,
            singleMemoryLimitBytes: policy.memoryLimitBytes)
        XCTAssertEqual(single, single2, "resolve must be deterministic for the same inputs")

        // 7) CLAMP path: with a co-resident draft the ceiling is lifted to AT LEAST the dual-residency floor
        //    (768 MB) and never below the configured single default — a CEILING that is never worse than unbounded.
        let dualFloor = BASMLXMemoryModel.dualResidencyCacheFloorBytes
        XCTAssertEqual(dualFloor, 768 * mib, "dual-residency cache floor must be exactly 768 MB")
        let union = BASMLXMemoryBudget.resolve(
            targetProviderID: "llama3_2.3b",
            draftProviderID: "llama3_2.1b",
            singleCacheLimitBytes: policy.cacheLimitBytes,
            singleMemoryLimitBytes: policy.memoryLimitBytes)
        XCTAssertTrue(union.isSpeculativeUnion, "a configured draft ⇒ speculative union budget")
        let expectedUnion = max(defaultCeiling, dualFloor)
        XCTAssertEqual(union.cacheLimitBytes, expectedUnion,
                       "union ceiling = max(configured 512 MB, 768 MB floor) = 768 MB (clamped UP, never down)")
        guard let unionCache = union.cacheLimitBytes else {
            return XCTFail("union budget must define a cache ceiling")
        }
        XCTAssertGreaterThanOrEqual(unionCache, defaultCeiling, "the clamped ceiling is never below the single default")

        // 8) The union must WIN over an in-force single default (explicit override, last-write-wins) — proving the
        //    clamped ceiling is actually applied to the bounded pool, not silently dropped.
        let overrode = cfg.applyCacheLimit(bytes: unionCache, precedence: .explicitOverride)
        XCTAssertEqual(overrode, .overrodeConflict(from: defaultCeiling, to: expectedUnion))
        XCTAssertEqual(cfg.currentCacheLimitBytes, expectedUnion, "the clamped union ceiling must now be in force")
        XCTAssertEqual(rec.sinks, [defaultCeiling, expectedUnion], "override reached the runtime; the rejected one never did")

        print("QINAO-GATE mlx_cache_pool_ceiling: PASS "
            + "(configured=\(defaultCeiling / mib)MB applied verbatim single-model; "
            + "clamped UP to \(expectedUnion / mib)MB dual-residency floor; "
            + "bounded pool holds against conflict, override wins, deterministic)")
    }

    func test_qinao_mlx_preload_memory_admission() {
    // QINAO #12 HIGH: when enforceMemoryAdmission is ON, the pre-load admission gate REJECTS a load whose
    // (estimated PEAK footprint + safety margin) crosses the device ActiveHard budget, and ACCEPTS one within.
    // The pure, framework-free source of truth for that decision is
    // BASMLXMemoryBudget.wouldExceedActiveHardCap(targetProviderID:capBytes:safetyMarginBytes:)
    //   -> returns TRUE (=REJECT) iff estimatedPeakFootprintBytes(id) != nil && peak + margin > cap
    //   -> returns FALSE (=ACCEPT) when within the cap OR when the peak estimate is nil (admit-by-default).
    // MLXOrganAdapter.loadModel consults exactly this when enforceMemoryAdmission is set
    // (Sources/BASMLXAdapter/MLXOrganAdapter.swift:561-569), so asserting the gate host-side IS the metric.
    let mib = 1024 * 1024

    // Local replicated oracle: the EXACT admission rule, independent of the SUT implementation.
    let oracleRejects: (Int?, Int, Int) -> Bool = { peak, cap, margin in
        guard let peak else { return false }   // nil estimate => admit by default (亏的不要)
        return peak + margin > cap
    }

    // The measured / derived peak table the gate reads (mirrors BASMLXMemoryBudgetTests verbatim).
    // (providerID, expectedPeakBytes-or-nil)
    let cases: [(id: String, peak: Int?)] = [
        ("mlx.gemma4.e4b.it.4bit", 4_314 * mib),  // DERIVED — jetsam'd twice at load
        ("mlx.gemma4.e2b.it.4bit", 3_114 * mib),  // MEASURED survivor (261 MB headroom)
        ("mlx.llama3_2.3b.it.4bit", 2_969 * mib), // MEASURED survivor (10h @ 38.3 tok/s)
        ("mlx.unknown.model",       nil),         // no basis => admit-by-default
    ]

    // 0) The peak-footprint table the gate consults must be EXACTLY as measured (tolerance = 0).
    for c in cases {
        XCTAssertEqual(
            BASMLXMemoryBudget.estimatedPeakFootprintBytes(forProviderID: c.id), c.peak,
            "peak-footprint estimate for \(c.id) must match the measured/derived table exactly")
    }

    let defaultCap = BASMLXMemoryBudget.measurediPhoneAirActiveHardCapBytes // ~3376 MB iPhone Air
    XCTAssertEqual(defaultCap, 3_376 * mib, "default ActiveHard cap is the measured iPhone Air jetsam ceiling")
    let defaultMargin = 128 * mib // documented default safetyMarginBytes (below E2B's 261 MB survival headroom)

    // 1) DEFAULT (constrained) cap + DEFAULT margin: gate decision must equal the oracle for every case.
    // tests-arch ④ device-robust (2026-07-11): pass `defaultCap` EXPLICITLY. The no-arg gate default
    // now resolves to the entitlement-aware LIVE cap (缝7), so on the real entitled iPhone Air the
    // default is ~6.29 GB, not the measured constrained 3376 MB the oracle uses — pin the constrained
    // admission LOGIC deterministically instead of the device-specific live default.
    for c in cases {
        let rejects = BASMLXMemoryBudget.wouldExceedActiveHardCap(targetProviderID: c.id, capBytes: defaultCap)
        let expected = oracleRejects(c.peak, defaultCap, defaultMargin)
        XCTAssertEqual(rejects, expected,
            "admission decision for \(c.id) must equal the oracle (reject=\(expected)) under the constrained cap")
        // Determinism: a re-call returns the identical decision (pure function, no hidden state).
        XCTAssertEqual(BASMLXMemoryBudget.wouldExceedActiveHardCap(targetProviderID: c.id, capBytes: defaultCap), rejects,
            "admission gate must be deterministic for \(c.id)")
    }

    // Pin the concrete raised bar at the default cap: ONLY E4B is refused; the two measured survivors + the
    // unmeasured entry are admitted (this is the production behaviour the metric protects).
    XCTAssertTrue(BASMLXMemoryBudget.wouldExceedActiveHardCap(targetProviderID: "mlx.gemma4.e4b.it.4bit", capBytes: BASMLXMemoryBudget.measurediPhoneAirActiveHardCapBytes),
        "E4B (4314+128 > 3376 MB) REJECTS")
    XCTAssertFalse(BASMLXMemoryBudget.wouldExceedActiveHardCap(targetProviderID: "mlx.gemma4.e2b.it.4bit", capBytes: BASMLXMemoryBudget.measurediPhoneAirActiveHardCapBytes),
        "E2B (3114+128 <= 3376 MB) ACCEPTS")
    XCTAssertFalse(BASMLXMemoryBudget.wouldExceedActiveHardCap(targetProviderID: "mlx.llama3_2.3b.it.4bit", capBytes: BASMLXMemoryBudget.measurediPhoneAirActiveHardCapBytes),
        "Llama-3B (2969+128 <= 3376 MB) ACCEPTS")
    XCTAssertFalse(BASMLXMemoryBudget.wouldExceedActiveHardCap(targetProviderID: "mlx.unknown.model", capBytes: BASMLXMemoryBudget.measurediPhoneAirActiveHardCapBytes),
        "unmeasured peak => ACCEPT (admit-by-default)")

    // 2) Cross-product sweep over caps x margins x the measured/derived models: the gate must agree with the
    //    oracle on EVERY combination — this exhaustively proves "reject iff peak+margin > cap".
    let caps = [0, 1_000 * mib, 3_114 * mib, 3_376 * mib, 4_314 * mib, 8_000 * mib]
    let margins = [0, 1, 128 * mib, 512 * mib]
    for c in cases where c.peak != nil {
        for cap in caps {
            for margin in margins {
                let rejects = BASMLXMemoryBudget.wouldExceedActiveHardCap(
                    targetProviderID: c.id, capBytes: cap, safetyMarginBytes: margin)
                XCTAssertEqual(rejects, oracleRejects(c.peak, cap, margin),
                    "gate(\(c.id), cap=\(cap), margin=\(margin)) must equal peak+margin>cap")
            }
        }
    }

    // 3) BOUNDARY (tolerance = 0): with margin 0, peak == cap ACCEPTS (not strictly greater); peak == cap+1
    //    REJECTS. Proves the comparison is a strict '>' exactly at the device budget edge.
    let e2bPeak = 3_114 * mib
    XCTAssertFalse(
        BASMLXMemoryBudget.wouldExceedActiveHardCap(
            targetProviderID: "mlx.gemma4.e2b.it.4bit", capBytes: e2bPeak, safetyMarginBytes: 0),
        "peak == cap (margin 0) is WITHIN budget => ACCEPT")
    XCTAssertTrue(
        BASMLXMemoryBudget.wouldExceedActiveHardCap(
            targetProviderID: "mlx.gemma4.e2b.it.4bit", capBytes: e2bPeak - 1, safetyMarginBytes: 0),
        "peak == cap+1 (margin 0) EXCEEDS budget => REJECT")

    // 4) MONOTONICITY / mutate-and-assert: a model REJECTED at the default cap must FLIP to ACCEPT once the cap
    //    is lifted above peak+margin (the larger-RAM host case). Mutating the budget upward must relax, never
    //    tighten, the decision.
    let e4b = "mlx.gemma4.e4b.it.4bit"
    XCTAssertTrue(BASMLXMemoryBudget.wouldExceedActiveHardCap(targetProviderID: e4b),
        "E4B refused under the iPhone Air cap")
    XCTAssertFalse(
        BASMLXMemoryBudget.wouldExceedActiveHardCap(targetProviderID: e4b, capBytes: 8_000 * mib),
        "lifting the cap to 8 GB ADMITS E4B (4314 MB) — the gate relaxes as budget grows")

    // 5) The adapter actually wires this opt-in (config-level invariant): enforceMemoryAdmission ON is reflected
    //    on the constructed adapter; OFF is the byte-equal default. Mirrors MLXMemoryPolicyTests construction.
    let off = MLXOrganAdapter()
    XCTAssertFalse(off.enforceMemoryAdmission, "default adapter is warn-only (byte-equal-off)")
    let on = MLXOrganAdapter(enforceMemoryAdmission: true, activeHardCapBytes: 8_000 * mib)
    XCTAssertTrue(on.enforceMemoryAdmission, "opt-in admission flag is honoured on the adapter")
    XCTAssertEqual(on.activeHardCapBytes, 8_000 * mib, "host-supplied ActiveHard cap is honoured on the adapter")

    print("QINAO-GATE mlx_preload_memory_admission: PASS — admission rejects iff peak+margin>cap "
        + "(E4B 4314+128>3376 REJECT; E2B/Llama-3B survivors + unmeasured ACCEPT; strict-'>' boundary; "
        + "cap-lift relaxes; \(caps.count)x\(margins.count) cap/margin sweep vs replicated oracle; "
        + "adapter opt-in wired)")
}

    func test_qinao_mlx_runtime_config_conflict_safety() {
    // QINAO #13 HIGH: every write to the process-global MLX.Memory.cacheLimit/.memoryLimit goes through the
    // UNIQUE MLXRuntimeConfig seam; a conflicting adapter-default write is REJECTED (first-default-wins) and
    // NEVER reaches the runtime, while an explicit override wins — all serialized under one lock.
    // Mirrors MLXRuntimeConfigTests: inject recording sinks (touching MLX.Memory on the macOS host aborts).

    // --- local recorder box (final class @unchecked Sendable; no captured-var mutation in closures) ---
    final class QINAORecorder: @unchecked Sendable {
        private let lock = NSLock()
        private(set) var sinks: [Int] = []
        private(set) var logs: [String] = []
        func sink(_ b: Int) { lock.lock(); sinks.append(b); lock.unlock() }
        func log(_ s: String) { lock.lock(); logs.append(s); lock.unlock() }
        var sinkCount: Int { lock.lock(); defer { lock.unlock() }; return sinks.count }
    }

    // ============================================================================================
    // PART A — cacheLimit conflict policy (one seam, exhaustive over the 4 ApplyResult outcomes).
    // ============================================================================================
    let cacheRec = QINAORecorder()
    let cfg = MLXRuntimeConfig(sink: { cacheRec.sink($0) }, logger: { cacheRec.log($0) })

    // (1) first write APPLIES + reaches the runtime exactly once, no diagnostic.
    let first = cfg.applyCacheLimit(bytes: 512, precedence: .adapterDefault)
    XCTAssertEqual(first, .applied(bytes: 512))
    XCTAssertEqual(cfg.currentCacheLimitBytes, 512)
    XCTAssertEqual(cacheRec.sinks, [512])
    XCTAssertTrue(cacheRec.logs.isEmpty, "first apply is not a conflict")

    // (2) idempotent re-apply of the SAME value is a no-op (must NOT re-hit the runtime).
    let same = cfg.applyCacheLimit(bytes: 512, precedence: .adapterDefault)
    XCTAssertEqual(same, .unchanged(bytes: 512))
    XCTAssertEqual(cacheRec.sinks, [512], "same value must not re-touch the global")

    // (3) CONFLICTING adapter default is REJECTED (first wins) + logged + NEVER reaches the runtime.
    let conflict = cfg.applyCacheLimit(bytes: 768, precedence: .adapterDefault)
    XCTAssertEqual(conflict, .rejectedConflict(kept: 512, ignored: 768))
    XCTAssertEqual(cfg.currentCacheLimitBytes, 512, "first default must win")
    XCTAssertEqual(cacheRec.sinks, [512], "the rejected default must NOT write the process-global")
    XCTAssertEqual(cacheRec.logs.count, 1, "a conflict must be logged, never silent")
    XCTAssertTrue(cacheRec.logs[0].contains("CONFLICT"))
    XCTAssertTrue(cacheRec.logs[0].contains("cacheLimit"))

    // (4) EXPLICIT override WINS (last write) + reaches the runtime + logged.
    let override = cfg.applyCacheLimit(bytes: 384, precedence: .explicitOverride)
    XCTAssertEqual(override, .overrodeConflict(from: 512, to: 384))
    XCTAssertEqual(cfg.currentCacheLimitBytes, 384, "explicit override must win")
    XCTAssertEqual(cacheRec.sinks, [512, 384], "the override must reach the runtime")
    XCTAssertTrue(cacheRec.logs.last!.contains("OVERRIDE"))

    // (5) after an override, a later DIFFERING adapter default is STILL rejected (override holds).
    let afterOverride = cfg.applyCacheLimit(bytes: 512, precedence: .adapterDefault)
    XCTAssertEqual(afterOverride, .rejectedConflict(kept: 384, ignored: 512))
    XCTAssertEqual(cacheRec.sinks, [512, 384], "no further runtime writes after the override")

    // ============================================================================================
    // PART B — memoryLimit is an INDEPENDENT process-global with the SAME policy, NO cross-talk.
    // ============================================================================================
    let cacheRec2 = QINAORecorder()
    let memRec = QINAORecorder()
    let cfg2 = MLXRuntimeConfig(
        sink: { cacheRec2.sink($0) }, memorySink: { memRec.sink($0) }, logger: { _ in })

    XCTAssertEqual(cfg2.applyMemoryLimit(bytes: 2048, precedence: .adapterDefault), .applied(bytes: 2048))
    // conflicting memory adapter-default rejected; the rejected value never reaches the memory sink.
    XCTAssertEqual(cfg2.applyMemoryLimit(bytes: 4096, precedence: .adapterDefault),
                   .rejectedConflict(kept: 2048, ignored: 4096))
    // independent cache write coexists without disturbing memory.
    XCTAssertEqual(cfg2.applyCacheLimit(bytes: 512, precedence: .adapterDefault), .applied(bytes: 512))
    XCTAssertEqual(cfg2.currentMemoryLimitBytes, 2048, "first memory default must win")
    XCTAssertEqual(cfg2.currentCacheLimitBytes, 512)
    XCTAssertEqual(memRec.sinks, [2048], "memory sink saw only its value; rejected 4096 never wrote")
    XCTAssertEqual(cacheRec2.sinks, [512], "cache sink saw only its value (no cross-talk)")

    // ============================================================================================
    // PART C — SERIALIZATION under concurrent contention: only ONE distinct value ever wins, the
    // rest are all rejected, and the global is written EXACTLY once. (Proves the seam serializes.)
    // ============================================================================================
    let raceRec = QINAORecorder()
    let cfg3 = MLXRuntimeConfig(sink: { raceRec.sink($0) }, logger: { _ in })
    let candidates = (1...64).map { $0 * 1024 }   // 64 distinct adapter defaults race for the one global
    DispatchQueue.concurrentPerform(iterations: candidates.count) { i in
        cfg3.applyCacheLimit(bytes: candidates[i], precedence: .adapterDefault)
    }
    XCTAssertEqual(raceRec.sinkCount, 1, "under contention the process-global is written EXACTLY once")
    let winner = cfg3.currentCacheLimitBytes
    XCTAssertNotNil(winner)
    XCTAssertEqual(raceRec.sinks.first, winner, "the single runtime write equals the in-force value")
    XCTAssertTrue(candidates.contains(winner!), "the winner is one of the contenders (no torn value)")
    // determinism: re-applying the SAME winning value is a stable no-op (no further global writes).
    XCTAssertEqual(cfg3.applyCacheLimit(bytes: winner!, precedence: .adapterDefault), .unchanged(bytes: winner!))
    XCTAssertEqual(raceRec.sinkCount, 1, "re-affirming the winner must not re-write the global")

    // ============================================================================================
    // PART D — the UNIQUE owner exists: the production singleton seam is reachable (its sinks are the
    // real gated MLX.Memory.* writers — not invoked here, so no metallib load).
    // ============================================================================================
    XCTAssertNotNil(MLXRuntimeConfig.shared)
    XCTAssertTrue(MLXRuntimeConfig.shared === MLXRuntimeConfig.shared, "one process-global owner")

    print("QINAO-GATE mlx_runtime_config_conflict_safety: PASS "
        + "(cache: applied/unchanged/rejected/overrode all exact; rejected default never wrote the global; "
        + "memory independent same-policy no cross-talk; 64-way race serialized to exactly 1 write winner=\(winner!); "
        + "unique singleton owner present)")
}

    func test_qinao_decode_stall_wedge_detection() async {
    // Mutable fake clock + verdict collector — mirrors the existing
    // BASDecodeLivenessMonitorTests.Harness verbatim (lock-guarded
    // because onStall/clock are @Sendable). Nested type gets a unique
    // QINAO-prefixed name per the hard rule.
    final class QINAOStallHarness: @unchecked Sendable {
        private let lock = NSLock()
        private var nowNs: UInt64 = 1_000_000_000
        private var verdictsStore: [BASDecodeStallVerdict] = []
        func setNow(seconds: Double) {
            lock.lock(); defer { lock.unlock() }
            nowNs = UInt64(seconds * 1_000_000_000)
        }
        func now() -> UInt64 {
            lock.lock(); defer { lock.unlock() }
            return nowNs
        }
        func record(_ v: BASDecodeStallVerdict) {
            lock.lock(); defer { lock.unlock() }
            verdictsStore.append(v)
        }
        var verdicts: [BASDecodeStallVerdict] {
            lock.lock(); defer { lock.unlock() }
            return verdictsStore
        }
        func clearVerdicts() {
            lock.lock(); defer { lock.unlock() }
            verdictsStore.removeAll()
        }
    }

    // Monitor factory mirrors makeMonitor(...) from the existing test:
    // ALL four init args (stallThresholdSec, gpuProbe, clock, onStall).
    let threshold: Double = 30
    func makeMonitor(_ h: QINAOStallHarness) -> BASDecodeLivenessMonitor {
        BASDecodeLivenessMonitor(
            stallThresholdSec: threshold,
            gpuProbe: nil,
            clock: { h.now() },
            onStall: { h.record($0) })
    }

    // The contract under test (source line 139):
    //   guard elapsedSec >= stallThresholdSec else { return nil }
    // => fires iff (now - lastProgress) >= threshold, and NOT before.
    // The clock is set so that beginTurn() stamps lastProgress at t=0s
    // (nowNs = 1e9 == 1.0s mapped via setNow); we then set absolute
    // elapsed and check. Because beginTurn reads clock() AT begin, we
    // drive elapsed by setting now = beginAbs + gap.

    // Exhaustive boundary sweep over a fine grid straddling the exact
    // threshold. Each gap gets a FRESH monitor+turn so episodes never
    // interfere (one verdict per episode is a separate invariant).
    // Oracle is the raw source predicate: gap >= threshold.
    let gaps: [Double] = [
        0, 1, 5, 15, 29,
        29.9, 29.99, 29.999,
        30.0,                      // exact boundary — MUST fire (>=)
        30.001, 30.01, 30.1,
        31, 45, 60, 600
    ]

    for gap in gaps {
        let h = QINAOStallHarness()
        let m = makeMonitor(h)
        // beginTurn stamps lastProgress at the current clock (1.0s).
        await m.beginTurn(id: "turn-\(gap)")
        // Move the clock forward by exactly `gap` seconds from begin.
        h.setNow(seconds: 1.0 + gap)
        let verdict = await m.check()

        let oracleFires = gap >= threshold   // replicated source oracle
        if oracleFires {
            XCTAssertNotNil(verdict,
                "gap \(gap)s >= threshold \(threshold)s MUST fire")
            XCTAssertEqual(verdict?.turnID, "turn-\(gap)")
            XCTAssertEqual(verdict!.secondsSinceProgress, gap,
                accuracy: 1e-6,
                "verdict must report the exact elapsed gap")
            XCTAssertEqual(h.verdicts.count, 1,
                "exactly one verdict for the crossing")
        } else {
            XCTAssertNil(verdict,
                "gap \(gap)s < threshold \(threshold)s MUST NOT fire")
            XCTAssertTrue(h.verdicts.isEmpty,
                "no sink delivery below threshold")
        }
        await m.endTurn()
    }

    // Determinism: identical inputs at the exact boundary reproduce the
    // identical verdict across repeated independent runs.
    var boundaryReports: [Bool] = []
    for _ in 0..<5 {
        let h = QINAOStallHarness()
        let m = makeMonitor(h)
        await m.beginTurn(id: "det")
        h.setNow(seconds: 1.0 + threshold)   // exactly == threshold
        let v = await m.check()
        boundaryReports.append(v != nil)
        await m.endTurn()
    }
    XCTAssertEqual(boundaryReports, [true, true, true, true, true],
        "exact-boundary detection must be deterministic across re-calls")

    // Mutate-and-assert: with the SAME monitor/turn, a sub-threshold
    // gap stays silent, then nudging the clock to the boundary flips it
    // to fire — proving the bar is the gap, not turn existence.
    let hm = QINAOStallHarness()
    let mm = makeMonitor(hm)
    await mm.beginTurn(id: "mutate")
    hm.setNow(seconds: 1.0 + (threshold - 0.001))   // just below
    let below = await mm.check()
    XCTAssertNil(below, "just below threshold must not fire")
    XCTAssertTrue(hm.verdicts.isEmpty)
    hm.setNow(seconds: 1.0 + threshold)             // mutate to exact
    let atBoundary = await mm.check()
    XCTAssertNotNil(atBoundary,
        "advancing the clock to exactly the threshold must fire")
    XCTAssertEqual(hm.verdicts.count, 1)
    await mm.endTurn()

    print("QINAO-GATE decode_stall_wedge_detection: PASS " +
        "(exhaustive boundary sweep \(gaps.count) gaps incl exact==\(threshold)s, " +
        "deterministic x5, mutate just-below->boundary flip)")
}

    func test_qinao_calibration_cache_invalidation() throws {
        // QINAO #24 HIGH — BASAutoRouteCalibrationStore.validate performs 4
        // INDEPENDENT invalidation checks (schemaVersion / substrate version /
        // device fingerprint / staleness). Drive all 4 individually + confirm
        // a fully-matching report passes, then re-call deterministically.
        //
        // validate is a static throwing func on the actor type (no actor
        // isolation on the method itself) → no await needed.
        // Construction mirrors testValidateAcceptsFreshCache verbatim:
        //   BASAutoRouteCalibrationReport(schemaVersion:measuredAtEpochSec:
        //     substrateVersion:deviceFingerprint:measurements:thresholds:)
        //   thresholds: .mSeriesDefault, measurements: []
        let now: Int64 = 1_700_000_000

        // Local builder so every variant is a fresh value (immutability).
        func makeReport(
            schema: Int = 1,
            measuredAt: Int64 = now - 100,
            substrate: String = "1.0.0",
            device: String = "host-A"
        ) -> BASAutoRouteCalibrationReport {
            BASAutoRouteCalibrationReport(
                schemaVersion: schema,
                measuredAtEpochSec: measuredAt,
                substrateVersion: substrate,
                deviceFingerprint: device,
                measurements: [],
                thresholds: .mSeriesDefault)
        }

        // The expected-host parameters that a FRESH report must match.
        let expSchema = 1
        let expSubstrate = "1.0.0"
        let expDevice = "host-A"
        let maxAge: Int64 = 3600

        // Local "expect staleCache" oracle: validate MUST throw exactly
        // .staleCache for the given report. Returns the rejection reason.
        func expectStale(
            _ report: BASAutoRouteCalibrationReport,
            _ label: String
        ) -> String {
            do {
                try BASAutoRouteCalibrationStore.validate(
                    report,
                    expectedSchemaVersion: expSchema,
                    expectedSubstrateVersion: expSubstrate,
                    expectedDeviceFingerprint: expDevice,
                    maxAgeSec: maxAge,
                    now: now)
                XCTFail("\(label): validate must throw .staleCache but returned")
                return ""
            } catch let err as BASAutoRouteCalibrationStoreError {
                switch err {
                case .staleCache(let reason):
                    XCTAssertEqual(
                        err.caseIdentifier, "staleCache",
                        "\(label): caseIdentifier")
                    XCTAssertFalse(
                        reason.isEmpty,
                        "\(label): reason must be non-empty")
                    return reason
                default:
                    XCTFail("\(label): wrong store error: \(err)")
                    return ""
                }
            } catch {
                XCTFail("\(label): wrong error type: \(error)")
                return ""
            }
        }

        // --- Baseline: a fully-matching, fresh report must PASS (no throw). ---
        let good = makeReport()
        XCTAssertNoThrow(
            try BASAutoRouteCalibrationStore.validate(
                good,
                expectedSchemaVersion: expSchema,
                expectedSubstrateVersion: expSubstrate,
                expectedDeviceFingerprint: expDevice,
                maxAgeSec: maxAge,
                now: now),
            "matching fresh report must validate")

        // --- Check 1: schemaVersion mismatch independently invalidates. ---
        let schemaReason =
            expectStale(makeReport(schema: 99), "schema")
        XCTAssertTrue(
            schemaReason.contains("schema"),
            "schema reason should mention schema: \(schemaReason)")

        // --- Check 2: substrate version mismatch independently invalidates. ---
        let substrateReason =
            expectStale(makeReport(substrate: "9.9.9"), "substrate")
        XCTAssertTrue(
            substrateReason.contains("substrate"),
            "substrate reason should mention substrate: \(substrateReason)")

        // --- Check 3: device fingerprint mismatch independently invalidates. ---
        let deviceReason =
            expectStale(makeReport(device: "different-host"), "device")
        XCTAssertTrue(
            deviceReason.contains("device"),
            "device reason should mention device: \(deviceReason)")

        // --- Check 4: staleness (age > maxAge) independently invalidates. ---
        // age = now - measuredAt = 100_000 > maxAge 3600.
        let ageReason =
            expectStale(makeReport(measuredAt: now - 100_000), "age")
        XCTAssertTrue(
            ageReason.contains("age"),
            "age reason should mention age: \(ageReason)")

        // --- Independence proof: each rejection reason is DISTINCT, ---
        // confirming the four checks are separate code paths, not one.
        let reasons = [schemaReason, substrateReason, deviceReason, ageReason]
        XCTAssertEqual(
            Set(reasons).count, 4,
            "all 4 invalidation reasons must be distinct: \(reasons)")

        // --- Boundary: age exactly == maxAge must PASS (strict > check). ---
        let boundary = makeReport(measuredAt: now - maxAge)
        XCTAssertNoThrow(
            try BASAutoRouteCalibrationStore.validate(
                boundary,
                expectedSchemaVersion: expSchema,
                expectedSubstrateVersion: expSubstrate,
                expectedDeviceFingerprint: expDevice,
                maxAgeSec: maxAge,
                now: now),
            "age == maxAge is fresh (strict > invalidation)")

        // --- Determinism: re-running the schema check yields the SAME reason. ---
        let schemaReason2 =
            expectStale(makeReport(schema: 99), "schema-recall")
        XCTAssertEqual(
            schemaReason, schemaReason2,
            "validate is pure: same input → same rejection reason")

        print("QINAO-GATE calibration_cache_invalidation: PASS " +
            "(4 independent checks each invalidate; baseline+boundary pass; " +
            "distinct reasons; deterministic)")
    }

    func test_qinao_provider_plan_route_constraint_soundness() {
    // Build a registry that offers EVERY route kind for EVERY task kind, so the
    // planner is never starved of a cloud/hybrid option. If the planner ever
    // leaks a forbidden route, this registry guarantees it had the chance to.
    func qinaoCaps(_ latency: String) -> BASModelCapabilities {
        BASModelCapabilities(
            supportsGeneration: true,
            supportsEmbeddings: true,
            supportsTools: true,
            supportsStructuredOutput: true,
            supportsHybridRouting: true,
            latencyClass: latency
        )
    }
    let allTaskKinds: [BASTaskKind] = [.chat, .plan, .retrieve, .tool, .summarize]
    func qinaoDescriptor(_ id: String, _ route: BASRouteKind, _ latency: String, _ cost: Double) -> BASModelDescriptor {
        BASModelDescriptor(
            modelID: id,
            routeKind: route,
            capabilities: qinaoCaps(latency),
            supportedTaskKinds: allTaskKinds,
            relativeCostScore: cost,
            maximumContextTokens: 8192
        )
    }
    let registry = BASCapabilityRegistry(descriptors: [
        qinaoDescriptor("local-fast", .local, "fast", 0.1),
        qinaoDescriptor("local-slow", .local, "slow", 0.3),
        qinaoDescriptor("hybrid-mid", .hybrid, "fast", 0.5),
        qinaoDescriptor("cloud-large", .cloud, "slow", 0.7)
    ])

    // Map a model id back to its declared route kind (oracle for fallbackModelIDs).
    let routeByID: [String: BASRouteKind] = [
        "local-fast": .local,
        "local-slow": .local,
        "hybrid-mid": .hybrid,
        "cloud-large": .cloud
    ]

    func qinaoDevice(lowPower: Bool, thermal: String) -> BASDeviceProfile {
        BASDeviceProfile(
            modelName: "iPhone",
            memoryMB: 8192,
            batteryLevel: 0.6,
            lowPowerMode: lowPower,
            thermalState: thermal
        )
    }
    func qinaoBudget() -> BASExecutionBudget {
        BASExecutionBudget(
            contextTokens: 4096,
            outputTokens: 512,
            retrievalItems: 4,
            toolCalls: 2,
            timeBudgetMs: 2000
        )
    }

    // The contract under test, derived purely from privacyMode + networkAvailable
    // (the only inputs to the planner's allowedRoutes policy):
    //   localOnly      -> { .local }                      (NEVER cloud, NEVER hybrid)
    //   offline (!net) -> NEVER .cloud (localFirst/cloudAllowed drop cloud)
    func qinaoAllowed(_ privacy: BASPrivacyMode, _ network: Bool, _ lowPower: Bool) -> Set<BASRouteKind> {
        switch privacy {
        case .localOnly:
            return [.local]
        case .localFirst:
            return (network && !lowPower) ? [.local, .hybrid, .cloud] : [.local, .hybrid]
        case .cloudAllowed:
            return network ? [.local, .hybrid, .cloud] : [.local, .hybrid]
        }
    }

    let privacyModes: [BASPrivacyMode] = [.localOnly, .localFirst, .cloudAllowed]
    let gears: [BASRuntimeGear] = [.low, .balanced, .high]
    let risks: [BASRiskLevel] = [.low, .medium, .high]
    let networkStates: [Bool] = [true, false]
    let lowPowerStates: [Bool] = [true, false]
    let thermalStates: [String] = ["nominal", "fair", "serious", "critical"]

    var gridSize = 0
    for task in allTaskKinds {
        for privacy in privacyModes {
            for gear in gears {
                for risk in risks {
                    for network in networkStates {
                        for lowPower in lowPowerStates {
                            for thermal in thermalStates {
                                let ctx = BASRuntimeContext(
                                    taskKind: task,
                                    gear: gear,
                                    deviceProfile: qinaoDevice(lowPower: lowPower, thermal: thermal),
                                    privacyMode: privacy,
                                    riskLevel: risk,
                                    networkAvailable: network,
                                    budget: qinaoBudget()
                                )
                                let allowed = qinaoAllowed(privacy, network, lowPower)

                                let advisory = BASDefaultRoutingPlanner.plan(context: ctx, registry: registry)

                                // (1) The chosen route's kind must be inside allowedRoutes.
                                XCTAssertTrue(
                                    allowed.contains(advisory.route.routeKind),
                                    "route \(advisory.route.routeKind) escaped allowed \(allowed) for privacy=\(privacy) net=\(network) lowPower=\(lowPower)"
                                )
                                // (2) localOnly => route MUST be exactly .local.
                                if privacy == .localOnly {
                                    XCTAssertEqual(
                                        advisory.route.routeKind, .local,
                                        "localOnly emitted non-local route \(advisory.route.routeKind)"
                                    )
                                }
                                // (3) offline => route MUST NOT be .cloud.
                                if !network {
                                    XCTAssertNotEqual(
                                        advisory.route.routeKind, .cloud,
                                        "offline emitted a cloud route (task=\(task) privacy=\(privacy))"
                                    )
                                }
                                // (4) Every fallback model id resolves to an allowed route kind.
                                for fid in advisory.route.fallbackModelIDs {
                                    if let k = routeByID[fid] {
                                        XCTAssertTrue(
                                            allowed.contains(k),
                                            "fallback model \(fid) (route \(k)) escaped allowed \(allowed)"
                                        )
                                    }
                                }
                                // (5) Every fallback-graph stage's route kind is allowed.
                                for stage in advisory.fallbackGraph.orderedStages {
                                    XCTAssertTrue(
                                        allowed.contains(stage.routeKind),
                                        "fallback stage \(stage.modelID) route \(stage.routeKind) escaped allowed \(allowed)"
                                    )
                                }

                                // (6) Determinism: a second identical call yields the identical route.
                                let advisory2 = BASDefaultRoutingPlanner.plan(context: ctx, registry: registry)
                                XCTAssertEqual(advisory.route, advisory2.route, "non-deterministic route for identical context")
                                XCTAssertEqual(advisory.fallbackGraph, advisory2.fallbackGraph, "non-deterministic fallback graph")

                                gridSize += 1
                            }
                        }
                    }
                }
            }
        }
    }

    // Negative-control: a registry of ONLY cloud descriptors under localOnly must
    // still never emit cloud (it should degrade to the local "unavailable" placeholder).
    let cloudOnlyRegistry = BASCapabilityRegistry(descriptors: [
        qinaoDescriptor("cloud-only-a", .cloud, "fast", 0.4),
        qinaoDescriptor("cloud-only-b", .cloud, "slow", 0.9)
    ])
    let strictCtx = BASRuntimeContext(
        taskKind: .chat,
        gear: .balanced,
        deviceProfile: qinaoDevice(lowPower: false, thermal: "nominal"),
        privacyMode: .localOnly,
        riskLevel: .high,
        networkAvailable: true,
        budget: qinaoBudget()
    )
    let strict = BASDefaultRoutingPlanner.plan(context: strictCtx, registry: cloudOnlyRegistry)
    XCTAssertEqual(strict.route.routeKind, .local, "localOnly leaked cloud when only cloud descriptors existed")
    XCTAssertNotEqual(strict.route.routeKind, .cloud, "localOnly emitted cloud under cloud-only registry")
    for stage in strict.fallbackGraph.orderedStages {
        XCTAssertEqual(stage.routeKind, .local, "localOnly cloud-only fallback stage \(stage.modelID) is \(stage.routeKind)")
    }

    XCTAssertGreaterThanOrEqual(gridSize, 2160, "profile x rule grid undercovered: \(gridSize)")
    print("QINAO-GATE provider_plan_route_constraint_soundness: PASS (\(gridSize) profile x rule cells, route+fallbacks bounded to allowedRoutes; localOnly->local only, offline->no cloud; cloud-only+localOnly negative control held; deterministic re-call)")
}

    func test_qinao_provider_plan_determinism_tiebreak() {
    // QINAO #27 HIGH: re-running plan N times + permuting input descriptor order yields
    // identical orderedProviderIDs; equal-score ties fall back to the stable base order.
    // BASProviderPlanner.plan is a pure (non-actor, non-async) static func on an enum.

    // Local mirror of the existing-test `providerDescriptor` helper (verbatim from
    // BASRuntimeCoreTests.swift:1562), defined inside the method per QINAO rules.
    func qinaoProviderDescriptor(
        id: String,
        bestFor: [BASAdaptiveTraceKind],
        strengths: [BASProviderCapability],
        latencyClass: BASProviderLatencyClass,
        memoryClass: BASProviderMemoryClass,
        languages: [BASAdaptiveResponseLanguage],
        supportsThinking: Bool
    ) -> BASProviderDescriptor {
        BASProviderDescriptor(
            providerID: id,
            taskAffinities: Dictionary(
                uniqueKeysWithValues: bestFor.map { ($0, 100) }
            ),
            capabilityProfile: BASProviderCapabilityProfile(
                strengths: strengths,
                latencyClass: latencyClass,
                memoryClass: memoryClass,
                supportedResponseLanguages: languages,
                supportsThinking: supportsThinking,
                supportsStructuredOutput: strengths.contains(.structuredOutput),
                supportsToolUse: strengths.contains(.lightToolUse),
                bestFor: bestFor
            )
        )
    }

    // Three providers with IDENTICAL capability profiles + identical task affinity.
    // With strategy == nil, routingScore = affinity*10 + preferredBias + baseBias.
    // affinity is identical across all three, preferredBias applies only to the
    // preferred provider, and baseBias is purely a function of base index. Therefore
    // the non-preferred providers tie on score and MUST resolve by base index
    // (the stable tie-break at ProviderPlanningCore.swift lines 622-626).
    let baseOrdered = ["alpha", "bravo", "charlie"]
    let descriptors: [BASProviderDescriptor] = baseOrdered.map { id in
        qinaoProviderDescriptor(
            id: id,
            bestFor: [.primary],
            strengths: [.structuredOutput, .lowLatency, .lowMemory],
            latencyClass: .low,
            memoryClass: .low,
            languages: [.english],
            supportsThinking: false
        )
    }

    // (1) Deterministic re-call: N identical runs => byte-identical orderedProviderIDs.
    func planOrdered(_ descs: [BASProviderDescriptor]) -> [String] {
        BASProviderPlanner.plan(
            task: .primary,
            preferredProviderID: "alpha",
            baseOrderedProviderIDs: baseOrdered,
            strategy: nil,
            descriptors: descs
        ).orderedProviderIDs
    }

    let reference = planOrdered(descriptors)
    for iteration in 0..<32 {
        let repeated = planOrdered(descriptors)
        XCTAssertEqual(
            repeated,
            reference,
            "Re-run #\(iteration) diverged from the first plan; planning is not deterministic."
        )
    }

    // (2) Input-permutation invariance: every permutation of the descriptor input array
    // must yield the SAME orderedProviderIDs, because the sort is keyed off the base
    // ordering index, not the descriptor array order. Exhaustive over all 3! = 6 perms.
    func qinaoPermutations<T>(_ array: [T]) -> [[T]] {
        guard array.count > 1 else { return [array] }
        var result: [[T]] = []
        for index in array.indices {
            var rest = array
            let element = rest.remove(at: index)
            for tail in qinaoPermutations(rest) {
                result.append([element] + tail)
            }
        }
        return result
    }

    let allPermutations = qinaoPermutations(descriptors)
    XCTAssertEqual(allPermutations.count, 6, "Expected 3! = 6 input permutations.")
    for permuted in allPermutations {
        let permutedOrder = planOrdered(permuted)
        XCTAssertEqual(
            permutedOrder,
            reference,
            "Permuting the descriptor input order changed orderedProviderIDs; ordering is not input-stable."
        )
    }

    // (3) Tie-break falls back to the STABLE base order (tolerance = 0, exact match).
    // The preferred provider ("alpha") also leads the base order, so the equal-score
    // tie-break must reproduce baseOrdered exactly.
    XCTAssertEqual(
        reference,
        baseOrdered,
        "Equal-score providers did not fall back to the stable base order."
    )

    // (4) Mutate-and-assert safety: the input descriptors array is value-typed; building
    // a fresh permuted copy must not perturb the original or its plan.
    let afterMutation = planOrdered(descriptors)
    XCTAssertEqual(
        afterMutation,
        reference,
        "Planning over the original descriptors after permutation runs was not stable."
    )

    print("QINAO-GATE provider_plan_determinism_tiebreak: PASS (32 re-runs identical, all 6 input permutations stable, ties -> base order \(reference))")
}
}
