import Testing
@testable import Before

struct DeveloperCenterAccessGateTests {
    @Test
    func lockedGateCountsDownUntilUnlock() {
        let gate = DeveloperCenterAccessGate(unlockTapCount: 3)

        #expect(gate.handleTap(currentCount: 0, unlocked: false) == .progress(remainingTaps: 2))
        #expect(gate.handleTap(currentCount: 1, unlocked: false) == .progress(remainingTaps: 1))
        #expect(gate.handleTap(currentCount: 2, unlocked: false) == .unlocked)
    }

    @Test
    func unlockedGateOpensImmediately() {
        let gate = DeveloperCenterAccessGate(unlockTapCount: 7)

        #expect(gate.handleTap(currentCount: 0, unlocked: true) == .openExisting)
    }
}
