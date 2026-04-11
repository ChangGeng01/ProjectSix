import BASHostKit

typealias DecisionPromptEvidenceFilterResult = BASPromptEvidenceFilterResult

enum DecisionPromptEvidenceGuard {
    static func filter(
        _ evidence: [String],
        maxRetained: Int
    ) -> DecisionPromptEvidenceFilterResult {
        BASPromptEvidenceGuard.filter(evidence, maxRetained: maxRetained)
    }
}
