import Foundation
import BASRuntimeCore

/// `BR-08` SovereignLockManager — active-lock state machine for the
/// sovereign loop.
///
/// ## Role
///
/// VerdictEngine produces a verdict level. The lock manager turns
/// that level into a **durable mode** scoped to a turn / session /
/// feature-domain so subsequent operations can consult "what lock
/// level is currently active over my scope?" without re-running the
/// full engine.
///
/// A `shadowLock` lock blocks promotion paths; a `toolCut` lock blocks
/// tool classes; a `rollback` lock freezes the scope until a restore
/// completes; a `deadStop` lock halts everything in that scope. The
/// lock `level` uses the same 8-step ladder as
/// `BASSovereignVerdictLevel` — higher subsumes lower.
///
/// ## Difference from PrivilegeArbiter
///
/// - PrivilegeArbiter tracks revocations of *individual permissions*
///   (`toolWrite`, `hostMutation`, …). Fine-grained.
/// - LockManager tracks *mode-level* clamps on entire scopes. Coarse.
///   A single active `deadStop` lock on a session means the session
///   is sealed regardless of which permissions the arbiter has on
///   file.
///
/// Both are consulted at gate time. Arbiter says "permission present";
/// lock manager says "scope not in a halting mode".
public actor BASSovereignLockManager {
    public struct ScopeIdentifier: Hashable, Sendable {
        public let scope: BASSovereignLockScope
        /// Context-dependent: for `.turn` this is `"<session>:<turn>"`;
        /// for `.session` it is `"<session>"`; for `.featureDomain` it
        /// is `"<domain>"`. Callers use the factory helpers below
        /// rather than constructing this directly.
        public let key: String

        public static func turn(session: String, turn: String) -> ScopeIdentifier {
            .init(scope: .turn, key: "\(session):\(turn)")
        }
        public static func session(_ session: String) -> ScopeIdentifier {
            .init(scope: .session, key: session)
        }
        public static func featureDomain(_ domain: String) -> ScopeIdentifier {
            .init(scope: .featureDomain, key: domain)
        }
    }

    // MARK: - State

    /// Active locks keyed by lockID. Released locks are kept so audit
    /// and explain paths can inspect history; `activeLocks(...)` is
    /// always filtered on `releasedAt == nil`.
    private var locks: [String: BASSovereignLock] = [:]
    /// Secondary index: scope identifier → lockIDs. Kept in sync with
    /// `locks`. Enables O(1) active-locks lookup.
    private var indexByScope: [ScopeIdentifier: Set<String>] = [:]
    /// Which scope each lock is registered under (so release removes
    /// from the index without scanning).
    private var scopeOfLock: [String: ScopeIdentifier] = [:]

    private let now: @Sendable () -> Date

    public init(now: @escaping @Sendable () -> Date = { Date() }) {
        self.now = now
    }

    // MARK: - Engage

    @discardableResult
    public func engage(
        lockID: String,
        scope: ScopeIdentifier,
        level: BASSovereignVerdictLevel,
        releaseCondition: String
    ) -> BASSovereignLock {
        let lock = BASSovereignLock(
            lockID: lockID,
            scope: scope.scope,
            lockLevel: level,
            createdAt: now(),
            releaseCondition: releaseCondition,
            releasedAt: nil
        )
        locks[lockID] = lock
        indexByScope[scope, default: []].insert(lockID)
        scopeOfLock[lockID] = scope
        return lock
    }

    /// Derive a lock from a verdict. The caller supplies the scope
    /// because the verdict itself doesn't carry session/turn/domain
    /// metadata — those live in `VerdictContext`.
    @discardableResult
    public func apply(
        verdict: BASSovereignVerdict,
        scope: ScopeIdentifier,
        releaseCondition: String? = nil
    ) -> BASSovereignLock? {
        // A `pass` verdict engages nothing; a `throttle` is soft and
        // also not a lock. Locks are for shadowLock+ levels.
        guard verdict.verdictLevel >= .shadowLock else { return nil }
        let condition = releaseCondition ?? "verdict(\(verdict.verdictID))"
        let lockID = "lock-\(verdict.verdictID)"
        return engage(
            lockID: lockID,
            scope: scope,
            level: verdict.verdictLevel,
            releaseCondition: condition
        )
    }

    // MARK: - Release

    /// Release a specific lock. Release sets `releasedAt` but keeps
    /// the record for audit; active-locks queries will ignore it.
    public func release(lockID: String) {
        guard var lock = locks[lockID], lock.releasedAt == nil else { return }
        lock.releasedAt = now()
        locks[lockID] = lock
        if let scope = scopeOfLock[lockID] {
            indexByScope[scope]?.remove(lockID)
            if indexByScope[scope]?.isEmpty == true {
                indexByScope.removeValue(forKey: scope)
            }
        }
    }

    /// Release every active lock under a given scope. Used by
    /// end-of-turn / end-of-session / maintenance-window exits.
    public func releaseAll(in scope: ScopeIdentifier) {
        guard let ids = indexByScope[scope] else { return }
        for id in ids { release(lockID: id) }
    }

    // MARK: - Queries

    public func activeLocks(in scope: ScopeIdentifier) -> [BASSovereignLock] {
        guard let ids = indexByScope[scope] else { return [] }
        return ids.compactMap { locks[$0] }
            .filter { $0.releasedAt == nil }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// Highest currently-active lock level across all scopes that
    /// apply to the triple `(session, turn?, featureDomain?)`.
    /// - turn matches `turn(session:session, turn:turn)` if `turn` given
    /// - session matches `session(session)`
    /// - feature matches `featureDomain(featureDomain)` if given
    public func highestActiveLevel(
        session: String,
        turn: String? = nil,
        featureDomain: String? = nil
    ) -> BASSovereignVerdictLevel {
        var highest: BASSovereignVerdictLevel = .pass
        func consider(_ scope: ScopeIdentifier) {
            for lock in activeLocks(in: scope) where lock.lockLevel > highest {
                highest = lock.lockLevel
            }
        }
        if let turn {
            consider(.turn(session: session, turn: turn))
        }
        consider(.session(session))
        if let featureDomain {
            consider(.featureDomain(featureDomain))
        }
        return highest
    }

    /// Answer "may an operation that needs the scope to be at most
    /// `maxTolerated` level proceed?" The convention: operations pick
    /// the highest level of lock they can still run under.
    ///
    /// - A tool-write caller passes `maxTolerated: .throttle` — any
    ///   `shadowLock`+ active lock denies.
    /// - A read-only caller passes `maxTolerated: .shadowLock` — only
    ///   `toolCut`+ denies.
    public func isOperationAllowed(
        maxTolerated: BASSovereignVerdictLevel,
        session: String,
        turn: String? = nil,
        featureDomain: String? = nil
    ) -> Bool {
        let current = highestActiveLevel(
            session: session,
            turn: turn,
            featureDomain: featureDomain
        )
        return current <= maxTolerated
    }

    public func lock(byID id: String) -> BASSovereignLock? {
        locks[id]
    }

    // MARK: - Diagnostics

    public func activeLockCount() -> Int {
        locks.values.filter { $0.releasedAt == nil }.count
    }

    public func totalLockCount() -> Int { locks.count }

    /// All active locks across every scope. Audit view.
    public func allActiveLocks() -> [BASSovereignLock] {
        locks.values
            .filter { $0.releasedAt == nil }
            .sorted { $0.createdAt < $1.createdAt }
    }
}
