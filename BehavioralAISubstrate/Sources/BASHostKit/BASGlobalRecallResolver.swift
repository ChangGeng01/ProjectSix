// ADR-037 — global-recall resolver. Relocated from the DeviceTestApp host into BASHostKit so it is
// SPM-unit-testable (the host wires it as the global-recall seam's `atomForID` backing).
import Foundation
import BASMemory

/// ADR-037 — bounded resolver backing the global-recall seam's `atomForID`. NSLock-guarded
/// atomID → (atom, domain) map with insertion-order FIFO eviction (the memory bound). `put` returns
/// any evicted ids so the caller mirrors the eviction into the engine — keeping engine-rows ==
/// resolver-keys (the ADR-037 lockstep invariant; without it the engine grows unbounded and cosineTopK
/// returns ids the resolver can't resolve → silent recall loss). `lookupSync` is the sync hot-path read
/// (inside the ch883 sync retrieve); `put`/eviction run between turns. Mirrors the service's withLock
/// idiom (never holds the lock across a suspension). `@unchecked Sendable`: the lock synchronizes.
public final class BASGlobalRecallResolver: @unchecked Sendable {
    /// Smallest sane corpus cap (also the host's parse floor).
    public static let minCap = 64
    private let lock = NSLock()
    private var map: [String: (atom: BASMemoryAtom, domain: String)] = [:]
    private var order: [String] = []          // insertion order for FIFO eviction
    private let cap: Int
    #if DEBUG
    private var writing = false
    #endif
    public init(cap: Int) { self.cap = max(Self.minCap, cap) }
    /// Insert/replace; returns the ids the FIFO cap evicted so the caller can `engine.remove` them in
    /// lockstep (engine-rows == resolver-keys).
    @discardableResult
    public func put(id: String, atom: BASMemoryAtom, domain: String) -> [String] {
        lock.lock(); defer { lock.unlock() }
        if map[id] == nil { order.append(id) }
        map[id] = (atom, domain)
        var evicted: [String] = []
        while order.count > cap {
            let e = order.removeFirst()
            map[e] = nil
            evicted.append(e)
        }
        return evicted
    }
    public func lookupSync(id: String) -> (atom: BASMemoryAtom, domain: String)? {
        lock.lock(); defer { lock.unlock() }
        return map[id]
    }
    public var count: Int {
        lock.lock(); defer { lock.unlock() }
        return map.count
    }
    // ADR-037 concurrency contract (M2): the sync hot-path reads (atomForID + cosineTopK, WITHIN a
    // turn) must never overlap the between-turns engine/resolver writes. The seam closures assert this;
    // the host brackets its between-turns sync with begin/endWrite. Always callable; the logic is
    // DEBUG-only (no-op + zero cost in release).
    public func beginWrite() {
        #if DEBUG
        lock.lock(); writing = true; lock.unlock()
        #endif
    }
    public func endWrite() {
        #if DEBUG
        lock.lock(); writing = false; lock.unlock()
        #endif
    }
    public func assertNotWriting() {
        #if DEBUG
        lock.lock(); let w = writing; lock.unlock()
        assert(!w, "ADR-037: global-recall sync read overlapped a between-turns write — turn-phase separation violated")
        #endif
    }
}
