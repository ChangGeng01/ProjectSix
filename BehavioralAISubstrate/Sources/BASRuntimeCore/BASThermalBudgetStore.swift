import Foundation

/// P0 经验持久化(RSI 章程 2026-07-07)— B4 learnedBudget 持久化从 BASEnduranceAppRunner
/// (:1543/:2702)提入库,宿主共用一条实现。语义与 runner 原样恒等:
/// - key 字符串冻结为 "bas.thermal.learned_budget"(改字符串 = 既有设备无声失忆);
/// - restore 带 (20...300)s sanity clamp(损坏 store 不得楔死预测器);
/// - persist 仅在 observedTransitions > 0 时写(零观察不覆盖旧学习值)。
/// UserDefaults 后端保持(per-device by construction,主权本地)。
public enum BASThermalBudgetStore {

    /// FROZEN — existing devices' learned budgets live under this exact key.
    public static let storageKey = "bas.thermal.learned_budget"

    /// The sanity band (seconds) — outside ⇒ treated as absent (cold prior).
    public static let sanityBand: ClosedRange<Double> = 20.0 ... 300.0

    /// Restore the last learned nominal-duty budget, or nil (= predictor's built-in prior).
    public static func restore(defaults: UserDefaults = .standard) -> Double? {
        let stored = defaults.double(forKey: storageKey)   // absent ⇒ 0.0 ⇒ outside band
        return sanityBand.contains(stored) ? stored : nil
    }

    /// Persist the learned budget — only when at least one nominal→hot transition was actually
    /// observed this run (an observation-free run must not overwrite prior learning).
    public static func persist(
        _ learnedBudget: Double, observedTransitions: Int, defaults: UserDefaults = .standard
    ) {
        guard observedTransitions > 0 else { return }
        defaults.set(learnedBudget, forKey: storageKey)
    }
}
