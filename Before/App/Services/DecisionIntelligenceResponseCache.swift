import Foundation

struct DecisionIntelligenceCacheTelemetrySnapshot: Equatable, Sendable {
    let entryCountByKind: [DecisionIntelligenceTraceKind: Int]
    let hitCountByKind: [DecisionIntelligenceTraceKind: Int]
    let missCountByKind: [DecisionIntelligenceTraceKind: Int]
    let storeCountByKind: [DecisionIntelligenceTraceKind: Int]
    let evictionCountByKind: [DecisionIntelligenceTraceKind: Int]
    let rejectedStoreCountByKind: [DecisionIntelligenceTraceKind: Int]
    let quarantinedHitCountByKind: [DecisionIntelligenceTraceKind: Int]

    var totalHits: Int {
        hitCountByKind.values.reduce(0, +)
    }

    var totalMisses: Int {
        missCountByKind.values.reduce(0, +)
    }

    var totalStores: Int {
        storeCountByKind.values.reduce(0, +)
    }

    var totalEvictions: Int {
        evictionCountByKind.values.reduce(0, +)
    }

    var totalRejectedStores: Int {
        rejectedStoreCountByKind.values.reduce(0, +)
    }

    var totalQuarantinedHits: Int {
        quarantinedHitCountByKind.values.reduce(0, +)
    }
}

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
    private var hitCountByKind: [DecisionIntelligenceTraceKind: Int] = [:]
    private var missCountByKind: [DecisionIntelligenceTraceKind: Int] = [:]
    private var storeCountByKind: [DecisionIntelligenceTraceKind: Int] = [:]
    private var evictionCountByKind: [DecisionIntelligenceTraceKind: Int] = [:]
    private var rejectedStoreCountByKind: [DecisionIntelligenceTraceKind: Int] = [:]
    private var quarantinedHitCountByKind: [DecisionIntelligenceTraceKind: Int] = [:]

    init(limit: Int = BeforePolicy.Settings.intelligenceResponseCacheLimit) {
        self.limit = max(1, limit)
    }

    func quickResult(for key: String) -> QuickCheckResult? {
        cachedValue(
            for: key,
            kind: .quick,
            storage: &quickStorage,
            order: &quickOrder,
            validator: DecisionIntelligenceCacheGuard.validate
        )
    }

    func storeQuickResult(_ result: QuickCheckResult, for key: String) {
        storeValue(
            result,
            for: key,
            kind: .quick,
            storage: &quickStorage,
            order: &quickOrder,
            validator: DecisionIntelligenceCacheGuard.validate
        )
    }

    func quarantineQuickResult(for key: String) {
        quarantineValue(
            for: key,
            kind: .quick,
            storage: &quickStorage,
            order: &quickOrder
        )
    }

    func balanceResult(for key: String) -> BalanceBoardResult? {
        cachedValue(
            for: key,
            kind: .balance,
            storage: &balanceStorage,
            order: &balanceOrder,
            validator: DecisionIntelligenceCacheGuard.validate
        )
    }

    func storeBalanceResult(_ result: BalanceBoardResult, for key: String) {
        storeValue(
            result,
            for: key,
            kind: .balance,
            storage: &balanceStorage,
            order: &balanceOrder,
            validator: DecisionIntelligenceCacheGuard.validate
        )
    }

    func quarantineBalanceResult(for key: String) {
        quarantineValue(
            for: key,
            kind: .balance,
            storage: &balanceStorage,
            order: &balanceOrder
        )
    }

    func mirrorResult(for key: String) -> MirrorResult? {
        cachedValue(
            for: key,
            kind: .mirror,
            storage: &mirrorStorage,
            order: &mirrorOrder,
            validator: DecisionIntelligenceCacheGuard.validate
        )
    }

    func storeMirrorResult(_ result: MirrorResult, for key: String) {
        storeValue(
            result,
            for: key,
            kind: .mirror,
            storage: &mirrorStorage,
            order: &mirrorOrder,
            validator: DecisionIntelligenceCacheGuard.validate
        )
    }

    func quarantineMirrorResult(for key: String) {
        quarantineValue(
            for: key,
            kind: .mirror,
            storage: &mirrorStorage,
            order: &mirrorOrder
        )
    }

    func reminder(for key: String) -> ReminderSelectionCandidate? {
        cachedValue(
            for: key,
            kind: .reminder,
            storage: &reminderStorage,
            order: &reminderOrder,
            validator: DecisionIntelligenceCacheGuard.validate
        )
    }

    func storeReminder(_ candidate: ReminderSelectionCandidate, for key: String) {
        storeValue(
            candidate,
            for: key,
            kind: .reminder,
            storage: &reminderStorage,
            order: &reminderOrder,
            validator: DecisionIntelligenceCacheGuard.validate
        )
    }

    func quarantineReminder(for key: String) {
        quarantineValue(
            for: key,
            kind: .reminder,
            storage: &reminderStorage,
            order: &reminderOrder
        )
    }

    func telemetrySnapshot() -> DecisionIntelligenceCacheTelemetrySnapshot {
        DecisionIntelligenceCacheTelemetrySnapshot(
            entryCountByKind: [
                .quick: quickStorage.count,
                .balance: balanceStorage.count,
                .mirror: mirrorStorage.count,
                .reminder: reminderStorage.count
            ],
            hitCountByKind: hitCountByKind,
            missCountByKind: missCountByKind,
            storeCountByKind: storeCountByKind,
            evictionCountByKind: evictionCountByKind,
            rejectedStoreCountByKind: rejectedStoreCountByKind,
            quarantinedHitCountByKind: quarantinedHitCountByKind
        )
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
        hitCountByKind.removeAll()
        missCountByKind.removeAll()
        storeCountByKind.removeAll()
        evictionCountByKind.removeAll()
        rejectedStoreCountByKind.removeAll()
        quarantinedHitCountByKind.removeAll()
    }

    private func cachedValue<Value>(
        for key: String,
        kind: DecisionIntelligenceTraceKind,
        storage: inout [String: Value],
        order: inout [String],
        validator: (Value) -> DecisionIntelligenceCacheGuardReason?
    ) -> Value? {
        guard let value = storage[key] else {
            missCountByKind[kind, default: 0] += 1
            return nil
        }
        if validator(value) != nil {
            storage.removeValue(forKey: key)
            order.removeAll { $0 == key }
            quarantinedHitCountByKind[kind, default: 0] += 1
            missCountByKind[kind, default: 0] += 1
            return nil
        }
        hitCountByKind[kind, default: 0] += 1
        touchKey(key, order: &order)
        return value
    }

    private func storeValue<Value>(
        _ value: Value,
        for key: String,
        kind: DecisionIntelligenceTraceKind,
        storage: inout [String: Value],
        order: inout [String],
        validator: (Value) -> DecisionIntelligenceCacheGuardReason?
    ) {
        if validator(value) != nil {
            rejectedStoreCountByKind[kind, default: 0] += 1
            return
        }
        storage[key] = value
        storeCountByKind[kind, default: 0] += 1
        touchKey(key, order: &order)

        while order.count > limit {
            let droppedKey = order.removeLast()
            storage.removeValue(forKey: droppedKey)
            evictionCountByKind[kind, default: 0] += 1
        }
    }

    private func touchKey(_ key: String, order: inout [String]) {
        order.removeAll { $0 == key }
        order.insert(key, at: 0)
    }

    private func quarantineValue<Value>(
        for key: String,
        kind: DecisionIntelligenceTraceKind,
        storage: inout [String: Value],
        order: inout [String]
    ) {
        guard storage.removeValue(forKey: key) != nil else { return }
        order.removeAll { $0 == key }
        quarantinedHitCountByKind[kind, default: 0] += 1
    }
}
