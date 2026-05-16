// MARK: - BASSSMScanFixtureRegistry
// chapter 六百七十九 / M2094 第二刀 — Swift-side typed
//                                    registry of canonical
//                                    mamba-ssm fixtures
//                                    (analytically-derived,
//                                    per Vendor/mamba-ssm-
//                                    fixtures/README.md)。
//
// ## Why Swift constants instead of bundle resources
//
// Swift Package Manager bundle-resource handling requires
// `.copy(...)` / `.process(...)` declarations in Package
// .swift plus per-target Bundle.module access。 For 6
// small JSON fixtures (total ~3 KB),inlining the fixture
// data as Swift constants is simpler + avoids the build-
// system coupling。 The Vendor/mamba-ssm-fixtures/*.json
// files remain as the documentation source of truth +
// the Swift constants here are the runtime consumers。
//
// ## Anti-drift discipline
//
// Anti-drift PROOF tests at BASSSMScanFixtureRegistry
// AntiDriftTests assert:
//   1. allFixtures.count == 6
//   2. Each fixture's expected_y has the correct shape
//      (B × L × D elements)
//   3. Each fixture's input arrays have correct shapes
//      (x/delta/B/C = B×L×D, A = D)
//   4. Tolerance is 1e-5 across all fixtures (tighter
//      tolerance would require GPU re-validation;looser
//      would weaken the proof)
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed fixture struct (no
//     magic literal arrays scattered through tests)
//   - chapter 二百一一 — single source-of-truth (this
//     registry is THE Swift-side canonical fixture set;
//     JSON files are documentation)
//   - chapter 三百九二 — replay-determinism (analytically
//     derived expected_y values are bit-stable IEEE
//     Float32 — see derivation comments)

import Foundation

/// Single canonical fixture for SSM-scan testing。
public struct BASSSMScanFixture:
    Equatable, Hashable, Sendable, Codable
{
    /// Human-readable fixture name (matches JSON filename
    /// minus prefix/suffix)。
    public let name: String

    /// Short description of what this fixture proves。
    public let description: String

    /// Step-by-step mathematical derivation of the
    /// expected_y values。 Documented inline so a future
    /// reader can re-verify by hand。
    public let derivation: String

    /// (B, L, D) shape of the test case。
    public let shape: BASSSMScanShape

    /// Input x array (length = B × L × D, row-major)。
    public let x: [Float]

    /// Input delta array (length = B × L × D, row-major)。
    public let delta: [Float]

    /// Input A array (length = D)。
    public let A: [Float]

    /// Input B array (length = B × L × D, row-major)。
    public let B: [Float]

    /// Input C array (length = B × L × D, row-major)。
    public let C: [Float]

    /// Expected output y array (length = B × L × D,
    /// row-major)。 Mathematically derived (see
    /// `derivation`)。
    public let expectedY: [Float]

    /// Tolerance for MAE comparison。
    public let tolerance: Float

    public init(
        name: String,
        description: String,
        derivation: String,
        shape: BASSSMScanShape,
        x: [Float],
        delta: [Float],
        A: [Float],
        B: [Float],
        C: [Float],
        expectedY: [Float],
        tolerance: Float
    ) {
        self.name = name
        self.description = description
        self.derivation = derivation
        self.shape = shape
        self.x = x
        self.delta = delta
        self.A = A
        self.B = B
        self.C = C
        self.expectedY = expectedY
        self.tolerance = tolerance
    }
}

/// Registry of all 6 canonical SSM-scan fixtures。 Mirrors
/// Vendor/mamba-ssm-fixtures/*.json content。
public enum BASSSMScanFixtureRegistry {

    public static let fixture01ZeroDeltaZeroOutput:
        BASSSMScanFixture =
    BASSSMScanFixture(
        name: "zero_delta_zero_output",
        description:
            "delta=0 across all positions forces A_bar" +
            "=exp(0)=1 and B_bar=0*B=0, so h stays at " +
            "h_0=0 indefinitely and y=C*0=0",
        derivation:
            "For all t: A_bar=exp(0*A)=1, B_bar=0*B=0, " +
            "h_t=1*h_{t-1}+0*x_t=h_{t-1}=0, y_t=C*0=0",
        shape: BASSSMScanShape(B: 1, L: 4, D: 2),
        x:     [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0],
        delta: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        A:     [-1.0, -0.5],
        B:     [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
        C:     [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
        expectedY:
               [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        tolerance: 1e-5)

    public static let fixture02IdentityUnitStep:
        BASSSMScanFixture =
    BASSSMScanFixture(
        name: "identity_unit_step",
        description:
            "Single-step identity: x=2.5, A=0, delta=1, " +
            "B=C=1 ⇒ y=2.5",
        derivation:
            "A_bar=exp(1*0)=1, B_bar=1*1=1, " +
            "h_0=1*0+1*2.5=2.5, y_0=1*2.5=2.5",
        shape: BASSSMScanShape(B: 1, L: 1, D: 1),
        x:     [2.5],
        delta: [1.0],
        A:     [0.0],
        B:     [1.0],
        C:     [1.0],
        expectedY: [2.5],
        tolerance: 1e-5)

    public static let fixture03TwoStepDecay:
        BASSSMScanFixture =
    BASSSMScanFixture(
        name: "two_step_decay",
        description:
            "Two-step decay: A=-1, delta=1, x=[1,0]. " +
            "Step 0 deposits 1; step 1 decays by exp(-1)",
        derivation:
            "t=0: A_bar=exp(-1), B_bar=1, " +
            "h_0=exp(-1)*0+1*1=1, y_0=1. " +
            "t=1: A_bar=exp(-1), B_bar=1, " +
            "h_1=exp(-1)*1+1*0=exp(-1), y_1=exp(-1)=0.36787944",
        shape: BASSSMScanShape(B: 1, L: 2, D: 1),
        x:     [1.0, 0.0],
        delta: [1.0, 1.0],
        A:     [-1.0],
        B:     [1.0, 1.0],
        C:     [1.0, 1.0],
        expectedY: [1.0, 0.36787944],
        tolerance: 1e-5)

    public static let fixture04ThreeStepAccumulation:
        BASSSMScanFixture =
    BASSSMScanFixture(
        name: "three_step_accumulation",
        description:
            "Three-step accumulation: A=0, delta=1, B=1, " +
            "x=1, C=2 ⇒ y=[2,4,6]",
        derivation:
            "Each step A_bar=1, B_bar=1. h: 0→1→2→3. " +
            "y=2*h: [2, 4, 6]",
        shape: BASSSMScanShape(B: 1, L: 3, D: 1),
        x:     [1.0, 1.0, 1.0],
        delta: [1.0, 1.0, 1.0],
        A:     [0.0],
        B:     [1.0, 1.0, 1.0],
        C:     [2.0, 2.0, 2.0],
        expectedY: [2.0, 4.0, 6.0],
        tolerance: 1e-5)

    public static let fixture05TwoChannelIndependence:
        BASSSMScanFixture =
    BASSSMScanFixture(
        name: "two_channel_independence",
        description:
            "Two channels (D=2) with A=[0,-1] yield " +
            "independent outputs at L=1 where initial " +
            "state h_0=0 masks the A coefficient",
        derivation:
            "Ch 0 (A=0): h_0=1*0+1*1=1, y_0=1. " +
            "Ch 1 (A=-1): h_0=exp(-1)*0+1*1=1, y_0=1. " +
            "Both y values are 1.0 at L=1",
        shape: BASSSMScanShape(B: 1, L: 1, D: 2),
        x:     [1.0, 1.0],
        delta: [1.0, 1.0],
        A:     [0.0, -1.0],
        B:     [1.0, 1.0],
        C:     [1.0, 1.0],
        expectedY: [1.0, 1.0],
        tolerance: 1e-5)

    public static let fixture06TwoBatchIndependence:
        BASSSMScanFixture =
    BASSSMScanFixture(
        name: "two_batch_independence",
        description:
            "Two batches (B=2) with x=[1,7] yield " +
            "independent outputs y=[1,7]. PROOF that " +
            "the kernel doesn't contaminate batches",
        derivation:
            "Batch 0 (x=1): h_0=1*0+1*1=1, y_0=1. " +
            "Batch 1 (x=7): h_0=1*0+1*7=7, y_0=7",
        shape: BASSSMScanShape(B: 2, L: 1, D: 1),
        x:     [1.0, 7.0],
        delta: [1.0, 1.0],
        A:     [0.0],
        B:     [1.0, 1.0],
        C:     [1.0, 1.0],
        expectedY: [1.0, 7.0],
        tolerance: 1e-5)

    /// All 6 canonical fixtures。 Returned in commit-
    /// order matching Vendor/mamba-ssm-fixtures/0[1-6]*.json
    /// numerical prefix。
    public static let allFixtures: [BASSSMScanFixture] = [
        fixture01ZeroDeltaZeroOutput,
        fixture02IdentityUnitStep,
        fixture03TwoStepDecay,
        fixture04ThreeStepAccumulation,
        fixture05TwoChannelIndependence,
        fixture06TwoBatchIndependence
    ]

    public static var fixtureCount: Int {
        return allFixtures.count
    }

    /// Looks up a fixture by name。 Returns nil if no
    /// fixture matches。
    public static func fixture(
        named name: String
    ) -> BASSSMScanFixture? {
        return allFixtures.first { $0.name == name }
    }
}
