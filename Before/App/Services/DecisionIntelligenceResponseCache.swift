import Foundation

actor DecisionIntelligenceResponseCache {
    static let shared = DecisionIntelligenceResponseCache()

    private let limit: Int
    private var quickStorage: [String: QuickCheckResult] = [:]
    private var quickOrder: [String] = []
    private var balanceStorage: [String: BalanceBoardResult] = [:]
    private var balanceOrder: [String] = []
    private var mirrorStorage: [String: MirrorResult] = [:]
    private var mirrorOrder: [String] = []
    private var reminderStorage: [String: ReminderSelectionCandidate] = [:]
    private var reminderOrder: [String] = []

    init(limit: Int = BeforePolicy.Settings.intelligenceResponseCacheLimit) {
        self.limit = max(1, limit)
    }

    func quickResult(for key: String) -> QuickCheckResult? {
        cachedValue(for: key, storage: &quickStorage, order: &quickOrder)
    }

    func storeQuickResult(_ result: QuickCheckResult, for key: String) {
        storeValue(result, for: key, storage: &quickStorage, order: &quickOrder)
    }

    func balanceResult(for key: String) -> BalanceBoardResult? {
        cachedValue(for: key, storage: &balanceStorage, order: &balanceOrder)
    }

    func storeBalanceResult(_ result: BalanceBoardResult, for key: String) {
        storeValue(result, for: key, storage: &balanceStorage, order: &balanceOrder)
    }

    func mirrorResult(for key: String) -> MirrorResult? {
        cachedValue(for: key, storage: &mirrorStorage, order: &mirrorOrder)
    }

    func storeMirrorResult(_ result: MirrorResult, for key: String) {
        storeValue(result, for: key, storage: &mirrorStorage, order: &mirrorOrder)
    }

    func reminder(for key: String) -> ReminderSelectionCandidate? {
        cachedValue(for: key, storage: &reminderStorage, order: &reminderOrder)
    }

    func storeReminder(_ candidate: ReminderSelectionCandidate, for key: String) {
        storeValue(candidate, for: key, storage: &reminderStorage, order: &reminderOrder)
    }

    func clear() {
        quickStorage.removeAll()
        quickOrder.removeAll()
        balanceStorage.removeAll()
        balanceOrder.removeAll()
        mirrorStorage.removeAll()
        mirrorOrder.removeAll()
        reminderStorage.removeAll()
        reminderOrder.removeAll()
    }

    private func cachedValue<Value>(
        for key: String,
        storage: inout [String: Value],
        order: inout [String]
    ) -> Value? {
        guard let value = storage[key] else { return nil }
        touchKey(key, order: &order)
        return value
    }

    private func storeValue<Value>(
        _ value: Value,
        for key: String,
        storage: inout [String: Value],
        order: inout [String]
    ) {
        storage[key] = value
        touchKey(key, order: &order)

        while order.count > limit {
            let droppedKey = order.removeLast()
            storage.removeValue(forKey: droppedKey)
        }
    }

    private func touchKey(_ key: String, order: inout [String]) {
        order.removeAll { $0 == key }
        order.insert(key, at: 0)
    }
}
