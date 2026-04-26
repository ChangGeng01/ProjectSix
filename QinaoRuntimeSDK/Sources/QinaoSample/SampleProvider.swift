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
