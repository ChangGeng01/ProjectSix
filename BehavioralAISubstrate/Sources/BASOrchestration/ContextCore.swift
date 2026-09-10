import Foundation

public enum BASContextLayerKind: String, Codable, Sendable, CaseIterable {
    case kernel
    case active
    case summary
    case retrieval

    public var title: String {
        switch self {
        case .kernel:
            "Kernel"
        case .active:
            "Active"
        case .summary:
            "Summary"
        case .retrieval:
            "Retrieval"
        }
    }
}

public enum BASContextLayerRetention: String, Codable, Sendable, CaseIterable {
    case required
    case preferred
    case onDemand
}

public struct BASContextBlock: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var layer: BASContextLayerKind
    public var title: String
    public var content: String
    public var retention: BASContextLayerRetention
    public var priority: Int

    public init(
        id: String,
        layer: BASContextLayerKind,
        title: String,
        content: String,
        retention: BASContextLayerRetention,
        priority: Int
    ) {
        self.id = id
        self.layer = layer
        self.title = title
        self.content = content
        self.retention = retention
        self.priority = priority
    }

    public var estimatedCharacters: Int {
        title.count + content.count + 4
    }

    public var rendered: String {
        "\(title): \(content)"
    }
}

public struct BASContextCompactionRequest: Codable, Sendable, Equatable {
    public var targetCharacters: Int
    public var maximumRetrievalBlocks: Int
    public var blocks: [BASContextBlock]

    public init(
        targetCharacters: Int,
        maximumRetrievalBlocks: Int = 2,
        blocks: [BASContextBlock]
    ) {
        self.targetCharacters = targetCharacters
        self.maximumRetrievalBlocks = maximumRetrievalBlocks
        self.blocks = blocks
    }
}

public struct BASContextCompactionPlan: Codable, Sendable, Equatable {
    public var targetCharacters: Int
    public var retainedBlocks: [BASContextBlock]
    public var droppedBlocks: [BASContextBlock]

    public init(
        targetCharacters: Int,
        retainedBlocks: [BASContextBlock],
        droppedBlocks: [BASContextBlock]
    ) {
        self.targetCharacters = targetCharacters
        self.retainedBlocks = retainedBlocks
        self.droppedBlocks = droppedBlocks
    }

    public var usedCharacters: Int {
        retainedBlocks.map(\.estimatedCharacters).reduce(0, +)
    }

    public var retainedKernelCount: Int {
        retainedBlocks.filter { $0.layer == .kernel }.count
    }

    public var retainedSummaryCount: Int {
        retainedBlocks.filter { $0.layer == .summary }.count
    }

    public var retainedRetrievalCount: Int {
        retainedBlocks.filter { $0.layer == .retrieval }.count
    }

    public var renderedContext: String {
        retainedBlocks.map(\.rendered).joined(separator: "\n")
    }
}

public enum BASContextCompactor {
    public static func compact(
        _ request: BASContextCompactionRequest
    ) -> BASContextCompactionPlan {
        let ordered = stableOrder(for: request.blocks)
        var retained: [BASContextBlock] = []
        var dropped: [BASContextBlock] = []
        var usedCharacters = 0
        var retrievalCount = 0

        for block in ordered {
            let blockCharacters = block.estimatedCharacters
            let wouldOverflow = usedCharacters + blockCharacters > request.targetCharacters
            let isRetrieval = block.layer == .retrieval

            if isRetrieval && retrievalCount >= request.maximumRetrievalBlocks {
                dropped.append(block)
                continue
            }

            let shouldForceKeep = block.retention == .required
            if !shouldForceKeep && wouldOverflow {
                dropped.append(block)
                continue
            }

            retained.append(block)
            usedCharacters += blockCharacters
            if isRetrieval {
                retrievalCount += 1
            }
        }

        return BASContextCompactionPlan(
            targetCharacters: request.targetCharacters,
            retainedBlocks: retained,
            droppedBlocks: dropped
        )
    }

    private static func stableOrder(
        for blocks: [BASContextBlock]
    ) -> [BASContextBlock] {
        let orderByLayer: [BASContextLayerKind: Int] = [
            .kernel: 0,
            .active: 1,
            .summary: 2,
            .retrieval: 3
        ]
        let orderByRetention: [BASContextLayerRetention: Int] = [
            .required: 0,
            .preferred: 1,
            .onDemand: 2
        ]

        return blocks.sorted { lhs, rhs in
            let lhsRetention = orderByRetention[lhs.retention] ?? 99
            let rhsRetention = orderByRetention[rhs.retention] ?? 99
            if lhsRetention != rhsRetention {
                return lhsRetention < rhsRetention
            }

            let lhsLayer = orderByLayer[lhs.layer] ?? 99
            let rhsLayer = orderByLayer[rhs.layer] ?? 99
            if lhsLayer != rhsLayer {
                return lhsLayer < rhsLayer
            }

            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }

            return lhs.id < rhs.id
        }
    }
}
