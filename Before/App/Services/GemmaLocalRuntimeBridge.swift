import Foundation

struct GemmaLocalRuntimeStatus: Equatable, Sendable {
    let canRunInference: Bool
    let title: String
    let detail: String
}

protocol GemmaLocalRuntimeBridging: Sendable {
    var status: GemmaLocalRuntimeStatus { get }

    func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput
    ) async -> QuickCheckResult?

    func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput
    ) async -> BalanceBoardResult?

    func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput
    ) async -> MirrorResult?
}

enum GemmaLocalRuntimeBridge {
    static let shared: any GemmaLocalRuntimeBridging = UnlinkedGemmaLocalRuntimeBridge()
}

struct UnlinkedGemmaLocalRuntimeBridge: GemmaLocalRuntimeBridging {
    var status: GemmaLocalRuntimeStatus {
        GemmaLocalRuntimeStatus(
            canRunInference: false,
            title: "Not linked",
            detail: "The LiteRT-LM iOS runtime bridge is not linked into this build yet, so Before cannot run the bundled Gemma model for local inference."
        )
    }

    func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput
    ) async -> QuickCheckResult? {
        nil
    }

    func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput
    ) async -> BalanceBoardResult? {
        nil
    }

    func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput
    ) async -> MirrorResult? {
        nil
    }
}
