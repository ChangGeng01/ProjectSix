import Foundation
import BASHostKit

struct DecisionEvolutionKillSwitchPolicy: Codable, Equatable, Sendable {
    static let currentSchemaVersion = "1.1.0"

    var schemaVersion: String
    var activeKillSwitchIDs: [String]
    var updatedAt: Date

    init(
        schemaVersion: String = DecisionEvolutionKillSwitchPolicy.currentSchemaVersion,
        activeKillSwitchIDs: [String] = [],
        updatedAt: Date = .now
    ) {
        self.schemaVersion = schemaVersion
        self.activeKillSwitchIDs = activeKillSwitchIDs
        self.updatedAt = updatedAt
    }
}

enum DecisionEvolutionKillSwitchStore {
    private static let defaultsKey = "before.evolutionKillSwitchPolicy"

    static func load(defaults: UserDefaults = .standard) -> [BASKillSwitchID] {
        guard let data = defaults.data(forKey: defaultsKey),
              let policy = try? JSONDecoder().decode(DecisionEvolutionKillSwitchPolicy.self, from: data) else {
            return []
        }

        return BASKillSwitchID.resolvePolicyIDs(policy.activeKillSwitchIDs)
    }

    static func save(
        _ killSwitches: [BASKillSwitchID],
        defaults: UserDefaults = .standard,
        now: Date = .now
    ) {
        let policy = DecisionEvolutionKillSwitchPolicy(
            activeKillSwitchIDs: orderedUnique(killSwitches).map(\.rawValue),
            updatedAt: now
        )
        guard let data = try? JSONEncoder().encode(policy) else { return }
        defaults.set(data, forKey: defaultsKey)
    }

    static func setEnabled(
        _ killSwitch: BASKillSwitchID,
        enabled: Bool,
        defaults: UserDefaults = .standard,
        now: Date = .now
    ) -> [BASKillSwitchID] {
        var activeKillSwitches = load(defaults: defaults)

        if enabled {
            activeKillSwitches = orderedUnique(activeKillSwitches + [killSwitch])
        } else {
            activeKillSwitches.removeAll { $0 == killSwitch }
        }

        save(activeKillSwitches, defaults: defaults, now: now)
        return activeKillSwitches
    }

    static func clear(
        defaults: UserDefaults = .standard,
        now: Date = .now
    ) {
        save([], defaults: defaults, now: now)
    }

    private static func orderedUnique(_ values: [BASKillSwitchID]) -> [BASKillSwitchID] {
        var seen = Set<BASKillSwitchID>()
        return values.filter { seen.insert($0).inserted }
    }
}

extension BASKillSwitchID {
    var displayTitle: String {
        switch self {
        case .forceGuardMode:
            "Force guard mode"
        case .disableFastPath:
            "Disable fast path"
        case .requireReviewedWrites:
            "Require reviewed writes"
        case .forceProtectedPermit:
            "Force protective permit"
        }
    }

    var detail: String {
        switch self {
        case .forceGuardMode:
            "Escalate the budget into guarded mode before the dream loop runs."
        case .disableFastPath:
            "Prevent sentinel fast-path execution and route work through a fuller runtime path."
        case .requireReviewedWrites:
            "Force every long-term write suggestion back through review before it can persist."
        case .forceProtectedPermit:
            "Downgrade direct answer modes into protected output modes when needed."
        }
    }
}
