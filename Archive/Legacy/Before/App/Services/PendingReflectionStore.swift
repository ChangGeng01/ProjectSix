import Foundation

enum PendingReflectionStore {
    private static let key = "before.pending.reflection.state"
    private static let storage = CodableStateStorage.protectedLocal

    static func load(now: Date = .now) -> PendingReflectionState {
        guard let state = storage.load(PendingReflectionState.self, key: key) else {
            return PendingReflectionState(context: nil, shouldPromptOnNextActive: false)
        }

        guard !state.isExpired(relativeTo: now) else {
            clear()
            return PendingReflectionState(context: nil, shouldPromptOnNextActive: false)
        }

        return state
    }

    static func save(_ state: PendingReflectionState) {
        storage.save(state, key: key)
    }

    static func clear() {
        storage.clear(key: key)
    }
}
