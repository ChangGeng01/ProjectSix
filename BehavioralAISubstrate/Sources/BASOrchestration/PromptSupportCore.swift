import CryptoKit
import Foundation
import BASRuntimeCore

public struct BASPromptPresentationBehavior: Codable, Equatable, Sendable {
    public var sharedPrelude: String
    public var adaptivePrefixByKindID: [String: String]
    public var baseEvidenceRetentionBudgetByKindID: [String: Int]
    public var lowGearClampKindIDs: [String]
    public var lowGearClampMaximumBudget: Int

    public init(
        sharedPrelude: String = """
        You are the language rendering layer for a host-owned cognition system.
        The host owns state, routing, policy, actions, and final release.
        Tighten language without adding facts, changing decisions, or inventing actions.
        Keep the tone grounded, calm, and concise.
        """,
        adaptivePrefixByKindID: [String: String] = [
            BASSemanticTaskKind.quick.rawValue: """
            Refine only the supplied paired perspective fields.
            Preserve the decision frame, actions, and intended emotional direction.
            """,
            BASSemanticTaskKind.balance.rawValue: """
            Tighten the supplied comparison fields without inventing facts or collapsing them into a verdict.
            Preserve the same focus and next-step intent.
            """,
            BASSemanticTaskKind.mirror.rawValue: """
            Clarify the supplied reflective fields without becoming dramatic, clinical, or binary.
            Preserve the same tension and next reflective move.
            """,
            BASSemanticTaskKind.reminder.rawValue: """
            Select one supplied candidate that best matches the current state.
            Do not rewrite or invent candidate text.
            """
        ],
        baseEvidenceRetentionBudgetByKindID: [String: Int] = [
            BASSemanticTaskKind.quick.rawValue: 5,
            BASSemanticTaskKind.balance.rawValue: 4,
            BASSemanticTaskKind.mirror.rawValue: 4,
            BASSemanticTaskKind.reminder.rawValue: 3
        ],
        lowGearClampKindIDs: [String] = [
            BASSemanticTaskKind.quick.rawValue,
            BASSemanticTaskKind.reminder.rawValue
        ],
        lowGearClampMaximumBudget: Int = 3
    ) {
        self.sharedPrelude = sharedPrelude
        self.adaptivePrefixByKindID = adaptivePrefixByKindID
        self.baseEvidenceRetentionBudgetByKindID = baseEvidenceRetentionBudgetByKindID
        self.lowGearClampKindIDs = lowGearClampKindIDs
        self.lowGearClampMaximumBudget = lowGearClampMaximumBudget
    }

    public static let generic = BASPromptPresentationBehavior()

    public func immutablePrefix(
        for kind: BASSemanticTaskKind
    ) -> String {
        _ = kind
        return sharedPrelude
    }

    public func adaptivePrefix(
        for kind: BASSemanticTaskKind
    ) -> String {
        adaptivePrefixByKindID[kind.rawValue, default: fallbackAdaptivePrefix(for: kind)]
    }

    public func evidenceRetentionBudget(
        for kind: BASSemanticTaskKind,
        strategy: BASAdaptiveTaskStrategy?
    ) -> Int {
        let base = baseEvidenceRetentionBudgetByKindID[kind.rawValue, default: fallbackBaseEvidenceRetentionBudget(for: kind)]

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

        if strategy.runtimeGear == .low && lowGearClampKindIDs.contains(kind.rawValue) {
            return min(retrievalBounded, lowGearClampMaximumBudget)
        }

        return retrievalBounded
    }

    private func fallbackAdaptivePrefix(
        for kind: BASSemanticTaskKind
    ) -> String {
        switch kind {
        case .quick:
            "Refine only the supplied paired perspective fields."
        case .balance:
            "Tighten the supplied comparison fields without inventing facts."
        case .mirror:
            "Clarify the supplied reflective fields without changing their meaning."
        case .reminder:
            "Select one supplied candidate without rewriting it."
        }
    }

    private func fallbackBaseEvidenceRetentionBudget(
        for kind: BASSemanticTaskKind
    ) -> Int {
        switch kind {
        case .quick:
            5
        case .balance:
            4
        case .mirror:
            4
        case .reminder:
            3
        }
    }
}

public enum BASPromptPrefixCatalog {
    public static let genericBehavior = BASPromptPresentationBehavior.generic

    public static let sharedPrelude = """
    You are the language rendering layer for a host-owned cognition system.
    The host owns state, routing, safety, verdicts, and actions.
    You only tighten wording or select from provided options.
    Keep the tone calm, short, and non-shaming.
    """

    public static let quick = """
    Rewrite only the supplied paired perspective fields.
    Keep the same meaning and do not change verdicts or actions.
    """

    public static let balance = """
    Tighten the supplied comparison fields without inventing new facts or turning them into a verdict.
    Preserve the same focus and next-step intent.
    """

    public static let mirror = """
    Clarify the supplied reflective fields without becoming dramatic, therapeutic, or binary.
    Preserve the same tension and reflective next move.
    """

    public static let reminder = """
    Pick one supplied candidate that best matches the current state.
    Do not rewrite or invent candidate text.
    """

    public static func instructions(
        for kind: BASSemanticTaskKind,
        behavior: BASPromptPresentationBehavior = genericBehavior
    ) -> String {
        behavior.immutablePrefix(for: kind) + "\n" + adaptivePrefix(for: kind, behavior: behavior)
    }

    public static func immutablePrefix(
        for kind: BASSemanticTaskKind,
        behavior: BASPromptPresentationBehavior = genericBehavior
    ) -> String {
        behavior.immutablePrefix(for: kind)
    }

    public static func adaptivePrefix(
        for kind: BASSemanticTaskKind,
        behavior: BASPromptPresentationBehavior = genericBehavior
    ) -> String {
        behavior.adaptivePrefix(for: kind)
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
        strategy: BASAdaptiveTaskStrategy?,
        behavior: BASPromptPresentationBehavior = BASPromptPresentationBehavior.generic
    ) -> Int {
        behavior.evidenceRetentionBudget(for: kind, strategy: strategy)
    }
}
