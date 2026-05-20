import Foundation

enum SharedLifeItemFactory {
    @MainActor
    static func makeQuickItem(from session: QuickCheckSession, result: QuickCheckResult? = nil) -> SharedLifeBoxItem {
        let prompt = trimmed(session.note)
        let title = session.scenario == .other ? "Shared quick decision" : "\(session.scenario.title) decision"
        let detail = result?.verdict.summary ?? "Bring this back when both people can look at it cleanly."
        return SharedLifeBoxItem(
            title: title,
            detail: detail,
            mode: .quick,
            prompt: prompt,
            draft: .quick(from: session)
        )
    }

    @MainActor
    static func makeBalanceItem(from session: BalanceBoardSession) -> SharedLifeBoxItem {
        let prompt = trimmed(session.prompt)
        let title = "Shared trade-off"
        let detail = "Use shared rules to name what matters most here."
        return SharedLifeBoxItem(
            title: title,
            detail: detail,
            mode: .balance,
            prompt: prompt,
            draft: .balance(from: session)
        )
    }

    @MainActor
    static func makeMirrorItem(from session: MirrorWorkspaceSession) -> SharedLifeBoxItem {
        let prompt = trimmed(session.prompt)
        let title = "Shared mirror"
        let detail = "This needs a slower shared read."
        return SharedLifeBoxItem(
            title: title,
            detail: detail,
            mode: .mirror,
            prompt: prompt,
            draft: .mirror(from: session)
        )
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
