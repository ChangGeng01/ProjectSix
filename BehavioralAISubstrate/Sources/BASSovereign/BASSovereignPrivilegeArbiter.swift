import Foundation
import BASRuntimeCore

/// `BR-02` PrivilegeArbiter — the sovereign authority on "is this
/// permission currently held?"
///
/// The arbiter is the bookkeeping layer behind BR-003/BR-004/BR-005/
/// BR-011. Whenever a VerdictEngine decision revokes a permission the
/// arbiter records it, and every subsequent privilege check sees the
/// revocation. The state is scoped per-session by default but also
/// supports feature-domain keys (matching `BASSovereignLockScope`).
///
/// ## Scope model
///
/// Three nested scopes, checked bottom-up:
///
/// 1. **Turn scope**: `(session, turn)`. Auto-decays at end of turn.
/// 2. **Session scope**: `(session)`. Revocation persists through the
///    session until explicitly lifted or the session ends.
/// 3. **Feature-domain scope**: `(domain)`. Cross-session. Used when
///    the integrity layer seals a feature domain ("no more external
///    actuation in this domain, until maintenance"). Named-domain
///    queries are partition-scoped — a differently-named domain does
///    NOT inherit the seal. A query that omits the domain cannot dodge
///    a seal by omission: it fails closed against every domain seal
///    for that permission.
///
/// ## Fail-closed
///
/// If any scope above the query has revoked the permission, the
/// arbiter denies — this matches the Black Ring `ROLLBACK` semantics.
/// There is no "union of allowed" — allowance is implicit and
/// revocation is the only active signal.
public actor BASSovereignPrivilegeArbiter {
    public struct ScopeKey: Hashable, Sendable, Codable {
        public let sessionID: String
        public let turnID: String?
        public let featureDomain: String?

        public init(sessionID: String, turnID: String? = nil, featureDomain: String? = nil) {
            self.sessionID = sessionID
            self.turnID = turnID
            self.featureDomain = featureDomain
        }
    }

    private struct Revocation: Sendable {
        let permission: BASSovereignPermission
        let reasonCode: String
        let recordedAt: Date
    }

    /// Keyed by scope. Each entry is the set of currently-revoked
    /// permissions for that scope.
    private var turnRevocations: [ScopeKey: [Revocation]] = [:]
    private var sessionRevocations: [String: [Revocation]] = [:]      // sessionID → revs
    private var domainRevocations: [String: [Revocation]] = [:]       // feature-domain → revs

    private let now: @Sendable () -> Date

    public init(now: @escaping @Sendable () -> Date = { Date() }) {
        self.now = now
    }

    // MARK: - Revoke

    public func revoke(
        _ permission: BASSovereignPermission,
        session: String,
        turn: String? = nil,
        featureDomain: String? = nil,
        reasonCode: String
    ) {
        let rev = Revocation(permission: permission, reasonCode: reasonCode, recordedAt: now())

        if let featureDomain {
            domainRevocations[featureDomain, default: []].append(rev)
        } else if let turn {
            let key = ScopeKey(sessionID: session, turnID: turn)
            turnRevocations[key, default: []].append(rev)
        } else {
            sessionRevocations[session, default: []].append(rev)
        }
    }

    /// Bulk apply a verdict's `revokedPermissions` set to the session.
    public func apply(
        verdict: BASSovereignVerdict,
        session: String,
        turn: String? = nil,
        featureDomain: String? = nil
    ) {
        let code = verdict.reasonCodes.first ?? verdict.verdictID
        for perm in verdict.revokedPermissions {
            revoke(perm, session: session, turn: turn, featureDomain: featureDomain, reasonCode: code)
        }
    }

    // MARK: - Queries

    public func isAllowed(
        _ permission: BASSovereignPermission,
        session: String,
        turn: String? = nil,
        featureDomain: String? = nil
    ) -> Bool {
        // Domain revocation is the widest scope. A query that NAMES a
        // domain is partition-scoped: only that domain's revocations
        // apply, and a differently-named domain does not inherit them
        // (see testDomainRevocationBlocksAcrossSessions). A query that
        // does NOT name a domain must not be able to dodge a domain
        // seal by omission — it fails CLOSED against ANY domain
        // revocation of the permission. (blindspot HIGH: the old code
        // only checked domainRevocations[featureDomain], so a nil-domain
        // query fell through to session/turn scope and returned true,
        // silently bypassing every domain seal.)
        if let featureDomain {
            if let revs = domainRevocations[featureDomain],
               revs.contains(where: { $0.permission == permission }) {
                return false
            }
        } else if domainRevocations.values.contains(where: { revs in
            revs.contains(where: { $0.permission == permission })
        }) {
            return false
        }
        // Session revocation blocks across all turns of that session.
        if let revs = sessionRevocations[session],
           revs.contains(where: { $0.permission == permission }) {
            return false
        }
        // Turn revocation blocks that turn only.
        if let turn {
            let key = ScopeKey(sessionID: session, turnID: turn)
            if let revs = turnRevocations[key],
               revs.contains(where: { $0.permission == permission }) {
                return false
            }
        }
        return true
    }

    /// Human-readable explanation for a denied privilege check.
    /// Returns `nil` if the permission is currently allowed.
    public func explainDenial(
        _ permission: BASSovereignPermission,
        session: String,
        turn: String? = nil,
        featureDomain: String? = nil
    ) -> String? {
        if let featureDomain,
           let rev = domainRevocations[featureDomain]?.first(where: { $0.permission == permission }) {
            return "domain(\(featureDomain)):\(rev.reasonCode)"
        }
        if let rev = sessionRevocations[session]?.first(where: { $0.permission == permission }) {
            return "session(\(session)):\(rev.reasonCode)"
        }
        if let turn {
            let key = ScopeKey(sessionID: session, turnID: turn)
            if let rev = turnRevocations[key]?.first(where: { $0.permission == permission }) {
                return "turn(\(turn)):\(rev.reasonCode)"
            }
        }
        return nil
    }

    // MARK: - Lifting

    /// Lift turn-scoped revocations when a turn ends. Session and
    /// domain revocations are NOT auto-lifted — they require an
    /// explicit maintenance call.
    public func endOfTurn(session: String, turn: String) {
        let key = ScopeKey(sessionID: session, turnID: turn)
        turnRevocations.removeValue(forKey: key)
    }

    public func endOfSession(_ session: String) {
        sessionRevocations.removeValue(forKey: session)
        turnRevocations = turnRevocations.filter { $0.key.sessionID != session }
    }

    public func liftDomainRevocations(_ featureDomain: String) {
        domainRevocations.removeValue(forKey: featureDomain)
    }

    // MARK: - Diagnostics

    public func revocationCount() -> Int {
        turnRevocations.values.map(\.count).reduce(0, +)
        + sessionRevocations.values.map(\.count).reduce(0, +)
        + domainRevocations.values.map(\.count).reduce(0, +)
    }
}
