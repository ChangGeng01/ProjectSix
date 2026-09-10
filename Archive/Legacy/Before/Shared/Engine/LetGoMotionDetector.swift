import Foundation

enum LetGoMotionDetector {
    static func detectDirection(
        sample: LetGoMotionSample,
        lastTriggeredAt: TimeInterval?,
        policy: BeforePolicy.LetGo.Type = BeforePolicy.LetGo.self
    ) -> LetGoFlickDirection? {
        if let lastTriggeredAt,
           sample.timestamp - lastTriggeredAt < policy.triggerCooldownInterval {
            return nil
        }

        let horizontal = abs(sample.x)
        let vertical = abs(sample.y)
        let depth = abs(sample.z)
        let largestOtherAxis = max(vertical, depth)

        guard horizontal >= policy.horizontalAccelerationThreshold else { return nil }
        guard horizontal >= largestOtherAxis * policy.directionalDominanceRatio else { return nil }

        return sample.x >= 0 ? .right : .left
    }
}
