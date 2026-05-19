import CryptoKit
import Foundation
// chapter 七百二 native-port — Rust SHA256 primitive。 Legacy
// CryptoKit body preserved as `/* ... */` per 全comment 不要删除。
import BASRustHashCore

public struct BASContextCompilationPolicy: Codable, Sendable, Equatable {
    public var targetCharacters: Int
    public var maximumRetrievalBlocks: Int
    public var blockSeparator: String
    public var sectionSeparator: String

    public init(
        targetCharacters: Int,
        maximumRetrievalBlocks: Int = 2,
        blockSeparator: String = "\n",
        sectionSeparator: String = "\n\n"
    ) {
        self.targetCharacters = targetCharacters
        self.maximumRetrievalBlocks = maximumRetrievalBlocks
        self.blockSeparator = blockSeparator
        self.sectionSeparator = sectionSeparator
    }
}

public struct BASContextCompilationRequest: Codable, Sendable, Equatable {
    public var blocks: [BASContextBlock]
    public var policy: BASContextCompilationPolicy

    public init(
        blocks: [BASContextBlock],
        policy: BASContextCompilationPolicy
    ) {
        self.blocks = blocks
        self.policy = policy
    }
}

public struct BASCompiledPrompt: Codable, Sendable, Equatable {
    public var policy: BASContextCompilationPolicy
    public var retainedBlocks: [BASContextBlock]
    public var stablePrefixBlocks: [BASContextBlock]
    public var volatileSuffixBlocks: [BASContextBlock]
    public var droppedBlocks: [BASContextBlock]
    public var stablePrefixPrompt: String
    public var volatileSuffixPrompt: String
    public var renderedPrompt: String
    public var stablePrefixFingerprint: String
    public var semanticFingerprint: String

    public init(
        policy: BASContextCompilationPolicy,
        retainedBlocks: [BASContextBlock],
        stablePrefixBlocks: [BASContextBlock],
        volatileSuffixBlocks: [BASContextBlock],
        droppedBlocks: [BASContextBlock],
        stablePrefixPrompt: String,
        volatileSuffixPrompt: String,
        renderedPrompt: String,
        stablePrefixFingerprint: String,
        semanticFingerprint: String
    ) {
        self.policy = policy
        self.retainedBlocks = retainedBlocks
        self.stablePrefixBlocks = stablePrefixBlocks
        self.volatileSuffixBlocks = volatileSuffixBlocks
        self.droppedBlocks = droppedBlocks
        self.stablePrefixPrompt = stablePrefixPrompt
        self.volatileSuffixPrompt = volatileSuffixPrompt
        self.renderedPrompt = renderedPrompt
        self.stablePrefixFingerprint = stablePrefixFingerprint
        self.semanticFingerprint = semanticFingerprint
    }
}

public enum BASContextCompiler {
    public static func compile(_ request: BASContextCompilationRequest) -> BASCompiledPrompt {
        let plan = BASContextCompactor.compact(
            BASContextCompactionRequest(
                targetCharacters: request.policy.targetCharacters,
                maximumRetrievalBlocks: request.policy.maximumRetrievalBlocks,
                blocks: request.blocks
            )
        )

        let retainedBlocks = plan.retainedBlocks
        let stablePrefixBlocks = retainedBlocks.filter { $0.retention != .onDemand }
        let volatileSuffixBlocks = retainedBlocks.filter { $0.retention == .onDemand }

        let stablePrefixPrompt = render(
            blocks: stablePrefixBlocks,
            separator: request.policy.blockSeparator
        )
        let volatileSuffixPrompt = render(
            blocks: volatileSuffixBlocks,
            separator: request.policy.blockSeparator
        )
        let renderedPrompt = joinSections(
            [stablePrefixPrompt, volatileSuffixPrompt],
            separator: request.policy.sectionSeparator
        )

        return BASCompiledPrompt(
            policy: request.policy,
            retainedBlocks: retainedBlocks,
            stablePrefixBlocks: stablePrefixBlocks,
            volatileSuffixBlocks: volatileSuffixBlocks,
            droppedBlocks: plan.droppedBlocks,
            stablePrefixPrompt: stablePrefixPrompt,
            volatileSuffixPrompt: volatileSuffixPrompt,
            renderedPrompt: renderedPrompt,
            stablePrefixFingerprint: fingerprint(
                "stable|\(policyMaterial(request.policy))|\(signature(for: stablePrefixBlocks))"
            ),
            semanticFingerprint: fingerprint(
                "semantic|\(policyMaterial(request.policy))|retained|\(signature(for: retainedBlocks))|dropped|\(signature(for: plan.droppedBlocks))"
            )
        )
    }

    private static func render(
        blocks: [BASContextBlock],
        separator: String
    ) -> String {
        blocks.map(\.rendered).joined(separator: separator)
    }

    private static func joinSections(
        _ sections: [String],
        separator: String
    ) -> String {
        sections
            .filter { !$0.isEmpty }
            .joined(separator: separator)
    }

    private static func policyMaterial(_ policy: BASContextCompilationPolicy) -> String {
        [
            "target=\(policy.targetCharacters)",
            "retrieval=\(policy.maximumRetrievalBlocks)",
            "blockSeparator=\(policy.blockSeparator)",
            "sectionSeparator=\(policy.sectionSeparator)"
        ]
        .joined(separator: "|")
    }

    private static func signature(for blocks: [BASContextBlock]) -> String {
        blocks.map(signature(for:)).joined(separator: "\u{001F}")
    }

    private static func signature(for block: BASContextBlock) -> String {
        [
            block.id,
            block.layer.rawValue,
            block.title,
            block.content,
            block.retention.rawValue,
            String(block.priority)
        ]
        .joined(separator: "|")
    }

    /// chapter 七百二 native-port — Rust-sourced fingerprint;
    /// legacy CryptoKit body preserved per 全comment 不要删除。
    private static func fingerprint(_ material: String) -> String {
        let data = Data(material.utf8)
        if let rust = try? BASRustLedgerCore.sha256(data) {
            return rust.map { String(format: "%02x", $0) }
                .joined()
        }
        // LEGACY CryptoKit BODY — preserved per 全comment 不要删除。
        /*
         * Pre-chapter-702 Swift implementation:
         *     let digest = SHA256.hash(data: Data(material.utf8))
         *     return digest.map { String(format: "%02x", $0) }.joined()
         */
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
