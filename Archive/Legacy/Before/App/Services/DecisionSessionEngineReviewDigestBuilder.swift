enum DecisionSessionEngineReviewDigestBuilder {
    static func build(
        from summary: DecisionSystemSessionEngineSummary
    ) -> [DecisionSessionEngineReviewDigestLine] {
        DecisionSessionReviewPresentationSupport.digestLines(from: summary)
    }

    static func presentations(
        from summary: DecisionSystemSessionEngineSummary
    ) -> [DecisionSessionEngineReviewItemPresentation] {
        build(from: summary).map(DecisionSessionReviewPresentationSupport.itemPresentation)
    }

    static func signalLines(
        from summary: DecisionSystemSessionEngineSummary
    ) -> [String] {
        build(from: summary).map(DecisionSessionReviewPresentationSupport.signalLine)
    }
}
