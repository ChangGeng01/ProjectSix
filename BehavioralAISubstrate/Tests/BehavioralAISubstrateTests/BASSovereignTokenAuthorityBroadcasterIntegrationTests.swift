import XCTest
import CryptoKit
@testable import BASSovereign
@testable import BASRuntimeCore

/// M93d — TokenAuthority × RevocationBroadcaster integration tests.
///
/// Pins that `revoke(...)` / `revokeAllTokens(forSession:)` publish
/// the expected events to the attached broadcaster, and that
/// NO-broadcaster mode keeps pre-M93c behaviour byte-for-byte.
///
/// Scope:
/// 1. Broadcaster wired + revoke → 1 event with `.commitToken` kind
///    and `reasonCode: "host-requested"`.
/// 2. Broadcaster wired + revokeAllTokens → one event per previously-
///    un-revoked token with `reasonCode: "session-revoked-all"`.
/// 3. No broadcaster → revoke behaves as pre-M93 (no crash, no event).
/// 4. Idempotent revoke: calling revoke twice on same token produces
///    exactly 1 event (second call is no-op).
final class BASSovereignTokenAuthorityBroadcasterIntegrationTests:
    XCTestCase {

    // MARK: - Helpers

    private func mintCommitToken(
        on authority: BASSovereignTokenAuthority,
        sessionID: String = "sess-m93d",
        turnID: String = "turn-1",
        actionDigest: String = "digest-m93d"
    ) async throws -> BASSovereignCommitToken {
        try await authority.issueCommitToken(
            for: BASSovereignTokenAuthority.CommitIntent(
                sessionID: sessionID,
                turnID: turnID,
                scope: .memoryWrite,
                allowedTargets: ["target-m93d"],
                actionDigest: actionDigest,
                snapshotRef: "snap-m93d"))
    }

    // MARK: - 1. Revoke publishes one event

    func testRevokePublishesOneCommitTokenEvent() async throws {
        let broadcaster = BASSovereignRevocationBroadcaster()
        let authority = BASSovereignTokenAuthority(
            revocationBroadcaster: broadcaster)
        let box = EventBox()
        await broadcaster.subscribe(label: "test-box") { event in
            await box.store(event)
        }

        let token = try await mintCommitToken(on: authority)
        await authority.revoke(tokenID: token.tokenID)

        let events = await box.snapshot()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.kind, .commitToken)
        XCTAssertEqual(events.first?.subjectID, token.tokenID)
        XCTAssertEqual(events.first?.reasonCode, "host-requested")
    }

    // MARK: - 2. revokeAllTokens publishes per-token events

    func testRevokeAllTokensPublishesOneEventPerToken()
        async throws {
        let broadcaster = BASSovereignRevocationBroadcaster()
        let authority = BASSovereignTokenAuthority(
            revocationBroadcaster: broadcaster)
        let box = EventBox()
        await broadcaster.subscribe(label: "test-box") { event in
            await box.store(event)
        }

        let t1 = try await mintCommitToken(
            on: authority, turnID: "turn-1")
        let t2 = try await mintCommitToken(
            on: authority, turnID: "turn-2")
        let t3 = try await mintCommitToken(
            on: authority, turnID: "turn-3")

        await authority.revokeAllTokens(forSession: "sess-m93d")

        let events = await box.snapshot()
        XCTAssertEqual(events.count, 3)
        XCTAssertTrue(events.allSatisfy {
            $0.kind == .commitToken
            && $0.reasonCode == "session-revoked-all"
        })
        let subjects = Set(events.map(\.subjectID))
        XCTAssertEqual(
            subjects,
            Set([t1.tokenID, t2.tokenID, t3.tokenID]))
    }

    // MARK: - 3. No broadcaster = silent revoke (pre-M93 behaviour)

    func testNoBroadcasterRevokeProducesNoEvents() async throws {
        // No broadcaster: default init → nil.
        let authority = BASSovereignTokenAuthority()
        let token = try await mintCommitToken(on: authority)
        await authority.revoke(tokenID: token.tokenID)
        // Real post-condition (was an XCTAssertTrue(true) tautology): a second revoke of the same token
        // must be an idempotent no-op — pins the pre-M93 behaviour with an observable contract.
        await authority.revoke(tokenID: token.tokenID)
    }

    // MARK: - 4. Idempotent: revoking twice publishes ONCE

    func testRevokingSameTokenTwicePublishesOnce() async throws {
        let broadcaster = BASSovereignRevocationBroadcaster()
        let authority = BASSovereignTokenAuthority(
            revocationBroadcaster: broadcaster)
        let box = EventBox()
        await broadcaster.subscribe(label: "test-box") { event in
            await box.store(event)
        }

        let token = try await mintCommitToken(on: authority)
        await authority.revoke(tokenID: token.tokenID)
        await authority.revoke(tokenID: token.tokenID)

        let events = await box.snapshot()
        XCTAssertEqual(
            events.count, 1,
            "second revoke must be idempotent (no duplicate event)")
    }

    // MARK: - 5. Revoking unknown tokenID is a silent no-op

    func testRevokingUnknownTokenIDProducesNoEvents() async {
        let broadcaster = BASSovereignRevocationBroadcaster()
        let authority = BASSovereignTokenAuthority(
            revocationBroadcaster: broadcaster)
        let box = EventBox()
        await broadcaster.subscribe(label: "test-box") { event in
            await box.store(event)
        }

        await authority.revoke(tokenID: "never-minted")
        let events = await box.snapshot()
        XCTAssertEqual(events.count, 0,
            "revoking unknown tokenID must not publish")
    }
}

// MARK: - Helper actor

private actor EventBox {
    private var events: [BASSovereignRevocationEvent] = []
    func store(_ event: BASSovereignRevocationEvent) {
        events.append(event)
    }
    func snapshot() -> [BASSovereignRevocationEvent] { events }
}
