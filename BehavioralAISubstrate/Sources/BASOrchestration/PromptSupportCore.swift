import CryptoKit
import Foundation
import BASRuntimeCore

public enum BASPromptPrefixCatalog {
    public static let sharedPrelude = """
    You are the language rendering layer for a local cognition host.
    The host owns state, routing, safety, verdicts, and actions.
    You only tighten wording or select from provided options.
    Keep the tone calm, short, and non-shaming.
    """

    public static let quick = """
    Rewrite only the two perspective lines.
    Keep the same meaning and do not change verdicts or actions.
    """

    public static let balance = """
    Tighten the board without inventing new facts or turning it into a verdict.
    Preserve the same focus and next-step intent.
    """

    public static let mirror = """
    Clarify the reflective pass without becoming dramatic, therapeutic, or yes-no.
    Preserve the same tension and reflective next move.
    """

    public static let reminder = """
    Pick one existing reminder that best matches the current state.
    Do not rewrite or invent reminder text.
    """

    public static func instructions(
        for kind: BASSemanticTaskKind
    ) -> String {
        sharedPrelude + "\n" + adaptivePrefix(for: kind)
    }

    public static func immutablePrefix(
        for kind: BASSemanticTaskKind
    ) -> String {
        _ = kind
        return sharedPrelude
    }

    public static func adaptivePrefix(
        for kind: BASSemanticTaskKind
    ) -> String {
        switch kind {
        case .quick:
            quick
        case .balance:
            balance
        case .mirror:
            mirror
        case .reminder:
            reminder
        }
    }
}

public enum BASPromptTextSanitizer {
    public static func sanitized(
        _ value: String,
        fallback: String,
        limit: Int
    ) -> String {
        let trimmed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")

        guard !trimmed.isEmpty else { return fallback }
        let collapsed = trimmed
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard !collapsed.isEmpty else { return fallback }
        guard collapsed.count > limit else { return collapsed }

        return String(collapsed.prefix(limit))
            .trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}

public enum BASPromptFingerprinting {
    public static func cacheFingerprint(
        providerIdentifier: String,
        semanticPrompt: String
    ) -> String {
        sha256Hex("\(providerIdentifier)\n\(semanticPrompt)")
    }

    public static func cacheFingerprint<Kind: Equatable & Sendable, FrontstageState: Equatable & Sendable>(
        providerIdentifier: String,
        envelope: BASPromptEnvelope<Kind, FrontstageState>
    ) -> String {
        cacheFingerprint(
            providerIdentifier: providerIdentifier,
            semanticPrompt: envelope.runtimePrompt
        )
    }

    public static func semanticFingerprint<Kind: Equatable & Sendable, FrontstageState: Equatable & Sendable>(
        for envelope: BASPromptEnvelope<Kind, FrontstageState>
    ) -> String {
        sha256Hex(envelope.runtimePrompt)
    }

    public static func stablePrefixFingerprint<Kind: Equatable & Sendable, FrontstageState: Equatable & Sendable>(
        for envelope: BASPromptEnvelope<Kind, FrontstageState>
    ) -> String {
        sha256Hex(envelope.layers.stablePrefix)
    }

    private static func sha256Hex(
        _ value: String
    ) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

public enum BASPromptRetentionAdvisor {
    public static func evidenceRetentionBudget(
        for kind: BASSemanticTaskKind,
        strategy: BASAdaptiveTaskStrategy?
    ) -> Int {
        let base: Int
        switch kind {
        case .quick:
            base = 5
        case .balance:
            base = 4
        case .mirror:
            base = 4
        case .reminder:
            base = 3
        }

        guard let strategy else { return base }

        let modeBudget: Int
        switch strategy.retrievalMode {
        case .off:
            modeBudget = max(2, base - 1)
        case .filtered:
            modeBudget = base
        case .adaptive:
            modeBudget = base + 1
        }

        let retrievalBounded: Int
        if strategy.retrievalItemBudget > 0 {
            retrievalBounded = max(2, min(modeBudget, strategy.retrievalItemBudget))
        } else {
            retrievalBounded = modeBudget
        }

        if strategy.runtimeGear == .low && (kind == .quick || kind == .reminder) {
            return min(retrievalBounded, 3)
        }

        return retrievalBounded
    }
}
