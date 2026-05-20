@preconcurrency import CoreMotion
import Foundation

@MainActor
final class LetGoMotionMonitor: ObservableObject {
    @Published private(set) var isAvailable = false

    private let motionManager: CMMotionManager
    private var lastTriggeredAt: TimeInterval?
    private var onTrigger: ((LetGoFlickDirection) -> Void)?

    init(motionManager: CMMotionManager = CMMotionManager()) {
        self.motionManager = motionManager
        self.isAvailable = motionManager.isDeviceMotionAvailable
    }

    func start(onTrigger: @escaping (LetGoFlickDirection) -> Void) {
        stop()

        guard motionManager.isDeviceMotionAvailable else {
            isAvailable = false
            return
        }

        isAvailable = true
        self.onTrigger = onTrigger
        lastTriggeredAt = nil
        motionManager.deviceMotionUpdateInterval = BeforePolicy.LetGo.motionUpdateInterval
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }

            let sample = LetGoMotionSample(
                x: motion.userAcceleration.x,
                y: motion.userAcceleration.y,
                z: motion.userAcceleration.z,
                timestamp: ProcessInfo.processInfo.systemUptime
            )

            guard let direction = LetGoMotionDetector.detectDirection(
                sample: sample,
                lastTriggeredAt: self.lastTriggeredAt
            ) else {
                return
            }

            self.lastTriggeredAt = sample.timestamp
            let callback = self.onTrigger
            self.stop()
            callback?(direction)
        }
    }

    func stop() {
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
        onTrigger = nil
    }
}
