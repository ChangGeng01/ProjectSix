import Foundation
import QinaoMLX

/// M228 — provider picker entries for QinaoSampleApp.
///
/// Lifted out of the executable target into the `QinaoSample`
/// library so test targets can `@testable import QinaoSample` and
/// exercise picker behavior + view rendering without driving an
/// actual SwiftUI app launch.
public enum SampleProvider: String, CaseIterable, Identifiable,
    Sendable, Equatable, Hashable
{
    case appleFoundation = "Apple Foundation Models"
    case mlxGemma4E4B = "Gemma 4 E4B (MLX, 4-bit)"
    case mlxGemma4E2B = "Gemma 4 E2B (MLX, 4-bit)"
    case mlxGemma3_4B = "Gemma 3 4B (MLX, 4-bit)"
    // availableAlternatives (Llama/Qwen) — wired + selectable, EXPERIMENTAL tier (QinaoMLXModel.certificationTier).
    case mlxLlama3_2_3B = "Llama 3.2 3B (MLX, 4-bit)"
    case mlxQwen2_5_3B = "Qwen2.5 3B (MLX, 4-bit)"
    case mlxLlama3_2_1B = "Llama 3.2 1B (MLX, 4-bit)"
    case mlxQwen2_5_1_5B = "Qwen2.5 1.5B (MLX, 4-bit)"
    case chatCompletions = "OpenAI-compatible API (M223)"

    public var id: String { rawValue }

    /// `true` when the provider is fully wired and selectable in
    /// the UI; `false` for picker placeholders that document the
    /// roadmap without lying about runtime support.
    public var isAvailable: Bool {
        self != .chatCompletions
    }

    /// Map picker entries to MLX model identity. `nil` for non-MLX
    /// entries; SampleSession branches on this before invoking the
    /// MLX factory.
    public var mlxModel: QinaoMLXModel? {
        switch self {
        case .mlxGemma4E4B: return .gemma4E4B
        case .mlxGemma4E2B: return .gemma4E2B
        case .mlxGemma3_4B: return .gemma3_4B
        case .mlxLlama3_2_3B: return .llama3_2_3B
        case .mlxQwen2_5_3B: return .qwen2_5_3B
        case .mlxLlama3_2_1B: return .llama3_2_1B
        case .mlxQwen2_5_1_5B: return .qwen2_5_1_5B
        default: return nil
        }
    }
}

/// Errors raised by the sample app's session resolver. Public so
/// tests can pattern-match against the typed cases instead of
/// scraping `localizedDescription` strings.
public enum SampleError: LocalizedError, Equatable {
    case providerNotWired(String)
    case endpointBuilderFailed(String)

    public var errorDescription: String? {
        switch self {
        case .providerNotWired(let name):
            return "provider not yet wired: \(name)"
        case .endpointBuilderFailed(let reason):
            return "endpoint builder failed: \(reason)"
        }
    }
}
