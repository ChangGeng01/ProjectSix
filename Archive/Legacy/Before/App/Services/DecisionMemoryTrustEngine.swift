import Foundation
import BASHostKit

typealias DecisionMemoryTrustProfile = BASMemoryTrustProfile

enum DecisionMemoryTrustEngine {
    static func profile(
        source: DecisionMemorySource,
        evidenceCount: Int,
        decayPolicy: DecisionMemoryDecayPolicy,
        governanceStatus: DecisionGovernedMemoryStatus,
        isPending: Bool,
        provenanceSummary: String
    ) -> DecisionMemoryTrustProfile {
        BASMemoryTrustEngine.profile(
            source: source.basSource,
            evidenceCount: evidenceCount,
            decayPolicy: decayPolicy.basDecayPolicy,
            governanceStatus: governanceStatus.basMemoryLoadStatus,
            isPending: isPending,
            provenanceSummary: provenanceSummary
        )
    }

    static func effectiveConfidence(
        rawConfidence: Double,
        trustProfile: DecisionMemoryTrustProfile
    ) -> Double {
        BASMemoryTrustEngine.effectiveConfidence(
            rawConfidence: rawConfidence,
            trustProfile: trustProfile
        )
    }
}

private extension DecisionGovernedMemoryStatus {
    var basMemoryLoadStatus: BASMemoryLoadStatus {
        switch self {
        case .admitted:
            .admitted
        case .deferred:
            .deferred
        case .pending:
            .pending
        }
    }
}
