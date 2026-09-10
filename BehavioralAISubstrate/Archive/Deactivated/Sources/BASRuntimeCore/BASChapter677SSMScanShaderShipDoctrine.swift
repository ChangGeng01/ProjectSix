// MARK: - BASChapter677SSMScanShaderShipDoctrine
// chapter 六百七十七 / M2088 第四刀 — close-out doctrine
//                                    sealing the chapter
//                                    677 SSM scan shader
//                                    ship arc。
//
// ## What chapter 677 shipped
//
// chapter 六百七十七 is Phase M opening chapter under the
// wild-rolling-meerkat REAL HOT-PATH ATTACK plan。 4 cuts
// landed:
//
//   M2085 第一刀 NEW Sources/BASMetalSubstrate/BASBuiltin
//                Kernels/SSMScan.metal — real Metal compute
//                shader implementing Mamba selective-scan
//                recurrence。 125 LOC MSL kernel。 Buffer
//                bindings (0..6),sequential scan per
//                (batch,channel) pair,float32。
//
//   M2086 第二刀 NEW Sources/BASMetalSubstrate/BASBuiltin
//                Kernels/BASSSMScanMetalShaderSource.swift
//                — Swift-side mirror of MSL source as
//                String constant for runtime compilation
//                via MTLDevice.makeLibrary(source:)。 22
//                anti-drift PROOF tests pinning kernel
//                signature + 13 math markers + line count
//                bounds + algorithmic invariants (h_0=0,
//                sequential loop,bounds check,row-major
//                indexing)。
//
//   M2087 第三刀 NEW Sources/BASMetalSubstrate/BASBuiltin
//                Kernels/BASSSMScanShape.swift — typed
//                Swift struct mirroring MSL SSMScanShape
//                with strict 12-byte 3-UInt32 layout。
//                Derived metrics (elementCount,payload
//                ByteCount,aBufferByteCount) + row-major
//                linearIndex helper + throwing validated
//                factory + typed error。 24 anti-drift
//                PROOF tests including 3 layout-invariant
//                pins (size + stride + alignment) + 3
//                field-type pins (must be UInt32 to match
//                MSL `uint`)。
//
//   M2088 第四刀 THIS close-out doctrine sealing the
//                3-artifact chapter。
//
// = 1 MSL file (125 LOC) + 2 Swift source files (~250 LOC)
// + 2 anti-drift test files (~400 LOC) + this doctrine
//
// ## Why these 3 artifacts together
//
// The 3 artifacts form a TYPED VERTICAL STACK for the
// chapter 六百七十八 / M2089 actor wrapper to consume:
//
//   Production code:    .metal file (canonical reference)
//   Runtime compilation: Swift string mirror (for SPM)
//   Type-safe upload:    BASSSMScanShape (12-byte struct)
//
// Without all 3,the chapter 678 actor wrapper would need
// to inline the MSL string + duplicate the shape layout
// reasoning — that's the entropy this chapter prevents。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed shape struct (no magic
//     integer triples scattered through future call
//     sites);typed marker list (no string-magic in
//     anti-drift tests)
//   - chapter 二百一一 — single source-of-truth (MSL
//     string mirror is THE compilation source;.metal
//     file is documentation reference)
//   - chapter 三百九二 — replay-determinism (shape struct
//     Codable;sequential scan reduction is FMA-stable)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (additive — ssmScan was identity-stub-only,new
//     kernel will populate a NEW typed key slot)
//   - 红线 7 — kernel dispatch is observation/computation
//   - ADR-014 OPT-IN — purely additive
//   - ADR-016 advances M2084 → M2088 across chapter 677

import Foundation

public enum BASChapter677SSMScanShaderShipDoctrine {

    public static let chapterTag: String =
        "chapter 六百七十七"
    public static let phase: String = "Phase M"
    public static let phaseStatus: String = "in-progress"

    public static let firstKnifeMNumber: Int = 2085
    public static let secondKnifeMNumber: Int = 2086
    public static let thirdKnifeMNumber: Int = 2087
    public static let fourthKnifeMNumber: Int = 2088

    public static let mNumberFirst: Int = 2085
    public static let mNumberLast: Int = 2088
    public static let knivesCount: Int = 4

    // MARK: - Artifacts shipped

    public static let artifactPaths: [String] = [
        "Sources/BASMetalSubstrate/BASBuiltinKernels/SSMScan.metal",
        "Sources/BASMetalSubstrate/BASBuiltinKernels/BASSSMScanMetalShaderSource.swift",
        "Sources/BASMetalSubstrate/BASBuiltinKernels/BASSSMScanShape.swift"
    ]

    public static var artifactCount: Int {
        return artifactPaths.count
    }

    public static let newTypes: [String] = [
        "BASSSMScanMetalShaderSource",
        "BASSSMScanShape",
        "BASSSMScanShapeError"
    ]

    public static var newTypesCount: Int {
        return newTypes.count
    }

    // MARK: - Test coverage

    public static let antiDriftTestFiles: [String] = [
        "BASSSMScanMetalShaderSourceAntiDriftTests",
        "BASSSMScanShapeAntiDriftTests"
    ]

    public static let chapter677AntiDriftTestCount: Int = 46
    // 22 (M2086) + 24 (M2087) = 46

    // MARK: - MSL kernel facts

    public static let kernelName: String =
        "ssm_scan_float32"

    public static let kernelDataType: String = "float32"

    public static let kernelBufferBindingCount: Int = 7
    // buffer(0)..buffer(6)

    public static let kernelAlgorithm: String =
        "selective-scan-scalar-state-per-channel"

    public static let kernelThreadingStrategy: String =
        "1 thread per (batch, channel) pair, sequential " +
        "scan over time L"

    public static let kernelIsParallelPrefixScan: Bool =
        false // Sequential scan, not parallel prefix-scan

    public static let kernelDiscretization: String =
        "zero-order-hold"

    public static let kernelInitialStateValue: String =
        "h_0 = 0"

    // MARK: - Layout contracts

    public static let shapeStructByteSize: Int = 12
    public static let shapeStructFieldCount: Int = 3
    public static let shapeStructFieldType: String =
        "UInt32"

    // MARK: - Achievement flags

    public static let mslCompilesViaXcodeMetalIfAvailable:
        Bool = true
    public static let swiftMirrorEnablesSpmRuntimeCompile:
        Bool = true
    public static let shapeStructByteEqualToMSL: Bool = true
    public static let antiDriftFullyCovers46Aspects: Bool =
        true

    // MARK: - Next chapter pointer

    public static let nextChapter: String =
        "chapter 六百七十八"
    public static let nextChapterGoal: String =
        "NEW BASMPSGraphSSMScanKernel actor wrapper " +
        "running the M2085 MSL kernel on MTLCommandQueue"
    public static let nextChapterMNumberStart: Int = 2089

    // MARK: - Phase M progress

    public static let phaseMChaptersComplete: Int = 1
    public static let phaseMChaptersTotal: Int = 6
    public static let phaseMCommitsComplete: Int = 4
    public static let phaseMCommitsTotal: Int = 24

    // MARK: - Cross-doctrine refs

    public static let priorPhaseLCompletionRef: String =
        "BASPhaseLCumulativeCompletionDoctrine"
    public static let priorHexa9CatalogRef: String =
        "BASPhaseJKLCompletionHexaCatalogDoctrine"

    public static let planRef: String =
        "wild-rolling-meerkat REAL HOT-PATH ATTACK Phase M"
}
