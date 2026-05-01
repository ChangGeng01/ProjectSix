import Foundation

// 六十五.3 — typed hot/cold seat residency runtime.
//
// ## Why this exists
//
// 六十四.2 typed-pinned each seat's `residency` (.hot or
// .cold). Manifesto v4 五.4 says 热席常驻、冷席按需唤醒。
// 但 runtime 现状是 `standardLoopSeats` factory 一次性
// register 全 9 席——所有都 hot。
//
// 六十五.3 ships a residency-aware actor: only hot seats
// register at boot; cold seats spawn on demand via
// `wakeup(seat:)`. This honors v4 latency condition
// `hotColdSeatResidency`.
//
// ## Doctrine
//
// - **Hot seats register at init.** From canonical
//   capability: scout / risk / surface / sovereignSentinel.
// - **Cold seats spawn lazy.** Memory / Planner / Critic /
//   HostAlignment / EvolutionShadow appear only when
//   `wakeup(seat:)` is called.
// - **Idempotent wakeup.** Calling `wakeup(.planner)` twice
//   is harmless — second call is a no-op.
// - **Sleep is explicit.** Caller calls `sleep(seat:)` to
//   release a cold seat's resources.
// - **Hot seats can't be slept.** Doctrine: hot core stays
//   on. Sleeping a hot seat returns false without effect.

/// Typed factory that produces a concrete seat for a given
/// kind. Caller injects a factory once; manager calls it
/// to spawn cold seats on demand.
public typealias QinaoSeatFactory = @Sendable (
    QinaoSeat
) -> (any QinaoSeatProtocol)?

public actor QinaoSeatResidencyManager {
    private let factory: QinaoSeatFactory
    private var registry: QinaoSeatRegistry
    private var awakenedColdSeats: Set<QinaoSeat> = []
    /// Cache of built seat instances keyed by seat kind.
    /// **Identity-preserving**: `sleep(seat:)` removes the
    /// slept seat from this cache, but surviving cached
    /// instances are re-registered as-is — never re-built
    /// via the factory (which could destroy actor state /
    /// in-flight tasks / lease refs of the survivor).
    private var instanceCache: [
        QinaoSeat: any QinaoSeatProtocol
    ] = [:]

    /// Create the manager + a fresh registry; immediately
    /// register all hot seats via the supplied factory.
    public init(
        factory: @escaping QinaoSeatFactory
    ) async {
        self.factory = factory
        self.registry = QinaoSeatRegistry()
        // Register hot seats at init.
        for seat in QinaoSeat.allCases
        where seat.canonicalCapability.residency == .hot
        {
            if let impl = factory(seat) {
                instanceCache[seat] = impl
                await registry.register(impl)
            }
        }
    }

    /// Wake up a cold seat. Returns true if the seat became
    /// active (i.e., factory produced an impl + register
    /// succeeded). Returns false if seat is already hot, or
    /// if seat is already awakened, or if the factory
    /// returned nil.
    @discardableResult
    public func wakeup(
        seat: QinaoSeat
    ) async -> Bool {
        // Hot seats are always on; wakeup is a no-op.
        if seat.canonicalCapability.residency == .hot {
            return false
        }
        // Already awakened — idempotent.
        if awakenedColdSeats.contains(seat) {
            return false
        }
        guard let impl = factory(seat) else {
            return false
        }
        instanceCache[seat] = impl
        await registry.register(impl)
        awakenedColdSeats.insert(seat)
        return true
    }

    /// Sleep a cold seat (release / unregister). Returns
    /// true on success. Hot seats cannot be slept (returns
    /// false). Cold seats not awakened are also no-op.
    ///
    /// **Identity-preserving**: surviving seats are NOT
    /// re-built by the factory; their cached instances are
    /// re-installed verbatim, so any internal actor state
    /// (counters, in-flight tasks, lease refs) survives
    /// across this rebuild.
    @discardableResult
    public func sleep(seat: QinaoSeat) async -> Bool {
        if seat.canonicalCapability.residency == .hot {
            return false
        }
        guard awakenedColdSeats.contains(seat) else {
            return false
        }
        // Drop slept seat from cache.
        instanceCache[seat] = nil
        awakenedColdSeats.remove(seat)
        // QinaoSeatRegistry doesn't expose unregister;
        // clear and re-register the surviving cached
        // instances (NOT factory-rebuilt).
        await registry.clear()
        for s in QinaoSeat.allCases {
            if let impl = instanceCache[s] {
                await registry.register(impl)
            }
        }
        return true
    }

    /// Inspection — currently active seats (hot + awakened
    /// cold).
    public func activeSeats() async -> Set<QinaoSeat> {
        Set(await registry.registeredSeats())
    }

    /// Inspection — awakened cold seats only.
    public func awakenedColdSeatsView() -> Set<QinaoSeat> {
        awakenedColdSeats
    }

    /// Direct access to the underlying registry — for
    /// callers that want to dispatch through it.
    public func underlyingRegistry()
        -> QinaoSeatRegistry { registry }
}
