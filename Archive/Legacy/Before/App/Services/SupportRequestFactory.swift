import Foundation

enum SupportRequestFactory {
    @MainActor
    static func makeQuickRequest(from session: QuickCheckSession, result: QuickCheckResult? = nil) -> SupportRequest {
        let kind: SupportRequestKind
        switch result?.verdict {
        case .notRecommended:
            kind = .holdMe10Minutes
        case .pause:
            kind = .helpMeJudgeThis
        case .goAhead:
            kind = .helpMeJudgeThis
        case nil:
            kind = .holdMe10Minutes
        }

        let prompt = trimmed(session.note)
        let scenarioTitle = session.scenario.title.lowercased()
        let message = prompt.isEmpty
            ? "I want a clearer read before I \(scenarioTitle)."
            : "I need a second read on: \(prompt)"

        return SupportRequest(
            kind: kind,
            message: message,
            mode: .quick,
            draft: .quick(from: session)
        )
    }

    @MainActor
    static func makeBalanceRequest(from session: BalanceBoardSession) -> SupportRequest {
        let prompt = trimmed(session.prompt)
        let message = prompt.isEmpty
            ? "Help me sort the trade-off without spiralling."
            : "Help me balance this: \(prompt)"

        return SupportRequest(
            kind: .helpMeJudgeThis,
            message: message,
            mode: .balance,
            draft: .balance(from: session)
        )
    }

    @MainActor
    static func makeMirrorRequest(from session: MirrorWorkspaceSession) -> SupportRequest {
        let prompt = trimmed(session.prompt)
        let message = prompt.isEmpty
            ? "I need a steadier mirror for this."
            : "I am getting blurry around: \(prompt)"

        return SupportRequest(
            kind: .iAmGettingBlurry,
            message: message,
            mode: .mirror,
            draft: .mirror(from: session)
        )
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
