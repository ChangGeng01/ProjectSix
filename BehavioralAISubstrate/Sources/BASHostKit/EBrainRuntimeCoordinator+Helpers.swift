import CryptoKit
import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

// MARK: - M71 split — BASEBrainRuntimeCoordinator — misc helper utilities.
// summarizedTokens / candidateDominanceScore / containsGuardLexicon / critiqueSeverity /
// recommendedPermitMode / saferPermitMode / permitStrictness / allowedDomains /
// forbiddenDomains / sovereignConstraintCodes / unique.
// Extracted from the 6099-line monolith during the M71 cohesion split.

extension BASEBrainRuntimeCoordinator {
    func summarizedTokens(
        _ values: [String],
        limit: Int = 4
    ) -> String {
        let uniqueValues = unique(values)
        guard uniqueValues.isEmpty == false else { return "no signals" }

        let head = Array(uniqueValues.prefix(limit))
        let remainingCount = uniqueValues.count - head.count
        if remainingCount > 0 {
            return head.joined(separator: ", ") + ", +\(remainingCount) more"
        }
        return head.joined(separator: ", ")
    }

    func candidateDominanceScore(
        _ candidate: BASCandidatePath
    ) -> Double {
        (candidate.expectedBenefit * 0.45)
            + (candidate.reversibility * 0.30)
            + (candidate.confidence * 0.20)
            - (candidate.expectedCost * 0.25)
    }

    func containsGuardLexicon(
        _ value: String
    ) -> Bool {
        let normalized = value.lowercased()
        return normalized.contains("delay")
            || normalized.contains("pause")
            || normalized.contains("wait")
            || normalized.contains("review")
            || normalized.contains("bounded")
            || normalized.contains("protect")
    }

    func critiqueSeverity(
        _ type: BASCritiqueType,
        in critiques: [BASCritiqueItem]
    ) -> Double {
        critiques
            .filter { $0.critiqueType == type }
            .map(\.severity)
            .max() ?? 0
    }

    func recommendedPermitMode(
        riskLevel: BASBrainRiskLevel,
        gsiScore: Double,
        irreversibility: Double,
        boundaryConflict: Double
    ) -> BASActionPermitMode {
        if riskLevel == .extreme || gsiScore >= 0.80 || irreversibility >= 0.88 || boundaryConflict >= 0.85 {
            return .block
        }
        if riskLevel == .high || gsiScore >= 0.68 || irreversibility >= 0.72 {
            return .delay
        }
        if riskLevel == .medium {
            return .compare
        }
        return .answer
    }

    func saferPermitMode(
        _ lhs: BASActionPermitMode,
        _ rhs: BASActionPermitMode
    ) -> BASActionPermitMode {
        permitStrictness(lhs) >= permitStrictness(rhs) ? lhs : rhs
    }

    func permitStrictness(
        _ mode: BASActionPermitMode
    ) -> Int {
        switch mode {
        case .answer:
            return 0
        case .mirror:
            return 1
        case .compare:
            return 2
        case .delay:
            return 3
        case .draftOnly:
            return 4
        case .localOnly:
            return 5
        case .replace:
            return 6
        case .block:
            return 7
        case .escalate:
            return 8
        }
    }

    func allowedDomains(
        for mode: BASActionPermitMode
    ) -> [String] {
        switch mode {
        case .answer:
            return ["bounded_reply", "plain_language"]
        case .mirror:
            return ["bounded_reply", "mirror"]
        case .compare:
            return ["bounded_reply", "comparison"]
        case .delay:
            return ["bounded_reply"]
        case .draftOnly:
            return ["bounded_reply", "draft"]
        case .localOnly:
            return ["bounded_reply", "local_action"]
        case .replace:
            return ["bounded_reply", "protective_alternative"]
        case .block:
            return ["protective_receipt"]
        case .escalate:
            return ["protective_receipt", "sovereign_alert"]
        }
    }

    func forbiddenDomains(
        for mode: BASActionPermitMode
    ) -> [String] {
        switch mode {
        case .answer:
            return []
        case .mirror:
            return ["tool_commit", "memory_commit", "host_commit"]
        case .compare:
            return ["tool_commit"]
        case .delay:
            return ["tool_commit", "memory_commit"]
        case .draftOnly:
            return ["tool_commit", "memory_commit", "host_commit"]
        case .localOnly:
            return ["memory_commit", "host_commit", "public_release"]
        case .replace:
            return ["tool_commit", "memory_commit", "host_commit"]
        case .block:
            return ["tool_commit", "memory_commit", "host_commit", "high_consequence_decode"]
        case .escalate:
            return ["tool_commit", "memory_commit", "host_commit", "public_release", "high_consequence_decode"]
        }
    }

    func sovereignConstraintCodes(
        for morph: BASNeuralMorph,
        actionPermit: BASActionPermit
    ) -> [String] {
        switch morph {
        case .stub:
            return ["tool_cut", "host_mod_freeze", "deep_zone_off", "stub_ready"]
        case .quarantine:
            return ["tool_cut", "host_mod_freeze", "memory_write_freeze"]
        case .rollbackRebuild:
            return ["host_mod_version_pin", "consistency_rebuild"]
        case .guard:
            return actionPermit.mode == .delay || actionPermit.mode == .replace
                ? ["tool_cut", "host_mod_freeze"]
                : []
        case .scout, .engage, .compare, .deepLoop:
            return []
        }
    }

    func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

}
