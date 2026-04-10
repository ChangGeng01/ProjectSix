import CryptoKit
import Foundation
import BASPolicy

public struct BASContextKernelPolicy: Codable, Sendable, Equatable {
    public var preservedBlockIDs: [String]
    public var preferredBlockIDs: [String]
    public var dropOrderIDs: [String]

    public init(
        preservedBlockIDs: [String] = [],
        preferredBlockIDs: [String] = [],
        dropOrderIDs: [String] = []
    ) {
        self.preservedBlockIDs = preservedBlockIDs
        self.preferredBlockIDs = preferredBlockIDs
        self.dropOrderIDs = dropOrderIDs
    }
}

public struct BASCognitionKernelRequest: Codable, Sendable, Equatable {
    public var blocks: [BASContextBlock]
    public var compilationPolicy: BASContextCompilationPolicy
    public var kernelPolicy: BASContextKernelPolicy
    public var truthState: BASStructuredTruthState?

    public init(
        blocks: [BASContextBlock],
        compilationPolicy: BASContextCompilationPolicy,
        kernelPolicy: BASContextKernelPolicy = BASContextKernelPolicy(),
        truthState: BASStructuredTruthState? = nil
    ) {
        self.blocks = blocks
        self.compilationPolicy = compilationPolicy
        self.kernelPolicy = kernelPolicy
        self.truthState = truthState
    }
}

public struct BASCognitionKernelSnapshot: Codable, Sendable, Equatable {
    public var compiledPrompt: BASCompiledPrompt
    public var truthState: BASStructuredTruthState?
    public var kernelPolicy: BASContextKernelPolicy
    public var kernelBlockCount: Int
    public var activeBlockCount: Int
    public var summaryBlockCount: Int
    public var retrievalBlockCount: Int

    public init(
        compiledPrompt: BASCompiledPrompt,
        truthState: BASStructuredTruthState?,
        kernelPolicy: BASContextKernelPolicy,
        kernelBlockCount: Int,
        activeBlockCount: Int,
        summaryBlockCount: Int,
        retrievalBlockCount: Int
    ) {
        self.compiledPrompt = compiledPrompt
        self.truthState = truthState
        self.kernelPolicy = kernelPolicy
        self.kernelBlockCount = kernelBlockCount
        self.activeBlockCount = activeBlockCount
        self.summaryBlockCount = summaryBlockCount
        self.retrievalBlockCount = retrievalBlockCount
    }

    public var frontstageBlockCount: Int {
        kernelBlockCount + activeBlockCount
    }
}

public enum BASCognitionKernelReleaseDecisionKind: String, Codable, Sendable {
    case allow
    case repair
    case reject
}

public struct BASCognitionKernelReleaseRequest: Codable, Sendable, Equatable {
    public var kernel: BASCognitionKernelSnapshot
    public var responseMode: String
    public var responseText: String
    public var proposedActions: [String]
    public var referencedFacts: [String: String]

    public init(
        kernel: BASCognitionKernelSnapshot,
        responseMode: String,
        responseText: String,
        proposedActions: [String] = [],
        referencedFacts: [String: String] = [:]
    ) {
        self.kernel = kernel
        self.responseMode = responseMode
        self.responseText = responseText
        self.proposedActions = proposedActions
        self.referencedFacts = referencedFacts
    }
}

public struct BASCognitionKernelReleaseDecision: Codable, Sendable, Equatable {
    public var kind: BASCognitionKernelReleaseDecisionKind
    public var reason: String
    public var consistencyCheck: BASConsistencyCheckResult?

    public init(
        kind: BASCognitionKernelReleaseDecisionKind,
        reason: String,
        consistencyCheck: BASConsistencyCheckResult?
    ) {
        self.kind = kind
        self.reason = reason
        self.consistencyCheck = consistencyCheck
    }
}

public enum BASCognitionKernel {
    public static func compile(
        _ request: BASCognitionKernelRequest
    ) -> BASCognitionKernelSnapshot {
        let initial = BASContextCompiler.compile(
            BASContextCompilationRequest(
                blocks: request.blocks,
                policy: request.compilationPolicy
            )
        )

        var retained = initial.retainedBlocks
        var dropped = initial.droppedBlocks
        let preserved = Set(request.kernelPolicy.preservedBlockIDs)
        let dropOrderIndex = Dictionary(
            uniqueKeysWithValues: request.kernelPolicy.dropOrderIDs.enumerated().map { ($0.element, $0.offset) }
        )

        while renderedLength(of: retained, separator: request.compilationPolicy.blockSeparator) > request.compilationPolicy.targetCharacters {
            guard let index = retained.enumerated()
                .filter({ !preserved.contains($0.element.id) })
                .sorted(by: { lhs, rhs in
                    let lhsDropRank = dropOrderIndex[lhs.element.id] ?? Int.max
                    let rhsDropRank = dropOrderIndex[rhs.element.id] ?? Int.max
                    if lhsDropRank != rhsDropRank {
                        return lhsDropRank < rhsDropRank
                    }

                    let lhsRetentionRank = retentionRank(lhs.element.retention)
                    let rhsRetentionRank = retentionRank(rhs.element.retention)
                    if lhsRetentionRank != rhsRetentionRank {
                        return lhsRetentionRank < rhsRetentionRank
                    }

                    if lhs.element.priority == rhs.element.priority {
                        return lhs.offset > rhs.offset
                    }
                    return lhs.element.priority < rhs.element.priority
                })
                .first?.offset else {
                break
            }

            dropped.append(retained.remove(at: index))
        }

        let stablePrefixBlocks = retained.filter { $0.retention != .onDemand }
        let volatileSuffixBlocks = retained.filter { $0.retention == .onDemand }
        let stablePrefixPrompt = render(stablePrefixBlocks, separator: request.compilationPolicy.blockSeparator)
        let volatileSuffixPrompt = render(volatileSuffixBlocks, separator: request.compilationPolicy.blockSeparator)
        let renderedPrompt = [stablePrefixPrompt, volatileSuffixPrompt]
            .filter { !$0.isEmpty }
            .joined(separator: request.compilationPolicy.sectionSeparator)

        let compiledPrompt = BASCompiledPrompt(
            policy: request.compilationPolicy,
            retainedBlocks: retained,
            stablePrefixBlocks: stablePrefixBlocks,
            volatileSuffixBlocks: volatileSuffixBlocks,
            droppedBlocks: dropped,
            stablePrefixPrompt: stablePrefixPrompt,
            volatileSuffixPrompt: volatileSuffixPrompt,
            renderedPrompt: renderedPrompt,
            stablePrefixFingerprint: fingerprint(
                "stable|\(policyMaterial(request.compilationPolicy))|\(signature(for: stablePrefixBlocks))"
            ),
            semanticFingerprint: fingerprint(
                "semantic|\(policyMaterial(request.compilationPolicy))|retained|\(signature(for: retained))|dropped|\(signature(for: dropped))"
            )
        )

        return BASCognitionKernelSnapshot(
            compiledPrompt: compiledPrompt,
            truthState: request.truthState,
            kernelPolicy: request.kernelPolicy,
            kernelBlockCount: retained.filter { $0.layer == .kernel }.count,
            activeBlockCount: retained.filter { $0.layer == .active }.count,
            summaryBlockCount: retained.filter { $0.layer == .summary }.count,
            retrievalBlockCount: retained.filter { $0.layer == .retrieval }.count
        )
    }

    public static func releaseDecision(
        for request: BASCognitionKernelReleaseRequest
    ) -> BASCognitionKernelReleaseDecision {
        guard let truthState = request.kernel.truthState else {
            return BASCognitionKernelReleaseDecision(
                kind: .allow,
                reason: "No structured truth state was attached to this kernel.",
                consistencyCheck: nil
            )
        }

        let consistency = BASConsistencyHarness.evaluate(
            BASConsistencyCheckInput(
                truthState: truthState,
                responseMode: request.responseMode,
                responseText: request.responseText,
                proposedActions: request.proposedActions,
                referencedFacts: request.referencedFacts
            )
        )

        guard !consistency.isConsistent else {
            return BASCognitionKernelReleaseDecision(
                kind: .allow,
                reason: "Response stayed inside the kernel truth state.",
                consistencyCheck: consistency
            )
        }

        let rejectKinds: Set<BASConsistencyViolationKind> = [
            .modeMismatch,
            .forbiddenAction,
            .factConflict
        ]
        let shouldReject = consistency.violations.contains { rejectKinds.contains($0.kind) }

        return BASCognitionKernelReleaseDecision(
            kind: shouldReject ? .reject : .repair,
            reason: shouldReject
                ? "Response drifted outside truth-state boundaries and must not be released."
                : "Response is close enough to repair, but not safe to release unchanged.",
            consistencyCheck: consistency
        )
    }

    private static func renderedLength(
        of blocks: [BASContextBlock],
        separator: String
    ) -> Int {
        render(blocks, separator: separator).count
    }

    private static func render(
        _ blocks: [BASContextBlock],
        separator: String
    ) -> String {
        blocks.map(\.rendered).joined(separator: separator)
    }

    private static func retentionRank(
        _ retention: BASContextLayerRetention
    ) -> Int {
        switch retention {
        case .onDemand:
            return 0
        case .preferred:
            return 1
        case .required:
            return 2
        }
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

    private static func fingerprint(_ material: String) -> String {
        let digest = SHA256.hash(data: Data(material.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
