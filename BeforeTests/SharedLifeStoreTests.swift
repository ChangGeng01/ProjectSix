import XCTest
@testable import Before

@MainActor
final class SharedLifeStoreTests: XCTestCase {
    func testSeededStoreStartsWithRulesAndBoxItems() {
        let storage = makeIsolatedStorage()
        let store = SharedLifeStore(
            defaults: storage.defaults,
            rulesKey: storage.rulesKey,
            boxKey: storage.boxKey
        )

        XCTAssertFalse(store.rules.isEmpty)
        XCTAssertFalse(store.boxItems.isEmpty)
        XCTAssertGreaterThanOrEqual(store.enabledRules.count, 1)
    }

    func testToggleAndStatusChangesPersistAcrossInstances() throws {
        let storage = makeIsolatedStorage()
        let first = SharedLifeStore(
            defaults: storage.defaults,
            rulesKey: storage.rulesKey,
            boxKey: storage.boxKey,
            seed: false
        )

        let rule = SharedLifeRule(
            kind: .budget,
            title: "Pause bigger shared spends",
            detail: "Wait a day before saying yes."
        )
        let item = SharedLifeBoxItem(
            title: "Should we upgrade the desk?",
            detail: "This touches the shared budget."
        )

        first.upsertRule(rule)
        first.insert(item)
        first.toggleRule(rule.id)
        first.markReviewing(item.id)

        let second = SharedLifeStore(
            defaults: storage.defaults,
            rulesKey: storage.rulesKey,
            boxKey: storage.boxKey,
            seed: false
        )

        XCTAssertEqual(second.rules.first?.isEnabled, false)
        XCTAssertEqual(second.boxItems.first?.status, .reviewing)
        XCTAssertEqual(second.pendingItems.first?.status, .reviewing)
    }

    func testClearAllResetsToConfiguredSeedChoice() {
        let storage = makeIsolatedStorage()
        let store = SharedLifeStore(
            defaults: storage.defaults,
            rulesKey: storage.rulesKey,
            boxKey: storage.boxKey,
            seed: false
        )

        store.insert(SharedLifeBoxItem(title: "Should we keep this subscription?", detail: "Shared monthly spend."))
        store.clearAll()

        XCTAssertTrue(store.rules.isEmpty)
        XCTAssertTrue(store.boxItems.isEmpty)
    }

    func testUpsertRuleReplacesExistingRuleInsteadOfDuplicatingIt() {
        let storage = makeIsolatedStorage()
        let store = SharedLifeStore(
            defaults: storage.defaults,
            rulesKey: storage.rulesKey,
            boxKey: storage.boxKey,
            seed: false
        )

        let original = SharedLifeRule(
            kind: .screen,
            title: "Pause late-night scrolling",
            detail: "Treat drift as a decision."
        )

        store.upsertRule(original)

        let updated = SharedLifeRule(
            id: original.id,
            createdAt: original.createdAt,
            updatedAt: .now,
            kind: .screen,
            title: "Pause late-night screen drift",
            detail: "Call it out before it turns into an hour.",
            isEnabled: false
        )

        store.upsertRule(updated)

        XCTAssertEqual(store.rules.count, 1)
        XCTAssertEqual(store.rules.first?.title, "Pause late-night screen drift")
        XCTAssertEqual(store.rules.first?.isEnabled, false)
    }

    func testRemoveRuleDeletesCustomRule() {
        let storage = makeIsolatedStorage()
        let store = SharedLifeStore(
            defaults: storage.defaults,
            rulesKey: storage.rulesKey,
            boxKey: storage.boxKey,
            seed: false
        )

        let rule = SharedLifeRule(
            kind: .delivery,
            title: "Name the real need first",
            detail: "Hunger, stress, or convenience?"
        )

        store.upsertRule(rule)
        store.removeRule(rule.id)

        XCTAssertTrue(store.rules.isEmpty)
    }

    func testRemovingCustomRuleAndItemPersists() {
        let storage = makeIsolatedStorage()
        let first = SharedLifeStore(
            defaults: storage.defaults,
            rulesKey: storage.rulesKey,
            boxKey: storage.boxKey,
            seed: false
        )

        let rule = SharedLifeRule(
            kind: .screen,
            title: "Pause doomscrolling after midnight",
            detail: "If it is late, name the cost before continuing."
        )
        let item = SharedLifeBoxItem(
            title: "Keep the extra subscription?",
            detail: "This is shared recurring spend."
        )

        first.upsertRule(rule)
        first.insert(item)
        first.removeRule(rule.id)
        first.removeItem(item.id)

        let second = SharedLifeStore(
            defaults: storage.defaults,
            rulesKey: storage.rulesKey,
            boxKey: storage.boxKey,
            seed: false
        )

        XCTAssertFalse(second.rules.contains(where: { $0.id == rule.id }))
        XCTAssertFalse(second.boxItems.contains(where: { $0.id == item.id }))
    }

    private func makeIsolatedStorage() -> (defaults: UserDefaults, rulesKey: String, boxKey: String) {
        let suite = "before.tests.sharedlife.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suite)
        }
        return (defaults, "\(suite).rules", "\(suite).box")
    }
}
