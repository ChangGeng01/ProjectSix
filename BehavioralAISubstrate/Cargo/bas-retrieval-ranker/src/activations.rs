// SPDX:internal
//
// activations.rs — chapter 七百十一 第一刀 / M2226
//
// Pointwise activations on the substrate's CPU path:
//
//   - gelu_exact(x, out)             : 0.5 * x * (1 + erf(x/√2))
//   - gelu_tanh_approx(x, out)       : 0.5 * x * (1 + tanh(√(2/π)
//                                       * (x + 0.044715 * x³)))
//   - silu(x, out)                   : x * σ(x) = x / (1 + e⁻ˣ)
//
// Each has a 4-wide SIMD-friendly variant (`*_simd`) that LLVM
// auto-vectorizes to NEON (aarch64) + AVX2 (x86_64)。
//
// ## erf approximation
//
// Rust std does not yet expose f32::erf as stable (as of 1.84,
// it's gated behind `float_erf`)。 To avoid a libm dependency
// we use Abramowitz & Stegun 7.1.26 polynomial with max abs
// error ~1.5e-7 over all reals — well below the chapter 392
// 1e-4 IEEE Float32 replay-determinism tolerance。
//
// ## Reference vectors (torch.nn.functional)
//
//   F.gelu(0.0)       = 0.0
//   F.gelu(1.0)       ≈ 0.8413447
//   F.gelu(2.0)       ≈ 1.9544997
//   F.gelu(-1.0)      ≈ -0.15865529
//
//   F.gelu(1.0, approximate="tanh") ≈ 0.84119
//   F.gelu(2.0, approximate="tanh") ≈ 1.95459
//
//   F.silu(0.0)       = 0.0
//   F.silu(1.0)       ≈ 0.7310586
//   F.silu(2.0)       ≈ 1.7615942
//   F.silu(-1.0)      ≈ -0.2689414

const SQRT_2_OVER_PI: f32 = 0.7978845608028654; // √(2/π)
const GELU_CUBIC_COEFF: f32 = 0.044715;
const INV_SQRT_2: f32 = 0.70710678118654752; // 1/√2

/// Abramowitz & Stegun 7.1.26 erf approximation。 Max abs error
/// ~1.5e-7 over all reals。 Self-contained — no libm。
#[inline]
fn erf_approx(x: f32) -> f32 {
    let p: f32 = 0.3275911;
    let a1: f32 = 0.254829592;
    let a2: f32 = -0.284496736;
    let a3: f32 = 1.421413741;
    let a4: f32 = -1.453152027;
    let a5: f32 = 1.061405429;
    let sign = if x < 0.0 { -1.0 } else { 1.0 };
    let ax = x.abs();
    let t = 1.0 / (1.0 + p * ax);
    let t2 = t * t;
    let t3 = t2 * t;
    let t4 = t3 * t;
    let t5 = t4 * t;
    let poly = a1 * t + a2 * t2 + a3 * t3
        + a4 * t4 + a5 * t5;
    let y = 1.0 - poly * (-(ax * ax)).exp();
    sign * y
}

// MARK: - GELU (exact via erf)

/// Exact GELU: y = 0.5 * x * (1 + erf(x/√2))。 Matches
/// torch.nn.functional.gelu (no approximate kwarg)。
pub fn gelu_exact(x: &[f32], out: &mut [f32]) {
    debug_assert_eq!(x.len(), out.len());
    for (i, &v) in x.iter().enumerate() {
        out[i] = 0.5 * v * (1.0 + erf_approx(v * INV_SQRT_2));
    }
}

/// SIMD-friendly variant — 4-wide unrolled loop。 Same numerics
/// as gelu_exact but the loop body lets LLVM emit NEON FMA
/// instructions on aarch64。
pub fn gelu_exact_simd(x: &[f32], out: &mut [f32]) {
    debug_assert_eq!(x.len(), out.len());
    let n = x.len();
    let chunks = n / 4;
    for c in 0..chunks {
        let base = c * 4;
        let v0 = x[base];
        let v1 = x[base + 1];
        let v2 = x[base + 2];
        let v3 = x[base + 3];
        let y0 = 0.5 * v0
            * (1.0 + erf_approx(v0 * INV_SQRT_2));
        let y1 = 0.5 * v1
            * (1.0 + erf_approx(v1 * INV_SQRT_2));
        let y2 = 0.5 * v2
            * (1.0 + erf_approx(v2 * INV_SQRT_2));
        let y3 = 0.5 * v3
            * (1.0 + erf_approx(v3 * INV_SQRT_2));
        out[base] = y0;
        out[base + 1] = y1;
        out[base + 2] = y2;
        out[base + 3] = y3;
    }
    // Tail
    for i in (chunks * 4)..n {
        let v = x[i];
        out[i] = 0.5 * v
            * (1.0 + erf_approx(v * INV_SQRT_2));
    }
}

// MARK: - GELU (tanh approximation)

/// GELU tanh-approx: y = 0.5*x*(1 + tanh(√(2/π)*(x + 0.044715*x³)))。
/// Matches torch.nn.functional.gelu(approximate="tanh")。 Slightly
/// faster than gelu_exact because it avoids erf。
pub fn gelu_tanh_approx(x: &[f32], out: &mut [f32]) {
    debug_assert_eq!(x.len(), out.len());
    for (i, &v) in x.iter().enumerate() {
        let cube = v * v * v;
        let inner = SQRT_2_OVER_PI
            * (v + GELU_CUBIC_COEFF * cube);
        out[i] = 0.5 * v * (1.0 + inner.tanh());
    }
}

/// SIMD-friendly tanh-approx GELU。
pub fn gelu_tanh_approx_simd(x: &[f32], out: &mut [f32]) {
    debug_assert_eq!(x.len(), out.len());
    let n = x.len();
    let chunks = n / 4;
    for c in 0..chunks {
        let base = c * 4;
        let v0 = x[base];
        let v1 = x[base + 1];
        let v2 = x[base + 2];
        let v3 = x[base + 3];
        let c0 = v0 * v0 * v0;
        let c1 = v1 * v1 * v1;
        let c2 = v2 * v2 * v2;
        let c3 = v3 * v3 * v3;
        let i0 = SQRT_2_OVER_PI
            * (v0 + GELU_CUBIC_COEFF * c0);
        let i1 = SQRT_2_OVER_PI
            * (v1 + GELU_CUBIC_COEFF * c1);
        let i2 = SQRT_2_OVER_PI
            * (v2 + GELU_CUBIC_COEFF * c2);
        let i3 = SQRT_2_OVER_PI
            * (v3 + GELU_CUBIC_COEFF * c3);
        out[base] = 0.5 * v0 * (1.0 + i0.tanh());
        out[base + 1] = 0.5 * v1 * (1.0 + i1.tanh());
        out[base + 2] = 0.5 * v2 * (1.0 + i2.tanh());
        out[base + 3] = 0.5 * v3 * (1.0 + i3.tanh());
    }
    for i in (chunks * 4)..n {
        let v = x[i];
        let cube = v * v * v;
        let inner = SQRT_2_OVER_PI
            * (v + GELU_CUBIC_COEFF * cube);
        out[i] = 0.5 * v * (1.0 + inner.tanh());
    }
}

// MARK: - SiLU (= Swish, beta=1)

/// SiLU: y = x * σ(x) = x / (1 + e⁻ˣ)。 Matches
/// torch.nn.functional.silu。
pub fn silu(x: &[f32], out: &mut [f32]) {
    debug_assert_eq!(x.len(), out.len());
    for (i, &v) in x.iter().enumerate() {
        let sig = 1.0 / (1.0 + (-v).exp());
        out[i] = v * sig;
    }
}

/// SIMD-friendly SiLU。
pub fn silu_simd(x: &[f32], out: &mut [f32]) {
    debug_assert_eq!(x.len(), out.len());
    let n = x.len();
    let chunks = n / 4;
    for c in 0..chunks {
        let base = c * 4;
        let v0 = x[base];
        let v1 = x[base + 1];
        let v2 = x[base + 2];
        let v3 = x[base + 3];
        let s0 = 1.0 / (1.0 + (-v0).exp());
        let s1 = 1.0 / (1.0 + (-v1).exp());
        let s2 = 1.0 / (1.0 + (-v2).exp());
        let s3 = 1.0 / (1.0 + (-v3).exp());
        out[base] = v0 * s0;
        out[base + 1] = v1 * s1;
        out[base + 2] = v2 * s2;
        out[base + 3] = v3 * s3;
    }
    for i in (chunks * 4)..n {
        let v = x[i];
        let sig = 1.0 / (1.0 + (-v).exp());
        out[i] = v * sig;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn approx_eq(a: f32, b: f32, tol: f32) -> bool {
        (a - b).abs() < tol
    }

    // Reference values from torch.nn.functional, fp32 tol 5e-5
    // (erf approximation max error 1.5e-7 + downstream cancel).

    #[test]
    fn gelu_exact_torch_ref_values() {
        let x = [0.0, 1.0, 2.0, -1.0, 0.5, -0.5];
        let mut y = [0.0_f32; 6];
        gelu_exact(&x, &mut y);
        assert!(approx_eq(y[0], 0.0, 1e-6));
        assert!(approx_eq(y[1], 0.8413447, 5e-5));
        assert!(approx_eq(y[2], 1.9544997, 5e-5));
        assert!(approx_eq(y[3], -0.15865529, 5e-5));
        assert!(approx_eq(y[4], 0.34573123, 5e-5));
        assert!(approx_eq(y[5], -0.15426877, 5e-5));
    }

    #[test]
    fn gelu_exact_simd_matches_scalar() {
        let x: Vec<f32> = (0..64)
            .map(|i| (i as f32 - 32.0) * 0.1)
            .collect();
        let mut y_scalar = vec![0.0_f32; 64];
        let mut y_simd = vec![0.0_f32; 64];
        gelu_exact(&x, &mut y_scalar);
        gelu_exact_simd(&x, &mut y_simd);
        for i in 0..64 {
            assert!(approx_eq(y_scalar[i], y_simd[i], 1e-6),
                "i={} scalar={} simd={}",
                i, y_scalar[i], y_simd[i]);
        }
    }

    #[test]
    fn gelu_tanh_approx_torch_ref_values() {
        let x = [0.0, 1.0, 2.0, -1.0];
        let mut y = [0.0_f32; 4];
        gelu_tanh_approx(&x, &mut y);
        assert!(approx_eq(y[0], 0.0, 1e-6));
        assert!(approx_eq(y[1], 0.84119, 5e-4));
        assert!(approx_eq(y[2], 1.95459, 5e-4));
        assert!(approx_eq(y[3], -0.15881, 5e-4));
    }

    #[test]
    fn gelu_tanh_approx_simd_matches_scalar() {
        let x: Vec<f32> = (0..63)
            .map(|i| (i as f32 - 31.0) * 0.13)
            .collect();
        let mut y_scalar = vec![0.0_f32; 63];
        let mut y_simd = vec![0.0_f32; 63];
        gelu_tanh_approx(&x, &mut y_scalar);
        gelu_tanh_approx_simd(&x, &mut y_simd);
        for i in 0..63 {
            assert!(approx_eq(y_scalar[i], y_simd[i], 1e-6));
        }
    }

    #[test]
    fn silu_torch_ref_values() {
        let x = [0.0, 1.0, 2.0, -1.0, 0.5, -0.5];
        let mut y = [0.0_f32; 6];
        silu(&x, &mut y);
        assert!(approx_eq(y[0], 0.0, 1e-6));
        assert!(approx_eq(y[1], 0.7310586, 5e-5));
        assert!(approx_eq(y[2], 1.7615942, 5e-5));
        assert!(approx_eq(y[3], -0.2689414, 5e-5));
        assert!(approx_eq(y[4], 0.31122968, 5e-5));
        assert!(approx_eq(y[5], -0.18877034, 5e-5));
    }

    #[test]
    fn silu_simd_matches_scalar() {
        let x: Vec<f32> = (0..128)
            .map(|i| (i as f32 - 64.0) * 0.05)
            .collect();
        let mut y_scalar = vec![0.0_f32; 128];
        let mut y_simd = vec![0.0_f32; 128];
        silu(&x, &mut y_scalar);
        silu_simd(&x, &mut y_simd);
        for i in 0..128 {
            assert!(approx_eq(y_scalar[i], y_simd[i], 1e-6));
        }
    }

    #[test]
    fn erf_approx_known_values() {
        // erf(0) = 0
        assert!(approx_eq(erf_approx(0.0), 0.0, 1e-6));
        // erf(1) ≈ 0.8427008
        assert!(approx_eq(erf_approx(1.0), 0.8427008, 5e-5));
        // erf(-1) ≈ -0.8427008
        assert!(approx_eq(erf_approx(-1.0), -0.8427008, 5e-5));
        // erf(2) ≈ 0.9953223
        assert!(approx_eq(erf_approx(2.0), 0.9953223, 5e-5));
        // erf(3) ≈ 0.9999779
        assert!(approx_eq(erf_approx(3.0), 0.9999779, 5e-5));
    }

    #[test]
    fn gelu_exact_zero_input() {
        let x = [0.0_f32; 16];
        let mut y = [1.0_f32; 16];
        gelu_exact(&x, &mut y);
        for v in y.iter() {
            assert_eq!(*v, 0.0);
        }
    }

    #[test]
    fn silu_handles_large_negative() {
        // Large negative — sigmoid saturates to 0, output ~0
        let x = [-50.0_f32];
        let mut y = [0.0_f32];
        silu(&x, &mut y);
        assert!(y[0].abs() < 1e-10);
    }

    #[test]
    fn silu_handles_large_positive() {
        // Large positive — sigmoid saturates to 1, output ~x
        let x = [50.0_f32];
        let mut y = [0.0_f32];
        silu(&x, &mut y);
        assert!(approx_eq(y[0], 50.0, 1e-5));
    }
}
