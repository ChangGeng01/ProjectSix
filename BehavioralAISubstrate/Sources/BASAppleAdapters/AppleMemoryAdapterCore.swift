import Foundation
import BASMemory

public struct BASAppleEmbeddingScoreInput: Codable, Equatable, Sendable {
    public var id: String
    public var score: Double

    public init(id: String, score: Double) {
        self.id = id
        self.score = score
    }
}

public enum BASAppleMemoryProjectionAdapter {
    public static func compile(
        _ request: BASBrainProjectionCompileRequest
    ) -> BASBrainProjection {
        BASBrainProjectionCompiler.compile(request)
    }

    public static func overlayEmbeddingScores(
        _ matches: [BASAppleEmbeddingScoreInput],
        on projection: BASBrainProjection
    ) -> BASBrainProjection {
        var updated = projection
        updated.embeddingScoresByID = Dictionary(
            matches.map { ($0.id, $0.score) },
            uniquingKeysWith: max
        )
        return updated
    }
}
