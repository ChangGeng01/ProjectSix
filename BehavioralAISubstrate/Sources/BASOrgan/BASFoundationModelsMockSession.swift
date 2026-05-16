// MARK: - BASFoundationModelsMockSession — chapter 四百 / M920
//
// G6 收尾 step 3:in-process mock of the iOS 26 `LanguageModel
// Session` surface for substrate-side tests。Pre-M920 substrate
// tests that wanted to exercise tool-calling end-to-end had no
// way to do so without an iOS 26 device — every test that
// touched AFM was guarded behind `#if canImport(FoundationModels)
// && available`,which evaluates false on macOS CI / sub-iOS-26
// developer machines。
//
// Post-M920 the mock provides a substrate-class session
// surface with:
//   - scriptable response sequences (caller pre-loads bodies,
//     mock returns them in order)
//   - scriptable tool-call emissions (caller declares which
//     tool the mock should ASK to invoke + with what arguments)
//   - per-call latency simulation
//   - typed call recording for test assertions
//
// This is NOT a substitute for real device exercise — it
// proves the SUBSTRATE wiring is correct,not that the real
// AFM model returns sensible tool calls。M870 audit-trace +
// M916 bridge resolution still apply。
//
// ## Why in-process mock vs. test-double protocol
//
// Substrate-doctrine choice (chapter 二百一一 single-source-of-
// truth):the real `BASOrganAdapter` protocol is what we test
// against。`BASFoundationModelsMockSession` is a `BASOrgan
// Adapter` conformer that pretends to be AFM。Tests construct
// it,inject into `BASToolCallingPlanner`(M915) or any other
// composition point,assert behavior。
//
// This mirrors the M915 `ScriptedAdapter` test fixture but
// promotes it to a SHIPPABLE substrate primitive (lives outside
// `Tests/`,available to host integration tests in SampleHost
// or any downstream package)。
//
// ## What this ships
//
//   - `BASFoundationModelsMockSession` actor conforming to
//     `BASOrganAdapter` (Sendable + descriptor + draft +
//     currentCapacity)
//   - `BASFoundationModelsMockResponse` typed Codable enum:
//     `.text(body:)` / `.toolCall(invocation:)` /
//     `.error(reason:)`
//   - `BASFoundationModelsMockCallRecord` typed Sendable
//     struct: each `draft(...)` invocation captures the
//     request + which scripted response was returned
//   - `BASFoundationModelsMockSession.scriptedResponses` /
//     `.callRecords()` accessors for test assertions
//   - `BASFoundationModelsMockSession.simulatedLatencyMs`
//     setter for testing deadline enforcement
//
// ## Doctrine pins held
//
// - 不变量 #1 / #2 / #3 全保 — mock is observation,never
//   touches permits / verdicts / commit token
// - chapter 二百一一 single-source-of-truth — mock is
//   explicit substrate primitive, not a private test fixture
// - chapter 三百九二 (M892) replay-determinism — same
//   scripted responses + same input order → same outputs
// - ADR-014 OPT-IN — production code path NEVER constructs
//   the mock;only test code does (no behavior risk)

import Foundation
import BASRuntimeCore

// MARK: - Scripted response

/// Typed enum of mock-session response shapes。Caller
/// pre-loads a sequence of these;each `draft(...)` call
/// consumes the next entry。
public enum BASFoundationModelsMockResponse:
    Sendable, Equatable, Codable
{
    /// Plain-text response (no tool calls)。
    case text(body: String)

    /// Tool-call request — the mock returns a draft body
    /// containing a typed marker that downstream policy
    /// closures can parse。Body shape:
    /// `"TOOL_CALL:<toolName>:<argumentsJSON>"`
    /// (M915 planner's policy closures match on this prefix
    /// during tests)。
    case toolCall(invocation: BASToolInvocation)

    /// Mock returns an error from `draft(...)`,wrapping the
    /// given reason。
    case error(reason: String)
}

// MARK: - Call record

/// Typed Sendable record of one `draft(...)` invocation。
/// Tests inspect these to verify the planner / dispatcher
/// passed the right request。
public struct BASFoundationModelsMockCallRecord:
    Sendable, Equatable, Codable
{
    /// The full request the mock received (after substrate
    /// composition,e.g. M915 planner concatenated tool
    /// results into context)。
    public let request: BASOrganRequest

    /// Which scripted response was returned for this call。
    /// Useful for asserting "the 3rd call returned a tool
    /// call,then the 4th returned final text"。
    public let respondedWith: BASFoundationModelsMockResponse

    /// Wall-clock timestamp at the moment of the call (ms
    /// since UNIX epoch)。Useful for asserting deadline /
    /// latency。
    public let calledAtMs: Int64

    public init(
        request: BASOrganRequest,
        respondedWith: BASFoundationModelsMockResponse,
        calledAtMs: Int64
    ) {
        self.request = request
        self.respondedWith = respondedWith
        self.calledAtMs = calledAtMs
    }
}

// MARK: - Mock errors

public enum BASFoundationModelsMockError:
    Error, Sendable, Equatable, Codable
{
    /// Caller exhausted the scripted response sequence。
    case scriptExhausted
    /// Caller asked for an `.error(...)` response;mock
    /// throws this with the reason。
    case scripted(reason: String)
}

// MARK: - Mock session

/// Test-only `BASOrganAdapter` conformer that returns
/// scripted responses from a pre-loaded sequence。Used in
/// substrate tests + downstream integration tests to exercise
/// tool-calling pipelines without an iOS 26 device。
public actor BASFoundationModelsMockSession: BASOrganAdapter {

    // MARK: - Adapter conformance

    public nonisolated let descriptor: BASOrganDescriptor

    private var scriptedResponses:
        [BASFoundationModelsMockResponse]
    private var responseIndex: Int = 0
    private var simulatedLatencyMsValue: Int64 = 0
    private var callRecordsValue:
        [BASFoundationModelsMockCallRecord] = []

    public init(
        scriptedResponses:
            [BASFoundationModelsMockResponse],
        providerID: String =
            "bas.test.foundation-models-mock",
        simulatedLatencyMs: Int64 = 0
    ) {
        precondition(simulatedLatencyMs >= 0,
            "simulatedLatencyMs must be >= 0")
        self.scriptedResponses = scriptedResponses
        self.simulatedLatencyMsValue = simulatedLatencyMs
        self.descriptor = BASOrganDescriptor(
            providerID: providerID,
            providerName: "FoundationModels Mock Session",
            supportsStreaming: false,
            maxInputTokens: 4_096,
            maxOutputTokens: 4_096,
            runsOnDevice: true,
            supportedRoles: Set(BASOrganRole.allCases))
    }

    public func draft(
        _ request: BASOrganRequest
    ) async throws -> BASOrganDraft {
        // Simulate latency if configured
        if simulatedLatencyMsValue > 0 {
            try await Task.sleep(
                nanoseconds:
                    UInt64(simulatedLatencyMsValue)
                    * 1_000_000)
        }

        // Pull next scripted response
        guard responseIndex < scriptedResponses.count else {
            throw BASFoundationModelsMockError
                .scriptExhausted
        }
        let response = scriptedResponses[responseIndex]
        responseIndex += 1
        let now = Int64(
            Date().timeIntervalSince1970 * 1_000)
        callRecordsValue.append(
            BASFoundationModelsMockCallRecord(
                request: request,
                respondedWith: response,
                calledAtMs: now))

        switch response {
        case .text(let body):
            return BASOrganDraft(
                requestID: request.requestID,
                providerID: descriptor.providerID,
                role: request.role,
                body: body,
                inputTokensEstimated: 10,
                outputTokensEstimated: body.count / 4,
                producedAt: Date(),
                traceID: "mock-trace-\(responseIndex)")

        case .toolCall(let invocation):
            // Encode the invocation as a parseable text
            // marker so test policy closures can detect it
            let argsJSON: String
            if let data = try? JSONEncoder()
                .encode(invocation.arguments),
               let str = String(
                data: data, encoding: .utf8)
            {
                argsJSON = str
            } else {
                argsJSON = "{}"
            }
            let body = "TOOL_CALL:" +
                "\(invocation.toolName):\(argsJSON)"
            return BASOrganDraft(
                requestID: request.requestID,
                providerID: descriptor.providerID,
                role: request.role,
                body: body,
                inputTokensEstimated: 10,
                outputTokensEstimated: 20,
                producedAt: Date(),
                traceID: "mock-tool-\(responseIndex)")

        case .error(let reason):
            throw BASFoundationModelsMockError
                .scripted(reason: reason)
        }
    }

    public func currentCapacity() async -> BASOrganCapacity {
        .unlimited
    }

    // MARK: - Test inspection

    /// Snapshot of all `draft(...)` invocations the mock has
    /// served so far。Tests assert against this。
    public func callRecords()
        -> [BASFoundationModelsMockCallRecord]
    {
        callRecordsValue
    }

    /// True iff every scripted response has been consumed。
    public var isExhausted: Bool {
        responseIndex >= scriptedResponses.count
    }

    /// Number of scripted responses remaining。
    public var remainingResponseCount: Int {
        max(0, scriptedResponses.count - responseIndex)
    }

    /// Replace the scripted response queue mid-test (e.g. to
    /// extend a long planning loop without reconstructing
    /// the actor)。
    public func appendResponses(
        _ additional: [BASFoundationModelsMockResponse]
    ) {
        scriptedResponses.append(contentsOf: additional)
    }

    /// Update the simulated per-call latency (e.g. to test
    /// deadline-enforcement paths)。
    public func setSimulatedLatencyMs(_ ms: Int64) {
        precondition(ms >= 0,
            "simulatedLatencyMs must be >= 0")
        simulatedLatencyMsValue = ms
    }

    // MARK: - Tool-call body parsing helpers

    /// Pure helper:given a mock-emitted draft body of the
    /// form `"TOOL_CALL:<toolName>:<argsJSON>"`,parse out
    /// the tool name + arguments。Returns nil for non-tool
    /// bodies。Used by test policy closures (M915 planner
    /// callers) to convert mock responses into
    /// `BASToolInvocation`s。
    public nonisolated static func parseToolCallBody(
        _ body: String
    ) -> (toolName: String, argumentsJSON: String)? {
        let prefix = "TOOL_CALL:"
        guard body.hasPrefix(prefix) else { return nil }
        let rest = body.dropFirst(prefix.count)
        guard let colonIdx = rest.firstIndex(of: ":")
        else { return nil }
        let toolName = String(rest[..<colonIdx])
        let argsJSON = String(
            rest[rest.index(after: colonIdx)...])
        return (toolName: toolName, argumentsJSON: argsJSON)
    }
}
