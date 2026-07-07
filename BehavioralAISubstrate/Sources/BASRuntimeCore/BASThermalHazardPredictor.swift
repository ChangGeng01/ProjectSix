// BASThermalHazardPredictor — B4 预测式热控 (FRONTIER_2026H2 B4, the EnerInfer pattern):
// upgrade the REACTIVE thermal stance (wait for ProcessInfo to flip, then flee the downclocked
// zone) to a PREDICTIVE one — learn how much decode duty the nominal zone absorbs before the OS
// declares fair, and pre-empt with duty shaping (inserted micro-cooldowns) BEFORE the transition.
//
// Why shaping beats riding into fair (measured, endurance-cert 2026-07-03): at `fair` the
// downclocked GPU makes the fused chain net-negative (0.91-0.99×) while nominal rides 1.20-1.36×;
// staying nominal-with-gaps trades a few idle seconds against a whole downclocked regime.
//
// The device exposes NO die temperature — only the coarse thermal tier — so the model is a
// duty-budget hazard estimator, not a thermometer: decode-seconds accumulate in the current
// nominal window, idle refunds duty at a recovery rate (heat sheds), and each observed
// nominal→hot exit tightens/loosens the learned budget by EMA (α=0.4, the codebase idiom).
// Pure value type: no clocks, no ProcessInfo — the caller feeds observations (testable, ADR-014).
// ⚰️ P4 注 (RSI 章程 2026-07-07):本预测器生产接线仅在 DeviceTestApp host(env 门控
// BAS_THERMAL_PREDICT);库内(BASMLXAdapter 车道)零调用者——库侧热响应刻意保持反应式
// (per-round 读 + planner 闸,已设备认证)。库内采纳 = 新 ADR-014 阶梯,非顺手接线。
// 持久化已提库:BASThermalBudgetStore(P0)。
public struct BASThermalHazardPredictor: Sendable {

    public struct Config: Sendable {
        /// Prior decode-seconds the nominal zone absorbs before fair. CALIBRATED 2026-07-04 from two
        /// full-duty iPhone Air runs (both: ~5 iters × ~10.5s decode → fair at ~46-52s of duty; the
        /// original 150 guess never fired). Learned online from every observed transition.
        public var priorNominalDutyBudget: Double = 60
        /// Hazard fires at duty ≥ budget × safetyFraction. 0.5 CALIBRATED 2026-07-04 from FOUR
        /// full-duty iPhone Air runs — observed nominal→fair transition duty {≈35, ≈42.5, ≈46, ≈52}s
        /// (coarse-tier + duty-seconds is a NOISY heat proxy; inter-run variance ≈ the warning
        /// margin). The line sits below the observed MINIMUM by principle (0.5×60=30 < 35), not
        /// tuned-until-it-fired: early-warning that fires 5-22s pre-fair is cheap insurance
        /// (an early effort downshift), a missed warning is a lost regime.
        public var safetyFraction: Double = 0.5
        /// Idle seconds refund duty at this rate (heat shedding while quiet).
        public var recoveryCredit: Double = 0.5
        /// EMA step for budget learning on each observed nominal→hot exit.
        public var emaAlpha: Double = 0.4
        /// Recommended gap when hazard is predicted.
        public var cooldownSeconds: Double = 4
        public init() {}
    }

    public let config: Config
    public private(set) var learnedBudget: Double
    public private(set) var dutyInWindow: Double = 0
    public private(set) var lastTier: Int = 0          // 0 nominal · 1 fair · 2 serious · 3 critical
    public private(set) var observedTransitions: Int = 0

    /// `learnedBudget` restores a PERSISTED estimate from prior runs (per-device recalibration —
    /// the 4-run calibration showed 35-52s inter-run variance; carrying the EMA across runs keeps
    /// the line tracking THIS device instead of re-paying the prior each launch). nil = prior.
    public init(config: Config = Config(), learnedBudget: Double? = nil) {
        self.config = config
        self.learnedBudget = learnedBudget ?? config.priorNominalDutyBudget
    }

    /// Decode work done. Counts ONLY inside the nominal window — once hot, the reactive layer
    /// (planner tier gate, adaptive-K thermal tier) owns the response and this window is frozen.
    public mutating func recordDecode(seconds: Double) {
        guard lastTier == 0, seconds > 0 else { return }
        dutyInWindow += seconds
    }

    /// Idle time (inserted gaps or natural quiet). Refunds duty — the shaping mechanism.
    public mutating func recordIdle(seconds: Double) {
        guard lastTier == 0, seconds > 0 else { return }
        dutyInWindow = max(0, dutyInWindow - seconds * config.recoveryCredit)
    }

    /// Thermal tier observation (ProcessInfo.thermalState.rawValue at the call site).
    /// nominal→hot LEARNS the budget from the window; hot→nominal resets the window.
    public mutating func recordTier(_ tier: Int) {
        defer { lastTier = tier }
        if lastTier == 0 && tier > 0 {
            learnedBudget = (1 - config.emaAlpha) * learnedBudget + config.emaAlpha * dutyInWindow
            observedTransitions += 1
        } else if lastTier > 0 && tier == 0 {
            dutyInWindow = 0
        }
    }

    /// True while still nominal but the accumulated duty crosses the pre-empt line.
    public var hazard: Bool {
        lastTier == 0 && dutyInWindow >= learnedBudget * config.safetyFraction
    }

    /// The shaping action: a recommended gap, or nil when no hazard.
    public var recommendedCooldown: Double? { hazard ? config.cooldownSeconds : nil }
}
