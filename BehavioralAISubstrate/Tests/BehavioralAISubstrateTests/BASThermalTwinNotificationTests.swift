import XCTest
@testable import BASLeaseLife

/// M216 — BASThermalTwin reacts to
/// `ProcessInfo.thermalStateDidChangeNotification` automatically.
///
/// ## Why this exists
///
/// `BASThermalTwin.defaultReader` already polls
/// `ProcessInfo.processInfo.thermalState` — but only when
/// `sample()` is explicitly called. On a real device the OS emits
/// `ProcessInfo.thermalStateDidChangeNotification` whenever the
/// thermal state actually changes; pre-M216 nothing was listening.
/// Hosts had to roll their own polling loop or set up the
/// notification observer themselves.
///
/// M216 adds `startObservingSystemNotifications(...)` /
/// `stopObservingSystemNotifications()`. Tests post synthetic
/// notifications onto a private `NotificationCenter` and verify
/// the twin auto-samples + yields a fresh reading to subscribers.
///
/// ## Why a private NotificationCenter
///
/// `NotificationCenter.default` is process-wide; posting test
/// notifications onto it would cross-talk with anything else
/// listening (other tests, the runtime, system services). The
/// twin's API takes an injected `notificationCenter` parameter so
/// tests own a fresh `NotificationCenter()` per test method.
@available(macOS 12, iOS 15, *)
final class BASThermalTwinNotificationTests: XCTestCase {

    /// Reader that returns whatever the test sets via the
    /// shared box. Lets tests "change the thermal state" between
    /// notification posts.
    private final class ReaderBox: @unchecked Sendable {
        private let lock = NSLock()
        private var value: BASThermalTwin.OSThermalState =
            .nominal
        func set(_ v: BASThermalTwin.OSThermalState) {
            lock.lock(); defer { lock.unlock() }
            value = v
        }
        func get() -> BASThermalTwin.OSThermalState {
            lock.lock(); defer { lock.unlock() }
            return value
        }
    }

    /// M269 — bounded-wait wrapper around an async producer.
    /// When CI / dev machines have a flaky `NotificationCenter`
    /// XPC stack (e.g. AddressBook CoreData crashes leak into
    /// system notification delivery), the
    /// `iterator.next()` call hung indefinitely. This helper
    /// races the producer against a short timer; the test gets
    /// `nil` if the timer wins so it can skip rather than hang
    /// the whole test bundle.
    private func awaitWithTimeout<T: Sendable>(
        _ description: String,
        timeout: TimeInterval = 2.0,
        op: @escaping @Sendable () async -> T?
    ) async -> T? {
        // Two tasks: one runs the producer, one sleeps for the
        // timeout. The first to finish wins.
        await withTaskGroup(of: T?.self) { group in
            group.addTask { await op() }
            group.addTask {
                try? await Task.sleep(
                    nanoseconds: UInt64(
                        timeout * 1_000_000_000))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    /// The reading MUST arrive — was `skipIfStackFlaky`, which skipped whenever it was nil
    /// while claiming "Pre-existing system flake — not a substrate regression".
    ///
    /// That claim was FALSE and the skip hid a real defect. These tests post onto a PRIVATE,
    /// in-process NotificationCenter — no XPC, no OS stack — and normally complete in ~86ms,
    /// so a >2s timeout is a HANG, not slowness. The hang was a race in the production API:
    /// `startObservingSystemNotifications` spawned a Task and returned BEFORE the observer
    /// attached, so a post in that window was lost (reproduced ~1 run in 3). Fixed at the
    /// source — the observer now registers synchronously — and measured 6/6 clean at ~86ms.
    ///
    /// A missing reading now means the twin genuinely failed to observe or sample: FAIL.
    private func requireReading(
        _ received: BASThermalTwin.Reading?,
        file: StaticString = #filePath, line: UInt = #line
    ) throws {
        _ = try XCTUnwrap(
            received,
            "the twin did not auto-sample within the timeout. The observer attaches "
            + "synchronously now, so this is a real failure to observe/sample — not an "
            + "OS flake.",
            file: file, line: line)
    }

    // MARK: - 1. Posting a notification triggers sample()

    func testPostingNotificationTriggersSample() async throws {
        let box = ReaderBox()
        box.set(.nominal)
        let twin = BASThermalTwin(reader: { box.get() })
        let center = NotificationCenter()

        await twin.startObservingSystemNotifications(
            notificationCenter: center)

        // Subscribe BEFORE posting — under parallel test load,
        // sleep alone races with the observer Task's
        // notification-stream setup. Awaiting the next reading
        // on a subscriber stream is deterministic on healthy
        // systems; bounded by `awaitWithTimeout` below for the
        // pre-existing flaky-XPC case.
        let stream = await twin.subscribe()

        // Simulate thermal state changing on the OS:
        box.set(.fair)
        center.post(
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil)

        let received = await awaitWithTimeout("post-yields") {
            var iter = stream.makeAsyncIterator()
            return await iter.next()
        }
        try requireReading(received)
        XCTAssertEqual(received?.osState, .fair)

        await twin.stopObservingSystemNotifications()
    }

    // MARK: - 2. Subscriber receives the auto-sampled reading

    func testSubscriberReceivesAutoSampledReading() async throws {
        let box = ReaderBox()
        box.set(.nominal)
        let twin = BASThermalTwin(reader: { box.get() })
        let center = NotificationCenter()

        await twin.startObservingSystemNotifications(
            notificationCenter: center)

        // Subscribe BEFORE posting so we definitely catch the
        // emitted reading.
        let stream = await twin.subscribe()

        // Trigger a state change.
        box.set(.serious)
        center.post(
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil)

        // M269 — bounded wait so flaky XPC stack can't hang the
        // test bundle.
        let received = await awaitWithTimeout("auto-sampled") {
            var iter = stream.makeAsyncIterator()
            return await iter.next()
        }
        try requireReading(received)
        XCTAssertEqual(
            received?.osState, .serious,
            "subscriber must receive the post-notification " +
            "reading reflecting the new OS state")

        await twin.stopObservingSystemNotifications()
    }

    // MARK: - 3. Stop unsubscribes from notifications

    func testStopObservingHaltsAutoSampling() async throws {
        let box = ReaderBox()
        box.set(.nominal)
        let twin = BASThermalTwin(reader: { box.get() })
        let center = NotificationCenter()

        await twin.startObservingSystemNotifications(
            notificationCenter: center)

        // Subscribe BEFORE posting to deterministically wait for
        // the auto-sample reading. Using sleep alone races with
        // the observer Task's subscription setup.
        let stream = await twin.subscribe()

        // Trigger first state change.
        box.set(.fair)
        center.post(
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil)
        // M269 — bounded wait
        let first = await awaitWithTimeout("first-fair") {
            var iter = stream.makeAsyncIterator()
            return await iter.next()
        }
        try requireReading(first)
        XCTAssertEqual(
            first?.osState, .fair,
            "first post must yield .fair reading")

        // Stop observing.
        await twin.stopObservingSystemNotifications()
        let observing = await twin.isObservingSystemNotifications()
        XCTAssertFalse(observing)

        // Post another notification — must NOT update
        // currentReading.
        box.set(.critical)
        center.post(
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil)
        try await Task.sleep(nanoseconds: 50_000_000)

        let afterStop = await twin.currentReading()
        XCTAssertEqual(
            afterStop?.osState, .fair,
            "after stopObservingSystemNotifications, posts MUST " +
            "NOT update currentReading; got " +
            "\(String(describing: afterStop?.osState))")
    }

    // MARK: - 4. Idempotent start

    /// Calling start twice should cancel the first task before
    /// starting the second — so no zombie observer task remains.
    func testStartTwiceReplacesObserverTask() async throws {
        let box = ReaderBox()
        let twin = BASThermalTwin(reader: { box.get() })
        let centerA = NotificationCenter()
        let centerB = NotificationCenter()

        await twin.startObservingSystemNotifications(
            notificationCenter: centerA)
        // Replace the observer with one bound to centerB.
        await twin.startObservingSystemNotifications(
            notificationCenter: centerB)

        // Subscribe before posting; await on centerB to confirm
        // the active observer is centerB-bound.
        let stream = await twin.subscribe()

        // First post on centerA — should be ignored by the
        // current (centerB-bound) observer. We CAN'T await for
        // it via iterator (it never arrives), so we instead
        // post on centerB next and verify centerB's reading is
        // the FIRST one received.
        box.set(.fair)
        centerA.post(
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil)
        // Brief sleep so any (incorrect) cross-talk has time to
        // surface before we post on centerB.
        try await Task.sleep(nanoseconds: 30_000_000)

        // A post on centerB SHOULD trigger sample.
        box.set(.serious)
        centerB.post(
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil)
        // M269 — bounded wait
        let received = await awaitWithTimeout("centerB-yields") {
            var iter = stream.makeAsyncIterator()
            return await iter.next()
        }
        try requireReading(received)
        XCTAssertEqual(
            received?.osState, .serious,
            "first reading on subscriber stream MUST be from " +
            "centerB post (.serious); if it's .fair, centerA " +
            "leaked through and the start-twice replacement " +
            "rule is broken")

        await twin.stopObservingSystemNotifications()
    }

    // MARK: - 5. isObservingSystemNotifications flag

    func testIsObservingFlagTracksLifecycle() async throws {
        let twin = BASThermalTwin(reader: { .nominal })
        let center = NotificationCenter()

        var observing = await twin.isObservingSystemNotifications()
        XCTAssertFalse(observing, "initial state: not observing")

        await twin.startObservingSystemNotifications(
            notificationCenter: center)
        observing = await twin.isObservingSystemNotifications()
        XCTAssertTrue(
            observing, "after start: must report observing")

        await twin.stopObservingSystemNotifications()
        observing = await twin.isObservingSystemNotifications()
        XCTAssertFalse(
            observing, "after stop: must report not observing")
    }
}
