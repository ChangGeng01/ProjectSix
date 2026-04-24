import Foundation

/// M93c — In-process publish-subscribe for sovereign warrant / token
/// revocations.
///
/// ## Why this exists
///
/// `BASSovereignTokenAuthority` revokes a `BASSovereignCommitToken`
/// or `BASSovereignWarrant` by marking it invalid on its internal
/// revocation set. But revocation is a state change that downstream
/// actors (the ledger actor, the runtime coordinator, observability
/// consumers, any live permit holder) need to **react to** — not
/// just pull on demand. A live session holding an already-issued
/// warrant that subsequently gets revoked must stop trusting it
/// within a bounded delay.
///
/// `BASSovereignRevocationBroadcaster` provides the reaction
/// primitive: a small actor-based publish-subscribe bus carrying
/// `BASSovereignRevocationEvent` values to every registered
/// observer. Latency target: <250ms from `publish()` to observer
/// invocation on the same process (tested).
///
/// ## Scope (M93 vs future)
///
/// M93 ships **in-process** broadcast only. Every observer lives in
/// the same process as the broadcaster. This covers the audit use
/// case — all of the substrate's consumers (ledger, token authority,
/// coordinator) are co-resident — and is deterministic enough to
/// test without plumbing IPC.
///
/// Future M94 candidate: a Darwin-only extension that also posts a
/// `CFNotificationCenterGetDarwinNotifyCenter` notification on
/// publish so sibling processes can subscribe via their own
/// broadcaster. That layer is opt-in — production hosts that need
/// cross-process revocation wire it; test / development hosts do not.
///
/// ## Non-Darwin
///
/// This file uses only Foundation + Swift concurrency. Builds
/// identically on Darwin and Linux.

// MARK: - Event schema

/// Kind of sovereign revocation. Stable raw values so observer
/// code can key on them across process boundaries (future M94).
public enum BASSovereignRevocationKind:
    String, Sendable, Equatable, Codable, CaseIterable {
    /// A `BASSovereignCommitToken` was revoked before its TTL.
    case commitToken = "commit-token"
    /// A `BASSovereignWarrant` was revoked before its TTL.
    case warrant
    /// A privilege was revoked (session-scoped sovereign lock
    /// relinquished early).
    case privilege
    /// A signing key rotation — the outgoing fingerprint is
    /// revoked. Carried alongside `commitToken` / `warrant` when
    /// the revocation cascade was triggered by a key rotation.
    case signingKey = "signing-key"
}

/// One revocation event. Sendable-safe value type.
public struct BASSovereignRevocationEvent:
    Sendable, Equatable, Codable, Hashable {
    /// What was revoked.
    public let kind: BASSovereignRevocationKind
    /// Stable identifier of the revoked artifact (token ID,
    /// warrant ID, privilege ID, key fingerprint — interpretation
    /// depends on `kind`).
    public let subjectID: String
    /// Free-text reason code for observability. Stable codes
    /// preferred ("ttl-expired", "host-requested", "policy-breach",
    /// "key-rotated").
    public let reasonCode: String
    /// Wall-clock at publish time. Observers that care about order
    /// can sort by this; most observers just react.
    public let publishedAt: Date

    public init(
        kind: BASSovereignRevocationKind,
        subjectID: String,
        reasonCode: String,
        publishedAt: Date = Date()
    ) {
        self.kind = kind
        self.subjectID = subjectID
        self.reasonCode = reasonCode
        self.publishedAt = publishedAt
    }
}

// MARK: - Broadcaster

/// Actor-backed in-process publish-subscribe bus for revocation
/// events.
///
/// Observers are keyed by a `label: String` — a human-readable
/// identifier the subscribing code chooses. Re-subscribing with the
/// same label replaces the previous observer in place (idempotent).
/// Unsubscribing with a label that isn't registered is a no-op.
///
/// The internal invocation is `await handler(event)` — observers
/// run sequentially inside the actor's execution context. This is
/// the right tradeoff for M93 scope: small number of observers
/// (typically <10) each doing cheap state updates. If the use case
/// ever grows to hundreds of observers with slow handlers, a
/// `TaskGroup`-based fan-out is a straightforward follow-up.
public actor BASSovereignRevocationBroadcaster {

    public typealias Handler =
        @Sendable (BASSovereignRevocationEvent) async -> Void

    private var observers: [String: Handler] = [:]
    private var publishCount: Int = 0

    public init() {}

    // MARK: - Subscription

    /// Register an observer. Calling with an already-registered
    /// `label` replaces the previous handler (idempotent).
    public func subscribe(
        label: String,
        handler: @escaping Handler
    ) {
        observers[label] = handler
    }

    /// Remove an observer. Unsubscribing a label that isn't
    /// registered is a no-op.
    public func unsubscribe(label: String) {
        observers.removeValue(forKey: label)
    }

    /// Number of currently-registered observers. Diagnostic.
    public var observerCount: Int {
        observers.count
    }

    /// Labels of currently-registered observers. Diagnostic.
    public var observerLabels: [String] {
        Array(observers.keys)
    }

    // MARK: - Publish

    /// Fan `event` out to every registered observer. Each
    /// observer runs to completion before the next starts; the
    /// entire call returns after all observers have processed.
    ///
    /// Observers that throw are not catchable from here — the
    /// handler signature is non-throwing. Observers that want to
    /// surface errors must handle them internally (log / halt
    /// their own subsystem / emit an audit entry).
    public func publish(
        _ event: BASSovereignRevocationEvent
    ) async {
        publishCount += 1
        // Snapshot observers first so a handler that calls back
        // into `subscribe` / `unsubscribe` doesn't mutate the set
        // mid-iteration.
        let snapshot = observers
        for handler in snapshot.values {
            await handler(event)
        }
    }

    /// Diagnostic: how many `publish(_:)` calls this broadcaster
    /// has processed since init.
    public var totalPublishCount: Int {
        publishCount
    }
}
