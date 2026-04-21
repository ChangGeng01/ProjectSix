import Foundation
import BASRuntimeCore
#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(Crypto)
import Crypto
#endif

/// Deterministic in-memory adapter. Used by every test in the
/// substrate that needs an organ but doesn't want a real model. The
/// output is a pure SHA-256 function of `providerID + role + preset
/// + instruction + context`, so two tests constructing the same
/// request always receive the same draft.
///
/// This is not a "mock that records calls". It's a *real adapter*
/// whose output is well-defined. Tests can assert on the draft body
/// without mystery.
public actor BASOrganDeterministicAdapter: BASOrganAdapter {
    public nonisolated let descriptor: BASOrganDescriptor

    private let clock: @Sendable () -> Date
    private var callCount: Int = 0

    public init(
        providerID: String = "bas.deterministic.v1",
        providerName: String = "BAS Deterministic Organ",
        maxInputTokens: Int = 8_192,
        maxOutputTokens: Int = 2_048,
        supportedRoles: Set<BASOrganRole> = [.scout, .core],
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.descriptor = BASOrganDescriptor(
            providerID: providerID,
            providerName: providerName,
            supportsStreaming: false,
            maxInputTokens: maxInputTokens,
            maxOutputTokens: maxOutputTokens,
            runsOnDevice: true,
            supportedRoles: supportedRoles)
        self.clock = clock
    }

    public func draft(_ request: BASOrganRequest) async throws -> BASOrganDraft {
        guard descriptor.supportedRoles.contains(request.role) else {
            throw BASOrganError.unsupportedRole(request.role)
        }
        if let deadline = request.deadline, deadline < clock() {
            throw BASOrganError.deadlineExpired
        }
        let inputEstimate = Self.estimateTokens(
            from: [request.instruction] + request.context)
        if inputEstimate > descriptor.maxInputTokens {
            throw BASOrganError.inputTooLong(
                limit: descriptor.maxInputTokens,
                actual: inputEstimate)
        }

        callCount += 1
        let digest = Self.digest(for: request, providerID: descriptor.providerID)
        let body = Self.bodyFor(
            request: request, digest: digest, callIndex: callCount)
        let outputEstimate = Self.estimateTokens(from: [body])

        return BASOrganDraft(
            requestID: request.requestID,
            providerID: descriptor.providerID,
            role: request.role,
            body: body,
            inputTokensEstimated: inputEstimate,
            outputTokensEstimated: outputEstimate,
            producedAt: clock(),
            traceID: digest)
    }

    public func currentCapacity() async -> BASOrganCapacity {
        .unlimited
    }

    public func calls() -> Int { callCount }

    // MARK: - Pure helpers (also useful for adapter tests)

    /// Produce a stable SHA-256 digest for a given request. Public so
    /// tests can pre-compute the expected traceID.
    public static func digest(
        for request: BASOrganRequest,
        providerID: String
    ) -> String {
        let payload = [
            providerID,
            request.role.rawValue,
            request.preset.name,
            String(format: "%.3f", request.preset.temperature),
            request.instruction,
            request.context.joined(separator: "\n")
        ].joined(separator: "|")
        let data = Data(payload.utf8)
        #if canImport(CryptoKit) || canImport(Crypto)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
        #else
        return "unhashed:\(payload.count)"
        #endif
    }

    /// Rough approximation: 1 token ≈ 4 chars. Adapters that care
    /// precisely (Apple FoundationModels, remote LLMs) override
    /// with their real tokenizer.
    public static func estimateTokens(from parts: [String]) -> Int {
        let total = parts.reduce(0) { $0 + $1.count }
        return (total + 3) / 4
    }

    private static func bodyFor(
        request: BASOrganRequest,
        digest: String,
        callIndex: Int
    ) -> String {
        // A short, structured response. Deterministic and obviously
        // synthetic — never mistakable for real model output in logs.
        let roleTag = request.role.rawValue.uppercased()
        let snippet = String(digest.prefix(12))
        return """
        [\(roleTag) · \(request.preset.name) · #\(callIndex)]
        instruction: \(request.instruction)
        trace: \(snippet)
        """
    }
}
