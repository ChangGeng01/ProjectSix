// MARK: - BASCoreMLOperatorWhitelist — chapter 四百 / M923
//
// G11 收尾 step 2:typed whitelist of CoreML operators that
// run efficiently on Apple Neural Engine (ANE)。Pre-M923 the
// M918 conversion contract pinned input/output shapes but
// NOT which operators the converted model is allowed to use。
// Post-M923 the conversion driver checks the source model's
// op set against this whitelist BEFORE conversion + reports
// any unsupported ops in the typed result。
//
// ## Why ANE compatibility matters for the substrate
//
// On iPhone the cognitive OS observer runs alongside the
// chenglu mesh + LLM inference。ANE residency is a real
// resource — if a converted Mamba head silently falls back
// to GPU because of one unsupported op,it competes with the
// chenglu mesh for GPU bandwidth and the 10h thermal envelope
// gets MORE crowded,not less。
//
// The whitelist is not exhaustive (it can't be — Apple's
// internal ANE op compatibility matrix isn't public)。But it
// pins the COMMON op subset every CoreML developer relies on
// + flags Mamba-specific risks (selective scan, cumulative
// sum-product reductions)。The driver uses it as a CONSERVATIVE
// pre-flight filter:if the model uses ONLY whitelisted ops,
// the driver proceeds;otherwise it surfaces the unsupported
// ops in the typed result so the engineer decides how to
// rewrite the model (or accept GPU fallback)。
//
// ## What this ships
//
//   - `BASCoreMLOperatorCategory` typed enum naming op
//     families (linearAlgebra / convolution / activation /
//     normalization / reduction / scan / elementwise)
//   - `BASCoreMLOperator` typed Codable struct: name +
//     category + ANE-safety flag + Mamba-relevance flag
//   - `BASCoreMLOperatorWhitelist.aneSafeOperators` static
//     list of ANE-safe operators (canonical CoreML names)
//   - `BASCoreMLOperatorWhitelist.knownMambaRiskyOperators`
//     static list of operators known to be risky for Mamba
//     conversions (selective scan, etc.)
//   - `BASCoreMLOperatorComplianceCheck` typed Codable struct:
//     given a list of operators in a candidate model,
//     reports compliance + categorized risks
//
// ## Doctrine pins held
//
// - chapter 二百一一 single-source-of-truth — ONE typed op
//   whitelist, conversion driver consumes it
// - chapter 一百八十五 anti-magic-number — op names pinned
//   as static constants
// - 红线 7 hint-only — compliance check is a HINT, driver /
//   engineer decides whether to proceed with non-compliant ops
// - ADR-014 OPT-IN — driver opts into checking;substrate
//   doesn't auto-validate

import Foundation

// MARK: - Operator category

public enum BASCoreMLOperatorCategory:
    String, Codable, Equatable, Sendable, Hashable, CaseIterable
{
    case linearAlgebra = "linearAlgebra"
    case convolution = "convolution"
    case activation = "activation"
    case normalization = "normalization"
    case reduction = "reduction"
    /// Cumulative scans / state-space updates。Mamba's
    /// selective-scan kernel falls here。Often NOT ANE-safe
    /// without custom kernels。
    case scan = "scan"
    case elementwise = "elementwise"
    case shape = "shape"
    case other = "other"
}

// MARK: - Operator descriptor

public struct BASCoreMLOperator:
    Codable, Equatable, Sendable, Hashable
{
    /// Canonical CoreML op name as it appears in
    /// `coremltools.proto`。
    public let name: String
    public let category: BASCoreMLOperatorCategory
    /// True if this operator runs efficiently on ANE per
    /// our (conservative) compatibility matrix。
    public let aneSafe: Bool
    /// True if this operator is critical for Mamba
    /// architectures (selective scan, etc.) — flag for
    /// special-case treatment in the converter。
    public let mambaRelevant: Bool

    public init(
        name: String,
        category: BASCoreMLOperatorCategory,
        aneSafe: Bool,
        mambaRelevant: Bool = false
    ) {
        self.name = name
        self.category = category
        self.aneSafe = aneSafe
        self.mambaRelevant = mambaRelevant
    }
}

// MARK: - Compliance check result

public struct BASCoreMLOperatorComplianceCheck:
    Codable, Equatable, Sendable, Hashable
{
    /// Operators present in the candidate model (or empty
    /// if the driver couldn't enumerate them)。
    public let operatorsUsed: [String]

    /// Subset of `operatorsUsed` that are NOT in the
    /// whitelist。Empty = compliant。
    public let unsupportedOperators: [String]

    /// Subset of `operatorsUsed` that the whitelist flags as
    /// Mamba-risky (selective scan, cumulative sum-product)。
    public let mambaRiskyOperators: [String]

    /// True iff every operator in `operatorsUsed` is in the
    /// whitelist AND none are flagged Mamba-risky。
    public var isFullyCompliant: Bool {
        unsupportedOperators.isEmpty
            && mambaRiskyOperators.isEmpty
    }

    public init(
        operatorsUsed: [String],
        unsupportedOperators: [String],
        mambaRiskyOperators: [String]
    ) {
        self.operatorsUsed = operatorsUsed
        self.unsupportedOperators = unsupportedOperators
        self.mambaRiskyOperators = mambaRiskyOperators
    }
}

// MARK: - Whitelist namespace

public enum BASCoreMLOperatorWhitelist {

    /// Whitelist version。Bumped whenever the canonical op
    /// list changes (new ANE-safe ops added,or one
    /// reclassified as risky based on new measurements)。
    public static let whitelistVersion: String = "M923.1.0.0"

    /// Conservative ANE-safe op set。Curated from publicly-
    /// documented CoreML op support + iPhone benchmarks。Not
    /// exhaustive — there ARE more ANE-safe ops,but listed
    /// ones are the safe minimum。
    public static let aneSafeOperators: [BASCoreMLOperator] = [
        // Linear algebra
        BASCoreMLOperator(name: "MatMul",
            category: .linearAlgebra, aneSafe: true,
            mambaRelevant: true),
        BASCoreMLOperator(name: "InnerProduct",
            category: .linearAlgebra, aneSafe: true),
        BASCoreMLOperator(name: "Add",
            category: .elementwise, aneSafe: true),
        BASCoreMLOperator(name: "Multiply",
            category: .elementwise, aneSafe: true),
        BASCoreMLOperator(name: "Subtract",
            category: .elementwise, aneSafe: true),
        BASCoreMLOperator(name: "Divide",
            category: .elementwise, aneSafe: true),

        // Convolution
        BASCoreMLOperator(name: "Convolution",
            category: .convolution, aneSafe: true,
            mambaRelevant: true),  // Mamba uses 1D conv
        BASCoreMLOperator(name: "DepthwiseConvolution",
            category: .convolution, aneSafe: true),

        // Activations
        BASCoreMLOperator(name: "ReLU",
            category: .activation, aneSafe: true),
        BASCoreMLOperator(name: "GELU",
            category: .activation, aneSafe: true,
            mambaRelevant: true),  // Mamba paper uses GELU
        BASCoreMLOperator(name: "SiLU",
            category: .activation, aneSafe: true,
            mambaRelevant: true),  // Mamba paper uses SiLU
        BASCoreMLOperator(name: "Sigmoid",
            category: .activation, aneSafe: true),
        BASCoreMLOperator(name: "Tanh",
            category: .activation, aneSafe: true),
        BASCoreMLOperator(name: "Softmax",
            category: .activation, aneSafe: true),

        // Normalization
        BASCoreMLOperator(name: "LayerNormalization",
            category: .normalization, aneSafe: true,
            mambaRelevant: true),
        BASCoreMLOperator(name: "RMSNorm",
            category: .normalization, aneSafe: true,
            mambaRelevant: true),  // Mamba uses RMSNorm
        BASCoreMLOperator(name: "BatchNormalization",
            category: .normalization, aneSafe: true),

        // Reductions
        BASCoreMLOperator(name: "ReduceSum",
            category: .reduction, aneSafe: true),
        BASCoreMLOperator(name: "ReduceMean",
            category: .reduction, aneSafe: true),
        BASCoreMLOperator(name: "ReduceMax",
            category: .reduction, aneSafe: true),

        // Shape ops
        BASCoreMLOperator(name: "Reshape",
            category: .shape, aneSafe: true),
        BASCoreMLOperator(name: "Transpose",
            category: .shape, aneSafe: true),
        BASCoreMLOperator(name: "Concat",
            category: .shape, aneSafe: true),
        BASCoreMLOperator(name: "Split",
            category: .shape, aneSafe: true),
        BASCoreMLOperator(name: "Slice",
            category: .shape, aneSafe: true),
        BASCoreMLOperator(name: "Gather",
            category: .shape, aneSafe: true),
        BASCoreMLOperator(name: "Embedding",
            category: .shape, aneSafe: true,
            mambaRelevant: true),
    ]

    /// Operators that are known to be RISKY for Mamba
    /// conversions on ANE。Driver flags these specifically
    /// so engineers can choose to rewrite the model OR
    /// accept GPU fallback。
    public static let knownMambaRiskyOperators:
        [BASCoreMLOperator] =
    [
        BASCoreMLOperator(name: "CumulativeSum",
            category: .scan, aneSafe: false,
            mambaRelevant: true),  // selective-scan kernel
        BASCoreMLOperator(name: "CumulativeProduct",
            category: .scan, aneSafe: false,
            mambaRelevant: true),  // selective-scan kernel
        BASCoreMLOperator(name: "Scan",
            category: .scan, aneSafe: false,
            mambaRelevant: true),
        BASCoreMLOperator(name: "ParallelScan",
            category: .scan, aneSafe: false,
            mambaRelevant: true),  // Mamba's hardware-aware kernel
        // Dynamic shapes are not ANE-safe in general
        BASCoreMLOperator(name: "DynamicReshape",
            category: .shape, aneSafe: false),
        BASCoreMLOperator(name: "TopK",
            category: .reduction, aneSafe: false),
    ]

    /// All known operator descriptors (whitelist + risky)。
    /// Conversion driver enumerates this for full coverage。
    public static var allKnownOperators:
        [BASCoreMLOperator]
    {
        aneSafeOperators + knownMambaRiskyOperators
    }

    /// Set of canonical names in the ANE-safe list。Cheap
    /// O(1) lookups for compliance checking。
    public static let aneSafeOperatorNames: Set<String> = {
        Set(aneSafeOperators.map(\.name))
    }()

    /// Set of canonical names known Mamba-risky。
    public static let mambaRiskyOperatorNames: Set<String> = {
        Set(knownMambaRiskyOperators.map(\.name))
    }()

    /// Run a compliance check against a candidate model's
    /// operator usage list。Pure。
    public static func check(
        operatorsUsed: [String]
    ) -> BASCoreMLOperatorComplianceCheck {
        let used = Array(Set(operatorsUsed))  // dedup
        let unsupported = used.filter {
            !aneSafeOperatorNames.contains($0)
                && !mambaRiskyOperatorNames.contains($0)
        }
        let risky = used.filter {
            mambaRiskyOperatorNames.contains($0)
        }
        return BASCoreMLOperatorComplianceCheck(
            operatorsUsed: used.sorted(),
            unsupportedOperators: unsupported.sorted(),
            mambaRiskyOperators: risky.sorted())
    }
}
