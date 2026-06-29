import Foundation

/// observe→DISPOSE (biomimetic-brain-efficiency) — pure input adapters that turn raw governance signals into
/// the bounded [0,1] scalars `BASEffortAllocator` consumes. Kept separate from the allocator so the producers
/// (predictive-coding ε in BASMetalSubstrate, thermal twin in BASLeaseLife) never have to be linked here: a
/// host extracts the raw value (`runningMSE`, a `ProcessInfo.ThermalState`) and passes the scalar in.
///
/// This is the "ε plumbing" the `BASAdjudicationGate` doc deferred: ε is a COMPUTE-allocation throttle whose
/// home is the effort/tier allocator (NOT the verify gate). `surprise(fromMSE:)` is where ε finally enters the
/// loop as a normalized signal.
public enum BASEffortSignals {

    /// The MSE at which surprise = 0.5 — the "moderately surprising" knee of the saturating curve. A host that
    /// runs a different predictive-coding scale tunes this; the default suits a unit-scale running MSE.
    public static let defaultSurpriseScale = 1.0

    /// Surprise (normalized ε) from a running mean-squared prediction error. Running MSE is unbounded (≥0); map
    /// it to [0,1) with the saturating, monotonic curve `mse / (mse + scale)` so ε becomes a bounded,
    /// scale-tunable surprise signal. `mse ≤ 0` (or a non-positive scale) ⇒ 0 (no surprise / no signal).
    public static func surprise(fromMSE mse: Double, scale: Double = defaultSurpriseScale) -> Double {
        guard mse > 0, scale > 0 else { return 0 }
        return mse / (mse + scale)
    }

    /// Thermal headroom in [0,1]: 1 = full budget, 0 = throttling. Monotonic with a cooler state. This is the
    /// "× headroom" factor of `energy ∝ surprise × stakes × headroom`, realized by the allocator as a hard CAP
    /// (thermal-lease: don't spend energy the device doesn't have).
    public static func headroom(for state: ProcessInfo.ThermalState) -> Double {
        switch state {
        case .nominal:  return 1.0
        case .fair:     return 0.6
        case .serious:  return 0.3
        case .critical: return 0.0
        @unknown default: return 0.3   // unknown ⇒ assume pressure (conservative)
        }
    }

    /// Headroom from the substrate's own per-turn thermal reading (`BASDeviceState.thermalLevel`) — the source a
    /// live turn carries, so a chat facade doesn't have to reach for `ProcessInfo`. Same scale as the OS mapper.
    public static func headroom(for level: BASThermalLevel) -> Double {
        switch level {
        case .nominal:  return 1.0
        case .warm:     return 0.6
        case .hot:      return 0.3
        case .critical: return 0.0
        }
    }
}
