import Foundation

public struct BASCurrentBrainUpdatePersistenceInput: Codable, Sendable, Equatable {
    public var mode: String
    public var dominantGoal: String?
    public var dominantReactionWeight: String
    public var fingerprint: String
    public var activeConstraints: [String]
    public var activeTemplateIDs: [String]
    public var failureGuardIDs: [String]

    public init(
        mode: String,
        dominantGoal: String?,
        dominantReactionWeight: String,
        fingerprint: String,
        activeConstraints: [String],
        activeTemplateIDs: [String],
        failureGuardIDs: [String]
    ) {
        self.mode = mode
        self.dominantGoal = dominantGoal
        self.dominantReactionWeight = dominantReactionWeight
        self.fingerprint = fingerprint
        self.activeConstraints = activeConstraints
        self.activeTemplateIDs = activeTemplateIDs
        self.failureGuardIDs = failureGuardIDs
    }
}

public struct BASCurrentBrainUpdateStoredFields: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var createdAt: Date
    public var source: String
    public var mode: String
    public var dominantGoal: String?
    public var dominantReactionWeight: String
    public var fingerprint: String
    public var activeConstraints: [String]
    public var activeTemplateIDs: [String]
    public var failureGuardIDs: [String]

    public init(
        id: UUID = UUID(),
        createdAt: Date,
        source: String,
        mode: String,
        dominantGoal: String?,
        dominantReactionWeight: String,
        fingerprint: String,
        activeConstraints: [String],
        activeTemplateIDs: [String],
        failureGuardIDs: [String]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.source = source
        self.mode = mode
        self.dominantGoal = dominantGoal
        self.dominantReactionWeight = dominantReactionWeight
        self.fingerprint = fingerprint
        self.activeConstraints = activeConstraints
        self.activeTemplateIDs = activeTemplateIDs
        self.failureGuardIDs = failureGuardIDs
    }
}

public enum BASCurrentBrainPersistenceApplier {
    public static let defaultUpdateLimit = 60
    public static let defaultRetentionInterval: TimeInterval = 60 * 60 * 24 * 14

    public static func updateInput(
        mode: String,
        bootstrapped: BASBootstrappedBrainState
    ) -> BASCurrentBrainUpdatePersistenceInput {
        BASCurrentBrainUpdatePersistenceInput(
            mode: normalizedString(mode),
            dominantGoal: normalizedOptionalString(bootstrapped.dominantGoal),
            dominantReactionWeight: bootstrapped.brainState.reactionWeights.dominantKey.rawValue,
            fingerprint: bootstrapped.brainState.verificationSnapshot.fingerprint,
            activeConstraints: canonicalStrings(bootstrapped.activeConstraints),
            activeTemplateIDs: canonicalStrings(bootstrapped.activeTemplateIDs),
            failureGuardIDs: canonicalStrings(bootstrapped.failureGuardIDs)
        )
    }

    public static func updateFields(
        id: UUID = UUID(),
        createdAt: Date,
        source: String,
        input: BASCurrentBrainUpdatePersistenceInput
    ) -> BASCurrentBrainUpdateStoredFields {
        BASCurrentBrainUpdateStoredFields(
            id: id,
            createdAt: createdAt,
            source: source,
            mode: normalizedString(input.mode),
            dominantGoal: normalizedOptionalString(input.dominantGoal),
            dominantReactionWeight: normalizedString(input.dominantReactionWeight),
            fingerprint: normalizedString(input.fingerprint),
            activeConstraints: canonicalStrings(input.activeConstraints),
            activeTemplateIDs: canonicalStrings(input.activeTemplateIDs),
            failureGuardIDs: canonicalStrings(input.failureGuardIDs)
        )
    }

    public static func canonicalUpdateOrder(
        for updates: [BASCurrentBrainUpdateStoredFields]
    ) -> [BASCurrentBrainUpdateStoredFields] {
        updates.sorted {
            if $0.createdAt != $1.createdAt {
                return $0.createdAt > $1.createdAt
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    public static func retainedUpdateIDs(
        in updates: [BASCurrentBrainUpdateStoredFields],
        now: Date,
        maxEntries: Int = defaultUpdateLimit,
        retentionInterval: TimeInterval = defaultRetentionInterval
    ) -> Set<UUID> {
        let freshnessFloor = now.addingTimeInterval(-retentionInterval)
        let eligible = canonicalUpdateOrder(for: updates)
            .filter { $0.createdAt >= freshnessFloor }
        return Set(eligible.prefix(maxEntries).map(\.id))
    }

    private static func canonicalStrings(_ values: [String]) -> [String] {
        Array(
            Set(
                values
                    .map(normalizedString)
                    .filter { !$0.isEmpty }
            )
        )
        .sorted()
    }

    private static func normalizedOptionalString(_ value: String?) -> String? {
        let normalized = normalizedString(value)
        return normalized.isEmpty ? nil : normalized
    }

    private static func normalizedString(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
