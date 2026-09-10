import Foundation

private struct EmbeddingMemoryIndexItem: Codable, Equatable, Sendable {
    let id: String
    let kind: String
    let title: String
    let detail: String
    let tags: [String]
    let tierRaw: String
    let updatedAt: Date
    let vector: [Double]

    var tier: DecisionMemoryTier {
        DecisionMemoryTier(rawValue: tierRaw) ?? .warm
    }
}

private struct EmbeddingMemoryIndexSnapshot: Codable, Equatable, Sendable {
    let items: [EmbeddingMemoryIndexItem]
    let updatedAt: Date
}

struct EmbeddingMemoryMatch: Equatable, Sendable {
    let id: String
    let title: String
    let detail: String
    let score: Double
    let tier: DecisionMemoryTier
}

enum EmbeddingMemoryStore {
    private static let key = "before.embedding.memory.index"
    private static let dimensions = 48
    private static let storage = CodableStateStorage.protectedLocal

    static func rebuildIndex(
        records: [DecisionMemoryRecord],
        candidates: [DecisionMemoryCandidateRecord],
        checkEvents: [CheckEvent],
        balance: [BalanceDecisionRecord] = [],
        mirror: [MirrorDecisionRecord] = []
    ) {
        let items =
            records.map {
                makeItem(
                    id: $0.id,
                    kind: "memory",
                    title: $0.headline,
                    detail: $0.value,
                    tags: $0.retrievalTags,
                    tier: $0.tier,
                    updatedAt: $0.lastConfirmedAt
                )
            } +
            candidates.map {
                makeItem(
                    id: $0.id,
                    kind: "candidate",
                    title: $0.headline,
                    detail: $0.value,
                    tags: $0.retrievalTags,
                    tier: $0.tier,
                    updatedAt: $0.lastObservedAt
                )
            } +
            checkEvents.map {
                makeItem(
                    id: $0.id.uuidString.lowercased(),
                    kind: "quick_event",
                    title: $0.currentPerspective,
                    detail: [$0.note, $0.afterPerspective].joined(separator: " "),
                    tags: [$0.scenario.rawValue, $0.finalAction.rawValue],
                    tier: .hot,
                    updatedAt: $0.createdAt
                )
            } +
            balance.map {
                makeItem(
                    id: $0.id.uuidString.lowercased(),
                    kind: "balance_record",
                    title: $0.focusTitle,
                    detail: [$0.prompt, $0.focusSummary, $0.nextAction].joined(separator: " "),
                    tags: ["balance", "tradeoff"],
                    tier: .warm,
                    updatedAt: $0.updatedAt
                )
            } +
            mirror.map {
                makeItem(
                    id: $0.id.uuidString.lowercased(),
                    kind: "mirror_record",
                    title: $0.nextActionTitle,
                    detail: [$0.prompt, $0.coreTension, $0.nextAction].joined(separator: " "),
                    tags: ["mirror", "reflection"],
                    tier: .warm,
                    updatedAt: $0.updatedAt
                )
            }
        storage.save(EmbeddingMemoryIndexSnapshot(items: items, updatedAt: .now), key: key)
    }

    static func query(
        _ text: String,
        allowedTiers: Set<DecisionMemoryTier> = Set(DecisionMemoryTier.allCases),
        limit: Int = 6
    ) -> [EmbeddingMemoryMatch] {
        guard let snapshot = storage.load(EmbeddingMemoryIndexSnapshot.self, key: key) else {
            return []
        }
        let queryVector = vector(for: text)
        return snapshot.items
            .filter { allowedTiers.contains($0.tier) }
            .map {
                EmbeddingMemoryMatch(
                    id: $0.id,
                    title: $0.title,
                    detail: $0.detail,
                    score: cosineSimilarity(queryVector, $0.vector),
                    tier: $0.tier
                )
            }
            .sorted {
                if $0.score == $1.score {
                    return $0.id < $1.id
                }
                return $0.score > $1.score
            }
            .prefix(limit)
            .map { $0 }
    }

    private static func makeItem(
        id: String,
        kind: String,
        title: String,
        detail: String,
        tags: [String],
        tier: DecisionMemoryTier,
        updatedAt: Date
    ) -> EmbeddingMemoryIndexItem {
        let text = ([title, detail] + tags).joined(separator: " ")
        return EmbeddingMemoryIndexItem(
            id: id,
            kind: kind,
            title: title,
            detail: detail,
            tags: tags,
            tierRaw: tier.rawValue,
            updatedAt: updatedAt,
            vector: vector(for: text)
        )
    }

    private static func vector(for text: String) -> [Double] {
        var vector = Array(repeating: 0.0, count: dimensions)
        let tokens = text
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
        guard !tokens.isEmpty else { return vector }
        for token in tokens {
            let bucket = abs(token.hashValue) % dimensions
            vector[bucket] += 1
        }
        let magnitude = sqrt(vector.reduce(0) { $0 + ($1 * $1) })
        guard magnitude > 0 else { return vector }
        return vector.map { $0 / magnitude }
    }

    private static func cosineSimilarity(_ lhs: [Double], _ rhs: [Double]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return 0 }
        return zip(lhs, rhs).reduce(0) { $0 + ($1.0 * $1.1) }
    }
}
