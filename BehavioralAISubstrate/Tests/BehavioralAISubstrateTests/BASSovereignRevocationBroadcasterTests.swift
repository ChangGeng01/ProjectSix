import XCTest
@testable import BASSovereign

/// M93c — Revocation broadcaster tests.
///
/// Pins:
///
/// 1. `publish` → registered observers are called with the event.
/// 2. Latency <250ms for a single observer (M93 target).
/// 3. Multiple observers all receive the same event.
/// 4. Subscribing same label twice REPLACES the handler (not
///    duplicate-register).
/// 5. Unsubscribing stops further deliveries.
/// 6. Publish with zero observers is a no-op (doesn't throw / hang /
///    increment anything besides `totalPublishCount`).
/// 7. Observer that calls `subscribe` / `unsubscribe` on the
///    broadcaster DOES NOT mutate the in-flight iteration (snapshot
///    semantics pinned).
/// 8. `BASSovereignRevocationEvent` Codable round-trip.
final class BASSovereignRevocationBroadcasterTests: XCTestCase {

    // MARK: - Fixtures

    private func sampleEvent(
        subjectID: String = "tok-m93c-1",
        kind: BASSovereignRevocationKind = .commitToken,
        reasonCode: String = "host-requested"
    ) -> BASSovereignRevocationEvent {
        BASSovereignRevocationEvent(
            kind: kind,
            subjectID: subjectID,
            reasonCode: reasonCode,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000))
    }

    // MARK: - 1. Publish delivers to registered observer

    func testSubscribeThenPublishInvokesObserver() async {
        let broadcaster = BASSovereignRevocationBroadcaster()
        let received = ReceivedBox()
        await broadcaster.subscribe(label: "o1") { event in
            await received.store(event)
        }
        let event = sampleEvent()
        await broadcaster.publish(event)
        let got = await received.snapshot()
        XCTAssertEqual(got.count, 1)
        XCTAssertEqual(got.first, event)
    }

    // MARK: - 2. Latency within 250ms target

    func testPublishLatencyBelow250ms() async {
        let broadcaster = BASSovereignRevocationBroadcaster()
        let received = ReceivedBox()
        await broadcaster.subscribe(label: "o-latency") { event in
            await received.store(event)
        }
        let event = sampleEvent()

        let start = Date()
        await broadcaster.publish(event)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(
            elapsed, 0.250,
            "publish must deliver in <250ms; got \(elapsed * 1000)ms")
        let gotCount = await received.count
        XCTAssertEqual(gotCount, 1)
    }

    // MARK: - 3. Multiple observers

    func testMultipleObserversAllReceiveEvent() async {
        let broadcaster = BASSovereignRevocationBroadcaster()
        let boxA = ReceivedBox()
        let boxB = ReceivedBox()
        let boxC = ReceivedBox()

        await broadcaster.subscribe(label: "A") { event in
            await boxA.store(event)
        }
        await broadcaster.subscribe(label: "B") { event in
            await boxB.store(event)
        }
        await broadcaster.subscribe(label: "C") { event in
            await boxC.store(event)
        }

        let event = sampleEvent(subjectID: "multi-obs")
        await broadcaster.publish(event)

        for box in [boxA, boxB, boxC] {
            let got = await box.snapshot()
            XCTAssertEqual(got, [event])
        }
    }

    // MARK: - 4. Subscribe with same label replaces

    func testResubscribeSameLabelReplacesHandler() async {
        let broadcaster = BASSovereignRevocationBroadcaster()
        let firstHandlerBox = ReceivedBox()
        let secondHandlerBox = ReceivedBox()

        await broadcaster.subscribe(label: "replace-me") { event in
            await firstHandlerBox.store(event)
        }
        await broadcaster.subscribe(label: "replace-me") { event in
            await secondHandlerBox.store(event)
        }

        let count = await broadcaster.observerCount
        XCTAssertEqual(
            count, 1,
            "same-label re-subscribe must REPLACE not duplicate")

        await broadcaster.publish(sampleEvent())
        let firstCount = await firstHandlerBox.count
        let secondCount = await secondHandlerBox.count
        XCTAssertEqual(firstCount, 0,
            "first handler must no longer receive")
        XCTAssertEqual(secondCount, 1,
            "second handler must receive")
    }

    // MARK: - 5. Unsubscribe stops deliveries

    func testUnsubscribeStopsFurtherDeliveries() async {
        let broadcaster = BASSovereignRevocationBroadcaster()
        let received = ReceivedBox()
        await broadcaster.subscribe(label: "transient") { event in
            await received.store(event)
        }
        await broadcaster.publish(sampleEvent(subjectID: "first"))

        await broadcaster.unsubscribe(label: "transient")
        await broadcaster.publish(sampleEvent(subjectID: "second"))

        let got = await received.snapshot()
        XCTAssertEqual(got.count, 1)
        XCTAssertEqual(got.first?.subjectID, "first")
    }

    func testUnsubscribeUnknownLabelIsNoOp() async {
        let broadcaster = BASSovereignRevocationBroadcaster()
        await broadcaster.unsubscribe(label: "never-registered")
        let count = await broadcaster.observerCount
        XCTAssertEqual(count, 0)
    }

    // MARK: - 6. Publish with zero observers

    func testPublishWithNoObserversIncrementsCounterOnly() async {
        let broadcaster = BASSovereignRevocationBroadcaster()
        await broadcaster.publish(sampleEvent())
        await broadcaster.publish(sampleEvent())
        let total = await broadcaster.totalPublishCount
        XCTAssertEqual(total, 2,
            "publish counter increments even without observers")
        let obsCount = await broadcaster.observerCount
        XCTAssertEqual(obsCount, 0)
    }

    // MARK: - 7. Snapshot semantics: observer mutation doesn't affect in-flight iteration

    func testObserverCanSubscribeDuringPublishWithoutAffectingCurrentIteration()
        async {
        let broadcaster = BASSovereignRevocationBroadcaster()
        let outerBox = ReceivedBox()
        let innerBox = ReceivedBox()

        // First observer: when it fires, it registers a second
        // observer. The second observer MUST NOT receive THIS
        // publish's event (snapshot taken before iteration).
        await broadcaster.subscribe(label: "outer") { event in
            await outerBox.store(event)
            await broadcaster.subscribe(label: "inner") { inner in
                await innerBox.store(inner)
            }
        }

        await broadcaster.publish(sampleEvent(subjectID: "first"))

        let outerGot = await outerBox.snapshot()
        let innerGot = await innerBox.snapshot()
        XCTAssertEqual(outerGot.count, 1,
            "outer received the publish")
        XCTAssertEqual(innerGot.count, 0,
            "inner registered DURING publish; must not see this event")

        // Now publish again — inner should see it.
        await broadcaster.publish(sampleEvent(subjectID: "second"))
        let innerGot2 = await innerBox.snapshot()
        XCTAssertEqual(innerGot2.count, 1,
            "inner receives the NEXT publish")
    }

    // MARK: - 8. Codable round-trip on the event type

    func testEventCodableRoundTrip() throws {
        let original = BASSovereignRevocationEvent(
            kind: .warrant,
            subjectID: "wrt-1",
            reasonCode: "policy-breach",
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        enc.dateEncodingStrategy = .millisecondsSince1970
        let data = try enc.encode(original)
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .millisecondsSince1970
        let decoded = try dec.decode(
            BASSovereignRevocationEvent.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - 9. All 4 revocation kinds distinct

    func testAllRevocationKindsHaveDistinctRawValues() {
        let raws = BASSovereignRevocationKind.allCases.map {
            $0.rawValue
        }
        XCTAssertEqual(
            Set(raws).count, raws.count,
            "every case must have a distinct raw value")
        XCTAssertEqual(raws.count, 4,
            "4 kinds: commitToken/warrant/privilege/signingKey")
    }
}

// MARK: - Helpers

/// Tiny actor to collect events observed by handlers; sendable-safe
/// across the actor barrier.
private actor ReceivedBox {
    private var events: [BASSovereignRevocationEvent] = []

    func store(_ event: BASSovereignRevocationEvent) {
        events.append(event)
    }

    func snapshot() -> [BASSovereignRevocationEvent] {
        events
    }

    var count: Int { events.count }
}
