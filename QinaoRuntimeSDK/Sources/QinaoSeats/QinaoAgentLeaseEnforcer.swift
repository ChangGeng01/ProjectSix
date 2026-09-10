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
    /// deep-audit P1-8 (2026-07-13): the presenting seat is not the seat the lease was
    /// issued to. A lease is a capability bound to one agent; presenting another agent's
    /// leaseRef to spend its budget/scope must fail closed. `QinaoAgentLease.agent` carried
    /// this binding since 六十四.3 but nothing compared it — this reason wires the check.
    case leaseAgentMismatch(issuedTo: QinaoSeat, presentedBy: QinaoSeat)
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

    /// Increment writes-used for a lease.
    ///
    /// deep-audit P1-8 (2026-07-13): DORMANT. No production or dispatch path calls this yet —
    /// the seat-fabric propose→commit lane (dispatchProposals) is test-only scaffolding and
    /// does not consume lease budget. This is the intended trigger point ("on each accepted
    /// write") for when that lane is wired into the sovereign spine; until then writesUsed
    /// stays 0 and the writesExhausted invariant never fires in practice. The prior comment
    /// ("Caller invokes on each successful proposal accept") described a caller that does not
    /// exist — the repo treats such doc-lies as first-class defects.
    public func recordWrite(leaseRef: String) {
        guard var entry = entries[leaseRef] else { return }
        entry.usage.writesUsed += 1
        entries[leaseRef] = entry
    }

    /// Increment loops-used. DORMANT — same as `recordWrite`: no caller consumes loop budget
    /// until the seat-fabric commit lane is wired (deep-audit P1-8).
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

    /// Check a lease's validity against an optional presenting `agent` and optional target
    /// domain. Returns typed report; empty reasons = valid.
    ///
    /// deep-audit P1-8 (2026-07-13): when `agent` is supplied and does not match the seat the
    /// lease was issued to, the check fails closed with `.leaseAgentMismatch` — a seat cannot
    /// spend another agent's lease. `agent` is optional so pre-existing callers that only test
    /// the time/write/loop/scope invariants keep their exact semantics.
    public func validity(
        leaseRef: String,
        agent: QinaoSeat? = nil,
        target: QinaoSeatDomain? = nil
    ) -> QinaoAgentLeaseValidityReport {
        guard let entry = entries[leaseRef] else {
            return QinaoAgentLeaseValidityReport(
                leaseRef: leaseRef,
                reasons: [.unknownLease])
        }
        var reasons: [QinaoAgentLeaseInvalidReason] = []
        if let agent, entry.lease.agent != agent {
            reasons.append(
                .leaseAgentMismatch(
                    issuedTo: entry.lease.agent,
                    presentedBy: agent))
        }
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
        agent: QinaoSeat? = nil,
        target: QinaoSeatDomain? = nil
    ) -> Bool {
        validity(
            leaseRef: leaseRef, agent: agent, target: target
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
