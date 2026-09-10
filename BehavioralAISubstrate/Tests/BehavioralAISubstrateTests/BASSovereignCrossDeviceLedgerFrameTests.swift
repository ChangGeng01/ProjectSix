import XCTest
@testable import BASSovereign

/// M296.3.x — cross-device ledger frame contract tests.
///
/// Doctrine pinned:
/// - Frame carries auditEntryRef + originDeviceID + clock
/// - `compare(to:)` delegates to the clock's compare
/// - Codable + Hashable round-trip preserve the frame
final class BASSovereignCrossDeviceLedgerFrameTests: XCTestCase {

    private func makeFrame(
        ref: String,
        device: String,
        counters: [String: UInt64]
    ) -> BASSovereignCrossDeviceLedgerFrame {
        BASSovereignCrossDeviceLedgerFrame(
            auditEntryRef: ref,
            originDeviceID: device,
            clock: BASSovereignCrossDeviceClock(
                deviceCounters: counters))
    }

    // MARK: - Field preservation

    func test_frameFieldsPreserved() {
        let f = makeFrame(
            ref: "audit-001",
            device: "device-A",
            counters: ["device-A": 3])
        XCTAssertEqual(f.auditEntryRef, "audit-001")
        XCTAssertEqual(f.originDeviceID, "device-A")
        XCTAssertEqual(f.clock.counter(for: "device-A"), 3)
    }

    // MARK: - compare delegates to clock

    func test_compareEqualWhenClocksEqual() {
        let a = makeFrame(
            ref: "x", device: "A",
            counters: ["A": 1, "B": 2])
        let b = makeFrame(
            ref: "y", device: "B",
            counters: ["A": 1, "B": 2])
        XCTAssertEqual(a.compare(to: b), .equal)
    }

    func test_compareBefore() {
        let a = makeFrame(
            ref: "x", device: "A",
            counters: ["A": 1])
        let b = makeFrame(
            ref: "y", device: "B",
            counters: ["A": 2, "B": 1])
        XCTAssertEqual(a.compare(to: b), .before)
    }

    func test_compareAfter() {
        let a = makeFrame(
            ref: "x", device: "A",
            counters: ["A": 5, "B": 5])
        let b = makeFrame(
            ref: "y", device: "B",
            counters: ["A": 2, "B": 3])
        XCTAssertEqual(a.compare(to: b), .after)
    }

    func test_compareConcurrent() {
        let a = makeFrame(
            ref: "x", device: "A",
            counters: ["A": 5, "B": 1])
        let b = makeFrame(
            ref: "y", device: "B",
            counters: ["A": 2, "B": 4])
        XCTAssertEqual(a.compare(to: b), .concurrent)
    }

    // MARK: - Codable round-trip

    func test_codableRoundTrip() throws {
        let original = makeFrame(
            ref: "audit-42",
            device: "device-A",
            counters: ["device-A": 5, "device-B": 3])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASSovereignCrossDeviceLedgerFrame.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Hashable

    func test_hashableForSetUsage() {
        let a = makeFrame(
            ref: "audit-1",
            device: "A",
            counters: ["A": 1])
        let dup = makeFrame(
            ref: "audit-1",
            device: "A",
            counters: ["A": 1])
        let other = makeFrame(
            ref: "audit-1",
            device: "A",
            counters: ["A": 2])
        let set: Set<BASSovereignCrossDeviceLedgerFrame> =
            [a, dup, other]
        XCTAssertEqual(set.count, 2) // a == dup
    }

    // MARK: - origin asc tiebreak (caller-side, doctrine pin)

    func test_concurrentFramesCanBeBrokenByOriginAsc() {
        // Doctrine: when compare returns .concurrent, sync
        // protocols may use originDeviceID ASC as tiebreak.
        // The frame doesn't enforce this — but the field is
        // there to support it.
        let a = makeFrame(
            ref: "x", device: "A",
            counters: ["A": 5, "B": 1])
        let b = makeFrame(
            ref: "y", device: "B",
            counters: ["A": 2, "B": 4])
        XCTAssertEqual(a.compare(to: b), .concurrent)
        // Caller-side tiebreak: ASC origin → A first.
        let frames = [b, a].sorted {
            $0.originDeviceID < $1.originDeviceID
        }
        XCTAssertEqual(frames.first?.originDeviceID, "A")
    }
}
