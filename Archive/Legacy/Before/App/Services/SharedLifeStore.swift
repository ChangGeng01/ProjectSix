import Foundation

@MainActor
final class SharedLifeStore: ObservableObject {
    @Published private(set) var rules: [SharedLifeRule]
    @Published private(set) var boxItems: [SharedLifeBoxItem]

    private let storage: CodableStateStorage
    private let rulesKey: String
    private let boxKey: String
    private let seed: Bool

    init(
        storage: CodableStateStorage = .protectedLocal,
        rulesKey: String = "before.sharedlife.rules",
        boxKey: String = "before.sharedlife.box",
        seed: Bool = true
    ) {
        self.storage = storage
        self.rulesKey = rulesKey
        self.boxKey = boxKey
        self.seed = seed
        self.rules = storage.load([SharedLifeRule].self, key: rulesKey) ?? (seed ? Self.seededRules : [])
        self.boxItems = storage.load([SharedLifeBoxItem].self, key: boxKey) ?? (seed ? Self.seededBoxItems : [])
    }

    var enabledRules: [SharedLifeRule] {
        rules.filter(\.isEnabled)
    }

    var pendingItems: [SharedLifeBoxItem] {
        boxItems
            .filter { $0.status == .pending || $0.status == .reviewing || $0.status == .deferred }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var resolvedItems: [SharedLifeBoxItem] {
        boxItems
            .filter { $0.status == .approved || $0.status == .dropped }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func insert(_ item: SharedLifeBoxItem) {
        boxItems.removeAll { $0.id == item.id }
        boxItems.insert(item, at: 0)
        persistBox()
    }

    func removeItem(_ itemID: UUID) {
        boxItems.removeAll { $0.id == itemID }
        persistBox()
    }

    func upsertRule(_ rule: SharedLifeRule) {
        rules.removeAll { $0.id == rule.id }
        rules.insert(rule, at: 0)
        persistRules()
    }

    func removeRule(_ ruleID: UUID) {
        rules.removeAll { $0.id == ruleID }
        persistRules()
    }

    func toggleRule(_ ruleID: UUID) {
        guard let index = rules.firstIndex(where: { $0.id == ruleID }) else { return }
        rules[index].isEnabled.toggle()
        rules[index].updatedAt = .now
        persistRules()
    }

    func approve(_ itemID: UUID) {
        update(itemID, status: .approved)
    }

    func markReviewing(_ itemID: UUID) {
        update(itemID, status: .reviewing)
    }

    func deferItem(_ itemID: UUID) {
        update(itemID, status: .deferred)
    }

    func drop(_ itemID: UUID) {
        update(itemID, status: .dropped)
    }

    func clearAll() {
        rules = seed ? Self.seededRules : []
        boxItems = seed ? Self.seededBoxItems : []
        persistRules()
        persistBox()
    }

    private func update(_ itemID: UUID, status: SharedLifeBoxStatus) {
        guard let index = boxItems.firstIndex(where: { $0.id == itemID }) else { return }
        boxItems[index].status = status
        boxItems[index].updatedAt = .now
        persistBox()
    }

    private func persistRules() {
        storage.save(rules, key: rulesKey)
    }

    private func persistBox() {
        storage.save(boxItems, key: boxKey)
    }

    private static let seededRules: [SharedLifeRule] = [
        SharedLifeRule(
            kind: .budget,
            title: "Pause non-essential spends over the shared threshold",
            detail: "If it is not urgent, let it sit for a day before deciding together.",
            isEnabled: true,
            isSeeded: true
        ),
        SharedLifeRule(
            kind: .delivery,
            title: "Late-night delivery gets a second check",
            detail: "If it is after 9pm, ask whether this is hunger, stress, or convenience.",
            isEnabled: true,
            isSeeded: true
        ),
        SharedLifeRule(
            kind: .sleep,
            title: "Protect tomorrow more than tonight's drift",
            detail: "After midnight, treat 'just one more' as a decision, not a default.",
            isEnabled: false,
            isSeeded: true
        )
    ]

    private static let seededBoxItems: [SharedLifeBoxItem] = [
        SharedLifeBoxItem(
            createdAt: Date(timeIntervalSinceNow: -4_000),
            updatedAt: Date(timeIntervalSinceNow: -3_800),
            title: "Upgrade the headphones this month?",
            detail: "Shared budget question, not just a solo reward.",
            status: .pending,
            isSeeded: true
        ),
        SharedLifeBoxItem(
            createdAt: Date(timeIntervalSinceNow: -9_000),
            updatedAt: Date(timeIntervalSinceNow: -8_400),
            title: "Friday delivery fallback",
            detail: "Keep one low-effort option before defaulting to expensive delivery.",
            status: .approved,
            isSeeded: true
        )
    ]
}
