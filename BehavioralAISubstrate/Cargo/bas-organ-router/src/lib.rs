// SPDX:internal
//
// bas-organ-router — chapter 七百四十七 第一刀 / M2406
//
// LAYER-MIGRATION ARC L2 Neural Organ adapter routing port。
// Pure-function policy:given tensor shape + workload size +
// power hint,select which kernel impl serves the dispatch。
//
// Per user directive 2026-05-20 L2 / L9 sub-directive:
//
//   「Metal/C++ 管 模型 内核,Rust 管 routing/adapter policy。」
//
// The policy lives in Rust;the kernels themselves stay in
// Metal (model math) + Swift (orchestration)。 This crate
// is the BRAIN that decides which kernel runs。
//
// Mirrors chapter 七百七 attention auto-router policy extended
// to a general L2 kernel-selection surface。

#![forbid(unsafe_op_in_unsafe_fn)]

pub const ABI_VERSION: i32 = 1;

#[no_mangle]
pub extern "C" fn bas_organ_router_abi_version() -> i32 {
    ABI_VERSION
}

// MARK: - Kernel backend enum

/// 4 backend kinds the L2 router may select。 Numerically
/// encoded for C ABI:
///   0 = CpuReference
///   1 = MetalKernel
///   2 = MpsGraph
///   3 = RustSimd
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
pub enum KernelBackend {
    CpuReference,
    MetalKernel,
    MpsGraph,
    RustSimd,
}

impl KernelBackend {
    pub fn to_i32(self) -> i32 {
        match self {
            KernelBackend::CpuReference => 0,
            KernelBackend::MetalKernel => 1,
            KernelBackend::MpsGraph => 2,
            KernelBackend::RustSimd => 3,
        }
    }
}

/// 6 kernel families the L2 router can dispatch。 Matches
/// the substrate's chapter 七百七-七百十一 auto-router
/// family taxonomy。
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
pub enum KernelFamily {
    Attention,
    MatMul,
    LayerNorm,
    RmsNorm,
    Softmax,
    Activation,
}

/// Power-budget hint for the host's current state。 Lower
/// budgets force CPU reference;higher budgets allow Metal。
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
pub enum PowerBudget {
    Constrained,  // host on battery / thermal pressure
    Normal,
    Generous,     // host on AC + cool
}

// MARK: - Routing decision

/// Decide which backend serves a kernel dispatch based on
/// (family, shape_size, power_budget)。
///
/// Decision rules (chapter 七百七 pattern + L2 extension):
///   - Constrained power → CpuReference for ALL families
///     (deterministic + low power)
///   - Tiny workload (size < 256) → CpuReference (FFI cost
///     dominates Metal/MPS setup)
///   - Attention with size ≥ 1024 → MetalKernel
///     (FlashAttention tiled kernel wins big at scale)
///   - MatMul mid-sized (256-1024) → MpsGraph
///     (Apple-tuned for typical shapes)
///   - MatMul large (≥ 1024) → MetalKernel
///   - LayerNorm/RmsNorm/Softmax → RustSimd (Welford pass +
///     SIMD beats both Metal launch overhead and CPU)
///   - Activation (any size) → RustSimd
///     (Cargo/bas-retrieval-ranker simd activation primitive)
pub fn select_backend(
    family: KernelFamily,
    shape_size: i32,
    budget: PowerBudget,
) -> KernelBackend {
    if budget == PowerBudget::Constrained {
        return KernelBackend::CpuReference;
    }
    if shape_size < 256 {
        return KernelBackend::CpuReference;
    }
    match family {
        KernelFamily::Attention => {
            if shape_size >= 1024 {
                KernelBackend::MetalKernel
            } else {
                KernelBackend::MpsGraph
            }
        }
        KernelFamily::MatMul => {
            if shape_size >= 1024 {
                KernelBackend::MetalKernel
            } else {
                KernelBackend::MpsGraph
            }
        }
        KernelFamily::LayerNorm
        | KernelFamily::RmsNorm
        | KernelFamily::Softmax => {
            KernelBackend::RustSimd
        }
        KernelFamily::Activation => {
            KernelBackend::RustSimd
        }
    }
}

// MARK: - C ABI

/// Select backend via C ABI。 Inputs are numeric:
///   family:  0=Attention 1=MatMul 2=LayerNorm 3=RmsNorm
///            4=Softmax 5=Activation
///   shape_size: i32
///   budget:  0=Constrained 1=Normal 2=Generous
/// Returns:backend i32 (0-3) or -1 on bad input
#[no_mangle]
pub extern "C" fn bas_organ_router_select(
    family_raw: i32,
    shape_size: i32,
    budget_raw: i32,
) -> i32 {
    let family = match family_raw {
        0 => KernelFamily::Attention,
        1 => KernelFamily::MatMul,
        2 => KernelFamily::LayerNorm,
        3 => KernelFamily::RmsNorm,
        4 => KernelFamily::Softmax,
        5 => KernelFamily::Activation,
        _ => return -1,
    };
    let budget = match budget_raw {
        0 => PowerBudget::Constrained,
        1 => PowerBudget::Normal,
        2 => PowerBudget::Generous,
        _ => return -1,
    };
    select_backend(family, shape_size, budget).to_i32()
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn constrained_power_always_cpu() {
        for family in [
            KernelFamily::Attention, KernelFamily::MatMul,
            KernelFamily::LayerNorm, KernelFamily::RmsNorm,
            KernelFamily::Softmax, KernelFamily::Activation,
        ] {
            assert_eq!(
                select_backend(family, 10000,
                    PowerBudget::Constrained),
                KernelBackend::CpuReference);
        }
    }

    #[test]
    fn tiny_size_always_cpu_under_normal() {
        for family in [
            KernelFamily::Attention, KernelFamily::MatMul,
        ] {
            assert_eq!(
                select_backend(
                    family, 128, PowerBudget::Normal),
                KernelBackend::CpuReference);
        }
    }

    #[test]
    fn large_attention_uses_metal() {
        assert_eq!(
            select_backend(
                KernelFamily::Attention,
                2048, PowerBudget::Normal),
            KernelBackend::MetalKernel);
    }

    #[test]
    fn mid_attention_uses_mpsgraph() {
        assert_eq!(
            select_backend(
                KernelFamily::Attention,
                512, PowerBudget::Normal),
            KernelBackend::MpsGraph);
    }

    #[test]
    fn large_matmul_uses_metal() {
        assert_eq!(
            select_backend(
                KernelFamily::MatMul,
                1024, PowerBudget::Normal),
            KernelBackend::MetalKernel);
    }

    #[test]
    fn norms_always_rust_simd_mid_or_large() {
        for family in [
            KernelFamily::LayerNorm,
            KernelFamily::RmsNorm,
            KernelFamily::Softmax,
        ] {
            assert_eq!(
                select_backend(
                    family, 512, PowerBudget::Normal),
                KernelBackend::RustSimd);
            assert_eq!(
                select_backend(
                    family, 2048, PowerBudget::Generous),
                KernelBackend::RustSimd);
        }
    }

    #[test]
    fn activation_always_rust_simd() {
        for size in [256, 1024, 8192] {
            assert_eq!(
                select_backend(
                    KernelFamily::Activation,
                    size, PowerBudget::Normal),
                KernelBackend::RustSimd);
        }
    }

    #[test]
    fn determinism_repeat_calls() {
        for _ in 0..10 {
            assert_eq!(
                select_backend(
                    KernelFamily::Attention,
                    1024, PowerBudget::Normal),
                KernelBackend::MetalKernel);
        }
    }

    // MARK: - C ABI

    #[test]
    fn c_abi_attention_large_returns_metal() {
        let rc = bas_organ_router_select(0, 2048, 1);
        assert_eq!(rc, 1);  // MetalKernel
    }

    #[test]
    fn c_abi_constrained_returns_cpu() {
        let rc = bas_organ_router_select(0, 2048, 0);
        assert_eq!(rc, 0);  // CpuReference
    }

    #[test]
    fn c_abi_bad_family_returns_fault() {
        let rc = bas_organ_router_select(99, 1024, 1);
        assert_eq!(rc, -1);
    }

    #[test]
    fn c_abi_bad_budget_returns_fault() {
        let rc = bas_organ_router_select(0, 1024, 99);
        assert_eq!(rc, -1);
    }

    #[test]
    fn backend_encoding() {
        assert_eq!(
            KernelBackend::CpuReference.to_i32(), 0);
        assert_eq!(
            KernelBackend::MetalKernel.to_i32(), 1);
        assert_eq!(
            KernelBackend::MpsGraph.to_i32(), 2);
        assert_eq!(
            KernelBackend::RustSimd.to_i32(), 3);
    }
}
