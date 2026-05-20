import Foundation

struct DecisionMemoryEligibilityCandidate: Equatable, Sendable {
    let id: String
    let type: DecisionMemoryType
    let headline: String
    let source: DecisionMemorySource
    let confidence: Double
    let priority: Double
    let retrievalTags: [String]
    let lastConfirmedAt: Date
    let decayPolicy: DecisionMemoryDecayPolicy
    let lifecycleState: DecisionMemoryLifecycleState
    let governanceStatus: DecisionGovernedMemoryStatus
    let isPending: Bool
    let provenanceSummary: String
    let sourceTrustScore: Double
    let sourceTrustTier: DecisionMemorySourceTrustTier
    let effectiveConfidence: Double
    let provenanceRisk: Bool
}

enum DecisionMemoryEligibilityJudge {
    static func decide(
        candidate: DecisionMemoryEligibilityCandidate,
        mode: DecisionMode,
        queryTags: Set<String>,
        now: Date
    ) -> DecisionMemoryEligibilityDecision {
        if candidate.type == .identity {
            return .allowed(.identityOverride)
        }

        if candidate.type == .goal {
            return .allowed(.goalOverride)
        }

        let meaningfulItemTags = relevantTags(candidate.retrievalTags)
        let meaningfulQueryTags = relevantTags(Array(queryTags))
        let hasTagOverlap = !meaningfulItemTags.intersection(meaningfulQueryTags).isEmpty
        let ageHours = max(0, now.timeIntervalSince(candidate.lastConfirmedAt) / 3_600)

        if candidate.provenanceRisk {
            return .screenedOut(.provenanceContamination)
        }

        if meaningfulItemTags.count >= 9, !hasTagOverlap {
            return .screenedOut(.tagFloodNoOverlap)
        }

        if candidate.isPending {
            if candidate.sourceTrustTier == .low, !hasTagOverlap, ageHours <= 18 {
                return .screenedOut(.lowTrustPending)
            }
            return hasTagOverlap
                ? .allowed(.pendingTagOverlap)
                : (ageHours <= 18 ? .allowed(.pendingGraceWindow) : .screenedOut(.confidenceNoOverlap))
        }

        if candidate.decayPolicy == .fast {
            return hasTagOverlap
                ? .allowed(.fastDecayTagOverlap)
                : (ageHours <= 24 ? .allowed(.fastDecayGraceWindow) : .screenedOut(.confidenceNoOverlap))
        }

        if candidate.effectiveConfidence < 0.62, !hasTagOverlap {
            return .screenedOut(.confidenceNoOverlap)
        }

        if candidate.type == .support {
            let baseline = mode == .mirror ? 0.58 : 0.64
            if candidate.priority < baseline, !hasTagOverlap {
                return .screenedOut(.supportPriorityNoOverlap)
            }
        }

        if candidate.type == .semantic {
            let baseline = mode == .mirror ? 0.58 : 0.64
            if candidate.priority < baseline, !hasTagOverlap {
                return .screenedOut(.semanticPriorityNoOverlap)
            }
        }

        return .allowed(.defaultAllowed)
    }

    private static func relevantTags(_ tags: [String]) -> Set<String> {
        let ignored = Set([
            "quick",
            "balance",
            "mirror",
            "recent",
            "goal",
            "long_term",
            "pattern",
            "repeat"
        ])

        return Set(tags.map { $0.lowercased() })
            .subtracting(ignored)
            .filter { tag in
                !tag.hasPrefix("lang:") && !tag.hasPrefix("script:")
            }
    }
}
