import XCTest
@testable import Before

final class LetGoMotionDetectorTests: XCTestCase {
    func testDetectsSingleStrongHorizontalFlick() {
        let direction = LetGoMotionDetector.detectDirection(
            sample: LetGoMotionSample(
                x: 1.42,
                y: 0.22,
                z: 0.18,
                timestamp: 10
            ),
            lastTriggeredAt: nil
        )

        XCTAssertEqual(direction, .right)
    }

    func testIgnoresVerticalDominantMotion() {
        let direction = LetGoMotionDetector.detectDirection(
            sample: LetGoMotionSample(
                x: 1.20,
                y: 1.12,
                z: 0.10,
                timestamp: 10
            ),
            lastTriggeredAt: nil
        )

        XCTAssertNil(direction)
    }

    func testRespectsCooldownWindow() {
        let direction = LetGoMotionDetector.detectDirection(
            sample: LetGoMotionSample(
                x: -1.35,
                y: 0.14,
                z: 0.08,
                timestamp: 10.2
            ),
            lastTriggeredAt: 10
        )

        XCTAssertNil(direction)
    }
}
