import Foundation
import Darwin

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
    static let shared: any GemmaLocalRuntimeBridging = DynamicGemmaLocalRuntimeBridge()
}

typealias GemmaRuntimeTextGenerator = @Sendable (_ prompt: String, _ modelPath: String, _ maxOutputTokens: Int32) -> String?

final class DynamicGemmaLocalRuntimeBridge: GemmaLocalRuntimeBridging, @unchecked Sendable {
    private let cachedLoadState: GemmaRuntimeLoadState
    private let modelPathProvider: @Sendable () -> String?

    init(
        loadState: GemmaRuntimeLoadState? = nil,
        modelPathProvider: @escaping @Sendable () -> String? = {
            GemmaE4BIntelligenceService.bundledModel?.fileURLPath
        }
    ) {
        self.cachedLoadState = loadState ?? Self.defaultLoadState()
        self.modelPathProvider = modelPathProvider
    }

    var status: GemmaLocalRuntimeStatus {
        switch cachedLoadState {
        case .missingLibrary:
            GemmaLocalRuntimeStatus(
                canRunInference: false,
                title: "Library missing",
                detail: "No LiteRT-LM runtime library was bundled with this build yet. Add a compatible LiteRT-LM framework or dylib to enable Gemma inference."
            )
        case let .failedToLoad(asset, reason):
            GemmaLocalRuntimeStatus(
                canRunInference: false,
                title: "Library found",
                detail: "Found \(asset.fileName), but Before could not load it yet: \(reason)"
            )
        case let .missingSymbols(asset, symbols):
            GemmaLocalRuntimeStatus(
                canRunInference: false,
                title: "Incompatible",
                detail: "\(asset.fileName) loaded, but it is missing required LiteRT-LM symbols: \(symbols.joined(separator: ", "))."
            )
        case let .ready(asset, _):
            GemmaLocalRuntimeStatus(
                canRunInference: true,
                title: "Ready",
                detail: "\(asset.fileName) is bundled and exposes the LiteRT-LM C API. Before can attempt local Gemma inference on this build."
            )
        }
    }

    func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput
    ) async -> QuickCheckResult? {
        guard case let .ready(_, generator) = cachedLoadState,
              let modelPath = modelPathProvider() else { return nil }

        let prompt = """
        You refine copy for a local decision app.
        Return exactly two lines.
        CURRENT: <rewrite of the current perspective>
        AFTER: <rewrite of the after perspective>
        Keep the same meaning, stay calm, and do not mention AI or morality.

        \(DecisionIntelligencePromptContract.quickRefinementPrompt(base: base, input: input))
        """

        guard let text = await generateText(
            prompt: prompt,
            modelPath: modelPath,
            maxOutputTokens: 120,
            generator: generator
        ) else {
            return nil
        }

        let fields = parseFields(from: text, expectedKeys: ["CURRENT", "AFTER"])
        guard let current = fields["CURRENT"], let after = fields["AFTER"] else { return nil }

        return QuickCheckResult(
            currentPerspective: DecisionIntelligencePromptContract.sanitized(
                current,
                fallback: base.currentPerspective,
                limit: DecisionIntelligencePromptContract.Limit.quickCurrentPerspective
            ),
            afterPerspective: DecisionIntelligencePromptContract.sanitized(
                after,
                fallback: base.afterPerspective,
                limit: DecisionIntelligencePromptContract.Limit.quickAfterPerspective
            ),
            verdict: base.verdict,
            primaryAction: base.primaryAction,
            secondaryActions: base.secondaryActions
        )
    }

    func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput
    ) async -> BalanceBoardResult? {
        guard case let .ready(_, generator) = cachedLoadState,
              let modelPath = modelPathProvider() else { return nil }

        let prompt = """
        You refine copy for a local balance-board decision tool.
        Return exactly four lines.
        HEADLINE: <headline>
        SUMMARY: <summary>
        FOCUS_DESCRIPTION: <focus description>
        NEXT_ACTION: <next action>
        Keep the same focus. Do not turn it into a yes-or-no verdict.

        \(DecisionIntelligencePromptContract.balanceRefinementPrompt(base: base, input: input))
        """

        guard let text = await generateText(
            prompt: prompt,
            modelPath: modelPath,
            maxOutputTokens: 180,
            generator: generator
        ) else {
            return nil
        }

        let fields = parseFields(
            from: text,
            expectedKeys: ["HEADLINE", "SUMMARY", "FOCUS_DESCRIPTION", "NEXT_ACTION"]
        )
        guard let headline = fields["HEADLINE"],
              let summary = fields["SUMMARY"],
              let focusDescription = fields["FOCUS_DESCRIPTION"],
              let nextAction = fields["NEXT_ACTION"] else { return nil }

        return BalanceBoardResult(
            headline: DecisionIntelligencePromptContract.sanitized(
                headline,
                fallback: base.headline,
                limit: DecisionIntelligencePromptContract.Limit.balanceHeadline
            ),
            summary: DecisionIntelligencePromptContract.sanitized(
                summary,
                fallback: base.summary,
                limit: DecisionIntelligencePromptContract.Limit.balanceSummary
            ),
            focusTitle: base.focusTitle,
            focusDescription: DecisionIntelligencePromptContract.sanitized(
                focusDescription,
                fallback: base.focusDescription,
                limit: DecisionIntelligencePromptContract.Limit.balanceFocusDescription
            ),
            nextAction: DecisionIntelligencePromptContract.sanitized(
                nextAction,
                fallback: base.nextAction,
                limit: DecisionIntelligencePromptContract.Limit.balanceNextAction
            )
        )
    }

    func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput
    ) async -> MirrorResult? {
        guard case let .ready(_, generator) = cachedLoadState,
              let modelPath = modelPathProvider() else { return nil }

        let prompt = """
        You refine copy for a structured mirror inside a local decision app.
        Return exactly three lines.
        HEADLINE: <headline>
        CORE_TENSION: <core tension>
        NEXT_ACTION: <next action>
        Stay restrained, reflective, and non-therapeutic.

        \(DecisionIntelligencePromptContract.mirrorRefinementPrompt(base: base, input: input))
        """

        guard let text = await generateText(
            prompt: prompt,
            modelPath: modelPath,
            maxOutputTokens: 180,
            generator: generator
        ) else {
            return nil
        }

        let fields = parseFields(
            from: text,
            expectedKeys: ["HEADLINE", "CORE_TENSION", "NEXT_ACTION"]
        )
        guard let headline = fields["HEADLINE"],
              let coreTension = fields["CORE_TENSION"],
              let nextAction = fields["NEXT_ACTION"] else { return nil }

        return MirrorResult(
            headline: DecisionIntelligencePromptContract.sanitized(
                headline,
                fallback: base.headline,
                limit: DecisionIntelligencePromptContract.Limit.mirrorHeadline
            ),
            coreTension: DecisionIntelligencePromptContract.sanitized(
                coreTension,
                fallback: base.coreTension,
                limit: DecisionIntelligencePromptContract.Limit.mirrorCoreTension
            ),
            nextActionTitle: base.nextActionTitle,
            nextAction: DecisionIntelligencePromptContract.sanitized(
                nextAction,
                fallback: base.nextAction,
                limit: DecisionIntelligencePromptContract.Limit.mirrorNextAction
            )
        )
    }

    private func generateText(
        prompt: String,
        modelPath: String,
        maxOutputTokens: Int32,
        generator: GemmaRuntimeTextGenerator
    ) async -> String? {
        autoreleasepool {
            generator(prompt, modelPath, maxOutputTokens)
        }
    }

    private static func defaultLoadState() -> GemmaRuntimeLoadState {
        guard let asset = GemmaRuntimeLibraryCatalog.preferredLibrary() else {
            return .missingLibrary
        }

        return LiteRTLMCAPI.load(from: asset)
    }

    private func parseFields(from text: String, expectedKeys: [String]) -> [String: String] {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map(String.init)

        return lines.reduce(into: [String: String]()) { partialResult, line in
            guard let separatorIndex = line.firstIndex(of: ":") else { return }
            let key = line[..<separatorIndex].trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard expectedKeys.contains(key) else { return }
            let value = line[line.index(after: separatorIndex)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return }
            partialResult[key] = value
        }
    }
}

private extension GemmaModelAsset {
    var fileURLPath: String {
        Bundle.main.resourceURL?
            .appendingPathComponent(GemmaModelAssetCatalog.modelSubdirectory, isDirectory: true)
            .appendingPathComponent(fileName)
            .path ?? fileName
    }
}

enum GemmaRuntimeLoadState {
    case missingLibrary
    case failedToLoad(GemmaRuntimeLibraryAsset, String)
    case missingSymbols(GemmaRuntimeLibraryAsset, [String])
    case ready(GemmaRuntimeLibraryAsset, GemmaRuntimeTextGenerator)
}

private struct LiteRTLMCAPI: @unchecked Sendable {
    typealias EngineSettingsRef = UnsafeMutableRawPointer
    typealias EngineRef = UnsafeMutableRawPointer
    typealias SessionRef = UnsafeMutableRawPointer
    typealias ResponsesRef = UnsafeMutableRawPointer
    typealias SessionConfigRef = UnsafeMutableRawPointer

    typealias SetMinLogLevelFn = @convention(c) (Int32) -> Void
    typealias EngineSettingsCreateFn = @convention(c) (
        UnsafePointer<CChar>?,
        UnsafePointer<CChar>?,
        UnsafePointer<CChar>?,
        UnsafePointer<CChar>?
    ) -> EngineSettingsRef?
    typealias EngineSettingsDeleteFn = @convention(c) (EngineSettingsRef?) -> Void
    typealias EngineSettingsSetMaxNumTokensFn = @convention(c) (EngineSettingsRef?, Int32) -> Void
    typealias EngineCreateFn = @convention(c) (UnsafeRawPointer?) -> EngineRef?
    typealias EngineDeleteFn = @convention(c) (EngineRef?) -> Void
    typealias SessionConfigCreateFn = @convention(c) () -> SessionConfigRef?
    typealias SessionConfigDeleteFn = @convention(c) (SessionConfigRef?) -> Void
    typealias SessionConfigSetMaxOutputTokensFn = @convention(c) (SessionConfigRef?, Int32) -> Void
    typealias EngineCreateSessionFn = @convention(c) (EngineRef?, SessionConfigRef?) -> SessionRef?
    typealias SessionDeleteFn = @convention(c) (SessionRef?) -> Void
    typealias SessionGenerateContentFn = @convention(c) (SessionRef?, UnsafeRawPointer?, Int) -> ResponsesRef?
    typealias ResponsesDeleteFn = @convention(c) (ResponsesRef?) -> Void
    typealias ResponsesGetNumCandidatesFn = @convention(c) (UnsafeRawPointer?) -> Int32
    typealias ResponsesGetResponseTextAtFn = @convention(c) (UnsafeRawPointer?, Int32) -> UnsafePointer<CChar>?

    private let handle: UnsafeMutableRawPointer
    private let setMinLogLevel: SetMinLogLevelFn
    private let engineSettingsCreate: EngineSettingsCreateFn
    private let engineSettingsDelete: EngineSettingsDeleteFn
    private let engineSettingsSetMaxNumTokens: EngineSettingsSetMaxNumTokensFn
    private let engineCreate: EngineCreateFn
    private let engineDelete: EngineDeleteFn
    private let sessionConfigCreate: SessionConfigCreateFn
    private let sessionConfigDelete: SessionConfigDeleteFn
    private let sessionConfigSetMaxOutputTokens: SessionConfigSetMaxOutputTokensFn
    private let engineCreateSession: EngineCreateSessionFn
    private let sessionDelete: SessionDeleteFn
    private let sessionGenerateContent: SessionGenerateContentFn
    private let responsesDelete: ResponsesDeleteFn
    private let responsesGetNumCandidates: ResponsesGetNumCandidatesFn
    private let responsesGetResponseTextAt: ResponsesGetResponseTextAtFn

    static func load(from asset: GemmaRuntimeLibraryAsset) -> GemmaRuntimeLoadState {
        guard let handle = dlopen(asset.path, RTLD_NOW | RTLD_LOCAL) else {
            let reason = dlerror().map { String(cString: $0) } ?? "Unknown load error."
            return .failedToLoad(asset, reason)
        }

        let requiredSymbols = [
            "litert_lm_set_min_log_level",
            "litert_lm_engine_settings_create",
            "litert_lm_engine_settings_delete",
            "litert_lm_engine_settings_set_max_num_tokens",
            "litert_lm_engine_create",
            "litert_lm_engine_delete",
            "litert_lm_session_config_create",
            "litert_lm_session_config_delete",
            "litert_lm_session_config_set_max_output_tokens",
            "litert_lm_engine_create_session",
            "litert_lm_session_delete",
            "litert_lm_session_generate_content",
            "litert_lm_responses_delete",
            "litert_lm_responses_get_num_candidates",
            "litert_lm_responses_get_response_text_at"
        ]

        let missingSymbols = requiredSymbols.filter { dlsym(handle, $0) == nil }
        guard missingSymbols.isEmpty else {
            dlclose(handle)
            return .missingSymbols(asset, missingSymbols)
        }

        let api = LiteRTLMCAPI(
            handle: handle,
            setMinLogLevel: unsafeBitCast(dlsym(handle, "litert_lm_set_min_log_level"), to: SetMinLogLevelFn.self),
            engineSettingsCreate: unsafeBitCast(dlsym(handle, "litert_lm_engine_settings_create"), to: EngineSettingsCreateFn.self),
            engineSettingsDelete: unsafeBitCast(dlsym(handle, "litert_lm_engine_settings_delete"), to: EngineSettingsDeleteFn.self),
            engineSettingsSetMaxNumTokens: unsafeBitCast(dlsym(handle, "litert_lm_engine_settings_set_max_num_tokens"), to: EngineSettingsSetMaxNumTokensFn.self),
            engineCreate: unsafeBitCast(dlsym(handle, "litert_lm_engine_create"), to: EngineCreateFn.self),
            engineDelete: unsafeBitCast(dlsym(handle, "litert_lm_engine_delete"), to: EngineDeleteFn.self),
            sessionConfigCreate: unsafeBitCast(dlsym(handle, "litert_lm_session_config_create"), to: SessionConfigCreateFn.self),
            sessionConfigDelete: unsafeBitCast(dlsym(handle, "litert_lm_session_config_delete"), to: SessionConfigDeleteFn.self),
            sessionConfigSetMaxOutputTokens: unsafeBitCast(dlsym(handle, "litert_lm_session_config_set_max_output_tokens"), to: SessionConfigSetMaxOutputTokensFn.self),
            engineCreateSession: unsafeBitCast(dlsym(handle, "litert_lm_engine_create_session"), to: EngineCreateSessionFn.self),
            sessionDelete: unsafeBitCast(dlsym(handle, "litert_lm_session_delete"), to: SessionDeleteFn.self),
            sessionGenerateContent: unsafeBitCast(dlsym(handle, "litert_lm_session_generate_content"), to: SessionGenerateContentFn.self),
            responsesDelete: unsafeBitCast(dlsym(handle, "litert_lm_responses_delete"), to: ResponsesDeleteFn.self),
            responsesGetNumCandidates: unsafeBitCast(dlsym(handle, "litert_lm_responses_get_num_candidates"), to: ResponsesGetNumCandidatesFn.self),
            responsesGetResponseTextAt: unsafeBitCast(dlsym(handle, "litert_lm_responses_get_response_text_at"), to: ResponsesGetResponseTextAtFn.self)
        )

        return .ready(asset) { prompt, modelPath, maxOutputTokens in
            api.generate(
                prompt: prompt,
                modelPath: modelPath,
                maxOutputTokens: maxOutputTokens
            )
        }
    }

    func generate(prompt: String, modelPath: String, maxOutputTokens: Int32) -> String? {
        setMinLogLevel(2)

        return modelPath.withCString { modelPathCString -> String? in
            "cpu".withCString { backendCString -> String? in
                guard let engineSettings = engineSettingsCreate(modelPathCString, backendCString, nil, nil) else {
                    return nil
                }
                defer { engineSettingsDelete(engineSettings) }

                engineSettingsSetMaxNumTokens(engineSettings, max(256, maxOutputTokens))

                guard let engine = engineCreate(engineSettings) else {
                    return nil
                }
                defer { engineDelete(engine) }

                guard let sessionConfig = sessionConfigCreate() else {
                    return nil
                }
                defer { sessionConfigDelete(sessionConfig) }

                sessionConfigSetMaxOutputTokens(sessionConfig, maxOutputTokens)

                guard let session = engineCreateSession(engine, sessionConfig) else {
                    return nil
                }
                defer { sessionDelete(session) }

                return prompt.withCString { promptCString -> String? in
                    var input = LiteRTLmInputData(
                        type: 0,
                        data: UnsafeRawPointer(promptCString),
                        size: strlen(promptCString)
                    )

                    guard let responses = withUnsafePointer(to: &input, {
                        sessionGenerateContent(session, UnsafeRawPointer($0), 1)
                    }) else {
                        return nil
                    }
                    defer { responsesDelete(responses) }

                    let count = responsesGetNumCandidates(responses)
                    guard count > 0,
                          let textPointer = responsesGetResponseTextAt(responses, 0) else {
                        return nil
                    }

                    return String(cString: textPointer)
                }
            }
        }
    }
}

private struct LiteRTLmInputData {
    var type: Int32
    var data: UnsafeRawPointer?
    var size: Int
}
