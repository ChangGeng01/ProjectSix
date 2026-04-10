import Foundation

public struct BASPromptBudget: Codable, Sendable, Equatable {
    public let targetCharacters: Int
    public let prefixCharacters: Int
    public let suffixCharacters: Int
    public let immutablePrefixCharacters: Int
    public let adaptivePrefixCharacters: Int

    public var totalCharacters: Int {
        prefixCharacters + suffixCharacters
    }

    public var isWithinTarget: Bool {
        totalCharacters <= targetCharacters
    }

    public var utilizationRatio: Double {
        guard targetCharacters > 0 else { return 0 }
        return Double(totalCharacters) / Double(targetCharacters)
    }

    public var stablePrefixShare: Double {
        guard totalCharacters > 0 else { return 0 }
        return Double(prefixCharacters) / Double(totalCharacters)
    }

    public var volatileSuffixShare: Double {
        guard totalCharacters > 0 else { return 0 }
        return Double(suffixCharacters) / Double(totalCharacters)
    }

    public var promptPressureSnapshot: BASPromptBudgetSnapshot {
        BASPromptBudgetSnapshot(
            targetCharacters: targetCharacters,
            prefixCharacters: prefixCharacters,
            suffixCharacters: suffixCharacters
        )
    }

    public init(
        targetCharacters: Int,
        prefixCharacters: Int,
        suffixCharacters: Int,
        immutablePrefixCharacters: Int? = nil,
        adaptivePrefixCharacters: Int? = nil
    ) {
        self.targetCharacters = targetCharacters
        self.prefixCharacters = prefixCharacters
        self.suffixCharacters = suffixCharacters

        let resolvedImmutable = immutablePrefixCharacters ?? prefixCharacters
        let resolvedAdaptive = adaptivePrefixCharacters ?? max(0, prefixCharacters - resolvedImmutable)
        self.immutablePrefixCharacters = resolvedImmutable
        self.adaptivePrefixCharacters = resolvedAdaptive
    }
}

public struct BASPromptLayers: Codable, Sendable, Equatable {
    public let immutablePrefix: String
    public let adaptivePrefix: String
    public let volatileSuffix: String

    public var stablePrefix: String {
        [immutablePrefix, adaptivePrefix]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    public var runtimePrompt: String {
        [stablePrefix, volatileSuffix]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    public init(
        immutablePrefix: String,
        adaptivePrefix: String,
        volatileSuffix: String
    ) {
        self.immutablePrefix = immutablePrefix
        self.adaptivePrefix = adaptivePrefix
        self.volatileSuffix = volatileSuffix
    }
}

public struct BASPromptEnvelope<Kind: Equatable & Sendable, FrontstageState: Equatable & Sendable>: Sendable, Equatable {
    public let kind: Kind
    public let instructions: String
    public let payload: String
    public let debugPrompt: String
    public let budget: BASPromptBudget
    public let layers: BASPromptLayers
    public let assembly: BASSemanticContextAssembly
    public let frontstageState: FrontstageState
    public let openTextSignalCount: Int

    public var runtimePrompt: String {
        layers.runtimePrompt
    }

    public init(
        kind: Kind,
        instructions: String,
        payload: String,
        debugPrompt: String,
        budget: BASPromptBudget,
        layers: BASPromptLayers,
        assembly: BASSemanticContextAssembly,
        frontstageState: FrontstageState,
        openTextSignalCount: Int
    ) {
        self.kind = kind
        self.instructions = instructions
        self.payload = payload
        self.debugPrompt = debugPrompt
        self.budget = budget
        self.layers = layers
        self.assembly = assembly
        self.frontstageState = frontstageState
        self.openTextSignalCount = openTextSignalCount
    }
}

public struct BASPromptEnvelopeRequest<Kind: Equatable & Sendable, FrontstageState: Equatable & Sendable>: Sendable, Equatable {
    public let kind: Kind
    public let immutablePrefix: String
    public let adaptivePrefix: String
    public let assembly: BASSemanticContextAssembly
    public let frontstageState: FrontstageState
    public let openTextSignalCount: Int
    public let targetCharacters: Int

    public init(
        kind: Kind,
        immutablePrefix: String,
        adaptivePrefix: String,
        assembly: BASSemanticContextAssembly,
        frontstageState: FrontstageState,
        openTextSignalCount: Int,
        targetCharacters: Int
    ) {
        self.kind = kind
        self.immutablePrefix = immutablePrefix
        self.adaptivePrefix = adaptivePrefix
        self.assembly = assembly
        self.frontstageState = frontstageState
        self.openTextSignalCount = openTextSignalCount
        self.targetCharacters = targetCharacters
    }
}

public enum BASPromptEnvelopeCompiler {
    public static func compile<Kind: Equatable & Sendable, FrontstageState: Equatable & Sendable>(
        _ request: BASPromptEnvelopeRequest<Kind, FrontstageState>
    ) -> BASPromptEnvelope<Kind, FrontstageState> {
        let instructions = [request.immutablePrefix, request.adaptivePrefix]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        let payload = request.assembly.payload
        let layers = BASPromptLayers(
            immutablePrefix: request.immutablePrefix,
            adaptivePrefix: request.adaptivePrefix,
            volatileSuffix: payload
        )

        var debugPromptSections = [
            "[IMMUTABLE PREFIX]",
            request.immutablePrefix,
            "",
            "[ADAPTIVE PREFIX]",
            request.adaptivePrefix,
            "",
            "[VOLATILE SUFFIX]",
            payload
        ]
        if !request.assembly.droppedBlocks.isEmpty {
            debugPromptSections += [
                "",
                "[COMPACTION]",
                "Dropped blocks: \(request.assembly.droppedBlockKinds.map { $0.rawValue }.joined(separator: ", "))"
            ]
        }

        return BASPromptEnvelope(
            kind: request.kind,
            instructions: instructions,
            payload: payload,
            debugPrompt: debugPromptSections.joined(separator: "\n"),
            budget: BASPromptBudget(
                targetCharacters: request.targetCharacters,
                prefixCharacters: instructions.count,
                suffixCharacters: payload.count,
                immutablePrefixCharacters: request.immutablePrefix.count,
                adaptivePrefixCharacters: request.adaptivePrefix.count
            ),
            layers: layers,
            assembly: request.assembly,
            frontstageState: request.frontstageState,
            openTextSignalCount: request.openTextSignalCount
        )
    }
}

public extension BASSemanticContextAssembly {
    var retainedBlockKinds: [BASSemanticPromptBlockKind] {
        retainedBlocks.map(\.kind)
    }

    var droppedBlockKinds: [BASSemanticPromptBlockKind] {
        droppedBlocks.map(\.kind)
    }
}
