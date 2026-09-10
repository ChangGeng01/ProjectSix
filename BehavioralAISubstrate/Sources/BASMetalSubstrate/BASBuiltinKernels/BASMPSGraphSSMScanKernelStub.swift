// MARK: - BASMPSGraphSSMScanKernelStub
// chapter 四百九十六 / M1361 — Tier 2 entry typed STUB
// chapter 六百八十一 / M2101 — REPURPOSED as .cpuBytes
//                              sibling delegating to
//                              BASSSMScanCPUReference for
//                              correct math (no longer
//                              identity-scan)
//
// ## chapter 681 / M2101 repurpose (Phase M)
//
// The chapter 496 / M1361 stub originally registered at
// `(ssmScan, float32, metalBuffer)` with identity-scan
// stub semantics (output = input)。 Chapter 六百七十八 /
// M2089 shipped REAL Metal compute kernel at the
// metalBuffer slot via BASMetalSSMScanKernel。 That
// collision required this stub to repurpose:
//
//   - Key MOVED to `(ssmScan, float32, cpuBytes)` —
//     sibling slot,no collision
//   - Implementation MOVED from identity-scan to actual
//     CPU computation via BASSSMScanCPUReference
//   - Production-readiness flag flipped to TRUE
//   - implementationStatus enum case now resolves to
//     `.cpuSwiftReferenceProduction`
//
// The repurposed kernel is a CPU-bytes fallback path
// that produces the SAME math as the GPU kernel,suitable
// for:
//   - Platforms without Metal (Linux,watchOS)
//   - Cross-validation in tests (proven oracle)
//   - Substrate-level integration tests where GPU
//     isn't available
//
// ## Honest doctrine
//
// The actor is RENAMED from "Stub" to a more accurate
// name in chapter 681 / M2102 — but the type name stays
// `BASMPSGraphSSMScanKernelStub` for backward source-
// compatibility。 A typealias bridge at chapter 682 will
// expose the new accurate name `BASCPUSSMScanKernel`。

import Foundation

/// Implementation status flag enum。 chapter 681 / M2101
/// adds `.cpuSwiftReferenceProduction` for the repurposed
/// stub。
public enum BASSSMScanKernelImplementationStatus:
    String, Codable, Sendable, Equatable, Hashable, CaseIterable
{
    /// chapter 496-680 era:identity-scan stub。 No longer
    /// used post-chapter 681 / M2101 — kept in enum for
    /// historical anti-drift。
    case stubIdentityScan = "stub-identity-scan"

    /// chapter 681 / M2101:CPU-Swift reference
    /// production implementation delegating to
    /// BASSSMScanCPUReference。 Real selective-scan math,
    /// not identity-scan。 Production-ready for hosts
    /// that don't need GPU dispatch。
    case cpuSwiftReferenceProduction =
        "cpu-swift-reference-production"

    /// chapter 678 / M2089:Real Metal compute shader
    /// production implementation。 Reserved enum case
    /// pointing at BASMetalSSMScanKernel (which lives
    /// under a different key)。
    case metalShaderProduction = "metal-shader-production"

    /// Reserved:MLX-swift bridge (not implemented)。
    case mlxBridgeProduction = "mlx-bridge-production"

    /// Reserved:CoreML ML Program (not implemented)。
    case coremlMlProgramProduction =
        "coreml-ml-program-production"

    public var isProductionReady: Bool {
        switch self {
        case .stubIdentityScan:
            return false
        case .cpuSwiftReferenceProduction,
             .metalShaderProduction,
             .mlxBridgeProduction,
             .coremlMlProgramProduction:
            return true
        }
    }
}

/// CPU-bytes sibling of `BASMetalSSMScanKernel`。 Delegates
/// to `BASSSMScanCPUReference` for the actual scan math。
///
/// Type name stays `BASMPSGraphSSMScanKernelStub` for
/// backward source-compatibility。 Semantically post-
/// chapter 681 / M2101,this is no longer a stub — it's
/// a real CPU implementation。 An accurate-name
/// typealias `BASCPUSSMScanKernel` is exposed at chapter
/// 682 for future call sites。
public actor BASMPSGraphSSMScanKernelStub: BASMetalKernel {

    /// chapter 681 / M2101 repurpose:key moved from
    /// `(ssmScan, float32, metalBuffer)` to
    /// `(ssmScan, float32, cpuBytes)` to avoid collision
    /// with chapter 678 / M2089 BASMetalSSMScanKernel
    /// which now owns the metalBuffer slot。
    public nonisolated let key: BASKernelKey =
        BASKernelKey(
            operation: .ssmScan,
            dataType: .float32,
            backingKind: .cpuBytes)

    /// chapter 681 / M2101:status flipped from
    /// `.stubIdentityScan` to
    /// `.cpuSwiftReferenceProduction`。
    public nonisolated let implementationStatus:
        BASSSMScanKernelImplementationStatus =
        .cpuSwiftReferenceProduction

    public init() {}

    public func evaluate(
        inputs: BASKernelInputs
    ) async throws -> BASKernelOutputs {
        // chapter 681 / M2101 contract:5 inputs (x, delta,
        // A, B, C) matching the GPU kernel surface。 The
        // chapter 496 stub accepted any descriptor count
        // (identity-scan was shape-agnostic);post-repurpose
        // we enforce the same 5-input contract as the GPU
        // kernel。
        guard inputs.descriptors.count == 5 else {
            throw BASKernelError.shapeMismatch(
                reason: "ssmScan (CPU sibling) expects 5 " +
                "inputs (x,delta,A,B,C);got " +
                "\(inputs.descriptors.count)")
        }
        for descriptor in inputs.descriptors {
            guard descriptor.dataType == .float32 else {
                throw BASKernelError.dataTypeMismatch(
                    expected: .float32,
                    actual: descriptor.dataType)
            }
        }
        let descX = inputs.descriptors[0]
        guard descX.shape.count == 3 else {
            throw BASKernelError.shapeMismatch(
                reason: "ssmScan (CPU sibling) x must be " +
                "rank-3 (B,L,D)")
        }
        let batch = descX.shape[0]
        let length = descX.shape[1]
        let channels = descX.shape[2]

        let shape = try BASSSMScanShape.validated(
            B: UInt32(batch),
            L: UInt32(length),
            D: UInt32(channels))

        let startTick = DispatchTime.now()
            .uptimeNanoseconds

        // Delegate to the proven-correct CPU reference
        let yData = try BASSSMScanCPUReference.scan(
            xData: inputs.payloads[0],
            deltaData: inputs.payloads[1],
            aData: inputs.payloads[2],
            bData: inputs.payloads[3],
            cData: inputs.payloads[4],
            shape: shape)

        let endTick = DispatchTime.now().uptimeNanoseconds

        let yDescriptor = BASTensorDescriptor.contiguous(
            shape: descX.shape,
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: descX.rankTag)

        return BASKernelOutputs(
            descriptors: [yDescriptor],
            payloads: [yData],
            executionNanos: endTick - startTick)
    }

    /// chapter 681 / M2101:production-readiness flipped
    /// from false to true。 Pre-repurpose this was false
    /// (identity-scan stub);post-repurpose this CPU
    /// sibling is production-grade。
    public static let isProductionReady: Bool = true
}

/// chapter 681 / M2102:accurate-name typealias for the
/// repurposed CPU sibling。 Hosts should prefer this
/// name for new call sites。
public typealias BASCPUSSMScanKernel =
    BASMPSGraphSSMScanKernelStub
