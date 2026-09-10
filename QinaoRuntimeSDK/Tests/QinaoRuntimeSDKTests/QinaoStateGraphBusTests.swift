import XCTest
@testable import QinaoSeats

/// 六十五.2 — state graph pub/sub bus tests.
final class QinaoStateGraphBusTests: XCTestCase {

    func test_emptyBus() async {
        let bus = QinaoStateGraphBus()
        let total = await bus.totalPublished()
        XCTAssertEqual(total, 0)
        let subs = await bus.subscriberCount()
        XCTAssertEqual(subs, 0)
    }

    func test_subscribeAndReceiveMatchingDomain() async {
        let bus = QinaoStateGraphBus()
        let sub = await bus.subscribe(
            agent: .scout,
            domains: [.situationField])

        await bus.publish(
            domain: .situationField,
            payload: "p1",
            originAgent: .memory)

        var iter = sub.events.makeAsyncIterator()
        let event = await iter.next()
        XCTAssertEqual(event?.domain, .situationField)
        XCTAssertEqual(event?.payload, "p1")
        XCTAssertEqual(event?.originAgent, .memory)
        sub.close()
    }

    func test_subscriberDoesNotReceiveOtherDomain()
        async
    {
        let bus = QinaoStateGraphBus()
        let sub = await bus.subscribe(
            agent: .scout,
            domains: [.situationField])

        // Publish to a different domain.
        await bus.publish(
            domain: .actionPermit,
            payload: "ignored")

        // Then publish to the subscribed domain.
        await bus.publish(
            domain: .situationField,
            payload: "received")

        var iter = sub.events.makeAsyncIterator()
        let event = await iter.next()
        // Subscriber must skip actionPermit and only see
        // situationField.
        XCTAssertEqual(
            event?.payload, "received",
            "subscriber must NOT see other-domain events")
        sub.close()
    }

    func test_publishedSequenceMonotonic() async {
        let bus = QinaoStateGraphBus()
        let s1 = await bus.publish(
            domain: .situationField, payload: "1")
        let s2 = await bus.publish(
            domain: .actionPermit, payload: "2")
        let s3 = await bus.publish(
            domain: .candidateFrontier, payload: "3")
        XCTAssertEqual(s1, 1)
        XCTAssertEqual(s2, 2)
        XCTAssertEqual(s3, 3)
        let total = await bus.totalPublished()
        XCTAssertEqual(total, 3)
    }

    func test_multipleSubscribers() async {
        let bus = QinaoStateGraphBus()
        let s1 = await bus.subscribe(
            agent: .scout,
            domains: [.situationField])
        let s2 = await bus.subscribe(
            agent: .risk,
            domains: [.situationField, .actionPermit])
        let count = await bus.subscriberCount()
        XCTAssertEqual(count, 2)

        await bus.publish(
            domain: .situationField, payload: "shared")

        var iter1 = s1.events.makeAsyncIterator()
        var iter2 = s2.events.makeAsyncIterator()
        let e1 = await iter1.next()
        let e2 = await iter2.next()
        XCTAssertEqual(e1?.payload, "shared")
        XCTAssertEqual(e2?.payload, "shared")
        s1.close()
        s2.close()
    }

    func test_subscribeCanonicalUsesReadDomains() async {
        let bus = QinaoStateGraphBus()
        let sub = await bus.subscribeCanonical(
            seat: .sovereignSentinel)
        // Sovereign sentinel canonical reads include
        // actionPermit + sovereignWarrant.
        XCTAssertTrue(
            sub.domains.contains(.actionPermit))
        XCTAssertTrue(
            sub.domains.contains(.sovereignWarrant))
        sub.close()
    }

    func test_eventCodable() throws {
        let event = QinaoStateGraphEvent(
            domain: .candidateFrontier,
            payload: "pp",
            originAgent: .planner,
            sequence: 42)
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(
            QinaoStateGraphEvent.self, from: data)
        XCTAssertEqual(decoded, event)
    }
}
