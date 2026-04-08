import Foundation

@MainActor
final class MirrorWorkspaceSession: ObservableObject, Identifiable {
    let id = UUID()
    let entrySource: EntrySource

    @Published var prompt: String
    @Published var emotion: String = ""
    @Published var relationship: String = ""
    @Published var reality: String = ""
    @Published var longTerm: String = ""
    @Published var selfLens: String = ""
    @Published var result: MirrorResult?

    init(entrySource: EntrySource, prompt: String = "") {
        self.entrySource = entrySource
        self.prompt = prompt
    }

    var canEvaluate: Bool {
        !trimmed(prompt).isEmpty && populatedFieldCount >= 3
    }

    func evaluate() {
        guard canEvaluate else { return }
        result = DecisionIntelligenceCoordinator.mirrorResult(
            for: MirrorInput(
                prompt: trimmed(prompt),
                emotion: trimmed(emotion),
                relationship: trimmed(relationship),
                reality: trimmed(reality),
                longTerm: trimmed(longTerm),
                selfLens: trimmed(selfLens)
            )
        )
    }

    var filledLensCount: Int {
        MirrorWorkspaceLens.allCases.filter { hasContent(for: $0) }.count
    }

    var missingLensCount: Int {
        MirrorWorkspaceLens.allCases.count - filledLensCount
    }

    var progressFraction: Double {
        guard !MirrorWorkspaceLens.allCases.isEmpty else { return 0 }
        return Double(filledLensCount) / Double(MirrorWorkspaceLens.allCases.count)
    }

    var stage: MirrorWorkspaceStage {
        if result != nil {
            return .reflected
        }

        switch filledLensCount {
        case 0:
            return .opening
        case 1...2:
            return .building
        default:
            return .ready
        }
    }

    var workspaceTitle: String {
        stage.title
    }

    var workspaceSubtitle: String {
        stage.subtitle
    }

    var filledLensTitles: [String] {
        MirrorWorkspaceLens.allCases.compactMap { lens in
            hasContent(for: lens) ? lens.title : nil
        }
    }

    var missingLensTitles: [String] {
        MirrorWorkspaceLens.allCases.compactMap { lens in
            hasContent(for: lens) ? nil : lens.title
        }
    }

    var revisitCueTitle: String {
        if result != nil {
            return "This mirror is ready to reopen later."
        }

        if canEvaluate {
            return "You have enough to reflect back now."
        }

        return "One or two lenses are still missing."
    }

    var revisitCueDetail: String {
        if result != nil {
            return "You can save the current shape, move it into Tomorrow Box, or keep editing if the question shifts."
        }

        if canEvaluate {
            return "Use Reflect it back when you want the mirror to name the pattern, the reality, and the self shape."
        }

        return "The mirror gets clearer when the feeling, the structure, and the self lens are all named."
    }

    private var populatedFieldCount: Int {
        [emotion, relationship, reality, longTerm, selfLens]
            .map(trimmed)
            .filter { !$0.isEmpty }
            .count
    }

    private func hasContent(for lens: MirrorWorkspaceLens) -> Bool {
        !trimmed(value(for: lens)).isEmpty
    }

    private func value(for lens: MirrorWorkspaceLens) -> String {
        switch lens {
        case .emotion:
            emotion
        case .relationship:
            relationship
        case .reality:
            reality
        case .longTerm:
            longTerm
        case .selfLens:
            selfLens
        }
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
