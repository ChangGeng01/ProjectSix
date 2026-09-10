import XCTest
@testable import QinaoSeats

/// M292.1 — typed seat scaffold contract tests.
///
/// Doctrine pinned by these tests:
/// - `QinaoSeat` has exactly 9 cases (manifest v2 第八节 council size)
/// - Raw values are stable strings (Codable + audit keys)
/// - All cases unique (no shadow seat)
/// - `SeatVerdict.urgency` clamped to [0,1] on construction
/// - `SeatVerdict` Codable round-trip preserves shape
final class QinaoSeatsTests: XCTestCase {

    // MARK: - Council size

    func test_seatEnumHas9Cases() {
        XCTAssertEqual(
            QinaoSeat.allCases.count, 9,
            "manifest v2 第八节 lists 9 seats; silent expansion/" +
            "contraction must be caught")
    }

    func test_seatEnumAllCasesAreDistinct() {
        let raws = QinaoSeat.allCases.map(\.rawValue)
        XCTAssertEqual(Set(raws).count, raws.count)
    }

    // MARK: - Raw value stability

    func test_seatRawValuesArePinned() {
        XCTAssertEqual(QinaoSeat.scout.rawValue, "scout")
        XCTAssertEqual(QinaoSeat.memory.rawValue, "memory")
        XCTAssertEqual(QinaoSeat.planner.rawValue, "planner")
        XCTAssertEqual(QinaoSeat.critic.rawValue, "critic")
        XCTAssertEqual(
            QinaoSeat.hostAlignment.rawValue, "hostAlignment")
        XCTAssertEqual(QinaoSeat.risk.rawValue, "risk")
        XCTAssertEqual(QinaoSeat.surface.rawValue, "surface")
        XCTAssertEqual(
            QinaoSeat.sovereignSentinel.rawValue,
            "sovereignSentinel")
        XCTAssertEqual(
            QinaoSeat.evolutionShadow.rawValue,
            "evolutionShadow")
    }

    // MARK: - SeatVerdict construction

    func test_verdictUrgencyClampedAtConstruction() {
        let high = SeatVerdict(seat: .scout, urgency: 1.5)
        XCTAssertEqual(high.urgency, 1.0, accuracy: 1e-9)

        let low = SeatVerdict(seat: .scout, urgency: -0.3)
        XCTAssertEqual(low.urgency, 0.0, accuracy: 1e-9)

        let mid = SeatVerdict(seat: .scout, urgency: 0.42)
        XCTAssertEqual(mid.urgency, 0.42, accuracy: 1e-9)
    }

    func test_verdictDefaultReasonCodesAndNoteAreEmpty() {
        let v = SeatVerdict(seat: .risk, urgency: 0.5)
        XCTAssertEqual(v.reasonCodes, [])
        XCTAssertEqual(v.note, "")
    }

    func test_verdictHoldsReasonCodesAndNote() {
        let v = SeatVerdict(
            seat: .risk,
            urgency: 0.7,
            reasonCodes: ["manipulation-risk", "boundary-conflict"],
            note: "watch ultimatum framing")
        XCTAssertEqual(
            v.reasonCodes,
            ["manipulation-risk", "boundary-conflict"])
        XCTAssertEqual(v.note, "watch ultimatum framing")
    }

    // MARK: - Codable round-trip

    func test_verdictCodableRoundTrip() throws {
        let original = SeatVerdict(
            seat: .sovereignSentinel,
            urgency: 0.8,
            reasonCodes: ["warrant-tampering"],
            note: "halt requested")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            SeatVerdict.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_seatCodableRoundTripForEveryCase() throws {
        for seat in QinaoSeat.allCases {
            let data = try JSONEncoder().encode(seat)
            let decoded = try JSONDecoder().decode(
                QinaoSeat.self, from: data)
            XCTAssertEqual(decoded, seat)
        }
    }
}
