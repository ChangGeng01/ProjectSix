import Foundation

// 四十八 — typed reference for honesty-board 四十五.3 Doctrines
// B (frequency 论) + C (双速成长). Pure typed vocabulary; pins
// the doctrine in code for grep / audit / instrumentation.
//
// ## Why this exists
//
// Doctrine B (四十五.3) names 4 state update tiers with
// canonical frequencies:
//
//   - 神经网络（parameter 态）: month / week / version
//   - 第二大脑（process 态）  : second / round
//   - 宿主（individual 态）   : day / phase / confirm
//   - SDK（device/product 态）: millisecond / session
//
// Doctrine C (四十五.3) layers a 双速成长 invariant on top:
// 宿主 layer 长得快、神经网络 layer 长得慢. The two doctrines
// were "implicit + 显式 taxonomy" until 47.x; this file makes
// them typed.
//
// ## Doctrine
//
// - **`BASStateUpdateScope`** — 4-tier enum mirroring Doctrine
//   B. Each actor has a canonical scope (Doctrine D × Doctrine B
//   matrix).
// - **`BASGrowthVelocity`** — 5-tier Comparable enum capturing
//   how fast a layer's state is allowed to change. L2 weight
//   changes require `.veryLow` (offline-only); host runtime and
//   SDK device state run at `.immediate`.
// - **Doctrine C invariant**: training operations on L2 must
//   carry `.veryLow` velocity. Pinned by tests.

public enum BASStateUpdateScope:
    String, Sendable, Equatable, Hashable, Codable, CaseIterable
{
    /// Parameter state — neural-network weights / quantized
    /// adapters. Updated at month / week / version cadence.
    case parameter

    /// Process state — L1-L14 in-turn cognition / decision /
    /// surface. Updated per turn (second / round cadence).
    case process

    /// Individual state — host constitution, value axes,
    /// boundary, relations, rhythm. Updated per day / phase /
    /// explicit confirmation.
    case individual

    /// Device / product state — SDK runtime, session, hot/cold
    /// pack, UI surface. Updated at millisecond / session
    /// cadence.
    case device
}

public extension BASActor {
    /// Doctrine B canonical scope per actor. Pins Doctrine D
    /// × Doctrine B matrix.
    var canonicalUpdateScope: BASStateUpdateScope {
        switch self {
        case .neuralNetwork: return .parameter
        case .secondBrain: return .process
        case .host: return .individual
        case .sdk: return .device
        }
    }
}

public enum BASGrowthVelocity:
    String, Sendable, Equatable, Hashable, Codable,
    CaseIterable, Comparable
{
    /// Updated continuously at runtime — SDK device state,
    /// session-level transient state.
    case immediate

    /// Per-turn / per-day — host preferences, ephemeral memory
    /// updates within a session.
    case fast

    /// Per-arc / per-pattern — L8 memory arcs, L13 evolution
    /// candidates collected over time.
    case medium

    /// Per-shadow-trial / per-version-delta — L13 furnace
    /// shadow trials → version deltas, infrequent governance
    /// transitions.
    case slow

    /// Offline-training-only — L2 neural-network weights, only
    /// updated through curriculum-filtered offline distillation.
    /// **Doctrine C invariant**: L2 changes MUST carry this
    /// velocity.
    case veryLow

    public var rank: Int {
        switch self {
        case .immediate: return 4
        case .fast: return 3
        case .medium: return 2
        case .slow: return 1
        case .veryLow: return 0
        }
    }

    public static func < (
        lhs: BASGrowthVelocity,
        rhs: BASGrowthVelocity
    ) -> Bool {
        lhs.rank < rhs.rank
    }
}

public extension BASStateUpdateScope {
    /// Doctrine C velocity floor for this scope — the slowest
    /// velocity any state at this scope is permitted to change
    /// at, by canonical doctrine. Parameter-scope state is the
    /// slowest (`.veryLow`); device-scope is the fastest
    /// (`.immediate`).
    var canonicalVelocity: BASGrowthVelocity {
        switch self {
        case .parameter: return .veryLow
        case .process: return .medium
        case .individual: return .fast
        case .device: return .immediate
        }
    }
}

public extension BASActor {
    /// Doctrine C: each actor's canonical growth velocity.
    /// Derived through the scope mapping.
    var canonicalGrowthVelocity: BASGrowthVelocity {
        canonicalUpdateScope.canonicalVelocity
    }
}

/// Doctrine C invariant check — does a proposed change to
/// parameter-scope state carry the required `.veryLow`
/// velocity? Used by training-pipeline calls that need to
/// audit "is this change allowed at L2 timescale".
public enum BASDoctrineCInvariant {
    /// Returns true iff the change at the given scope is
    /// running at a velocity ≤ canonical floor. (Lower = slower
    /// in `BASGrowthVelocity` ordering; parameter scope must
    /// stay at `.veryLow` exactly.)
    public static func permits(
        velocity: BASGrowthVelocity,
        at scope: BASStateUpdateScope
    ) -> Bool {
        switch scope {
        case .parameter:
            // L2 changes MUST carry .veryLow exactly.
            return velocity == .veryLow
        case .process, .individual, .device:
            // Other scopes accept any velocity ≤ their floor.
            return velocity <= scope.canonicalVelocity
        }
    }
}
