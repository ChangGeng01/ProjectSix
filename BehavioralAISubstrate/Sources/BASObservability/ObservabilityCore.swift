import Foundation
import BASMemory
import BASPolicy
import BASRuntimeCore

public struct BASTraceLatencyBreakdown: Codable, Sendable, Equatable {
    public var routeSelectionMs: Int
    public var retrievalMs: Int
    public var generationMs: Int
    public var toolMs: Int

    public init(routeSelectionMs: Int, retrievalMs: Int, generationMs: Int, toolMs: Int) {
        self.routeSelectionMs = routeSelectionMs
        self.retrievalMs = retrievalMs
        self.generationMs = generationMs
        self.toolMs = toolMs
    }

    public var totalMs: Int { routeSelectionMs + retrievalMs + generationMs + toolMs }
}

public struct BASAuditEvent: Codable, Sendable, Equatable {
    public var id: UUID
    public var category: String
    public var message: String
    public var timestamp: Date
    public var metadata: [String: String]

    public init(id: UUID = UUID(), category: String, message: String, timestamp: Date = .now, metadata: [String: String] = [:]) {
        self.id = id
        self.category = category
        self.message = message
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

public struct BASExecutionTrace: Codable, Sendable, Equatable {
    public var inputSummary: String
    public var selectedRoute: BASModelRoute
    public var memoriesRecalled: [String]
    public var toolsCalled: [String]
    public var latency: BASTraceLatencyBreakdown
    public var auditEvents: [BASAuditEvent]
    public var outputSummary: String

    public init(
        inputSummary: String,
        selectedRoute: BASModelRoute,
        memoriesRecalled: [String],
        toolsCalled: [String],
        latency: BASTraceLatencyBreakdown,
        auditEvents: [BASAuditEvent] = [],
        outputSummary: String
    ) {
        self.inputSummary = inputSummary
        self.selectedRoute = selectedRoute
        self.memoriesRecalled = memoriesRecalled
        self.toolsCalled = toolsCalled
        self.latency = latency
        self.auditEvents = auditEvents
        self.outputSummary = outputSummary
    }
}

public struct BASReplayBundle: Codable, Sendable, Equatable {
    public var trace: BASExecutionTrace
    public var brainState: BASCurrentBrainState
    public var runtimeContext: BASRuntimeContext
    public var policyDecision: BASPolicyDecisionRecord

    public init(trace: BASExecutionTrace, brainState: BASCurrentBrainState, runtimeContext: BASRuntimeContext, policyDecision: BASPolicyDecisionRecord) {
        self.trace = trace
        self.brainState = brainState
        self.runtimeContext = runtimeContext
        self.policyDecision = policyDecision
    }
}

public struct BASAnomalySignal: Codable, Sendable, Equatable {
    public var id: UUID
    public var kind: String
    public var severity: String
    public var message: String
    public var timestamp: Date

    public init(id: UUID = UUID(), kind: String, severity: String, message: String, timestamp: Date = .now) {
        self.id = id
        self.kind = kind
        self.severity = severity
        self.message = message
        self.timestamp = timestamp
    }
}
