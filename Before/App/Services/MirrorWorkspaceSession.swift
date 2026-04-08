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
        result = MirrorEngine.evaluate(
            MirrorInput(
                prompt: trimmed(prompt),
                emotion: trimmed(emotion),
                relationship: trimmed(relationship),
                reality: trimmed(reality),
                longTerm: trimmed(longTerm),
                selfLens: trimmed(selfLens)
            )
        )
    }

    private var populatedFieldCount: Int {
        [emotion, relationship, reality, longTerm, selfLens]
            .map(trimmed)
            .filter { !$0.isEmpty }
            .count
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
