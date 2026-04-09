import Foundation

struct DecisionMemoryTrustProfile: Equatable, Sendable {
    let score: Double
    let tier: DecisionMemorySourceTrustTier
    let provenanceRisk: Bool
    let confidenceMultiplier: Double
    let decayGraceMultiplier: Double
}

enum DecisionMemoryTrustEngine {
    static func profile(
        source: DecisionMemorySource,
        evidenceCount: Int,
        decayPolicy: DecisionMemoryDecayPolicy,
        governanceStatus: DecisionGovernedMemoryStatus,
        isPending: Bool,
        provenanceSummary: String
    ) -> DecisionMemoryTrustProfile {
        let baseScore: Double = switch source {
        case .reminder:
            0.94
        case .pattern:
            0.82
        case .reflection:
            0.74
        case .history:
            0.66
        }

        let evidenceBoost = min(0.12, Double(max(0, evidenceCount - 1)) * 0.03)
        let governanceAdjustment: Double = switch governanceStatus {
        case .admitted:
            0.04
        case .deferred:
            -0.08
        case .pending:
            -0.12
        }
        let decayAdjustment: Double = switch decayPolicy {
        case .stable:
            0.04
        case .slow:
            0.02
        case .medium:
            0
        case .fast:
            -0.06
        }
        let pendingPenalty = isPending ? 0.06 : 0
        let provenanceRisk = isContaminated(provenanceSummary)
        let contaminationPenalty = provenanceRisk ? 0.24 : 0

        let score = clamp(
            baseScore +
                evidenceBoost +
                governanceAdjustment +
                decayAdjustment -
                pendingPenalty -
                contaminationPenalty,
            min: 0.15,
            max: 0.99
        )

        let tier: DecisionMemorySourceTrustTier
        switch score {
        case ..<0.60:
            tier = .low
        case ..<0.82:
            tier = .medium
        default:
            tier = .high
        }

        let confidenceMultiplier = 0.55 + (score * 0.45)
        let decayGraceMultiplier: Double = switch tier {
        case .high:
            1.25
        case .medium:
            1.0
        case .low:
            0.72
        }

        return DecisionMemoryTrustProfile(
            score: score,
            tier: tier,
            provenanceRisk: provenanceRisk,
            confidenceMultiplier: confidenceMultiplier,
            decayGraceMultiplier: decayGraceMultiplier
        )
    }

    static func effectiveConfidence(
        rawConfidence: Double,
        trustProfile: DecisionMemoryTrustProfile
    ) -> Double {
        clamp(
            rawConfidence * trustProfile.confidenceMultiplier,
            min: 0,
            max: 1
        )
    }

    private static func isContaminated(_ provenanceSummary: String) -> Bool {
        let normalized = provenanceSummary.lowercased()
        let suspiciousTokens = [
            "<script",
            "</",
            "```",
            "http://",
            "https://",
            "assistant:",
            "tool call",
            "function(",
            "\"role\":",
            "{json"
        ]

        return suspiciousTokens.contains { normalized.contains($0) }
    }

    private static func clamp(
        _ value: Double,
        min lowerBound: Double,
        max upperBound: Double
    ) -> Double {
        Swift.max(lowerBound, Swift.min(upperBound, value))
    }
}
