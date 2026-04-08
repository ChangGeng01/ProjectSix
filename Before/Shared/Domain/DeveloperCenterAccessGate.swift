import Foundation

enum DeveloperCenterAccessOutcome: Equatable {
    case progress(remainingTaps: Int)
    case unlocked
    case openExisting
}

struct DeveloperCenterAccessGate {
    let unlockTapCount: Int

    init(unlockTapCount: Int = BeforePolicy.Settings.developerCenterUnlockTapCount) {
        self.unlockTapCount = unlockTapCount
    }

    func handleTap(currentCount: Int, unlocked: Bool) -> DeveloperCenterAccessOutcome {
        guard !unlocked else { return .openExisting }

        let nextCount = currentCount + 1
        if nextCount >= unlockTapCount {
            return .unlocked
        }

        return .progress(remainingTaps: unlockTapCount - nextCount)
    }
}
