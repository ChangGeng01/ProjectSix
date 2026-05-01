import Foundation

// 六十五.1 — typed runtime lease enforcer.
//
// ## Why this exists
//
// 六十四.3 ship 了 `QinaoAgentLease` typed shape. 但 typed
// 类型独自不能让 lease 在 runtime 真生效——需要一个 actor
// 跟踪每张 lease 的发放 / 使用 / 到期，并能拒绝过期 lease
// 的 proposal。
//
// 六十五.1 ships that actor: `QinaoAgentLeaseEnforcer`.
//
// ## Doctrine
//
// - **Pure typed runtime.** Actor encapsulates lease state;
//   external API is async but semantically deterministic.
// - **Issuance is monotonic.** Each issued lease gets a
//   stable ref `lease-<seq>`. seq never reuses.
// - **Validity 4 independent invariants:** unexpired wall
//   clock + writes ≤ maxWrites + loops ≤ maxLoops + scope
//   contains target.
// - **Revocation is explicit.** Caller can mark a lease
//   revoked; subsequent checks return invalid even if other
//   invariants hold.

/// Typed reasons a lease check can fail. Pipelines branch
/// on case for stable telemetry.
public enum QinaoAgentLeaseInvalidReason:
    Sendable, Equatable, Hashable, Codable
{
    case unknownLease
    case expired(elapsedMs: Int, maxMs: Int)
    case writesExhausted(used: Int, max: Int)
    case loopsExhausted(used: Int, max: Int)
    case targetOutsideScope(QinaoSeatDomain)
    case revoked
}

/// Typed validity report — empty `reasons` means valid.
public struct QinaoAgentLeaseValidityReport:
    Sendable, Equatable, Hashable, Codable
{
    public let leaseRef: String
    public let reasons: [QinaoAgentLeaseInvalidReason]

    public init(
        leaseRef: String,
        reasons: [QinaoAgentLeaseInvalidReason]
    ) {
        self.leaseRef = leaseRef
        self.reasons = reasons
    }

    public var isValid: Bool { reasons.isEmpty }
}

/// Per-lease usage counters tracked at issuance.
public struct QinaoAgentLeaseUsage:
    Sendable, Equatable, Hashable, Codable
{
    public var writesUsed: Int
    public var loopsUsed: Int
    public var revoked: Bool

    public init(
        writesUsed: Int = 0,
        loopsUsed: Int = 0,
        revoked: Bool = false
    ) {
        self.writesUsed = writesUsed
        self.loopsUsed = loopsUsed
        self.revoked = revoked
    }
}

/// Actor managing lease lifecycles.
public actor QinaoAgentLeaseEnforcer {
    private struct Entry {
        let lease: QinaoAgentLease
        let issuedAtMs: Int
        var usage: QinaoAgentLeaseUsage
    }

    private var nextSeq: Int = 1
    private var entries: [String: Entry] = [:]
    private let now: @Sendable () -> Int

    /// `now` returns wall-clock milliseconds since some
    /// stable epoch. Defaults to `Date()` based; tests pass
    /// a deterministic clock.
    public init(
        now: @escaping @Sendable () -> Int = {
            Int(
                Date().timeIntervalSince1970 * 1000)
        }
    ) {
        self.now = now
    }

    /// Issue a lease and return its stable ref.
    public func issue(
        _ lease: QinaoAgentLease
    ) -> String {
        let ref = "lease-\(nextSeq)"
        nextSeq += 1
        entries[ref] = Entry(
            lease: lease,
            issuedAtMs: now(),
            usage: QinaoAgentLeaseUsage())
        return ref
    }

    /// Increment writes-used for a lease. Caller invokes on
    /// each successful proposal accept.
    public func recordWrite(leaseRef: String) {
        guard var entry = entries[leaseRef] else { return }
        entry.usage.writesUsed += 1
        entries[leaseRef] = entry
    }

    /// Increment loops-used.
    public func recordLoop(leaseRef: String) {
        guard var entry = entries[leaseRef] else { return }
        entry.usage.loopsUsed += 1
        entries[leaseRef] = entry
    }

    /// Mark a lease revoked. Subsequent checks return invalid.
    public func revoke(leaseRef: String) {
        guard var entry = entries[leaseRef] else { return }
        entry.usage.revoked = true
        entries[leaseRef] = entry
    }

    /// Check a lease's validity against optional target
    /// domain. Returns typed report; empty reasons = valid.
    public func validity(
        leaseRef: String,
        target: QinaoSeatDomain? = nil
    ) -> QinaoAgentLeaseValidityReport {
        guard let entry = entries[leaseRef] else {
            return QinaoAgentLeaseValidityReport(
                leaseRef: leaseRef,
                reasons: [.unknownLease])
        }
        var reasons: [QinaoAgentLeaseInvalidReason] = []
        if entry.usage.revoked {
            reasons.append(.revoked)
        }
        let elapsed = now() - entry.issuedAtMs
        if elapsed > entry.lease.maxMs {
            reasons.append(
                .expired(
                    elapsedMs: elapsed,
                    maxMs: entry.lease.maxMs))
        }
        if entry.usage.writesUsed
            >= entry.lease.maxWrites
            && entry.lease.maxWrites > 0
        {
            reasons.append(
                .writesExhausted(
                    used: entry.usage.writesUsed,
                    max: entry.lease.maxWrites))
        }
        if entry.usage.loopsUsed
            >= entry.lease.maxLoops
            && entry.lease.maxLoops > 0
        {
            reasons.append(
                .loopsExhausted(
                    used: entry.usage.loopsUsed,
                    max: entry.lease.maxLoops))
        }
        if let target,
            !entry.lease.scope.contains(target)
        {
            reasons.append(
                .targetOutsideScope(target))
        }
        return QinaoAgentLeaseValidityReport(
            leaseRef: leaseRef, reasons: reasons)
    }

    /// Convenience boolean.
    public func isValid(
        leaseRef: String,
        target: QinaoSeatDomain? = nil
    ) -> Bool {
        validity(
            leaseRef: leaseRef, target: target
        ).isValid
    }

    /// Inspection — count of issued leases (for tests +
    /// dashboards).
    public func issuedCount() -> Int { entries.count }

    /// Inspection — typed usage for a lease.
    public func usage(
        leaseRef: String
    ) -> QinaoAgentLeaseUsage? {
        entries[leaseRef]?.usage
    }
}
