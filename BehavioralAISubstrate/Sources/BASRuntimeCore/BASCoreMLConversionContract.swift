// MARK: - BASCoreMLConversionContract — chapter 四百 / M918
//
// G11 收尾 substrate-side typed contract for the future
// MLX → CoreML conversion pipeline (P2 G11 from M840 roadmap)。
// Pre-M918 the doctrine standing was:
//   `g11MLXCoreML: external` (no substrate primitive)
// which meant a future conversion CLI would have NO typed
// substrate entry to validate against。Post-M918 the typed
// contract pins:
//   - input shape (MLX weight path + tokenizer config)
//   - output shape (.mlpackage path + metadata)
//   - parity validation (forward-pass comparison test inputs
//     + tolerance)
// so when the external mlx → coreml conversion CLI ships,it
// has a Swift-side typed contract to honor。
//
// ## Why a typed contract for external work
//
// External Python tooling (coremltools, mlx-swift utilities)
// will produce `.mlpackage` files。Those files plug into
// `BASLayerMLHeadRegistry` for substrate inference。Without a
// typed contract:
//   - the converter author guesses the substrate's expected
//     I/O shape
//   - schema drift happens silently between converter and
//     substrate (e.g. converter assumes input dim 64,
//     substrate registers dim 32 head → runtime crash on
//     first inference)
//   - parity validation (the lossiness check) lives only in
//     the converter,never re-verified at runtime
// With a typed contract:
//   - converter authors read the contract,emit matching
//     mlpackages
//   - substrate-side `BASCoreMLConversionContract.validate(...)`
//     can be called BEFORE registering the mlpackage to catch
//     shape mismatches early
//   - parity-test inputs travel ALONGSIDE the model so any
//     consumer can re-verify parity at any time
//
// ## What this ships (M918)
//
//   - `BASCoreMLModelKind` typed enum (chenglu / mamba /
//     userStateReducer / extensible)
//   - `BASCoreMLConversionInput` typed Codable struct
//     specifying the conversion source (MLX weights + config)
//   - `BASCoreMLConversionOutput` typed Codable struct
//     specifying the expected output (mlpackage path +
//     compute units + dimensions)
//   - `BASCoreMLConversionParitySpec` typed Codable struct
//     with parity-test inputs + tolerance threshold
//   - `BASCoreMLConversionRequest` Codable bundle of the
//     three above for one conversion job
//   - `BASCoreMLConversionResult` Codable result with parity
//     metrics (max-abs-error / mean-abs-error / passed?)
//   - `BASCoreMLConversionContract` namespace with
//     `validate(request:)` typed validator
//
// ## What this does NOT ship
//
//   - The Python `coremltools` conversion driver
//   - `.mlpackage` reading/writing (Apple's CoreML SDK does
//     that via `MLModel.compileModel(at:)`)
//   - Numerical parity computation (substrate primitive
//     describes the SHAPE of parity tests;the actual forward
//     pass + diff lives in BASLayerMLHeadRegistry consumers)
//
// ## Doctrine pins held
//
// - 不变量 #1 / #2 / #3 — contract is observation,no
//   permit/verdict mutation
// - 红线 7 hint-only — parity result is HINT,host decides
//   whether to register the converted head
// - chapter 二百一一 single-source-of-truth — ONE typed
//   conversion contract
// - chapter 一百八十五 anti-magic-number — tolerance
//   defaults named typed constants
// - chapter 三百九二 (M892) replay-determinism — same
//   parity inputs produce same parity metrics
// - ADR-014 OPT-IN — contract is queried only when caller
//   invokes;substrate behavior unchanged for hosts that
//   don't run conversions

import Foundation

// MARK: - Model kind

/// Typed enum naming the model kinds the substrate's CoreML
/// pipeline supports。Adding a new model kind requires bumping
/// the contract version + threading the case through the
/// validator + the layer registry。
public enum BASCoreMLModelKind:
    String, Codable, Equatable, Sendable, Hashable,
    CaseIterable
{
    /// Chenglu mesh heads (preflight / multiHead /
    /// permitPredict / lengthHead / latencyHead — already in
    /// production)。
    case chenglu = "chenglu"

    /// Mamba SSM head (G8 — converted via this contract)。
    case mamba = "mamba"

    /// User-state reducer head (M842 — currently pure Swift,
    /// future CoreML port)。
    case userStateReducer = "userStateReducer"

    /// Knowledge-graph extractor head (M857 — currently pure
    /// Swift,future CoreML port for cycle-detection
    /// inference)。
    case knowledgeGraphExtractor = "knowledgeGraphExtractor"
}

// MARK: - Conversion input

/// Typed Codable spec of the conversion source。Pinned so the
/// external Python driver reads exactly this shape。
public struct BASCoreMLConversionInput:
    Codable, Equatable, Sendable, Hashable
{
    /// File path (or URL string) of the MLX weights file。
    /// Python driver opens this with `mlx.load(...)`。
    public let mlxWeightsPath: String

    /// Optional tokenizer config path (relevant for
    /// language-model-class kinds like mamba)。Nil for purely
    /// numeric heads (chenglu / userStateReducer)。
    public let tokenizerConfigPath: String?

    /// Model kind being converted。Drives validator's
    /// per-kind shape checks。
    public let modelKind: BASCoreMLModelKind

    /// Optional source-version tag (e.g. "mamba-130m-v2")。
    public let sourceVersionTag: String?

    public init(
        mlxWeightsPath: String,
        tokenizerConfigPath: String? = nil,
        modelKind: BASCoreMLModelKind,
        sourceVersionTag: String? = nil
    ) {
        self.mlxWeightsPath = mlxWeightsPath
        self.tokenizerConfigPath = tokenizerConfigPath
        self.modelKind = modelKind
        self.sourceVersionTag = sourceVersionTag
    }
}

// MARK: - Conversion output

/// Typed enum of CoreML compute-unit configurations the
/// converted mlpackage targets。Mirrors `MLComputeUnits`。
public enum BASCoreMLComputeUnit:
    String, Codable, Equatable, Sendable, Hashable,
    CaseIterable
{
    case cpuOnly = "cpuOnly"
    case cpuAndGPU = "cpuAndGPU"
    case all = "all"  // CPU + GPU + ANE
    case cpuAndNeuralEngine = "cpuAndNeuralEngine"
}

/// Typed Codable spec of the converted output mlpackage。
public struct BASCoreMLConversionOutput:
    Codable, Equatable, Sendable, Hashable
{
    /// File path where the converter writes the
    /// `.mlpackage`。Convention:
    /// `Models/<kind>/<sourceTag>.mlpackage`。
    public let mlpackagePath: String

    /// Target compute unit configuration the mlpackage was
    /// compiled for。Substrate-side registry uses this when
    /// loading via `MLModelConfiguration.computeUnits`。
    public let targetComputeUnit: BASCoreMLComputeUnit

    /// Input tensor dimensions (per-input,row-major)。Empty
    /// dict for kinds that take string tokens instead of
    /// numeric tensors (e.g. mamba)。
    public let inputDimensions: [String: [Int]]

    /// Output tensor dimensions (per-output,row-major)。
    public let outputDimensions: [String: [Int]]

    /// Numeric precision of the converted weights (typed)。
    public let precision: Precision

    public enum Precision:
        String, Codable, Equatable, Sendable, Hashable,
        CaseIterable
    {
        case float32 = "float32"
        case float16 = "float16"
        case int8 = "int8"
    }

    public init(
        mlpackagePath: String,
        targetComputeUnit: BASCoreMLComputeUnit,
        inputDimensions: [String: [Int]],
        outputDimensions: [String: [Int]],
        precision: Precision
    ) {
        self.mlpackagePath = mlpackagePath
        self.targetComputeUnit = targetComputeUnit
        self.inputDimensions = inputDimensions
        self.outputDimensions = outputDimensions
        self.precision = precision
    }
}

// MARK: - Parity spec

/// Typed Codable spec describing parity-test inputs + the
/// max-tolerated error between MLX and CoreML forward passes
/// on those inputs。Travels alongside the mlpackage so any
/// consumer can re-verify parity at any time。
public struct BASCoreMLConversionParitySpec:
    Codable, Equatable, Sendable, Hashable
{
    /// Path to a JSONL file with parity-test cases。Each line
    /// is one `BASCoreMLParityTestCase`。
    public let testCasePath: String

    /// Number of test cases the JSONL contains (sanity check)。
    public let testCaseCount: Int

    /// Maximum tolerated absolute error per output element。
    /// Default 1e-3 matches typical FP16 quantization parity。
    public let maxAbsErrorTolerance: Double

    /// Maximum tolerated mean absolute error across all
    /// elements。Tighter than max-abs (signals systemic drift
    /// vs. occasional outliers)。Default 1e-4。
    public let meanAbsErrorTolerance: Double

    public init(
        testCasePath: String,
        testCaseCount: Int,
        maxAbsErrorTolerance: Double =
            BASCoreMLConversionContract
                .defaultMaxAbsErrorTolerance,
        meanAbsErrorTolerance: Double =
            BASCoreMLConversionContract
                .defaultMeanAbsErrorTolerance
    ) {
        precondition(testCaseCount > 0,
            "testCaseCount must be > 0")
        precondition(maxAbsErrorTolerance > 0,
            "maxAbsErrorTolerance must be > 0")
        precondition(meanAbsErrorTolerance > 0,
            "meanAbsErrorTolerance must be > 0")
        self.testCasePath = testCasePath
        self.testCaseCount = testCaseCount
        self.maxAbsErrorTolerance = maxAbsErrorTolerance
        self.meanAbsErrorTolerance = meanAbsErrorTolerance
    }
}

/// Typed Codable test case for the parity JSONL。Each line in
/// the parity-test file decodes to one of these。
public struct BASCoreMLParityTestCase:
    Codable, Equatable, Sendable, Hashable
{
    /// Stable identifier。Useful when failures need to be
    /// correlated across runs。
    public let testCaseID: String

    /// Input tensor values (per-input,flat row-major)。
    /// Caller reshapes to inputDimensions on decode。
    public let inputs: [String: [Double]]

    /// Expected output tensor values from the reference (MLX)
    /// forward pass。Substrate-side validator compares this
    /// against the CoreML forward pass on the same inputs。
    public let expectedOutputs: [String: [Double]]

    public init(
        testCaseID: String,
        inputs: [String: [Double]],
        expectedOutputs: [String: [Double]]
    ) {
        self.testCaseID = testCaseID
        self.inputs = inputs
        self.expectedOutputs = expectedOutputs
    }
}

// MARK: - Conversion request

/// Typed Codable bundle of input + output + parity for one
/// conversion job。Caller writes this as JSON,Python driver
/// reads it,produces the mlpackage + parity result。
public struct BASCoreMLConversionRequest:
    Codable, Equatable, Sendable, Hashable
{
    public let contractVersion: String
    public let input: BASCoreMLConversionInput
    public let output: BASCoreMLConversionOutput
    public let parity: BASCoreMLConversionParitySpec
    public let requestedAtMs: Int64

    public init(
        contractVersion: String =
            BASCoreMLConversionContract.contractVersion,
        input: BASCoreMLConversionInput,
        output: BASCoreMLConversionOutput,
        parity: BASCoreMLConversionParitySpec,
        requestedAtMs: Int64
    ) {
        self.contractVersion = contractVersion
        self.input = input
        self.output = output
        self.parity = parity
        self.requestedAtMs = requestedAtMs
    }
}

// MARK: - Conversion result

/// Typed Codable result of one conversion job。Driver writes
/// this when the conversion + parity check finishes。
public struct BASCoreMLConversionResult:
    Codable, Equatable, Sendable, Hashable
{
    public let requestContractVersion: String
    public let modelKind: BASCoreMLModelKind
    public let mlpackagePath: String

    /// True iff conversion succeeded (mlpackage exists)。
    public let conversionSucceeded: Bool

    /// True iff parity check passed (errors within tolerances)。
    /// Only meaningful when `conversionSucceeded == true`。
    public let parityPassed: Bool

    /// Observed max-abs-error across all parity test cases。
    /// Nil when conversion failed (no parity to report)。
    public let observedMaxAbsError: Double?

    /// Observed mean-abs-error across all parity test cases。
    public let observedMeanAbsError: Double?

    /// Wall-clock duration of the conversion job (ms)。
    public let durationMs: Int64

    /// Optional error message when conversion failed。
    public let errorMessage: String?

    public init(
        requestContractVersion: String,
        modelKind: BASCoreMLModelKind,
        mlpackagePath: String,
        conversionSucceeded: Bool,
        parityPassed: Bool,
        observedMaxAbsError: Double?,
        observedMeanAbsError: Double?,
        durationMs: Int64,
        errorMessage: String? = nil
    ) {
        self.requestContractVersion = requestContractVersion
        self.modelKind = modelKind
        self.mlpackagePath = mlpackagePath
        self.conversionSucceeded = conversionSucceeded
        self.parityPassed = parityPassed
        self.observedMaxAbsError = observedMaxAbsError
        self.observedMeanAbsError = observedMeanAbsError
        self.durationMs = durationMs
        self.errorMessage = errorMessage
    }
}

// MARK: - Validator

/// Typed result of validating a `BASCoreMLConversionRequest`
/// before sending it to the converter。
public enum BASCoreMLConversionValidationResult:
    Sendable, Equatable
{
    case valid
    case invalid(reason: BASCoreMLConversionValidationFailure)
}

public enum BASCoreMLConversionValidationFailure:
    String, Sendable, Equatable, Hashable, CaseIterable, Codable
{
    case mismatchedContractVersion = "mismatchedContractVersion"
    case emptyMLXWeightsPath = "emptyMLXWeightsPath"
    case emptyMLPackagePath = "emptyMLPackagePath"
    case emptyParityTestCasePath = "emptyParityTestCasePath"
    case nonPositiveTestCaseCount = "nonPositiveTestCaseCount"
    case missingTokenizerForLMKind = "missingTokenizerForLMKind"
    case nonPositiveDimension = "nonPositiveDimension"
}

// MARK: - Contract namespace

/// Substrate-side typed namespace for the CoreML conversion
/// contract。Pure functions over Codable values。
public enum BASCoreMLConversionContract {

    /// Contract version pin。Bumped when ANY field changes in
    /// `BASCoreMLConversionInput` / `BASCoreMLConversionOutput`
    /// / `BASCoreMLConversionParitySpec` / Result。Driver
    /// asserts this on load。
    public static let contractVersion: String = "M918.1.0.0"

    /// chapter 一百八十五 anti-magic-number — typed defaults
    public static let defaultMaxAbsErrorTolerance: Double =
        1e-3
    public static let defaultMeanAbsErrorTolerance: Double =
        1e-4

    /// Validate a conversion request before sending to the
    /// driver。Pure。
    public static func validate(
        request: BASCoreMLConversionRequest
    ) -> BASCoreMLConversionValidationResult {
        if request.contractVersion != contractVersion {
            return .invalid(
                reason: .mismatchedContractVersion)
        }
        if request.input.mlxWeightsPath.isEmpty {
            return .invalid(
                reason: .emptyMLXWeightsPath)
        }
        if request.output.mlpackagePath.isEmpty {
            return .invalid(
                reason: .emptyMLPackagePath)
        }
        if request.parity.testCasePath.isEmpty {
            return .invalid(
                reason: .emptyParityTestCasePath)
        }
        if request.parity.testCaseCount <= 0 {
            return .invalid(
                reason: .nonPositiveTestCaseCount)
        }
        // LM-class kinds (mamba) need tokenizer config
        if request.input.modelKind == .mamba
            && request.input.tokenizerConfigPath == nil
        {
            return .invalid(
                reason: .missingTokenizerForLMKind)
        }
        // All input/output dims must be positive
        let allDimGroups: [[String: [Int]]] = [
            request.output.inputDimensions,
            request.output.outputDimensions
        ]
        for group in allDimGroups {
            for (_, dims) in group {
                if dims.contains(where: { $0 <= 0 }) {
                    return .invalid(
                        reason: .nonPositiveDimension)
                }
            }
        }
        return .valid
    }

    /// Compute a typed conversion result given observed
    /// errors。Pure helper for drivers to format their result。
    public static func computeResult(
        request: BASCoreMLConversionRequest,
        observedMaxAbsError: Double,
        observedMeanAbsError: Double,
        durationMs: Int64
    ) -> BASCoreMLConversionResult {
        let parityPassed =
            observedMaxAbsError <=
                request.parity.maxAbsErrorTolerance
            && observedMeanAbsError <=
                request.parity.meanAbsErrorTolerance
        return BASCoreMLConversionResult(
            requestContractVersion:
                request.contractVersion,
            modelKind: request.input.modelKind,
            mlpackagePath: request.output.mlpackagePath,
            conversionSucceeded: true,
            parityPassed: parityPassed,
            observedMaxAbsError: observedMaxAbsError,
            observedMeanAbsError: observedMeanAbsError,
            durationMs: durationMs)
    }
}
