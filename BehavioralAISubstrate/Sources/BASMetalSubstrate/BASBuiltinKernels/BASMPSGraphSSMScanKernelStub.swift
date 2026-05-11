// MARK: - BASMPSGraphSSMScanKernelStub
// chapter 四百九十六 / M1361-M1362 — typed ssmScan kernel STUB
//
// HONEST DOCTRINE NOTE — chapter 四百九十六 / Tier 2 entry:
// =============================================================
// Mamba SSM selective scan is NOT natively supported by
// MPSGraph。 Real production implementations require ONE of:
//
//   (a) Custom Metal compute shader implementing parallel
//       prefix-scan (Blelloch-style work-efficient algorithm
//       adapted for selective gating)
//   (b) MLX-swift bridge via vendored mlx-swift-lm package
//   (c) CoreML ML Program with cumsum_v2 + element-wise scan
//
// All three paths are EXTERNAL implementation work outside
// the substrate's pure-Swift scope。 Chapter 496 ships:
//   - This typed STUB conforming to BASMetalKernel
//   - Pure-Swift identity-scan reference (output = input)
//   - HONEST documentation that this is NOT production-ready
//
// Production wiring is scheduled for follow-up Tier 2 phase
// K (chapter 497+) with explicit revert path if all 3
// external paths fail。
//
// The STUB is useful for:
//   - Substrate-level integration testing (registry slot
//     populated;dispatcher routing works)
//   - Protocol conformance proof (BASMetalKernel surface
//     contract held)
//   - Coverage doctrine (chapter 四百九十六 snapshot can
//     pin 7-of-8 native MPSGraph + 1-of-1 stub)
//
// HONEST SCOPE: The stub does NOT implement selective gating。
// It returns identity (output = input)。 Callers that use the
// stub for real ssmScan computation will get incorrect results。
// Use BASMPSGraphSSMScanKernelStub.isProductionReady ==
// false to gate against accidental production use。

import Foundation

/// Sendable + Equatable wrapper for the production-readiness
/// flag。 Exposed as a typed property on the stub so callers
/// can pattern-match against it。
public enum BASSSMScanKernelImplementationStatus:
    String, Codable, Sendable, Equatable, Hashable, CaseIterable
{
    /// Pure-Swift identity-scan reference for testing only。
    /// Returns inputs verbatim。 Not for production use。
    case stubIdentityScan = "stub-identity-scan"

    /// Custom Metal compute shader implementing parallel
    /// prefix-scan with selective gating。 Reserved for
    /// Tier 2 phase K (chapter 497+)。
    case metalShaderProduction = "metal-shader-production"

    /// MLX-swift bridge implementation (vendored
    /// mlx-swift-lm)。 Reserved for Tier 2 phase K fallback。
    case mlxBridgeProduction = "mlx-bridge-production"

    /// CoreML ML Program with cumsum_v2 + element-wise
    /// scan。 Reserved for Tier 2 phase K fallback。
    case coremlMlProgramProduction =
        "coreml-ml-program-production"

    public var isProductionReady: Bool {
        switch self {
        case .stubIdentityScan:
            return false
        case .metalShaderProduction,
             .mlxBridgeProduction,
             .coremlMlProgramProduction:
            return true
        }
    }
}

public actor BASMPSGraphSSMScanKernelStub: BASMetalKernel {

    public nonisolated let key: BASKernelKey =
        BASKernelKey(
            operation: .ssmScan,
            dataType: .float32,
            backingKind: .metalBuffer)

    /// Implementation status flag。 STUB always returns
    /// `.stubIdentityScan`。
    public nonisolated let implementationStatus:
        BASSSMScanKernelImplementationStatus =
        .stubIdentityScan

    public init() {}

    public func evaluate(
        inputs: BASKernelInputs
    ) async throws -> BASKernelOutputs {
        // Validate descriptors against the stub's typed key
        for descriptor in inputs.descriptors {
            guard descriptor.dataType == .float32 else {
                throw BASKernelError.dataTypeMismatch(
                    expected: .float32,
                    actual: descriptor.dataType)
            }
        }
        // Identity scan:emit each input descriptor + payload
        // verbatim as outputs。 Mirrors a no-op scan (state-
        // space matrix = identity,no gating)。 HONEST: this
        // produces incorrect results vs. real ssmScan;use
        // only for substrate integration testing。
        return BASKernelOutputs(
            descriptors: inputs.descriptors,
            payloads: inputs.payloads,
            executionNanos: 0)
    }

    /// Convenience class-level constant exposing the
    /// production-readiness flag。 Callers should gate
    /// against this before wiring the stub into production
    /// dispatch paths。
    public static let isProductionReady: Bool = false
}
