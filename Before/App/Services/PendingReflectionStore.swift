import Foundation

enum PendingReflectionStore {
    private static let key = "before.pending.reflection.state"

    static func load() -> PendingReflectionState {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let state = try? JSONDecoder().decode(PendingReflectionState.self, from: data)
        else {
            return PendingReflectionState(context: nil, shouldPromptOnNextActive: false)
        }

        return state
    }

    static func save(_ state: PendingReflectionState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
